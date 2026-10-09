-- Wilayah gang (turf war). Pengganti sayer-gangs, terhubung ke gang Crew.
--
-- Alur: anggota gang berada PromptSeconds di zona gang lain / zona bebas -> client dapat pilihan
-- Rebut / Abaikan. Rebut -> persiapan PrepMinutes (harus tetap di zona) -> perang WarMinutes ->
-- gang dengan poin terbanyak menguasai zona. Zona tetap milik gang itu sampai direbut gang lain.
--
-- Semua dihitung di server:
--   * posisi anggota dibaca server (OneSync) tiap Turf.TickSeconds -> syarat prompt, persiapan, poin hadir
--   * jual narkoba / curi mobil lewat export AddTurfActivity (hanya bisa dipanggil resource server)
--   * pembunuhan dibaca dari state bag kematian + GetPedSourceOfDeath (bukan laporan client)
--   * satu-satunya event client adalah "setuju rebut", dan itu dicek ulang dengan data server
-- Hanya gang bertag 'gang' yang ikut dan yang bisa melihat blip wilayah.

local config = require 'config'
local zoneList = require 'shared.zones'

local T = config.Turf
local DEATH_BAG = 'f_medical:deathState'
local ALIVE = 1

local turf = {}

---@type table<string, table> nama gang -> data gang (milik main.lua)
local Gangs
---@type table<integer, table> src -> sesi (milik main.lua)
local Sessions
local notify, audit

---@class TurfZone
---@field id string
---@field label string
---@field boxes number[][] { minX, minY, maxX, maxY }
---@field bounds number[]
---@field owner string?
---@field prep { endsAt: integer, gangs: table<string, true>, starter: string }? persiapan (gang yang menekan J)
---@field war { endsAt: integer, points: table<string, number>, defender: string? }? points = daftar peserta
---@field cooldownUntil integer
---@field dirty boolean

---@type table<string, TurfZone>
local Zones = {}
local ZoneOrder = {}
---@type table<integer, string> src -> gang (anggota gang bertag 'gang' yang dapat blip)
local Viewers = {}
---@type table<integer, { zone: string?, since: integer }>
local Presence = {}
local Cooldowns = {}  -- 'cid:activity' -> os.time()
local killedAt = {}   -- victim src -> os.time()
local pairKill = {}   -- 'killerCid:victimCid' -> os.time()
local approveAt = {}  -- src -> os.time() klik Rebut terakhir
-- src -> os.time() batas: app Crew yang dibuka sebelum ini langsung ke Peringkat > Wilayah
-- (setelah notifikasi hasil perebutan; notifikasi custom app tidak bisa membawa link sendiri)
local openTurf = {}
local OPEN_TURF_SECONDS = 600
local warCount = 0   -- zona yang sedang perebutan
local prepCount = 0  -- zona yang sedang persiapan (ikut dihitung di MaxWars)
local ready = false

-- Zona -----------------------------------------------------------------------------------------

