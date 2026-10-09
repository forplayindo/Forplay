-- command bebas restriksi untuk cek status admin kamu sendiri (jawab "apakah saya admin?")
RegisterCommand('hygiene_whoami', function(source)
    if source == 0 then return end

    local ok, isAdmin = pcall(IsPlayerAceAllowed, source --[[@as string]], 'group.admin')
    if not ok then return end

    local license2 = GetPlayerIdentifierByType(source --[[@as string]], 'license2')

    pcall(function()
        exports.qbx_core:Notify(source, ('%s | license2: %s'):format(
            isAdmin and 'ADMIN' or 'BUKAN ADMIN', license2 or 'tidak ada'), isAdmin and 'success' or 'error', 20000)
    end)
end, false)

-- command khusus admin untuk testing HUD hygiene tanpa perlu nunggu drain/RNG lama
lib.addCommand('hygiene_set', {
    help = 'Set nilai HUD hygiene (testing): mandi | kencing | poop',
    restricted = 'group.admin',
    params = {
        { name = 'key', help = 'mandi | kencing | poop', type = 'string' },
        { name = 'value', help = 'nilai 0-100', type = 'number' },
    }
}, function(source, args)
    local key = args.key
    if key ~= 'mandi' and key ~= 'kencing' and key ~= 'poop' then
        exports.qbx_core:Notify(source, 'Key harus: mandi | kencing | poop', 'error')
        return
    end

    HygieneClampSet(source, key, args.value)
    HygieneSyncHud(source)
    exports.qbx_core:Notify(source, ('%s di-set ke %s'):format(key, args.value), 'success')
end)

lib.addCommand('hygiene_status', {
    help = 'Lihat nilai HUD hygiene kamu saat ini',
    restricted = 'group.admin',
}, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local meta = player.PlayerData.metadata

    exports.qbx_core:Notify(source, ('Mandi: %s | Kencing: %s | Poop: %s'):format(
        meta.mandi or 0, meta.kencing or 0, meta.poop or 0
    ), 'inform', 10000)
end)
