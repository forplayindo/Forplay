-- Tampilan & modifikasi kendaraan pribadi: SERVER YANG MENENTUKAN.
--
-- Masalah lama: garasi (f_garages), f_vipgarage, dan jual-beli (f_vehiclesales) menyimpan
-- lib.getVehicleProperties dari CLIENT ke player_vehicles.mods. Kalau client itu belum menerima
-- modif terbaru (baru dipasang mekanik, sinkron telat, kendaraan valet yang propertinya dipasang
-- oleh client yang bukan pemilik entity), database tertimpa -> modif kembali ke asal / berubah.
-- Cheater juga bisa menyuntik modif lewat data itu.
--
-- Aturan sekarang (MergeClientProps):
--  - Kondisi (bensin, kesehatan, kotor, kaca/pintu/ban rusak) diambil dari client.
--  - Modif & tampilan diambil dari database; hanya bengkel (f_mechanicjob) / admin yang mengubahnya.
--  - Tampilan dasar yang BELUM tercatat (mobil baru dari dealer belum punya warna tersimpan)
--    diisi sekali dari client, setelah itu terkunci.
-- EnsureAppearance: setelah kendaraan muncul, pasang ulang tampilan dari database sekali
-- (jaring pengaman kalau properti saat spawn tidak terpasang sempurna).

local CONDITION = {
    bodyHealth = true, engineHealth = true, tankHealth = true, fuelLevel = true, oilLevel = true,
    dirtLevel = true, windows = true, doors = true, tyres = true,
}

-- boleh diisi dari client HANYA kalau database belum punya nilainya
local BASE = {
    color1 = true, color2 = true, pearlescentColor = true, wheelColor = true, interiorColor = true,
    dashboardColor = true, paintType1 = true, paintType2 = true, extras = true, livery = true,
    windowTint = true, plateIndex = true, xenonColor = true, neonColor = true, tyreSmokeColor = true,
}

local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, t = pcall(json.decode, raw)
    return ok and type(t) == 'table' and t or {}
end

---@param vehicleId integer
---@param client table? properti dari client (lib.getVehicleProperties)
---@return table? props properti yang aman disimpan, nil kalau kendaraan tidak ada di player_vehicles
local function mergeClientProps(vehicleId, client)
    local row = vehicleId and MySQL.single.await('SELECT mods, plate, hash FROM player_vehicles WHERE id = ?', { vehicleId })
    if not row then return end
    local props = decode(row.mods)
    client = type(client) == 'table' and client or {}
    for k in pairs(CONDITION) do
        if client[k] ~= nil then props[k] = client[k] end
    end
    for k in pairs(BASE) do
        if props[k] == nil and client[k] ~= nil then props[k] = client[k] end
    end
    props.plate = props.plate or row.plate
    props.model = props.model or tonumber(row.hash)
    return props
end

exports('MergeClientProps', mergeClientProps)

---Properti tampilan saja (tanpa kondisi), untuk dipasang ulang ke kendaraan.
local function appearanceOf(props)
    local out = {}
    for k, v in pairs(props) do
        if not CONDITION[k] and k ~= 'model' and k ~= 'lockState' then out[k] = v end
    end
    return out
end

---Pasang ulang tampilan dari database ke kendaraan yang baru muncul (lewat state bag ox_lib,
---diterapkan oleh pemilik entity). Sekali per spawn, jadi ringan.
---@param veh integer entity
---@param vehicleId? integer
---@param delay? integer ms
local function ensureAppearance(veh, vehicleId, delay)
    CreateThread(function()
        Wait(delay or 1500)
        if not DoesEntityExist(veh) then return end
        vehicleId = vehicleId or Entity(veh).state.vehicleid
        if not vehicleId then return end
        local props = decode(MySQL.scalar.await('SELECT mods FROM player_vehicles WHERE id = ?', { vehicleId }))
        local look = appearanceOf(props)
        if next(look) and DoesEntityExist(veh) then
            Entity(veh).state:set('ox_lib:setVehicleProperties', look, true)
        end
    end)
end

exports('EnsureAppearance', ensureAppearance)
