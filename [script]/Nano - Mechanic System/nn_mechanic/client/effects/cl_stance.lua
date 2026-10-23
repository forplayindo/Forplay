local bridgeInstance = bridge
if not bridgeInstance then
    local communityBridgeExports = exports.community_bridge
    bridgeInstance = communityBridgeExports.Bridge(communityBridgeExports)
end
bridge = bridgeInstance

local ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local ANIM_CLIP = "machinic_loop_mechandplayer"

local STANCE_ADJUSTMENT_LIMITS = {
    rideHeight = 0.3,
    wheelOffsetFront = 0.2,
    wheelOffsetRear = 0.2,
    camberFront = 0.4,
    camberRear = 0.4,
    wheelSize = 0.5,
    wheelWidth = 0.3
}

local vehicleStanceCache = {}

local function getClosestVehicle()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    local pedCoords = GetEntityCoords(playerPed)
    vehicle = GetClosestVehicle(pedCoords.x, pedCoords.y, pedCoords.z, 6.0, 0, 70)

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end

    return nil
end

local function checkAndConsumeItem(itemName)
    local hasItem = bridge.Callback.Trigger("nn_mechanic:hasItem", itemName)
    if not hasItem then
        local message = string.format(t("missing_item"), itemName)
        bridge.Notify.SendNotify(message, "error")
        return false
    end

    local itemConsumed = bridge.Callback.Trigger("nn_mechanic:consumeItem", itemName)
    if not itemConsumed then
        bridge.Notify.SendNotify(t("failed_to_remove_item"), "error")
        return false
    end

    return true
end

local function startProgressBar(labelKey, fallbackLabel, duration)
    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do
        Wait(30)
    end

    local playerPed = PlayerPedId()
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)

    local progressBarDuration = duration or 8000
    local label = t(labelKey)
    if not label then
        label = fallbackLabel
    end

    local options = {
        duration = progressBarDuration,
        label = label,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = ANIM_DICT,
            clip = ANIM_CLIP,
            flag = 1
        }
    }

    local success = bridge.ProgressBar.Open(options)
    SetPedCanRagdoll(playerPed, true)
    return success == true
end

local function roundNumber(number, decimalPlaces)
    decimalPlaces = decimalPlaces or 0
    local multiplier = 10 ^ decimalPlaces
    return math.floor(number * multiplier) / multiplier
end

local function canGetVehicleHandlingFloat(vehicle, handlingClass, handlingName)
    local originalValue = GetVehicleHandlingFloat(vehicle, handlingClass, handlingName)
    SetVehicleHandlingFloat(vehicle, handlingClass, handlingName, originalValue + 0.01)
    local newValue = GetVehicleHandlingFloat(vehicle, handlingClass, handlingName)

    if newValue == originalValue then
        return false
    end

    SetVehicleHandlingFloat(vehicle, handlingClass, handlingName, originalValue)
    return true
end

local function getVehicleHandlingFloatSafe(vehicle, handlingClass, handlingName)
    local isModifiable = canGetVehicleHandlingFloat(vehicle, handlingClass, handlingName)
    if not isModifiable then
        return nil
    end
    return GetVehicleHandlingFloat(vehicle, handlingClass, handlingName)
end

local function getVehicleWheelSizeSafe(vehicle)
    local originalSize = GetVehicleWheelSize(vehicle)
    local modIndex = GetVehicleMod(vehicle, 23)

    if modIndex == -1 then
        return nil
    end

    local didSet = SetVehicleWheelSize(vehicle, originalSize + 0.1)
    if not didSet then
        return nil
    end

    SetVehicleWheelSize(vehicle, originalSize)
    return originalSize
end

local function getVehicleWheelWidthSafe(vehicle)
    local originalWidth = GetVehicleWheelWidth(vehicle)
    local modIndex = GetVehicleMod(vehicle, 23)

    if modIndex == -1 then
        return nil
    end

    local didSet = SetVehicleWheelWidth(vehicle, originalWidth + 0.1)
    if not didSet then
        return nil
    end

    SetVehicleWheelWidth(vehicle, originalWidth)
    return originalWidth
end

local function createTempVehicle(sourceVehicle)
    local modelHash = GetEntityModel(sourceVehicle)
    local tempVehicle = CreateVehicle(modelHash, 0, 0, 0, 0, false, false)

    SetEntityVisible(tempVehicle, false, false)
    SetEntityInvincible(tempVehicle, true)
    SetVehicleModKit(tempVehicle, 0)

    local wheelType = GetVehicleWheelType(sourceVehicle)
    SetVehicleWheelType(tempVehicle, wheelType)

    local wheelMod = GetVehicleMod(sourceVehicle, 23)
    local wheelModVariation = GetVehicleModVariation(sourceVehicle, 23)
    SetVehicleMod(tempVehicle, 23, wheelMod, wheelModVariation)

    local tireMod = GetVehicleMod(sourceVehicle, 24)
    local tireModVariation = GetVehicleModVariation(sourceVehicle, 24)
    SetVehicleMod(tempVehicle, 24, tireMod, tireModVariation)

    Wait(1)
    return tempVehicle
end

local function getVehicleStanceValues(vehicle)
    local stanceValues = {}
    stanceValues.rideHeight = GetVehicleSuspensionHeight(vehicle)
    stanceValues.wheelOffsetFront = GetVehicleWheelXOffset(vehicle, 1)
    stanceValues.wheelOffsetRear = GetVehicleWheelXOffset(vehicle, 3)
    stanceValues.camberFront = getVehicleHandlingFloatSafe(vehicle, "CCarHandlingData", "fCamberFront")
    stanceValues.camberRear = getVehicleHandlingFloatSafe(vehicle, "CCarHandlingData", "fCamberRear")
    stanceValues.wheelSize = getVehicleWheelSizeSafe(vehicle)
    stanceValues.wheelWidth = getVehicleWheelWidthSafe(vehicle)
    return stanceValues
end

local function getDefaultVehicleStanceValues(sourceVehicle)
    local tempVehicle = createTempVehicle(sourceVehicle)
    local defaultStanceValues = getVehicleStanceValues(tempVehicle)
    DeleteVehicle(tempVehicle)
    return defaultStanceValues
end

local function applyStanceValuesToVehicle(vehicle, stanceValues)
    if not (vehicle and DoesEntityExist(vehicle)) then
        return
    end

    if stanceValues.rideHeight then
        SetVehicleSuspensionHeight(vehicle, stanceValues.rideHeight)
    end

    if stanceValues.camberFront then
        SetVehicleHandlingFloat(vehicle, "CCarHandlingData", "fCamberFront", stanceValues.camberFront)
    end

    if stanceValues.camberRear then
        SetVehicleHandlingFloat(vehicle, "CCarHandlingData", "fCamberRear", stanceValues.camberRear)
    end

    if stanceValues.wheelSize then
        SetVehicleWheelSize(vehicle, stanceValues.wheelSize)
        for i = 0, 3 do
            local halfWheelSize = stanceValues.wheelSize / 2
            SetVehicleWheelRimColliderSize(vehicle, i, roundNumber(halfWheelSize, 2))
            SetVehicleWheelTireColliderSize(vehicle, i, roundNumber(halfWheelSize, 2))
        end
    end

    if stanceValues.wheelWidth then
        SetVehicleWheelWidth(vehicle, stanceValues.wheelWidth)
    end
end

