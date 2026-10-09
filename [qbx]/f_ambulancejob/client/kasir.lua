-- Kasir EMS (client): ox_target di setiap titik kasir, NUI panel #kasir.
--  "Kasir (Bayar Tagihan)" untuk semua orang · "Kasir EMS (Petugas)" untuk EMS bertugas.
-- Semua keputusan di server (server/kasir.lua, server/stock.lua).
local cfg = require 'config.stock'

local open = false      ---@type false|'patient'|'staff'

local function isOnDutyEms()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == 'ems' and job.onduty
end

local function nearestKasir()
    local pos, best = GetEntityCoords(cache.ped), math.huge
    for _, k in ipairs(cfg.kasir) do
        best = math.min(best, #(pos - k.coords))
    end
    return best
end

local function closeKasir()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'kasirClose' })
end

local CALLBACK = { patient = 'f_ambulancejob:server:kasirPatient', staff = 'f_ambulancejob:server:kasirStaff' }

local function openKasir(mode)
    if open then return end
    local data = lib.callback.await(CALLBACK[mode], false)
    if not data or data.error then
        return exports.qbx_core:Notify(data and data.error or 'Kasir tidak tersedia', 'error')
    end
    open = mode
    SendNUIMessage({ action = 'kasirOpen', mode = mode, data = data })
    SetNuiFocus(true, true)

    -- tutup kalau menjauh; daftar disegarkan berkala (status pasien dekat / tagihan baru)
    CreateThread(function()
        local tick = 0
        while open == mode do
            Wait(1000)
            if nearestKasir() > cfg.menuDistance or (mode == 'staff' and not isOnDutyEms()) then closeKasir() break end
            tick += 1
            if tick % 5 == 0 then
                local fresh = lib.callback.await(CALLBACK[mode], false)
                if open == mode and fresh and not fresh.error then SendNUIMessage({ action = 'kasirUpdate', data = fresh }) end
            end
        end
    end)
end

RegisterNUICallback('ksClose', function(_, cb) cb(1) closeKasir() end)

---Teruskan aksi NUI ke server (hanya untuk mode menu yang sedang terbuka).
local function relay(name, mode, callback, ...)
    local args = { ... }
    RegisterNUICallback(name, function(data, cb)
        if open ~= mode then return cb({ error = 'Menu tidak terbuka' }) end
        local params = {}
        for i, key in ipairs(args) do params[i] = type(data) == 'table' and data[key] or nil end
        cb(lib.callback.await(callback, false, table.unpack(params, 1, #args)) or { error = 'Gagal' })
    end)
end

relay('ksPay', 'patient', 'f_ambulancejob:server:kasirPay', 'id', 'method')
relay('ksClaim', 'patient', 'f_ambulancejob:server:kasirClaim', 'id')
relay('ksApprove', 'staff', 'f_ambulancejob:server:kasirApprove', 'id')
relay('ksCancel', 'staff', 'f_ambulancejob:server:kasirCancel', 'id')
relay('ksCollect', 'staff', 'f_ambulancejob:server:kasirCollect', 'id')
relay('ksBuy', 'staff', 'f_ambulancejob:server:supplierBuy', 'cart')
relay('ksPrices', 'staff', 'f_ambulancejob:server:kasirPrices', 'changes')
relay('ksLimits', 'staff', 'f_ambulancejob:server:kasirLimits', 'withEms', 'withoutEms')

for i, k in ipairs(cfg.kasir) do
    exports.ox_target:addBoxZone({
        name = 'f_ambulancejob:kasir:' .. i,
        coords = k.coords,
        size = k.size,
        rotation = k.rotation or 0,
        options = {
            {
                name = 'kasir_patient',
                icon = 'fa-solid fa-file-invoice-dollar',
                label = 'Kasir (Bayar Tagihan)',
                distance = 2.5,
                onSelect = function() openKasir('patient') end,
            },
            {
                name = 'kasir_staff',
                icon = 'fa-solid fa-cash-register',
                label = 'Kasir EMS (Petugas)',
                distance = 2.5,
                canInteract = isOnDutyEms,
                onSelect = function() openKasir('staff') end,
            },
        },
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and open then SetNuiFocus(false, false) end
end)