for i = 1, #zoneList do
    local def = zoneList[i]
    local boxes = {}
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for j = 1, #def.boxes do
        local b = def.boxes[j]
        local x1, x2 = math.min(b[1], b[3]), math.max(b[1], b[3])
        local y1, y2 = math.min(b[2], b[4]), math.max(b[2], b[4])
        boxes[j] = { x1, y1, x2, y2 }
        minX, minY = math.min(minX, x1), math.min(minY, y1)
        maxX, maxY = math.max(maxX, x2), math.max(maxY, y2)
    end
    Zones[def.id] = {
        id = def.id, label = def.label, boxes = boxes, bounds = { minX, minY, maxX, maxY },
        cooldownUntil = 0, dirty = false,
    }
    ZoneOrder[#ZoneOrder + 1] = def.id
end

---@return string? zone id
local function zoneAt(x, y)
    for i = 1, #ZoneOrder do
        local z = Zones[ZoneOrder[i]]
        local b = z.bounds
        if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then
            for j = 1, #z.boxes do
                local r = z.boxes[j]
                if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then return z.id end
            end
        end
    end
end

-- Warna blip: hex gang -> warna blip GTA terdekat (palet GTA terbatas, nilai RGB perkiraan) -------

local BLIP_COLORS = {
    { 0, 254, 254, 254 }, { 1, 224, 50, 50 }, { 2, 114, 204, 114 }, { 3, 93, 182, 229 },
    { 5, 238, 198, 78 }, { 6, 194, 80, 80 }, { 7, 156, 110, 175 }, { 8, 254, 122, 195 },
    { 15, 0, 176, 193 }, { 17, 234, 142, 80 }, { 21, 204, 102, 0 }, { 25, 56, 112, 62 },
    { 27, 125, 46, 181 }, { 29, 40, 70, 160 }, { 30, 40, 120, 120 }, { 38, 44, 109, 184 },
    { 39, 140, 140, 140 }, { 40, 60, 60, 60 }, { 46, 234, 195, 50 },
}
local colorCache = {}

local function blipColor(hex)
    if colorCache[hex] then return colorCache[hex] end
    local r, g, b = tostring(hex):match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return 0 end
    r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
    local best, bestD = 0, math.huge
    for i = 1, #BLIP_COLORS do
        local c = BLIP_COLORS[i]
        local d = (c[2] - r) ^ 2 + (c[3] - g) ^ 2 + (c[4] - b) ^ 2
        if d < bestD then best, bestD = c[1], d end
    end
    colorCache[hex] = best
    return best
end

-- Helper ---------------------------------------------------------------------------------------

local function isTurfGang(name)
    local g = name and Gangs[name]
    return g ~= nil and g.tag == 'gang'
end

local function onlineOf(gangName)
    local n = 0
    for _, s in pairs(Sessions) do
        if s.gang == gangName then n = n + 1 end
    end
    return n
end

local function isAlive(src)
    local state = Player(src).state[DEATH_BAG]
    return state == nil or state == ALIVE
end

---Teks sementara di layar pemain (bawah tengah, hilang sendiri setelah beberapa detik).
local function screen(src, text, kind)
    TriggerClientEvent('f_crew:turf:result', src, text, kind)
end

local function hhmm(secs)
    local h, m = secs // 3600, (secs % 3600) // 60
    if h > 0 then return ('%d jam %d menit'):format(h, m) end
    return ('%d menit'):format(math.max(1, m))
end

---Data satu zona untuk client: o = label pemilik, c = warna blip, w = sedang perang.
local function zoneData(z)
    local g = z.owner and Gangs[z.owner]
    return { o = g and g.label or nil, c = g and blipColor(g.color) or nil, w = z.war ~= nil }
end

local function pushZone(z)
    local data = zoneData(z)
    for src in pairs(Viewers) do TriggerClientEvent('f_crew:turf:zone', src, z.id, data) end
end

local function fullSync(src)
    local zones = {}
    for id, z in pairs(Zones) do zones[id] = zoneData(z) end
    TriggerClientEvent('f_crew:turf:all', src, {
        alpha = T.BlipAlpha, labels = T.LabelBlips, sprite = T.LabelSprite, scale = T.LabelScale,
        zones = zones,
    })
end

local function setOwner(z, owner)
    z.owner = owner
    z.dirty = true
end

-- Perang ---------------------------------------------------------------------------------------

local function defendersShort(z)
    return z.owner ~= nil and onlineOf(z.owner) < T.MinDefenders
end

---Boleh memulai persiapan baru di zona ini (gang pertama yang menekan J)?
---@return boolean ok, string? alasan gagal
local function canStartPrep(z, gang)
    if z.war or z.prep then return false, ('%s sedang diperebutkan.'):format(z.label) end
    if z.owner == gang then return false, ('%s sudah milik gangmu.'):format(z.label) end
    local now = os.time()
    if now < z.cooldownUntil then
        return false, ('%s baru selesai diperebutkan. Bisa direbut lagi %s lagi.'):format(z.label, hhmm(z.cooldownUntil - now))
    end
    if warCount + prepCount >= T.MaxWars then return false, 'Terlalu banyak perebutan wilayah berjalan. Coba lagi nanti.' end
    if defendersShort(z) then
        return false, ('Anggota %s yang online kurang dari %d.'):format(Gangs[z.owner].label, T.MinDefenders)
    end
    return true
end

---Boleh ikut persiapan yang sudah berjalan? (pemilik zona otomatis ikut, tidak perlu J)
local function canJoinPrep(z, gang)
    return z.prep ~= nil and not z.prep.gangs[gang] and z.owner ~= gang
end

---Gang ikut dalam persiapan / perebutan di zona ini (penyerang yang menekan J atau pemilik zona).
local function isParticipant(z, gang)
    if z.war then return z.war.points[gang] ~= nil end
    if z.prep then return z.prep.gangs[gang] == true or z.owner == gang end
    return false
end

local function cancelPrep(z)
    if not z.prep then return end
    z.prep = nil
    prepCount = math.max(0, prepCount - 1)
end

---Persiapan habis: gang penyerang yang masih punya anggota hidup di zona ikut perebutan.
---@param present table<string, true> gang yang punya anggota di zona pada tick ini
local function resolvePrep(z, present)
    local prep = z.prep
    cancelPrep(z)

    local attackers = {}
    for gang in pairs(prep.gangs) do
        if present[gang] and Gangs[gang] and gang ~= z.owner then attackers[#attackers + 1] = gang end
    end
    local why
    if #attackers == 0 then
        why = ('Persiapan rebut %s batal: tidak ada penyerang yang bertahan di zona.'):format(z.label)
    elseif defendersShort(z) then
        why = ('Persiapan rebut %s batal: anggota %s yang online kurang dari %d.'):format(z.label, Gangs[z.owner].label, T.MinDefenders)
    end
    if why then
        for src, p in pairs(Presence) do
            local s = Sessions[src]
            if p.zone == z.id and s and prep.gangs[s.gang] then screen(src, why, 'error') end
        end
        return
    end

    z.war = { endsAt = os.time() + T.WarMinutes * 60, points = {}, defender = z.owner }
    for i = 1, #attackers do z.war.points[attackers[i]] = 0 end
    if z.owner then z.war.points[z.owner] = 0 end
    warCount = warCount + 1
    pushZone(z)
    audit(nil, 'CrewTurfWar', ('perebutan dimulai di %s: %s (pemilik %s)'):format(z.id, table.concat(attackers, ', '), z.owner or '-'))
end

local function endWar(z)
    local war = z.war
    z.war = nil
    warCount = math.max(0, warCount - 1)
    z.cooldownUntil = os.time() + T.WarCooldownMinutes * 60
    z.dirty = true

    local winner, best = nil, -1
    for gang, pts in pairs(war.points) do
        if Gangs[gang] and (pts > best or (pts == best and gang == war.defender)) then winner, best = gang, pts end
    end
    -- penyerang tanpa poin sama sekali tidak menang; pemilik lama tetap bertahan
    if winner and best <= 0 and winner ~= war.defender then winner = war.defender and Gangs[war.defender] and war.defender or nil end

    local text
    if winner then
        setOwner(z, winner)
        text = ('%s dikuasai %s'):format(z.label, Gangs[winner].label)
    else
        setOwner(z, nil)
        text = ('Perebutan %s selesai tanpa pemenang'):format(z.label)
    end
    pushZone(z)
    -- satu-satunya notifikasi HP soal perebutan: hasil akhirnya. Membuka app Crew sesudahnya
    -- langsung ke Peringkat > Wilayah.
    local openUntil = os.time() + OPEN_TURF_SECONDS
    for src in pairs(Viewers) do
        notify(src, 'Perebutan Wilayah', text)
        openTurf[src] = openUntil
    end
    for src, p in pairs(Presence) do
        local s = Sessions[src]
        if p.zone == z.id and s and war.points[s.gang] ~= nil then screen(src, text, 'done') end
    end
    audit(nil, 'CrewTurfWarEnd', ('perebutan %s selesai, pemenang %s (%s poin)'):format(z.id, winner or '-', math.floor(best)))
end

-- Aktivitas (poin perang) ----------------------------------------------------------------------

---Dipanggil resource lain (server) saat pemain melakukan aktivitas. Hanya dihitung sebagai poin
---perang kalau pemain berada di zona yang sedang diperebutkan dan gangnya peserta.
---@param src integer
---@param activity string 'drugselling'|'carjacking'
function turf.activity(src, activity)
    if not ready or not T.Enabled or warCount == 0 then return end
    local act = T.Activities[activity]
    local s = Sessions[src]
    if not act or not s or not isTurfGang(s.gang) then return end
    if GetPlayerRoutingBucket(src) ~= 0 or not isAlive(src) then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    local id = zoneAt(pos.x, pos.y)
    local z = id and Zones[id]
    if not z or not z.war or z.war.points[s.gang] == nil then return end

    local key = s.cid .. ':' .. activity
    local now = os.time()
    if act.cooldown > 0 and now - (Cooldowns[key] or 0) < act.cooldown * 60 then return end
    Cooldowns[key] = now
    z.war.points[s.gang] = (z.war.points[s.gang] or 0) + act.points
end

-- Pembunuhan saat perang: korban & pembunuh dari gang peserta yang berbeda, korban di zona yang sedang perang.
AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, value)
    if not ready or not T.Enabled or warCount == 0 then return end
    if not value or value == ALIVE then return end
    local victim = GetPlayerFromStateBagName(bagName)
    if not victim or victim == 0 then return end
    local now = os.time()
    if now - (killedAt[victim] or 0) < 60 then return end
    killedAt[victim] = now

    local vs = Sessions[victim]
    if not vs or not isTurfGang(vs.gang) then return end
    local vped = GetPlayerPed(victim)
    local vpos = GetEntityCoords(vped)
    local id = zoneAt(vpos.x, vpos.y)
    local z = id and Zones[id]
    if not z or not z.war or z.war.points[vs.gang] == nil then return end

    local killerEnt = GetPedSourceOfDeath(vped)
    if not killerEnt or killerEnt == 0 or not DoesEntityExist(killerEnt) then return end
    if GetEntityType(killerEnt) == 2 then killerEnt = GetPedInVehicleSeat(killerEnt, -1) end
    if not killerEnt or killerEnt == 0 then return end
    local killer = NetworkGetEntityOwner(killerEnt)
    if not killer or killer == victim or GetPlayerPed(killer) ~= killerEnt then return end

    local ks = Sessions[killer]
    if not ks or ks.gang == vs.gang or z.war.points[ks.gang] == nil then return end
    if #(GetEntityCoords(killerEnt) - vpos) > 300.0 then return end
    local pk = ks.cid .. ':' .. vs.cid
    if now - (pairKill[pk] or 0) < 180 then return end
    pairKill[pk] = now

    z.war.points[ks.gang] = (z.war.points[ks.gang] or 0) + T.WarKillPoints
end)

-- Setuju rebut (satu-satunya input client; semua syarat dicek ulang di server) -------------------

RegisterNetEvent('f_crew:turf:approve', function(zoneId)
    local src = source
    if not ready or not T.Enabled then return end
    local now = os.time()
    if now - (approveAt[src] or 0) < 2 then return end
    approveAt[src] = now

    local s = Sessions[src]
    local p = Presence[src]
    if not s or not isTurfGang(s.gang) or not p or p.zone ~= zoneId then return end
    if now - p.since < T.PromptSeconds then return end
    local z = Zones[zoneId]
    if not z then return end

    if z.prep then
        -- gang lain ikut: hitung mundur tetap milik gang pertama
        if not canJoinPrep(z, s.gang) then return end
        z.prep.gangs[s.gang] = true
        audit(src, 'CrewTurfJoin', ('%s ikut persiapan rebut %s'):format(s.gang, z.id))
    else
        local okPrep, why = canStartPrep(z, s.gang)
        if not okPrep then
            screen(src, why, 'error')
            return
        end
        z.prep = { endsAt = now + T.PrepMinutes * 60, gangs = { [s.gang] = true }, starter = s.gang }
        prepCount = prepCount + 1
        audit(src, 'CrewTurfPrep', ('%s memulai persiapan rebut %s'):format(s.gang, z.id))
    end
    TriggerClientEvent('f_crew:turf:presence', src, zoneId, { prep = math.max(0, z.prep.endsAt - now) })
end)

