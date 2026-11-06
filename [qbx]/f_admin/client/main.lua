local nuiOpen = false   -- false | 'admin' | 'lapor'

-- Hanya callback server ini yang boleh dipanggil dari NUI (callback tak dikenal tidak pernah membalas).
local ALLOWED = {}
for _, n in ipairs({
    'home', 'staff_list', 'staff_add', 'staff_role', 'staff_remove', 'perms_list', 'perms_set',
    'logs_get', 'logs_set', 'logs_test', 'players', 'player', 'player_act', 'set_data', 'jobs', 'set_job',
    'items', 'give_items', 'vehicles', 'give_vehicle', 'veh_spawn', 'veh_save', 'veh_plate', 'money', 'weapons',
    'self_back', 'world', 'weather', 'time', 'radio', 'stash',
    'reports', 'report_open', 'report_claim', 'report_reply', 'report_close', 'bans', 'unban',
    'pets', 'pets_decide', 'wtune', 'wtune_save',
    'lapor_mine', 'lapor_send', 'lapor_read', 'lapor_reply',
}) do ALLOWED[n] = true end
local LAPOR = { lapor_mine = true, lapor_send = true, lapor_read = true, lapor_reply = true }

-- aksi lokal (client) yang dipanggil NUI, diisi client/self.lua & client/dev.lua
ACT = {}

function CloseNui()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if ClearWeaponPreview then ClearWeaponPreview() end
end

local function notify(msg, kind) lib.notify({ description = msg, type = kind or 'inform' }) end
Notify = notify

RegisterNetEvent('f_admin:client:open', function()
    if nuiOpen then return end
    local res = lib.callback.await('f_admin:open', false)
    if not res or not res.ok then return notify(res and res.msg or 'Gagal membuka panel admin.', 'error') end
    nuiOpen = 'admin'
    res.state = SelfState()
    SendNUIMessage({ action = 'open', data = res })
    SetNuiFocus(true, true)
end)

-- /lapor tanpa isi: buka form (open = true), atau segarkan kalau sedang terbuka
RegisterNetEvent('f_admin:client:lapor', function(open)
    if open then
        if nuiOpen then return end
        nuiOpen = 'lapor'
        SendNUIMessage({ action = 'lapor' })
        SetNuiFocus(true, true)
    elseif nuiOpen == 'lapor' then
        SendNUIMessage({ action = 'laporRefresh' })
    end
end)

RegisterNetEvent('f_admin:client:reports', function(count)
    if nuiOpen == 'admin' then SendNUIMessage({ action = 'reports', count = count }) end
end)

RegisterNUICallback('close', function(_, cb)
    nuiOpen = false
    SetNuiFocus(false, false)
    if ClearWeaponPreview then ClearWeaponPreview() end
    cb(1)
end)

RegisterNUICallback('req', function(d, cb)
    if type(d) ~= 'table' or not ALLOWED[d.name] then return cb({ ok = false, msg = 'Permintaan tidak dikenal.' }) end
    if nuiOpen == 'lapor' and not LAPOR[d.name] then return cb({ ok = false }) end
    local res = lib.callback.await('f_admin:' .. d.name, false, d.data) or { ok = false, msg = 'Tidak ada respon server.' }
    if res.close then CloseNui() end
    cb(res)
end)

RegisterNUICallback('act', function(d, cb)
    local fn = type(d) == 'table' and nuiOpen == 'admin' and ACT[d.name]
    if not fn then return cb({ ok = false, msg = 'Aksi tidak dikenal.' }) end
    local res = fn(d.data or {}) or { ok = true }
    if res.close then CloseNui() end
    cb(res)
end)

---------------------------------------------------------------- dari server
lib.callback.register('f_admin:confirm', function(msg)
    return lib.alertDialog({ header = 'Konfirmasi', content = msg, centered = true, cancel = true, labels = { confirm = 'Ya', cancel = 'Batal' } }) == 'confirm'
end)

lib.callback.register('f_admin:vehprops', function()
    if not cache.vehicle then return end
    local info = exports.qbx_core:GetVehiclesByHash()[GetEntityModel(cache.vehicle)]
    return info and info.model, lib.getVehicleProperties(cache.vehicle)
end)

RegisterNetEvent('f_admin:client:kill', function()
    SetEntityHealth(cache.ped, 0)
end)

RegisterNetEvent('f_admin:client:fixveh', function()
    local veh = cache.vehicle
    if not veh then return end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    notify('Kendaraanmu diperbaiki staff.', 'success')
end)

RegisterNetEvent('f_admin:client:setModel', function(skin)
    local model = joaat(skin)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return notify('Model tidak valid.', 'error') end
    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    SetPedRandomComponentVariation(cache.ped, 1)
    SetModelAsNoLongerNeeded(model)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and nuiOpen then SetNuiFocus(false, false) end
end)
