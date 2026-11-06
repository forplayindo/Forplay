-- Gang Wars: perebutan wilayah antar gang (menu /peranggang). Terhubung ke gang Crew.
--
-- Wilayah = poligon titik { x, y } di tabel crew_turf_zones, diatur admin dari menu (nama, titik,
-- minimal peserta online, reward). Pemilik + cooldown di crew_turf.
--
-- Alur: Boss/Wakil klik Kuasai (wilayah bebas) / Rebut (milik gang lain) -> syarat dicek saat itu
-- saja -> persiapan PrepMinutes (gang lain bisa Join) -> perang WarMinutes -> poin terbanyak
-- menguasai wilayah + reward. Setelah setuju perang selalu jalan, apa pun yang terjadi dengan
-- jumlah anggota (logout / crash). Satu gang hanya bisa ikut satu perang sekaligus.
--
-- Semua dihitung di server:
--   * posisi peserta dibaca server (OneSync) tiap Turf.TickSeconds -> poin hadir + scoreboard
--   * jual narkoba / curi mobil lewat export AddTurfActivity (hanya bisa dipanggil resource server)
--   * pembunuhan dibaca dari state bag kematian + GetPedSourceOfDeath (bukan laporan client)
--   * semua aksi menu lewat lib.callback dan dicek ulang di sini (rank, anggota online, slot, admin)
-- Hanya gang bertag 'gang' yang ikut.
--
-- Mode "Rebut Bendera" (z.mode = 'flag'): pemenang = gang yang benderanya berdiri di titik bendera
-- saat waktu habis (kosong = pemilik lama). Cabut / tancap dijalankan loop server per 0,5 detik
-- (jarak, hidup, musuh di dekat tiang dicek di sini; client hanya menekan / melepas E). Bendera =
-- item Turf.Flag.Item dengan metadata crew = nama gang; tertancap = item hilang dari inventory,
-- dicabut musuh = kembali ke Boss (offline / penuh -> antre sampai login).

local config = require 'config'
local seed = require 'server.turf_seed'
local util = require 'server.util'

local T = config.Turf
local F = T.Flag
local DEPUTY = config.DeputyGrade
local DEATH_BAG = 'f_medical:deathState'
local ALIVE = 1
local FLAG_STATE = 'crewFlag' -- state bag pemain yang sedang memegang bendera (dibaca semua client)

local turf = {}

---@type table<string, table> nama gang -> data gang (milik main.lua)
local Gangs
---@type table<integer, table> src -> sesi (milik main.lua)
local Sessions
local notify, audit

---@class TurfBattle
---@field phase 'prep'|'war'
---@field endsAt integer
---@field points table<string, number> gang peserta -> poin (pemilik + penyerang)
---@field defender string?
---@field attackers string[] urutan gang penyerang (yang pertama memulai)
---@field counts table<string, integer> anggota hidup di wilayah per gang (tick terakhir)

---@class TurfZone
---@field id string
---@field label string
---@field points number[][] { { x, y }, ... }
---@field bounds number[] { minX, minY, maxX, maxY }
---@field min integer minimal anggota online per gang
---@field reward table[] { { item, jumlah }, ... }
---@field owner string?
---@field cooldownUntil integer
---@field dirty boolean
---@field battle TurfBattle?
---@field mode? 'points'|'flag'
---@field flagPt? number[] { x, y, z? } titik tiang bendera (mode flag)
---@field flag? string gang yang benderanya sedang berdiri
---@field flagAt? integer os.time() bendera ditancapkan

---@type table<string, TurfZone>
local Zones = {}
local ZoneOrder = {}
---@type table<string, { model: string?, issued: integer, pending: integer }> gang -> data bendera
local FlagInfo = {}
---@type table<string, table> wilayah -> aksi cabut / tancap yang sedang berjalan
local Actions = {}
---@type table<integer, string> src -> gang bendera yang sedang dipegang
local Holding = {}
---@type table<string, true> wilayah yang sedang persiapan / perang
local Battles = {}
local battleCount = 0
---@type table<string, integer> gang -> reward belum diambil
local PendingRewards = {}
local Cooldowns = {}  -- 'cid:activity' -> os.time()
local killedAt = {}   -- victim src -> os.time()
local pairKill = {}   -- 'killerCid:victimCid' -> os.time()
local callAt = {}     -- src -> GetGameTimer() aksi menu terakhir
-- src -> os.time() batas: app Crew yang dibuka sebelum ini langsung ke Peringkat > Wilayah
local openTurf = {}
local OPEN_TURF_SECONDS = 600
local ready = false

-- Geometri -------------------------------------------------------------------------------------

local function boundsOf(points)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #points do
        local p = points[i]
        minX, minY = math.min(minX, p[1]), math.min(minY, p[2])
        maxX, maxY = math.max(maxX, p[1]), math.max(maxY, p[2])
    end
    return { minX, minY, maxX, maxY }
end

---Titik di dalam poligon (ray casting).
local function inPoly(points, x, y)
    local inside = false
    local j = #points
    for i = 1, #points do
        local xi, yi, xj, yj = points[i][1], points[i][2], points[j][1], points[j][2]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
        j = i
    end
    return inside
end

local function inZone(z, x, y)
    local b = z.bounds
    return x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] and inPoly(z.points, x, y)
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

local function isAdmin(src)
    return IsPlayerAceAllowed(src, T.AdminAce)
end

local function gangLabel(name)
    local g = name and Gangs[name]
    return g and g.label or nil
end

local function gangColor(name)
    local g = name and Gangs[name]
    return g and g.color or '#9ca3af'
end

---Wilayah tempat gang sedang ikut persiapan / perang.
local function battleOf(gang)
    for id in pairs(Battles) do
        local z = Zones[id]
        if z.battle.points[gang] ~= nil then return z end
    end
end

