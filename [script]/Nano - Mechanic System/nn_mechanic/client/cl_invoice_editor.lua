if not bridge then
    bridge = exports.community_bridge:Bridge()
end

function CloseInvoiceEditor()
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "invoice-editor"
        }
    })
    State.openPage = nil
end

function OpenInvoiceEditor()
    if not State.shop or not State.shop.id then
        bridge.Notify.SendNotify(t("must_be_in_shop"), "error")
        return
    end
    
    SendNUIMessage({
        action = "setInvoiceEditorShop",
        data = {
            shopId = State.shop.id,
            shopName = State.shop.name
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "invoice-editor"
        }
    })
    
    SetNuiFocus(true, true)
    DisplayRadar(false)
    TriggerScreenblurFadeIn(500)
    State.openPage = "invoice-editor"
end

RegisterCommand("mech_invoice", function()
    if State.openPage then
        return
    end
    OpenInvoiceEditor()
end, false)

RegisterNUICallback("invoiceEditorClose", function(data, cb)
    CloseInvoiceEditor()
    cb({ success = true })
end)

RegisterNUICallback("invoiceEditorLoad", function(data, cb)
    if not State.shop or not State.shop.id then
        cb({ success = false, error = t("must_be_in_shop") })
        return
    end
    
    local statuses = data.statuses
    if not statuses then
        statuses = { "draft", "unpaid" }
    end
    
    local filters = {
        page = data.page,
        pageSize = data.pageSize,
        dateFrom = data.dateFrom,
        dateTo = data.dateTo,
        plate = data.plate,
        vehicleName = data.vehicleName,
        search = data.search
    }
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceList", State.shop.id, statuses, filters)
    cb(result or { success = false, error = "Failed to load invoices" })
end)

RegisterNUICallback("invoiceEditorTabCounts", function(data, cb)
    if not State.shop or not State.shop.id then
        cb({ success = false, error = t("must_be_in_shop") })
        return
    end
    
    local filters = {}
    if data then
        filters.dateFrom = data.dateFrom
        filters.dateTo = data.dateTo
        filters.plate = data.plate
        filters.vehicleName = data.vehicleName
        filters.search = data.search
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceListTabCounts", State.shop.id, filters)
    cb(result or { success = false, error = "Failed to load counts" })
end)

RegisterNUICallback("invoiceEditorGet", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, error = "Invoice ID required" })
        return
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceGet", data.invoiceId)
    cb(result or { success = false, error = "Failed to get invoice" })
end)

RegisterNUICallback("invoiceEditorCreateDraft", function(data, cb)
    if not State.shop or not State.shop.id then
        cb({ success = false, error = t("must_be_in_shop") })
        return
    end
    
    local vehiclePlate = data.vehiclePlate or ""
    local vehicleName = data.vehicleName or ""
    local items = data.items or {}
    local notes = data.notes or ""
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceCreateDraft", State.shop.id, vehiclePlate, vehicleName, items, notes)
    cb(result or { success = false, error = "Failed to create draft" })
end)

RegisterNUICallback("invoiceEditorUpdateDraft", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, error = "Invoice ID required" })
        return
    end
    
    local vehiclePlate = data.vehiclePlate or ""
    local vehicleName = data.vehicleName or ""
    local items = data.items or {}
    local notes = data.notes or ""
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceUpdateDraft", data.invoiceId, vehiclePlate, vehicleName, items, notes)
    cb(result or { success = false, error = "Failed to update draft" })
end)

RegisterNUICallback("invoiceEditorSend", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, error = "Invoice ID required" })
        return
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceSend", data.invoiceId)
    cb(result or { success = false, error = "Failed to send invoice" })
end)

RegisterNUICallback("invoiceEditorResend", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, error = "Invoice ID required" })
        return
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceSend", data.invoiceId)
    cb(result or { success = false, error = "Failed to resend invoice" })
end)

RegisterNUICallback("invoiceEditorDelete", function(data, cb)
    if not data or not data.invoiceId then
        cb({ success = false, error = "Invoice ID required" })
        return
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceDelete", data.invoiceId)
    cb(result or { success = false, error = "Failed to delete invoice" })
end)

RegisterNUICallback("getInvoicesForSafari", function(data, cb)
    if not State.shop or not State.shop.id then
        cb({ success = false, error = t("must_be_in_shop") })
        return
    end
    
    local result = bridge.Callback.Trigger("nn_mechanic:invoiceListForSafari", State.shop.id, data or {})
    cb(result or { success = false, error = "Failed to load invoices" })
end)