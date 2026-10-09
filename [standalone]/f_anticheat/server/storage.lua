Storage = {}

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `f_anticheat_bans` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(100),
            `license` VARCHAR(100),
            `discord` VARCHAR(100),
            `ip` VARCHAR(64),
            `category` VARCHAR(50),
            `reason` VARCHAR(255),
            `banned_by` VARCHAR(100),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_license` (`license`),
            INDEX `idx_discord` (`discord`),
            INDEX `idx_ip` (`ip`)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `f_anticheat_log` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(100),
            `license` VARCHAR(100),
            `category` VARCHAR(50),
            `points` INT,
            `total_points` INT,
            `reason` VARCHAR(255),
            `action` VARCHAR(20),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end)

---@param ban { name: string, license: string?, discord: string?, ip: string?, category: string, reason: string, bannedBy: string }
function Storage.InsertBan(ban)
    return MySQL.insert.await(
        'INSERT INTO f_anticheat_bans (name, license, discord, ip, category, reason, banned_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { ban.name, ban.license, ban.discord, ban.ip, ban.category, ban.reason, ban.bannedBy }
    )
end

---@param identifiers { license: string?, discord: string?, ip: string? }
---@return table? ban
function Storage.FindBan(identifiers)
    if not identifiers.license and not identifiers.discord and not identifiers.ip then return nil end

    local clauses = {}
    local values = {}

    if identifiers.license then
        clauses[#clauses + 1] = '`license` = ?'
        values[#values + 1] = identifiers.license
    end
    if identifiers.discord then
        clauses[#clauses + 1] = '`discord` = ?'
        values[#values + 1] = identifiers.discord
    end
    if identifiers.ip then
        clauses[#clauses + 1] = '`ip` = ?'
        values[#values + 1] = identifiers.ip
    end

    return MySQL.single.await(
        ('SELECT * FROM f_anticheat_bans WHERE %s ORDER BY id DESC LIMIT 1'):format(table.concat(clauses, ' OR ')),
        values
    )
end

---@param identifier string license, discord id, or ip
---@return integer affectedRows
function Storage.RemoveBan(identifier)
    return MySQL.update.await(
        'DELETE FROM f_anticheat_bans WHERE `license` = ? OR `discord` = ? OR `ip` = ?',
        { identifier, identifier, identifier }
    )
end

---@param limit integer?
function Storage.GetRecentBans(limit)
    return MySQL.query.await('SELECT * FROM f_anticheat_bans ORDER BY id DESC LIMIT ?', { limit or 25 })
end

function Storage.InsertLog(entry)
    MySQL.insert('INSERT INTO f_anticheat_log (name, license, category, points, total_points, reason, action) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { entry.name, entry.license, entry.category, entry.points, entry.totalPoints, entry.reason, entry.action })
end
