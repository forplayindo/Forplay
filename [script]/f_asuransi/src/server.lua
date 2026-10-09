---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT
local timerActive = false

Config.nui.start_sound = Config.sound.start_sound.sound
Config.nui.start_volume = Config.sound.start_sound.volume
Config.nui.end_sound = Config.sound.end_sound.sound
Config.nui.end_volume = Config.sound.end_sound.volume
Config.nui.time_nui = Config.auto.DeleteVehicleTimer

RegisterCommand(Config.Staff.Command, function(source)
    local myGroup = Framework.GetGroup(source)
    if Config.Framework == "esx" then
        for i = 1, #Config.Staff.Group do
            if Config.Staff.Group[i] == myGroup then
                if not timerActive then
                    TriggerClientEvent('bk_asuransi:client:niu', -1, {type = 'openui', data = Config.nui})
                    TriggerEvent("bk_asuransi:startDeleteTimer")
                else
                    Gx_Notify( Leng['already_autoDV'], Leng['tittle'], 'inform', 'top', 8000, source)
                end
                return
            end
        end
    elseif Config.Framework == "qb" then
        for role, hasRole in pairs(myGroup) do
            if hasRole then
                for i = 1, #Config.Staff.Group do
                    if Config.Staff.Group[i] == role then
                        if not timerActive then
                            TriggerClientEvent('bk_asuransi:client:niu', -1, {type = 'openui', data = Config.nui})
                            TriggerEvent("bk_asuransi:startDeleteTimer")
                        else
                            Gx_Notify( Leng['already_autoDV'], Leng['tittle'],'inform', 'top', 8000, source)
                        end
                        return
                    end
                end
            end
        end
    end

end)

local function isInSafeZone(coords)
    if Config.RemoveCarsInSafeZone then return false end
    for _, zone in ipairs(Config.safezone.zone) do
        if #(coords - zone.coord) <= zone.radius then return true end
    end
    return false
end

-- Hapus semua kendaraan yang tidak dinaiki pemain (pengemudi atau penumpang), langsung di server.
-- Dulu tiap client mengirim event hapus per kendaraan tanpa pengecekan apa pun, sehingga siapa saja
-- bisa menghapus kendaraan orang lain kapan saja; sekarang tidak ada event dari client lagi.
local function deleteUnoccupiedVehicles()
    local occupied = {}
    for _, playerId in ipairs(GetPlayers()) do
        local veh = GetVehiclePedIsIn(GetPlayerPed(playerId), false)
        if veh ~= 0 then occupied[veh] = true end
    end

    local removed = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if not occupied[veh] and DoesEntityExist(veh) and not isInSafeZone(GetEntityCoords(veh)) then
            DeleteEntity(veh)
            removed = removed + 1
        end
    end
    print(('[f_asuransi] %d kendaraan dihapus'):format(removed))
end

-- server-only: tidak didaftarkan sebagai net event supaya client tidak bisa memicu hapus massal
AddEventHandler("bk_asuransi:startDeleteTimer", function()
    if timerActive then return end
    timerActive = true
    local timer = Config.auto.DeleteVehicleTimer * 60 
    while timer > 0 do
        Citizen.Wait(1000) 
        timer = timer - 1
        local minutes = math.floor(timer / 60)
        local seconds = timer % 60
        TriggerClientEvent('bk_asuransi:client:updateTimer', -1, {timer = string.format("%02d:%02d", minutes, seconds), end_sound = Config.sound.end_sound.sound, end_volume = Config.sound.end_sound.volume})
        if timer == 0 then
            deleteUnoccupiedVehicles()
            TriggerClientEvent('bk_asuransi:client:closeui', -1)
            timerActive = false
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local currentTime = string.format("%02d:%02d", tonumber(os.date("%H")), tonumber(os.date("%M")))
        for _, time in pairs(Config.auto.time) do
            if currentTime == time and not timerActive then
                TriggerClientEvent('bk_asuransi:client:niu', -1, {type = 'openui', data = Config.nui})
                TriggerEvent("bk_asuransi:startDeleteTimer") 
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        
    end
end)
---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT