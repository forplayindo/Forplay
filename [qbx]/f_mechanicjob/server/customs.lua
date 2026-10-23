-- Kustom kendaraan (server). Dipanggil f_customs lewat export:
--  CustomInfo(src, netId)  -> harga & status untuk NUI kustom
--  CustomSubmit(src, netId, lines, opts) -> buat order di kasir, atau langsung pasang (mekanik on duty
--     di kendaraannya sendiri / admin).
-- Harga SELALU dihitung di sini dari Master Harga; nilai mod dibandingkan dengan mods di database,
-- jadi yang tidak berubah tidak ditagih. Order lunas dipasang mekanik dari tab Kustom (15 detik).
local cfg = require 'config.shared'
local CUS = require 'config.customs'

Customs = {}

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty, player
end

---------------------------------------------------------------------------
-- Spesifikasi properti yang boleh dibeli (nama properti ox_lib)
---------------------------------------------------------------------------
local LEVEL = { modEngine = 'Mesin', modBrakes = 'Rem', modTransmission = 'Transmisi', modSuspension = 'Suspensi', modArmor = 'Armor' }
local MAXLEVEL = {}
for _, c in ipairs(CUS.catalog) do
    for _, it in ipairs(c.items) do
        local key, lv = it.code:match('^(%w+):(%d+)$')
        if key and LEVEL[key] then MAXLEVEL[key] = math.max(MAXLEVEL[key] or 0, tonumber(lv)) end
    end
end

-- mod biasa: kode harga + label
local MOD = {
    modSpoilers = { 'spoiler', 'Spoiler' }, modFrontBumper = { 'frontBumper', 'Bumper Depan' },
    modRearBumper = { 'rearBumper', 'Bumper Belakang' }, modSideSkirt = { 'sideSkirt', 'Rok Samping' },
    modExhaust = { 'exhaust', 'Knalpot' }, modFrame = { 'rollcage', 'Roll Cage' }, modGrille = { 'grille', 'Grill' },
    modHood = { 'hood', 'Kap Mesin' }, modFender = { 'fender', 'Fender Kiri' }, modRightFender = { 'fender', 'Fender Kanan' },
    modRoof = { 'roof', 'Atap' }, modHorns = { 'horn', 'Klakson' },
    modPlateHolder = { 'bodyAcc', 'Dudukan Plat' }, modVanityPlate = { 'bodyAcc', 'Plat Hias' },
    modArchCover = { 'bodyAcc', 'Penutup Roda' }, modAerials = { 'bodyAcc', 'Antena' }, modTrimB = { 'bodyAcc', 'Trim Bodi' },
    modTank = { 'bodyAcc', 'Tutup Tangki' }, modWindows = { 'bodyAcc', 'Jendela' }, modDoorR = { 'bodyAcc', 'Pintu' },
    modTrimA = { 'interior', 'Trim Interior' }, modOrnaments = { 'interior', 'Ornamen' }, modDashboard = { 'interior', 'Dashboard' },
    modDial = { 'interior', 'Speedometer' }, modDoorSpeaker = { 'interior', 'Speaker Pintu' }, modSeats = { 'interior', 'Jok' },
    modSteeringWheel = { 'interior', 'Setir' }, modShifterLeavers = { 'interior', 'Tuas Persneling' }, modAPlate = { 'interior', 'Plakat' },
    modSpeakers = { 'interior', 'Speaker' }, modTrunk = { 'interior', 'Bagasi' },
    modHydrolic = { 'engineBay', 'Hidrolik Mesin' }, modEngineBlock = { 'engineBay', 'Blok Mesin' },
    modAirFilter = { 'engineBay', 'Filter Udara' }, modStruts = { 'engineBay', 'Strut' },
    modLivery = { 'livery', 'Livery' }, livery = { 'livery', 'Livery' },
}

-- warna (indeks palet GTA)
local COLOR = {
    color1 = { nil, 'Warna Utama' }, color2 = { nil, 'Warna Kedua' }, pearlescentColor = { 'pearl', 'Pearl' },
    wheelColor = { 'wheelColor', 'Warna Velg' }, interiorColor = { 'interiorColor', 'Warna Interior' },
    dashboardColor = { 'interiorColor', 'Warna Dashboard' },
}

local RANGE = {
    windowTint = { 'windowTint', 'Kaca Film', -1, 6 },
    plateIndex = { 'plateIndex', 'Gaya Plat', 0, 12 },
}

