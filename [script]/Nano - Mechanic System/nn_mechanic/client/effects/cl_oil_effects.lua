VehicleEnginePower = VehicleEnginePower or {}
OilStallState = OilStallState or {}
OilVisualHealth = OilVisualHealth or {}

function EnsureEnginePowerState(vehicleEntity)
    local networkId = NetworkGetNetworkIdFromEntity(vehicleEntity)
    if not networkId or networkId == 0 then
        return nil, nil
    end

    local enginePowerData = VehicleEnginePower[networkId]
    if not enginePowerData then
        local vehicleState = Entity(vehicleEntity).state

        local baseEnginePower = vehicleState.ns_base_engine_power
        if not baseEnginePower or baseEnginePower <= 0 then
            baseEnginePower = GetVehicleHandlingFloat(vehicleEntity, "CHandlingData", "fInitialDriveForce")
        end

        local baseDriveInertia = vehicleState.ns_base_drive_inertia
        if not baseDriveInertia or baseDriveInertia <= 0 then
            baseDriveInertia = GetVehicleHandlingFloat(vehicleEntity, "CHandlingData", "fDriveInertia")
        end

        if not baseEnginePower or baseEnginePower <= 0 then
            return nil, nil
        end

        if not baseDriveInertia or baseDriveInertia <= 0 then
            baseDriveInertia = 1.0
        end

        enginePowerData = {
            stock = baseEnginePower,
            stockInertia = baseDriveInertia,
            custom = nil,
            customInertia = nil,
            oilMult = 1.0,
            oilInertiaMult = 1.0
        }
        VehicleEnginePower[networkId] = enginePowerData
    end
    return enginePowerData, networkId
end

local function resetVehicleEngineMultipliers(vehicleEntity)
    ModifyVehicleTopSpeed(vehicleEntity, 1.0)
    SetVehicleEnginePowerMultiplier(vehicleEntity, 0.0)
end

function ApplyEffectiveEnginePower(vehicleEntity)
    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if not enginePowerData then
        return
    end

    local effectiveDriveForce = enginePowerData.custom
    if not effectiveDriveForce then
        effectiveDriveForce = enginePowerData.stock
    end

    if effectiveDriveForce and effectiveDriveForce > 0 then
        effectiveDriveForce = effectiveDriveForce * enginePowerData.oilMult
        SetVehicleHandlingFloat(vehicleEntity, "CHandlingData", "fInitialDriveForce", effectiveDriveForce)
    end

    local effectiveDriveInertia = enginePowerData.customInertia
    if not effectiveDriveInertia then
        effectiveDriveInertia = enginePowerData.stockInertia
    end

    if effectiveDriveInertia and effectiveDriveInertia > 0 then
        effectiveDriveInertia = effectiveDriveInertia * enginePowerData.oilInertiaMult
        SetVehicleHandlingFloat(vehicleEntity, "CHandlingData", "fDriveInertia", effectiveDriveInertia)
    end

    resetVehicleEngineMultipliers(vehicleEntity)
end

function SetCustomEnginePower(vehicleEntity, newCustomPower)
    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if not enginePowerData then
        return
    end
    enginePowerData.custom = newCustomPower
    ApplyEffectiveEnginePower(vehicleEntity)
end

function ClearCustomEnginePower(vehicleEntity)
    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if not enginePowerData then
        return
    end
    enginePowerData.custom = nil
    ApplyEffectiveEnginePower(vehicleEntity)
end

function SetCustomEngineInertia(vehicleEntity, newCustomInertia)
    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if not enginePowerData then
        return
    end
    enginePowerData.customInertia = newCustomInertia
    ApplyEffectiveEnginePower(vehicleEntity)
end

function ClearCustomEngineInertia(vehicleEntity)
    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if not enginePowerData then
        return
    end
    enginePowerData.customInertia = nil
    ApplyEffectiveEnginePower(vehicleEntity)
end

local function getOilPowerReductionMultiplier(oilQualityNormalized)
    local oilProfile = Config.OilQuality.profiles[Config.OilQuality.defaultProfile]
    if not oilProfile then
        return 1.0
    end

    local thresholds = oilProfile.thresholds
    local powerReduction = oilProfile.powerReduction

    if oilQualityNormalized >= thresholds.excellent then
        return powerReduction.excellent
    elseif oilQualityNormalized >= thresholds.good then
        return powerReduction.good
    elseif oilQualityNormalized >= thresholds.fair then
        return powerReduction.fair
    elseif oilQualityNormalized >= thresholds.poor then
        return powerReduction.poor
    else
        return powerReduction.critical
    end
end

local function getOilInertiaReductionMultiplier(oilQualityNormalized)
    local oilProfile = Config.OilQuality.profiles[Config.OilQuality.defaultProfile]
    if oilProfile and oilProfile.inertiaReduction then
        local thresholds = oilProfile.thresholds
        local inertiaReduction = oilProfile.inertiaReduction

        if oilQualityNormalized >= thresholds.excellent then
            return inertiaReduction.excellent
        elseif oilQualityNormalized >= thresholds.good then
            return inertiaReduction.good
        elseif oilQualityNormalized >= thresholds.fair then
            return inertiaReduction.fair
        elseif oilQualityNormalized >= thresholds.poor then
            return inertiaReduction.poor
        else
            return inertiaReduction.critical
        end
    end
    return 1.0
