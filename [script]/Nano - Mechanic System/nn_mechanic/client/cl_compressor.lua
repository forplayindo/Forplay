local bridge
if _G.bridge then
    bridge = _G.bridge
else
    local communityBridge = exports.community_bridge
    bridge = communityBridge.Bridge(communityBridge)
    _G.bridge = bridge
end

local spawnedCompressors = {}
local activeRopes = {}
local minigameState = {}
minigameState.isPlaying = false
minigameState.lastPressure = nil

RegisterNetEvent("nn_mechanic:useAirCompressor")
AddEventHandler("nn_mechanic:useAirCompressor", function()
    if not (State.employee and State.shop) then
        local notificationMessage = t("not_an_employee")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local shopId, shopCoords = bridge.Callback.Trigger("nn_mechanic:getClosestShop", playerCoords.x, playerCoords.y, playerCoords.z)

    if not shopId or not shopCoords then
        local notificationMessage = t("no_shop_found")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    local shopVector = vector3(shopCoords.x, shopCoords.y, shopCoords.z)
    local distanceToShop = #(playerCoords - shopVector)

    if distanceToShop > 50.0 then
        local notificationMessage = t("too_far_from_shop")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    local placedCompressorObject, compressorHeading = bridge.Placeable.PlaceObject("prop_compressor_01", 15.0, true)

    if not placedCompressorObject then
        local notificationMessage = t("placement_cancelled")
        bridge.Notify.SendNotify(notificationMessage, "info")
        return
    end

    local compressorObjectCoords = GetEntityCoords(placedCompressorObject)
    local distanceCompressorToShop = #(compressorObjectCoords - shopVector)

    if distanceCompressorToShop > 50.0 then
        local notificationMessage = t("compressor_too_far_from_shop")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    local compressorPlacementData = {}
    compressorPlacementData.coords = placedCompressorObject
    compressorPlacementData.heading = compressorHeading

    TriggerServerEvent("nn_mechanic:addAirCompressor", shopId, compressorPlacementData)
end)

local SpawnAirCompressor
SpawnAirCompressor = function(coords, heading)
    if not coords or not coords.x then
        return nil
    end

    local compressorModelHash = GetHashKey("prop_compressor_01")
    RequestModel(compressorModelHash)
    while not HasModelLoaded(compressorModelHash) do
        Wait(10)
    end

    local compressorObject = CreateObject(compressorModelHash, coords.x, coords.y, coords.z, false, true, false)
    if compressorObject and 0 ~= compressorObject then
        local effectiveHeading = heading or 0.0
        SetEntityHeading(compressorObject, effectiveHeading)
        PlaceObjectOnGroundProperly(compressorObject)
        SetEntityAsMissionEntity(compressorObject, true, true)
        FreezeEntityPosition(compressorObject, true)
    end

    SetModelAsNoLongerNeeded(compressorModelHash)

    local newIndex = #spawnedCompressors + 1
    spawnedCompressors[newIndex] = { object = compressorObject }

    bridge.Target.AddLocalEntity(compressorObject, {
        {
            label = t("take_hose_out"),
            icon = "fas fa-wind",
            canInteract = function()
                local employeeState = State.employee
                if employeeState then
                    employeeState = State.shop
                    if employeeState then
                        employeeState = State.compressor
                        employeeState = employeeState.rope
                        employeeState = not employeeState
                    end
                end
                return employeeState
            end,
            onSelect = function()
                if not (State.employee and State.shop) then
                    local notificationMessage = t("not_an_employee")
                    bridge.Notify.SendNotify(notificationMessage, "error")
                    return
                end
                if State.compressor and State.compressor.rope then
                    local notificationMessage = t("hose_already_out")
                    bridge.Notify.SendNotify(notificationMessage, "error")
                    return
                end

                local playerPedCoords = GetEntityCoords(PlayerPedId())
                local closestVehicle = GetClosestVehicle(playerPedCoords, 5.0, 0, 70)

                if not DoesEntityExist(closestVehicle) then
                    local notificationMessage = t("no_vehicle_found")
                    bridge.Notify.SendNotify(notificationMessage, "error")
                    return
                end

                local ropeId = AttachRopeToPlayer(compressorObject)
                if not ropeId then
                    return
                end

                State.compressor = State.compressor or {}
                State.compressor.compressor = compressorObject
                State.compressor.rope = ropeId
                State.compressor.vehicle = closestVehicle
                ShowWheelSelectionMenu(compressorObject, closestVehicle)
            end,
        },
        {
            label = t("return_hose"),
            icon = "fas fa-wind",
            canInteract = function()
                local employeeState = State.employee
                if employeeState then
                    employeeState = State.shop
                end
                return employeeState
            end,
            onSelect = function()
                if not (State.employee and State.shop) then
                    local notificationMessage = t("not_an_employee")
                    bridge.Notify.SendNotify(notificationMessage, "error")
                    return
                end
                ReturnHose(compressorObject)
            end,
        },
    })
    return compressorObject
