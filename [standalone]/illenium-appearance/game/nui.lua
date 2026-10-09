local client = client

RegisterNUICallback("appearance_get_locales", function(_, cb)
    cb(Locales[GetConvar("illenium-appearance:locale", "en")].UI)
end)

RegisterNUICallback("appearance_get_settings", function(_, cb)
    cb({ appearanceSettings = client.getAppearanceSettings() })
end)

RegisterNUICallback("appearance_get_data", function(_, cb)
    Wait(250)
    local appearanceData = client.getAppearance()
    if appearanceData.tattoos then
        client.setPedTattoos(cache.ped, appearanceData.tattoos)
    end
    cb({ config = client.getConfig(), appearanceData = appearanceData })
end)

RegisterNUICallback("appearance_set_camera", function(camera, cb)
    cb(1)
    client.setCamera(camera)
end)

RegisterNUICallback("appearance_turn_around", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 180.0)
end)

RegisterNUICallback("appearance_rotate_camera", function(direction, cb)
    cb(1)
    client.rotateCamera(direction)
end)

RegisterNUICallback("appearance_change_model", function(model, cb)
    local playerPed = client.setPlayerModel(model)

    SetEntityHeading(cache.ped, client.getHeading())
    SetEntityInvincible(playerPed, true)
    TaskStandStill(playerPed, -1)

    cb({
        appearanceSettings = client.getAppearanceSettings(),
        appearanceData = client.getPedAppearance(playerPed)
    })
end)

RegisterNUICallback("appearance_change_component", function(component, cb)
    client.setPedComponent(cache.ped, component)
    cb(client.getComponentSettings(cache.ped, component.component_id))
end)

RegisterNUICallback("appearance_change_prop", function(prop, cb)
    client.setPedProp(cache.ped, prop)
    cb(client.getPropSettings(cache.ped, prop.prop_id))
end)

RegisterNUICallback("appearance_change_head_blend", function(headBlend, cb)
    cb(1)
    client.setPedHeadBlend(cache.ped, headBlend)
end)

RegisterNUICallback("appearance_change_face_feature", function(faceFeatures, cb)
    cb(1)
    client.setPedFaceFeatures(cache.ped, faceFeatures)
end)

RegisterNUICallback("appearance_change_head_overlay", function(headOverlays, cb)
    cb(1)
    client.setPedHeadOverlays(cache.ped, headOverlays)
end)

RegisterNUICallback("appearance_change_hair", function(hair, cb)
    client.setPedHair(cache.ped, hair)
    cb(client.getHairSettings(cache.ped))
end)

RegisterNUICallback("appearance_change_eye_color", function(eyeColor, cb)
    cb(1)
    client.setPedEyeColor(cache.ped, eyeColor)
end)

-- Menghitung tattoo per (zona + nama) sebagai multiset, supaya tattoo yang sama
-- dipasang dua kali tetap terhitung dua.
local function countTattoos(tattoos)
    local counts = {}
    if not tattoos then return counts end
    for zone, list in pairs(tattoos) do
        for i = 1, #list do
            local t = list[i]
            local key = zone .. "|" .. (t.name or t.label or "?")
            counts[key] = (counts[key] or 0) + 1
        end
    end
    return counts
end

-- Tattoo yang ada di `final` tapi tidak ada di `original` = yang harus dibayar.
local function getNewTattoos(original, final)
    local before = countTattoos(original)
    local added = {}
    if not final then return added end
    for zone, list in pairs(final) do
        for i = 1, #list do
            local t = list[i]
            local key = zone .. "|" .. (t.name or t.label or "?")
            if (before[key] or 0) > 0 then
                before[key] = before[key] - 1
            else
                added[#added + 1] = t
            end
        end
    end
    return added
end

local function chargeOnApply()
    return Config.ChargePerTattoo and not Config.ChargeTattoosOnSave
end

RegisterNUICallback("appearance_apply_tattoo", function(data, cb)
    local paid = not data.tattoo or not chargeOnApply() or lib.callback.await("illenium-appearance:server:payForTattoo", false, data.tattoo)
    if paid then
        client.addPedTattoo(cache.ped, data.updatedTattoos or data)
    end
    cb(paid)
end)

RegisterNUICallback("appearance_preview_tattoo", function(previewTattoo, cb)
    cb(1)
    client.setPreviewTattoo(cache.ped, previewTattoo.data, previewTattoo.tattoo)
end)

RegisterNUICallback("appearance_delete_tattoo", function(data, cb)
    cb(1)
    client.removePedTattoo(cache.ped, data)
end)

RegisterNUICallback("appearance_wear_clothes", function(dataWearClothes, cb)
    cb(1)
    client.wearClothes(dataWearClothes.data, dataWearClothes.key)
end)

RegisterNUICallback("appearance_remove_clothes", function(clothes, cb)
    cb(1)
    client.removeClothes(clothes)
end)

RegisterNUICallback("appearance_save", function(appearance, cb)
    cb(1)

    -- Tagih sekali di akhir, hanya untuk tattoo yang benar-benar masih terpasang.
    if Config.ChargePerTattoo and Config.ChargeTattoosOnSave then
        local original = client.getAppearance().tattoos
        local added = getNewTattoos(original, appearance.tattoos)
        if #added > 0 then
            local paid = lib.callback.await("illenium-appearance:server:payForTattoos", false, added)
            if not paid then
                -- Uang tidak cukup: batalkan HANYA bagian tattoo-nya, perubahan lain tetap disimpan.
                -- Dicetak ke console supaya kalau tattoo "hilang saat save" penyebabnya jelas.
                print("^3[illenium-appearance]^7 pembayaran tattoo gagal, " .. #added .. " tattoo dikembalikan ke kondisi awal")
                appearance.tattoos = original
                client.setPedTattoos(cache.ped, original)
            end
        end
    end

    client.wearClothes(appearance, "head")
    client.wearClothes(appearance, "body")
    client.wearClothes(appearance, "bottom")
    client.exitPlayerCustomization(appearance)
end)

RegisterNUICallback("appearance_exit", function(_, cb)
    cb(1)
    client.exitPlayerCustomization()
end)

RegisterNUICallback("rotate_left", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 10.0)
end)

RegisterNUICallback("rotate_right", function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, -10.0)
end)

RegisterNUICallback("get_theme_configuration", function(_, cb)
    cb(Config.Theme)
end)
