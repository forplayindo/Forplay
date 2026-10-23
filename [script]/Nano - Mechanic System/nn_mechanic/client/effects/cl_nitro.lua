local bridge

do
    local tempBridge = bridge
    if not tempBridge then
        tempBridge = exports.community_bridge
        tempBridge = tempBridge.Bridge(tempBridge)
    end
    bridge = tempBridge
end

local vehicleNitroBoostStates = {}
local vehicleNitroPurgeStates = {}
local vehicleNitroPurgeParticles = {}
local vehicleLightTrailStates = {}
local vehicleLightTrailParticles = {}
local vehicleCurrentFuel = {}
local vehicleMaxFuel = {}

local lastFuelSaveTick = 0
local FUEL_SAVE_INTERVAL = 10000

local CONTROL_ACCELERATE = 19
local CONTROL_HANDBRAKE = 71

local isHudVisible = false

local nitroHudData = {
    fuel = 0,
    maxFuel = 0,
    isActive = false,
    isPurging = false,
    bottles = {}
}

local function RequestPtfxAssetCore()
    local assetLoaded = HasNamedPtfxAssetLoaded("core")
    if not assetLoaded then
        RequestNamedPtfxAsset("core")
        while true do
            assetLoaded = HasNamedPtfxAssetLoaded("core")
            if assetLoaded then
                break
            end
            Wait(10)
        end
    end
end

local function SetNitroScreenEffects(enableEffects)
    if not Config.Nitro.screenEffectsEnabled then
        return
    end

    if enableEffects then
        StopScreenEffect("RaceTurbo")
        StartScreenEffect("RaceTurbo", 0, false)
        SetTimecycleModifier("rply_motionblur")
        ShakeGameplayCam("SKY_DIVING_SHAKE", 0.25)
    else
        StopGameplayCamShaking(true)
        SetTransitionTimecycleModifier("default", 0.35)
    end
end

local function IsVehicleNitroBoostEnabled(vehicle)
    return true == vehicleNitroBoostStates[vehicle]
end

local function SetVehicleNitroBoostEnabled(vehicle, enable)
    if IsVehicleNitroBoostEnabled(vehicle) == enable then
        return
    end

    local ped = PlayerPedId()
    local isInVehicle = IsPedInVehicle(ped, vehicle, false)
    if isInVehicle or not enable then
        SetNitroScreenEffects(enable)
    end

    SetVehicleBoostActive(vehicle, enable)
    if enable then
        vehicleNitroBoostStates[vehicle] = true
    else
        vehicleNitroBoostStates[vehicle] = nil
    end
end

local function CreateVehicleExhaustBackfire(vehicle, scale)
    if not DoesEntityExist(vehicle) then
        return
    end

    RequestPtfxAssetCore()

    local exhaustBones = {
        "exhaust", "exhaust_2", "exhaust_3", "exhaust_4", "exhaust_5", "exhaust_6",
        "exhaust_7", "exhaust_8", "exhaust_9", "exhaust_10", "exhaust_11", "exhaust_12",
        "exhaust_13", "exhaust_14", "exhaust_15", "exhaust_16"
    }

    local particleScale = scale or 1.0

    for _, boneName in ipairs(exhaustBones) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        if -1 ~= boneIndex then
            local boneWorldPos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            local particleOffset = GetOffsetFromEntityGivenWorldCoords(vehicle, boneWorldPos.x, boneWorldPos.y, boneWorldPos.z)
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedOnEntity("veh_backfire", vehicle, particleOffset.x, particleOffset.y, particleOffset.z, 0.0, 0.0, 0.0, particleScale, false, false, false)
        end
    end
end

local function CreateLoopedParticleOnEntity(entity, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, scale)
    RequestPtfxAssetCore()
    UseParticleFxAssetNextCall("core")
    return StartParticleFxLoopedOnEntity("ent_sht_steam", entity, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, scale, false, false, false)
end

local function CreateVehicleLightTrail(vehicle, boneIndex, scale)
    RequestPtfxAssetCore()
    UseParticleFxAssetNextCall("core")
    local particleHandle = StartParticleFxLoopedOnEntityBone("veh_light_red_trail", vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, boneIndex, scale, false, false, false)
    SetParticleFxLoopedEvolution(particleHandle, "speed", 1.0, false)
    return particleHandle
end

local function FadeOutAndStopParticle(particleHandle, duration)
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + duration

        while GetGameTimer() < endTime do
            Citizen.Wait(0)
            local remainingTime = endTime - GetGameTimer()
            local progress = remainingTime / duration
            SetParticleFxLoopedScale(particleHandle, progress)
            SetParticleFxLoopedAlpha(particleHandle, progress)
        end
        StopParticleFxLooped(particleHandle, false)
    end)