---Pengumuman di chat (tab Pengumuman f_chat), tidak dikirim ke job police / EMS (cek job saja).
local function announce(text)
    if GetResourceState('f_chat') ~= 'started' then return end
    local targets = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local p = src and exports.qbx_core:GetPlayer(src)
        local job = p and p.PlayerData.job
        if p and not (job and T.ChatHideJobTypes[job.type]) then targets[#targets + 1] = src end
    end
    if #targets == 0 then return end
    exports.f_chat:SendMessage(nil, 'announce', text, {
        tag = T.ChatTag, color = T.ChatColor, anonymous = true, name = '', targets = targets,
    })
end

---Rate limit aksi menu per pemain.
local function limited(src, ms, kind)
    local key = src .. (kind or '')
    local now = GetGameTimer()
    if now - (callAt[key] or 0) < (ms or 400) then return true end
    callAt[key] = now
    return false
end

local function fail(err) return { ok = false, err = err } end
local function ok(data) return { ok = true, data = data } end

-- Bendera: item, model, kirim ke Boss -----------------------------------------------------------

---Model prop bendera gang (addon dari tab Bendera admin, atau default config).
local function flagModel(gang, hand)
    local info = gang and FlagInfo[gang]
    if info and info.model then return info.model end
    return hand and F.DefaultHandModel or F.DefaultModel
end

local function flagMeta(gang)
    local label = gangLabel(gang) or '?'
    return {
        crew = gang, label = 'Bendera ' .. label,
        description = ('Bendera gang %s. Hanya anggota %s yang bisa memegangnya. Ditancapkan saat Rebut Bendera (/peranggang).'):format(label, label),
    }
end

---Slot item bendera milik gang ini di inventory pemain.
local function findFlagSlot(src, gang)
    local slots = exports.ox_inventory:Search(src, 'slots', F.Item)
    for _, item in pairs(slots or {}) do
        if item.metadata and item.metadata.crew == gang then return item.slot end
    end
end

local function sessionOfCid(cid)
    for src, s in pairs(Sessions) do
        if s.cid == cid then return src, s end
    end
end

local function flagInfo(gang)
    local info = FlagInfo[gang]
    if not info then
        info = { issued = 0, pending = 0 }
        FlagInfo[gang] = info
    end
    return info
end

local function saveFlagInfo(gang)
    local info = FlagInfo[gang]
    if not info then return end
    MySQL.prepare('INSERT INTO crew_flags (gang, model, issued, pending) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model), issued = VALUES(issued), pending = VALUES(pending)', {
        gang, info.model, info.issued, info.pending,
    })
end

---Serahkan 1 bendera ke Boss gang: online -> inventory, offline / tas penuh -> antre sampai login.
---@return boolean langsung masuk inventory
local function giveFlag(gang, why)
    local g = Gangs[gang]
    if not g then return false end
    local info = flagInfo(gang)
    local src = sessionOfCid(g.owner)
    if src and exports.ox_inventory:CanCarryItem(src, F.Item, 1) and exports.ox_inventory:AddItem(src, F.Item, 1, flagMeta(gang)) then
        saveFlagInfo(gang)
        notify(src, 'Bendera Gang', why)
        return true
    end
    info.pending = info.pending + 1
    saveFlagInfo(gang)
    return false
end

---Boss login: bendera yang antre dimasukkan ke inventory.
local function deliverPending(src)
    local s = Sessions[src]
    local g = s and Gangs[s.gang]
    local info = g and FlagInfo[g.name]
    if not info or info.pending < 1 or g.owner ~= s.cid then return end
    local given = 0
    while info.pending > 0 and exports.ox_inventory:CanCarryItem(src, F.Item, 1) and exports.ox_inventory:AddItem(src, F.Item, 1, flagMeta(g.name)) do
        info.pending = info.pending - 1
        given = given + 1
    end
    if given > 0 then
        saveFlagInfo(g.name)
        notify(src, 'Bendera Gang', ('%d bendera gang masuk ke inventory.'):format(given))
    end
end

---Daftar bendera tertancap untuk semua client (prop dibuat lokal di tiap client).
local function publishFlags()
    local list = {}
    for id, z in pairs(Zones) do
        if z.flag and z.flagPt and Gangs[z.flag] then
            list[id] = {
                x = z.flagPt[1], y = z.flagPt[2], z = z.flagPt[3], h = z.flagPt[4],
                m = flagModel(z.flag), l = gangLabel(z.flag), c = gangColor(z.flag),
            }
        end
    end
    GlobalState.crewFlags = list
end

---Tugu di setiap titik bendera (selalu berdiri, bendera ditancap di atasnya). Berubah hanya saat admin edit wilayah.
local function publishPoints()
    local list = {}
    for id, z in pairs(Zones) do
        if z.mode == 'flag' and z.flagPt then
            list[id] = { x = z.flagPt[1], y = z.flagPt[2], z = z.flagPt[3], h = z.flagPt[4] }
        end
    end
    GlobalState.crewFlagPoints = list
end

local function holdState(gang)
    return { m = flagModel(gang, true), g = gang, l = gangLabel(gang), c = gangColor(gang) }
end

local function stowFlag(src)
    if not Holding[src] then return end
    Holding[src] = nil
    if GetPlayerName(src) then Player(src).state:set(FLAG_STATE, nil, true) end
end

-- Scoreboard (HUD) -----------------------------------------------------------------------------

local function hudParts(z)
    local b = z.battle
    local parts = {}
    for g, pts in pairs(b.points) do
        parts[#parts + 1] = {
            g = g, label = gangLabel(g) or '?', color = gangColor(g),
            role = g == b.defender and 'pemilik' or 'penyerang',
            pts = math.floor(pts), n = b.counts[g] or 0,
        }
    end
    table.sort(parts, function(a, c)
        if a.pts ~= c.pts then return a.pts > c.pts end
        return a.label < c.label
    end)
    return parts
end

---Kirim scoreboard ke anggota online gang peserta. only = satu pemain saja (baru login).
---@param inside table<integer, true>? pemain yang ada di dalam wilayah pada tick ini
local function pushHud(z, inside, only)
    local b = z.battle
    local now = os.time()
    local data = {
        id = z.id, zone = z.label, phase = b.phase, left = math.max(0, b.endsAt - now),
        total = (b.phase == 'prep' and T.PrepMinutes or T.WarMinutes) * 60, parts = hudParts(z),
        mode = z.mode,
    }
    if z.mode == 'flag' then
        data.point = z.flagPt
        data.radius = F.ActionRadius
        data.pull, data.plant = F.PullSeconds, F.PlantSeconds
        data.flag = z.flag and { g = z.flag, label = gangLabel(z.flag) or '?', color = gangColor(z.flag), since = math.max(0, now - (z.flagAt or now)) } or nil
        local a = Actions[z.id]
        data.action = a and { kind = a.kind, g = a.gang, label = gangLabel(a.gang) or '?', contested = a.contested } or nil
    end
    for src, s in pairs(Sessions) do
        if (not only or only == src) and b.points[s.gang] ~= nil then
            data.mine = s.gang
            data.inside = inside and inside[src] or false
            TriggerClientEvent('f_crew:turf:hud', src, data)
        end
    end
end

local function hudDone(points, text)
    for src, s in pairs(Sessions) do
        if points[s.gang] ~= nil then TriggerClientEvent('f_crew:turf:hudDone', src, text) end
    end
end

-- Perang ---------------------------------------------------------------------------------------

local function setOwner(z, owner)
    z.owner = owner
    z.dirty = true
end

---Mode bendera: "poin" = detik bendera gang berdiri selama perang (hanya untuk riwayat / scoreboard).
local function creditFlag(z)
    local b = z.battle
    if not b or b.phase ~= 'war' then return end
    local now = os.time()
    if z.flag and b.points[z.flag] ~= nil then
        b.points[z.flag] = b.points[z.flag] + math.max(0, now - (b.flagFrom or now))
    end
    b.flagFrom = now
end

local function startWar(z)
    local b = z.battle
    b.phase = 'war'
    b.flagFrom = os.time()
    b.endsAt = os.time() + T.WarMinutes * 60
    local names = {}
    for g in pairs(b.points) do names[#names + 1] = gangLabel(g) or g end
    announce(('Perang %s dimulai! %s. Berakhir %d menit lagi.'):format(z.label, table.concat(names, ' vs '), T.WarMinutes))
    audit(nil, 'CrewTurfWar', ('perang dimulai di %s: %s'):format(z.id, table.concat(names, ', ')))
end

local function trimHistory()
    MySQL.update([[
        DELETE FROM crew_turf_history WHERE id NOT IN (
            SELECT id FROM (SELECT id FROM crew_turf_history ORDER BY id DESC LIMIT ?) keep
        )
    ]], { T.HistoryLimit })
end

local function endWar(z)
    local b = z.battle
    if z.mode == 'flag' then creditFlag(z) end
    local a = Actions[z.id]
    if a then
        Actions[z.id] = nil
        if GetPlayerName(a.src) then TriggerClientEvent('f_crew:flag:progress', a.src, { stop = true, reason = 'Waktu perang habis.' }) end
    end
    z.battle = nil
    Battles[z.id] = nil
    battleCount = math.max(0, battleCount - 1)
    TriggerEvent('f_crew:server:warEnded', z.id) -- f_graffiti menghapus graffiti perang wilayah ini
    z.cooldownUntil = os.time() + T.WarCooldownMinutes * 60
    z.dirty = true

    local defender = b.defender
    local winner, best = nil, -1
    if z.mode == 'flag' then
        -- bendera yang berdiri menang; titik kosong = pemilik lama bertahan (wilayah bebas tetap bebas)
        if z.flag and b.points[z.flag] ~= nil and Gangs[z.flag] then
            winner = z.flag
        elseif defender and Gangs[defender] then
            winner = defender
        end
        best = winner and b.points[winner] or 0
    else
        for gang, pts in pairs(b.points) do
            if Gangs[gang] and (pts > best or (pts == best and gang == defender)) then winner, best = gang, pts end
        end
        -- penyerang tanpa poin sama sekali tidak menang; pemilik lama tetap bertahan
        if winner and best <= 0 and winner ~= defender then winner = defender and Gangs[defender] and defender or nil end
    end

    local text
    if winner and winner == defender then
        text = ('%s berhasil mempertahankan %s'):format(gangLabel(winner), z.label)
    elseif winner then
        text = ('%s dikuasai %s'):format(z.label, gangLabel(winner))
    else
        text = ('Perebutan %s selesai tanpa pemenang'):format(z.label)
    end
    setOwner(z, winner)

    -- riwayat (label & warna disimpan supaya tetap terbaca walau gang bubar)
    local scores = {}
    for gang, pts in pairs(b.points) do
        -- sec = mode bendera: pts adalah detik bendera berdiri
        scores[#scores + 1] = { g = gang, label = gangLabel(gang) or '?', color = gangColor(gang), pts = math.floor(pts), sec = z.mode == 'flag' or nil }
    end
    table.sort(scores, function(a, c) return a.pts > c.pts end)
    MySQL.insert('INSERT INTO crew_turf_history (zone, prev_label, winner, winner_label, scores, ended_at) VALUES (?, ?, ?, ?, ?, ?)', {
        z.label, gangLabel(defender), winner, gangLabel(winner), json.encode(scores), os.time(),
    }, function() trimHistory() end)

    -- reward untuk pemenang (diambil Boss/Wakil di tab Reward)
    if winner and #z.reward > 0 then
        MySQL.insert('INSERT INTO crew_turf_rewards (gang, zone, items, won_at) VALUES (?, ?, ?, ?)', {
            winner, z.label, json.encode(z.reward), os.time(),
        })
        PendingRewards[winner] = (PendingRewards[winner] or 0) + 1
    end

    announce(text .. '!')
    hudDone(b.points, text)
    -- notifikasi HP ke semua anggota gang (tag gang); membuka app Crew sesudahnya -> Peringkat > Wilayah
    local openUntil = os.time() + OPEN_TURF_SECONDS
    for src, s in pairs(Sessions) do
        if isTurfGang(s.gang) then
            notify(src, 'Perebutan Wilayah', text)
            openTurf[src] = openUntil
        end
    end
    audit(nil, 'CrewTurfWarEnd', ('perang %s selesai, pemenang %s (%s poin)'):format(z.id, winner or '-', math.floor(best)))
end

-- Bendera: pegang, cabut, tancap ---------------------------------------------------------------

---Kabar singkat ke semua anggota online gang peserta.
local function flagEvent(z, text)
    local b = z.battle
    if not b then return end
    for src, s in pairs(Sessions) do
        if b.points[s.gang] ~= nil then TriggerClientEvent('f_crew:flag:event', src, text) end
    end
end

local function distToFlag(src, z)
    local ped = GetPlayerPed(src)
    if ped == 0 then return math.huge end
    return #(GetEntityCoords(ped).xy - vec2(z.flagPt[1], z.flagPt[2]))
end

---Ada anggota hidup dari gang peserta lain di dekat tiang?
local function contested(z, gang)
    local b = z.battle
    for src, s in pairs(Sessions) do
        if s.gang ~= gang and b.points[s.gang] ~= nil and GetPlayerRoutingBucket(src) == 0 and isAlive(src)
            and distToFlag(src, z) <= F.ContestRadius then
            return true
        end
    end
    return false
end

local function stopAction(z, a, reason, done)
    if Actions[z.id] ~= a then return end
    Actions[z.id] = nil
    if GetPlayerName(a.src) then TriggerClientEvent('f_crew:flag:progress', a.src, { stop = true, reason = reason, done = done }) end
    if z.battle then pushHud(z) end
end

local function finishAction(z, a)
    if a.kind == 'pull' then
        local old = z.flag
        creditFlag(z)
        z.flag, z.flagAt, z.dirty = nil, 0, true
        stopAction(z, a, nil, ('Bendera %s dicabut!'):format(gangLabel(old) or '?'))
        flagEvent(z, ('%s mencabut bendera %s di %s!'):format(gangLabel(a.gang), gangLabel(old) or '?', z.label))
        if old then giveFlag(old, ('Bendera gangmu dicabut %s di %s dan kembali ke inventory.'):format(gangLabel(a.gang), z.label)) end
        audit(a.src, 'CrewFlagPull', ('%s mencabut bendera %s di %s'):format(a.gang, old or '-', z.id))
    else
        local slot = Holding[a.src] == a.gang and findFlagSlot(a.src, a.gang)
        if not slot or not exports.ox_inventory:RemoveItem(a.src, F.Item, 1, nil, slot) then
            return stopAction(z, a, 'Bendera tidak ada di inventory.')
        end
        stowFlag(a.src)
        creditFlag(z)
        z.flag, z.flagAt, z.dirty = a.gang, os.time(), true
        stopAction(z, a, nil, 'Benderamu berdiri! Pertahankan sampai waktu habis.')
        flagEvent(z, ('%s menancapkan bendera di %s!'):format(gangLabel(a.gang), z.label))
        audit(a.src, 'CrewFlagPlant', ('%s menancapkan bendera di %s'):format(a.gang, z.id))
    end
    publishFlags()
    pushHud(z)
end

---Loop server satu aksi: progres hanya bertambah kalau semua syarat terpenuhi & tidak ada musuh dekat.
local function runAction(z, a)
    CreateThread(function()
        while Actions[z.id] == a do
            Wait(500)
            if Actions[z.id] ~= a then return end
            local s = Sessions[a.src]
            local b = z.battle
            local err
            if not s or s.gang ~= a.gang or not b or b.phase ~= 'war' then
                err = 'Perang sudah selesai.'
            elseif not isAlive(a.src) or GetPlayerRoutingBucket(a.src) ~= 0 then
                err = 'Dibatalkan.'
            elseif a.kind == 'pull' and z.flag ~= a.target then
                err = 'Bendera sudah berubah.'
            elseif a.kind == 'plant' and (z.flag or Holding[a.src] ~= a.gang) then
                err = z.flag and 'Bendera lain sudah berdiri.' or 'Bendera tidak dipegang.'
            elseif GetVehiclePedIsIn(GetPlayerPed(a.src), false) ~= 0 or distToFlag(a.src, z) > F.ActionRadius + 0.5 then
                err = 'Terlalu jauh dari tiang bendera.'
            end
            if err then return stopAction(z, a, err) end

            local busy = contested(z, a.gang)
            if not busy then a.done = a.done + 0.5 end
            if busy ~= a.contested then
                a.contested = busy
                pushHud(z)
            end
            if a.done >= a.need then return finishAction(z, a) end
            TriggerClientEvent('f_crew:flag:progress', a.src, {
                kind = a.kind, title = a.title, p = a.done / a.need, left = math.ceil(a.need - a.done), contested = busy,
            })
        end
    end)
end

local function flagStart(src)
    local s = Sessions[src]
    if not s or not isTurfGang(s.gang) then return fail('Hanya untuk anggota gang.') end
    local z = battleOf(s.gang)
    if not z or z.mode ~= 'flag' or not z.flagPt then return fail('Gangmu tidak sedang ikut Rebut Bendera.') end
    if z.battle.phase ~= 'war' then return fail('Perang belum dimulai.') end
    local cur = Actions[z.id]
    if cur then return fail(cur.src == src and 'Sedang berjalan.' or 'Bendera sedang dicabut / ditancap orang lain.') end
    if not isAlive(src) or GetPlayerRoutingBucket(src) ~= 0 then return fail('Tidak bisa sekarang.') end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return fail('Turun dari kendaraan dulu.') end
    if distToFlag(src, z) > F.ActionRadius then return fail('Terlalu jauh dari tiang bendera.') end

    local a = { src = src, gang = s.gang, done = 0, contested = false }
    if z.flag and z.flag ~= s.gang then
        a.kind, a.need, a.target = 'pull', F.PullSeconds, z.flag
        a.title = ('Mencabut bendera %s'):format(gangLabel(z.flag) or '?')
    elseif z.flag then
        return fail('Bendera gangmu sudah berdiri. Pertahankan!')
    else
        if Holding[src] ~= s.gang or not findFlagSlot(src, s.gang) then
            return fail('Pegang bendera gangmu dulu (pakai item dari inventory).')
        end
        a.kind, a.need = 'plant', F.PlantSeconds
        a.title = ('Menancapkan bendera %s'):format(gangLabel(s.gang) or '?')
    end
    Actions[z.id] = a
    pushHud(z)
    runAction(z, a)
    return ok({ kind = a.kind, title = a.title, need = a.need })
end

local function cancelActionsOf(src)
    for id, a in pairs(Actions) do
        if a.src == src then stopAction(Zones[id], a) end
    end
end

---Pakai item bendera: pegang (state bag dibaca semua client untuk prop di tangan) / simpan lagi.
local function flagHold(src, slot)
    if Holding[src] then
        cancelActionsOf(src)
        stowFlag(src)
        return ok(false)
    end
    local s = Sessions[src]
    slot = tonumber(slot)
    local item = slot and exports.ox_inventory:GetSlot(src, slot)
    if not item or item.name ~= F.Item then return fail('Bendera tidak ditemukan.') end
    local gang = item.metadata and item.metadata.crew
    if not gang or not Gangs[gang] then return fail('Bendera ini milik gang yang sudah bubar.') end
    if not s or s.gang ~= gang then return fail(('Ini bendera %s. Hanya anggotanya yang bisa memegang.'):format(gangLabel(gang))) end
    if not isAlive(src) then return fail('Tidak bisa sekarang.') end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return fail('Turun dari kendaraan dulu.') end
    Holding[src] = gang
    Player(src).state:set(FLAG_STATE, holdState(gang), true)
    return ok(true)
end

RegisterNetEvent('f_crew:flag:cancel', function() cancelActionsOf(source) end)
RegisterNetEvent('f_crew:flag:stow', function()
    local src = source
    cancelActionsOf(src)
    stowFlag(src)
end)

-- mati / pingsan -> bendera disimpan otomatis
AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, value)
    if not value or value == ALIVE then return end
    local src = GetPlayerFromStateBagName(bagName)
    if src and Holding[src] then
        cancelActionsOf(src)
        stowFlag(src)
    end
end)

-- Syarat aksi menu -----------------------------------------------------------------------------

---Tombol Kuasai / Rebut untuk wilayah ini. nil = tidak ada tombol (perang / cooldown / milik sendiri).
---@return { label: string, ok: boolean, reason: string? }?
local function actionFor(z, s)
    if not s or not isTurfGang(s.gang) then return nil end
    if z.battle or os.time() < z.cooldownUntil or z.owner == s.gang then return nil end
    local label = z.owner and 'Rebut' or 'Kuasai'
    local reason
    if s.grade < DEPUTY then
        reason = 'Hanya Boss / Wakil'
    elseif battleOf(s.gang) then
        reason = 'Gangmu sedang ikut perang lain'
    elseif z.owner and battleOf(z.owner) then
        reason = ('%s sedang ikut perang lain'):format(gangLabel(z.owner))
    elseif battleCount >= T.MaxWars then
        reason = ('Sudah %d perang berjalan'):format(T.MaxWars)
    else
        local mine = onlineOf(s.gang)
        if mine < z.min then
            reason = ('Anggota gangmu online %d/%d'):format(mine, z.min)
        elseif z.owner then
            local theirs = onlineOf(z.owner)
            if theirs < z.min then reason = ('Anggota %s online %d/%d'):format(gangLabel(z.owner), theirs, z.min) end
        end
    end
    return { label = label, ok = reason == nil, reason = reason }
end

---Tombol Join untuk perang yang masih persiapan.
---@return { ok: boolean, reason: string? }?
local function joinFor(z, s)
    if not s or not isTurfGang(s.gang) then return nil end
    local b = z.battle
    if not b or b.phase ~= 'prep' or b.points[s.gang] ~= nil then return nil end
    local reason
    if s.grade < DEPUTY then
        reason = 'Hanya Boss / Wakil'
    elseif battleOf(s.gang) then
        reason = 'Gangmu sedang ikut perang lain'
    else
        local mine = onlineOf(s.gang)
        if mine < z.min then reason = ('Anggota gangmu online %d/%d'):format(mine, z.min) end
    end
    return { ok = reason == nil, reason = reason }
end

-- Aktivitas (poin perang) ----------------------------------------------------------------------

---Dipanggil resource lain (server) saat pemain melakukan aktivitas. Hanya dihitung sebagai poin
---kalau pemain berada di wilayah yang sedang perang dan gangnya peserta.
---@param src integer
---@param activity string 'drugselling'|'carjacking'
function turf.activity(src, activity)
    if not ready or not T.Enabled or battleCount == 0 then return end
    local act = T.Activities[activity]
    local s = Sessions[src]
    if not act or not s or not isTurfGang(s.gang) then return end
    local z = battleOf(s.gang)
    if not z or z.battle.phase ~= 'war' or z.mode == 'flag' then return end
    if GetPlayerRoutingBucket(src) ~= 0 or not isAlive(src) then return end
    local pos = GetEntityCoords(GetPlayerPed(src))
    if not inZone(z, pos.x, pos.y) then return end

    local key = s.cid .. ':' .. activity
    local now = os.time()
    if act.cooldown > 0 and now - (Cooldowns[key] or 0) < act.cooldown * 60 then return end
    Cooldowns[key] = now
    z.battle.points[s.gang] = z.battle.points[s.gang] + act.points
end

-- Graffiti perang (f_graffiti) -----------------------------------------------------------------

---Wilayah perang (fase perang, mode poin) tempat gang pemain ikut dan titik x, y berada di dalamnya.
---@return string? zoneId, string? label
function turf.graffitiZone(src, x, y)
    if not ready or not T.Enabled or battleCount == 0 or (T.WarGraffitiPoints or 0) <= 0 then return nil end
    local s = Sessions[src]
    if not s or not isTurfGang(s.gang) then return nil end
    local z = battleOf(s.gang)
    if not z or z.battle.phase ~= 'war' or z.mode == 'flag' then return nil end
    if GetPlayerRoutingBucket(src) ~= 0 or not inZone(z, x, y) then return nil end
    return z.id, z.label
end

---Gang pemain kalau ia peserta perang yang sedang berjalan di wilayah ini.
---@return string?
function turf.graffitiParticipant(zoneId, src)
    local z = Zones[zoneId]
    local s = Sessions[src]
    local b = z and z.battle
    if not b or b.phase ~= 'war' or not s or b.points[s.gang] == nil then return nil end
    return s.gang
end

---Poin graffiti: sign 1 = semprot, -1 = dibersihkan. Poin tidak bisa di bawah 0.
---@return boolean
function turf.graffitiPoints(zoneId, gang, sign)
    local z = Zones[zoneId]
    local b = z and z.battle
    if not b or b.phase ~= 'war' or z.mode == 'flag' or b.points[gang] == nil then return false end
    local pts = (T.WarGraffitiPoints or 0) * (sign < 0 and -1 or 1)
    b.points[gang] = math.max(0, b.points[gang] + pts)
    pushHud(z)
    return true
end

-- Pembunuhan saat perang: korban & pembunuh dari gang peserta yang berbeda, korban di wilayah itu.
AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, value)
    if not ready or not T.Enabled or battleCount == 0 then return end
    if not value or value == ALIVE then return end
    local victim = GetPlayerFromStateBagName(bagName)
    if not victim or victim == 0 then return end
    local now = os.time()
    if now - (killedAt[victim] or 0) < 60 then return end
    killedAt[victim] = now

    local vs = Sessions[victim]
    if not vs or not isTurfGang(vs.gang) then return end
    local z = battleOf(vs.gang)
    if not z or z.battle.phase ~= 'war' or z.mode == 'flag' then return end
    local vped = GetPlayerPed(victim)
    local vpos = GetEntityCoords(vped)
    if not inZone(z, vpos.x, vpos.y) then return end

    local killerEnt = GetPedSourceOfDeath(vped)
    if not killerEnt or killerEnt == 0 or not DoesEntityExist(killerEnt) then return end
    if GetEntityType(killerEnt) == 2 then killerEnt = GetPedInVehicleSeat(killerEnt, -1) end
    if not killerEnt or killerEnt == 0 then return end
    local killer = NetworkGetEntityOwner(killerEnt)
    if not killer or killer == victim or GetPlayerPed(killer) ~= killerEnt then return end

    local ks = Sessions[killer]
    if not ks or ks.gang == vs.gang or z.battle.points[ks.gang] == nil then return end
    if #(GetEntityCoords(killerEnt) - vpos) > 300.0 then return end
    local pk = ks.cid .. ':' .. vs.cid
    if now - (pairKill[pk] or 0) < 180 then return end
    pairKill[pk] = now

    z.battle.points[ks.gang] = z.battle.points[ks.gang] + T.WarKillPoints