end

local function getOilQualityNormalized(vehicleEntity)
    local networkId = NetworkGetNetworkIdFromEntity(vehicleEntity)
    if not networkId or networkId == 0 then
        return nil
    end

    local stateBagName = ("entity:%d"):format(networkId)
    local oilQualityRaw = GetStateBagValue(stateBagName, "ns_oil_quality")

    if not oilQualityRaw then
        return nil
    end
    return oilQualityRaw / 100.0
end

AddEventHandler("entityRemoved", function(entity)
    local entityType = GetEntityType(entity)
    if entityType ~= 2 then
        return
    end

    local networkId = NetworkGetNetworkIdFromEntity(entity)
    if not networkId or networkId == 0 then
        return
    end

    VehicleEnginePower[networkId] = nil
    OilStallState[networkId] = nil
    OilVisualHealth[networkId] = nil
end)

local function getOilEffectsConfig()
    local oilProfile = Config.OilQuality.profiles[Config.OilQuality.defaultProfile]
    if oilProfile and oilProfile.effects then
        return oilProfile.effects
    end
    return nil
end

local function getOilVisualHealthTier(oilQualityNormalized)
    local oilProfile = Config.OilQuality.profiles[Config.OilQuality.defaultProfile]
    if not oilProfile then
        return "none"
    end

    local thresholds = oilProfile.thresholds

    if oilQualityNormalized >= thresholds.good then
        return "none"
    elseif oilQualityNormalized >= thresholds.fair then
        return "light"
    elseif oilQualityNormalized >= thresholds.poor then
        return "medium"
    else
        return "heavy"
    end
end

local function handleOilVisualHealth(vehicleEntity, networkId, visualHealthTier)
    local oilEffectsConfig = getOilEffectsConfig()

    if visualHealthTier == "none" then
        local vehicleVisualHealthData = OilVisualHealth[networkId]
        if vehicleVisualHealthData then
            local currentEngineHealth = GetVehicleEngineHealth(vehicleEntity)
            local healthToSet = math.max(vehicleVisualHealthData.saved, currentEngineHealth)
            SetVehicleEngineHealth(vehicleEntity, healthToSet)
            OilVisualHealth[networkId] = nil
        end
        return
    end

    local smokeEffectConfig = nil
    if oilEffectsConfig and oilEffectsConfig.smoke then
        smokeEffectConfig = oilEffectsConfig.smoke[visualHealthTier]
    end

    if not smokeEffectConfig then
        return
    end

    local drainPerTick = smokeEffectConfig.drainPerTick or 2.0
    local floorHealth = smokeEffectConfig.floorHealth or 200

    local currentEngineHealth = GetVehicleEngineHealth(vehicleEntity)
    local vehicleVisualHealthData = OilVisualHealth[networkId]

    if not vehicleVisualHealthData then
        vehicleVisualHealthData = {
            saved = currentEngineHealth,
            tier = "none"
        }
        OilVisualHealth[networkId] = vehicleVisualHealthData
    end

    if floorHealth < currentEngineHealth then
        local newEngineHealth = math.max(currentEngineHealth - drainPerTick, floorHealth)
        SetVehicleEngineHealth(vehicleEntity, newEngineHealth)
        if vehicleVisualHealthData.tier ~= visualHealthTier then
            vehicleVisualHealthData.tier = visualHealthTier
        end
    end
end

local function handleEngineStall(vehicleEntity, networkId, stallDurationMs, stallConfig)
    SetVehicleUndriveable(vehicleEntity, true)

    local stallEndTime = GetGameTimer() + stallDurationMs
    while GetGameTimer() < stallEndTime do
        if not DoesEntityExist(vehicleEntity) then
            break
        end
        SetVehicleEngineOn(vehicleEntity, false, true, true)
        Wait(0)
    end

    if DoesEntityExist(vehicleEntity) then
        SetVehicleUndriveable(vehicleEntity, false)
        SetVehicleEngineOn(vehicleEntity, true, false, true)
    end

    local stallState = OilStallState[networkId]
    if stallState then
        stallState.stalledUntil = nil
        local nextCheckInterval = (stallConfig and stallConfig.checkIntervalMs) or 10000
        stallState.nextCheckAt = GetGameTimer() + nextCheckInterval
    end
end

local lastPlayerVehicleNetworkId = 0

