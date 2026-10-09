-- Panel "Periksa Kendaraan" (client): opsi ox_target di kendaraan, NUI, dan progress perbaikan.
-- Semua keputusan ada di server (server/panel.lua); client hanya menampilkan & menjalankan animasi.
local cfg = require 'config.shared'
local clientCfg = require 'config.client'

local openNet ---@type number? netId kendaraan yang sedang dibuka
local busy = false
local tabletObj ---@type number?

---Tablet di tangan selama panel terbuka.
local function startTablet()
    if tabletObj and DoesEntityExist(tabletObj) then return end
    local t = clientCfg.tablet
    local ped = cache.ped
    lib.requestAnimDict(t.dict, 5000)
    lib.requestModel(t.prop, 5000)
    local pos = GetEntityCoords(ped)
    tabletObj = CreateObject(joaat(t.prop), pos.x, pos.y, pos.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(joaat(t.prop))
    local p = t.placement
    AttachEntityToEntity(tabletObj, ped, GetPedBoneIndex(ped, t.bone), p[1], p[2], p[3], p[4], p[5], p[6], true, true, false, true, 1, true)
    TaskPlayAnim(ped, t.dict, t.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    RemoveAnimDict(t.dict)
end

local function stopTablet()
    if tabletObj and DoesEntityExist(tabletObj) then DeleteEntity(tabletObj) end
    tabletObj = nil
    StopAnimTask(cache.ped, clientCfg.tablet.dict, clientCfg.tablet.clip, 1.0)
end

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function nuiConfig()
    return {
        parts = cfg.parts, groups = cfg.groups, fluids = cfg.fluids, tyre = cfg.tyre, tyres = cfg.tyres,
        levels = cfg.levels, levelLabels = cfg.levelLabels, needs = cfg.needs,
        itemLabels = cfg.itemLabels, itemIcons = cfg.itemIcons,
    }
end

local function closePanel()
    if not openNet then return end
    openNet = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTablet()
end

local function showPanel(status)
    SendNUIMessage({ action = 'open', status = status, config = nuiConfig() })
    SetNuiFocus(true, true)
    startTablet()
end

local function openPanel(netId)
    if openNet or busy then return end
    local res = lib.callback.await('f_mechanicjob:server:panelOpen', false, netId)
    if not res or res.error then
        return exports.qbx_core:Notify(res and res.error or 'Gagal membuka data kendaraan', 'error')
    end
    openNet = netId
    showPanel(res.status)

    -- segarkan data & tutup kalau mekanik menjauh
    CreateThread(function()
        while openNet == netId do
            Wait(2000)
            if openNet ~= netId then break end
            if not busy then
                local status = lib.callback.await('f_mechanicjob:server:panelStatus', false, netId)
                if openNet ~= netId then break end
                if not status then
                    exports.qbx_core:Notify('Kendaraan terlalu jauh', 'error')
                    closePanel()
                    break
                end
                SendNUIMessage({ action = 'update', status = status })
            end
        end
    end)
end

local function labelFor(action, key)
    if action == 'all' then return 'Memperbaiki semua...' end
    if action == 'tyres' then return 'Mengganti ban...' end
    if action == 'tyre' then return 'Mengganti ban...' end
    local def = cfg.parts[key]
    if not def then return 'Memperbaiki...' end
    return (def.fluid and 'Mengisi %s...' or 'Memperbaiki %s...'):format(def.label:lower())
end

local function animFor(action, key)
    local kind = (action == 'tyre' or action == 'tyres') and 'tyre' or (action == 'part' and clientCfg.animOf[key]) or 'under'
    return clientCfg.anims[kind] or clientCfg.anims.under
end

local function runAction(action, key)
    local netId = openNet
    if not netId or busy then return end
    busy = true

    local res = lib.callback.await('f_mechanicjob:server:actionStart', false, netId, action, key)
    if not res or res.error then
        busy = false
        return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error')
    end

    -- panel & tablet disembunyikan selama animasi supaya progress bar & animasi memperbaiki terlihat
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    stopTablet()

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 then TaskTurnPedToFaceEntity(cache.ped, veh, 800) Wait(600) end

    local ok = lib.progressCircle({
        duration = res.duration,
        position = 'bottom',
        label = labelFor(action, key),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = animFor(action, key),
    })
    ClearPedTasks(cache.ped)

    if not ok then
        lib.callback.await('f_mechanicjob:server:actionCancel', false)
        busy = false
        exports.qbx_core:Notify('Perbaikan dibatalkan', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    local done = lib.callback.await('f_mechanicjob:server:actionFinish', false)
    busy = false
    if not done or done.error then
        exports.qbx_core:Notify(done and done.error or 'Gagal', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    exports.qbx_core:Notify('Perbaikan selesai', 'success')
    if openNet == netId then showPanel(done.status) end
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closePanel()
end)

RegisterNUICallback('action', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    CreateThread(function() runAction(data.action, data.key) end)
end)

-- Tab Tagihan: jawaban server langsung dikembalikan ke halaman
RegisterNUICallback('billingGet', function(_, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingGet', false, openNet) or { error = 'Gagal' })
end)

RegisterNUICallback('billingAdd', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingAdd', false, openNet, type(data) == 'table' and data.code or nil) or { error = 'Gagal' })
end)

RegisterNUICallback('billingSend', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    data = type(data) == 'table' and data or {}
    local res = lib.callback.await('f_mechanicjob:server:billingSend', false, openNet, data.target, data.lines or {}, data.channel)
    if res and res.sent then
        exports.qbx_core:Notify(res.channel == 'kasir' and ('Tagihan Rp %d masuk kasir atas nama %s'):format(res.sent, res.to or 'pelanggan')
            or ('Tagihan Rp %d dikirim ke HP %s'):format(res.sent, res.to or 'pelanggan'), 'success')
    end
    cb(res or { error = 'Gagal' })
end)

-- Tab Kustom: order kustom yang sudah lunas untuk kendaraan ini
RegisterNUICallback('customGet', function(_, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:customGet', false, openNet) or { error = 'Gagal' })
end)

local function runCustom(billId)
    local netId = openNet
    if not netId or busy then return end
    busy = true

    local res = lib.callback.await('f_mechanicjob:server:customStart', false, netId, billId)
    if not res or res.error then
        busy = false
        SendNUIMessage({ action = 'custom', data = { error = res and res.error or 'Gagal' } })
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    stopTablet()

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 then TaskTurnPedToFaceEntity(cache.ped, veh, 800) Wait(600) end

    local ok = lib.progressBar({
        duration = res.duration,
        position = 'bottom',
        label = 'Memasang modifikasi...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = clientCfg.customAnim,
    })
    ClearPedTasks(cache.ped)

    if not ok then
        lib.callback.await('f_mechanicjob:server:customCancel', false)
        busy = false
        exports.qbx_core:Notify('Pemasangan dibatalkan, modifikasi tidak dipasang', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    local done = lib.callback.await('f_mechanicjob:server:customFinish', false)
    busy = false
    if done and not done.error then exports.qbx_core:Notify(done.msg or 'Modifikasi terpasang', 'success')
    else exports.qbx_core:Notify(done and done.error or 'Gagal', 'error') end
    if openNet == netId then
        showPanel(nil)
        SendNUIMessage({ action = 'custom', data = done or { error = 'Gagal' } })
    end
end

RegisterNUICallback('customInstall', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    CreateThread(function() runCustom(tonumber(data.id)) end)
end)

RegisterNUICallback('billingDiscard', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingDiscard', false, openNet, type(data) == 'table' and data.id or nil) or { error = 'Gagal' })
end)

---Server meminta nilai mesin / body / tangki / ban bocor dari client pemegang fisika kendaraan
---(nilai di server sering tidak ter-update). MechNativeSnapshot ada di client/wear.lua.
lib.callback.register('f_mechanicjob:client:nativeSnap', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    return MechNativeSnapshot(veh)
end)

---Kendaraan dari netId yang fisikanya kita pegang (minta kontrol sebentar), atau nil.
local function controlled(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do Wait(50) end
        if not NetworkHasControlOfEntity(veh) then return end -- pemegang fisika yang menerapkan
    end
    return veh
end

---Command admin (/setkondisi, /rusakkan, /kondisipenuh): nilai bawaan GTA dalam persen.
RegisterNetEvent('f_mechanicjob:client:setNative', function(netId, v)
    if type(v) ~= 'table' then return end
    local veh = controlled(netId)
    if not veh then return end
    if v.fixAll then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
    end
    if v.engine then SetVehicleEngineHealth(veh, v.engine * 10.0) end
    if v.body then SetVehicleBodyHealth(veh, v.body * 10.0) end
    if v.tank then SetVehiclePetrolTankHealth(veh, v.tank * 10.0) end
    for _, idx in ipairs(v.burst or {}) do SetVehicleTyreBurst(veh, idx, false, 1000.0) end
end)

---Perbaikan bagian bawaan GTA. Dikirim server ke client pemegang fisika kendaraan (dan mekaniknya).
RegisterNetEvent('f_mechanicjob:client:applyNative', function(netId, native)
    if type(native) ~= 'table' then return end
    local veh = controlled(netId)
    if not veh then return end

    local fixed = {}
    for _, idx in ipairs(native.tyres or {}) do fixed[idx] = true end

    if native.body then
        -- SetVehicleFixed memulihkan semuanya (termasuk memasang roda yang lepas); kembalikan bagian
        -- yang tidak sedang diperbaiki
        local engine, tank = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh)
        local fuel, dirt = GetVehicleFuelLevel(veh), GetVehicleDirtLevel(veh)
        local burst = {}
        for idx = 0, 7 do
            if IsVehicleTyreBurst(veh, idx, false) and not fixed[idx] then burst[#burst + 1] = idx end
        end
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        if not native.engine then SetVehicleEngineHealth(veh, engine) end
        if not native.tank then SetVehiclePetrolTankHealth(veh, tank) end
        for i = 1, #burst do SetVehicleTyreBurst(veh, burst[i], false, 1000.0) end
        SetVehicleFuelLevel(veh, fuel)
        SetVehicleDirtLevel(veh, dirt)
    end
    if native.engine then
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
    end
    if native.tank then SetVehiclePetrolTankHealth(veh, 1000.0) end
    for idx in pairs(fixed) do SetVehicleTyreFixed(veh, idx) end
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_mechanicjob:inspect',
        icon = 'fa-solid fa-screwdriver-wrench',
        label = 'Periksa Kendaraan',
        distance = cfg.distance,
        canInteract = function(entity)
            if not isMechanic() or openNet or busy then return false end
            local class = GetVehicleClass(entity)
            return class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 and class ~= 21
        end,
        onSelect = function(data)
            openPanel(NetworkGetNetworkIdFromEntity(data.entity))
        end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if openNet then SetNuiFocus(false, false) end
    if tabletObj and DoesEntityExist(tabletObj) then DeleteEntity(tabletObj) end
end)