-- Tick -----------------------------------------------------------------------------------------

local function tick()
    local now = os.time()
    local warPts = T.WarPresencePoints * T.TickSeconds / 60 -- poin per menit, dibagi per tick
    ---@type table<string, table<string, true>> zona -> gang yang punya anggota hidup di sana
    local present = {}

    for src, s in pairs(Sessions) do
        if isTurfGang(s.gang) then
            local id
            local ped = GetPlayerPed(src)
            if ped ~= 0 and GetPlayerRoutingBucket(src) == 0 and isAlive(src) then
                local pos = GetEntityCoords(ped)
                id = zoneAt(pos.x, pos.y)
            end
            local p = Presence[src]
            local wasIn = p and p.zone
            if not p or p.zone ~= id then
                -- pindah / keluar zona / mati: waktu di zona dihitung dari awal
                p = { zone = id, since = now }
                Presence[src] = p
            end

            if id then
                local z = Zones[id]
                present[id] = present[id] or {}
                present[id][s.gang] = true
                local part = isParticipant(z, s.gang)
                if z.war and part then
                    z.war.points[s.gang] = z.war.points[s.gang] + warPts
                end

                -- status untuk layar pemain (hanya dikirim saat di dalam zona / baru keluar).
                -- Gang di luar peserta tidak melihat apa-apa selama perebutan.
                local info = { own = z.owner == s.gang }
                local inZoneLong = now - p.since >= T.PromptSeconds
                if z.war then
                    if part then info.war = math.max(0, z.war.endsAt - now) end
                elseif z.prep then
                    if part then
                        info.prep = math.max(0, z.prep.endsAt - now)
                    elseif inZoneLong and canJoinPrep(z, s.gang) then
                        info.prompt, info.join = true, true
                    end
                elseif not info.own and inZoneLong then
                    -- pilihan Rebut hanya muncul kalau zona memang bisa direbut sekarang
                    info.prompt = canStartPrep(z, s.gang)
                end
                TriggerClientEvent('f_crew:turf:presence', src, id, info)
            elseif wasIn then
                TriggerClientEvent('f_crew:turf:presence', src, nil)
            end
        else
            Presence[src] = nil
        end
    end

    -- persiapan habis -> perebutan; perebutan habis -> pemenang
    for id, z in pairs(Zones) do
        if z.prep and now >= z.prep.endsAt then
            resolvePrep(z, present[id] or {})
        elseif z.war and now >= z.war.endsAt then
            endWar(z)
        end
    end

    -- simpan
    for _, z in pairs(Zones) do
        if z.dirty then
            z.dirty = false
            MySQL.prepare('INSERT INTO crew_turf (zone, owner, cooldown_until) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE owner = VALUES(owner), cooldown_until = VALUES(cooldown_until)', {
                z.id, z.owner, z.cooldownUntil,
            })
        end
    end
