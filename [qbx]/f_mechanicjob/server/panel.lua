-- Panel "Periksa Kendaraan" (server). Semua perbaikan divalidasi di sini: job mekanik on duty,
-- Tas Perkakas, jarak ke kendaraan, lift (bagian berat), stok, dan durasi progress (actionStart -> actionFinish).
-- Bahan dipotong dari Stok Gudang Bengkel (server/stock.lua) SETELAH progress selesai.
local cfg = require 'config.shared'

---@type table<number, { net: number, action: string, key?: string, startedAt: number, duration: number }>
local pending = {}

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function stockOf()
    return Stock.Counts()
end

-- GetVehiclesByHash(key) mengembalikan seluruh tabel kalau model tidak ada, jadi index sendiri
local VEHICLES_BY_HASH = exports.qbx_core:GetVehiclesByHash()

local function vehicleInfo(veh)
    local info = VEHICLES_BY_HASH[GetEntityModel(veh)]
    if not info then return 'Kendaraan', nil end
    local name = info.name or info.model or 'Kendaraan'
    if info.brand and info.brand ~= '' then name = info.brand .. ' ' .. name end
    return name, info.model
end

---Nilai semua bagian dalam persen.
local function partValues(veh, c)
    local native = Condition.Native(veh)
    local out = {}
    for key, def in pairs(cfg.parts) do
        out[key] = def.native and native[def.native] or c[key]
    end
    return out
end

---Boleh memperbaiki bagian berat di posisi kendaraan sekarang? (config heavyRepair)
---@return boolean ok, string? reason
local function heavyAllowed(veh)
    if cfg.heavyRepair == 'anywhere' or Lift.Holds(veh) then return true end
    if cfg.heavyRepair == 'workshop' then
        if #(GetEntityCoords(veh) - cfg.workshop.center) <= cfg.workshop.radius then return true end
        return false, 'bawa ke bengkel'
    end
    return false, 'perlu lift'
end

local function buildStatus(src, veh)
    local c = Condition.Get(veh)
    if not c then return end
    local name, spawn = vehicleInfo(veh)
    local tyres = {}
    for key, t in pairs(Condition.Tyres(veh, c)) do tyres[key] = { wear = t.wear, burst = t.burst, off = t.off } end
    return {
        net = NetworkGetNetworkIdFromEntity(veh),
        name = name,
        spawn = spawn,
        plate = Billing.PlateOf(veh),
        kind = Condition.Kind(veh),
        odo = math.floor(c.odo or 0),
        parts = partValues(veh, c),
        tyres = tyres,
        stock = stockOf(),
        bag = HasToolBag(src),
        onLift = Lift.Holds(veh),
        heavyOk = heavyAllowed(veh),
        heavyNeed = select(2, heavyAllowed(veh)),
        pendingBill = Billing.PendingCount(veh),
        customReady = Customs.ReadyFor(veh) and 1 or 0,
    }
end