-- satu baris = beberapa properti
local BUNDLE = {
    wheels = { label = 'Velg', code = 'wheels', keys = { wheels = true, modFrontWheels = true, modBackWheels = true } },
    tires = { label = 'Ban Custom', code = 'customTires', keys = { modCustomTiresF = true, modCustomTiresR = true } },
    smoke = { label = 'Asap Ban', code = 'tyreSmoke', keys = { modSmokeEnabled = true, tyreSmokeColor = true } },
    xenon = { label = 'Lampu Xenon', code = 'xenon', keys = { modXenon = true, xenonColor = true } },
    neon = { label = 'Neon', keys = { neonEnabled = true, neonColor = true } },
}

---------------------------------------------------------------------------
-- Jenis zona (f_customs config/shared.lua): 'paint' = warna bodi saja, 'mod' = sisanya
---------------------------------------------------------------------------
local BODY_PAINT = { color1 = true, color2 = true, pearlescentColor = true }
local STATION_LABEL = { mod = 'zona Modifikasi Kendaraan (lift)', paint = 'zona Cat Kendaraan (booth cat)' }

---@param items { id: string }[]
local function stationOf(items)
    for _, it in ipairs(items) do
        if BODY_PAINT[it.id] then return 'paint' end
    end
    return 'mod'
end

---Jenis zona tempat kendaraan berada (nil = di luar zona / f_customs mati).
local function vehStation(veh)
    if GetResourceState('f_customs') ~= 'started' then return end
    local ok, st = pcall(function() return exports.f_customs:StationAt(GetEntityCoords(veh)) end)
    return ok and st or nil
end

-- urutan pengerjaan modifikasi (animasi mekanik per kelompok)
local GROUP_ORDER = { 'perf', 'wheel', 'body', 'interior' }
local function groupOf(id)
    if LEVEL[id] or id == 'modTurbo' or (MOD[id] and MOD[id][1] == 'engineBay') then return 'perf' end
    if id == 'wheels' or id == 'tires' or id == 'smoke' then return 'wheel' end
    if MOD[id] and MOD[id][1] == 'interior' then return 'interior' end
    return 'body'
end

