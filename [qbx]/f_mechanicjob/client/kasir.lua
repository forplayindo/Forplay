-- Kasir bengkel (client): ox_target di meja kasir. Warga "Bayar Tagihan", mekanik on duty "Menu Kasir".
-- Titik Gudang Bengkel (mekanik): Setor Bahan ke Stok + Ambil Tas Perkakas.
-- Titik Supplier (mekanik): lihat Stok Gudang, Manager membeli bahan baku ke supplier.
-- NUI panel #kasir (html/kasir.js). Semua keputusan di server (server/kasir.lua, server/stock.lua).
local cfg = require 'config.shared'
local SC = require 'config.stock'

local open = false ---@type false|'customer'|'staff'|'gudang'|'supplier'
local OPEN_CB = { customer = 'kasirMine', staff = 'kasirStaff', gudang = 'gudangGet', supplier = 'stockGet' }
local POINT = { gudang = SC.point, supplier = SC.supplier } -- selain ini: meja kasir

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function closeKasir()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'kasirClose' })
end

local function openKasir(mode)
    if open then return end
    local data = lib.callback.await('f_mechanicjob:server:' .. OPEN_CB[mode], false)
    if not data or data.error then
        return exports.qbx_core:Notify(data and data.error or 'Kasir tidak tersedia', 'error')
    end
    open = mode
    SendNUIMessage({ action = 'kasirOpen', mode = mode, data = data })
    SetNuiFocus(true, true)

    -- tutup kalau menjauh dari meja kasir / gudang / supplier (cek ringan tiap detik selama menu terbuka)
    local point = POINT[mode] or cfg.cashier
    local center, maxDist = point.coords, point.distance + 3.0
    CreateThread(function()
        while open == mode do
            Wait(1000)
            if #(GetEntityCoords(cache.ped) - center) > maxDist then closeKasir() break end
        end
    end)
end

local function call(name, ...)
    return lib.callback.await('f_mechanicjob:server:' .. name, false, ...) or { error = 'Gagal' }
end

RegisterNUICallback('ksClose', function(_, cb) cb(1) closeKasir() end)

RegisterNUICallback('ksMine', function(_, cb)
    if open ~= 'customer' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('kasirMine'))
end)

RegisterNUICallback('ksRemoveLine', function(data, cb)
    if open ~= 'customer' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('kasirRemoveLine', data.bill, data.line))
end)

RegisterNUICallback('ksPay', function(data, cb)
    if open ~= 'customer' then return cb({ error = 'Menu tidak terbuka' }) end
    local res = call('kasirPay', data.bill, data.method)
    if res.msg then exports.qbx_core:Notify(res.msg, 'success') end
    cb(res)
end)

RegisterNUICallback('ksCancelTransfer', function(data, cb)
    if open ~= 'customer' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('kasirCancelTransfer', data.bill))
end)

RegisterNUICallback('ksStaff', function(_, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('kasirStaff'))
end)

RegisterNUICallback('ksDelete', function(data, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('kasirDelete', data.bill))
end)

RegisterNUICallback('ksPrices', function(_, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('pricesGet'))
end)

RegisterNUICallback('ksPricesSave', function(data, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('pricesSave', data.changes))
end)

RegisterNUICallback('ksSupplier', function(_, cb)
    if open ~= 'supplier' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('stockGet'))
end)

RegisterNUICallback('ksGudang', function(_, cb)
    if open ~= 'gudang' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('gudangGet'))
end)

RegisterNUICallback('ksDeposit', function(data, cb)
    if open ~= 'gudang' then return cb({ error = 'Menu tidak terbuka' }) end
    local res = call('gudangDeposit', data.cart)
    if res.msg then exports.qbx_core:Notify(res.msg, 'success') end
    cb(res)
end)

RegisterNUICallback('ksBag', function(_, cb)
    if open ~= 'gudang' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(call('gudangBag'))
end)

RegisterNUICallback('ksSupplierBuy', function(data, cb)
    if open ~= 'supplier' then return cb({ error = 'Menu tidak terbuka' }) end
    local res = call('supplierBuy', data.cart)
    if res.msg then exports.qbx_core:Notify(res.msg, 'success') end
    cb(res)
end)

exports.ox_target:addSphereZone({
    name = 'f_mechanicjob:kasir',
    coords = cfg.cashier.coords,
    radius = cfg.cashier.radius,
    options = {
        {
            name = 'kasir_pay',
            icon = 'fa-solid fa-cash-register',
            label = 'Bayar Tagihan Bengkel',
            distance = cfg.cashier.distance,
            onSelect = function() openKasir('customer') end,
        },
        {
            name = 'kasir_staff',
            icon = 'fa-solid fa-user-gear',
            label = 'Menu Kasir (Mekanik)',
            distance = cfg.cashier.distance,
            canInteract = isMechanic,
            onSelect = function() openKasir('staff') end,
        },
    },
})

exports.ox_target:addSphereZone({
    name = 'f_mechanicjob:gudang',
    coords = SC.point.coords,
    radius = SC.point.radius,
    options = {
        {
            name = 'gudang_open',
            icon = 'fa-solid fa-warehouse',
            label = 'Gudang Bengkel (Setor Bahan)',
            distance = SC.point.distance,
            canInteract = isMechanic,
            onSelect = function() openKasir('gudang') end,
        },
        {
            name = 'gudang_bag',
            icon = 'fa-solid fa-toolbox',
            label = 'Ambil Tas Perkakas',
            distance = SC.point.distance,
            canInteract = isMechanic,
            onSelect = function()
                local res = lib.callback.await('f_mechanicjob:server:gudangBag', false)
                if res and res.error then exports.qbx_core:Notify(res.error, 'error') end
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    name = 'f_mechanicjob:supplier',
    coords = SC.supplier.coords,
    radius = SC.supplier.radius,
    options = {
        {
            name = 'supplier_open',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Supplier Bahan Baku',
            distance = SC.supplier.distance,
            canInteract = isMechanic,
            onSelect = function() openKasir('supplier') end,
        },
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and open then SetNuiFocus(false, false) end
end)
