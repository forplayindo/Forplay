-- Panel "Cek Pasien" (client): opsi ox_target di badan player, NUI, dan progress bar tindakan.
-- Semua keputusan ada di server (server/patient.lua); client hanya menampilkan & menjalankan animasi.
local cfg = require 'config.treatment'

local openTarget  ---@type number? server id pasien yang sedang dibuka
local busy = false

-- animasi tiap tindakan
local ANIMS = {
    part = { scenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD' },
    bleed = { scenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD' },
    all = { scenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD' },
    painkiller = { dict = 'mp_common', clip = 'givetake1_a' },
    revive = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
    transfusion = { scenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD' },
    crutch = { dict = 'mp_common', clip = 'givetake1_a' },
}

local LABELS = {
    part = 'Mengobati %s...',
    bleed = 'Menghentikan pendarahan...',
    all = 'Mengobati semua luka...',
    painkiller = 'Memberi painkiller...',
    revive = 'Melakukan CPR...',
    transfusion = 'Transfusi darah...',
    crutch = 'Memberikan Crutch...',
}

local function isOnDutyEms()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == 'ems' and job.onduty
end

local function closePanel()
    if not openTarget then return end
    local target = openTarget
    openTarget = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    -- countdown tergeletak pasien lanjut lagi
    lib.callback('f_ambulancejob:server:patientClose', false, function() end, target)
end

local function showPanel(status)
    SendNUIMessage({ action = 'open', status = status, config = {
        bodyParts = cfg.bodyParts,
        severityLabels = cfg.severityLabels,
        bleedLabels = cfg.bleedLabels,
        heavyBleed = cfg.heavyBleed,
        critical = cfg.blood.critical,
    } })
    SetNuiFocus(true, true)
end

local function openPanel(target)
    if openTarget or busy then return end
    local res = lib.callback.await('f_ambulancejob:server:patientOpen', false, target)
    if not res or res.error then
        return exports.qbx_core:Notify(res and res.error or 'Gagal membuka data pasien', 'error')
    end
    openTarget = target
    showPanel(res.status)

    -- segarkan data (pendarahan berjalan, countdown) & tutup kalau pasien menjauh
    CreateThread(function()
        while openTarget == target do
            Wait(2000)
            if openTarget ~= target then break end
            if not busy then
                local status = lib.callback.await('f_ambulancejob:server:patientStatus', false, target)
                if openTarget ~= target then break end
                if not status then
                    exports.qbx_core:Notify('Pasien terlalu jauh', 'error')
                    closePanel()
                    break
                end
                SendNUIMessage({ action = 'update', status = status })
            end
        end
    end)
end

local function runAction(action, part)
    local target = openTarget
    if not target or busy then return end
    busy = true

    local res = lib.callback.await('f_ambulancejob:server:actionStart', false, target, action, part)
    if not res or res.error then
        busy = false
        return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error')
    end

    -- panel disembunyikan selama animasi supaya progress bar & animasi terlihat
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    local label = LABELS[action]
    if action == 'part' then label = label:format((cfg.bodyParts[part] and cfg.bodyParts[part].label or ''):lower()) end

    local ped = GetPlayerPed(GetPlayerFromServerId(target))
    if ped ~= 0 then TaskTurnPedToFaceEntity(cache.ped, ped, 800) Wait(600) end

    local ok = lib.progressCircle({
        duration = res.duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = ANIMS[action],
    })
    ClearPedTasks(cache.ped)

    if not ok then
        lib.callback.await('f_ambulancejob:server:actionCancel', false)
        busy = false
        exports.qbx_core:Notify(locale('error.canceled'), 'error')
        if openTarget == target then showPanel(nil) end
        return
    end

    local done = lib.callback.await('f_ambulancejob:server:actionFinish', false)
    busy = false
    if not done or done.error then
        exports.qbx_core:Notify(done and done.error or 'Gagal', 'error')
        if openTarget == target then showPanel(nil) end
        return
    end

    exports.qbx_core:Notify('Tindakan selesai', 'success')
    if openTarget == target then showPanel(done.status) end
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closePanel()
end)

-- Tab Tagihan: jawaban server langsung dikembalikan ke halaman (respons fetch)
RegisterNUICallback('billingGet', function(_, cb)
    if not openTarget then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_ambulancejob:server:billingGet', false, openTarget) or { error = 'Gagal' })
end)

RegisterNUICallback('billingSend', function(data, cb)
    if not openTarget then return cb({ error = 'Panel tidak terbuka' }) end
    local res = lib.callback.await('f_ambulancejob:server:billingSend', false, openTarget,
        type(data) == 'table' and data.lines or {}, type(data) == 'table' and data.mode or nil)
    if res and res.sent then
        exports.qbx_core:Notify(res.mode == 'kasir' and 'Tagihan masuk Kasir. Arahkan pasien membayar di kasir.'
            or 'Tagihan dikirim ke HP pasien', 'success')
    end
    cb(res or { error = 'Gagal' })
end)

RegisterNUICallback('billingDiscard', function(data, cb)
    if not openTarget then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_ambulancejob:server:billingDiscard', false, openTarget, type(data) == 'table' and data.id or nil) or { error = 'Gagal' })
end)

RegisterNUICallback('action', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    CreateThread(function() runAction(data.action, data.part) end)
end)

exports.ox_target:addGlobalPlayer({
    {
        name = 'f_ambulancejob:checkPatient',
        icon = 'fa-solid fa-stethoscope',
        label = 'Cek Pasien',
        distance = cfg.distance,
        canInteract = function()
            return isOnDutyEms() and not openTarget and not busy
        end,
        onSelect = function(data)
            local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
            openPanel(target)
        end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if openTarget then SetNuiFocus(false, false) end
end)
