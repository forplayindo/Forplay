-- Lab Forensik (panel NUI html/lab.*). Polisi on-duty memilih kantong bukti, progress 10 detik,
-- lalu server mencocokkan DNA / sidik jari ke pemiliknya (server/lab.lua).

local sharedConfig = require 'config.shared'
local labOpen = false

local function isLeoOnDuty()
    local job = QBX.PlayerData.job
    return job ~= nil and job.type == 'leo' and job.onduty
end

local function closeLab()
    labOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'labClose' })
end

local function openLab()
    local bags = lib.callback.await('f_police:server:labBags', false)
    if not bags then return end
    labOpen = true
    SendNUIMessage({ type = 'labOpen', data = bags })
    SetNuiFocus(true, true)
end

RegisterNUICallback('labClose', function(_, cb)
    closeLab()
    cb(1)
end)

RegisterNUICallback('labReopen', function(_, cb)
    cb(1)
    local bags = lib.callback.await('f_police:server:labBags', false)
    if not bags then return closeLab() end
    SendNUIMessage({ type = 'labOpen', data = bags })
end)

RegisterNUICallback('labAnalyze', function(data, cb)
    if not labOpen or not lib.callback.await('f_police:server:labStart', false, data.slot) then
        return cb({ ok = false })
    end
    cb({ ok = true })

    -- sembunyikan panel selama pemeriksaan
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'labClose' })

    local done = lib.progressCircle({
        duration = 10000,
        position = 'bottom',
        label = 'Memeriksa bukti...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_parking_meter@male@idle_a', clip = 'idle_a', flag = 49 },
    })
    if not done then
        lib.callback.await('f_police:server:labCancel', false)
        labOpen = false
        return
    end

    local result = lib.callback.await('f_police:server:labResult', false)
    if not result then
        labOpen = false
        return exports.qbx_core:Notify('Pemeriksaan gagal. Pastikan kamu tetap di lab dan bukti masih dibawa.', 'error')
    end
    SendNUIMessage({ type = 'labResult', data = result })
    SetNuiFocus(true, true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and labOpen then SetNuiFocus(false, false) end
end)

CreateThread(function()
    for i, coords in ipairs(sharedConfig.locations.lab) do
        exports.ox_target:addBoxZone({
            name = ('f_police_lab_%d'):format(i),
            coords = coords,
            size = vec3(1.5, 1.5, 2.0),
            options = {{
                name = 'f_police:lab',
                icon = 'fa-solid fa-flask',
                label = 'Lab Forensik',
                distance = 2.0,
                canInteract = isLeoOnDuty,
                onSelect = openLab,
            }},
        })
    end
end)