end

local function IsVehicleNitroPurgeEnabled(vehicle)
    return true == vehicleNitroPurgeStates[vehicle]
end

local function SetVehicleNitroPurgeEnabled(vehicle, enable)
    if IsVehicleNitroPurgeEnabled(vehicle) == enable then
        return
    end

    if enable then
        local bonnetBoneIndex = GetEntityBoneIndexByName(vehicle, "bonnet")
        local bonnetWorldPos = GetWorldPositionOfEntityBone(vehicle, bonnetBoneIndex)
        local bonnetOffset = GetOffsetFromEntityGivenWorldCoords(vehicle, bonnetWorldPos.x, bonnetWorldPos.y, bonnetWorldPos.z)
        local particleHandles = {}

        for _ = 0, 3 do
            local leftParticle = CreateLoopedParticleOnEntity(vehicle, bonnetOffset.x - 0.5, bonnetOffset.y + 0.05, bonnetOffset.z, 40.0, -20.0, 0.0, 0.5)
            local rightParticle = CreateLoopedParticleOnEntity(vehicle, bonnetOffset.x + 0.5, bonnetOffset.y + 0.05, bonnetOffset.z, 40.0, 20.0, 0.0, 0.5)
            table.insert(particleHandles, leftParticle)
            table.insert(particleHandles, rightParticle)
        end
        vehicleNitroPurgeStates[vehicle] = true
        vehicleNitroPurgeParticles[vehicle] = particleHandles
    else
        local purgeParticles = vehicleNitroPurgeParticles[vehicle]
        if purgeParticles and #purgeParticles > 0 then
            for _, particle in ipairs(purgeParticles) do
                StopParticleFxLooped(particle, false)
            end
        end
        vehicleNitroPurgeStates[vehicle] = nil
        vehicleNitroPurgeParticles[vehicle] = nil
    end
end

local function IsVehicleLightTrailEnabled(vehicle)
    return true == vehicleLightTrailStates[vehicle]
end

local function SetVehicleLightTrailEnabled(vehicle, enable)
    if IsVehicleLightTrailEnabled(vehicle) == enable then
        return
    end

    if enable then
        local particleHandles = {}
        local taillightL_boneIndex = GetEntityBoneIndexByName(vehicle, "taillight_l")
        local taillightR_boneIndex = GetEntityBoneIndexByName(vehicle, "taillight_r")

        local leftTrail = CreateVehicleLightTrail(vehicle, taillightL_boneIndex, 1.0)
        local rightTrail = CreateVehicleLightTrail(vehicle, taillightR_boneIndex, 1.0)

        table.insert(particleHandles, leftTrail)
        table.insert(particleHandles, rightTrail)

        vehicleLightTrailStates[vehicle] = true
        vehicleLightTrailParticles[vehicle] = particleHandles
    else
        local lightTrails = vehicleLightTrailParticles[vehicle]
        if lightTrails and #lightTrails > 0 then
            for _, particle in ipairs(lightTrails) do
                FadeOutAndStopParticle(particle, 500)
            end
        end
        vehicleLightTrailStates[vehicle] = nil
        vehicleLightTrailParticles[vehicle] = nil
    end
end

local function RefreshVehicleFuelData(vehicle)
    if vehicleCurrentFuel[vehicle] then
        return
    end

    local vehicleState = Entity(vehicle).state
    if not vehicleState then
        return
    end

    local nitroData = vehicleState.nn_nitro_data
    if nitroData and nitroData.fuel then
        vehicleCurrentFuel[vehicle] = nitroData.fuel.current or 0
        vehicleMaxFuel[vehicle] = nitroData.fuel.max or 0
    else
        vehicleCurrentFuel[vehicle] = 0
        vehicleMaxFuel[vehicle] = 0
    end
end

local function GetVehicleCurrentFuel(vehicle)
    return vehicleCurrentFuel[vehicle] or 0
end

local function GetVehicleMaxFuel(vehicle)
    return vehicleMaxFuel[vehicle] or 0
end

local function SetVehicleFuelData(vehicle, currentFuel, maxFuel)
    vehicleCurrentFuel[vehicle] = currentFuel
    if maxFuel then
        vehicleMaxFuel[vehicle] = maxFuel
    end
end

