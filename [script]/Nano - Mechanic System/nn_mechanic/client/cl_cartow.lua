local bridgeLocal = bridge
if not bridgeLocal then
    local communityBridgeExports = exports.community_bridge
    bridgeLocal = communityBridgeExports.Bridge(communityBridgeExports)
end
bridge = bridgeLocal

local towState = {
    active = false,
    towVehicle = nil,
    towType = nil,
    attachedVehicle = nil,
    candidates = {}
}

local towVehicleModels = {
    flatbed = GetHashKey("flatbed"),
    towtruck = GetHashKey("towtruck"),
    towtruck2 = GetHashKey("towtruck2")
}

local function getTowVehicleType(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) then
        return nil
    end

    local entityModel = GetEntityModel(vehicleEntity)
    for towTypeName, modelHash in pairs(towVehicleModels) do
        if entityModel == modelHash then
            return towTypeName
        end
    end
    return nil
end

local function isVehicleOccupied(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) then
        return false
    end
    return not IsVehicleSeatFree(vehicleEntity, -1)
end

local function findNearbyTowableVehicles(playerCoords, radius, excludeVehicleEntity)
    local nearbyVehicles = {}
    local findHandle, currentVehicle = FindFirstVehicle()
    local success = true

    while success do
        if DoesEntityExist(currentVehicle) and currentVehicle ~= excludeVehicleEntity then
            local vehicleCoords = GetEntityCoords(currentVehicle)
            local distance = #(playerCoords - vehicleCoords)

            if radius >= distance then
                local vehicleInfo = {
                    vehicle = currentVehicle,
                    netId = NetworkGetNetworkIdFromEntity(currentVehicle),
                    distance = distance,
                    coords = vehicleCoords,
                    plate = GetVehicleNumberPlateText(currentVehicle),
                    model = GetDisplayNameFromVehicleModel(GetEntityModel(currentVehicle))
                }
                table.insert(nearbyVehicles, vehicleInfo)
            end
        end
        success, currentVehicle = FindNextVehicle(findHandle)
    end
    EndFindVehicle(findHandle)

    table.sort(nearbyVehicles, function(a, b)
        return a.distance < b.distance
    end)

    return nearbyVehicles
end

local function requestNetworkControl(entity, timeoutMs)
    if not timeoutMs then
        timeoutMs = 1000
    end

    local startTime = GetGameTimer()
    if NetworkHasControlOfEntity(entity) then
        return true
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    NetworkRequestControlOfNetworkId(netId)
    NetworkRequestControlOfEntity(entity)

    while true do
        if NetworkHasControlOfEntity(entity) then
            break
        end

        Wait(10)
        NetworkRequestControlOfNetworkId(netId)
        NetworkRequestControlOfEntity(entity)

        if timeoutMs < (GetGameTimer() - startTime) then
            return false
        end
    end
    return true
end

local function getAttachedVehicle(towVehicleEntity, towType)
    if towType == "towtruck" or towType == "towtruck2" then
        return GetEntityAttachedToTowTruck(towVehicleEntity)
    elseif towType == "flatbed" then
        return towState.attachedVehicle
    end
    return nil
end

local function attachVehicle(towVehicleEntity, targetVehicleEntity, towType)
    local hasControlOfTarget = requestNetworkControl(targetVehicleEntity, 2000)
    if not hasControlOfTarget then
        bridge.Notify.SendNotify(t("tow_network_control_failed"), "error")
        return false
    end
    requestNetworkControl(towVehicleEntity, 1000)

    if towType == "flatbed" then
        local targetVehicleModelHash = GetEntityModel(targetVehicleEntity)
        local minTargetVehicleDim, _ = GetModelDimensions(targetVehicleModelHash)
        local bodyshellBoneIndex = GetEntityBoneIndexByName(targetVehicleEntity, "bodyshell")

        AttachEntityToEntity(
            targetVehicleEntity,
            towVehicleEntity,
            bodyshellBoneIndex,
            0.0,
            -2.35,
            0.3 - minTargetVehicleDim.z,
            0.0,
            0.0,
            0.0,
            false,
            true,
            true,
            false,
            0,
            true
        )
        towState.attachedVehicle = targetVehicleEntity
        return true
    end
    return false