end

local ShowWheelSelectionMenu
ShowWheelSelectionMenu = function(compressorEntity, vehicleEntity)
    if not vehicleEntity or not DoesEntityExist(vehicleEntity) then
        return
    end

    local availableWheels = GetAvailableWheels(vehicleEntity)
    if #availableWheels == 0 then
        local notificationMessage = t("no_wheels_found")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    local menuItems = {}
    for _, wheelData in ipairs(availableWheels) do
        table.insert(menuItems, {
            label = wheelData.label,
            icon = "fas fa-circle",
            nuiCallback = "selectWheelForTireInflation",
            callbackData = {
                wheelIndex = wheelData.wheelIndex,
                boneName = wheelData.boneName,
            },
        })
    end

    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "wheel_selection_menu",
            items = menuItems,
        },
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu",
        },
    })
    State.openPage = "menu"
    State.currentMenuId = "wheel_selection_menu"
    StartMenuControlsThread()
end

local AttachRopeToPlayer
AttachRopeToPlayer = function(compressorEntity)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local compressorAttachCoords = GetOffsetFromEntityInWorldCoords(compressorEntity, -0.7, -0.01, 0.825)

    local playerHandBoneIndex = GetPedBoneIndex(playerPed, 57005)
    local playerHandCoords = GetWorldPositionOfEntityBone(playerPed, playerHandBoneIndex)

    if playerHandCoords.z == 0.0 then
        local notificationMessage = t("bone_not_found")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return nil
    end

    local flareModelHash = GetHashKey("prop_flare_01b")
    RequestModel(flareModelHash)
    while not HasModelLoaded(flareModelHash) do
        Wait(100)
    end

    if State.compressor and State.compressor.dummyObj then
        DeleteEntity(State.compressor.dummyObj)
        State.compressor.dummyObj = nil
    end

    local dummyObject = CreateObject(flareModelHash, compressorAttachCoords.x, compressorAttachCoords.y, compressorAttachCoords.z, false, false, true)
    while not DoesEntityExist(dummyObject) do
        Wait(100)
    end

    SetEntityRotation(dummyObject, vector3(180, 0, 0))
    SetEntityCollision(dummyObject, false, false)
    FreezeEntityPosition(dummyObject, true)
    SetEntityVisible(dummyObject, false, false)

    State.compressor = State.compressor or {}
    State.compressor.dummyObj = dummyObject

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Citizen.Wait(0)
    end

    local ropeId = AddRope(compressorAttachCoords.x, compressorAttachCoords.y, compressorAttachCoords.z, 0.0, 0.0, 0.0, 7.0, 1, 3.5, 0.5, 1.0, false, false, false, 100.0, true)
    while not ropeId do
        Citizen.Wait(0)
    end

    ActivatePhysics(ropeId)
    LoadRopeData(ropeId, "ropeFamily3")
    Wait(50)

    RequestAnimDict("missfbi4prepp1")
    while not HasAnimDictLoaded("missfbi4prepp1") do
        Citizen.Wait(0)
    end
    TaskPlayAnim(playerPed, "missfbi4prepp1", "idle", 8.0, 8.0, -1, 51, 0, false, false, false)

    AttachEntityToEntity(dummyObject, playerPed, GetPedBoneIndex(playerPed, 57005), 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 0, true)

    local dummyObjectCoords = GetEntityCoords(dummyObject)
    AttachEntitiesToRope(ropeId, compressorEntity, dummyObject, compressorAttachCoords.x, compressorAttachCoords.y, compressorAttachCoords.z, dummyObjectCoords.x, dummyObjectCoords.y, dummyObjectCoords.z, 50.0, false, false, "", "")

    return ropeId
