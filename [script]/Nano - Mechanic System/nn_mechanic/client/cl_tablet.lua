local isTabletActive
local tabletAnimDict
local tabletAnimName
local tabletPropHash
local tabletBoneId
local tabletPropOffsetPos
local tabletPropOffsetRot

local is_nan
local deep_copy

-- Initial variable assignments
isTabletActive = false
tabletAnimDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
tabletAnimName = "base"
tabletPropHash = -1585232418
tabletBoneId = 60309
tabletPropOffsetPos = vector3(0.03, 0.002, 0.0)
tabletPropOffsetRot = vector3(10.0, 160.0, 0.0)

-- Function to check for NaN values
function is_nan(value)
    local valueType = type(value)
    return valueType == "number" and value ~= value
end

-- Function for deep copying tables, handling circular references (by returning nil) and specific number types
function deep_copy(original, seen)
    local originalType = type(original)

    if originalType == "number" then
        if is_nan(original) or original == math.huge or original == -math.huge then
            return nil
        end
        return original
    end

    if originalType ~= "table" then
        return original
    end

    seen = seen or {}

    if seen[original] then
        return nil
    end

    seen[original] = true
    local newTable = {}
    for key, value in pairs(original) do
        local copiedValue = deep_copy(value, seen)
        if copiedValue ~= nil then
            newTable[key] = copiedValue
        end
    end
    seen[original] = nil
    return newTable
end

-- Forward declaration for ToggleTablet_internal, as openTabletHandler calls it
local ToggleTablet_internal

-- Defines the ToggleTablet_internal function (originally the final L9_1 function)
function ToggleTablet_internal(show)
    if show then
        if not isTabletActive then
            isTabletActive = true
            Citizen.CreateThread(function()
                RequestAnimDict(tabletAnimDict)
                while not HasAnimDictLoaded(tabletAnimDict) do
                    Citizen.Wait(150)
                end

                RequestModel(tabletPropHash)
                while not HasModelLoaded(tabletPropHash) do
                    Citizen.Wait(150)
                end

                local playerPed = PlayerPedId()
                local tabletProp = CreateObject(tabletPropHash, 0.0, 0.0, 0.0, true, true, false)
                local boneIndex = GetPedBoneIndex(playerPed, tabletBoneId)

                SetCurrentPedWeapon(playerPed, -1569615261, true)

                AttachEntityToEntity(
                    tabletProp,
                    playerPed,
                    boneIndex,
                    tabletPropOffsetPos.x, tabletPropOffsetPos.y, tabletPropOffsetPos.z,
                    tabletPropOffsetRot.x, tabletPropOffsetRot.y, tabletPropOffsetRot.z,
                    true, false, false, false, 2, true
                )

                SetModelAsNoLongerNeeded(tabletPropHash)

                while isTabletActive do
                    Citizen.Wait(100)
                    playerPed = PlayerPedId()
                    if not IsEntityPlayingAnim(playerPed, tabletAnimDict, tabletAnimName, 3) then
                        TaskPlayAnim(
                            playerPed,
                            tabletAnimDict,
                            tabletAnimName,
                            3.0, 3.0, -1, 49, 0, 0, 0, 0
                        )
                    end
                end

                DetachEntity(tabletProp, true, false)
                DeleteEntity(tabletProp)
                ClearPedSecondaryTask(playerPed)
            end)
        end
    elseif not show then
        if isTabletActive then
            isTabletActive = false
        end
    end
end

-- Event handler for refreshing orders
local function refreshOrdersHandler()
    if not State or State.openPage ~= "tablet" then
        return
    end

    if not State.shop or not State.shop.id then
        return
    end

    local shopId = State.shop.id
    local ordersData = bridge.Callback.Trigger("nn_mechanic:getShopOrders", shopId)

    local copiedOrders = deep_copy(ordersData)
    local ordersToSend = copiedOrders or ordersData

    if not copiedOrders then
        ordersToSend = {}
    end

    SendNUIMessage({
        action = "setOrders",
        data = ordersToSend
    })
end
RegisterNetEvent("nn_mechanic:refreshOrders", refreshOrdersHandler)