local function groupsOf(items)
    local has = {}
    for _, it in ipairs(items) do has[groupOf(it.id)] = true end
    local out = {}
    for _, g in ipairs(GROUP_ORDER) do if has[g] then out[#out + 1] = g end end
    return out
end

---Lama pemasangan (ms) dari tahap-tahapnya.
local function installTime(veh, station, groups)
    local T = cfg.customInstall
    if station == 'paint' then return T.paintSide * 4 end
    local wheels = Condition.Kind(veh) == 'bike' and 2 or 4
    local total = 0
    for _, g in ipairs(groups) do total += g == 'wheel' and T.wheel * wheels or T[g] end
    return total
end

local PAINT = {}
for group, ids in pairs(CUS.paintGroups) do
    if type(ids) == 'table' then for _, id in ipairs(ids) do PAINT[id] = group end end
end

-- untuk perkiraan harga di NUI f_customs (harga final tetap dihitung server)
local CODES = {}
for k, v in pairs(MOD) do CODES[k] = v[1] end
for k, v in pairs(COLOR) do CODES[k] = v[1] or 'paint' end
for k, v in pairs(RANGE) do CODES[k] = v[1] end
local PAINT_LIST = {}
for id, group in pairs(PAINT) do PAINT_LIST[tostring(id)] = group end
local function paintCode(id)
    if id >= CUS.paintGroups.chameleonFrom then return 'paint:Chameleon' end
    return 'paint:' .. (PAINT[id] or 'Classic')
end

---------------------------------------------------------------------------
-- Validasi
---------------------------------------------------------------------------
local function int(v, min, max)
    if type(v) ~= 'number' or v ~= math.floor(v) or v < min or v > max then return end
    return v
end

local function rgb(v)
    if type(v) ~= 'table' or #v ~= 3 then return end
    for i = 1, 3 do if not int(v[i], 0, 255) then return end end
    return { v[1], v[2], v[3] }
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function price(code) return Prices.Get(code) or 0 end

local function cleanDesc(s)
    s = tostring(s or ''):gsub('[<>&"\']', ''):gsub('%s+', ' ')
    return s:sub(1, 48)
end

---Satu baris dari client -> { id, label, desc, price, props } atau nil kalau tidak berubah / error string.
---@param line { id: string, props: table, desc?: string }
---@param old table mods di database
local function priceLine(line, old)
    if type(line) ~= 'table' or type(line.id) ~= 'string' or type(line.props) ~= 'table' then return 'Data tidak valid' end
    local id, p = line.id, line.props
    local desc = cleanDesc(line.desc)
    local count = 0
    for _ in pairs(p) do count += 1 end
    if count == 0 then return 'Data tidak valid' end

    local function single(key)
        if count ~= 1 or p[key] == nil then return false end
        return true
    end

    -- level performa
    if LEVEL[id] then
        if CUS.disabled[id] then return ('%s tidak dijual'):format(LEVEL[id]) end
        local v = single(id) and int(p[id], -1, 20)
        if not v then return 'Data tidak valid' end
        if same(v, old[id]) then return end
        local cost = v < 0 and 0 or price(('%s:%d'):format(id, math.min(v + 1, MAXLEVEL[id] or 1)))
        return { id = id, label = LEVEL[id], desc = desc, price = cost, props = { [id] = v } }
    end

    if id == 'modTurbo' then
        if CUS.disabled.modTurbo then return 'Turbo tidak dijual' end
        if not single(id) or type(p[id]) ~= 'boolean' then return 'Data tidak valid' end
        if same(p[id], old[id] or false) then return end
        return { id = id, label = 'Turbo', desc = desc, price = p[id] and price('modTurbo') or 0, props = { modTurbo = p[id] } }
    end

    if MOD[id] then
        if CUS.disabled[id] then return ('%s tidak dijual'):format(MOD[id][2]) end
        local v = single(id) and int(p[id], -1, 300)
        if not v then return 'Data tidak valid' end
        if same(v, old[id]) then return end
        return { id = id, label = MOD[id][2], desc = desc, price = v < 0 and 0 or price(MOD[id][1]), props = { [id] = v } }
    end

    if COLOR[id] then
        local v = single(id) and int(p[id], 0, 242)
        if not v then return 'Data tidak valid' end
        if same(v, old[id]) then return end
        local code = COLOR[id][1] or paintCode(v)
        return { id = id, label = COLOR[id][2], desc = desc, price = price(code), props = { [id] = v } }
    end

    if RANGE[id] then
        local r = RANGE[id]
        local v = single(id) and int(p[id], r[3], r[4])
        if not v then return 'Data tidak valid' end
        if same(v, old[id]) then return end
        return { id = id, label = r[2], desc = desc, price = price(r[1]), props = { [id] = v } }
    end

    local extra = id:match('^extra:(%d+)$')
    if extra then
        extra = tonumber(extra)
        if extra < 1 or extra > 15 or count ~= 1 or type(p.extras) ~= 'table' then return 'Data tidak valid' end
        local v = int(p.extras[tostring(extra)] or p.extras[extra], 0, 1)
        if not v then return 'Data tidak valid' end
        local oldExtras = type(old.extras) == 'table' and old.extras or {}
        if v == (oldExtras[tostring(extra)] or oldExtras[extra]) then return end
        return { id = id, label = ('Extra %d'):format(extra), desc = desc, price = price('extra'), props = { extras = { [tostring(extra)] = v } } }
    end

    local b = BUNDLE[id]
    if not b then return 'Modifikasi tidak dikenal' end
    for k in pairs(p) do if not b.keys[k] then return 'Data tidak valid' end end
    local props, changed = {}, false

    if id == 'wheels' then
        props.wheels = p.wheels ~= nil and int(p.wheels, 0, 12) or nil
        props.modFrontWheels = p.modFrontWheels ~= nil and int(p.modFrontWheels, -1, 400) or nil
        props.modBackWheels = p.modBackWheels ~= nil and int(p.modBackWheels, -1, 400) or nil
        for k in pairs(p) do if props[k] == nil then return 'Data tidak valid' end end
        local stock = true
        for k, v in pairs(props) do
            if not same(v, old[k]) then changed = true end
            if k ~= 'wheels' and v >= 0 then stock = false end
        end
        if not changed then return end
        return { id = id, label = b.label, desc = desc, price = stock and 0 or price(b.code), props = props }
    end

    if id == 'tires' then
        local any = false
        for k, v in pairs(p) do
            if type(v) ~= 'boolean' then return 'Data tidak valid' end
            props[k] = v
            if not same(v, old[k] or false) then changed = true end
            if v then any = true end
        end
        if not changed then return end
        return { id = id, label = b.label, desc = desc, price = any and price(b.code) or 0, props = props }
    end

    if id == 'smoke' then
        if p.modSmokeEnabled ~= nil and type(p.modSmokeEnabled) ~= 'boolean' then return 'Data tidak valid' end
        props.modSmokeEnabled = p.modSmokeEnabled
        if p.tyreSmokeColor ~= nil then
            props.tyreSmokeColor = rgb(p.tyreSmokeColor)
            if not props.tyreSmokeColor then return 'Data tidak valid' end
        end
        for k, v in pairs(props) do if not same(v, old[k]) then changed = true end end
        if not changed then return end
        local on = props.modSmokeEnabled
        if on == nil then on = old.modSmokeEnabled end
        return { id = id, label = b.label, desc = desc, price = on and price(b.code) or 0, props = props }
    end

    if id == 'xenon' then
        if p.modXenon ~= nil and type(p.modXenon) ~= 'boolean' then return 'Data tidak valid' end
        props.modXenon = p.modXenon
        if p.xenonColor ~= nil then
            props.xenonColor = p.xenonColor == 255 and 255 or int(p.xenonColor, -1, 12)
            if not props.xenonColor then return 'Data tidak valid' end
        end
        for k, v in pairs(props) do if not same(v, old[k]) then changed = true end end
        if not changed then return end
        local on = props.modXenon
        if on == nil then on = old.modXenon end
        return { id = id, label = b.label, desc = desc, price = on and price(b.code) or 0, props = props }
    end

    if id == 'neon' then
        local cost = 0
        if p.neonEnabled ~= nil then
            if type(p.neonEnabled) ~= 'table' or #p.neonEnabled ~= 4 then return 'Data tidak valid' end
            local oldN = type(old.neonEnabled) == 'table' and old.neonEnabled or {}
            props.neonEnabled = {}
            for i = 1, 4 do
                local v = p.neonEnabled[i]
                if type(v) ~= 'boolean' then return 'Data tidak valid' end
                props.neonEnabled[i] = v
                if v ~= (oldN[i] == true) then changed = true end
                if v and oldN[i] ~= true then cost += price('neon') end
            end
        end
        if p.neonColor ~= nil then
            props.neonColor = rgb(p.neonColor)
            if not props.neonColor then return 'Data tidak valid' end
            if not same(props.neonColor, old.neonColor) then
                changed = true
                cost += price('neonColor')
            end
        end
        if not changed then return end
        return { id = id, label = b.label, desc = desc, price = cost, props = props }
    end

    return 'Modifikasi tidak dikenal'
end

---@return string? err, table? lines, integer? total
local function priceAll(lines, old)
    if type(lines) ~= 'table' or #lines == 0 then return 'Belum ada modifikasi' end
    if #lines > 80 then return 'Terlalu banyak modifikasi' end
    local out, seen, total = {}, {}, 0
    for _, line in ipairs(lines) do
        local r = priceLine(line, old)
        if type(r) == 'string' then return r end
        if r then
            if seen[r.id] then return 'Data tidak valid' end
            seen[r.id] = true
            out[#out + 1] = r
            total += r.price
        end
    end
    if #out == 0 then return 'Tidak ada perubahan dari kondisi sekarang' end
    return nil, out, total
end

---------------------------------------------------------------------------
-- Kendaraan & database
---------------------------------------------------------------------------
local function vehicleRow(veh)
    local vid = tonumber(Entity(veh).state.vehicleid)
    if not vid then return end
    local row = MySQL.single.await('SELECT id, citizenid, plate, mods FROM player_vehicles WHERE id = ?', { vid })
    if not row then return end
    local ok, mods = pcall(json.decode, row.mods or '{}')
    row.mods = ok and type(mods) == 'table' and mods or {}
    return row
end

local function mergeProps(lines)
    local props = {}
    for _, l in ipairs(lines) do
        for k, v in pairs(l.props) do
            if k == 'extras' then
                props.extras = props.extras or {}
                for e, s in pairs(v) do props.extras[tostring(e)] = s end
            else
                props[k] = v
            end
        end
    end
    return props
end

---Terapkan ke kendaraan (pemilik entity, lewat state bag ox_lib) dan simpan ke player_vehicles.
---@param veh integer
---@param vehicleid integer?
---@param props table
local function applyProps(veh, vehicleid, props)
    local mods = {}
    if vehicleid then
        local raw = MySQL.scalar.await('SELECT mods FROM player_vehicles WHERE id = ?', { vehicleid })
        local ok, decoded = pcall(json.decode, raw or '{}')
        mods = ok and type(decoded) == 'table' and decoded or {}
    end
    -- ox_lib memasang ban custom bersama velg (SetVehicleMod 23/24), jadi kirim pasangannya juga
    local live = table.clone(props)
    if live.modFrontWheels ~= nil and live.modCustomTiresF == nil then live.modCustomTiresF = mods.modCustomTiresF or false end
    if live.modCustomTiresF ~= nil and live.modFrontWheels == nil then live.modFrontWheels = mods.modFrontWheels or -1 end
    if live.modBackWheels ~= nil and live.modCustomTiresR == nil then live.modCustomTiresR = mods.modCustomTiresR or false end
    if live.modCustomTiresR ~= nil and live.modBackWheels == nil then live.modBackWheels = mods.modBackWheels or -1 end
    Entity(veh).state:set('ox_lib:setVehicleProperties', live, true)
    if not vehicleid then return end
    for k, v in pairs(props) do
        if k == 'extras' then
            local merged = {}
            for e, s in pairs(type(mods.extras) == 'table' and mods.extras or {}) do merged[tostring(e)] = s end
            for e, s in pairs(v) do merged[e] = s end
            mods.extras = merged
        else
            mods[k] = v
        end
    end
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE id = ?', { json.encode(mods), vehicleid })
end

local function getVeh(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    return veh
end

---------------------------------------------------------------------------
-- Export untuk f_customs
---------------------------------------------------------------------------
---@return table
local function info(src, netId)
    local veh = getVeh(netId)
    if not veh then return { error = 'Kendaraan tidak ditemukan' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan' } end
    local row = vehicleRow(veh)
    local mech = isMechanic(src)
    local active = row and Kasir.ActiveCustom(row.id)
    return {
        prices = Prices.All(),
        codes = CODES,
        paint = PAINT_LIST,
        chameleonFrom = CUS.paintGroups.chameleonFrom,
        disabled = CUS.disabled,
        maxLevel = MAXLEVEL,
        mechanics = (exports.qbx_core:GetDutyCountType(cfg.jobType)) or 0,
        owned = row ~= nil,
        free = row ~= nil and mech and row.citizenid == player.PlayerData.citizenid or false,
        active = active and { id = active.id, status = active.status, total = active.total } or nil,
    }
end
exports('CustomInfo', info)

---@param opts { admin?: boolean, dry?: boolean }
local function submit(src, netId, lines, opts)
    opts = type(opts) == 'table' and opts or {}
    local veh = getVeh(netId)
    if not veh then return { error = 'Kendaraan tidak ditemukan' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan' } end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return { error = 'Kamu harus berada di dalam kendaraan' } end

    local row = vehicleRow(veh)
    if not row and not opts.admin then return { error = 'Hanya kendaraan milik pribadi yang bisa dikustom' } end

    local err, priced, total = priceAll(lines, row and row.mods or {})
    if err then return { error = err } end
    -- zona cat hanya warna bodi, zona modifikasi tanpa warna bodi (admin bebas)
    if opts.station and not opts.admin then
        for _, l in ipairs(priced) do
            if opts.station == 'paint' and not BODY_PAINT[l.id] then return { error = 'Di booth cat hanya bisa mengganti warna bodi' } end
            if opts.station == 'mod' and BODY_PAINT[l.id] then return { error = 'Warna bodi diganti di booth cat' } end
        end
    end

    local mech = isMechanic(src)
    local free = opts.admin or (row and mech and row.citizenid == player.PlayerData.citizenid)
    if opts.dry then return { lines = priced, total = total, free = free and true or false } end

    if free then
        applyProps(veh, row and row.id, mergeProps(priced))
        return { applied = true, total = total }
    end

    if Kasir.ActiveCustom(row.id) then return { error = 'Kendaraan ini masih punya order kustom yang belum selesai' } end
    if ((exports.qbx_core:GetDutyCountType(cfg.jobType)) or 0) <= 0 then return { error = 'Tidak ada mekanik yang bertugas' } end

    local bill = Kasir.Add({
        kind = 'custom', citizenid = player.PlayerData.citizenid, name = Billing.CharName(player),
        plate = Billing.PlateOf(veh), vehicleid = row.id, items = priced, total = total,
        createdBy = player.PlayerData.citizenid, createdByName = Billing.CharName(player),
    })
    if not bill then return { error = 'Order gagal disimpan' } end
    return { ok = true, id = bill.id, total = total }
end
exports('CustomSubmit', submit)

---------------------------------------------------------------------------
-- Tab Kustom (mekanik)
---------------------------------------------------------------------------
---@type table<number, { net: number, bill: integer, startedAt: number }>
local installing = {}

---@return string? err, number? veh
local function checkMech(src, netId)
    local veh = getVeh(netId)
    if not veh then return 'Kendaraan tidak ditemukan' end
    if not isMechanic(src) then return 'Hanya mekanik yang sedang bertugas' end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > cfg.closeDistance then return 'Kendaraan terlalu jauh' end
    return nil, veh
end

---Order lunas untuk kendaraan ini (dipakai badge panel).
function Customs.ReadyFor(veh)
    return Kasir.PaidCustom(tonumber(Entity(veh).state.vehicleid))
end

local function customData(veh)
    local b = Customs.ReadyFor(veh)
    if not b then return { order = false } end
    local items = {}
    for i, it in ipairs(b.items) do items[i] = { label = it.label, desc = it.desc, price = it.price } end
    local station = stationOf(b.items)
    return {
        order = { id = b.id, name = b.name, plate = b.plate, total = b.total, method = b.method, paidAt = b.paidAt, items = items },
        station = station,
        stationLabel = STATION_LABEL[station],
        inStation = vehStation(veh) == station,
        duration = installTime(veh, station, groupsOf(b.items)),
        empty = GetPedInVehicleSeat(veh, -1) == 0,
    }
end

lib.callback.register('f_mechanicjob:server:customGet', function(src, netId)
    local err, veh = checkMech(src, netId)
    if err then return { error = err } end
    return customData(veh)
end)

lib.callback.register('f_mechanicjob:server:customStart', function(src, netId, billId)
    local err, veh = checkMech(src, netId)
    if err then return { error = err } end
    local b = Customs.ReadyFor(veh)
    if not b or b.id ~= tonumber(billId) then return { error = 'Order tidak ditemukan atau belum lunas' } end
    local station = stationOf(b.items)
    if vehStation(veh) ~= station then return { error = ('Kendaraan harus berada di %s'):format(STATION_LABEL[station]) } end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return { error = 'Kendaraan harus kosong (tanpa pengemudi)' } end
    local groups = groupsOf(b.items)
    local duration = installTime(veh, station, groups)
    installing[src] = { net = tonumber(netId), bill = b.id, startedAt = GetGameTimer(), duration = duration }
    FreezeEntityPosition(veh, true)
    return { duration = duration, station = station, groups = groups }
end)

lib.callback.register('f_mechanicjob:server:customCancel', function(src)
    local job = installing[src]
    installing[src] = nil
    local veh = job and getVeh(job.net)
    if veh then FreezeEntityPosition(veh, false) end
end)

lib.callback.register('f_mechanicjob:server:customFinish', function(src)
    local job = installing[src]
    installing[src] = nil
    if not job then return { error = 'Tidak ada pemasangan berjalan' } end
    local veh = getVeh(job.net)
    if veh then FreezeEntityPosition(veh, false) end
    if GetGameTimer() - job.startedAt < job.duration - 500 then return { error = 'Pemasangan terlalu cepat' } end

    local err
    err, veh = checkMech(src, job.net)
    if err then return { error = err } end
    local b = Customs.ReadyFor(veh)
    if not b or b.id ~= job.bill then return { error = 'Order tidak ditemukan' } end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return { error = 'Kendaraan harus kosong (tanpa pengemudi)' } end
    if vehStation(veh) ~= stationOf(b.items) then return { error = ('Kendaraan harus berada di %s'):format(STATION_LABEL[stationOf(b.items)]) } end

    applyProps(veh, b.vehicleid, mergeProps(b.items))
    Kasir.Done(b)
    local p = exports.qbx_core:GetPlayerByCitizenId(b.citizenid)
    if p then exports.qbx_core:Notify(p.PlayerData.source, ('Modifikasi kendaraan %s sudah terpasang.'):format(b.plate), 'success', 7000) end
    local data = customData(veh)
    data.msg = ('Order #%d terpasang.'):format(b.id)
    return data
end)

AddEventHandler('playerDropped', function()
    local job = installing[source]
    installing[source] = nil
    local veh = job and getVeh(job.net)
    if veh then FreezeEntityPosition(veh, false) end
end)
