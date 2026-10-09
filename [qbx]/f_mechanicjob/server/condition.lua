-- Kondisi kendaraan (server = sumber kebenaran).
--  * Bagian buatan script (oli, rem, suspensi, keausan ban, ...) disimpan di state bag kendaraan
--    'f_mech:cond' (direplikasi supaya client pengemudi bisa menerapkan efeknya).
--  * Mesin, body, tangki & ban bocor memakai nilai bawaan GTA (ikut tersimpan di props garasi).
--  * Kendaraan pemain (state.vehicleid) disimpan di tabel mechanic_vehicle_condition.
--  * Client pengemudi hanya boleh MENGURANGI kondisi (laporan keausan, dibatasi per detik).
--    Kenaikan hanya lewat perbaikan yang divalidasi server (server/panel.lua).
local cfg = require 'config.shared'
local serverCfg = require 'config.server'

Condition = {}

local STATE_KEY = 'f_mech:cond'
local MAX_WEAR_PER_SEC = 3.0   -- % per bagian per detik (batas atas laporan client)
local MAX_KM_PER_SEC = 0.12    -- ~430 km/j

---@type table<integer, table> vehicleid -> kondisi yang belum disimpan
local dirty = {}
---@type table<number, integer> entity -> vehicleid (untuk simpan saat kendaraan hilang)
local tracked = {}
---@type table<string, integer> "src:entity" -> GetGameTimer laporan terakhir
local lastReport = {}

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_vehicle_condition` (
            `vehicle_id` INT NOT NULL,
            `data` LONGTEXT NOT NULL,
            `odometer` FLOAT NOT NULL DEFAULT 0,
            `updated_at` INT NOT NULL,
            PRIMARY KEY (`vehicle_id`)
        )
    ]])
end)

---@param veh number
---@return 'car'|'bike'|nil
function Condition.Kind(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    return cfg.vehicleTypes[GetVehicleType(veh)]
end

---@param kind 'car'|'bike'
local function tyreKeys(kind)
    local keys = {}
    for i, t in ipairs(cfg.tyres[kind]) do keys[i] = t.key end
    return keys
end

---Melengkapi kunci yang hilang (data lama / jenis kendaraan berubah).
local function normalize(c, kind, fill)
    c = type(c) == 'table' and c or {}
    for _, key in ipairs(cfg.custom) do
        c[key] = math.max(0.0, math.min(100.0, tonumber(c[key]) or fill()))
    end
    local tw = type(c.tw) == 'table' and c.tw or {}
    local out = {}
    for _, key in ipairs(tyreKeys(kind)) do out[key] = math.max(0.0, math.min(100.0, tonumber(tw[key]) or fill())) end
    c.tw = out
    c.odo = tonumber(c.odo) or 0.0
    return c
end

local function npcFill()
    local n = serverCfg.npcCondition
    return math.random(n.min, n.max) + 0.0
end

local function fullFill() return 100.0 end

local function loadOwned(vid, kind)
    local row = MySQL.single.await('SELECT data, odometer FROM mechanic_vehicle_condition WHERE vehicle_id = ?', { vid })
    if not row then return normalize({}, kind, fullFill) end
    local ok, data = pcall(json.decode, row.data)
    local c = normalize(ok and data or {}, kind, fullFill)
    c.odo = tonumber(row.odometer) or c.odo
    return c
end

local function save(vid, c)
    MySQL.prepare('INSERT INTO mechanic_vehicle_condition (vehicle_id, data, odometer, updated_at) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), odometer = VALUES(odometer), updated_at = VALUES(updated_at)',
        { vid, json.encode(c), c.odo or 0, os.time() })
end

---Kondisi kendaraan (dimuat / dibuat kalau belum ada). nil kalau jenis kendaraan tidak didukung.
---@param veh number
---@return table?
function Condition.Get(veh)
    local kind = Condition.Kind(veh)
    if not kind then return end
    local state = Entity(veh).state
    local c = state[STATE_KEY]
    if type(c) == 'table' then return c end

    local vid = tonumber(state.vehicleid)
    if vid then
        c = loadOwned(vid, kind)
        tracked[veh] = vid
    elseif GetEntityPopulationType(veh) == 7 then
        -- dibuat script (job, rental, /car, dealer, ...) = kendaraan baru, 100% sehat
        c = normalize({}, kind, fullFill)
    else
        local n = serverCfg.npcCondition
        c = normalize({}, kind, npcFill)
        c.odo = math.random(n.odoMin, n.odoMax) + 0.0
    end
    state:set(STATE_KEY, c, true)
    return c
end

---@param veh number
---@param c table
function Condition.Set(veh, c)
    Entity(veh).state:set(STATE_KEY, c, true)
    local vid = tonumber(Entity(veh).state.vehicleid)
    if vid then
        tracked[veh] = vid
        dirty[vid] = c
    end
end

-- Nilai bawaan GTA (mesin, body, tangki, ban bocor) di SERVER sering tidak ter-update (body health
-- tetap 1000). Nilai yang benar ada di client pemegang fisika kendaraan, jadi diambil dari sana:
--  * pengemudi mengirimnya bersama laporan keausan
--  * saat panel dibuka / disegarkan server meminta langsung ke pemegang fisika (Condition.Refresh)
local SNAP_TTL = 15000 -- ms; snapshot lebih tua dari ini tidak dipakai
---@type table<number, { e: number, b: number, t: number, burst: table<integer, true>, at: integer }>
local snaps = {}

---Simpan snapshot nilai bawaan dari client (persen 0-100, burst = daftar wheel index).
function Condition.Report(veh, n)
    if type(n) ~= 'table' then return end
    local function pct(v) return math.max(0.0, math.min(100.0, tonumber(v) or 100.0)) end
    local burst = {}
    for _, idx in ipairs(type(n.burst) == 'table' and n.burst or {}) do
        idx = math.floor(tonumber(idx) or -1)
        if idx >= 0 and idx <= 7 then burst[idx] = true end
    end
    snaps[veh] = { e = pct(n.e), b = pct(n.b), t = pct(n.t), burst = burst, at = GetGameTimer() }
end

---Minta snapshot terbaru ke client pemegang fisika (maks. ~1,5 detik menunggu).
function Condition.Refresh(veh)
    local owner = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 then return end
    local p = promise.new()
    lib.callback('f_mechanicjob:client:nativeSnap', owner, function(n) p:resolve(n or false) end, NetworkGetNetworkIdFromEntity(veh))
    SetTimeout(1500, function() p:resolve(false) end)
    local n = Citizen.Await(p)
    if n then Condition.Report(veh, n) end
end

---Setelah perbaikan: snapshot langsung disesuaikan supaya panel tidak menampilkan nilai lama.
function Condition.MarkRepaired(veh, native)
    local s = snaps[veh]
    if not s then return end
    if native.engine then s.e = 100.0 end
    if native.body then s.b = 100.0 end
    if native.tank then s.t = 100.0 end
    for _, idx in ipairs(native.tyres or {}) do s.burst[idx] = nil end
    s.at = GetGameTimer()
end

local function freshSnap(veh)
    local s = snaps[veh]
    if s and GetGameTimer() - s.at <= SNAP_TTL then return s end
end

---Nilai bawaan GTA dalam persen.
function Condition.Native(veh)
    local s = freshSnap(veh)
    if s then return { engine = s.e, body = s.b, tank = s.t } end
    local function pct(v) return math.max(0, math.min(100, (tonumber(v) or 0) / 10)) end
    return {
        engine = pct(GetVehicleEngineHealth(veh)),
        body = pct(GetVehicleBodyHealth(veh)),
        tank = pct(GetVehiclePetrolTankHealth(veh)),
    }
end

---Status ban: { key = { wear, burst, off, index } }. off = roda lepas (ditandai vehiclehandler).
function Condition.Tyres(veh, c)
    local kind = Condition.Kind(veh)
    local s = freshSnap(veh)
    local state = Entity(veh).state
    local out = {}
    for _, t in ipairs(cfg.tyres[kind]) do
        local burst
        if s then burst = s.burst[t.index] == true else burst = IsVehicleTyreBurst(veh, t.index, false) end
        local off = state['f_mech:wheelOff:' .. t.index] == true
        out[t.key] = { wear = c.tw[t.key] or 100, burst = burst or off, off = off, index = t.index, label = t.label }
    end
    return out
end

AddEventHandler('entityRemoved', function(entity) snaps[entity] = nil end)

-- kendaraan dari garasi: muat kondisi tersimpan
AddEventHandler('f_garages:server:vehicleSpawned', function(veh)
    if DoesEntityExist(veh) then Condition.Get(veh) end
end)

-- pengemudi meminta kondisi awal (kendaraan yang belum punya state)
RegisterNetEvent('f_mechanicjob:server:initCond', function(netId)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end
    Condition.Get(veh)
end)

---Laporan keausan dari pengemudi: hanya pengurangan, dibatasi sesuai lama sejak laporan terakhir.
---@param payload { p?: table<string, number>, tw?: table<string, number>, km?: number }
RegisterNetEvent('f_mechanicjob:server:wear', function(netId, payload)
    local src = source
    if type(payload) ~= 'table' then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return end
    -- pengemudi saat ini, atau baru turun (laporan terakhir dikirim saat keluar)
    local ped = GetPlayerPed(src)
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= ped and (driver ~= 0 or #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 15.0) then return end

    local c = Condition.Get(veh)
    if not c then return end
    -- nilai bawaan GTA dari pengemudi (pemegang fisika), lebih akurat daripada nilai di server
    if type(payload.n) == 'table' then Condition.Report(veh, payload.n) end

    local key = src .. ':' .. veh
    local now = GetGameTimer()
    local elapsed = math.min(120.0, math.max(1.0, (now - (lastReport[key] or (now - 30000))) / 1000))
    lastReport[key] = now
    local cap = MAX_WEAR_PER_SEC * elapsed

    local changed = false
    if type(payload.p) == 'table' then
        for _, part in ipairs(cfg.custom) do
            local d = tonumber(payload.p[part])
            if d and d > 0 then
                c[part] = math.max(0.0, c[part] - math.min(d, cap))
                changed = true
            end
        end
    end
    if type(payload.tw) == 'table' then
        for tyre, value in pairs(c.tw) do
            local d = tonumber(payload.tw[tyre])
            if d and d > 0 then
                c.tw[tyre] = math.max(0.0, value - math.min(d, cap))
                changed = true
            end
        end
    end
    local km = tonumber(payload.km)
    if km and km > 0 then
        c.odo = (c.odo or 0) + math.min(km, MAX_KM_PER_SEC * elapsed)
        changed = true
    end
    if changed then Condition.Set(veh, c) end
end)

---Decit rem: hanya pengemudi kendaraan yang remnya memang Rusak / Parah, dibatasi per pemain.
local lastSqueal = {}
RegisterNetEvent('f_mechanicjob:server:squeal', function(netId)
    local src = source
    local now = GetGameTimer()
    if lastSqueal[src] and now - lastSqueal[src] < 1500 then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end
    local c = Entity(veh).state[STATE_KEY]
    if type(c) ~= 'table' or (c.brakes or 100) >= cfg.levels[2] then return end
    lastSqueal[src] = now

    local pos = GetEntityCoords(veh)
    local severe = (c.brakes or 100) < cfg.levels[3]
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 and #(GetEntityCoords(ped) - pos) <= 45.0 then
            TriggerClientEvent('f_mechanicjob:client:squeal', tonumber(id), netId, severe)
        end
    end
end)

AddEventHandler('playerDropped', function() lastSqueal[source] = nil end)

local function flush()
    for vid, c in pairs(dirty) do
        save(vid, c)
        dirty[vid] = nil
    end
end

CreateThread(function()
    while true do
        Wait(serverCfg.saveEvery * 1000)
        flush()
        for veh in pairs(tracked) do
            if not DoesEntityExist(veh) then tracked[veh] = nil end
        end
    end
end)

AddEventHandler('entityRemoved', function(entity)
    local vid = tracked[entity]
    if not vid then return end
    tracked[entity] = nil
    if dirty[vid] then
        save(vid, dirty[vid])
        dirty[vid] = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then flush() end
end)

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for key in pairs(lastReport) do
        if key:sub(1, #prefix) == prefix then lastReport[key] = nil end
    end
end)

---Kondisi kendaraan untuk resource lain (persen). nil kalau tidak didukung.
exports('GetCondition', function(veh)
    local c = Condition.Get(veh)
    if not c then return end
    local out = {}
    for k, v in pairs(c) do out[k] = v end
    for k, v in pairs(Condition.Native(veh)) do out[k] = v end
    return out
end)
