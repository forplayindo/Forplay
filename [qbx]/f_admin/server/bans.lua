---------------------------------------------------------------------------
-- Ban HWID: semua identifier + hardware token (GetPlayerTokens). Akun baru dari PC
-- yang sama ikut tertolak dan identitasnya ditempel ke ban yang sama.
-- IP disimpan tapi TIDAK dipakai mencocokkan (warnet / CGNAT operator seluler berbagi IP).
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_admin_bans` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(100),
            `license` VARCHAR(100),
            `reason` VARCHAR(255),
            `banned_by` VARCHAR(100),
            `origin` VARCHAR(20) DEFAULT 'Panel',
            `expire` INT NULL,
            `alts` INT DEFAULT 0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_admin_ban_ids` (
            `ban_id` INT NOT NULL,
            `value` VARCHAR(255) NOT NULL,
            `kind` VARCHAR(10) NOT NULL,
            PRIMARY KEY (`ban_id`, `value`),
            INDEX `idx_value` (`value`)
        )
    ]])
end)

function DurationText(sec)
    if not sec or sec <= 0 then return 'permanen' end
    local d, h = math.floor(sec / 86400), math.floor(sec % 86400 / 3600)
    if d >= 30 and d % 30 == 0 then return ('%d bulan'):format(d // 30) end
    if d > 0 then return h > 0 and ('%d hari %d jam'):format(d, h) or ('%d hari'):format(d) end
    return ('%d jam'):format(math.max(1, h))
end

---@return { value: string, kind: string }[] matchable, string? ip
local function collect(src)
    local list, ip = {}, nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('^ip:') then ip = id else list[#list + 1] = { value = id, kind = 'id' } end
    end
    for i = 0, GetNumPlayerTokens(src) - 1 do
        local tok = GetPlayerToken(src, i)
        if tok then list[#list + 1] = { value = tok, kind = 'hw' } end
    end
    return list, ip
end

local function insertIds(banId, list)
    if #list == 0 then return end
    local ph, vals = {}, {}
    for _, e in ipairs(list) do
        ph[#ph + 1] = '(?, ?, ?)'
        vals[#vals + 1] = banId
        vals[#vals + 1] = e.value
        vals[#vals + 1] = e.kind
    end
    MySQL.insert.await('INSERT IGNORE INTO f_admin_ban_ids (ban_id, value, kind) VALUES ' .. table.concat(ph, ','), vals)
end

---Ban pemain online. duration 0 = permanen.
---@return integer? banId
function BanPlayer(src, reason, duration, bannedBy)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end
    local list, ip = collect(src)
    local lic = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    if ip then list[#list + 1] = { value = ip, kind = 'ip' } end
    local expire = (duration and duration > 0) and (os.time() + duration) or nil
    local origin = bannedBy == 'Anti-cheat' and 'Anti-cheat' or 'Panel'

    local id = MySQL.insert.await('INSERT INTO f_admin_bans (name, license, reason, banned_by, origin, expire) VALUES (?, ?, ?, ?, ?, ?)',
        { CharName(src) .. ' (' .. (GetPlayerName(src) or '?') .. ')', lic, reason, bannedBy or 'Staff', origin, expire })
    insertIds(id, list)

    DropPlayer(tostring(src), ('Kamu di-ban dari server ini.\nAlasan: %s\nLama: %s\nID ban: #%d'):format(reason, DurationText(duration), id))
    return id
end

exports('BanPlayer', BanPlayer)

---------------------------------------------------------------- cek saat masuk
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Memeriksa status ban…')

    local list = collect(src)
    if #list == 0 then return deferrals.done() end
    local ph, vals = {}, {}
    for _, e in ipairs(list) do ph[#ph + 1] = '?'; vals[#vals + 1] = e.value end

    local ok, ban = pcall(MySQL.single.await, ([[
        SELECT b.* FROM f_admin_ban_ids i JOIN f_admin_bans b ON b.id = i.ban_id
        WHERE i.kind <> 'ip' AND i.value IN (%s) AND (b.expire IS NULL OR b.expire > UNIX_TIMESTAMP())
        ORDER BY b.id DESC LIMIT 1]]):format(table.concat(ph, ',')), vals)
    if not ok or not ban then return deferrals.done() end

    -- akun / identitas baru dari PC yang sama ditempel ke ban ini
    local known = MySQL.query.await('SELECT value FROM f_admin_ban_ids WHERE ban_id = ?', { ban.id }) or {}
    local have, fresh, newLicense = {}, {}, false
    for _, k in ipairs(known) do have[k.value] = true end
    for _, e in ipairs(list) do
        if not have[e.value] then
            fresh[#fresh + 1] = e
            if e.value:find('^license2?:') then newLicense = true end
        end
    end
    if #fresh > 0 then
        insertIds(ban.id, fresh)
        if newLicense then MySQL.update('UPDATE f_admin_bans SET alts = alts + 1 WHERE id = ?', { ban.id }) end
    end

    local untilText = ban.expire and os.date('%d/%m/%Y %H:%M', ban.expire) or 'Permanen'
    deferrals.done(('Kamu di-ban dari server ini.\nAlasan: %s\nSampai: %s\nID ban: #%d'):format(ban.reason or '-', untilText, ban.id))
end)

---------------------------------------------------------------- Daftar Ban
Handle('bans', 'player.unban', function()
    local rows = MySQL.query.await([[
        SELECT b.id, b.name, b.license, b.reason, b.banned_by, b.origin, b.expire, b.alts,
            SUM(i.kind = 'id') AS ids, SUM(i.kind = 'hw') AS hw
        FROM f_admin_bans b LEFT JOIN f_admin_ban_ids i ON i.ban_id = b.id
        WHERE b.expire IS NULL OR b.expire > UNIX_TIMESTAMP()
        GROUP BY b.id ORDER BY b.id DESC LIMIT 300]]) or {}
    for _, r in ipairs(rows) do
        r.until_text = r.expire and os.date('%d/%m/%Y %H:%M', r.expire) or 'Permanen'
        r.ids, r.hw = tonumber(r.ids) or 0, tonumber(r.hw) or 0
    end
    return { ok = true, bans = rows }
end)

Handle('unban', 'player.unban', function(src, d)
    local id = tonumber(d.id)
    local ban = id and MySQL.single.await('SELECT name FROM f_admin_bans WHERE id = ?', { id })
    if not ban then return { ok = false, msg = 'Ban tidak ditemukan.' } end
    MySQL.query.await('DELETE FROM f_admin_ban_ids WHERE ban_id = ?', { id })
    MySQL.query.await('DELETE FROM f_admin_bans WHERE id = ?', { id })
    Log(src, 'ban', ('mencabut ban #%d **%s**'):format(id, ban.name))
    return { ok = true, msg = 'Ban ' .. ban.name .. ' dicabut' }
end)

-- ban kedaluwarsa dibersihkan saat start
CreateThread(function()
    Wait(5000)
    local old = MySQL.query.await('SELECT id FROM f_admin_bans WHERE expire IS NOT NULL AND expire < UNIX_TIMESTAMP()') or {}
    for _, r in ipairs(old) do
        MySQL.query.await('DELETE FROM f_admin_ban_ids WHERE ban_id = ?', { r.id })
        MySQL.query.await('DELETE FROM f_admin_bans WHERE id = ?', { r.id })
    end
end)
