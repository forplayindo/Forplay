-- Rumah milik semua karakter akun ini (untuk pilihan lokasi spawn).
-- Pemilik dicocokkan lewat license pemain, jadi client tidak bisa meminta rumah karakter orang lain.
lib.callback.register('f_multichar:server:properties', function(source)
    if Player(source).state.isLoggedIn then return {} end
    if not GetResourceState('f_properties'):find('start') then return {} end

    local license2 = GetPlayerIdentifierByType(source, 'license2')
    local license = GetPlayerIdentifierByType(source, 'license')
    local rows = MySQL.query.await([[
        SELECT pr.id, pr.property_name, pr.owner
        FROM properties pr
        JOIN players pl ON pl.citizenid = pr.owner
        WHERE pl.license = ? OR pl.license = ?
    ]], { license2 or '', license or '' }) or {}

    local out = {}
    for _, r in ipairs(rows) do
        out[r.owner] = out[r.owner] or {}
        out[r.owner][#out[r.owner] + 1] = { id = r.id, label = r.property_name }
    end
    return out
end)

-- Rumah MLO dari f_spawnpoints (diserahkan admin), dicocokkan lewat license yang sama.
lib.callback.register('f_multichar:server:houses', function(source)
    if Player(source).state.isLoggedIn then return {} end
    if not GetResourceState('f_spawnpoints'):find('start') then return {} end
    return exports.f_spawnpoints:GetCharacterSpawns(
        GetPlayerIdentifierByType(source, 'license'),
        GetPlayerIdentifierByType(source, 'license2')
    )
end)