end

local function detachVehicle(towVehicleEntity, towType)
    local attachedVehicleEntity = getAttachedVehicle(towVehicleEntity, towType)
    if not attachedVehicleEntity or attachedVehicleEntity == 0 then
        return false
    end

    local hasControlOfAttached = requestNetworkControl(attachedVehicleEntity, 2000)
    if not hasControlOfAttached then
        bridge.Notify.SendNotify(t("tow_network_control_failed"), "error")
        return false
    end
    requestNetworkControl(towVehicleEntity, 1000)

    if towType == "towtruck" or towType == "towtruck2" then
        DetachVehicleFromTowTruck(towVehicleEntity, attachedVehicleEntity)
    elseif towType == "flatbed" then
        local towVehicleWorldCoords = GetOffsetFromEntityInWorldCoords(towVehicleEntity, 0.0, 0.0, 0.0)
        local towVehicleEntityCoords = GetEntityCoords(towVehicleEntity, false)
        local attachedVehicleWorldCoords = GetOffsetFromEntityInWorldCoords(attachedVehicleEntity, 0.0, 0.0, 0.0)

        local minTowDim, maxTowDim = GetModelDimensions(GetEntityModel(towVehicleEntity))
        local minAttachedDim, maxAttachedDim = GetModelDimensions(GetEntityModel(attachedVehicleEntity))

        local attachedVehicleWidth = math.ceil(maxAttachedDim.y - minAttachedDim.y)

        local yOffsetTempAttach
        if attachedVehicleWidth < 6 then
            yOffsetTempAttach = math.ceil((maxTowDim.y - minTowDim.y) * 0.75)
        else
            yOffsetTempAttach = math.ceil((maxTowDim.y - minTowDim.y) * 0.5)
        end
        local yOffset = yOffsetTempAttach + attachedVehicleWidth + 0.0

        local zOffset = -1 * (towVehicleWorldCoords.z - (towVehicleEntityCoords.z - (attachedVehicleWorldCoords.z - towVehicleWorldCoords.z))) + 0.0

        AttachEntityToEntity(
            attachedVehicleEntity,
            towVehicleEntity,
            20,
            0.0,
            0.0 - yOffset,
            zOffset,
            0.0,
            0.0,
            0.0,
            false,
            false,
            false,
            false,
            20,
            true
        )
        Wait(100)
        DetachEntity(attachedVehicleEntity, false, false)
    end

    towState.attachedVehicle = nil
    return true
end

