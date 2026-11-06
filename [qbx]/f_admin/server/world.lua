---------------------------------------------------------------------------
-- Halaman Server: cuaca, waktu, radio, stash (Renewed-Weathersync membaca GlobalState)
---------------------------------------------------------------------------
local WEATHER = {
    EXTRASUNNY = 'Cerah terik', CLEAR = 'Cerah', NEUTRAL = 'Netral', SMOG = 'Kabut asap', FOGGY = 'Berkabut',
    OVERCAST = 'Mendung', CLOUDS = 'Berawan', CLEARING = 'Mulai cerah', RAIN = 'Hujan', THUNDER = 'Badai petir',
    SNOW = 'Salju', BLIZZARD = 'Badai salju', SNOWLIGHT = 'Salju ringan', XMAS = 'Natal', HALLOWEEN = 'Halloween',
}

Handle('world', false, function()
    local w, t = GlobalState.weather, GlobalState.currentTime
    return {
        ok = true,
        weather = w and w.weather or 'CLEAR',
        hour = t and t.hour or 12,
        minute = t and t.minute or 0,
        blackout = GlobalState.blackOut == true,
        freeze = GlobalState.freezeTime == true,
    }
end)

Handle('weather', 'server.weather', function(src, d)
    if d.blackout ~= nil then
        GlobalState.blackOut = d.blackout == true
        Log(src, 'server', GlobalState.blackOut and 'menyalakan pemadaman listrik' or 'mematikan pemadaman listrik')
        return { ok = true, msg = GlobalState.blackOut and 'Pemadaman listrik aktif' or 'Listrik kembali menyala' }
    end
    local w = type(d.weather) == 'string' and d.weather:upper()
    if not w or not WEATHER[w] then return { ok = false, msg = 'Cuaca tidak dikenal.' } end
    GlobalState.weather = { weather = w, time = 9999999999 }
    Log(src, 'server', 'mengganti cuaca ke ' .. WEATHER[w])
    return { ok = true, msg = 'Cuaca diganti: ' .. WEATHER[w] }
end)

Handle('time', 'server.time', function(src, d)
    if d.freeze ~= nil then
        GlobalState.freezeTime = d.freeze == true
        return { ok = true, msg = GlobalState.freezeTime and 'Waktu dibekukan' or 'Waktu berjalan lagi' }
    end
    local h, m = math.floor(tonumber(d.hour) or -1), math.floor(tonumber(d.minute) or 0)
    if h < 0 or h > 23 or m < 0 or m > 59 then return { ok = false, msg = 'Jam tidak valid.' } end
    GlobalState.currentTime = { hour = h, minute = m }
    Log(src, 'server', ('mengganti waktu ke %02d:%02d'):format(h, m))
    return { ok = true, msg = ('Waktu diganti ke %02d:%02d'):format(h, m) }
end)

Handle('radio', 'server.radio', function(src, d)
    local f = tonumber(d.freq)
    if not f or f <= 0 then return { ok = false, msg = 'Frekuensi tidak valid.' } end
    if GetResourceState('pma-voice') ~= 'started' then return { ok = false, msg = 'pma-voice tidak berjalan.' } end
    local list = {}
    for id in pairs(exports['pma-voice']:getPlayersInRadioChannel(f) or {}) do
        list[#list + 1] = { id = id, name = CharName(id), ooc = GetPlayerName(id) }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { ok = true, list = list, freq = f }
end)

Handle('stash', 'server.stash', function(src, d)
    local name = type(d.name) == 'string' and d.name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name == '' then return { ok = false, msg = 'Isi nama stash.' } end
    if not exports.ox_inventory:GetInventory(name, false) then return { ok = false, msg = 'Stash "' .. name .. '" tidak ditemukan.' } end
    exports.ox_inventory:forceOpenInventory(src, 'stash', name)
    Log(src, 'server', 'membuka stash ' .. name)
    return { ok = true, close = true }
end)