end

-- Hook dari main.lua ---------------------------------------------------------------------------

---Sesi anggota dimulai: anggota gang bertag 'gang' dapat blip wilayah.
function turf.join(src)
    if not ready or not T.Enabled then return end
    local s = Sessions[src]
    if s and isTurfGang(s.gang) then
        Viewers[src] = s.gang
        fullSync(src)
    elseif Viewers[src] then
        turf.leave(src)
    end
end

-- Client minta data blip setelah script-nya siap (maks. 1x per 30 detik per pemain).
local requestedAt = {}
RegisterNetEvent('f_crew:turf:request', function()
    local src = source
    local now = os.time()
    if now - (requestedAt[src] or 0) < 30 then return end
    requestedAt[src] = now
    turf.join(src)
end)
AddEventHandler('playerDropped', function()
    requestedAt[source] = nil
    approveAt[source] = nil
    openTurf[source] = nil
end)

---Sekali pakai: true kalau app Crew harus dibuka di Peringkat > Wilayah (baru dapat notifikasi hasil).
function turf.takeOpen(src)
    local untilAt = openTurf[src]
    openTurf[src] = nil
    return untilAt ~= nil and os.time() <= untilAt
end

---Sesi berakhir / keluar gang: blip dihapus.
function turf.leave(src)
    Presence[src] = nil
    killedAt[src] = nil
    if Viewers[src] then
        Viewers[src] = nil
        if GetPlayerPing(src) > 0 then TriggerClientEvent('f_crew:turf:all', src, nil) end
    end
