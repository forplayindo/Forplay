local ox = exports.ox_inventory

---@type table<string, table>
local Stashes = {}

local allowed = {}
for _, id in ipairs(Config.AllowedLicenses) do allowed[id:lower()] = true end

local function isAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if allowed[id:lower()] then return true end
    end
    return false
end

local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = kind or 'inform' })
end

local function log(src, msg)
    local name = src and GetPlayerName(src) or 'console'
    print(('^3[f_stash]^0 %s: %s'):format(name, msg))
    lib.logger(src or 0, 'f_stash', msg)
end

---------------------------------------------------------------------------
-- ox_inventory
---------------------------------------------------------------------------
local function register(s)
    local groups = s.gtype ~= 'public' and { [s.group] = s.grade } or nil
    ox:RegisterStash(s.id, s.label, s.slots, s.weight * 1000, s.personal or nil, groups, s.coords)
end

-- Stash yang dihapus tetap tercatat di ox_inventory sampai restart; dikunci ke grup yang tidak ada.
local function lockDeleted(id)
    ox:RegisterStash(id, 'Dihapus', 1, 1, nil, { ['__f_stash_deleted'] = 0 }, vec3(0.0, 0.0, -1000.0))
end

-- Simpan & lepas stash yang sedang dimuat di memori. Wajib sebelum mendaftar ulang stash personal,
-- karena RegisterStash ox_inventory merusak owner salinan personal yang sedang dimuat.
local function unload(s)
    if not s.personal then
        ox:RemoveInventory(s.id)
        return
    end

    local owners = {}
    for _, row in ipairs(MySQL.query.await("SELECT owner FROM ox_inventory WHERE name = ? AND owner <> ''", { s.id }) or {}) do
        owners[row.owner] = true
    end
    for _, pd in ipairs(exports.qbx_core:GetPlayersData()) do
        owners[pd.citizenid] = true
    end
    for owner in pairs(owners) do
        ox:RemoveInventory(('%s:%s'):format(s.id, owner))
    end
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local function fromRow(r)
    return {
        id = r.id, label = r.label, coords = vec3(r.x, r.y, r.z),
        gtype = r.gtype, group = r.grp, grade = r.grade,
        personal = r.personal == 1 or r.personal == true,
        duty = r.duty == 1 or r.duty == true,
        slots = r.slots, weight = r.weight,
        createdBy = r.created_by, createdAt = r.created_at,
    }
end

local function publicList()
    local list = {}
    for _, s in pairs(Stashes) do
        list[#list + 1] = {
            id = s.id, label = s.label, coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z },
            gtype = s.gtype, group = s.group, grade = s.grade, duty = s.duty,
        }
    end
    return list
end

local function broadcast()
    TriggerClientEvent('f_stash:client:sync', -1, publicList())
end

local function insert(s, by)
    MySQL.insert.await([[INSERT IGNORE INTO f_stash (id, label, x, y, z, gtype, grp, grade, personal, duty, slots, weight, created_by, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        s.id, s.label, s.coords.x, s.coords.y, s.coords.z, s.gtype, s.group, s.grade,
        s.personal and 1 or 0, s.duty and 1 or 0, s.slots, s.weight, by, os.time(),
    })
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_stash (
        id VARCHAR(60) NOT NULL PRIMARY KEY,
        label VARCHAR(60) NOT NULL,
        x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL,
        gtype VARCHAR(10) NOT NULL,
        grp VARCHAR(60) NOT NULL,
        grade INT NOT NULL DEFAULT 0,
        personal TINYINT(1) NOT NULL DEFAULT 0,
        duty TINYINT(1) NOT NULL DEFAULT 0,
        slots INT NOT NULL,
        weight INT NOT NULL,
        created_by VARCHAR(80) NULL,
        created_at INT NOT NULL DEFAULT 0
    )]])

    if GetResourceKvpInt('seeded') ~= 1 then
        for _, s in ipairs(Config.Seed) do insert(s, 'migrasi') end
        SetResourceKvpInt('seeded', 1)
        print('^2[f_stash]^0 stash lama dimigrasikan ke tabel f_stash')
    end

    for _, r in ipairs(MySQL.query.await('SELECT * FROM f_stash') or {}) do
        local s = fromRow(r)
        Stashes[s.id] = s
        register(s)
    end

    broadcast()
