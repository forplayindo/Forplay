---@type table<integer, table>
local Points = {}

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
    print(('^3[f_spawnpoints]^0 %s: %s'):format(name, msg))
    lib.logger(src or 0, 'f_spawnpoints', msg)
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local function fromRow(r)
    return {
        id = r.id, label = r.label,
        coords = vec4(r.x, r.y, r.z, r.h),
        owner = r.owner, ownerName = r.owner_name,
        createdBy = r.created_by, createdAt = r.created_at,
    }
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_spawnpoints (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        label VARCHAR(60) NOT NULL,
        x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, h FLOAT NOT NULL DEFAULT 0,
        stype VARCHAR(10) NOT NULL DEFAULT 'house',
        owner VARCHAR(50) NULL,
        owner_name VARCHAR(100) NULL,
        created_by VARCHAR(80) NULL,
        created_at INT NOT NULL DEFAULT 0,
        INDEX idx_owner (owner)
    )]])

    for _, r in ipairs(MySQL.query.await("SELECT * FROM f_spawnpoints WHERE stype = 'house'") or {}) do
        Points[r.id] = fromRow(r)
    end
end)

---------------------------------------------------------------------------
-- Untuk f_multichar: rumah milik semua karakter akun ini.
-- Pemilik dicocokkan lewat license, jadi client tidak bisa meminta rumah karakter orang lain.
---------------------------------------------------------------------------
---@return table<string, {id: integer, label: string, coords: vector4}[]>
exports('GetCharacterSpawns', function(license, license2)
    local out = {}
    if not next(Points) then return out end

    local mine = {}
    for _, row in ipairs(MySQL.query.await('SELECT citizenid FROM players WHERE license = ? OR license = ?', { license or '', license2 or '' }) or {}) do
        mine[row.citizenid] = true
    end

    for _, p in pairs(Points) do
        if p.owner and mine[p.owner] then
            out[p.owner] = out[p.owner] or {}
            out[p.owner][#out[p.owner] + 1] = { id = p.id, label = p.label, coords = p.coords }
        end
    end
    for _, list in pairs(out) do
        table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    end
    return out
end)

---------------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------------
local function adminList()
    local list = {}
    for _, p in pairs(Points) do
        list[#list + 1] = {
            id = p.id, label = p.label,
            coords = { x = p.coords.x, y = p.coords.y, z = p.coords.z, w = p.coords.w },
            owner = p.owner, ownerName = p.ownerName,
            createdBy = p.createdBy, createdAt = p.createdAt,
        }
    end
    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

local function cleanLabel(label)
    label = type(label) == 'string' and label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #label < 2 or #label > 40 then return nil end
    return label
end

local function adminPos(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    return vec4(c.x, c.y, c.z, GetEntityHeading(ped))
end

---Cari karakter dari ID server (online) atau citizenid (online/offline).
---@return string? citizenid, string? name, integer? source
local function findCharacter(target)
    target = type(target) == 'string' and target:gsub('%s+', '') or tostring(target or '')
    if target == '' then return nil end

    local srcId = tonumber(target)
    if srcId then
        local player = exports.qbx_core:GetPlayer(srcId)
        if not player then return nil end
        local ci = player.PlayerData.charinfo
        return player.PlayerData.citizenid, ('%s %s'):format(ci.firstname, ci.lastname), srcId
    end

    local citizenid = target:upper()
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    if not row then return nil end
    local ci = json.decode(row.charinfo) or {}
    local online = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    return citizenid, ('%s %s'):format(ci.firstname or '?', ci.lastname or ''), online and online.PlayerData.source
end

local function adminCallback(name, fn)
    lib.callback.register('f_spawnpoints:admin:' .. name, function(src, ...)
        if not isAdmin(src) then
            log(src, 'memanggil menu admin spawn rumah tanpa izin')
            return { ok = false, msg = 'Tidak punya izin.' }
        end
        return fn(src, ...)
    end)
end

adminCallback('open', function()
    return { ok = true, points = adminList() }
end)

adminCallback('create', function(src, d)
    local label = cleanLabel(type(d) == 'table' and d.label)
    if not label then return { ok = false, msg = 'Nama rumah 2-40 karakter.' } end

    local c = adminPos(src)
    local by = GetPlayerName(src)
    local id = MySQL.insert.await('INSERT INTO f_spawnpoints (label, x, y, z, h, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        label, c.x, c.y, c.z, c.w, by, os.time(),
    })
    if not id then return { ok = false, msg = 'Gagal menyimpan ke database.' } end

    Points[id] = { id = id, label = label, coords = c, createdBy = by, createdAt = os.time() }
    log(src, ('membuat rumah #%d "%s" di %.2f, %.2f, %.2f'):format(id, label, c.x, c.y, c.z))
    return { ok = true, msg = 'Rumah dibuat. Titik spawn = posisi & arah hadap kamu.', points = adminList() }
end)

adminCallback('rename', function(src, id, d)
    local p = Points[tonumber(id)]
    if not p then return { ok = false, msg = 'Rumah tidak ditemukan.' } end
    local label = cleanLabel(type(d) == 'table' and d.label)
    if not label then return { ok = false, msg = 'Nama rumah 2-40 karakter.' } end

    MySQL.update.await('UPDATE f_spawnpoints SET label = ? WHERE id = ?', { label, p.id })
    log(src, ('mengganti nama rumah #%d "%s" -> "%s"'):format(p.id, p.label, label))
    p.label = label
    return { ok = true, msg = 'Nama rumah diperbarui.', points = adminList() }
end)

adminCallback('move', function(src, id)
    local p = Points[tonumber(id)]
    if not p then return { ok = false, msg = 'Rumah tidak ditemukan.' } end

    local c = adminPos(src)
    MySQL.update.await('UPDATE f_spawnpoints SET x = ?, y = ?, z = ?, h = ? WHERE id = ?', { c.x, c.y, c.z, c.w, p.id })
    p.coords = c
    log(src, ('memindah titik spawn rumah #%d "%s" ke %.2f, %.2f, %.2f'):format(p.id, p.label, c.x, c.y, c.z))
    return { ok = true, msg = 'Titik spawn dipindah ke posisi & arah hadap kamu.', points = adminList() }
end)

adminCallback('give', function(src, id, target)
    local p = Points[tonumber(id)]
    if not p then return { ok = false, msg = 'Rumah tidak ditemukan.' } end

    local citizenid, name, ownerSrc = findCharacter(target)
    if not citizenid then return { ok = false, msg = 'Pemain tidak ditemukan. Isi ID server (online) atau citizenid.' } end
    if p.owner == citizenid then return { ok = false, msg = ('Rumah ini sudah milik %s.'):format(name) } end

    MySQL.update.await('UPDATE f_spawnpoints SET owner = ?, owner_name = ? WHERE id = ?', { citizenid, name, p.id })
    log(src, ('menyerahkan rumah #%d "%s" ke %s (%s), sebelumnya %s'):format(p.id, p.label, name, citizenid, p.owner or 'kosong'))

    local oldOwner = p.owner and exports.qbx_core:GetPlayerByCitizenId(p.owner)
    if oldOwner then notify(oldOwner.PlayerData.source, ('%s bukan milikmu lagi.'):format(p.label), 'error') end
    if ownerSrc then notify(ownerSrc, ('Kamu sekarang pemilik %s. Pilih rumah ini saat masuk kota untuk spawn di sana.'):format(p.label), 'success') end

    p.owner, p.ownerName = citizenid, name
    return { ok = true, msg = ('Rumah diserahkan ke %s.'):format(name), points = adminList() }
end)

adminCallback('revoke', function(src, id)
    local p = Points[tonumber(id)]
    if not p then return { ok = false, msg = 'Rumah tidak ditemukan.' } end
    if not p.owner then return { ok = false, msg = 'Rumah ini belum ada pemiliknya.' } end

    MySQL.update.await('UPDATE f_spawnpoints SET owner = NULL, owner_name = NULL WHERE id = ?', { p.id })
    log(src, ('mencabut rumah #%d "%s" dari %s (%s)'):format(p.id, p.label, p.ownerName or '?', p.owner))

    local oldOwner = exports.qbx_core:GetPlayerByCitizenId(p.owner)
    if oldOwner then notify(oldOwner.PlayerData.source, ('%s bukan milikmu lagi.'):format(p.label), 'error') end

    p.owner, p.ownerName = nil, nil
    return { ok = true, msg = 'Pemilik dicabut, rumah kosong.', points = adminList() }
end)

adminCallback('delete', function(src, id)
    local p = Points[tonumber(id)]
    if not p then return { ok = false, msg = 'Rumah tidak ditemukan.' } end

    MySQL.update.await('DELETE FROM f_spawnpoints WHERE id = ?', { p.id })
    Points[p.id] = nil
    log(src, ('menghapus rumah #%d "%s" (pemilik %s)'):format(p.id, p.label, p.owner or 'kosong'))
    return { ok = true, msg = 'Rumah dihapus.', points = adminList() }
end)

lib.addCommand(Config.Command, {
    help = 'Kelola titik spawn rumah MLO',
}, function(src)
    if not isAdmin(src) then
        return notify(src, 'Kamu tidak punya akses ke menu ini.', 'error')
    end
    TriggerClientEvent('f_spawnpoints:client:openAdmin', src)
end)
