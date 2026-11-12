local recoils = require 'f_recoils.config'

-- [F-PATCH] nilai dari /admin > Senjata (f_admin/client/wtune.lua) menimpa config.lua.
-- f_admin mengirim tabel { [tostring(hash)] = recoil } lewat event lokal + LocalPlayer.state.f_recoil.
-- Loop asli hanya mengecek tiap 350 ms sehingga kebanyakan tembakan terlewat (recoil terasa
-- tidak berubah); sekarang setiap tembakan dihitung dan recoil-nya menumpuk.
-- Re-apply setelah update f_smallresources.
local override = LocalPlayer.state.f_recoil or {}

AddEventHandler('f_admin:recoil', function(tbl)
    override = type(tbl) == 'table' and tbl or {}
end)

local function recoilOf(wep)
    wep = wep & 0xFFFFFFFF -- hash bertanda (sama dengan kunci config.lua)
    if wep >= 0x80000000 then wep -= 0x100000000 end
    local v = override[tostring(wep)]
    if v == nil then v = recoils[wep] end
    return v or 0
end

local running = false

local function recoilLoop()
    if running then return end
    running = true
    CreateThread(function()
        local pending = 0 -- sisa kenaikan kamera yang belum diterapkan
        while cache.weapon do
            local ped = cache.ped
            local active = pending > 0 or IsPlayerFreeAiming(cache.playerId) or IsControlPressed(0, 24) or IsDisabledControlPressed(0, 24)
            if active then
                if IsPedShooting(ped) and not IsPedDoingDriveby(ped) then
                    pending += recoilOf(cache.weapon)
                end
                if pending > 0 then
                    local p = GetGameplayCamRelativePitch()
                    if GetFollowPedCamViewMode() ~= 4 then
                        SetGameplayCamRelativePitch(p + 0.1, 0.2)
                        pending -= 0.1
                    elseif pending > 0.1 then
                        SetGameplayCamRelativePitch(p + 0.6, 1.2)
                        pending -= 0.6
                    else
                        SetGameplayCamRelativePitch(p + 0.016, 0.333)
                        pending -= 0.1
                    end
                    if pending < 0.001 then pending = 0 end
                end
                Wait(0)
            else
                Wait(100)
            end
        end
        running = false
    end)
end

lib.onCache('weapon', function(weapon)
    Wait(5)
    if not weapon then return end
    recoilLoop()
end)