local function installStanceKit()
    local vehicle = getClosestVehicle()
    if not vehicle then
        bridge.Notify.SendNotify(t("no_vehicle_found"), "error")
        return false
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then
        bridge.Notify.SendNotify(t("no_vehicle_found"), "error")
        return false
    end

    local stanceData = bridge.Callback.Trigger("nn_mechanic:getVehicleStanceData", plate)
    if stanceData and stanceData.enabled then
        bridge.Notify.SendNotify(t("stance_kit_already_installed"), "error")
        return false
    end

    local itemConsumed = checkAndConsumeItem("stance_kit")
    if not itemConsumed then
        return false
    end

    local progressBarSuccess = startProgressBar("installing_stance_kit", t("installing_stance_kit"), 8000)
    if not progressBarSuccess then
        return false
    end

    local newStanceData = {
        enabled = true,
        values = getDefaultVehicleStanceValues(vehicle)
    }

    TriggerServerEvent("nn_mechanic:setVehicleStanceData", plate, json.encode(newStanceData))

    bridge.Notify.SendNotify(t("stance_kit_installed"), "success")
    return true
end
StartInstallStanceKit = installStanceKit

local function handleUseStanceKitEvent()
    if State and State.openPage == "menu" and State.currentMenuId == "stance_kit_menu" then
        return
    end

    local menuItems = {
        {
            label = t("install_stance_kit"),
            icon = "fas fa-car",
            nuiCallback = "installStanceKit"
        }
    }

    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "stance_kit_menu",
            items = menuItems
        }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu"
        }
    })

    if State then
        State.openPage = "menu"
        State.currentMenuId = "stance_kit_menu"
    end

    if StartMenuControlsThread then
        StartMenuControlsThread()
    end
end
RegisterNetEvent("nn_mechanic:useStanceKit", handleUseStanceKitEvent)

local function handleInstallStanceKitNuiCallback(data, cb)
    if State and State.openPage == "menu" and State.currentMenuId == "stance_kit_menu" then
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

    local installSuccess = StartInstallStanceKit()
    cb({success = installSuccess == true})
end
RegisterNUICallback("installStanceKit", handleInstallStanceKitNuiCallback)

local function handleUseStanceControllerEvent()
    local vehicle = getClosestVehicle()
    if not vehicle then
        bridge.Notify.SendNotify(t("no_vehicle_found"), "error")
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then
        bridge.Notify.SendNotify(t("no_vehicle_found"), "error")
        return
    end

    local stanceData = bridge.Callback.Trigger("nn_mechanic:getVehicleStanceData", plate)
    if not stanceData then
        stanceData = {}
    end

    if not Config.Debug then
        if not (stanceData and stanceData.enabled) then
            bridge.Notify.SendNotify(t("stance_kit_not_installed"), "error")
            return
        end
    end

    local modelHash = GetEntityModel(vehicle)
    local vehicleDisplayName = GetDisplayNameFromVehicleModel(modelHash)
    if vehicleDisplayName then
        vehicleDisplayName = GetLabelText(vehicleDisplayName)
        if vehicleDisplayName == "NULL" then
            vehicleDisplayName = "VEHICLE"
        end
    else
        vehicleDisplayName = "VEHICLE"
    end

    local defaultStanceValues = getDefaultVehicleStanceValues(vehicle)
    local currentStanceValues = getVehicleStanceValues(vehicle)
    local effectiveStanceValues = stanceData.values or currentStanceValues

    State.stanceVehicle = vehicle
    State.stancePlate = plate
    State.stanceDefaults = defaultStanceValues
    State.openPage = "stance-control"

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "stance-control"
        }
    })
    SendNUIMessage({
        action = "stanceControlInit",
        data = {
            vehicleName = vehicleDisplayName,
            values = effectiveStanceValues,
            defaultValues = defaultStanceValues,
            adjustments = STANCE_ADJUSTMENT_LIMITS
        }
    })
    SetNuiFocus(true, true)
end
RegisterNetEvent("nn_mechanic:useStanceController", handleUseStanceControllerEvent)

local function handleStanceControlPreviewNuiCallback(data, cb)
    local currentVehicle = State.stanceVehicle
    if not (currentVehicle and DoesEntityExist(currentVehicle)) then
        cb({success = false})
        return
    end

    applyStanceValuesToVehicle(data.vehicle, data.values)
    cb({success = true})
