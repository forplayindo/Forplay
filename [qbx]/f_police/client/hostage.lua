-- Sandera: penyandera memegang pistol di belakang sandera dan tetap bisa berjalan pelan.
-- [G] lepaskan, [H] eksekusi. Penyandera mati / jatuh / senjata lepas = sandera bebas.

local config = require 'config.criminal'
local cfg, text = config.hostage, config.text
local DICT = 'anims@gangops@hostage@'

---@type integer|false server id penyandera kalau pemain ini sedang disandera
IsHostage = false
---@type integer|false server id sandera kalau pemain ini sedang menyandera
HoldingHostage = false

local weapons = {}
for _, hash in ipairs(cfg.weapons) do weapons[hash & 0xFFFFFFFF] = true end

---@param hash? integer|false cache.weapon is false while unarmed
---@return boolean
function IsHostageWeapon(hash)
    return math.type(hash) == 'integer' and weapons[hash & 0xFFFFFFFF] == true
end

local TAKER_BLOCKED = {
    21,  -- sprint
    22,  -- jump
    23,  -- enter vehicle
    24,  -- attack
    25,  -- aim
    37,  -- weapon wheel
    44,  -- cover
    140, 141, 142, 143, 257, 263, 264, -- melee / attack
}

local function pedOf(serverId)
    local idx = GetPlayerFromServerId(serverId)
    return idx ~= -1 and GetPlayerPed(idx) or 0
end

local function isDown()
    return LocalPlayer.state.isDead == true or IsPedDeadOrDying(cache.ped, true)
end

RegisterNetEvent('f_police:client:hostageTaker', function(victim)
    if GetInvokingResource() then return end
    HoldingHostage = victim
    lib.requestAnimDict(DICT)
    lib.showTextUI(text.hostageHelp)

    CreateThread(function()
        local reported = false
        while HoldingHostage == victim do
            for i = 1, #TAKER_BLOCKED do DisableControlAction(0, TAKER_BLOCKED[i], true) end
            DisablePlayerFiring(cache.playerId, true)

            if not IsEntityPlayingAnim(cache.ped, DICT, 'perp_idle', 3) then
                TaskPlayAnim(cache.ped, DICT, 'perp_idle', 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            if not reported then
                if IsControlJustPressed(0, cfg.releaseKey) then
                    reported = true
                    TriggerServerEvent('f_police:server:hostageRelease')
                elseif IsControlJustPressed(0, cfg.executeKey) then
                    reported = true
                    TriggerServerEvent('f_police:server:hostageExecute')
                elseif isDown() or IsPedRagdoll(cache.ped) or cache.vehicle
                    or not IsHostageWeapon(cache.weapon) or pedOf(victim) == 0 then
                    reported = true
                    TriggerServerEvent('f_police:server:hostageBroken')
                end
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('f_police:client:hostageVictim', function(taker)
    if GetInvokingResource() then return end
    local takerPed = pedOf(taker)
    if takerPed == 0 then return end

    IsHostage = taker
    lib.requestAnimDict(DICT)
    ClearPedTasksImmediately(cache.ped)
    AttachEntityToEntity(cache.ped, takerPed, 0, -0.24, 0.11, 0.0, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
    exports.qbx_core:Notify(text.hostageVictim, 'error')

    CreateThread(function()
        local reported = false
        while IsHostage == taker do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- look
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true) -- chat
            EnableControlAction(0, 249, true) -- push to talk

            if not IsEntityPlayingAnim(cache.ped, DICT, 'victim_idle', 3) and not isDown() then
                TaskPlayAnim(cache.ped, DICT, 'victim_idle', 8.0, -8.0, -1, 1, 0, false, false, false)
            end

            if not reported and isDown() then
                reported = true
                TriggerServerEvent('f_police:server:hostageBroken')
            end

            -- penyandera keluar dari jangkauan (disconnect): lepas sendiri, server membersihkan saat drop
            if pedOf(taker) == 0 then
                IsHostage = false
                DetachEntity(cache.ped, true, false)
                ClearPedTasks(cache.ped)
            end
            Wait(0)
        end
    end)
end)

---@param kind 'release'|'execute'|'broken'
RegisterNetEvent('f_police:client:hostageEnd', function(kind)
    if GetInvokingResource() then return end

    if HoldingHostage then
        local victimPed = pedOf(HoldingHostage)
        HoldingHostage = false
        lib.hideTextUI()
        StopAnimTask(cache.ped, DICT, 'perp_idle', 1.0)

        if kind == 'execute' and victimPed ~= 0 then
            local head = GetPedBoneCoords(victimPed, 31086, 0.0, 0.0, 0.0)
            SetPedShootsAtCoord(cache.ped, head.x, head.y, head.z, true)
            lib.playAnim(cache.ped, DICT, 'perp_fail', 8.0, -8.0, 1500, 48)
        elseif kind == 'release' then
            lib.playAnim(cache.ped, 'reaction@shove', 'shove_var_a', 8.0, -8.0, 1000, 48)
        end
    end

    if IsHostage then
        IsHostage = false
        DetachEntity(cache.ped, true, false)
        ClearPedTasks(cache.ped)

        if kind == 'execute' then
            lib.playAnim(cache.ped, DICT, 'victim_fail', 8.0, -8.0, -1, 0)
            Wait(700)
            if not isDown() then SetEntityHealth(cache.ped, 0) end
        elseif kind == 'release' then
            lib.playAnim(cache.ped, 'reaction@shove', 'shoved_back', 8.0, -8.0, 1000, 0)
        end
    end

    RemoveAnimDict(DICT)
end)