local function DrainVehicleFuel(vehicle, isPurging)
    if not vehicleCurrentFuel[vehicle] then
        RefreshVehicleFuelData(vehicle)
    end

    local drainRate = Config.Nitro.fuel.drainRate
    if isPurging then
        drainRate = drainRate * Config.Nitro.fuel.purgeMultiplier
    end

    local currentFuel = vehicleCurrentFuel[vehicle]
    if currentFuel > 0 then
        vehicleCurrentFuel[vehicle] = currentFuel - drainRate

        local currentTime = GetGameTimer()
        if (currentTime - lastFuelSaveTick) > FUEL_SAVE_INTERVAL then
            lastFuelSaveTick = currentTime
            local plateText = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
            TriggerServerEvent("nn_mechanic:nitro:saveFuel", plateText, vehicleCurrentFuel[vehicle])
        end

        if vehicleCurrentFuel[vehicle] <= 0 then
            vehicleCurrentFuel[vehicle] = 0
            local plateText = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
            TriggerServerEvent("nn_mechanic:nitro:consumeBottle", plateText)
        end
    end
end

local function GetNitroPowerMultiplier(vehicle)
    local vehicleState = Entity(vehicle).state
    if not vehicleState then
        return 1.0
    end

    local nitroData = vehicleState.nn_nitro_data
    if nitroData and nitroData.bottles and #nitroData.bottles ~= 0 then
        local totalPower = 0
        for _, bottle in ipairs(nitroData.bottles) do
            totalPower = totalPower + (bottle.power or 1.0)
        end
        return totalPower / #nitroData.bottles
    end

    return 1.0
end