end)

lib.callback.register('f_stash:getList', function()
    return publicList()
end)

---------------------------------------------------------------------------
-- Keamanan buka stash (server-side): personal hanya milik sendiri, on duty bila diwajibkan.
-- Grup/grade & jarak sudah dicek oleh ox_inventory sendiri.
---------------------------------------------------------------------------
local function openHook(p)
    if p.inventoryType ~= 'stash' then return end
    local base, owner = p.inventoryId:match('^([^:]+):?(.*)$')
    local s = Stashes[base]
    if not s then return end

    local player = exports.qbx_core:GetPlayer(p.source)
    if not player then return false end
    local pd = player.PlayerData

    if s.personal and owner ~= pd.citizenid then
        log(p.source, ('mencoba membuka stash personal orang lain: %s'):format(p.inventoryId))
        return false
    end

    if s.duty and s.gtype == 'job' and not (pd.job.name == s.group and pd.job.onduty) then
        notify(p.source, 'Kamu harus on duty untuk membuka stash ini.', 'error')
        return false
    end
end

ox:registerHook('openInventory', openHook)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= 'ox_inventory' then return end
    for _, s in pairs(Stashes) do register(s) end
    ox:registerHook('openInventory', openHook)
end)

---------------------------------------------------------------------------
-- Admin
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

local function adminList()
    local list = {}
    for _, s in pairs(Stashes) do
        list[#list + 1] = {
            id = s.id, label = s.label, coords = { x = s.coords.x, y = s.coords.y, z = s.coords.z },
            gtype = s.gtype, group = s.group, grade = s.grade, personal = s.personal, duty = s.duty,
            slots = s.slots, weight = s.weight, createdBy = s.createdBy, createdAt = s.createdAt,
            protected = Config.Protected[s.id],
        }
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

local validGrade = {}
for _, g in ipairs(Config.Grades) do validGrade[g] = true end

---@return table? data, string? err
local function validate(d, editing)
    if type(d) ~= 'table' then return nil, 'Data tidak valid.' end
    local label = type(d.label) == 'string' and d.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #label < 2 or #label > 40 then return nil, 'Nama stash 2-40 karakter.' end

    local slots, weight, grade = math.tointeger(tonumber(d.slots)), math.tointeger(tonumber(d.weight)), math.tointeger(tonumber(d.grade))
    if not slots or slots < 1 or slots > Config.MaxSlots then return nil, ('Slot 1-%d.'):format(Config.MaxSlots) end
    if not weight or weight < 1 or weight > Config.MaxWeight then return nil, ('Berat 1-%d kg.'):format(Config.MaxWeight) end
    if not grade or not validGrade[grade] then return nil, 'Grade tidak valid.' end
    local public = d.gtype == 'public'
    if not public and not groupExists(d.gtype, d.group) then return nil, 'Job/gang tidak ditemukan.' end

    if editing and slots < editing.slots then
        return nil, ('Slot tidak boleh dikurangi (sekarang %d), barang di slot belakang bisa hilang.'):format(editing.slots)
    end

    return {
        label = label, slots = slots, weight = weight,
        gtype = d.gtype, group = public and '' or d.group, grade = public and 0 or grade,
        personal = editing and editing.personal or d.personal == true,
        duty = d.gtype == 'job' and d.duty == true,
    }
end

local function adminCallback(name, fn)
    lib.callback.register('f_stash:admin:' .. name, function(src, ...)
        if not isAdmin(src) then
            log(src, 'memanggil menu admin stash tanpa izin')
            return { ok = false, msg = 'Tidak punya izin.' }
        end
        return fn(src, ...)
    end)
