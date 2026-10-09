-- Donor darah (client): ox_target "Ambil Darah" untuk EMS, pop-up persetujuan untuk pendonor,
-- efek lemas setelah donor. Keputusan & item di server (server/blood.lua).
local cfg = require 'config.treatment'
local donor = cfg.donor
local busy = false

local function isOnDutyEms()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == 'ems' and job.onduty
end

local function takeBlood(target)
    if busy then return end
    busy = true
    exports.qbx_core:Notify('Menunggu persetujuan pendonor...', 'inform')

    local res = lib.callback.await('f_ambulancejob:server:donorStart', false, target)
    if not res or res.error then
        busy = false
        return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error')
    end

    local ped = GetPlayerPed(GetPlayerFromServerId(target))
    if ped ~= 0 then TaskTurnPedToFaceEntity(cache.ped, ped, 800) Wait(600) end

    local ok = lib.progressCircle({
        duration = res.duration,
        position = 'bottom',
        label = 'Mengambil darah...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = { dict = 'anim@heists@humane_labs@finale@keycards', clip = 'ped_a_enter_loop', flag = 49 },
        prop = { model = `prop_syringe_01`, bone = 18905, pos = vec3(0.11, 0.03, 0.01), rot = vec3(90.0, 0.0, -50.0) },
    })
    ClearPedTasks(cache.ped)

    if not ok then
        lib.callback.await('f_ambulancejob:server:donorCancel', false)
        busy = false
        return exports.qbx_core:Notify(locale('error.canceled'), 'error')
    end

    local done = lib.callback.await('f_ambulancejob:server:donorFinish', false)
    busy = false
    if not done or done.error then
        return exports.qbx_core:Notify(done and done.error or 'Gagal', 'error')
    end
    exports.qbx_core:Notify(('Darah golongan %s masuk Stok Gudang (stok Kantong Darah: %d)'):format(done.bloodtype, done.stock or 0), 'success', 7000)
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'f_ambulancejob:takeBlood',
        icon = 'fa-solid fa-droplet',
        label = 'Ambil Darah',
        distance = cfg.distance,
        items = donor.emptyBag,
        canInteract = function(entity)
            if busy or not isOnDutyEms() then return false end
            local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
            return (Player(serverId).state['f_medical:deathState'] or 1) == 1
        end,
        onSelect = function(data)
            takeBlood(GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity)))
        end,
    },
})

-- Pendonor: setuju / tolak. Menutup sendiri setelah consentTimeout detik (dianggap menolak).
lib.callback.register('f_ambulancejob:client:donorConsent', function(emsName, bloodLoss, timeout)
    local answered = false
    SetTimeout((timeout or 20) * 1000, function()
        if not answered then lib.closeAlertDialog() end
    end)
    local result = lib.alertDialog({
        header = 'Donor Darah',
        content = ('**%s** (EMS) ingin mengambil darahmu.\n\nDarahmu akan berkurang %d%% dan kamu akan lemas sebentar. Setuju?'):format(emsName, bloodLoss),
        centered = true,
        cancel = true,
        labels = { confirm = 'Setuju', cancel = 'Tolak' },
    })
    answered = true
    return result == 'confirm'
end)

-- Pendonor lemas: tidak bisa lari selama beberapa saat.
RegisterNetEvent('f_ambulancejob:client:donorWeak', function(seconds)
    if GetInvokingResource() then return end
    exports.qbx_core:Notify('Darahmu sudah diambil. Kamu lemas, istirahat sebentar.', 'inform', 7000)
    local untilTime = GetGameTimer() + (tonumber(seconds) or 120) * 1000
    CreateThread(function()
        while GetGameTimer() < untilTime do
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- lompat
            Wait(0)
        end
    end)
end)