end

local AttachRopeToVehicle
AttachRopeToVehicle = function(compressorEntity, vehicleEntity, boneName)
    local compressorAttachCoords = GetOffsetFromEntityInWorldCoords(compressorEntity, -0.7, -0.01, 0.825)

    local vehicleBoneIndex = GetEntityBoneIndexByName(vehicleEntity, boneName)
    if -1 == vehicleBoneIndex then
        return nil
    end

    local vehicleBonePosition = GetWorldPositionOfEntityBone(vehicleEntity, vehicleBoneIndex)

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Citizen.Wait(0)
    end

    local ropeId = AddRope(compressorAttachCoords.x, compressorAttachCoords.y, compressorAttachCoords.z, 0.0, 0.0, 0.0, 7.0, 1, 3.5, 0.5, 1.0, false, false, false, 100.0, true)
    while not ropeId do
        Citizen.Wait(0)
    end

    ActivatePhysics(ropeId)
    LoadRopeData(ropeId, "ropeFamily3")
    Wait(50)

    AttachEntitiesToRope(ropeId, compressorEntity, vehicleEntity, compressorAttachCoords.x, compressorAttachCoords.y, compressorAttachCoords.z, vehicleBonePosition.x, vehicleBonePosition.y, vehicleBonePosition.z + 0.26, 50.0, false, false, "", "")

    return ropeId
end

local GetAvailableWheels
GetAvailableWheels = function(vehicleEntity)
    local isBike = IsBikeClass(GetVehicleClass(vehicleEntity))
    local boneNames
    local wheelIndicesMap
    local wheelLabelsConfig

    if isBike then
        boneNames = { "wheel_lf", "wheel_lr" }
        wheelIndicesMap = { wheel_lf = 0, wheel_lr = 4 }
        wheelLabelsConfig = Config.TirePressure.bikeWheelLabels
    else
        boneNames = { "wheel_lf", "wheel_rf", "wheel_lr", "wheel_rr" }
        wheelIndicesMap = { wheel_lf = 0, wheel_rf = 1, wheel_lr = 2, wheel_rr = 3 }
        wheelLabelsConfig = Config.TirePressure.wheelLabels
    end

    local availableWheels = {}
    for _, boneName in ipairs(boneNames) do
        local boneIndex = GetEntityBoneIndexByName(vehicleEntity, boneName)
        if -1 ~= boneIndex then
            local wheelIndex = wheelIndicesMap[boneName]
            local label = wheelLabelsConfig[wheelIndex]
            if not label then
                label = Config.TirePressure.wheelLabels[wheelIndex]
                if not label then
                    label = boneName
                end
            end
            table.insert(availableWheels, {
                boneName = boneName,
                wheelIndex = wheelIndex,
                label = label,
            })
        end
    end
    return availableWheels
end

local IsTireBurst
IsTireBurst = function(vehicleEntity, wheelIndex)
    return IsVehicleTyreBurst(vehicleEntity, wheelIndex, false)
end

