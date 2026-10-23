local currentVehicleEntity = nil
local originalHandlingValues = {}

local function getEngineSwapConfig()
    local engines = {}
    if Config.EngineSwap and Config.EngineSwap.engines then
        for key, value in pairs(Config.EngineSwap.engines) do
            engines[key] = value
        end
    end
    return engines
end

local function openEngineEditorPage()
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "engine_editor"
        }
    })

    SendNUIMessage({
        action = "setEngineEditorData",
        data = {
            engines = getEngineSwapConfig()
        }
    })

    local playerPed = PlayerPedId()
    local vehicleInPed = GetVehiclePedIsIn(playerPed, false)
    if vehicleInPed ~= 0 then
        currentVehicleEntity = vehicleInPed
    end

    local isVehicleSpawned = currentVehicleEntity ~= nil and DoesEntityExist(currentVehicleEntity)
    if not isVehicleSpawned then
        currentVehicleEntity = nil
        originalHandlingValues = {}
    end

    SendNUIMessage({
        action = "engineEditorVehicleStatus",
        data = {
            spawned = isVehicleSpawned
        }
    })

    SetNuiFocus(true, true)
    State.openPage = "engine_editor"
end

OpenEngineEditor = openEngineEditorPage

local function handleCloseEngineEditor(data, cb)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = nil
        }
    })
    SetNuiFocus(false, false)
    State.openPage = nil
    cb("ok")
end
RegisterNUICallback("closeEngineEditor", handleCloseEngineEditor)

local function handleSpawnVehicle(data, cb)
    local model = data.model
    if not model or model == "" then
        cb({ success = false })
        return
    end

    local modelHash = joaat(model)
    if not IsModelValid(modelHash) then
        cb({ success = false })
        return
    end

    if currentVehicleEntity and DoesEntityExist(currentVehicleEntity) then
        DeleteEntity(currentVehicleEntity)
        currentVehicleEntity = nil
    end

    RequestModel(modelHash)
    local waitCount = 0
    while not HasModelLoaded(modelHash) and waitCount < 50 do
        Wait(100)
        waitCount = waitCount + 1
    end

    if not HasModelLoaded(modelHash) then
        cb({ success = false })
        return
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local newVehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    currentVehicleEntity = newVehicle

    SetModelAsNoLongerNeeded(modelHash)

    if currentVehicleEntity and DoesEntityExist(currentVehicleEntity) then
        SetVehicleOnGroundProperly(currentVehicleEntity)
        local plate = GetVehicleNumberPlateText(currentVehicleEntity)
        bridge.VehicleKey.GiveKeys(currentVehicleEntity, plate)
        TaskWarpPedIntoVehicle(playerPed, currentVehicleEntity, -1)
        originalHandlingValues = {}
        SendNUIMessage({
            action = "engineEditorVehicleStatus",
            data = {
                spawned = true
            }
        })
        cb({ success = true })
    else
        cb({ success = false })
    end
end
RegisterNUICallback("engineEditorSpawnVehicle", handleSpawnVehicle)

local function handleDeleteVehicle(data, cb)
    if currentVehicleEntity and DoesEntityExist(currentVehicleEntity) then
        DeleteEntity(currentVehicleEntity)
    end
    currentVehicleEntity = nil
    originalHandlingValues = {}
    SendNUIMessage({
        action = "engineEditorVehicleStatus",
        data = {
            spawned = false
        }
    })
    cb("ok")
end
RegisterNUICallback("engineEditorDeleteVehicle", handleDeleteVehicle)

local function handleApplyHandling(data, cb)
    if not (currentVehicleEntity and DoesEntityExist(currentVehicleEntity)) then
        cb({ success = false })
        return
    end

    local mode = data.mode or "set"
    local values = data.values or {}

    for handlingKey, handlingValue in pairs(values) do
        if type(handlingValue) == "number" and type(handlingKey) == "string" then
            if not originalHandlingValues[handlingKey] then
                originalHandlingValues[handlingKey] = GetVehicleHandlingFloat(currentVehicleEntity, "CHandlingData", handlingKey)
            end

            local finalValue = handlingValue
            if mode == "difference" then
                finalValue = GetVehicleHandlingFloat(currentVehicleEntity, "CHandlingData", handlingKey) + handlingValue
            end
            SetVehicleHandlingFloat(currentVehicleEntity, "CHandlingData", handlingKey, finalValue + 0.0)
        end
    end

    ModifyVehicleTopSpeed(currentVehicleEntity, 1.0)
    SetVehicleEnginePowerMultiplier(currentVehicleEntity, 0.0)

    cb({ success = true })
end
RegisterNUICallback("engineEditorApplyHandling", handleApplyHandling)

local function handleApplySound(data, cb)
    if not (currentVehicleEntity and DoesEntityExist(currentVehicleEntity)) then
        cb({ success = false })
        return
    end

    local preset = data.preset
    if preset and type(preset) == "string" and preset ~= "" then
        ForceUseAudioGameObject(currentVehicleEntity, preset)
    end

    cb({ success = true })
end
RegisterNUICallback("engineEditorApplySound", handleApplySound)

local function handleResetHandling(data, cb)
    if not (currentVehicleEntity and DoesEntityExist(currentVehicleEntity)) then
        cb({ success = false })
        return
    end

    for handlingKey, originalValue in pairs(originalHandlingValues) do
        if originalValue then
            SetVehicleHandlingFloat(currentVehicleEntity, "CHandlingData", handlingKey, originalValue + 0.0)
        end
    end
    originalHandlingValues = {}

    ModifyVehicleTopSpeed(currentVehicleEntity, 1.0)
    SetVehicleEnginePowerMultiplier(currentVehicleEntity, 0.0)

    cb({ success = true })
end
RegisterNUICallback("engineEditorResetHandling", handleResetHandling)

RegisterCommand("engine_editor", function()
    local isAdmin = bridge.Callback.Trigger("nn_mechanic:checkIsAdmin")
    if not isAdmin then
        bridge.Notify.SendNotify(t("not_authorized"), "error")
        return
    end
    OpenEngineEditor()
end, false)