local function generateTowMenuItems()
    local menuItems = {}
    local playerCoords = GetEntityCoords(PlayerPedId())
    local currentAttachedVehicle = getAttachedVehicle(towState.towVehicle, towState.towType)

    local hasAttachedVehicle = currentAttachedVehicle and currentAttachedVehicle ~= 0

    if towState.towType == "flatbed" then
        if hasAttachedVehicle then
            local attachedPlate = GetVehicleNumberPlateText(currentAttachedVehicle)
            local attachedModel = GetDisplayNameFromVehicleModel(GetEntityModel(currentAttachedVehicle))

            table.insert(menuItems, {
                label = string.format("%s - %s %s", t("tow_detach"), attachedModel, attachedPlate),
                nuiCallback = "tow:detach",
                callbackData = {}
            })
        else
            towState.candidates = findNearbyTowableVehicles(playerCoords, Config.Towing.radius, towState.towVehicle)

            if #towState.candidates > 0 then
                for i, candidate in ipairs(towState.candidates) do
                    local isOccupied = isVehicleOccupied(candidate.vehicle)
                    local isAttached = IsEntityAttachedToAnyVehicle(candidate.vehicle)
                    local isDisabled = isOccupied or isAttached

                    local label = string.format("%s - %s (%.1fm)", candidate.model, candidate.plate, candidate.distance)
                    if isOccupied then
                        label = label .. " [" .. t("tow_occupied") .. "]"
                    elseif isAttached then
                        label = label .. " [" .. t("tow_attached_label") .. "]"
                    end

                    table.insert(menuItems, {
                        label = label,
                        nuiCallback = "tow:attach",
                        callbackData = {
                            index = i,
                            netId = candidate.netId
                        },
                        disabled = isDisabled
                    })
                end
            else
                table.insert(menuItems, {
                    label = t("tow_no_nearby_vehicles"),
                    disabled = true
                })
            end
        end
    end

    if towState.towType == "towtruck" or towState.towType == "towtruck2" then
        local attachedToTowTruck = GetEntityAttachedToTowTruck(towState.towVehicle)
        if attachedToTowTruck and attachedToTowTruck ~= 0 then
            if DoesEntityExist(attachedToTowTruck) then
                local attachedPlate = GetVehicleNumberPlateText(attachedToTowTruck)
                local attachedModel = GetDisplayNameFromVehicleModel(GetEntityModel(attachedToTowTruck))

                table.insert(menuItems, {
                    label = string.format("%s - %s %s", t("tow_detach"), attachedModel, attachedPlate),
                    nuiCallback = "tow:detach",
                    callbackData = {}
                })
            end
        end

        table.insert(menuItems, {
            label = t("tow_raise_arm") or "Raise Arm",
            nuiCallback = "tow:armUp",
            callbackData = {}
        })

        table.insert(menuItems, {
            label = t("tow_lower_arm") or "Lower Arm",
            nuiCallback = "tow:armDown",
            callbackData = {}
        })
    end

    table.insert(menuItems, {
        label = t("tow_refresh") or "Refresh",
        nuiCallback = "tow:refresh",
        callbackData = {}
    })

    table.insert(menuItems, {
        label = t("close") or "Close",
        nuiCallback = "tow:close",
        callbackData = {}
    })

    return menuItems
end

local function showTowMenu()
    if not towState.active then
        return
    end

    local menuData = generateTowMenuItems()

    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "tow_menu",
            items = menuData
        }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu"
        }
    })
    State.openPage = "menu"
    State.currentMenuId = "tow_menu"
    StartMenuControlsThread()
end

local function hideTowMenu()
    if State.openPage == "menu" then
        if State.currentMenuId == "tow_menu" then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = false,
                    page = "menu"
                }
            })
            State.openPage = nil
            State.currentMenuId = nil
        end
    end
end

local function resetTowState()
    towState.active = false
    towState.towVehicle = nil
    towState.towType = nil
    towState.attachedVehicle = nil
    towState.candidates = {}
    hideTowMenu()
end

local function initiateTowing()
    local playerPed = PlayerPedId()

    if not IsPedInAnyVehicle(playerPed, false) then
        bridge.Notify.SendNotify(t("tow_must_be_in_vehicle"), "error")
        return
    end

    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    if GetPedInVehicleSeat(playerVehicle, -1) ~= playerPed then
        bridge.Notify.SendNotify(t("tow_must_be_driver"), "error")
        return
    end

    local towType = getTowVehicleType(playerVehicle)
    if not towType then
        bridge.Notify.SendNotify(t("tow_not_in_tow_vehicle"), "error")
        return
    end

    local mechanicCheck = bridge.Callback.Trigger("nn_mechanic:isPlayerEmployee")
    local isMechanic = mechanicCheck and mechanicCheck.isEmployee
    if not isMechanic then
        bridge.Notify.SendNotify(t("tow_not_mechanic"), "error")
        return
    end

    if towState.active then
        resetTowState()
        Wait(100)
    end

    towState.active = true
    towState.towVehicle = playerVehicle
    towState.towType = towType

    if towType == "towtruck" or towType == "towtruck2" then
        local attachedVehicle = GetEntityAttachedToTowTruck(playerVehicle)
        if attachedVehicle and attachedVehicle ~= 0 then
            towState.attachedVehicle = attachedVehicle
        end
    end

    bridge.Notify.SendNotify(t("tow_menu_opened"), "inform")
    showTowMenu()

    Citizen.CreateThread(function()
        while true do
            if not towState.active then
                break
            end
            Wait(500)

            if not IsPedInAnyVehicle(PlayerPedId(), false) then
                resetTowState()
                bridge.Notify.SendNotify(t("tow_menu_closed"), "inform")
            end
        end
    end)