local GetWheelBonePosition
GetWheelBonePosition = function(vehicleEntity, boneName)
    local boneIndex = GetEntityBoneIndexByName(vehicleEntity, boneName)
    if -1 == boneIndex then
        return nil
    end
    local bonePosition = GetWorldPositionOfEntityBone(vehicleEntity, boneIndex)
    return bonePosition
end

local AttachHoseToVehicle
AttachHoseToVehicle = function(compressorEntity, vehicleEntity, boneName, wheelIndex)
    local playerPed = PlayerPedId()

    FreezeEntityPosition(vehicleEntity, true)

    local progressBarSuccess = bridge.ProgressBar.Open({
        duration = 3000,
        label = t("attaching_hose"),
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
            clip = "machinic_loop_mechandplayer",
            flag = 1,
        },
    })

    if not progressBarSuccess then
        if State.compressor and State.compressor.rope then
            DeleteRope(State.compressor.rope)
            RopeUnloadTextures()
            State.compressor.rope = nil
        end
        if State.compressor and State.compressor.dummyObj then
            DeleteEntity(State.compressor.dummyObj)
            State.compressor.dummyObj = nil
        end
        ClearPedTasks(playerPed)
        return
    end

    if State.compressor and State.compressor.rope then
        DeleteRope(State.compressor.rope)
        RopeUnloadTextures()
        State.compressor.rope = nil
    end
    if State.compressor and State.compressor.dummyObj then
        DeleteEntity(State.compressor.dummyObj)
        State.compressor.dummyObj = nil
    end
    ClearPedTasks(playerPed)

    local newRope = AttachRopeToVehicle(compressorEntity, vehicleEntity, boneName)
    if not newRope then
        local notificationMessage = t("failed_to_attach_hose")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    State.compressor = State.compressor or {}
    State.compressor.rope = newRope
    ClearPedTasks(PlayerPedId())
    OpenPressureGaugeMinigame(vehicleEntity, wheelIndex)
end

local OpenPressureGaugeMinigame
OpenPressureGaugeMinigame = function(vehicleEntity, wheelIndex)
    local vehiclePlate = GetVehicleNumberPlateText(vehicleEntity)
    vehiclePlate = vehiclePlate:gsub("%s+", "")

    local tireIsBurst = IsTireBurst(vehicleEntity, wheelIndex)
    if tireIsBurst then
        local notificationMessage = t("tire_burst")
        bridge.Notify.SendNotify(notificationMessage, "error")
        FreezeEntityPosition(vehicleEntity, false)
        ReattachRopeToPlayer()
        return
    end

    local tireData = bridge.Callback.Trigger("nn_mechanic:getVehicleTireData", vehiclePlate, tostring(wheelIndex))
    if not tireData or not tireData.psi then
        local notificationMessage = t("failed_to_get_tire_data")
        bridge.Notify.SendNotify(notificationMessage, "error")
        FreezeEntityPosition(vehicleEntity, false)
        ReattachRopeToPlayer()
        return
    end

    RequestAnimDict("move_crouch_proto")
    while not HasAnimDictLoaded("move_crouch_proto") do
        Citizen.Wait(0)
    end
    TaskPlayAnim(PlayerPedId(), "move_crouch_proto", "idle", 8.0, 8.0, -1, 51, 0, false, false, false)

    SendNUIMessage({
        action = "setPressureGaugeData",
        data = {
            currentPressure = tireData.psi,
            targetPressure = 32,
            wheelIndex = wheelIndex,
        },
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "pressure-gauge",
        },
    })
    State.openPage = "pressure-gauge"
    SetNuiFocus(true, true)
end

local ReattachRopeToPlayer
ReattachRopeToPlayer = function()
    local compressorState = State.compressor
    if not (compressorState and compressorState.compressor) then
        return
    end
    if not compressorState.vehicle then
        return
    end

    if compressorState.rope then
        DeleteRope(compressorState.rope)
        RopeUnloadTextures()
        compressorState.rope = nil
    end

    local newRope = AttachRopeToPlayer(compressorState.compressor)
    if newRope then
        compressorState.rope = newRope
    end
