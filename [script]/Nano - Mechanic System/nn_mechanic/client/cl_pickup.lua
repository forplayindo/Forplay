local PickupModule = {}
PickupModule.activeRoute = nil
PickupModule.warehousePeds = {}
PickupModule.warehouseBlips = {}
PickupModule.warehousePedNetIds = {}
PickupModule.currentSupplierCode = nil
PickupModule.activeInstructions = nil
PickupModule.instructionStepCompleted = {
    navigate = false,
    collect = false
}

function GetWarehouseLocation(supplierCode)
    local warehouseLocations = Config.WarehouseLocations
    if warehouseLocations and warehouseLocations[supplierCode] then
        return warehouseLocations[supplierCode]
    end
    return nil
end

function StartPickupRoute(supplierCode, orderNumber)
    local warehouseLocation = GetWarehouseLocation(supplierCode)
    if not warehouseLocation then
        bridge.Notify.SendNotify(t("warehouse_location_not_found"), "error")
        return false
    end

    if PickupModule.activeRoute then
        ClearGpsMultiRoute()
    end

    local blipCoords = warehouseLocation.coords
    local blip = AddBlipForCoord(blipCoords.x, blipCoords.y, blipCoords.z)
    SetBlipSprite(blip, 280)
    local blipColor = warehouseLocation.blipColor or 1
    SetBlipColour(blip, blipColor)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName("STRING")
    local supplierName = OrderHelpers.GetSupplierNameFromCode(supplierCode)
    if not supplierName then
        supplierName = supplierCode
    end
    AddTextComponentSubstringPlayerName(supplierName .. " " .. t("warehouse"))
    EndTextCommandSetBlipName(blip)

    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, blipColor)

    PickupModule.activeRoute = {
        supplierCode = supplierCode,
        orderNumber = orderNumber,
        blip = blip,
        coords = warehouseLocation.coords
    }
    PickupModule.currentSupplierCode = supplierCode
    PickupModule.instructionStepCompleted = {
        navigate = false,
        collect = false
    }

    local warehousePed = TryGetWarehousePed(supplierCode)
    if warehousePed and DoesEntityExist(warehousePed) then
        AddPickupInteractionToPed(supplierCode, warehousePed)
    else
        if not PickupModule.warehousePedNetIds[supplierCode] then
            TriggerServerEvent("nn_mechanic:requestWarehousePed", supplierCode)
        end
        StartPedMonitoringThread(supplierCode)
    end

    local notificationMessage = string.format(t("pickup_route_created"), supplierName)
    bridge.Notify.SendNotify(notificationMessage, "success")
    return true
end

function GetWarehousePed(supplierCode)
    return PickupModule.warehousePeds[supplierCode]
end

function RegisterWarehousePed(supplierCode, netId)
    PickupModule.warehousePedNetIds[supplierCode] = netId
    dprint(string.format("Stored warehouse ped netId for %s (netId: %d)", supplierCode, netId))
    TryGetWarehousePed(supplierCode)
end

function TryGetWarehousePed(supplierCode)
    local pedNetId = PickupModule.warehousePedNetIds[supplierCode]
    if not pedNetId then
        return nil
    end

    local existingPed = PickupModule.warehousePeds[supplierCode]
    if existingPed and DoesEntityExist(existingPed) then
        return existingPed
    end

    local warehouseLocation = GetWarehouseLocation(supplierCode)
    if not warehouseLocation then
        return nil
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local warehouseCoords = warehouseLocation.coords
    local distance = #(playerCoords - warehouseCoords)

    if distance < 30.0 then
        local ped = NetToPed(pedNetId)
        if ped and ped ~= 0 then
            if DoesEntityExist(ped) then
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, false)
                SetPedCombatAttributes(ped, 17, true)
                SetPedCanRagdoll(ped, false)
                SetPedCanEvasiveDive(ped, false)
                SetPedAsEnemy(ped, false)
                SetPedRelationshipGroupHash(ped, 1862763509)
                SetEntityProofs(ped, true, true, true, true, true, true, true, true)

                PickupModule.warehousePeds[supplierCode] = ped
                AddPickupInteractionToPed(supplierCode, ped)
                dprint(string.format("Successfully registered warehouse ped for %s (netId: %d)", supplierCode, pedNetId))
                return ped
            end
        end
    end
    return nil
end

function UnregisterWarehousePed(supplierCode)
    local ped = PickupModule.warehousePeds[supplierCode]
    if ped then
        bridge.Target.RemoveLocalEntity(ped)
        PickupModule.warehousePeds[supplierCode] = nil
    end
    PickupModule.warehousePedNetIds[supplierCode] = nil
end

