-- Editor garasi in-game (/garasi). Garasi buatan editor disimpan di tabel f_garasi dan didaftarkan
-- lewat GarageRegister (server/main.lua) -> langsung aktif tanpa restart.
-- Garasi dari config/server.lua atau script lain (f_crew, f_properties) hanya ditampilkan.
local EC = require 'config.editor'

local Edited = {} ---@type table<string, table> garasi buatan editor (id -> data)

local allowed = {}
for _, id in ipairs(Config.editorLicenses or {}) do allowed[id:lower()] = true end

local function isAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if allowed[id:lower()] then return true end
    end
    return false
end

local function log(src, msg)
    print(('^3[f_garages:editor]^0 %s: %s'):format(src and GetPlayerName(src) or 'console', msg))
end

---------------------------------------------------------------------------
-- data
---------------------------------------------------------------------------
---@param g table data editor
---@return GarageConfig
local function toGarageConfig(g)
    local points = {}
    for i, p in ipairs(g.points) do points[i] = vec2(p.x, p.y) end
    local spawns = {}
    for i, s in ipairs(g.spawns) do spawns[i] = vec4(s.x, s.y, s.z, s.w) end

    local cfg = {
        label = g.label,
        vehicleType = g.vtype,
        accessPoints = { { zone = { points = points, z = g.z, height = g.height }, spawns = spawns } },
    }
    if g.gtype ~= 'public' then
        cfg.groups = { [g.group] = g.grade }
        cfg.shared = g.shared or nil
    end
    if g.depot then
        cfg.type = GarageType.DEPOT
        cfg.states = { VehicleState.OUT, VehicleState.IMPOUNDED }
        cfg.skipGarageCheck = true
    end
    return cfg
end

local function fromRow(r)
    local ok1, points = pcall(json.decode, r.points)
    local ok2, spawns = pcall(json.decode, r.spawns)
    return {
        id = r.id, label = r.label, vtype = r.vtype, depot = r.depot == 1 or r.depot == true,
        gtype = r.gtype, group = r.grp, grade = r.grade, shared = r.shared == 1 or r.shared == true,
        points = ok1 and points or {}, spawns = ok2 and spawns or {},
        z = r.z, height = r.height,
        createdBy = r.created_by, createdAt = r.created_at,
    }
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_garasi (
        id VARCHAR(40) NOT NULL PRIMARY KEY,
        label VARCHAR(60) NOT NULL,
        vtype VARCHAR(10) NOT NULL,
        depot TINYINT(1) NOT NULL DEFAULT 0,
        gtype VARCHAR(10) NOT NULL,
        grp VARCHAR(60) NOT NULL DEFAULT '',
        grade INT NOT NULL DEFAULT 0,
        shared TINYINT(1) NOT NULL DEFAULT 0,
        points TEXT NOT NULL,
        spawns TEXT NOT NULL,
        z FLOAT NOT NULL,
        height FLOAT NOT NULL,
        created_by VARCHAR(80) NULL,
        created_at INT NOT NULL DEFAULT 0
    )]])

    for _, r in ipairs(MySQL.query.await('SELECT * FROM f_garasi') or {}) do
        local g = fromRow(r)
        if #g.points >= 3 and #g.spawns >= 1 then
            Edited[g.id] = g
            GarageRegister(g.id, toGarageConfig(g))
        end
    end
end)

