---------------------------------------------------------------------------
-- Spectate: staff dibekukan & tak terlihat di bawah target, kamera mengikuti target.
-- [BACKSPACE] berhenti, kembali ke posisi & routing bucket semula (diurus server).
---------------------------------------------------------------------------
local target -- server id yang sedang ditonton

local function hide(on)
    FreezeEntityPosition(cache.ped, on)
    SetEntityCollision(cache.ped, not on, not on)
    SetEntityVisible(cache.ped, not on, false)
    SetEntityInvincible(cache.ped, on)
end

local function stop()
    if not target then return end
    target = nil
    NetworkSetInSpectatorMode(false, cache.ped)
    TriggerServerEvent('f_admin:server:spectateEnd')
end

RegisterNetEvent('f_admin:client:spectate', function(id, coords, name)
    local first = target == nil
    target = id
    if not first then return end
    hide(true)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - 15.0, false, false, false, false)
    lib.showTextUI(('Spectate %s  ·  [BACKSPACE] berhenti'):format(name), { position = 'top-center' })

    CreateThread(function()
        local nextPoll = 0
        while target do
            local pl = GetPlayerFromServerId(target)
            local tp = pl ~= -1 and GetPlayerPed(pl) or 0
            if tp ~= 0 and DoesEntityExist(tp) then
                if not NetworkIsInSpectatorMode() then NetworkSetInSpectatorMode(true, tp) end
                local c = GetEntityCoords(tp)
                SetEntityCoordsNoOffset(cache.ped, c.x, c.y, c.z - 15.0, false, false, false)
            elseif GetGameTimer() > nextPoll then
                -- target di luar jangkauan stream: ambil posisinya dari server lalu dekati
                nextPoll = GetGameTimer() + 1000
                local c = lib.callback.await('f_admin:spectatePos', false)
                if not c then break end
                NetworkSetInSpectatorMode(false, cache.ped)
                SetEntityCoordsNoOffset(cache.ped, c.x, c.y, c.z - 15.0, false, false, false)
            end
            if IsControlJustPressed(0, 177) then break end -- BACKSPACE
            Wait(0)
        end
        lib.hideTextUI()
        stop()
    end)
end)

RegisterNetEvent('f_admin:client:spectateEnded', function(pos)
    NetworkSetInSpectatorMode(false, cache.ped)
    if pos then SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, false, false, false, false) end
    hide(false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not target then return end
    NetworkSetInSpectatorMode(false, cache.ped)
    hide(false)
    lib.hideTextUI()
end)