-- Event handler for opening the tablet
local function openTabletHandler()
    if not State or not State.shop or not State.shop.id then
        bridge.Notify.SendNotify(t("not_an_employee"), "error")
        return
    end

    local shopId = State.shop.id
    local ordersData = bridge.Callback.Trigger("nn_mechanic:getShopOrders", shopId)

    local copiedOrders = deep_copy(ordersData)
    local ordersToSend = copiedOrders or ordersData

    if not copiedOrders then
        ordersToSend = {}
    end

    ToggleTablet_internal(true)
    Wait(300)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setOrders",
        data = ordersToSend
    })
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "tablet" }
    })
    DisplayRadar(false)
    State.openPage = "tablet"
    TriggerScreenblurFadeIn(500)
end
RegisterNetEvent("nn_mechanic:openTablet", openTabletHandler)

-- NUI Callback for finishing an order
local function finishOrderCallback(data, cb)
    if not data or not data.orderId then
        cb({ success = false })
        return
    end
    TriggerServerEvent("nn_mechanic:updateOrderStatus", data.orderId, "completed")
    cb({ success = true })
end
RegisterNUICallback("finishOrder", finishOrderCallback)

-- NUI Callback for starting an order
local function startOrderCallback(data, cb)
    if not data or not data.orderId then
        cb({ success = false })
        return
    end
    TriggerServerEvent("nn_mechanic:startOrder", data.orderId)
    cb({ success = true })
end
RegisterNUICallback("startOrder", startOrderCallback)

-- NUI Callback for cancelling an order
local function cancelOrderCallback(data, cb)
    if not data or not data.orderId then
        cb({ success = false })
        return
    end
    TriggerServerEvent("nn_mechanic:cancelOrder", data.orderId)
    cb({ success = true })
end
RegisterNUICallback("cancelOrder", cancelOrderCallback)

-- NUI Callback for billing a customer
local function billCustomerCallback(data, cb)
    if not data or not data.orderId then
        cb({ success = false })
        return
    end
    TriggerServerEvent("nn_mechanic:sendInvoice", data.orderId)
    cb({ success = true })
end
RegisterNUICallback("billCustomer", billCustomerCallback)

