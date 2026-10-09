-- BOLO di peta: kendaraan bertanda BOLO di MDT (f_phone) muncul sebagai blip di peta polisi on-duty.
-- Ringan: tidak bekerja sama sekali saat tidak ada BOLO atau tidak ada polisi on-duty; posisi dicari
-- tiap 30 detik, mobil yang sudah ketemu dicek ulang tanpa memindai semua kendaraan.

local INTERVAL = 30000

---@type table<string, { entity?: integer, pending?: boolean }> plat -> data BOLO
local bolos = {}
local loaded = false
---@type table<integer, true> polisi yang menerima blip putaran terakhir
local receivers = {}

local function norm(plate)
    return ((tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' '):upper()))
end

local function dutyCops()
    local list = {}
    for src, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if IsLeoAndOnDuty(player) then list[#list + 1] = src end
    end
    return list
end

local function notifyCops(msg, kind)
    for _, src in ipairs(dutyCops()) do
        exports.qbx_core:Notify(src, msg, kind or 'inform', 8000)
    end
end

local function loadBolos()
    if loaded or GetResourceState('f_phone') ~= 'started' then return end
    local ok, rows = pcall(MySQL.query.await, 'SELECT plate FROM phone_mdt_vehicles WHERE bolo = 1')
    if not ok then return end
    loaded = true
    for _, row in ipairs(rows or {}) do
        local plate = norm(row.plate)
        bolos[plate] = bolos[plate] or {}
    end
end

local function sendBlips(list)
    local now = {}
    for _, src in ipairs(dutyCops()) do
        now[src] = true
        TriggerClientEvent('f_police:client:boloBlips', src, list)
    end
    for src in pairs(receivers) do
        if not now[src] and GetPlayerName(src) then TriggerClientEvent('f_police:client:boloBlips', src, {}) end
    end
    receivers = now
end

local function tick()
    loadBolos()
    if not next(bolos) then
        if next(receivers) then sendBlips({}) end
        return
    end
    if #dutyCops() == 0 then return end

    -- mobil yang sudah ketemu cukup dicek ulang; pindai semua kendaraan hanya kalau ada yang belum
    local missing = false
    for plate, data in pairs(bolos) do
        local e = data.entity
        if not e or not DoesEntityExist(e) or norm(GetVehicleNumberPlateText(e)) ~= plate then
            data.entity = nil
            missing = true
        end
    end
    if missing then
        for _, veh in ipairs(GetAllVehicles()) do
            local data = bolos[norm(GetVehicleNumberPlateText(veh))]
            if data and not data.entity then data.entity = veh end
        end
    end

    local list = {}
    for plate, data in pairs(bolos) do
        if data.entity then
            local c = GetEntityCoords(data.entity)
            list[#list + 1] = { plate = plate, x = c.x, y = c.y, z = c.z }
        end
        if data.pending then
            data.pending = nil
            if data.entity then
                notifyCops(('BOLO %s: lokasi kendaraan ditemukan, lihat blip merah di peta.'):format(plate), 'success')
            else
                notifyCops(('BOLO %s: kendaraan tidak terdeteksi di jalan (kemungkinan di garasi atau depot). Akan terus dicari tiap 30 detik.'):format(plate), 'error')
            end
        end
    end
    sendBlips(list)
end

SetInterval(tick, INTERVAL)

-- dipicu f_phone saat tanda kendaraan di MDT disimpan
AddEventHandler('f_phone:server:mdtVehicleFlags', function(plate, _, isBolo, by)
    plate = norm(plate)
    if plate == '' then return end
    loadBolos()

    if isBolo then
        bolos[plate] = { pending = true }
        notifyCops(('BOLO aktif untuk %s%s. Mencari lokasi kendaraan, tunggu ±30 detik.'):format(
            plate, by and (' oleh ' .. by) or ''))
    elseif bolos[plate] then
        bolos[plate] = nil
        notifyCops(('BOLO %s dicabut.'):format(plate))
        tick()
    end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'f_phone' then loadBolos() end
end)

AddEventHandler('playerDropped', function()
    receivers[source] = nil
end)
