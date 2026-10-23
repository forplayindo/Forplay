if not bridge then
    bridge = exports.community_bridge:Bridge()
end

local currentInvoiceData = nil

function CloseInvoiceUI()
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            action = "setVisible",
            page = "invoice"
        }
    })
    if State then
        State.openPage = nil
    end
    currentInvoiceData = nil
end

RegisterNetEvent("nn_mechanic:invoicePaymentResult", function(data)
    if not data then return end
    if data.success then
        CloseInvoiceUI()
        return
    end
    
    SendNUIMessage({
        action = "invoiceError",
        data = {
            message = data.message or "Error"
        }
    })
end)

RegisterNetEvent("nn_mechanic:invoiceDeclined", function()
    CloseInvoiceUI()
end)

RegisterNetEvent("nn_mechanic:invoicePaidToMechanic", function(data)
    if not data then return end
    
    local message = string.format("%s: $%s (%s)", t("invoice_paid_mechanic"), tostring(data.amount or 0), tostring(data.account or "bank"))
    bridge.Notify.SendNotify(message, "success")
end)

RegisterNetEvent("nn_mechanic:invoiceDeclinedToMechanic", function()
    bridge.Notify.SendNotify(t("invoice_declined_mechanic"), "error")
end)

function GetClosestVehiclePlate()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 71)
    
    if vehicle and vehicle ~= 0 then
        if DoesEntityExist(vehicle) then
            return GetVehicleNumberPlateText(vehicle)
        end
    end
    
    if IsPedInAnyVehicle(ped, false) then
        local inVehicle = GetVehiclePedIsIn(ped, false)
        if inVehicle and inVehicle ~= 0 then
            return GetVehicleNumberPlateText(inVehicle)
        end
    end
    
    return nil
end

RegisterNetEvent("nn_mechanic:receiveInvoice", function(data)
    if not data or not data.id then return end
    
    currentInvoiceData = data
    
    SendNUIMessage({
        action = "setInvoice",
        data = data
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            action = "setVisible",
            page = "invoice"
        }
    })
    
    SetNuiFocus(true, true)
    DisplayRadar(false)
    TriggerScreenblurFadeIn(500)
    
    if State then
        State.openPage = "invoice"
    end
end)

RegisterNUICallback("invoicePay", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false })
        return
    end
    
    local accountType = "bank"
    if data.account == "cash" then
        accountType = "cash"
    end
    
    local plate = GetClosestVehiclePlate()
    
    if currentInvoiceData and currentInvoiceData.orderId then
        TriggerServerEvent("nn_mechanic:payInvoice", data.invoiceId, accountType)
    else
        TriggerServerEvent("nn_mechanic:payInvoiceNew", data.invoiceId, accountType, plate)
    end
    
    cb({ success = true })
end)

RegisterNUICallback("invoiceDecline", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false })
        return
    end
    
    if currentInvoiceData and currentInvoiceData.orderId then
        TriggerServerEvent("nn_mechanic:declineInvoice", data.invoiceId)
    else
        TriggerServerEvent("nn_mechanic:declineInvoiceNew", data.invoiceId)
    end
    
    cb({ success = true })
end)