-- NUI Callback for performing an installation
local function performInstallCallback(data, cb)
    local orderId = data.orderId
    local partIndex = data.partIndex

    if not orderId or partIndex == nil then
        cb({ success = false })
        return
    end

    local order = bridge.Callback.Trigger("nn_mechanic:getOrderById", orderId)

    if not order then
        bridge.Notify.SendNotify(t("order_not_found"), "error")
        cb({ success = false })
        return
    end

    local part = order.parts and order.parts[partIndex + 1]

    if not part then
        cb({ success = false })
        return
    end

    ToggleTablet_internal(false)
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(500)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "tablet" }
    })
    State.openPage = nil

    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0, 0, 71)

        local installSuccess = false

        if part.serviceType == "engine" or part.modId == 11 then
            local p = promise.new()
            startEngineSwap(part.referenceNumber, function(result)
                p.resolve(result)
            end)
            installSuccess = Citizen.Await(p)
        elseif part.modId == 23 then
            local p = promise.new()
            startWheelSwap(closestVehicle, part, function(result)
                p.resolve(result)
            end)
            installSuccess = Citizen.Await(p)
        elseif part.modId == 4 then
            local p = promise.new()
            ChangeExhaust(part.referenceNumber, function(result)
                p.resolve(result)
            end)
            installSuccess = Citizen.Await(p)
        elseif part.modId == 7 then
            local p = promise.new()
            startHoodSwap(part.referenceNumber, function(result)
                p.resolve(result)
            end)
            installSuccess = Citizen.Await(p)
        elseif part.modId == 48 then
            local p = promise.new()
            StartLiveryInstall(closestVehicle, {
                referenceNumber = part.referenceNumber,
                modIndex = part.modIndex,
                liveryOldMethod = part.liveryOldMethod
            }, function(result)
                p.resolve(result)
            end)
            installSuccess = Citizen.Await(p)
        elseif part.modId then
            installSuccess = StartChange(closestVehicle, part.modId, part.modIndex)
        elseif part.serviceType == "respray" then
            local resprayData = part.respray
            if not resprayData then
                bridge.Notify.SendNotify(t("invalid_respray_data"), "error")
                installSuccess = false
            else
                local resprayMatch = CheckResprayMatch(closestVehicle, resprayData)
                if resprayMatch.primary and resprayMatch.secondary then
                    local message = t("respray_already_applied")
                    if not message then
                        message = "Vehicle already has this color. Marked complete."
                    end
                    bridge.Notify.SendNotify(message, "success")
                    installSuccess = true
                else
                    local p = promise.new()
                    InitResprayOrder(
                        closestVehicle,
                        resprayData,
                        orderId,
                        partIndex,
                        function(result)
                            p.resolve(result)
                        end,
                        {
                            primary = resprayMatch.primary,
                            secondary = resprayMatch.secondary
                        }
                    )
                    TriggerEvent("nn_mechanic:closeTablet")
                    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "tablet" } })
                    SetNuiFocus(false, false)
                    TriggerScreenblurFadeOut(500)
                    State.openPage = nil
                    installSuccess = Citizen.Await(p)
                end
            end
        elseif part.serviceType == "neon_lights" then
            local neonData = part.neonLights
            if not neonData or neonData.action ~= "install" then
                bridge.Notify.SendNotify(t("invalid_neon_data"), "error")
                installSuccess = false
            else
                local rgbColorData = neonData.rgb
                if not rgbColorData then
                    bridge.Notify.SendNotify(t("missing_color_data"), "error")
                    installSuccess = false
                else
                    local processedRgbColor = {}
                    local colorType = type(rgbColorData)
                    if colorType == "table" then
                        if rgbColorData.r then
                            processedRgbColor.r = rgbColorData.r
                            processedRgbColor.g = rgbColorData.g or 255
                            processedRgbColor.b = rgbColorData.b or 255
                        elseif rgbColorData[1] then
                            processedRgbColor.r = rgbColorData[1]
                            processedRgbColor.g = rgbColorData[2] or 255
                            processedRgbColor.b = rgbColorData[3] or 255
                        else
                            processedRgbColor.r = 255
                            processedRgbColor.g = 255
                            processedRgbColor.b = 255
                        end
                    else
                        processedRgbColor.r = 255
                        processedRgbColor.g = 255
                        processedRgbColor.b = 255
                    end

                    local p = promise.new()
                    ShowLightsInstallConfirmationMenu("neon", processedRgbColor, function(result)
                        p.resolve(result)
                    end)
                    installSuccess = Citizen.Await(p)
                end
            end
        elseif part.serviceType == "extra_colours" then
            local extraColoursData = part.extraColours
            if not extraColoursData then
                local message = t("invalid_extra_colours_data")
                if not message then
                    message = "Invalid extra colours data"
                end
                bridge.Notify.SendNotify(message, "error")
                installSuccess = false
            else
                local p = promise.new()
                StartInstallExtraColours(extraColoursData, function(result)
                    p.resolve(result)
                end)
                installSuccess = Citizen.Await(p)
            end
        elseif part.serviceType == "xenon_lights" then
            local xenonData = part.xenonLights
            if not xenonData or xenonData.action ~= "install" then
                bridge.Notify.SendNotify(t("invalid_xenon_data"), "error")
                installSuccess = false
            else
                local rgbColorData = xenonData.rgb
                if not rgbColorData then
                    bridge.Notify.SendNotify(t("missing_color_data"), "error")
                    installSuccess = false
                else
                    local processedRgbColor = {}
                    local colorType = type(rgbColorData)
                    if colorType == "table" then
                        if rgbColorData.r then
                            processedRgbColor.r = rgbColorData.r
                            processedRgbColor.g = rgbColorData.g or 255
                            processedRgbColor.b = rgbColorData.b or 255
                        elseif rgbColorData[1] then
                            processedRgbColor.r = rgbColorData[1]
                            processedRgbColor.g = rgbColorData[2] or 255
                            processedRgbColor.b = rgbColorData[3] or 255
                        else
                            processedRgbColor.r = 255
                            processedRgbColor.g = 255
                            processedRgbColor.b = 255
                        end
                    else
                        processedRgbColor.r = 255
                        processedRgbColor.g = 255
                        processedRgbColor.b = 255
                    end

                    local p = promise.new()
                    ShowLightsInstallConfirmationMenu("xenon", processedRgbColor, function(result)
                        p.resolve(result)
                    end)
                    installSuccess = Citizen.Await(p)
                end
            end
        else
            bridge.Notify.SendNotify("Unknown part type", "error")
            installSuccess = false
        end

        if installSuccess then
            bridge.Callback.Trigger("nn_mechanic:updateOrderPartStatusSync", orderId, partIndex, true)
            TriggerEvent("nn_mechanic:openTablet")
            cb({ success = true })
        else
            TriggerEvent("nn_mechanic:openTablet")
            cb({ success = false })
        end
    end)
end
RegisterNUICallback("performInstall", performInstallCallback)

-- Expose ToggleTablet_internal globally as ToggleTablet
ToggleTablet = ToggleTablet_internal