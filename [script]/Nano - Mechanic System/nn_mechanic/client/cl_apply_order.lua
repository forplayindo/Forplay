local function debugPrint(message)
    print(string.format("^3[apply-order]^7 %s", tostring(message)))
end

local function clampColorComponent(value)
    local numValue = tonumber(value)
    if numValue == nil then
        value = 0
    else
        value = numValue
    end

    if value < 0 then
        return 0
    end

    if value > 255 then
        return 255
    end

    return math.floor(value)
end

local function parseRgbColor(colorData)
    if type(colorData) ~= "table" then
        return {r = 255, g = 255, b = 255}
    end

    local r = colorData.r or colorData[1] or 255
    local g = colorData.g or colorData[2] or 255
    local b = colorData.b or colorData[3] or 255

    local parsedColor = {}
    parsedColor.r = clampColorComponent(r)
    parsedColor.g = clampColorComponent(g)
    parsedColor.b = clampColorComponent(b)

    return parsedColor
end

local function requestVehicleControl(entityId, timeoutMs)
    if not (entityId and entityId ~= 0 and DoesEntityExist(entityId)) then
        return false
    end

    if not NetworkGetEntityIsNetworked(entityId) then
        return true
    end

    local timeout = timeoutMs or 4000
    local endTime = GetGameTimer() + timeout

    NetworkRequestControlOfEntity(entityId)

    while true do
        if NetworkHasControlOfEntity(entityId) then
            break
        end

        if GetGameTimer() > endTime then
            break
        end

        NetworkRequestControlOfEntity(entityId)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entityId)
end

local function applyRespray(vehicle, resprayData)
    if not resprayData then
        return false
    end

    SetVehicleModKit(vehicle, 0)

    local currentPearlescentColorIndex = select(1, GetVehicleExtraColours(vehicle))

    local primaryPaintType = tonumber(resprayData.primaryPaintType) or 0
    local secondaryPaintType = tonumber(resprayData.secondaryPaintType) or 0
    local mode = resprayData.mode or "stock"

    if mode == "stock" then
        ClearVehicleCustomPrimaryColour(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)

        local primaryColorIndex = tonumber(resprayData.primaryColorIndex) or 0
        local secondaryColorIndex = tonumber(resprayData.secondaryColorIndex) or 0

        SetVehicleModColor_1(vehicle, primaryPaintType, primaryColorIndex, currentPearlescentColorIndex or 0)
        SetVehicleModColor_2(vehicle, secondaryPaintType, secondaryColorIndex)
    else
        local primaryCustomColor = resprayData.primary or {}
        local secondaryCustomColor = resprayData.secondary or {}

        SetVehicleModColor_1(vehicle, primaryPaintType, 0, currentPearlescentColorIndex or 0)
        SetVehicleCustomPrimaryColour(
            vehicle,
            tonumber(primaryCustomColor[1]) or 0,
            tonumber(primaryCustomColor[2]) or 0,
            tonumber(primaryCustomColor[3]) or 0
        )

        SetVehicleModColor_2(vehicle, secondaryPaintType, 0)
        SetVehicleCustomSecondaryColour(
            vehicle,
            tonumber(secondaryCustomColor[1]) or 0,
            tonumber(secondaryCustomColor[2]) or 0,
            tonumber(secondaryCustomColor[3]) or 0
        )
    end
    return true
end

local function applyExtraColors(vehicle, extraColorsData)
    if not extraColorsData then
        return true
    end

    SetVehicleModKit(vehicle, 0)

    local currentPearlescentColorIndex, currentWheelColorIndex = GetVehicleExtraColours(vehicle)

    local newPearlescentColorIndex = tonumber(extraColorsData.pearlescentColorIndex)
    local newWheelColorIndex = tonumber(extraColorsData.wheelColorIndex)

    if newPearlescentColorIndex ~= nil or newWheelColorIndex ~= nil then
        SetVehicleExtraColours(
            vehicle,
            newPearlescentColorIndex or currentPearlescentColorIndex,
            newWheelColorIndex or currentWheelColorIndex
        )
    end

    if extraColorsData.tyreSmokeRgb then
        local tyreSmokeRgb = parseRgbColor(extraColorsData.tyreSmokeRgb)
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(vehicle, tyreSmokeRgb.r, tyreSmokeRgb.g, tyreSmokeRgb.b)
    end

    return true
end

local function applyNeonLights(vehicle, neonLightsData)
    if not neonLightsData then
        return false
    end

    SetVehicleModKit(vehicle, 0)

    if neonLightsData.action == "remove" then
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, false)
        end
        DisableVehicleNeonLights(vehicle, true)
        return true
    end

    local colorRgb = parseRgbColor(neonLightsData.rgb or neonLightsData)

    DisableVehicleNeonLights(vehicle, false)

    for i = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, i, true)
    end
    SetVehicleNeonLightsColour(vehicle, colorRgb.r, colorRgb.g, colorRgb.b)

    return true
end

local function applyXenonLights(vehicle, xenonLightsData)
    if not xenonLightsData then
        return false
    end

    SetVehicleModKit(vehicle, 0)

    if xenonLightsData.action == "remove" then
        ToggleVehicleMod(vehicle, 22, false)
        ClearVehicleXenonLightsCustomColor(vehicle)
        return true
    end

    local colorRgb = parseRgbColor(xenonLightsData.rgb or xenonLightsData)

    ToggleVehicleMod(vehicle, 22, true)
    SetVehicleXenonLightsCustomColor(vehicle, colorRgb.r, colorRgb.g, colorRgb.b)

    return true
