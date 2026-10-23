-- Panel admin: daftar karakter yang tidak aktif + hapus permanen (pemain offline saja).
-- Semua aksi dicek ulang di server (ACE 'admin'); client hanya menampilkan.
local cfg = require 'config'

---@type { query: string }[] query hapus untuk tabel yang benar-benar ada (diisi saat start)
local deleteQueries = {}
local ready = false

local function isAdmin(src)
    return IsPlayerAceAllowed(tostring(src), 'admin')
end

CreateThread(function()
    -- hanya ambil kolom dari tabel yang dipakai (bukan seluruh database) agar hasil query kecil
    local tables, seen = { 'mechanic_vehicle_condition' }, { mechanic_vehicle_condition = true }
    for _, d in ipairs(cfg.deleteTables) do
        local t = d[1]:lower()
        if not seen[t] then seen[t] = true; tables[#tables + 1] = t end
    end
    local rows = MySQL.query.await(('SELECT TABLE_NAME AS t, COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) IN (%s)')
        :format(('?,'):rep(#tables):sub(1, -2)), tables) or {}
    local exists = {}
    for _, r in ipairs(rows) do exists[r.t:lower() .. '.' .. r.c:lower()] = true end

    -- kondisi kendaraan (f_mechanicjob) tersimpan per vehicle_id, jadi dihapus sebelum player_vehicles
    if exists['mechanic_vehicle_condition.vehicle_id'] then
        deleteQueries[#deleteQueries + 1] = 'DELETE FROM `mechanic_vehicle_condition` WHERE `vehicle_id` IN (SELECT `id` FROM `player_vehicles` WHERE `citizenid` = ?)'
    end
    for _, d in ipairs(cfg.deleteTables) do
        if exists[d[1]:lower() .. '.' .. d[2]:lower()] then
            deleteQueries[#deleteQueries + 1] = ('DELETE FROM `%s` WHERE `%s` = ?'):format(d[1], d[2])
        end
    end
    deleteQueries[#deleteQueries + 1] = 'DELETE FROM `player_vehicles` WHERE `citizenid` = ?'
    deleteQueries[#deleteQueries + 1] = 'DELETE FROM `players` WHERE `citizenid` = ?'
    ready = true
end)

local function fullName(charinfo)
    local ok, ci = pcall(json.decode, charinfo or '')
    if not ok or type(ci) ~= 'table' then return '-' end
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function jobLabel(job)
    local ok, j = pcall(json.decode, job or '')
    if not ok or type(j) ~= 'table' then return '-' end
    return j.label or j.name or '-'
end

local function bankOf(money)
    local ok, m = pcall(json.decode, money or '')
    if not ok or type(m) ~= 'table' then return 0, 0 end
    return math.floor(tonumber(m.bank) or 0), math.floor(tonumber(m.cash) or 0)
end

lib.callback.register('f_karakter:server:list', function(src, filter)
    if not isAdmin(src) then return { error = 'Tidak punya akses' } end
    filter = type(filter) == 'table' and filter or {}
    local days = math.max(0, math.min(3650, math.floor(tonumber(filter.days) or cfg.defaultDays)))
    local search = type(filter.search) == 'string' and filter.search:sub(1, 40) or ''
    local like = '%' .. search:gsub('[%%_\\]', '\\%0') .. '%'

    local rows = MySQL.query.await([[
        SELECT p.citizenid, p.license, p.name, p.charinfo, p.job, p.money,
               UNIX_TIMESTAMP(p.last_logged_out) AS lastSeen,
               (SELECT COUNT(*) FROM player_vehicles v WHERE v.citizenid = p.citizenid) AS vehicles
        FROM players p
        WHERE (? = 0 OR p.last_logged_out IS NULL OR p.last_logged_out < NOW() - INTERVAL ? DAY)
          AND (? = '' OR p.citizenid LIKE ? OR p.charinfo LIKE ? OR p.name LIKE ?)
        ORDER BY p.last_logged_out IS NULL DESC, p.last_logged_out ASC
        LIMIT ?
    ]], { days, days, search, like, like, like, cfg.pageSize }) or {}

    local list = {}
    for i, r in ipairs(rows) do
        local bank, cash = bankOf(r.money)
        list[i] = {
            citizenid = r.citizenid,
            name = fullName(r.charinfo),
            account = r.name,
            license = r.license,
            job = jobLabel(r.job),
            bank = bank,
            cash = cash,
            vehicles = tonumber(r.vehicles) or 0,
            lastSeen = tonumber(r.lastSeen),
            online = exports.qbx_core:GetPlayerByCitizenId(r.citizenid) ~= nil,
        }
    end
    return { list = list, days = days, now = os.time() }
end)

lib.callback.register('f_karakter:server:delete', function(src, citizenid)
    if not isAdmin(src) then return { error = 'Tidak punya akses' } end
    if not ready then return { error = 'Server belum siap, coba lagi' } end
    if type(citizenid) ~= 'string' or not citizenid:match('^%w+$') or #citizenid > 50 then return { error = 'Citizen ID tidak valid' } end
    if exports.qbx_core:GetPlayerByCitizenId(citizenid) then return { error = 'Karakter sedang dimainkan (online). Minta pemain logout dulu.' } end

    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    if not row then return { error = 'Karakter tidak ditemukan' } end

    local queries = {}
    for i, q in ipairs(deleteQueries) do queries[i] = { query = q, values = { citizenid } } end
    local ok = MySQL.transaction.await(queries)
    if not ok then return { error = 'Gagal menghapus (database). Tidak ada data yang berubah.' } end

    lib.print.info(('%s (%s) menghapus karakter %s - %s'):format(GetPlayerName(src), src, citizenid, fullName(row.charinfo)))
    return { ok = true }
end)

lib.addCommand(cfg.command, {
    help = 'Admin: kelola / hapus karakter tidak aktif',
    restricted = 'group.admin',
}, function(src)
    if not isAdmin(src) then return end
    TriggerClientEvent('f_karakter:client:open', src, cfg.defaultDays)
end)
