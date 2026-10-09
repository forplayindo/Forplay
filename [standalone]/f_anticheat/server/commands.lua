lib.addCommand('ac', {
    help = 'Anti-cheat admin tools: status | points <id> | resetpoints <id> | unban <identifier> | bans',
    restricted = Config.ExemptAce,
    params = {
        { name = 'action', help = 'status | points | resetpoints | unban | bans', type = 'string' },
        { name = 'target', help = 'player id or ban identifier', type = 'string', optional = true },
    }
}, function(source, args)
    local action = args.action
    local target = args.target

    if action == 'status' then
        exports.qbx_core:Notify(source, ('Entity spam: %s | Explosion: %s | Speed: %s | Weapon: %s | Health: %s'):format(
            tostring(Config.EntitySpam.enabled), tostring(Config.Explosion.enabled),
            tostring(Config.Speed.enabled), tostring(Config.Weapon.enabled), tostring(Config.Health.enabled)
        ), 'inform', 10000)
        return
    end

    if action == 'points' then
        local id = tonumber(target)
        if not id then exports.qbx_core:Notify(source, 'Usage: /ac points <playerId>', 'error') return end
        exports.qbx_core:Notify(source, ('Pemain %d punya %d poin anti-cheat'):format(id, exports.f_anticheat:GetPoints(id)), 'inform')
        return
    end

    if action == 'resetpoints' then
        local id = tonumber(target)
        if not id then exports.qbx_core:Notify(source, 'Usage: /ac resetpoints <playerId>', 'error') return end
        exports.f_anticheat:ResetPoints(id)
        exports.qbx_core:Notify(source, ('Poin anti-cheat pemain %d sudah dihapus'):format(id), 'success')
        return
    end

    if action == 'unban' then
        if not target or target == '' then exports.qbx_core:Notify(source, 'Usage: /ac unban <license|discord|ip>', 'error') return end
        local affected = Storage.RemoveBan(target)
        exports.qbx_core:Notify(source, affected > 0 and 'Ban dihapus.' or 'Ban tidak ditemukan.', affected > 0 and 'success' or 'error')
        return
    end

    if action == 'bans' then
        local bans = Storage.GetRecentBans(10)
        if not bans or #bans == 0 then
            exports.qbx_core:Notify(source, 'Belum ada ban tercatat.', 'inform')
            return
        end
        for _, b in ipairs(bans) do
            print(('[f_anticheat] #%s %s | %s | %s | %s'):format(b.id, b.name, b.category, b.reason, b.created_at))
        end
        exports.qbx_core:Notify(source, ('%d ban terbaru ditampilkan di konsol server.'):format(#bans), 'inform')
        return
    end

    exports.qbx_core:Notify(source, 'Unknown action. Use: status | points | resetpoints | unban | bans', 'error')
end)
