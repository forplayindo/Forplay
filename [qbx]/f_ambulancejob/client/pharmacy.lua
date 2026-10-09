-- Apotek (client): ox_target "Pesan Obat" di setiap meja apotek, NUI panel #pharmacy.
-- Warga hanya memesan; pembayaran di Kasir. Semua keputusan di server (server/pharmacy.lua).
local cfg = require 'config.pharmacy'

local open = false

local function nearestCounter()
    local pos, best = GetEntityCoords(cache.ped), math.huge
    for _, c in ipairs(cfg.counters) do best = math.min(best, #(pos - c.coords)) end
    return best
end

local function closePharmacy()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'pharmacyClose' })
end

local function openPharmacy()
    if open then return end
    local data = lib.callback.await('f_ambulancejob:server:pharmacyMenu', false)
    if not data or data.error then
        return exports.qbx_core:Notify(data and data.error or 'Apotek tidak tersedia', 'error')
    end
    open = true
    SendNUIMessage({ action = 'pharmacyOpen', data = data })
    SetNuiFocus(true, true)

    CreateThread(function()
        while open do
            Wait(1000)
            if nearestCounter() > 8.0 then closePharmacy() break end
        end
    end)
end

RegisterNUICallback('phClose', function(_, cb) cb(1) closePharmacy() end)

RegisterNUICallback('phMenu', function(_, cb)
    cb(lib.callback.await('f_ambulancejob:server:pharmacyMenu', false) or { error = 'Gagal' })
end)

RegisterNUICallback('phOrder', function(data, cb)
    if not open then return cb({ error = 'Menu tidak terbuka' }) end
    local res = lib.callback.await('f_ambulancejob:server:pharmacyOrder', false, data.cart)
    if res and res.ordered then
        exports.qbx_core:Notify(('Pesanan #%d dibuat. Bayar di Kasir rumah sakit dalam %d menit.'):format(res.ordered.id, res.timeout), 'success', 8000)
    end
    cb(res or { error = 'Gagal' })
end)

for i, c in ipairs(cfg.counters) do
    exports.ox_target:addBoxZone({
        name = 'f_ambulancejob:pharmacy:' .. i,
        coords = c.coords,
        size = c.size,
        rotation = c.rotation or 0,
        options = {
            {
                name = 'pharmacy_order',
                icon = 'fa-solid fa-prescription-bottle-medical',
                label = 'Pesan Obat',
                distance = 2.5,
                onSelect = openPharmacy,
            },
        },
    })
end

-- blip apotek dipindah ke f_blips

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and open then SetNuiFocus(false, false) end
end)