end

local function handleVehicleModService(vehicle, modData)
    if type(modData) ~= "table" then
        return false
    end

    SetVehicleModKit(vehicle, 0)

    local serviceType = modData.serviceType

    if serviceType == "respray" then
        if modData.respray then
            return applyRespray(vehicle, modData.respray)
        end
    elseif serviceType == "extra_colours" then
        if modData.extraColours then
            return applyExtraColors(vehicle, modData.extraColours)
        end
    elseif serviceType == "neon_lights" then
        if modData.neonLights then
            return applyNeonLights(vehicle, modData.neonLights)
        end
    elseif serviceType == "xenon_lights" then
        if modData.xenonLights then
            return applyXenonLights(vehicle, modData.xenonLights)
        end
    end

    local modId = tonumber(modData.modId)
    local modIndex = modData.modIndex
    if modIndex ~= nil then
        modIndex = tonumber(modIndex)
    end

    if serviceType == "engine" or modId == 11 then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        local customEngineId = modData.customEngineId

        if customEngineId then
            if type(customEngineId) == "string" then
                if Config and Config.EngineSwap and Config.EngineSwap.engines and Config.EngineSwap.engines[customEngineId] then
                    local engineModCount = GetNumVehicleMods(vehicle, 11) - 1
                    local engineModIndex = (engineModCount >= 0 and engineModCount) or -1
                    SetVehicleMod(vehicle, 11, engineModIndex, false)
                    TriggerServerEvent("nn_mechanic:setCustomEngine", netId, customEngineId)
                end
            end
        else
            TriggerServerEvent("nn_mechanic:clearCustomEngine", netId)
            if modIndex ~= nil then
                SetVehicleMod(vehicle, 11, modIndex, false)
            end
        end
        return true
    end

    if modId == nil then
        debugPrint("skipped line (no modId / unknown serviceType)")
        return false
    end

    if modId == 18 then
        ToggleVehicleMod(vehicle, 18, true)
        return true
    end

    if modId == 23 then
        local wheelTypeId = tonumber(modData.wheelId)
        if wheelTypeId then
            SetVehicleWheelType(vehicle, wheelTypeId)
        end
        if modIndex ~= nil then
            SetVehicleMod(vehicle, 23, modIndex, false)
            SetVehicleMod(vehicle, 24, modIndex, false)
        end
        return modIndex ~= nil
    end

    if modId == 48 then
        if modData.liveryOldMethod then
            SetVehicleLivery(vehicle, modIndex or 0)
        else
            SetVehicleMod(vehicle, 48, modIndex or -1, false)
        end
        return true
    end

    if modId == 50 then
        SetVehicleNumberPlateTextIndex(vehicle, modIndex or 0)
        return true
    end

    if modId == 51 then
        SetVehicleWindowTint(vehicle, modIndex or 0)
        return true
    end

    if modIndex ~= nil then
        SetVehicleMod(vehicle, modId, modIndex, false)
        return true
    end

    debugPrint(string.format("skipped modId=%s (missing modIndex)", tostring(modId)))
    return false
end

if Config.Debug then
    local function applyOrderCommand(source, args)
        local orderNumber = args and args[1] or ""

        if not orderNumber or orderNumber == "" then
            debugPrint("usage: /apply-order <order_number>   e.g. ORD-000001")
            return
        end

        orderNumber = tostring(orderNumber):gsub("^%s+", ""):gsub("%s+$", "")

        local orderData = bridge.Callback.Trigger("nn_mechanic:getOrderByNumber", orderNumber)

        if not orderData then
            local notificationMessage = t("order_not_found") or "Order not found"
            bridge.Notify.SendNotify(notificationMessage, "error")
            debugPrint(string.format("no order: %s", orderNumber))
            return
        end

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local closestVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 8.0, 0, 71)

        if not (closestVehicle and closestVehicle ~= 0 and DoesEntityExist(closestVehicle)) then
            local notificationMessage = t("no_vehicle_found") or "No vehicle nearby"
            bridge.Notify.SendNotify(notificationMessage, "error")
            return
        end

        if not requestVehicleControl(closestVehicle) then
            bridge.Notify.SendNotify("Could not take control of vehicle (network)", "error")
            return
        end

        local parts = orderData.parts
        if not (type(parts) == "table" and #parts > 0) then
            bridge.Notify.SendNotify("Order has no parts", "error")
            return
        end

        local appliedPartsCount = 0
        for i = 1, #parts do
            local success = handleVehicleModService(closestVehicle, parts[i])
            if success then
                appliedPartsCount = appliedPartsCount + 1
            end
        end

        local vehicleProps = getVehicleProperties(closestVehicle)
        if vehicleProps then
            TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
        end

        TriggerServerEvent("nn_mechanic:debugMarkOrderApplied", orderNumber)

        bridge.Notify.SendNotify(
            string.format("Order %s: applied %d/%d parts, props saved", orderNumber, appliedPartsCount, #parts),
            "success"
        )
        debugPrint(string.format("done %s parts %d/%d vehicle %s", orderNumber, appliedPartsCount, #parts, tostring(closestVehicle)))
    end

    RegisterCommand("apply-order", applyOrderCommand, false)
end