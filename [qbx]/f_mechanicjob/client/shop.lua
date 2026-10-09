-- Toko bengkel (client): ox_target di meja bengkel untuk warga ("Beli Perlengkapan") dan mekanik
-- ("Toko Bengkel (Mekanik)"), NUI panel #shop. Semua keputusan di server (server/shop.lua).
local cfg = require 'config.shop'
local jobCfg = require 'config.shared'

local open = false ---@type false|'customer'|'staff'

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == jobCfg.jobType and job.onduty
end

local function closeShop()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'shopClose' })
end

local function openShop(mode)
    if open then return end
    local data = lib.callback.await(mode == 'staff' and 'f_mechanicjob:server:shopStaff' or 'f_mechanicjob:server:shopMenu', false)
    if not data or data.error then
        return exports.qbx_core:Notify(data and data.error or 'Toko tidak tersedia', 'error')
    end
    open = mode
    SendNUIMessage({ action = 'shopOpen', mode = mode, data = data })
    SetNuiFocus(true, true)

    CreateThread(function()
        local tick = 0
        while open == mode do
            Wait(1000)
            if #(GetEntityCoords(cache.ped) - cfg.counter) > 8.0 then closeShop() break end
            tick += 1
            if mode == 'staff' and tick % 3 == 0 then
                local fresh = lib.callback.await('f_mechanicjob:server:shopStaff', false)
                if open == 'staff' and fresh and not fresh.error then SendNUIMessage({ action = 'shopUpdate', data = fresh }) end
            end
        end
    end)
end

RegisterNUICallback('shClose', function(_, cb) cb(1) closeShop() end)

RegisterNUICallback('shOrder', function(data, cb)
    if open ~= 'customer' then return cb({ error = 'Menu tidak terbuka' }) end
    local res = lib.callback.await('f_mechanicjob:server:shopOrder', false, data.cart, data.method)
    if res and res.ok then
        exports.qbx_core:Notify(res.paid
            and ('Pesanan #%s lunas. Tunggu mekanik menyerahkan barang.'):format(res.code)
            or ('Invoice pesanan #%s dikirim ke HP. Bayar lewat Bank dalam %d menit.'):format(res.code, res.timeout), 'success', 7000)
    end
    cb(res or { error = 'Gagal' })
end)

RegisterNUICallback('shCancel', function(_, cb)
    cb(lib.callback.await('f_mechanicjob:server:shopCancel', false) or { error = 'Gagal' })
end)

RegisterNUICallback('shMenu', function(_, cb)
    cb(lib.callback.await('f_mechanicjob:server:shopMenu', false) or { error = 'Gagal' })
end)

RegisterNUICallback('shServe', function(data, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:shopServe', false, data.code) or { error = 'Gagal' })
end)

RegisterNUICallback('shReject', function(data, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:shopReject', false, data.code) or { error = 'Gagal' })
end)

RegisterNUICallback('shSetLimit', function(data, cb)
    if open ~= 'staff' then return cb({ error = 'Menu tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:shopSetLimit', false, data.value) or { error = 'Gagal' })
end)

exports.ox_target:addBoxZone({
    name = 'f_mechanicjob:shop',
    coords = cfg.counter,
    size = cfg.counterSize,
    rotation = 0,
    options = {
        {
            name = 'shop_buy',
            icon = 'fa-solid fa-toolbox',
            label = 'Beli Perlengkapan',
            distance = 2.5,
            onSelect = function() openShop('customer') end,
        },
        {
            name = 'shop_staff',
            icon = 'fa-solid fa-user-gear',
            label = 'Toko Bengkel (Mekanik)',
            distance = 2.5,
            canInteract = isMechanic,
            onSelect = function() openShop('staff') end,
        },
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and open then SetNuiFocus(false, false) end
end)