end)

-- Tick -----------------------------------------------------------------------------------------

local function tick()
    local now = os.time()
    local warPts = T.WarPresencePoints * T.TickSeconds / 60 -- poin per menit, dibagi per tick
    local inside = {}

    if battleCount > 0 then
        for id in pairs(Battles) do Zones[id].battle.counts = {} end
        for src, s in pairs(Sessions) do
            local z = isTurfGang(s.gang) and battleOf(s.gang)
            if z then
                local ped = GetPlayerPed(src)
                if ped ~= 0 and GetPlayerRoutingBucket(src) == 0 and isAlive(src) then
                    local pos = GetEntityCoords(ped)
                    if inZone(z, pos.x, pos.y) then
                        local b = z.battle
                        inside[src] = true
                        b.counts[s.gang] = (b.counts[s.gang] or 0) + 1
                        if b.phase == 'war' and z.mode ~= 'flag' then b.points[s.gang] = b.points[s.gang] + warPts end
                    end
                end
            end
        end
        for id in pairs(Battles) do
            if Zones[id].mode == 'flag' then creditFlag(Zones[id]) end
        end

        -- persiapan habis -> perang; perang habis -> pemenang
        local due = {}
        for id in pairs(Battles) do
            if now >= Zones[id].battle.endsAt then due[#due + 1] = Zones[id] end
        end
        for i = 1, #due do
            local z = due[i]
            if z.battle.phase == 'prep' then startWar(z) else endWar(z) end
        end
        for id in pairs(Battles) do pushHud(Zones[id], inside) end
    end

    -- pemegang bendera yang item-nya sudah tidak ada (dibuang / diberikan) / ganti gang
    for src, gang in pairs(Holding) do
        local s = Sessions[src]
        if not s or s.gang ~= gang or not findFlagSlot(src, gang) then
            cancelActionsOf(src)
            stowFlag(src)
        end
    end

    -- simpan
    for _, z in pairs(Zones) do
        if z.dirty then
            z.dirty = false
            MySQL.prepare('INSERT INTO crew_turf (zone, owner, cooldown_until, flag, flag_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE owner = VALUES(owner), cooldown_until = VALUES(cooldown_until), flag = VALUES(flag), flag_at = VALUES(flag_at)', {
                z.id, z.owner, z.cooldownUntil, z.flag, z.flagAt or 0,
            })
        end
    end
end

-- Menu: data -----------------------------------------------------------------------------------

local function boardList(mine)
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
    return out
end

---@param full boolean sertakan titik poligon (hanya saat menu pertama dibuka / setelah edit)
local function menuData(src, full)
    local s = Sessions[src]
    if s and not isTurfGang(s.gang) then s = nil end
    local admin = isAdmin(src)
    if not s and not admin then return fail('Gang Wars hanya untuk anggota gang (bukan komunitas).') end

    local now = os.time()
    local zones = {}
    for i = 1, #ZoneOrder do
        local z = Zones[ZoneOrder[i]]
        local b = z.battle
        zones[i] = {
            id = z.id, label = z.label, min = z.min, reward = z.reward,
            owner = gangLabel(z.owner), color = z.owner and gangColor(z.owner) or nil, mine = s and z.owner == s.gang or false,
            cd = math.max(0, z.cooldownUntil - now),
            phase = b and b.phase or nil, left = b and math.max(0, b.endsAt - now) or nil,
            act = actionFor(z, s),
            points = full and z.points or nil,
            mode = z.mode, fpt = z.flagPt,
            flag = z.flag and gangLabel(z.flag) or nil, fcolor = z.flag and gangColor(z.flag) or nil,
        }
    end

    local wars = {}
    for id in pairs(Battles) do
        local z = Zones[id]
        local b = z.battle
        local parts = hudParts(z)
        for i = 1, #parts do
            parts[i].mine = s and parts[i].g == s.gang or false
            parts[i].flag = z.flag ~= nil and parts[i].g == z.flag or nil
            parts[i].g = nil
        end
        wars[#wars + 1] = {
            id = z.id, label = z.label, phase = b.phase, left = math.max(0, b.endsAt - now),
            parts = parts, join = joinFor(z, s), started = b.endsAt, mode = z.mode,
        }
    end
    table.sort(wars, function(a, b) return a.started < b.started end)

    return ok({
        me = s and {
            gang = s.gang, label = gangLabel(s.gang), color = gangColor(s.gang), canAct = s.grade >= DEPUTY,
            online = onlineOf(s.gang), rewards = PendingRewards[s.gang] or 0,
        } or nil,
        admin = admin,
        cfg = {
            prep = T.PrepMinutes, war = T.WarMinutes, cooldown = math.floor(T.WarCooldownMinutes / 60),
            maxWars = T.MaxWars, presence = T.WarPresencePoints, kill = T.WarKillPoints,
            graffiti = T.WarGraffitiPoints or 0,
            drug = T.Activities.drugselling and T.Activities.drugselling.points or 0,
            car = T.Activities.carjacking and T.Activities.carjacking.points or 0,
            defaultMin = T.DefaultMinPlayers, maxItems = T.MaxRewardItems, history = T.HistoryLimit,
            pull = F.PullSeconds, plant = F.PlantSeconds, contest = F.ContestRadius,
        },
        running = battleCount,
        zones = zones,
        wars = wars,
        board = boardList(s and s.gang),
    })
end

-- Menu: aksi -----------------------------------------------------------------------------------

local function startBattle(src, zoneId)
    local s = Sessions[src]
    local z = type(zoneId) == 'string' and Zones[zoneId]
    if not s or not isTurfGang(s.gang) then return fail('Hanya untuk anggota gang.') end
    if not z then return fail('Wilayah tidak ditemukan.') end
    local a = actionFor(z, s)
    if not a then return fail(('%s tidak bisa direbut sekarang.'):format(z.label)) end
    if not a.ok then return fail(a.reason) end

    local now = os.time()
    z.battle = {
        phase = 'prep', endsAt = now + T.PrepMinutes * 60,
        points = { [s.gang] = 0 }, defender = z.owner, attackers = { s.gang }, counts = {},
    }
    if z.owner then z.battle.points[z.owner] = 0 end
    Battles[z.id] = true
    battleCount = battleCount + 1

    if z.owner then
        announce(('%s akan merebut %s dari %s! Perang dimulai %d menit lagi. Cek /peranggang.'):format(
            gangLabel(s.gang), z.label, gangLabel(z.owner), T.PrepMinutes))
    else
        announce(('%s akan menguasai %s! Perang dimulai %d menit lagi. Cek /peranggang.'):format(
            gangLabel(s.gang), z.label, T.PrepMinutes))
    end
    audit(src, 'CrewTurfPrep', ('%s memulai persiapan %s %s'):format(s.gang, a.label:lower(), z.id))
    pushHud(z)
    return ok(true)
end

local function joinBattle(src, zoneId)
    local s = Sessions[src]
    local z = type(zoneId) == 'string' and Zones[zoneId]
    if not s or not isTurfGang(s.gang) then return fail('Hanya untuk anggota gang.') end
    if not z or not z.battle then return fail('Perang tidak ditemukan.') end
    local j = joinFor(z, s)
    if not j then return fail('Tidak bisa join perang ini.') end
    if not j.ok then return fail(j.reason) end

    z.battle.points[s.gang] = 0
    z.battle.attackers[#z.battle.attackers + 1] = s.gang
    announce(('%s ikut perebutan %s! Cek /peranggang.'):format(gangLabel(s.gang), z.label))
    audit(src, 'CrewTurfJoin', ('%s ikut persiapan %s'):format(s.gang, z.id))
    pushHud(z)
    return ok(true)
end

local function rewardList(src)
    local s = Sessions[src]
    if not s or not isTurfGang(s.gang) then return ok({}) end
    local rows = MySQL.query.await('SELECT id, zone, items, won_at, claimed_by, claimed_at FROM crew_turf_rewards WHERE gang = ? ORDER BY id DESC LIMIT 30', { s.gang }) or {}
    for i = 1, #rows do rows[i].items = json.decode(rows[i].items) or {} end
    return ok(rows)
end

local claiming = {}
local function claimReward(src, id)
    local s = Sessions[src]
    id = tonumber(id)
    if not s or not isTurfGang(s.gang) then return fail('Hanya untuk anggota gang.') end
    if s.grade < DEPUTY then return fail('Hanya Boss / Wakil yang bisa mengambil reward.') end
    if not id or claiming[id] then return fail('Sedang diproses.') end
    claiming[id] = true

    local res = (function()
        local row = MySQL.single.await('SELECT gang, zone, items, claimed_at FROM crew_turf_rewards WHERE id = ?', { id })
        if not row or row.gang ~= s.gang then return fail('Reward tidak ditemukan.') end
        if row.claimed_at then return fail('Reward sudah diambil.') end
        local items = json.decode(row.items) or {}
        for i = 1, #items do
            local it = items[i]
            if not exports.ox_inventory:CanCarryItem(src, it[1], it[2]) then
                return fail('Inventory penuh / terlalu berat untuk reward ini.')
            end
        end
        local changed = MySQL.update.await('UPDATE crew_turf_rewards SET claimed_by = ?, claimed_at = ? WHERE id = ? AND claimed_at IS NULL', {
            s.name, os.time(), id,
        })
        if changed ~= 1 then return fail('Reward sudah diambil.') end
        PendingRewards[s.gang] = math.max(0, (PendingRewards[s.gang] or 1) - 1)
        local given = {}
        for i = 1, #items do
            local it = items[i]
            if exports.ox_inventory:AddItem(src, it[1], it[2]) then given[#given + 1] = ('%dx %s'):format(it[2], it[1]) end
        end
        audit(src, 'CrewTurfReward', ('%s (%s) ambil reward %s: %s'):format(s.name, s.gang, row.zone, table.concat(given, ', ')))
        return ok(true)
    end)()

    claiming[id] = nil
    return res
end

local function historyList()
    local rows = MySQL.query.await('SELECT zone, prev_label, winner_label, scores, ended_at FROM crew_turf_history ORDER BY id DESC LIMIT ?', { T.HistoryLimit }) or {}
    for i = 1, #rows do rows[i].scores = json.decode(rows[i].scores) or {} end
    return ok(rows)
end

-- Admin: tambah / edit / hapus wilayah ---------------------------------------------------------

local function cleanPoints(list)
    if type(list) ~= 'table' or #list < 3 or #list > 80 then return nil end
    local out = {}
    for i = 1, #list do
        local p = list[i]
        local x, y = type(p) == 'table' and tonumber(p[1]), type(p) == 'table' and tonumber(p[2])
        if not x or not y or x ~= x or y ~= y or math.abs(x) > 6000 or y < -6000 or y > 9500 then return nil end
        out[i] = { math.floor(x * 100 + 0.5) / 100, math.floor(y * 100 + 0.5) / 100 }
    end
    return out
end

local function cleanReward(list)
    if type(list) ~= 'table' or #list > T.MaxRewardItems then return nil, ('Maksimal %d item reward.'):format(T.MaxRewardItems) end
    local out = {}
    for i = 1, #list do
        local r = list[i]
        local name, count = type(r) == 'table' and r[1], type(r) == 'table' and tonumber(r[2])
        if type(name) ~= 'string' or not name:match('^[%w_%-]+$') or #name > 50 then return nil, 'Nama item tidak valid.' end
        if not exports.ox_inventory:Items(name) then return nil, ('Item "%s" tidak ada di ox_inventory.'):format(name) end
        count = count and math.floor(count)
        if not count or count < 1 or count > 100000000 then return nil, ('Jumlah item "%s" tidak valid.'):format(name) end
        out[#out + 1] = { name, count }
    end
    return out
end

local function newId(label)
    local base = label:upper():gsub('[^A-Z0-9]', ''):sub(1, 12)
    if base == '' then base = 'ZONA' end
    local id, n = base, 1
    while Zones[id] do
        n = n + 1
        id = base:sub(1, 12) .. n
    end
    return id
end

local function rebuildOrder()
    ZoneOrder = {}
    for id in pairs(Zones) do ZoneOrder[#ZoneOrder + 1] = id end
    table.sort(ZoneOrder, function(a, b) return Zones[a].label < Zones[b].label end)
end

local function saveZone(src, data)
    if not isAdmin(src) then return fail('Hanya admin.') end
    if type(data) ~= 'table' then return fail('Data tidak valid.') end
    local label = type(data.label) == 'string' and data.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #label < 2 or #label > 32 then return fail('Nama wilayah 2-32 karakter.') end
    local points = cleanPoints(data.points)
    if not points then return fail('Titik wilayah tidak valid (minimal 3, maksimal 80).') end
    local min = math.floor(tonumber(data.min) or 0)
    if min < 1 or min > 100 then return fail('Minimal peserta 1-100.') end
    local reward, rerr = cleanReward(data.reward or {})
    if not reward then return fail(rerr) end

    local mode = data.mode == 'flag' and 'flag' or 'points'
    local flagPt
    if mode == 'flag' then
        local f = data.flag
        local x, y, h = type(f) == 'table' and tonumber(f[1]), type(f) == 'table' and tonumber(f[2]), type(f) == 'table' and tonumber(f[3])
        if not x or not y or x ~= x or y ~= y then return fail('Tentukan titik bendera dulu.') end
        if not inPoly(points, x, y) then return fail('Titik bendera harus di dalam wilayah.') end
        local r = function(v) return math.floor(v * 100 + 0.5) / 100 end
        local zOk = h and h == h and math.abs(h) < 3000
        flagPt = { r(x), r(y), zOk and r(h) or nil }
        -- arah tugu/kain (dari [F] posisi saya); hanya kalau z ada supaya array JSON tidak bolong
        local hd = zOk and tonumber(f[4])
        if hd and hd == hd then flagPt[4] = r(hd % 360) end
    end

    local z = type(data.id) == 'string' and Zones[data.id] or nil
    for id, other in pairs(Zones) do
        if other.label:lower() == label:lower() and (not z or id ~= z.id) then return fail('Nama wilayah sudah dipakai.') end
    end

    if z then
        if z.battle then return fail('Wilayah sedang diperebutkan, tunggu sampai selesai.') end
        z.label, z.points, z.bounds, z.min, z.reward = label, points, boundsOf(points), min, reward
        z.mode, z.flagPt = mode, flagPt
        -- bukan mode bendera lagi: bendera yang berdiri kembali ke Boss
        if z.flag and mode ~= 'flag' then
            local old = z.flag
            z.flag, z.flagAt, z.dirty = nil, 0, true
            giveFlag(old, ('Mode %s diubah admin, bendera gangmu dikembalikan.'):format(label))
        end
        MySQL.update.await('UPDATE crew_turf_zones SET label = ?, points = ?, min_players = ?, reward = ?, mode = ?, flag_point = ? WHERE id = ?', {
            label, json.encode(points), min, json.encode(reward), mode, flagPt and json.encode(flagPt) or nil, z.id,
        })
        audit(src, 'CrewTurfZoneEdit', ('wilayah %s (%s) diubah, %d titik, mode %s'):format(z.id, label, #points, mode))
    else
        local id = newId(label)
        MySQL.insert.await('INSERT INTO crew_turf_zones (id, label, points, min_players, reward, created_at, mode, flag_point) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            id, label, json.encode(points), min, json.encode(reward), os.time(), mode, flagPt and json.encode(flagPt) or nil,
        })
        Zones[id] = {
            id = id, label = label, points = points, bounds = boundsOf(points), min = min, reward = reward,
            cooldownUntil = 0, dirty = false, mode = mode, flagPt = flagPt,
        }
        audit(src, 'CrewTurfZoneAdd', ('wilayah %s (%s) ditambah, %d titik, mode %s'):format(id, label, #points, mode))
    end
    rebuildOrder()
    publishFlags()
    publishPoints()
    return ok(true)
end

local function deleteZone(src, id)
    if not isAdmin(src) then return fail('Hanya admin.') end
    local z = type(id) == 'string' and Zones[id]
    if not z then return fail('Wilayah tidak ditemukan.') end
    if z.battle then return fail('Wilayah sedang diperebutkan, tunggu sampai selesai.') end
    Zones[id] = nil
    rebuildOrder()
    publishPoints()
    if z.flag then
        giveFlag(z.flag, ('Wilayah %s dihapus admin, bendera gangmu dikembalikan.'):format(z.label))
        publishFlags()
    end
    MySQL.update.await('DELETE FROM crew_turf_zones WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM crew_turf WHERE zone = ?', { id })
    audit(src, 'CrewTurfZoneDelete', ('wilayah %s (%s) dihapus'):format(id, z.label))
    return ok(true)
end

-- Admin: bendera gang (tab Bendera) ------------------------------------------------------------

local function flagList(src)
    if not isAdmin(src) then return fail('Hanya admin.') end
    local list, cids = {}, {}
    for name, g in pairs(Gangs) do
        if g.tag == 'gang' then
            local info = FlagInfo[name] or { issued = 0, pending = 0 }
            local planted = {}
            for _, z in pairs(Zones) do
                if z.flag == name then planted[#planted + 1] = z.label end
            end
            list[#list + 1] = {
                gang = name, label = g.label, color = g.color, owner = g.owner, online = sessionOfCid(g.owner) ~= nil,
                model = info.model or '', issued = info.issued, pending = info.pending, planted = planted,
            }
            cids[#cids + 1] = g.owner
        end
    end
    if #cids > 0 then
        local rows = MySQL.query.await(('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(string.rep('?', #cids, ',')), cids) or {}
        local names = {}
        for i = 1, #rows do names[rows[i].citizenid] = util.charName(rows[i].charinfo) end
        for i = 1, #list do
            list[i].boss = names[list[i].owner] or '?'
            list[i].owner = nil
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return ok({ list = list, item = F.Item, model = F.DefaultModel, hand = F.DefaultHandModel })
end

local function flagSetModel(src, p)
    if not isAdmin(src) then return fail('Hanya admin.') end
    local gang = type(p) == 'table' and p.gang
    if not isTurfGang(gang) then return fail('Gang tidak ditemukan.') end
    local model = type(p.model) == 'string' and p.model:match('^%s*(.-)%s*$') or ''
    if model ~= '' and (#model > 64 or not model:match('^[%w_%-]+$')) then return fail('Nama model hanya huruf, angka, _ dan - (maks 64).') end
    local info = flagInfo(gang)
    info.model = model ~= '' and model or nil
    saveFlagInfo(gang)
    publishFlags()
    for hsrc, hgang in pairs(Holding) do
        if hgang == gang then Player(hsrc).state:set(FLAG_STATE, holdState(gang), true) end
    end
    audit(src, 'CrewFlagModel', ('model bendera %s = %s'):format(gang, info.model or '(default)'))
    return ok(true)
end

local function flagGive(src, gang)
    if not isAdmin(src) then return fail('Hanya admin.') end
    if not isTurfGang(gang) then return fail('Gang tidak ditemukan.') end
    local info = flagInfo(gang)
    info.issued = info.issued + 1
    local now = giveFlag(gang, 'Admin memberikan bendera gang. Cek inventory.')
    audit(src, 'CrewFlagGive', ('bendera %s diberikan ke Boss (%s)'):format(gang, now and 'langsung' or 'antre sampai login'))
    return ok(now)
end

-- Callback menu: satu pintu, rate limit per pemain.
local handlers = {
    data = function(src, p) return menuData(src, p == true) end,
    start = startBattle,
    join = joinBattle,
    rewards = rewardList,
    claim = claimReward,
    history = function() return historyList() end,
    saveZone = saveZone,
    deleteZone = deleteZone,
    flagHold = flagHold,
    flagStart = flagStart,
    flags = flagList,
    flagModel = flagSetModel,
    flagGive = flagGive,
}

lib.callback.register('f_crew:turf:call', function(src, name, payload)
    if not ready or not T.Enabled then return fail('Gang Wars belum siap.') end
    local fn = type(name) == 'string' and handlers[name]
    if not fn then return fail('Aksi tidak dikenal.') end
    -- aksi tulis punya jatah sendiri supaya tidak tertahan oleh polling data menu
    if limited(src, name == 'data' and 300 or 600, name == 'data' and 'r' or 'w') then return fail('Terlalu cepat, coba lagi.') end
    local success, res = pcall(fn, src, payload)
    if not success then
        lib.print.error(('[f_crew] turf %s: %s'):format(name, res))
        return fail('Terjadi kesalahan di server.')
    end
    if name ~= 'data' and type(res) == 'table' and not res.ok then
        lib.print.warn(('[f_crew] turf %s ditolak untuk %s (%s): %s'):format(name, GetPlayerName(src) or '?', src, res.err))
    end
    return res
end)

AddEventHandler('playerDropped', function()
    callAt[source .. 'r'], callAt[source .. 'w'] = nil, nil
    openTurf[source] = nil
    Holding[source] = nil
    cancelActionsOf(source)
end)

-- Hook dari main.lua ---------------------------------------------------------------------------

---Sesi anggota dimulai (login / ganti gang / ganti rank): tampilkan scoreboard kalau gangnya perang.
function turf.join(src)
    if not ready or not T.Enabled then return end
    local s = Sessions[src]
    local z = s and isTurfGang(s.gang) and battleOf(s.gang)
    if z then pushHud(z, nil, src) end
    -- bendera yang antre untuk Boss (inventory baru siap beberapa detik setelah login)
    if s and FlagInfo[s.gang] and FlagInfo[s.gang].pending > 0 then
        SetTimeout(5000, function()
            if Sessions[src] == s then deliverPending(src) end
        end)
    end
end

---Sekali pakai: true kalau app Crew harus dibuka di Peringkat > Wilayah (baru dapat notifikasi hasil).
function turf.takeOpen(src)
    local untilAt = openTurf[src]
    openTurf[src] = nil
    return untilAt ~= nil and os.time() <= untilAt
end

---Sesi berakhir / keluar gang: scoreboard ditutup.
function turf.leave(src)
    killedAt[src] = nil
    cancelActionsOf(src)
    stowFlag(src)
    if GetPlayerPing(src) > 0 then TriggerClientEvent('f_crew:turf:hud', src, nil) end
end

---Lepas semua wilayah, perang & reward milik gang (bubar / jadi komunitas).
function turf.release(gangName)
    local flags = false
    for id, a in pairs(Actions) do
        if a.gang == gangName or a.target == gangName then stopAction(Zones[id], a, 'Gang bubar.') end
    end
    for _, z in pairs(Zones) do
        if z.owner == gangName then setOwner(z, nil) end
        if z.flag == gangName then
            z.flag, z.flagAt, z.dirty, flags = nil, 0, true, true
        end
        local b = z.battle
        if b and b.points[gangName] ~= nil then
            b.points[gangName] = nil
            if b.defender == gangName then b.defender = nil end
            for i = #b.attackers, 1, -1 do
                if b.attackers[i] == gangName then table.remove(b.attackers, i) end
            end
        end
    end
    if PendingRewards[gangName] then
        PendingRewards[gangName] = nil
        MySQL.update('DELETE FROM crew_turf_rewards WHERE gang = ? AND claimed_at IS NULL', { gangName })
    end
    if FlagInfo[gangName] then
        FlagInfo[gangName] = nil
        MySQL.update('DELETE FROM crew_flags WHERE gang = ?', { gangName })
    end
    if flags then publishFlags() end
end

---Pengaturan gang berubah (warna / tag). Warna baru terlihat di menu saat data berikutnya diambil.
function turf.gangChanged(g)
    if not ready then return end
    if g.tag ~= 'gang' then turf.release(g.name) end
    publishFlags() -- warna / nama di atas bendera tertancap
end

---Data tab Wilayah di Peringkat (app Crew).
function turf.board(mine)
    local wars = {}
    local now = os.time()
    for i = 1, #ZoneOrder do
        local z = Zones[ZoneOrder[i]]
        if z.battle and z.battle.phase == 'war' then wars[#wars + 1] = { label = z.label, left = math.max(0, z.battle.endsAt - now) } end
    end
    return { list = boardList(mine), wars = wars, total = #ZoneOrder, enabled = T.Enabled }
end

-- Start ----------------------------------------------------------------------------------------

local function ensureSchema()
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
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_turf_zones (
            id          VARCHAR(16)  NOT NULL,
            label       VARCHAR(32)  NOT NULL,
            points      TEXT         NOT NULL,
            min_players SMALLINT UNSIGNED NOT NULL DEFAULT 5,
            reward      TEXT         NOT NULL,
            created_at  INT UNSIGNED NOT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_turf_history (
            id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
            zone         VARCHAR(32)  NOT NULL,
            prev_label   VARCHAR(32)  NULL,
            winner       VARCHAR(32)  NULL,
            winner_label VARCHAR(32)  NULL,
            scores       TEXT         NOT NULL,
            ended_at     INT UNSIGNED NOT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_turf_rewards (
            id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            gang       VARCHAR(32)  NOT NULL,
            zone       VARCHAR(32)  NOT NULL,
            items      TEXT         NOT NULL,
            won_at     INT UNSIGNED NOT NULL,
            claimed_by VARCHAR(64)  NULL,
            claimed_at INT UNSIGNED NULL,
            PRIMARY KEY (id),
            INDEX idx_gang (gang)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS crew_flags (
            gang    VARCHAR(32) NOT NULL,
            model   VARCHAR(64) NULL,
            issued  INT UNSIGNED NOT NULL DEFAULT 0,
            pending SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (gang)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    -- kolom mode Rebut Bendera untuk tabel versi sebelumnya
    local function addColumn(tbl, col, def)
        local has = MySQL.scalar.await([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
        ]], { tbl, col })
        if (has or 0) == 0 then MySQL.query.await(('ALTER TABLE %s ADD COLUMN %s %s'):format(tbl, col, def)) end
    end
    addColumn('crew_turf_zones', 'mode', "VARCHAR(8) NOT NULL DEFAULT 'points'")
    addColumn('crew_turf_zones', 'flag_point', 'VARCHAR(80) NULL')
    addColumn('crew_turf', 'flag', 'VARCHAR(32) NULL')
    addColumn('crew_turf', 'flag_at', 'INT UNSIGNED NOT NULL DEFAULT 0')
end

---Isi crew_turf_zones dari server/turf_seed.lua kalau tabel masih kosong (sekali saja).
local function seedZones()
    if (MySQL.scalar.await('SELECT COUNT(*) FROM crew_turf_zones') or 0) > 0 then return end
    local now = os.time()
    for i = 1, #seed do
        local z = seed[i]
        MySQL.insert.await('INSERT INTO crew_turf_zones (id, label, points, min_players, reward, created_at) VALUES (?, ?, ?, ?, ?, ?)', {
            z.id, z.label, json.encode(z.points), T.DefaultMinPlayers, '[]', now,
        })
    end
    lib.print.info(('[f_crew] %d wilayah awal diimpor ke crew_turf_zones'):format(#seed))
end

---@param ctx { Gangs: table, Sessions: table, notify: function, audit: function }
function turf.start(ctx)
    Gangs, Sessions, notify, audit = ctx.Gangs, ctx.Sessions, ctx.notify, ctx.audit
    if not T.Enabled then return end

    ensureSchema()
    seedZones()

    local rows = MySQL.query.await('SELECT id, label, points, min_players, reward, mode, flag_point FROM crew_turf_zones') or {}
    for i = 1, #rows do
        local r = rows[i]
        local points = json.decode(r.points)
        if type(points) == 'table' and #points >= 3 then
            local fpt = r.flag_point and json.decode(r.flag_point)
            local flagMode = r.mode == 'flag' and type(fpt) == 'table' and tonumber(fpt[1]) and tonumber(fpt[2])
            Zones[r.id] = {
                id = r.id, label = r.label, points = points, bounds = boundsOf(points),
                min = r.min_players, reward = json.decode(r.reward) or {}, cooldownUntil = 0, dirty = false,
                mode = flagMode and 'flag' or 'points', flagPt = flagMode and fpt or nil,
            }
        end
    end
    rebuildOrder()

    local flagRows = MySQL.query.await('SELECT gang, model, issued, pending FROM crew_flags') or {}
    for i = 1, #flagRows do
        local r = flagRows[i]
        if isTurfGang(r.gang) then
            FlagInfo[r.gang] = { model = r.model, issued = r.issued, pending = r.pending }
        else
            MySQL.update('DELETE FROM crew_flags WHERE gang = ?', { r.gang })
        end
    end

    local owners = MySQL.query.await('SELECT zone, owner, cooldown_until, flag, flag_at FROM crew_turf') or {}
    for i = 1, #owners do
        local r = owners[i]
        local z = Zones[r.zone]
        if z then
            z.cooldownUntil = tonumber(r.cooldown_until) or 0
            if r.owner and isTurfGang(r.owner) then
                z.owner = r.owner
            elseif r.owner then
                z.dirty = true -- gang sudah bubar / jadi komunitas
            end
            if r.flag and z.mode == 'flag' and isTurfGang(r.flag) then
                z.flag, z.flagAt = r.flag, tonumber(r.flag_at) or 0
            elseif r.flag then
                z.dirty = true
            end
        end
    end
    publishFlags()
    publishPoints()
    -- state bag pemain bertahan walau resource restart: bendera di tangan dilepas
    for _, id in ipairs(GetPlayers()) do
        local p = Player(tonumber(id) --[[@as integer]])
        if p.state[FLAG_STATE] then p.state:set(FLAG_STATE, nil, true) end
    end
    -- pemilik wilayah yang sudah dihapus
    MySQL.update.await('DELETE t FROM crew_turf t LEFT JOIN crew_turf_zones z ON z.id = t.zone WHERE z.id IS NULL')

    -- reward: yang sudah diambil dibersihkan, yang belum dihitung per gang
    MySQL.update.await('DELETE FROM crew_turf_rewards WHERE claimed_at IS NOT NULL AND claimed_at < ?', { os.time() - T.RewardKeepDays * 86400 })
    local pending = MySQL.query.await('SELECT gang, COUNT(*) AS n FROM crew_turf_rewards WHERE claimed_at IS NULL GROUP BY gang') or {}
    for i = 1, #pending do
        if isTurfGang(pending[i].gang) then PendingRewards[pending[i].gang] = pending[i].n end
    end
    trimHistory()

    ready = true
    CreateThread(function()
        while true do
            Wait(T.TickSeconds * 1000)
            local success, err = pcall(tick)
            if not success then lib.print.error(('[f_crew] turf tick: %s'):format(err)) end
        end
    end)
end

return turf
