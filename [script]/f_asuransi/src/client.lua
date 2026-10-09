---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT
local function Checkedstr(text, detected)
    return string.find(text, detected) ~= nil
end
-- Kendaraan dihapus langsung di server (src/server.lua); client hanya menampilkan UI dan blip.

Citizen.CreateThread(function()
    if Config.RemoveCarsInSafeZone then return end
    for _, zone in ipairs(Config.safezone.zone) do
        if Config.safezone.blipshow then
            local blip = AddBlipForRadius(zone.coord.x, zone.coord.y, zone.coord.z, zone.radius)
            SetBlipColour(blip, Config.safezone.blipstyle.color)
            SetBlipAlpha(blip, Config.safezone.blipstyle.degraded)
        end
    end
end)

RegisterNetEvent("bk_asuransi:client:niu")
AddEventHandler("bk_asuransi:client:niu", function(data)
    local logo = data.data.logo
    if not Checkedstr(logo, "http") then
        data.data.logo = "assets/" .. logo
    end

    SendNUIMessage({
        type = data.type,
        data = data.data,
    })
    SetNuiFocus(false, false)
end)

RegisterNetEvent('bk_asuransi:client:updateTimer')
AddEventHandler('bk_asuransi:client:updateTimer', function(data)
    SendNUIMessage({
        type = "updateTimer",
        data = data
    })
end)

RegisterNetEvent('bk_asuransi:client:closeui')
AddEventHandler('bk_asuransi:client:closeui', function()
    SendNUIMessage({
        type = "closeui",
        data = {
            style = Config.nui.style,
            color = Config.nui.color,
            logo = Config.clear_nui.logo,
            tittle = Config.nui.tittle,
            description = Config.clear_nui.description,
            position = Config.nui.position,
            clear_sound = Config.clear_nui.clear_sound.sound,
            clear_volume = Config.clear_nui.clear_sound.volume
        }
    })
end)
---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT