-- Tidak ada thread/loop di server: semua kerja hanya terjadi saat ada pemain keluar.

local function dbg(...)
    if Config.Debug then print('^3[4play-combatlog]^7', ...) end
end

local active = {}   -- [id] = log
local nextId = 0

local function reasonLabel(reason)
    local r = (reason or ''):lower()
    if r:find('crash') then return Config.Reasons.crash end
    if r:find('timed out') or r:find('timeout') then return Config.Reasons.timeout end
    if r:find('ban') then return Config.Reasons.ban end
    if r:find('kick') then return Config.Reasons.kick end
    if r:find('exit') or r:find('quit') then return Config.Reasons.quit end
    return Config.Reasons.other
end

local function getDiscord(src)
    local id = GetPlayerIdentifierByType(src, 'discord')
    return id and id:gsub('^discord:', '') or nil
end

local function getName(src)
    if Config.NameSource == 'character' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        local ci = ok and player and player.PlayerData and player.PlayerData.charinfo
        if ci and ci.firstname then
            return ('%s %s'):format(ci.firstname, ci.lastname or '')
        end
    end
    return GetPlayerName(src) or ('ID ' .. src)
end

local function prune()
    local now = os.time()
    for id, log in pairs(active) do
        if log.expires <= now then active[id] = nil end
    end
end

-- Kirim ke klien: umur log (detik) supaya timer tidak tergantung jam klien
local function payload(log)
    return {
        id = log.id,
        name = log.name,
        serverId = log.serverId,
        discord = log.discord,
        reason = log.reason,
        coords = log.coords,
        age = os.time() - log.created,
        duration = Config.Duration,
    }
end

-- Semua pemain melihat combat log: satu event broadcast ke semua
local function broadcast(log)
    TriggerClientEvent('4play-combatlog:add', -1, payload(log))
end

local function createLog(src, reason, coordsOverride)
    local ped = GetPlayerPed(src)
    local coords = coordsOverride or (ped ~= 0 and GetEntityCoords(ped))
    if not coords or (coords.x == 0.0 and coords.y == 0.0) then
        dbg(('Gagal: posisi pemain %s tidak terbaca (ped=%s)'):format(src, ped))
        return false
    end

    prune()
    nextId += 1
    local now = os.time()
    local log = {
        id = nextId,
        name = getName(src),
        serverId = src,
        discord = getDiscord(src),
        license = GetPlayerIdentifierByType(src, 'license'),
        reason = reasonLabel(reason),
        rawReason = reason or '',
        coords = vec3(coords.x, coords.y, coords.z),
        created = now,
        expires = now + Config.Duration,
    }
    active[log.id] = log
    broadcast(log)
    dbg(('Combat log #%d: %s (id %s) di %.1f, %.1f, %.1f, discord=%s'):format(
        log.id, log.name, src, log.coords.x, log.coords.y, log.coords.z, tostring(log.discord)))
    return true
end

AddEventHandler('playerDropped', function(reason)
    createLog(source, reason)
end)

-- Teks yang disalin saat pemain menekan tombol salin.
-- Dibuat di server supaya license tidak dikirim ke semua pemain.
lib.callback.register('4play-combatlog:getCopyText', function(_, id)
    local log = active[id]
    if not log or log.expires <= os.time() then return nil end

    local reason = log.reason
    if log.rawReason ~= '' and log.rawReason ~= log.reason then
        reason = ('%s (%s)'):format(log.reason, log.rawReason)
    end

    local c = log.coords
    return table.concat({
        'Nama Player: ' .. log.name .. ' (ID ' .. log.serverId .. ')',
        'Reason: ' .. reason,
        'Discord: ' .. (log.discord or Config.Locale.noDiscord),
        'License: ' .. (log.license or '-'),
        ('Coord: vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z),
    }, '\n')
end)

-- Pemain yang baru masuk / baru load karakter mengambil log yang masih aktif
lib.callback.register('4play-combatlog:getActive', function()
    prune()
    local list = {}
    for _, log in pairs(active) do list[#list + 1] = payload(log) end
    return list
end)

-- ==================== COMMAND TES (HAPUS MULAI DARI SINI) ====================
-- Untuk tes: membuat combat log palsu di depanmu. Bisa dipakai semua pemain.
lib.addCommand('combatlogtest', {
    help = 'Buat combat log palsu di posisimu (tes)',
}, function(source)
    -- Dibuat 3 m di depanmu supaya ring dan kartunya langsung terlihat
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    local h = math.rad(GetEntityHeading(ped))
    local pos = vec3(c.x - math.sin(h) * 3.0, c.y + math.cos(h) * 3.0, c.z)

    if createLog(source, 'Exiting', pos) then
        TriggerClientEvent('ox_lib:notify', source, { description = 'Combat log tes dibuat di depanmu', type = 'success' })
    else
        TriggerClientEvent('ox_lib:notify', source, { description = 'Gagal membuat combat log tes, cek console server', type = 'error' })
    end
end)
-- ==================== COMMAND TES (SAMPAI SINI) ====================