end

---Lepas semua zona & poin perang milik gang (bubar / jadi komunitas).
function turf.release(gangName)
    for _, z in pairs(Zones) do
        local changed = false
        if z.owner == gangName then
            setOwner(z, nil)
            changed = true
        end
        if z.war then
            z.war.points[gangName] = nil
            if z.war.defender == gangName then z.war.defender = nil end
        end
        if z.prep then
            z.prep.gangs[gangName] = nil
            if not next(z.prep.gangs) then cancelPrep(z) end
        end
        if changed then pushZone(z) end
    end
end

---Pengaturan gang berubah (warna / tag).
function turf.gangChanged(g)
    if not ready then return end
    if g.tag ~= 'gang' then turf.release(g.name) end
    for src, s in pairs(Sessions) do
        if s.gang == g.name then turf.join(src) end
    end
    for _, z in pairs(Zones) do
        if z.owner == g.name then pushZone(z) end
    end
end

---Data tab Wilayah di Peringkat.
function turf.board(mine)
    local byGang = {}
    for i = 1, #ZoneOrder do
        local z = Zones[ZoneOrder[i]]
        if z.owner and isTurfGang(z.owner) then
            local e = byGang[z.owner]
            if not e then
                e = { g = Gangs[z.owner], zones = {} }
                byGang[z.owner] = e
            end
            e.zones[#e.zones + 1] = z.label
        end
    end
    local list = {}
    for _, e in pairs(byGang) do list[#list + 1] = e end
    table.sort(list, function(a, b)
        if #a.zones ~= #b.zones then return #a.zones > #b.zones end
        return a.g.label < b.g.label
    end)
    local out = {}
    for i = 1, #list do
        local e = list[i]
        table.sort(e.zones)
        out[i] = {
            rank = i, label = e.g.label, color = e.g.color, count = #e.zones,
            zones = table.concat(e.zones, ', '), mine = e.g.name == mine,
        }
    end
    local wars = {}
    local now = os.time()
    for i = 1, #ZoneOrder do
        local z = Zones[ZoneOrder[i]]
        if z.war then wars[#wars + 1] = { label = z.label, left = math.max(0, z.war.endsAt - now) } end
    end
    return { list = out, wars = wars, total = #ZoneOrder, enabled = T.Enabled }
end

---@param ctx { Gangs: table, Sessions: table, notify: function, audit: function }
function turf.start(ctx)
    Gangs, Sessions, notify, audit = ctx.Gangs, ctx.Sessions, ctx.notify, ctx.audit
    if not T.Enabled then return end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_turf (
            zone           VARCHAR(16) NOT NULL,
            owner          VARCHAR(32) NULL,
            cooldown_until INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (zone)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    -- tabel versi pertama punya kolom rep, belum punya cooldown_until
    local hasCd = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'crew_turf' AND COLUMN_NAME = 'cooldown_until'
    ]])
    if (hasCd or 0) == 0 then
        MySQL.query.await('ALTER TABLE crew_turf ADD COLUMN cooldown_until INT UNSIGNED NOT NULL DEFAULT 0')
    end

    local rows = MySQL.query.await('SELECT zone, owner, cooldown_until FROM crew_turf') or {}
    for i = 1, #rows do
        local r = rows[i]
        local z = Zones[r.zone]
        if z then
            z.cooldownUntil = tonumber(r.cooldown_until) or 0
            if r.owner and isTurfGang(r.owner) then
                z.owner = r.owner
            elseif r.owner then
                z.dirty = true -- gang sudah bubar / jadi komunitas
            end
        end
    end
    -- zona yang dihapus dari shared/zones.lua
    local ids = {}
    for id in pairs(Zones) do ids[#ids + 1] = id end
    MySQL.update.await(('DELETE FROM crew_turf WHERE zone NOT IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)

    ready = true
    CreateThread(function()
        while true do
            Wait(T.TickSeconds * 1000)
            local ok, err = pcall(tick)
            if not ok then lib.print.error(('[f_crew] turf tick: %s'):format(err)) end
        end
    end)
end

return turf