end
RegisterNUICallback("stanceControlPreview", handleStanceControlPreviewNuiCallback)

local function handleStanceControlConfirmNuiCallback(data, cb)
    local vehiclePlate = State.stancePlate
    if not vehiclePlate then
        cb({success = false})
        return
    end

    local stanceDataToSend = {
        enabled = true,
        values = data.values
    }

    TriggerServerEvent("nn_mechanic:setVehicleStanceData", vehiclePlate, json.encode(stanceDataToSend))

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "stance-control"
        }
    })
    SetNuiFocus(false, false)

    State.openPage = nil
    State.stanceVehicle = nil
    State.stancePlate = nil
    State.stanceDefaults = nil

    bridge.Notify.SendNotify(t("stance_kit_installed"), "success")
    cb({success = true})
end
RegisterNUICallback("stanceControlConfirm", handleStanceControlConfirmNuiCallback)

local function onStanceControlClose_internal()
    local vehicle = State.stanceVehicle
    local plate = State.stancePlate

    if vehicle and DoesEntityExist(vehicle) and plate then
        local stanceData = bridge.Callback.Trigger("nn_mechanic:getVehicleStanceData", plate)
        if stanceData and stanceData.values then
            applyStanceValuesToVehicle(vehicle, stanceData.values)
        end
    end

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "stance-control"
        }
    })
    SetNuiFocus(false, false)

    State.openPage = nil
    State.stanceVehicle = nil
    State.stancePlate = nil
    State.stanceDefaults = nil
end
onStanceControlClose = onStanceControlClose_internal

local function handleStanceControlCloseNuiCallback(data, cb)
    onStanceControlClose()
    cb({success = true})
end
RegisterNUICallback("stanceControlClose", handleStanceControlCloseNuiCallback)

Citizen.CreateThread(function()
    while Config.Stance.enabled do
        for vehicleHandle, stanceData in pairs(vehicleStanceCache) do
            if State and State.stanceVehicle == vehicleHandle then
            else
                if DoesEntityExist(vehicleHandle) then
                    applyStanceValuesToVehicle(vehicleHandle, stanceData)
                else
                    vehicleStanceCache[vehicleHandle] = nil
                end
            end
        end
        Wait(10)
    end
end)

local function handleStateBagChange(stateBagName, key, newValue)
    dprint("state bag change handler for vehicle_stance")
    local vehicle = GetEntityFromStateBagName(stateBagName)

    if not (vehicle ~= 0 and DoesEntityExist(vehicle)) then
        return
    end

    while not HasCollisionLoadedAroundEntity(vehicle) do
        if not DoesEntityExist(vehicle) then
            return
        end
        Wait(100)
    end

    if newValue then
        vehicleStanceCache[vehicle] = newValue
    else
        vehicleStanceCache[vehicle] = nil
    end
end
AddStateBagChangeHandler("nn_vehicle_stance", nil, handleStateBagChange)

local function handleGameEventTriggered(eventName, eventData)
    if eventName == "CEventNetworkPlayerEnteredVehicle" then
        local pedId = eventData[1]
        local localPlayerId = PlayerId()

        if pedId == localPlayerId then
            local vehicle = eventData[2]
            if vehicle and DoesEntityExist(vehicle) then
                NetworkRegisterEntityAsNetworked(vehicle)
                local networkId = NetworkGetNetworkIdFromEntity(vehicle)

                if networkId ~= 0 then
                    SetNetworkIdCanMigrate(networkId, true)
                    Wait(100)

                    local plate = GetVehicleNumberPlateText(vehicle)
                    if plate then
                        TriggerServerEvent("nn_mechanic:initializeVehicleStanceStateBag", networkId, plate)
                    end
                end
            end
        end
    end
end
AddEventHandler("gameEventTriggered", handleGameEventTriggered)