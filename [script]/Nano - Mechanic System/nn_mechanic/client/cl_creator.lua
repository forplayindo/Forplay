State = {}
State.isAdminMode = false
State.currentShopId = nil

function OpenCreator()
    SendNUIMessage({
        action = "setTranslations",
        data = {
            translations = Translations[Config.Language]
        }
    })
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            action = "setVisible",
            page = "creator"
        }
    })
    DisplayRadar(false)
end

function OpenAdminManagement(shopId)
    local adminShopData = bridge.Callback.Trigger("nn_mechanic:getShopForAdminManagement", shopId)
    if not adminShopData then
        bridge.Notify.SendNotify(t("no_permission"), "error")
        return
    end

    State.isAdminMode = true
    State.currentShopId = shopId

    SendNUIMessage({
        action = "setTranslations",
        data = {
            translations = Translations[Config.Language]
        }
    })

    local vehicleUpgrades = Config.VehicleUpgrades or {}

    SendNUIMessage({
        action = "setManagementData",
        data = {
            managementData = adminShopData.shop,
            vehicleUpgrades = vehicleUpgrades,
            isAdminMode = true,
            hideFinanceTab = true
        }
    })

    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "management"
        }
    })

    SetNuiFocus(true, true)
    TriggerScreenblurFadeIn(500)
end

function ShowPublicShopSelector()
    local canManageResult = bridge.Callback.Trigger("nn_mechanic:canAdminManageShops")
    if not canManageResult then
        bridge.Notify.SendNotify(t("no_permission"), "error")
        return
    end

    local publicShops = bridge.Callback.Trigger("nn_mechanic:getPublicShops")

    if not publicShops or #publicShops == 0 then
        bridge.Notify.SendNotify(t("no_public_shops"), "info")
        return
    end

    local shopOptions = {}
    for _, shop in ipairs(publicShops) do
        table.insert(shopOptions, {
            title = shop.name,
            description = string.format("ID: %d", shop.id),
            onSelect = function()
                OpenAdminManagement(shop.id)
            end
        })
    end

    if bridge.Menu then
        bridge.Menu.Open({
            id = "admin_public_shops",
            title = t("manage_public_shop"),
            options = shopOptions
        })
    else
        if #publicShops > 0 then
            OpenAdminManagement(publicShops[1].id)
        end
    end
end

RegisterNUICallback("nn_mechanic:startLocationCapture", function(data, cb)
    State.isCapturingLocation = true
    State.captureType = data.type

    SetNuiFocus(false, false)

    local helpTextTitle, helpTextDescription = t("move_to_desired_location_enter_confirm_esc_cancel")
    bridge.HelpText.ShowHelpText(helpTextTitle, helpTextDescription)

    Citizen.CreateThread(function()
        local currentCoords = nil
        while true do
            if not State.isCapturingLocation then
                break
            end

            local pedCoords = GetEntityCoords(State.Ped)
            currentCoords = roundCoords(pedCoords)

            DrawMarker(
                1,
                currentCoords.x,
                currentCoords.y,
                currentCoords.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                2.0, 2.0, 1.0,
                132, 221, 111, 100,
                false,
                true,
                2,
                false,
                nil, nil,
                false
            )

            if IsControlJustPressed(0, 18) then -- ENTER
                State.isCapturingLocation = false
                bridge.HelpText.HideHelpText()

                local capturedLocation = {
                    x = currentCoords.x,
                    y = currentCoords.y,
                    z = currentCoords.z
                }

                if State.captureType == "shop" then
                    State.capturedShopLocation = capturedLocation
                elseif State.captureType == "management" then
                    State.capturedManagementLocation = capturedLocation
                end

                cb(capturedLocation)
                Citizen.Wait(100)
                OpenCreator()
                break
            end

            if IsControlJustPressed(0, 322) then -- ESC
                State.isCapturingLocation = false
                bridge.HelpText.HideHelpText()
                cb(nil)
                Citizen.Wait(100)
                OpenCreator()
                break
            end

            Wait(0)
        end
    end)
end)

RegisterNUICallback("nn_mechanic:createShop", function(shopData, cb)
    TriggerServerEvent("nn_mechanic:createShop", shopData)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            action = "setVisible",
            page = "creator"
        }
    })
    DisplayRadar(true)
    cb("ok")
end)

RegisterCommand(Config.Creator.Command, function()
    local playerJobData = bridge.Framework.GetPlayerJobData()
    if playerJobData.jobName ~= Config.Creator.Job then
        return
    end
    OpenCreator()
end, false)

RegisterCommand("managepublicshop", function()
    ShowPublicShopSelector()
end, false)