end

local ReturnHose
ReturnHose = function(compressorEntity)
    if not (State.compressor and State.compressor.rope) then
        local notificationMessage = t("no_hose_to_return")
        bridge.Notify.SendNotify(notificationMessage, "error")
        return
    end

    local playerPed = PlayerPedId()

    if State.compressor.rope then
        DeleteRope(State.compressor.rope)
        RopeUnloadTextures()
        State.compressor.rope = nil
    end

    if State.compressor.dummyObj then
        DeleteEntity(State.compressor.dummyObj)
        State.compressor.dummyObj = nil
    end

    ClearPedTasks(playerPed)

    if State.openPage == "menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = false,
                page = "menu",
            },
        })
        State.openPage = nil
        State.currentMenuId = nil
    end

    State.compressor = {
        compressor = nil,
        rope = nil,
        dummyObj = nil,
        vehicle = nil,
        wheelIndex = nil,
        boneName = nil,
        plate = nil,
    }
end

RegisterNUICallback("selectWheelForTireInflation", function(callbackData, callback)
    local compressorState = State.compressor
    if not (compressorState and compressorState.compressor) then
        callback({ success = false })
        return
    end
    if not compressorState.vehicle then
        callback({ success = false })
        return
    end

    local wheelIndex = callbackData.wheelIndex
    local boneName = callbackData.boneName
    if not wheelIndex or not boneName then
        callback({ success = false })
        return
    end

    local vehicleBoneIndex = GetEntityBoneIndexByName(compressorState.vehicle, boneName)
    if -1 == vehicleBoneIndex then
        local notificationMessage = t("get_closer_to_the_tire")
        bridge.Notify.SendNotify(notificationMessage, "error")
        callback({ success = false })
        return
    end

    local vehicleBonePosition = GetWorldPositionOfEntityBone(compressorState.vehicle, vehicleBoneIndex)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distanceToTire = #(vehicleBonePosition - playerCoords)

    if distanceToTire > 1.0 then
        local notificationMessage = t("get_closer_to_the_tire")
        bridge.Notify.SendNotify(notificationMessage, "error")
        callback({ success = false })
        return
    end

    compressorState.wheelIndex = wheelIndex
    compressorState.boneName = boneName
    local vehiclePlate = GetVehicleNumberPlateText(compressorState.vehicle)
    compressorState.plate = vehiclePlate:gsub("%s+", "")

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "menu",
        },
    })
    State.openPage = nil
    State.currentMenuId = nil

    AttachHoseToVehicle(compressorState.compressor, compressorState.vehicle, boneName, wheelIndex)
    callback({ success = true })
end)