function AddPickupInteractionToPed(supplierCode, ped)
    if not ped or not DoesEntityExist(ped) then
        return
    end

    local supplierName = OrderHelpers.GetSupplierNameFromCode(supplierCode)
    if not supplierName then
        supplierName = supplierCode
    end

    local options = {}
    local collectOption = {}
    collectOption.name = "collect_pickup_" .. supplierCode
    collectOption.label = t("pickup_collect_delivery")
    collectOption.icon = "fas fa-box"

    function collectOption.onSelect()
        local shopId = nil
        if State.shop and State.shop.id then
            shopId = State.shop.id
        elseif State.currentShopId then
            shopId = State.currentShopId
        end

        if not shopId then
            bridge.Notify.SendNotify(t("shop_not_found"), "error")
            return
        end

        local currentOrderNumber = PickupModule.activeRoute and PickupModule.activeRoute.orderNumber or nil

        local callbackResult = bridge.Callback.Trigger("nn_mechanic:collectPickup", shopId, supplierCode, currentOrderNumber)
        if callbackResult and callbackResult.success then
            if PickupModule.activeInstructions and not PickupModule.instructionStepCompleted.collect then
                PickupModule.instructionStepCompleted.collect = true
                CompleteInstructionStep(2)
            end
            local itemCount = callbackResult.itemCount or 0
            bridge.Notify.SendNotify(string.format(t("pickup_items_received"), itemCount), "success")
            CleanupPickupRoute()
        else
            local errorMessage = t("pickup_no_deliveries")
            if callbackResult and callbackResult.error then
                errorMessage = callbackResult.error
            end
            bridge.Notify.SendNotify(errorMessage, "error")
        end
    end
    options[1] = collectOption
    bridge.Target.AddLocalEntity(ped, options)
end

function ShowPickupInstructions(supplierName)
    local instructions = {}
    local navigateStep = {
        title = string.format(t("pickup_instructions_navigate"), supplierName),
        description = string.format(t("pickup_instructions_navigate_desc"), supplierName),
        completed = false
    }
    local collectStep = {
        title = t("pickup_instructions_collect"),
        description = t("pickup_instructions_collect_desc"),
        completed = false
    }
    instructions[1] = navigateStep
    instructions[2] = collectStep
    PickupModule.activeInstructions = instructions
    OpenInstructions(instructions)
    StartInstructionMonitoring()
end

function StartInstructionMonitoring()
    Citizen.CreateThread(function()
        while true do
            if not PickupModule.activeRoute or not PickupModule.currentSupplierCode then
                break
            end

            Wait(1000)

            local currentSupplierCode = PickupModule.currentSupplierCode
            local warehousePed = PickupModule.warehousePeds[currentSupplierCode]

            if not warehousePed or not DoesEntityExist(warehousePed) then
                warehousePed = TryGetWarehousePed(currentSupplierCode)
            end

            if warehousePed and DoesEntityExist(warehousePed) then
                local playerPed = PlayerPedId()
                local pedCoords = GetEntityCoords(warehousePed)
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(pedCoords - playerCoords)

                if distance < 5.0 then
                    if not PickupModule.instructionStepCompleted.navigate then
                        PickupModule.instructionStepCompleted.navigate = true
                        CompleteInstructionStep(1)
                    end
                end
            end

            if not PickupModule.activeRoute then
                break
            end
        end
    end)
end

function StartPedMonitoringThread(supplierCode)
    Citizen.CreateThread(function()
        while true do
            if not PickupModule.warehousePedNetIds[supplierCode] then
                break
            end

            if PickupModule.warehousePeds[supplierCode] then
                break
            end

            Wait(2000)

            local ped = TryGetWarehousePed(supplierCode)
            if ped and DoesEntityExist(ped) then
                break
            end
        end
    end)
end

function CleanupPickupRoute()
    if PickupModule.activeRoute and PickupModule.activeRoute.blip then
        RemoveBlip(PickupModule.activeRoute.blip)
    end
    ClearGpsMultiRoute()
    PickupModule.activeRoute = nil
    PickupModule.currentSupplierCode = nil
    PickupModule.activeInstructions = nil
    PickupModule.instructionStepCompleted = {
        navigate = false,
        collect = false
    }
end

function CleanupAllWarehousePeds()
    for _, ped in pairs(PickupModule.warehousePeds) do
        bridge.Target.RemoveLocalEntity(ped)
    end
    PickupModule.warehousePeds = {}
    PickupModule.warehousePedNetIds = {}

    for _, blip in pairs(PickupModule.warehouseBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PickupModule.warehouseBlips = {}
end

RegisterNetEvent("nn_mechanic:warehousePedSpawned", function(supplierCode, netId)
    RegisterWarehousePed(supplierCode, netId)
end)

RegisterNetEvent("nn_mechanic:warehousePedRemoved", function(supplierCode)
    UnregisterWarehousePed(supplierCode)
end)

Citizen.CreateThread(function()
    Wait(2000)
    local warehouseLocations = Config.WarehouseLocations or {}
    for supplierCode, _ in pairs(warehouseLocations) do
        TriggerServerEvent("nn_mechanic:requestWarehousePed", supplierCode)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAllWarehousePeds()
        CleanupPickupRoute()
    end
end)