local function IsNitroInstalled(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end
    local vehicleState = Entity(vehicle).state
    if not vehicleState then
        return false
    end
    return true == vehicleState.nn_nitro_installed
end

local function IsNitroBoostKeyPressed()
    local keyboardKey = Config.Nitro.controls.keyboardKey
    local controllerKey = Config.Nitro.controls.controllerKey

    if not IsInputDisabled(2) then
        DisableControlAction(2, controllerKey, true)
        return IsDisabledControlPressed(2, controllerKey)
    end
    return IsControlPressed(0, keyboardKey)
end

local function IsHandbrakePressed()
    return IsControlPressed(0, CONTROL_HANDBRAKE)
end

local function IsElectricVehicle(vehicle)
    local modelHash = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(modelHash)
    local lowerDisplayName = string.lower(displayName)
    return true == Config.Nitro.electricVehicles[lowerDisplayName]
end

local function UpdateNitroHud(vehicle, isActive, isPurging)
    local currentFuel = vehicleCurrentFuel[vehicle] or 0
    local maxFuel = vehicleMaxFuel[vehicle] or 0

    local vehicleState = Entity(vehicle).state
    local bottlesData = {}
    if vehicleState and vehicleState.nn_nitro_data and vehicleState.nn_nitro_data.bottles then
        bottlesData = vehicleState.nn_nitro_data.bottles
    end

    nitroHudData.fuel = currentFuel
    nitroHudData.maxFuel = maxFuel
    nitroHudData.isActive = isActive
    nitroHudData.isPurging = isPurging
    nitroHudData.bottles = bottlesData

    SendNUIMessage({
        action = "nitroHudUpdate",
        data = nitroHudData
    })
end

local function SetNitroHudVisibility(visible, vehicle)
    if isHudVisible == visible then
        return
    end
    isHudVisible = visible

    if visible and vehicle then
        RefreshVehicleFuelData(vehicle)
        UpdateNitroHud(vehicle, false, false)
    end

    SendNUIMessage({
        action = "setVisibility",
        data = { visible = visible, page = "nitro-hud" }
    })
end

Citizen.CreateThread(function()
    while Config.Nitro.enabled do
        local backfireCount = 0
        local pedCoords = GetEntityCoords(State.Ped)

        for vehicle, _ in pairs(vehicleNitroBoostStates) do
            if DoesEntityExist(vehicle) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(pedCoords - vehicleCoords)
                if distance < 50.0 then
                    backfireCount = backfireCount + 1
                    CreateVehicleExhaustBackfire(vehicle, 1.25)
                end
            end
        end
        Citizen.Wait(backfireCount > 0 and 1 or 500)
    end
end)

Citizen.CreateThread(function()
    while Config.Nitro.enabled do
        Citizen.Wait(1)

        local ped = State.Ped
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        local driverPed = GetPedInVehicleSeat(currentVehicle, -1)
        local isBoostEnabled = IsVehicleNitroBoostEnabled(currentVehicle)

        if currentVehicle ~= 0 and driverPed == ped and isBoostEnabled then
            if IsVehicleStopped(currentVehicle) then
                Wait(500)
            else
                local vehicleModel = GetEntityModel(currentVehicle)
                local maxSpeed = GetVehicleModelMaxSpeed(vehicleModel)
                local currentSpeed = GetEntitySpeed(currentVehicle)
                local powerMultiplier = GetNitroPowerMultiplier(currentVehicle)

                local torqueMultiplier = (powerMultiplier * maxSpeed) / math.max(currentSpeed, 1.0)
                torqueMultiplier = math.min(torqueMultiplier, powerMultiplier * 3.0)
                SetVehicleEngineTorqueMultiplier(currentVehicle, torqueMultiplier)
            end
        end
    end
end)

Citizen.CreateThread(function()
    while Config.Nitro.enabled do
        Citizen.Wait(100)

        if isHudVisible then
            local pedId = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(pedId, false)
            if currentVehicle ~= 0 then
                if IsNitroInstalled(currentVehicle) then
                    local isBoostEnabled = IsVehicleNitroBoostEnabled(currentVehicle)
                    local isPurgeEnabled = IsVehicleNitroPurgeEnabled(currentVehicle)
                    UpdateNitroHud(currentVehicle, isBoostEnabled, isPurgeEnabled)
                end
            else
                Wait(400)
            end
        end
    end
end)

Citizen.CreateThread(function()
    local prevVehicle = 0
    while Config.Nitro.enabled do
        Citizen.Wait(0)

        local ped = State.Ped
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        local driverPed = GetPedInVehicleSeat(currentVehicle, -1)

        if prevVehicle ~= 0 and prevVehicle ~= currentVehicle then
            SetVehicleNitroBoostEnabled(prevVehicle, false)
            SetVehicleLightTrailEnabled(prevVehicle, false)
            SetVehicleNitroPurgeEnabled(prevVehicle, false)

            local prevVehicleNetId = NetworkGetNetworkIdFromEntity(prevVehicle)
            TriggerServerEvent("nn_mechanic:nitro:sync", prevVehicleNetId, false, false, true)

            if vehicleCurrentFuel[prevVehicle] then
                local plateText = GetVehicleNumberPlateText(prevVehicle):gsub("%s+", "")
                TriggerServerEvent("nn_mechanic:nitro:saveFuel", plateText, vehicleCurrentFuel[prevVehicle])
            end
            SetNitroHudVisibility(false)
        end

        if currentVehicle == 0 or driverPed ~= ped then
            if isHudVisible then
                SetNitroHudVisibility(false)
            end
            prevVehicle = currentVehicle
            Wait(500)
        else
            local modelHash = GetEntityModel(currentVehicle)
            local isCar = IsThisModelACar(modelHash)
            local allowElectric = Config.Nitro.allowElectric
            local isElectric = IsElectricVehicle(currentVehicle)

            if not isCar or (not allowElectric and isElectric) then
                if isHudVisible then
                    SetNitroHudVisibility(false)
                end
                prevVehicle = currentVehicle
                Wait(500)
            else
                if not IsNitroInstalled(currentVehicle) then
                    if isHudVisible then
                        SetNitroHudVisibility(false)
                    end
                    prevVehicle = currentVehicle
                    Wait(500)
                else
                    if not isHudVisible then
                        SetNitroHudVisibility(true, currentVehicle)
                    end
                    RefreshVehicleFuelData(currentVehicle)

                    local isBoostKeyPressed = IsNitroBoostKeyPressed()
                    local isHandbrakePressed = IsHandbrakePressed()
                    local isEngineRunning = GetIsVehicleEngineRunning(currentVehicle)
                    local isBoostEnabled = IsVehicleNitroBoostEnabled(currentVehicle)
                    local isPurgeEnabled = IsVehicleNitroPurgeEnabled(currentVehicle)
                    local hasFuel = GetVehicleCurrentFuel(currentVehicle) > 0

                    if isEngineRunning and isBoostKeyPressed and hasFuel then
                        local useAccelerateForBoost = Config.Nitro.controls.useAccelerateForBoost
                        if useAccelerateForBoost then
                            if isHandbrakePressed then
                                if not isPurgeEnabled then
                                    SetVehicleNitroBoostEnabled(currentVehicle, false)
                                    SetVehicleLightTrailEnabled(currentVehicle, false)
                                    SetVehicleNitroPurgeEnabled(currentVehicle, true)
                                    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                                    TriggerServerEvent("nn_mechanic:nitro:sync", netId, false, true, false)
                                end
                                DrainVehicleFuel(currentVehicle, true)
                            else
                                if not isBoostEnabled then
                                    SetVehicleNitroBoostEnabled(currentVehicle, true)
                                    SetVehicleLightTrailEnabled(currentVehicle, true)
                                    SetVehicleNitroPurgeEnabled(currentVehicle, false)
                                    local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                                    TriggerServerEvent("nn_mechanic:nitro:sync", netId, true, false, false)
                                end
                                DrainVehicleFuel(currentVehicle, false)
                            end
                        else
                            if not isBoostEnabled then
                                SetVehicleNitroBoostEnabled(currentVehicle, true)
                                SetVehicleLightTrailEnabled(currentVehicle, true)
                                local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                                TriggerServerEvent("nn_mechanic:nitro:sync", netId, true, false, false)
                            end
                            DrainVehicleFuel(currentVehicle, false)
                        end
                    elseif isBoostEnabled or isPurgeEnabled then
                        SetVehicleNitroBoostEnabled(currentVehicle, false)
                        SetVehicleLightTrailEnabled(currentVehicle, false)
                        SetVehicleNitroPurgeEnabled(currentVehicle, false)
                        local netId = NetworkGetNetworkIdFromEntity(currentVehicle)
                        TriggerServerEvent("nn_mechanic:nitro:sync", netId, false, false, false)
                    end
                    prevVehicle = currentVehicle
                end
            end
        end
    end
end)

RegisterNetEvent("nn_mechanic:nitro:update", function(serverId, netId, enableBoost, enablePurge, forcePassengerSeat)
    local player = GetPlayerFromServerId(serverId)
    if not NetworkIsPlayerConnected(player) then
        return
    end

    if player == PlayerId() then
        return
    end

    local ped = GetPlayerPed(player)
    local vehicle = GetVehiclePedIsIn(ped, forcePassengerSeat)

    if vehicle == 0 then
        vehicle = NetworkGetEntityFromNetworkId(netId)
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleNitroBoostEnabled(vehicle, enableBoost)
        SetVehicleLightTrailEnabled(vehicle, enableBoost)
        SetVehicleNitroPurgeEnabled(vehicle, enablePurge)
    end
end)

RegisterNetEvent("nn_mechanic:nitro:bottleConsumed", function(plateText, nitroData)
    local pedId = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(pedId, false)
    if currentVehicle == 0 then
        return
    end

    local currentVehiclePlate = GetVehicleNumberPlateText(currentVehicle):gsub("%s+", "")
    if currentVehiclePlate ~= plateText then
        return
    end

    if nitroData and nitroData.fuel then
        SetVehicleFuelData(currentVehicle, nitroData.fuel.current, nitroData.fuel.max)
    else
        SetVehicleFuelData(currentVehicle, 0, 0)
    end

    if nitroData and nitroData.bottles and #nitroData.bottles > 0 then
        local bottlesRemaining = #nitroData.bottles
        bridge.Notify.SendNotify(t("nitro_bottle_empty_remaining"):format(bottlesRemaining), "warning")
    else
        bridge.Notify.SendNotify(t("nitro_bottle_empty_none"), "error")
        SetNitroHudVisibility(false)
    end

    if isHudVisible then
        UpdateNitroHud(currentVehicle, false, false)
    end
end)

RegisterNetEvent("nn_mechanic:nitro:dataRefresh", function(plateText, nitroData)
    local pedId = PlayerPedId()
    local currentVehicle = GetVehiclePedIsIn(pedId, false)
    if currentVehicle == 0 then
        return
    end

    local currentVehiclePlate = GetVehicleNumberPlateText(currentVehicle):gsub("%s+", "")
    if currentVehiclePlate ~= plateText then
        return
    end

    if nitroData and nitroData.fuel then
        SetVehicleFuelData(currentVehicle, nitroData.fuel.current, nitroData.fuel.max)
    end

    if isHudVisible then
        local isBoostEnabled = IsVehicleNitroBoostEnabled(currentVehicle)
        local isPurgeEnabled = IsVehicleNitroPurgeEnabled(currentVehicle)
        UpdateNitroHud(currentVehicle, isBoostEnabled, isPurgeEnabled)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNitroHudVisibility(false)

        for vehicle, _ in pairs(vehicleNitroBoostStates) do
            if DoesEntityExist(vehicle) then
                SetVehicleBoostActive(vehicle, false)
            end
        end

        for _, particles in pairs(vehicleNitroPurgeParticles) do
            if particles then
                for _, particle in ipairs(particles) do
                    StopParticleFxLooped(particle, false)
                end
            end
        end

        for _, particles in pairs(vehicleLightTrailParticles) do
            if particles then
                for _, particle in ipairs(particles) do
                    StopParticleFxLooped(particle, false)
                end
            end
        end

        StopScreenEffect("RaceTurbo")
        StopGameplayCamShaking(true)
        SetTransitionTimecycleModifier("default", 0.0)
    end
end)