CreateThread(function()
    while true do
        Wait(500)

        local oilEffectsConfig = getOilEffectsConfig()
        local playerPed = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(playerPed, false)
        local isPlayerInVehicle = currentVehicle ~= 0

        -- Logic for handling cleanup if player is not in a vehicle or if oil effects are disabled
        if not isPlayerInVehicle or not oilEffectsConfig then
            if lastPlayerVehicleNetworkId ~= 0 then
                local previousVehicle = NetToVeh(lastPlayerVehicleNetworkId)
                if previousVehicle ~= 0 and DoesEntityExist(previousVehicle) then
                    SetVehicleUndriveable(previousVehicle, false)
                    SetVehicleEngineTorqueMultiplier(previousVehicle, 1.0)
                end
                local stallState = OilStallState[lastPlayerVehicleNetworkId]
                if stallState then
                    stallState.stalledUntil = nil
                end
                lastPlayerVehicleNetworkId = 0
            end
            if not isPlayerInVehicle then
                goto continue_loop
            end
            if not oilEffectsConfig then
                goto continue_loop
            end
        end

        -- From here, we know `isPlayerInVehicle` is true AND `oilEffectsConfig` is not nil.
        local currentVehicleNetworkId = NetworkGetNetworkIdFromEntity(currentVehicle)
        if not currentVehicleNetworkId or currentVehicleNetworkId == 0 then
            goto continue_loop
        end

        lastPlayerVehicleNetworkId = currentVehicleNetworkId

        local oilQualityNormalized = getOilQualityNormalized(currentVehicle)
        if not oilQualityNormalized then
            oilQualityNormalized = 100.0
        end

        local visualHealthTier = getOilVisualHealthTier(oilQualityNormalized)
        handleOilVisualHealth(currentVehicle, currentVehicleNetworkId, visualHealthTier)

        if visualHealthTier == "medium" or visualHealthTier == "heavy" then
            local stallEffectTier = (visualHealthTier == "heavy") and "critical" or "poor"

            local stallConfig = oilEffectsConfig.stall and oilEffectsConfig.stall[stallEffectTier]
            local knockConfig = oilEffectsConfig.knock and oilEffectsConfig.knock[stallEffectTier]

            local vehicleStallState = OilStallState[currentVehicleNetworkId]
            if not vehicleStallState then
                vehicleStallState = {}
                OilStallState[currentVehicleNetworkId] = vehicleStallState
            end

            if not vehicleStallState.stalledUntil and stallConfig then
                local currentTime = GetGameTimer()
                local nextCheckAt = vehicleStallState.nextCheckAt
                if not nextCheckAt or currentTime >= nextCheckAt then
                    local randomChance = math.random()
                    if randomChance < stallConfig.chance then
                        local minDuration = stallConfig.minDurationMs or 800
                        local maxDuration = stallConfig.maxDurationMs or 2000
                        local stallDuration = math.random(minDuration, maxDuration)

                        vehicleStallState.stalledUntil = true

                        if stallConfig.shakeIntensity and stallConfig.shakeIntensity > 0 then
                            ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", stallConfig.shakeIntensity)
                        end

                        if stallConfig.backfire then
                            CreateVehicleExhaustBackfire(currentVehicle, 0.6)
                        end

                        CreateThread(function()
                            handleEngineStall(currentVehicle, currentVehicleNetworkId, stallDuration, stallConfig)
                        end)
                    end
                    local checkInterval = stallConfig.checkIntervalMs or 10000
                    vehicleStallState.nextCheckAt = currentTime + checkInterval
                end
            end

            if not vehicleStallState.stalledUntil and knockConfig then
                local isEngineRunning = GetIsVehicleEngineRunning(currentVehicle)
                if isEngineRunning then
                    local currentTime = GetGameTimer()
                    local nextKnockAt = vehicleStallState.nextKnockAt
                    if not nextKnockAt or currentTime >= nextKnockAt then
                        local intervalMs = knockConfig.intervalMs or 4000
                        vehicleStallState.nextKnockAt = currentTime + intervalMs

                        local torqueMult = knockConfig.torqueMult or 0.5
                        local durationMs = knockConfig.durationMs or 200

                        CreateThread(function()
                            SetVehicleEngineTorqueMultiplier(currentVehicle, torqueMult)
                            Wait(durationMs)
                            if DoesEntityExist(currentVehicle) then
                                SetVehicleEngineTorqueMultiplier(currentVehicle, 1.0)
                            end
                        end)
                    end
                end
            end
        end
        ::continue_loop::
    end
end)

AddStateBagChangeHandler("ns_oil_quality", nil, function(stateBagName, key, newVal)
    local _, networkIdStr = stateBagName:match("entity:(%d+)")
    local networkId = tonumber(networkIdStr)
    if not networkId then
        return
    end

    local vehicleEntity = NetToVeh(networkId)
    if vehicleEntity == 0 or not DoesEntityExist(vehicleEntity) then
        return
    end

    local oilQualityNormalized = 100.0
    if newVal then
        oilQualityNormalized = newVal / 100.0
    end

    local enginePowerData = EnsureEnginePowerState(vehicleEntity)
    if enginePowerData then
        enginePowerData.oilMult = getOilPowerReductionMultiplier(oilQualityNormalized)
        enginePowerData.oilInertiaMult = getOilInertiaReductionMultiplier(oilQualityNormalized)
        ApplyEffectiveEnginePower(vehicleEntity)
    end
end)