end

adminCallback('open', function()
    return { ok = true, stashes = adminList(), groups = groupCatalog(), grades = Config.Grades }
end)

adminCallback('create', function(src, d)
    local data, err = validate(d)
    if not data then return { ok = false, msg = err } end

    local id
    repeat id = ('fstash_%s%d'):format(os.time(), math.random(100, 999)) until not Stashes[id]

    data.id = id
    data.coords = GetEntityCoords(GetPlayerPed(src))
    data.createdBy = GetPlayerName(src)
    data.createdAt = os.time()
    insert(data, data.createdBy)

    Stashes[id] = data
    register(data)
    broadcast()
    log(src, ('membuat stash %s "%s" (%s %s grade %d, %s)'):format(id, data.label, data.gtype, data.group, data.grade, data.personal and 'personal' or 'bersama'))
    return { ok = true, msg = 'Stash dibuat di posisi kamu.', stashes = adminList() }
end)

adminCallback('update', function(src, id, d)
    local s = Stashes[id]
    if not s then return { ok = false, msg = 'Stash tidak ditemukan.' } end
    local data, err = validate(d, s)
    if not data then return { ok = false, msg = err } end

    MySQL.update.await('UPDATE f_stash SET label = ?, gtype = ?, grp = ?, grade = ?, duty = ?, slots = ?, weight = ? WHERE id = ?', {
        data.label, data.gtype, data.group, data.grade, data.duty and 1 or 0, data.slots, data.weight, id,
    })

    -- Lepas salinan yang dimuat: ox_inventory tidak bisa mengosongkan groups lewat daftar ulang (mis. job -> umum).
    unload(s)
    for k, v in pairs(data) do s[k] = v end
    register(s)
    broadcast()
    log(src, ('mengubah stash %s "%s" (%s %s grade %d)'):format(id, s.label, s.gtype, s.group, s.grade))
    return { ok = true, msg = 'Stash diperbarui.', stashes = adminList() }
end)

adminCallback('move', function(src, id)
    local s = Stashes[id]
    if not s then return { ok = false, msg = 'Stash tidak ditemukan.' } end

    local c = GetEntityCoords(GetPlayerPed(src))
    MySQL.update.await('UPDATE f_stash SET x = ?, y = ?, z = ? WHERE id = ?', { c.x, c.y, c.z, id })

    if s.personal then unload(s) end
    s.coords = c
    register(s)
    broadcast()
    log(src, ('memindah stash %s "%s" ke %.2f, %.2f, %.2f'):format(id, s.label, c.x, c.y, c.z))
    return { ok = true, msg = 'Stash dipindah ke posisi kamu. Isi tetap aman.', stashes = adminList() }
end)

adminCallback('delete', function(src, id)
    local s = Stashes[id]
    if not s then return { ok = false, msg = 'Stash tidak ditemukan.' } end
    if Config.Protected[id] then
        return { ok = false, msg = ('Stash ini dipakai %s, tidak bisa dihapus (boleh dipindah).'):format(Config.Protected[id]) }
    end

    Stashes[id] = nil
    broadcast()
    unload(s)
    lockDeleted(id)
    unload(s) -- yang sempat terbuka selama proses di atas
    MySQL.update.await('DELETE FROM ox_inventory WHERE name = ?', { id })
    MySQL.update.await('DELETE FROM f_stash WHERE id = ?', { id })
    log(src, ('menghapus stash %s "%s" beserta isinya'):format(id, s.label))
    return { ok = true, msg = 'Stash dan isinya dihapus.', stashes = adminList() }
end)

lib.addCommand(Config.Command, {
    help = 'Kelola stash job/gang',
}, function(src)
    if not isAdmin(src) then
        return notify(src, 'Kamu tidak punya akses ke menu stash.', 'error')
    end
    TriggerClientEvent('f_stash:client:openAdmin', src)
end)
