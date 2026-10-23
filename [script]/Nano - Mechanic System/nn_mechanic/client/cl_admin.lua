local function OpenAdminPanel()
    local isAdmin = bridge.Callback.Trigger("nn_mechanic:checkIsAdmin")
    if not isAdmin then
        bridge.Notify.SendNotify(t("no_permission"), "error")
        return
    end

    local shopsData = bridge.Callback.Trigger("nn_mechanic:adminGetAllShops")
    if shopsData then
        if shopsData.success then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = true,
                    page = "admin_panel"
                }
            })
            SendNUIMessage({
                action = "setAdminPanelData",
                data = {
                    shops = shopsData.shops
                }
            })
            TriggerScreenblurFadeIn(500)
            SetNuiFocus(true, true)
        end
    else
        bridge.Notify.SendNotify(t("no_permission"), "error")
    end
end

RegisterNUICallback("closeAdminPanel", function(data, cb)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = nil
        }
    })
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(500)
    State.openPage = nil
    cb("ok")
end)

RegisterNUICallback("refreshAdminShops", function(data, cb)
    local shopsData = bridge.Callback.Trigger("nn_mechanic:adminGetAllShops")
    if shopsData and shopsData.success then
        SendNUIMessage({
            action = "setAdminPanelData",
            data = {
                shops = shopsData.shops
            }
        })
    end
    cb("ok")
end)

RegisterNUICallback("adminDeleteShop", function(data, cb)
    local result = bridge.Callback.Trigger("nn_mechanic:adminDeleteShop", data.shopId, data.password)
    local response = result or { success = false, error = "Failed to delete shop" }
    cb(response)
end)

RegisterNUICallback("getNearbyPlayers", function(data, cb)
    local playersData = bridge.Callback.Trigger("nn_mechanic:getNearbyPlayersAdmin")
    local response = playersData or {}
    cb(response)
end)

RegisterNUICallback("getCurrentAdminInfo", function(data, cb)
    local adminInfo = bridge.Callback.Trigger("nn_mechanic:getCurrentAdminInfo")
    cb(adminInfo)
end)

RegisterNUICallback("adminSetShopOwner", function(data, cb)
    local result = bridge.Callback.Trigger("nn_mechanic:adminSetShopOwner", data)
    local response = result or { success = false }
    cb(response)
end)

RegisterNUICallback("adminAddEmployee", function(data, cb)
    local result = bridge.Callback.Trigger("nn_mechanic:adminAddEmployee", data)
    local response = result or { success = false }
    cb(response)
end)

RegisterNUICallback("adminRemoveEmployee", function(data, cb)
    local result = bridge.Callback.Trigger("nn_mechanic:adminRemoveEmployee", data)
    local response = result or { success = false }
    cb(response)
end)

RegisterNUICallback("adminGetLogs", function(data, cb)
    local filters = data.filters or {}
    local result = bridge.Callback.Trigger("nn_mechanic:adminGetLogs", filters)
    local response = result or { success = false, error = "server_error" }
    cb(response)
end)

RegisterNUICallback("adminGetLogCategories", function(data, cb)
    local result = bridge.Callback.Trigger("nn_mechanic:getLogCategories")
    local response = result or {}
    cb(response)
end)

RegisterCommand(Config.AdminPanel.Command, OpenAdminPanel, false)

RegisterNetEvent("nn_mechanic:removeShopBlip", function(shopId)
    RemoveShopBlip(shopId)
end)