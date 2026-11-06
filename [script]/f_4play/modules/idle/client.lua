-- Animasi idle saat diam. Ringan: cek tiap 0,5 detik; Wait(0) hanya selama animasi berjalan
-- (untuk membatalkan begitu pemain menekan tombol gerak / bidik).

local C = IdleConfig
local TASK_PLAY_ANIM = `SCRIPT_TASK_PLAY_ANIM`
local FEMALE = `mp_f_freemode_01`
local UNARMED = `WEAPON_UNARMED`
local DEATH_BAG = 'f_medical:deathState'

-- tombol yang membatalkan idle: gerak, lari, lompat, masuk kendaraan, bidik, tembak, cover, roda senjata
local CANCEL = { 30, 31, 32, 33, 34, 35, 21, 22, 23, 24, 25, 44, 37 }

local function pressed()
    for i = 1, #CANCEL do
        if IsControlPressed(0, CANCEL[i]) or IsDisabledControlPressed(0, CANCEL[i]) then return true end
    end
    return false
end

---Boleh idle sekarang? (diam, jalan kaki, tidak sedang animasi / scenario lain)
local function canIdle(ped)
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return false end
    if cache.vehicle or IsPedInAnyVehicle(ped, true) or IsPedGettingIntoAVehicle(ped) then return false end
    if IsPedInCover(ped, false) or IsPedCuffed(ped) or IsPedUsingAnyScenario(ped) then return false end
    if IsPlayerFreeAiming(cache.playerId) or IsPedShooting(ped) or IsPedReloading(ped) then return false end
    if GetScriptTaskStatus(ped, TASK_PLAY_ANIM) ~= 7 then return false end -- emote / duduk / borgol dll.
    if GetEntitySpeed(ped) > 0.1 then return false end
    if C.SkipArmed and GetSelectedPedWeapon(ped) ~= UNARMED then return false end
    local death = LocalPlayer.state[DEATH_BAG]
    if death ~= nil and death ~= 1 then return false end
    return true
end

local function playIdle(ped)
    local set = GetEntityModel(ped) == FEMALE and C.Female or (IsPedMale(ped) and C.Male or C.Female)
    local clip = set.clips[math.random(#set.clips)]
    if not pcall(lib.requestAnimDict, set.dict, 2000) then return end
    TaskPlayAnim(ped, set.dict, clip, 2.0, -2.0, -1, 0, 0.0, false, false, false)

    Wait(100)
    while IsEntityPlayingAnim(ped, set.dict, clip, 3) do
        if pressed() or cache.vehicle or IsEntityDead(ped) or IsPedRagdoll(ped) then
            StopAnimTask(ped, set.dict, clip, 3.0)
            break
        end
        Wait(0)
    end
    RemoveAnimDict(set.dict)
end

CreateThread(function()
    local still = 0
    while true do
        Wait(500)
        local ped = cache.ped
        if LocalPlayer.state.isLoggedIn and not pressed() and canIdle(ped) then
            still = still + 500
            if still >= C.Delay then
                playIdle(ped)
                -- tetap diam: animasi berikutnya setelah jeda acak
                still = C.Delay - math.random(C.Cooldown[1], C.Cooldown[2])
            end
        else
            still = 0
        end
    end
end)