---@return string? err, number? veh
local function checkCommon(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return 'Kendaraan tidak ditemukan' end
    if not isMechanic(src) then return 'Hanya mekanik yang sedang bertugas' end
    if not Condition.Kind(veh) then return 'Kendaraan ini tidak bisa diperiksa' end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > cfg.closeDistance then return 'Kendaraan terlalu jauh' end
    -- ambil nilai mesin / body / tangki / ban bocor terbaru dari pemegang fisika kendaraan
    Condition.Refresh(veh)
    return nil, veh
end

---Rencana satu tindakan: error (string) atau { items, duration, parts, tyres, services }.
local function plan(src, veh, action, key)
    local c = Condition.Get(veh)
    local values = partValues(veh, c)
    local tyres = Condition.Tyres(veh, c)
    local heavyOk, heavyNeed = heavyAllowed(veh)
    local stock = stockOf()
    if not HasToolBag(src) then return 'Bawa Tas Perkakas dulu (ambil di Gudang Bengkel)' end

    local items, parts, tyreList, services, duration = {}, {}, {}, {}, 0
    local wheelFix = false
    local function addPart(k)
        local def = cfg.parts[k]
        items[def.item] = (items[def.item] or 0) + def.qty
        parts[#parts + 1] = k
        services[#services + 1] = def.service
        duration += def.duration
    end
    local function addTyre(k)
        items[cfg.tyre.item] = (items[cfg.tyre.item] or 0) + cfg.tyre.qty
        tyreList[#tyreList + 1] = k
        services[#services + 1] = cfg.tyre.service
        duration += cfg.tyre.duration
        -- roda lepas: dipasang ulang lewat perbaikan body (SetVehicleFixed), jadi bahan & jasa body ikut
        if tyres[k].off and not wheelFix then
            wheelFix = true
            local body = cfg.parts.body
            items[body.item] = (items[body.item] or 0) + body.qty
            services[#services + 1] = body.service
            duration += body.duration
        end
    end

    if action == 'part' then
        local def = cfg.parts[key]
        if not def then return 'Bagian tidak dikenal' end
        if values[key] >= 100 then return ('%s masih dalam kondisi baik'):format(def.label) end
        if def.heavy and not heavyOk then
            return heavyNeed == 'perlu lift' and ('%s hanya bisa diperbaiki di atas lift bengkel'):format(def.label)
                or ('%s hanya bisa diperbaiki di bengkel'):format(def.label)
        end
        addPart(key)
    elseif action == 'tyre' then
        local t = tyres[key]
        if not t then return 'Ban tidak dikenal' end
        if not t.burst and t.wear >= 100 then return 'Ban ini masih baru' end
        addTyre(key)
    elseif action == 'tyres' or action == 'all' then
        if action == 'all' then
            for k, def in pairs(cfg.parts) do
                if values[k] < cfg.needs and (not def.heavy or heavyOk) then addPart(k) end
            end
        end
        for k, t in pairs(tyres) do
            if t.burst or t.wear < cfg.needs then addTyre(k) end
        end
        if #parts == 0 and #tyreList == 0 then return 'Tidak ada yang perlu diperbaiki di sini' end
        duration = math.min(60000, math.floor(duration * 0.6))
    else
        return 'Tindakan tidak dikenal'
    end

    for item, count in pairs(items) do
        if (stock[item] or 0) < count then
            return ('Stok gudang kurang: %s ×%d (sisa %d)'):format(Stock.Label(item), count, stock[item] or 0)
        end
    end
    return { items = items, duration = duration, parts = parts, tyres = tyreList, services = services, wheelFix = wheelFix }
end

---Terapkan perbaikan. Bagian bawaan GTA diterapkan oleh pemilik entity (client yang memegang fisika).
local function apply(src, veh, p)
    local c = Condition.Get(veh)
    local native = { tyres = {} }
    for _, k in ipairs(p.parts) do
        local def = cfg.parts[k]
        if def.native then native[def.native] = true else c[k] = 100.0 end
    end
    local tyreDefs = Condition.Tyres(veh, c)
    for _, k in ipairs(p.tyres) do
        c.tw[k] = 100.0
        if tyreDefs[k].burst then native.tyres[#native.tyres + 1] = tyreDefs[k].index end
    end
    if p.wheelFix then native.body = true end
    -- perbaikan body (SetVehicleFixed) memasang kembali semua roda yang lepas
    if native.body then
        for idx = 0, 7 do
            if Entity(veh).state['f_mech:wheelOff:' .. idx] then Entity(veh).state:set('f_mech:wheelOff:' .. idx, nil, true) end
        end
    end
    Condition.Set(veh, c)
    Condition.MarkRepaired(veh, native)

    if native.engine or native.body or native.tank or #native.tyres > 0 then
        local owner = NetworkGetEntityOwner(veh)
        if not owner or owner <= 0 then owner = src end
        TriggerClientEvent('f_mechanicjob:client:applyNative', owner, NetworkGetNetworkIdFromEntity(veh), native)
        if owner ~= src then TriggerClientEvent('f_mechanicjob:client:applyNative', src, NetworkGetNetworkIdFromEntity(veh), native) end
    end
end

lib.callback.register('f_mechanicjob:server:panelOpen', function(src, netId)
    local err, veh = checkCommon(src, netId)
    if err then return { error = err } end
    return { status = buildStatus(src, veh) }
end)

lib.callback.register('f_mechanicjob:server:panelStatus', function(src, netId)
    local err, veh = checkCommon(src, netId)
    if err then return end
    return buildStatus(src, veh)
end)

lib.callback.register('f_mechanicjob:server:actionStart', function(src, netId, action, key)
    local err, veh = checkCommon(src, netId)
    if err then return { error = err } end
    local p = plan(src, veh, action, key)
    if type(p) == 'string' then return { error = p } end
    pending[src] = { net = tonumber(netId), action = action, key = key, startedAt = GetGameTimer(), duration = p.duration }
    return { duration = p.duration }
end)

lib.callback.register('f_mechanicjob:server:actionFinish', function(src)
    local job = pending[src]
    pending[src] = nil
    if not job then return { error = 'Tidak ada perbaikan berjalan' } end
    if GetGameTimer() - job.startedAt < job.duration - 500 then return { error = 'Perbaikan terlalu cepat' } end

    local err, veh = checkCommon(src, job.net)
    if err then return { error = err } end
    -- kondisi bisa berubah selama progress (bahan dipindah, kendaraan turun dari lift, dll.)
    local p = plan(src, veh, job.action, job.key)
    if type(p) == 'string' then return { error = p } end

    local ok, missing = Stock.Take(p.items)
    if not ok then return { error = ('Stok gudang kurang: %s'):format(Stock.Label(missing)) } end
    apply(src, veh, p)
    for i = 1, #p.services do Billing.Record(src, veh, p.services[i]) end

    Wait(400) -- beri waktu nilai bawaan GTA tersinkron sebelum status dikirim balik
    return { status = buildStatus(src, veh) }
end)

lib.callback.register('f_mechanicjob:server:actionCancel', function(src)
    pending[src] = nil
end)

AddEventHandler('playerDropped', function() pending[source] = nil end)