end

local function onAttachVehicleNuiCallback(callbackData, cb)
    local index = callbackData.index
    local netId = callbackData.netId

    if not towState.active or not index then
        cb({ success = false })
        return
    end

    local candidateVehicleInfo = towState.candidates[index]
    if not candidateVehicleInfo then
        cb({ success = false })
        return
    end

    local targetVehicleEntity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(targetVehicleEntity) then
        targetVehicleEntity = candidateVehicleInfo.vehicle
    end

    if not DoesEntityExist(targetVehicleEntity) then
        bridge.Notify.SendNotify(t("tow_vehicle_not_found") or "Vehicle not found", "error")
        cb({ success = false })
        return
    end

    if isVehicleOccupied(targetVehicleEntity) then
        bridge.Notify.SendNotify(t("tow_cannot_tow_occupied"), "error")
        cb({ success = false })
        return
    end

    if IsEntityAttachedToAnyVehicle(targetVehicleEntity) then
        bridge.Notify.SendNotify(t("tow_already_attached"), "error")
        cb({ success = false })
        return
    end

    local success = attachVehicle(towState.towVehicle, targetVehicleEntity, towState.towType)
    if success then
        bridge.Notify.SendNotify(t("tow_attached"), "success")
        showTowMenu()
    end

    cb({ success = true })
end
RegisterNUICallback("tow:attach", onAttachVehicleNuiCallback)

local function onDetachVehicleNuiCallback(callbackData, cb)
    if not towState.active then
        cb({ success = false })
        return
    end

    local success = detachVehicle(towState.towVehicle, towState.towType)
    if success then
        bridge.Notify.SendNotify(t("tow_detached"), "success")
        showTowMenu()
    end

    cb({ success = true })
end
RegisterNUICallback("tow:detach", onDetachVehicleNuiCallback)

local function onArmUpNuiCallback(callbackData, cb)
    if not towState.active or not towState.towVehicle then
        cb({ success = false })
        return
    end

    SetVehicleTowTruckArmPosition(towState.towVehicle, 1.0)
    bridge.Notify.SendNotify(t("tow_arm_raised") or "Arm raised", "success")
    cb({ success = true })
end
RegisterNUICallback("tow:armUp", onArmUpNuiCallback)

local function onArmDownNuiCallback(callbackData, cb)
    if not towState.active or not towState.towVehicle then
        cb({ success = false })
        return
    end

    SetVehicleTowTruckArmPosition(towState.towVehicle, 0.0)
    bridge.Notify.SendNotify(t("tow_arm_lowered") or "Arm lowered", "success")
    cb({ success = true })
end
RegisterNUICallback("tow:armDown", onArmDownNuiCallback)

local function onRefreshNuiCallback(callbackData, cb)
    if not towState.active then
        cb({ success = false })
        return
    end

    showTowMenu()
    cb({ success = true })
end
RegisterNUICallback("tow:refresh", onRefreshNuiCallback)

local function onCloseNuiCallback(callbackData, cb)
    resetTowState()
    bridge.Notify.SendNotify(t("tow_menu_closed"), "inform")
    cb({ success = true })
end
RegisterNUICallback("tow:close", onCloseNuiCallback)

RegisterCommand("tow", function()
    if towState.active then
        resetTowState()
        return
    end
    initiateTowing()
end, false)

RegisterKeyMapping("tow", "Tow Vehicle Menu", "keyboard", "F10")