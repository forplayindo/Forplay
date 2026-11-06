local recoils = require 'f_recoils.config'

-- [F-PATCH] nilai dari /admin > Senjata (f_admin/client/wtune.lua) menimpa config.lua.
-- Re-apply setelah update f_smallresources.
local function recoilOf(wep)
    local over = LocalPlayer.state.f_recoil
    local v = over and over[tostring(wep)]
    if v == nil then v = recoils[wep] end
    return v
end

local function recoilLoop()
    CreateThread(function()
        while cache.weapon do
            if IsPedShooting(cache.ped) and not IsPedDoingDriveby(cache.ped) then
                local _, wep = GetCurrentPedWeapon(cache.ped, true)
                local recoil = recoilOf(wep)
                if recoil and recoil ~= 0 then
                    -- luacheck: ignore
                    local tv = 0
                    if GetFollowPedCamViewMode() ~= 4 then
                        repeat
                            Wait(0)
                            local p = GetGameplayCamRelativePitch()
                            SetGameplayCamRelativePitch(p + 0.1, 0.2)
                            tv += 0.1
                        until tv >= recoil
                    else
                        repeat
                            Wait(0)
                            local p = GetGameplayCamRelativePitch()
                            if recoil > 0.1 then
                                SetGameplayCamRelativePitch(p + 0.6, 1.2)
                                tv += 0.6
                            else
                                SetGameplayCamRelativePitch(p + 0.016, 0.333)
                                tv += 0.1
                            end
                        until tv >= recoil
                    end
                end
            end
            Wait(350) -- might be able to reduce time here for more recoil
        end
    end)
end

lib.onCache('weapon', function(weapon)
    Wait(5)
    if not weapon then return end
    recoilLoop()
end)