RegisterNUICallback("pressureGaugeUpdate", function(callbackData, callback)
    local compressorState = State.compressor
    if not (compressorState and compressorState.vehicle) then
        callback({ success = false })
        return
    end
    if not compressorState.wheelIndex then
        callback({ success = false })
        return
    end

    local currentPressure = callbackData.pressure
    if not currentPressure then
        callback({ success = false })
        return
    end

    local isActive = callbackData.isActive
    if nil ~= isActive then
        if isActive then
            if not minigameState.isPlaying then
                local compressorCoords
                if compressorState.compressor then
                    compressorCoords = GetEntityCoords(compressorState.compressor)
                else
                    compressorCoords = GetEntityCoords(PlayerPedId())
                end
                TriggerServerEvent("nn_mechanic:pressureSoundStart", compressorCoords)
                minigameState.isPlaying = true
            end
        else
            if minigameState.isPlaying then
                Wait(250)
                TriggerServerEvent("nn_mechanic:pressureSoundStop")
                minigameState.isPlaying = false
            end
        end
    end

    minigameState.lastPressure = currentPressure
    local maxPressure = Config.TirePressure.maxPressure
    if currentPressure >= maxPressure then
        if minigameState.isPlaying then
            TriggerServerEvent("nn_mechanic:pressureSoundStop")
            minigameState.isPlaying = false
        end
        minigameState.lastPressure = nil
        SetVehicleTyreBurst(compressorState.vehicle, compressorState.wheelIndex, true, 1000.0)
        local notificationMessage = t("tire_exploded")
        bridge.Notify.SendNotify(notificationMessage, "error")

        TriggerServerEvent("nn_mechanic:setVehicleTireBurst", compressorState.plate, compressorState.wheelIndex, true)
        local vehicleProps = getVehicleProperties(compressorState.vehicle)
        TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)

        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = false,
                page = "pressure-gauge",
            },
        })
        State.openPage = nil
        SetNuiFocus(false, false)
        ReattachRopeToPlayer()
        FreezeEntityPosition(compressorState.vehicle, false)

        compressorState.boneName = nil
        compressorState.plate = nil

        ShowWheelSelectionMenu(State.compressor.compressor, State.compressor.vehicle)
        callback({ success = true, exploded = true })
        return
    end

    callback({ success = true })
end)

RegisterNUICallback("pressureGaugeClose", function(callbackData, callback)
    local compressorState = State.compressor
    if not (compressorState and compressorState.vehicle) then
        callback({ success = false })
        return
    end
    if not compressorState.wheelIndex then
        callback({ success = false })
        return
    end
    if not compressorState.plate then
        callback({ success = false })
        return
    end

    local finalPressure = callbackData.finalPressure
    if not finalPressure then
        callback({ success = false })
        return
    end

    if minigameState.isPlaying then
        TriggerServerEvent("nn_mechanic:pressureSoundStop")
        minigameState.isPlaying = false
    end
    minigameState.lastPressure = nil

    ClearPedTasks(PlayerPedId())
    TriggerServerEvent("nn_mechanic:setVehicleTirePressure", compressorState.plate, compressorState.wheelIndex, finalPressure)

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "pressure-gauge",
        },
    })
    State.openPage = nil
    SetNuiFocus(false, false)
    ReattachRopeToPlayer()
    FreezeEntityPosition(compressorState.vehicle, false)

    compressorState.wheelIndex = nil
    compressorState.boneName = nil
    compressorState.plate = nil

    ShowWheelSelectionMenu(State.compressor.compressor, State.compressor.vehicle)
    callback({ success = true })
end)

Citizen.CreateThread(function()
    Wait(3000)
    local allCompressors = bridge.Callback.Trigger("nn_mechanic:getAllAirCompressors")
    if allCompressors then
        for _ , shopCompressors in pairs(allCompressors) do
            for _ , compressorData in ipairs(shopCompressors) do
                local coords = compressorData.coords
                if coords then
                    local compressorCoords = vector3(coords.x, coords.y, coords.z)
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    local distanceToCompressor = #(playerCoords - compressorCoords)

                    while distanceToCompressor > 40.0 do
                        Wait(100)
                        playerCoords = GetEntityCoords(PlayerPedId())
                        distanceToCompressor = #(playerCoords - compressorCoords)
                    end
                    SpawnAirCompressor(compressorCoords, compressorData.heading)
                end
            end
        end
    end
end)

RegisterNetEvent("nn_mechanic:spawnAirCompressor")
AddEventHandler("nn_mechanic:spawnAirCompressor", function(shopId, compressorData)
    if compressorData and compressorData.coords then
        SpawnAirCompressor(compressorData.coords, compressorData.heading)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, compressorEntry in ipairs(spawnedCompressors) do
            if compressorEntry.object then
                DeleteEntity(compressorEntry.object)
            end
        end
        for _, ropeId in ipairs(activeRopes) do
            if ropeId then
                RopeUnloadTextures()
                DeleteRope(ropeId)
            end
        end
    end
end)