---------------------------------------------------------------------------
-- admin
---------------------------------------------------------------------------
local function groupCatalog()
    local function build(src, skip)
        local out = {}
        for name, g in pairs(src or {}) do
            if name ~= skip then
                local grades = {}
                for lvl, gr in pairs(g.grades or {}) do grades[tostring(lvl)] = gr.name end
                out[#out + 1] = { name = name, label = g.label or name, grades = grades }
            end
        end
        table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
        return out
    end
    return {
        job = build(exports.qbx_core:GetJobs(), 'unemployed'),
        gang = build(exports.qbx_core:GetGangs(), 'none'),
    }
end

local function groupExists(gtype, name)
    if gtype == 'job' then return exports.qbx_core:GetJobs()[name] ~= nil end
    if gtype == 'gang' then return exports.qbx_core:GetGangs()[name] ~= nil end
    return false
end

local function groupsText(groups)
    if type(groups) == 'string' then return groups end
    if type(groups) ~= 'table' then return nil end
    local names = {}
    for k, v in pairs(groups) do names[#names + 1] = type(k) == 'number' and tostring(v) or k end
    table.sort(names)
    return table.concat(names, ', ')
end

-- semua garasi untuk daftar (vector diubah ke tabel biasa supaya aman dikirim ke NUI)
local function adminList()
    local list = {}
    for name, cfg in pairs(Garages) do
        local own = Edited[name]
        local ap = cfg.accessPoints and cfg.accessPoints[1]
        local zone = ap and ap.zone
        if zone then
            local points, spawns = {}, {}
            for i, p in ipairs(zone.points) do points[i] = { x = p.x, y = p.y } end
            for i, s in ipairs(ap.spawns or {}) do spawns[i] = { x = s.x, y = s.y, z = s.z, w = s.w or 0.0 } end
            list[#list + 1] = {
                id = name,
                label = cfg.label or name,
                editable = own ~= nil,
                vtype = cfg.vehicleType or 'car',
                depot = cfg.type == GarageType.DEPOT,
                gtype = own and own.gtype or (cfg.groups and 'group' or 'public'),
                group = own and own.group or groupsText(cfg.groups),
                grade = own and own.grade or 0,
                shared = own and own.shared or cfg.shared == true,
                points = points, spawns = spawns,
                z = zone.z, height = zone.height,
                createdBy = own and own.createdBy,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.editable ~= b.editable then return a.editable end
        return a.label:lower() < b.label:lower()
    end)
    return list
end

local validGrade = {}
for _, g in ipairs(EC.grades) do validGrade[g] = true end
local validType = { car = true, air = true, sea = true }

---@return table? data, string? err
local function validate(d)
    if type(d) ~= 'table' then return nil, 'Data tidak valid.' end
    local label = type(d.label) == 'string' and d.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #label < 2 or #label > 40 then return nil, 'Nama garasi 2-40 karakter.' end
    if not validType[d.vtype] then return nil, 'Jenis kendaraan tidak valid.' end

    local gtype = d.gtype
    if gtype ~= 'public' and gtype ~= 'job' and gtype ~= 'gang' then return nil, 'Pemilik tidak valid.' end
    local grade = math.tointeger(tonumber(d.grade)) or 0
    if gtype ~= 'public' then
        if not groupExists(gtype, d.group) then return nil, 'Job/gang tidak ditemukan.' end
        if not validGrade[grade] then return nil, 'Grade tidak valid.' end
    end

    local height = tonumber(d.height)
    if not height or height < 2 or height > 40 then return nil, 'Tinggi zona 2-40 meter.' end

    -- titik area
    if type(d.points) ~= 'table' or #d.points < 3 then return nil, 'Area butuh minimal 3 titik. Klik "Tandai Area".' end
    if #d.points > EC.maxPoints then return nil, ('Maksimal %d titik area.'):format(EC.maxPoints) end
    local points, cx, cy, minZ = {}, 0.0, 0.0, nil
    for i, p in ipairs(d.points) do
        local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
        if not x or not y or not z then return nil, 'Titik area tidak valid.' end
        points[i] = { x = x, y = y }
        cx, cy = cx + x, cy + y
        minZ = math.min(minZ or z, z)
    end
    cx, cy = cx / #points, cy / #points
    for _, p in ipairs(points) do
        if #(vec2(p.x, p.y) - vec2(cx, cy)) > EC.maxSize then return nil, 'Area terlalu besar.' end
    end

    -- titik keluar kendaraan
    if type(d.spawns) ~= 'table' or #d.spawns < 1 then return nil, 'Butuh minimal 1 titik keluar kendaraan. Klik "Tandai Titik Keluar".' end
    if #d.spawns > EC.maxSpawns then return nil, ('Maksimal %d titik keluar.'):format(EC.maxSpawns) end
    local spawns = {}
    for i, s in ipairs(d.spawns) do
        local x, y, z, w = tonumber(s.x), tonumber(s.y), tonumber(s.z), tonumber(s.w)
        if not x or not y or not z or not w then return nil, 'Titik keluar tidak valid.' end
        if #(vec2(x, y) - vec2(cx, cy)) > EC.spawnRange then return nil, 'Titik keluar terlalu jauh dari area garasi.' end
        spawns[i] = { x = x, y = y, z = z, w = w % 360.0 }
    end

    return {
        label = label, vtype = d.vtype, depot = d.depot == true,
        gtype = gtype, group = gtype == 'public' and '' or d.group, grade = gtype == 'public' and 0 or grade,
        shared = gtype ~= 'public' and d.shared == true,
        points = points, spawns = spawns, z = minZ, height = height,
    }
end

local function save(g, isNew)
    local values = { g.label, g.vtype, g.depot and 1 or 0, g.gtype, g.group, g.grade, g.shared and 1 or 0,
        json.encode(g.points), json.encode(g.spawns), g.z, g.height }
    if isNew then
        table.insert(values, 1, g.id)
        values[#values + 1] = g.createdBy
        values[#values + 1] = g.createdAt
        MySQL.insert.await([[INSERT INTO f_garasi (id, label, vtype, depot, gtype, grp, grade, shared, points, spawns, z, height, created_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], values)
    else
        values[#values + 1] = g.id
        MySQL.update.await([[UPDATE f_garasi SET label = ?, vtype = ?, depot = ?, gtype = ?, grp = ?, grade = ?, shared = ?,
            points = ?, spawns = ?, z = ?, height = ? WHERE id = ?]], values)
    end
end

local function adminCallback(name, fn)
    lib.callback.register('f_garages:editor:' .. name, function(src, ...)
        if not isAdmin(src) then
            log(src, 'memanggil editor garasi tanpa izin')
            return { ok = false, msg = 'Tidak punya izin.' }
        end
        return fn(src, ...)
    end)
end

adminCallback('open', function()
    return { ok = true, garages = adminList(), groups = groupCatalog(), grades = EC.grades, defaultHeight = EC.defaultHeight }
end)

adminCallback('create', function(src, d)
    local g, err = validate(d)
    if not g then return { ok = false, msg = err } end

    local id
    repeat id = ('fgar_%d%d'):format(os.time(), math.random(100, 999)) until not Garages[id]
    g.id, g.createdBy, g.createdAt = id, GetPlayerName(src), os.time()

    save(g, true)
    Edited[id] = g
    GarageRegister(id, toGarageConfig(g))
    log(src, ('membuat garasi %s "%s" (%s, %s)'):format(id, g.label, g.vtype, g.gtype))
    return { ok = true, msg = 'Garasi dibuat dan langsung aktif.', garages = adminList() }
end)

adminCallback('update', function(src, id, d)
    local old = Edited[id]
    if not old then return { ok = false, msg = 'Garasi ini tidak bisa diubah dari editor.' } end
    local g, err = validate(d)
    if not g then return { ok = false, msg = err } end

    g.id, g.createdBy, g.createdAt = id, old.createdBy, old.createdAt
    save(g, false)
    Edited[id] = g
    GarageRegister(id, toGarageConfig(g))
    log(src, ('mengubah garasi %s "%s"'):format(id, g.label))
    return { ok = true, msg = 'Garasi diperbarui.', garages = adminList() }
end)

adminCallback('delete', function(src, id)
    local g = Edited[id]
    if not g then return { ok = false, msg = 'Garasi ini tidak bisa dihapus dari editor.' } end

    local fallback = EC.fallback[g.vtype]
    local moved = MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE garage = ?', { fallback, id }) or 0
    MySQL.update.await('DELETE FROM f_garasi WHERE id = ?', { id })
    Edited[id] = nil
    GarageUnregister(id)
    log(src, ('menghapus garasi %s "%s" (%d kendaraan dipindah ke %s)'):format(id, g.label, moved, fallback))
    local msg = moved > 0 and ('Garasi dihapus. %d kendaraan di dalamnya dipindah ke %s.'):format(moved, fallback) or 'Garasi dihapus.'
    return { ok = true, msg = msg, garages = adminList() }
end)

lib.addCommand(EC.command, { help = 'Editor garasi (admin)' }, function(src)
    if not isAdmin(src) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kamu tidak punya akses ke editor garasi.' })
    end
    TriggerClientEvent('f_garages:client:openEditor', src)
end)
