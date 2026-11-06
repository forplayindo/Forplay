-- f_crew server: gang/komunitas buatan pemain untuk app Crew (f_phone).
--
-- Ringan: tidak ada loop. Semua data gang ada di memori (Gangs) dan hanya ditulis ke database saat
-- ada aksi. Keanggotaan milik qbx_core (player_groups); waktu main dicatat per sesi login dan baru
-- ditulis saat sesi berakhir. Semua aksi dicek di server (keanggotaan, rank, target, rate limit).

local config = require 'config'
local util   = require 'server.util'
local db     = require 'server.db'
local links  = require 'server.links'
local turf   = require 'server.turf'
local logger = require '@qbx_core.modules.logger'

local ok, fail = util.ok, util.fail
local DEPUTY, BOSS = config.DeputyGrade, config.BossGrade
local DAY = 86400
local APP_TTL = config.ApplicationDays * DAY
local TAGS = { gang = true, community = true }
local RECRUIT = { open = true, apply = true, closed = true }

---@type table<string, table> nama internal gang (crew_<id>) -> data
local Gangs = {}
---@type table<string, string> label huruf kecil -> nama internal
local ByLabel = {}
---@type table<integer, { cid: string, gang: string, grade: integer, name: string, since: integer, gangSince: integer }>
local Sessions = {}
---@type table<string, boolean> kunci aksi tulis yang sedang berjalan
local busy = {}
---@type table<integer, { w: integer, t: integer, n: integer }>
local lastCall = {}
local ready = false

-- Helper umum ---------------------------------------------------------------------------------

local function audit(src, event, message)
    lib.print.info(('[f_crew] %s: %s'):format(event, message))
    logger.log({
        source = src and ('%s (%s)'):format(GetPlayerName(src) or '?', src) or 'f_crew',
        event = event,
        message = message,
        webhook = config.Webhook,
        color = 'orange',
    })
end

---@param key string
---@param fn function
local function withLock(key, fn)
    if busy[key] then return fail('Sedang diproses, coba lagi sebentar.') end
    busy[key] = true
    local success, res = pcall(fn)
    busy[key] = nil
    if not success then
        lib.print.error(('[f_crew] %s'):format(res))
        return fail('Terjadi kesalahan di server.')
    end
    return res
end

local function cooldownLeft(cid)
    local left = GetResourceKvpInt('cd:' .. cid) - os.time()
    return left > 0 and left or 0
end

local function setCooldown(cid)
    SetResourceKvpInt('cd:' .. cid, os.time() + config.CooldownHours * 3600)
end

local function cooldownMsg(left)
    return ('Tunggu %d jam %d menit lagi sebelum buat atau gabung gang.'):format(left // 3600, (left % 3600) // 60)
end

---@param cid string
---@return integer?
local function sourceOf(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil
end

---Grade anggota dari player_groups, nil kalau bukan anggota.
local function memberGrade(gangName, cid)
    if type(cid) ~= 'string' then return nil end
    return MySQL.scalar.await("SELECT grade FROM player_groups WHERE citizenid = ? AND `group` = ? AND type = 'gang'", { cid, gangName })
end

---Apakah karakter (online/offline) sudah punya gang apa pun.
local function hasAnyGang(cid)
    return (MySQL.scalar.await("SELECT COUNT(*) FROM player_groups WHERE citizenid = ? AND type = 'gang'", { cid }) or 0) > 0
end

local function charNameByCid(cid)
    local src = sourceOf(cid)
    if src then
        local p = exports.qbx_core:GetPlayer(src)
        if p then return util.charName(p.PlayerData.charinfo) end
    end
    return util.charName(MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid }))
end

local function onlineCounts()
    local counts = {}
    for _, s in pairs(Sessions) do counts[s.gang] = (counts[s.gang] or 0) + 1 end
    return counts
end

---Jalankan fn(src) untuk anggota online gang, opsional minimal rank tertentu.
local function eachOnline(g, minGrade, fn)
    for src, s in pairs(Sessions) do
        if s.gang == g.name and (not minGrade or s.grade >= minGrade) then fn(src) end
    end
end

local function notifyGang(g, minGrade, title, body, except)
    eachOnline(g, minGrade, function(src)
        if src ~= except then links.notify(src, title, body) end
    end)
end

local function pushGang(g, minGrade)
    eachOnline(g, minGrade, function(src) TriggerClientEvent('f_crew:client:refresh', src) end)
end

local function gradeName(g, grade)
    return g.grades[grade + 1] or config.Grades[grade] and config.Grades[grade].name or tostring(grade)
end

-- Cache gang ----------------------------------------------------------------------------------

local function addToCache(g)
    Gangs[g.name] = g
    ByLabel[g.label:lower()] = g.name
end

local function removeFromCache(g)
    Gangs[g.name] = nil
    ByLabel[g.label:lower()] = nil
end

local function rowToGang(r)
    local grades = json.decode(r.grades or '[]') or {}
    for i = 0, 3 do grades[i + 1] = grades[i + 1] or config.Grades[i].name end
    return {
        id = r.id,
        name = r.name,
        label = r.label,
        tag = TAGS[r.tag] and r.tag or 'gang',
        description = r.description or '',
        color = r.color or config.DefaultColor,
        recruit = RECRUIT[r.recruit] and r.recruit or 'apply',
        maxMembers = r.max_members or config.MaxMembersDefault,
        grades = grades,
        radio = r.radio,
        garage = r.garage and json.decode(r.garage) or nil,
        announcement = r.announcement or '',
        announcedAt = r.announced_at or 0,
        owner = r.owner,
        createdAt = r.created_at,
        lastActive = r.last_active or 0,
        totalSeconds = tonumber(r.total_seconds) or 0,
        members = 0,
    }
end

local function summary(g, online)
    return {
        name = g.name,
        label = g.label,
        tag = g.tag,
        description = g.description,
        color = g.color,
        recruit = g.recruit,
        members = g.members,
        max = g.maxMembers,
        online = online[g.name] or 0,
    }
end

local function freeRadio()
    local used = {}
    for _, g in pairs(Gangs) do
        if g.radio then used[g.radio] = true end
    end
    for ch = config.RadioMin, config.RadioMax do
        if not used[ch] then return ch end
    end
end

-- Sesi online (leaderboard + hitungan online) -------------------------------------------------

local function touch(g)
    local now = os.time()
    if now - g.lastActive < 3600 then return end
    g.lastActive = now
    MySQL.prepare('UPDATE crew_gangs SET last_active = ? WHERE name = ?', { now, g.name })
end

---Tag crew ('gang' / 'community') dipasang di statebag supaya client (ox_target f_police) bisa
---menyembunyikan opsi khusus gang tanpa callback. Server lain tetap cek lewat export IsGang.
local function setTagState(src, tag)
    if not GetPlayerName(src) then return end
    Player(src).state:set('crewTag', tag, true)
end

local function sessionStop(src)
    local s = Sessions[src]
    if not s then return end
    Sessions[src] = nil
    setTagState(src, nil)
    turf.leave(src)
    local now = os.time()

    -- total gang (peringkat antar gang) punya titik mulai sendiri: reset boss tidak menyentuhnya
    local gangSecs = now - s.gangSince
    local g = Gangs[s.gang]
    if gangSecs > 0 and g then
        g.totalSeconds = g.totalSeconds + gangSecs
        MySQL.prepare('UPDATE crew_gangs SET total_seconds = total_seconds + ? WHERE name = ?', { gangSecs, s.gang })
    end

    local secs = now - s.since
    if secs < 1 then return end
    MySQL.prepare([[
        INSERT INTO crew_playtime (gang, citizenid, name, seconds) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds), name = VALUES(name)
    ]], { s.gang, s.cid, s.name, secs })
end

local function sessionStart(src)
    if Sessions[src] then return end
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return end
    local pg = p.PlayerData.gang
    local g = pg and Gangs[pg.name]
    if not g then return end
    -- qbx_core mereset rank gang aktif ke 0 kalau pemain login sebelum gang crew didaftarkan
    -- (server baru start / resource di-restart). Rank asli tetap ada di player_groups (PlayerData.gangs):
    -- pulihkan. SetPlayerPrimaryGang memicu OnGangUpdate -> sesi dimulai ulang dengan rank yang benar.
    local real = p.PlayerData.gangs and p.PlayerData.gangs[g.name]
    if real and real ~= (pg.grade and pg.grade.level) then
        lib.print.info(('[f_crew] rank gang %s dipulihkan %s -> %s'):format(p.PlayerData.citizenid, pg.grade and pg.grade.level or '?', real))
        exports.qbx_core:SetPlayerPrimaryGang(p.PlayerData.citizenid, g.name)
        if Sessions[src] then return end
        p = exports.qbx_core:GetPlayer(src)
        pg = p and p.PlayerData.gang
        if not pg or pg.name ~= g.name then return end
    end
    Sessions[src] = {
        cid = p.PlayerData.citizenid,
        gang = g.name,
        grade = pg.grade and pg.grade.level or 0,
        name = util.charName(p.PlayerData.charinfo),
        since = os.time(),
        gangSince = os.time(),
    }
    setTagState(src, g.tag)
    touch(g)
    turf.join(src)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(p)
    local src = p and p.PlayerData and p.PlayerData.source
    if src and ready then sessionStart(src) end
end)

-- Masuk/keluar gang, naik/turun rank: semuanya lewat SetPlayerPrimaryGang yang memicu event ini.
AddEventHandler('QBCore:Server:OnGangUpdate', function(src)
    if not src or not ready then return end
    sessionStop(src)
    sessionStart(src)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if src then sessionStop(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    sessionStop(src)
    lastCall[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Sessions) do sessionStop(src) end
end)

-- Masuk / keluar / bubar ----------------------------------------------------------------------

local function joinGang(cid, g)
    local added, err = exports.qbx_core:AddPlayerToGang(cid, g.name, 0)
    if not added then
        if err and err.code == 'max_gangs' then return fail('Pemain itu sudah punya gang.') end
        return fail('Gagal bergabung ke gang.')
    end
    exports.qbx_core:SetPlayerPrimaryGang(cid, g.name)
    MySQL.update.await('DELETE FROM crew_applications WHERE citizenid = ?', { cid })
    g.members = g.members + 1
    local name = charNameByCid(cid)
    local src = sourceOf(cid)
    if src then links.notify(src, g.label, 'Kamu sekarang anggota ' .. g.label) end
    notifyGang(g, nil, g.label, name .. ' bergabung ke gang', src)
    pushGang(g)
    audit(src, 'CrewJoin', ('%s (%s) bergabung ke %s (%s)'):format(name, cid, g.label, g.name))
    return ok(true)
end

---Keluarkan anggota (online/offline) dari gang.
local function removeMember(cid, g, withCooldown)
    exports.qbx_core:RemovePlayerFromGang(cid, g.name)
    local src = sourceOf(cid)
    if src then
        -- memicu OnGangUpdate: sesi berhenti, mm_radio & HUD ikut diperbarui
        exports.qbx_core:SetPlayerPrimaryGang(cid, 'none')
        links.radioKick(src, g.radio)
        TriggerClientEvent('f_crew:client:refresh', src)
    end
    if withCooldown then
        setCooldown(cid)
        if src then
            links.notify(src, 'Crew', ('Kamu baru bisa gabung atau buat gang lagi setelah %d jam.'):format(config.CooldownHours))
        end
    end
    g.members = math.max(0, g.members - 1)
end

---Bubarkan gang: anggota dikeluarkan, kas ke `receiver`, kendaraan ke impound, lalu dihapus.
---@param g table
---@param receiver string? citizenid penerima sisa kas
---@param withCooldown boolean
---@param reason string
local function disbandGang(g, receiver, withCooldown, reason)
    local members = MySQL.query.await("SELECT citizenid FROM player_groups WHERE `group` = ? AND type = 'gang'", { g.name }) or {}
    for i = 1, #members do
        local cid = members[i].citizenid
        local src = sourceOf(cid)
        removeMember(cid, g, withCooldown)
        if src then links.notify(src, g.label, 'Gang telah dibubarkan.') end
    end

    local balance = links.balance(g.name)
    if balance and balance > 0 and receiver and links.removeAccount(g.name, balance) then
        exports.qbx_core:AddMoney(receiver, 'bank', balance, 'crew-disband')
    end

    links.impoundGarage(g.name)
    if g.garage then
        g.garage = nil
        links.syncGarage(g, true)
    end
    if g.radio then
        links.radioUnlock(g.radio)
        links.radioBroadcast(g.radio, nil, nil)
    end

    MySQL.update.await('DELETE FROM crew_applications WHERE gang = ?', { g.name })
    MySQL.update.await('DELETE FROM crew_playtime WHERE gang = ?', { g.name })
    MySQL.update.await('DELETE FROM crew_bank_log WHERE gang = ?', { g.name })
    MySQL.update.await('DELETE FROM crew_gangs WHERE name = ?', { g.name })
    turf.release(g.name)
    removeFromCache(g)
    exports.qbx_core:RemoveGang(g.name)
    TriggerEvent('f_crew:server:gangDisbanded', g.name) -- f_graffiti menghapus graffiti gang ini

    audit(nil, 'CrewDisband', ('%s (%s) dibubarkan (%s), %d anggota, kas Rp %d ke %s'):format(
        g.label, g.name, reason, #members, balance or 0, receiver or '-'))
end

-- Validasi ------------------------------------------------------------------------------------

local function validLabel(raw)
    local s = util.text(raw, 64)
    if #s < config.NameMin or #s > config.NameMax then
        return nil, ('Nama gang harus %d-%d karakter.'):format(config.NameMin, config.NameMax)
    end
    if not s:match("^[%w][%w %-%.'&]*$") then
        return nil, "Nama hanya boleh huruf, angka, spasi, dan - . ' &"
    end
    local low = s:lower()
    local squashed = low:gsub('[^%w]', '')
    local words = {}
    for w in low:gmatch('%w+') do words[w] = true end
    for _, bad in ipairs(config.BlockedWords) do
        if (#bad <= 4 and words[bad]) or (#bad > 4 and squashed:find(bad, 1, true)) then
            return nil, 'Nama mengandung kata yang tidak diizinkan.'
        end
    end
    if low == 'none' then return nil, 'Nama tidak diizinkan.' end
    for jobName, job in pairs(exports.qbx_core:GetJobs()) do
        if low == jobName or (type(job.label) == 'string' and low == job.label:lower()) then
            return nil, 'Nama sama dengan nama pekerjaan.'
        end
    end
    if ByLabel[low] then return nil, 'Nama gang sudah dipakai.' end
    return s
end

-- Data untuk UI -------------------------------------------------------------------------------

local function homeData(ctx)
    local g = ctx.gang
    local online = onlineCounts()
    local data = summary(g, online)
    data.grade = ctx.grade
    data.gradeName = gradeName(g, ctx.grade)
    data.grades = g.grades
    data.radio = g.radio
    data.hasGarage = g.garage ~= nil
    data.announcement = g.announcement
    data.announcedAt = g.announcedAt
    data.perms = { deputy = ctx.grade >= DEPUTY, boss = ctx.grade >= BOSS }
    if ctx.grade >= DEPUTY then
        data.pending = MySQL.scalar.await("SELECT COUNT(*) FROM crew_applications WHERE gang = ? AND kind = 'apply' AND created_at > ?", {
            g.name, os.time() - APP_TTL,
        }) or 0
    end
    return data
end

-- Aksi ----------------------------------------------------------------------------------------

---@type table<string, { write: boolean, need: string, fn: function }>
local actions = {}

---@param name string
---@param write boolean aksi yang mengubah data (rate limit ketat + kunci)
---@param need 'any'|'free'|'member'|'deputy'|'boss'
---@param fn fun(ctx: table, p: table): table
local function action(name, write, need, fn)
    actions[name] = { write = write, need = need, fn = fn }
end

action('state', false, 'any', function(ctx)
    local data = { me = { name = ctx.name }, cooldown = cooldownLeft(ctx.cid) }
    -- baru dapat notifikasi hasil perebutan wilayah: app langsung ke Peringkat > Wilayah
    if turf.takeOpen(ctx.src) then data.open = 'turf' end
    if ctx.gang then
        data.gang = homeData(ctx)
        return ok(data)
    end
    if ctx.anyGang then
        data.foreign = true
        return ok(data)
    end
    local rows = MySQL.query.await('SELECT id, gang, kind, message, created_at FROM crew_applications WHERE citizenid = ? AND created_at > ?', {
        ctx.cid, os.time() - APP_TTL,
    }) or {}
    local online = onlineCounts()
    data.invites = {}
    for i = 1, #rows do
        local r = rows[i]
        local g = Gangs[r.gang]
        if g then
            local item = summary(g, online)
            item.id = r.id
            item.at = r.created_at
            if r.kind == 'apply' then
                item.message = r.message
                data.application = item
            else
                data.invites[#data.invites + 1] = item
            end
        end
    end
    return ok(data)
end)

action('discover', false, 'any', function()
    local online = onlineCounts()
    local list = {}
    for _, g in pairs(Gangs) do list[#list + 1] = summary(g, online) end
    table.sort(list, function(a, b)
        if a.members ~= b.members then return a.members > b.members end
        return a.label < b.label
    end)
    return ok(list)
end)

action('create', true, 'free', function(ctx, p)
    local left = cooldownLeft(ctx.cid)
    if left > 0 then return fail(cooldownMsg(left)) end
    local label, err = validLabel(p.label)
    if not label then return fail(err) end

    return withLock('label:' .. label:lower(), function()
        local now = os.time()
        local g = {
            label = label,
            tag = TAGS[p.tag] and p.tag or 'gang',
            description = util.text(p.description, config.DescMax),
            color = util.color(p.color) or config.DefaultColor,
            recruit = RECRUIT[p.recruit] and p.recruit or 'apply',
            maxMembers = config.MaxMembersDefault,
            grades = {},
            radio = freeRadio(),
            announcement = '',
            announcedAt = 0,
            owner = ctx.cid,
            createdAt = now,
            lastActive = now,
            totalSeconds = 0,
            members = 0,
        }
        for i = 0, 3 do g.grades[i + 1] = config.Grades[i].name end

        local id = MySQL.insert.await([[
            INSERT INTO crew_gangs (label, tag, description, color, recruit, max_members, grades, radio, owner, created_at, last_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { g.label, g.tag, g.description, g.color, g.recruit, g.maxMembers, json.encode(g.grades), g.radio, g.owner, now, now })
        if not id then return fail('Nama gang sudah dipakai.') end

        g.id = id
        g.name = 'crew_' .. id
        MySQL.update.await('UPDATE crew_gangs SET name = ? WHERE id = ?', { g.name, id })
        addToCache(g)
        links.registerGangs({ g })

        local added = exports.qbx_core:AddPlayerToGang(ctx.cid, g.name, BOSS)
        if not added then
            removeFromCache(g)
            exports.qbx_core:RemoveGang(g.name)
            MySQL.update.await('DELETE FROM crew_gangs WHERE id = ?', { id })
            return fail('Gagal membuat gang, coba lagi.')
        end
        exports.qbx_core:SetPlayerPrimaryGang(ctx.cid, g.name)
        g.members = 1

        links.ensureAccount(g)
        if g.radio then
            links.radioLock(g)
            links.radioBroadcast(g.radio, g.name, g.label)
        end
        MySQL.update.await('DELETE FROM crew_applications WHERE citizenid = ?', { ctx.cid })

        audit(ctx.src, 'CrewCreate', ('%s (%s) membuat %s "%s" (%s), radio %s'):format(
            ctx.name, ctx.cid, g.tag, g.label, g.name, g.radio or '-'))
        return ok(true)
    end)
end)

action('apply', true, 'free', function(ctx, p)
    local left = cooldownLeft(ctx.cid)
    if left > 0 then return fail(cooldownMsg(left)) end
    local g = type(p.gang) == 'string' and Gangs[p.gang]
    if not g then return fail('Gang tidak ditemukan.') end
    if g.recruit == 'closed' then return fail('Gang ini hanya menerima lewat undangan.') end

    return withLock(g.name, function()
        if g.members >= g.maxMembers then return fail('Gang sudah penuh.') end
        if g.recruit == 'open' then return joinGang(ctx.cid, g) end

        local pending = MySQL.scalar.await("SELECT COUNT(*) FROM crew_applications WHERE citizenid = ? AND kind = 'apply' AND created_at > ?", {
            ctx.cid, os.time() - APP_TTL,
        }) or 0
        if pending > 0 then return fail('Kamu masih punya lamaran yang menunggu keputusan.') end

        MySQL.insert.await("INSERT INTO crew_applications (gang, citizenid, name, kind, message, created_at) VALUES (?, ?, ?, 'apply', ?, ?)", {
            g.name, ctx.cid, ctx.name, util.text(p.message, config.MessageMax), os.time(),
        })
        notifyGang(g, DEPUTY, g.label, 'Lamaran baru dari ' .. ctx.name)
        pushGang(g, DEPUTY)
        return ok(true)
    end)
end)

action('cancelApply', true, 'free', function(ctx)
    local row = MySQL.single.await("SELECT gang FROM crew_applications WHERE citizenid = ? AND kind = 'apply'", { ctx.cid })
    MySQL.update.await("DELETE FROM crew_applications WHERE citizenid = ? AND kind = 'apply'", { ctx.cid })
    local g = row and Gangs[row.gang]
    if g then pushGang(g, DEPUTY) end
    return ok(true)
end)

action('acceptInvite', true, 'free', function(ctx, p)
    local left = cooldownLeft(ctx.cid)
    if left > 0 then return fail(cooldownMsg(left)) end
    local id = util.int(p.id, 1, 2147483647)
    local row = id and MySQL.single.await("SELECT gang, created_at FROM crew_applications WHERE id = ? AND citizenid = ? AND kind = 'invite'", { id, ctx.cid })
    if not row or row.created_at < os.time() - APP_TTL then return fail('Undangan sudah tidak berlaku.') end
    local g = Gangs[row.gang]
    if not g then return fail('Gang sudah tidak ada.') end
    return withLock(g.name, function()
        if g.members >= g.maxMembers then return fail('Gang sudah penuh.') end
        return joinGang(ctx.cid, g)
    end)
end)

action('declineInvite', true, 'free', function(ctx, p)
    local id = util.int(p.id, 1, 2147483647)
    if id then MySQL.update.await("DELETE FROM crew_applications WHERE id = ? AND citizenid = ? AND kind = 'invite'", { id, ctx.cid }) end
    return ok(true)
end)

action('members', false, 'member', function(ctx)
    local g = ctx.gang
    local rows = MySQL.query.await([[
        SELECT pg.citizenid, pg.grade, p.charinfo FROM player_groups pg
        LEFT JOIN players p ON p.citizenid = pg.citizenid
        WHERE pg.`group` = ? AND pg.type = 'gang'
    ]], { g.name }) or {}
    local online = {}
    for _, s in pairs(Sessions) do
        if s.gang == g.name then online[s.cid] = true end
    end
    local list = {}
    for i = 1, #rows do
        local r = rows[i]
        list[i] = {
            cid = r.citizenid,
            name = util.charName(r.charinfo),
            grade = r.grade,
            gradeName = gradeName(g, r.grade),
            online = online[r.citizenid] == true,
            me = r.citizenid == ctx.cid,
            manage = r.citizenid ~= ctx.cid and r.grade < ctx.grade and ctx.grade >= DEPUTY,
        }
    end
    table.sort(list, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return ok({ list = list, grades = g.grades, myGrade = ctx.grade })
end)

action('leave', true, 'member', function(ctx)
    local g = ctx.gang
    if ctx.grade >= BOSS then
        return fail('Boss harus menyerahkan kepemimpinan atau membubarkan gang dulu.')
    end
    removeMember(ctx.cid, g, true)
    notifyGang(g, nil, g.label, ctx.name .. ' keluar dari gang')
    pushGang(g)
    audit(ctx.src, 'CrewLeave', ('%s (%s) keluar dari %s'):format(ctx.name, ctx.cid, g.name))
    return ok(true)
end)

-- Leaderboard waktu main
action('leaderboard', false, 'member', function(ctx)
    local g = ctx.gang
    local rows = MySQL.query.await([[
        SELECT pt.citizenid, pt.name, pt.seconds FROM crew_playtime pt
        JOIN player_groups pg ON pg.citizenid = pt.citizenid AND pg.`group` = pt.gang AND pg.type = 'gang'
        WHERE pt.gang = ? ORDER BY pt.seconds DESC LIMIT ?
    ]], { g.name, config.LeaderboardLimit }) or {}
    local byCid, list = {}, {}
    for i = 1, #rows do
        local r = { cid = rows[i].citizenid, name = rows[i].name, seconds = tonumber(rows[i].seconds) or 0, online = false }
        byCid[r.cid] = r
        list[#list + 1] = r
    end
    local now = os.time()
    for _, s in pairs(Sessions) do
        if s.gang == g.name then
            local r = byCid[s.cid]
            if not r then
                r = { cid = s.cid, name = s.name, seconds = 0 }
                byCid[s.cid] = r
                list[#list + 1] = r
            end
            r.seconds = r.seconds + (now - s.since)
            r.online = true
        end
    end
    table.sort(list, function(a, b) return a.seconds > b.seconds end)
    local out = {}
    for i = 1, math.min(#list, config.LeaderboardLimit) do
        local r = list[i]
        out[i] = { rank = i, name = r.name, points = r.seconds // 60, online = r.online, me = r.cid == ctx.cid }
    end
    return ok({ list = out, boss = ctx.grade >= BOSS })
end)

action('resetLeaderboard', true, 'boss', function(ctx)
    local g = ctx.gang
    MySQL.update.await('DELETE FROM crew_playtime WHERE gang = ?', { g.name })
    local now = os.time()
    for _, s in pairs(Sessions) do
        if s.gang == g.name then s.since = now end
    end
    pushGang(g)
    audit(ctx.src, 'CrewLeaderboardReset', ('%s mereset leaderboard %s'):format(ctx.name, g.name))
    return ok(true)
end)

-- Peringkat antar gang: total waktu main semua anggota. Hanya admin yang bisa reset (/resetgang).
-- Gang dan komunitas diperingkat terpisah (payload.tag).
action('gangBoard', false, 'any', function(ctx, p)
    local tag = TAGS[p.tag] and p.tag or 'gang'
    local now = os.time()
    local live = {}
    for _, s in pairs(Sessions) do live[s.gang] = (live[s.gang] or 0) + (now - s.gangSince) end
    local list = {}
    for _, g in pairs(Gangs) do
        if g.tag == tag then
            list[#list + 1] = { g = g, seconds = g.totalSeconds + (live[g.name] or 0) }
        end
    end
    table.sort(list, function(a, b)
        if a.seconds ~= b.seconds then return a.seconds > b.seconds end
        return a.g.label < b.g.label
    end)
    local mine = ctx.gang and ctx.gang.name
    local out = {}
    for i = 1, math.min(#list, config.LeaderboardLimit) do
        local g = list[i].g
        out[i] = {
            rank = i,
            label = g.label,
            color = g.color,
            points = list[i].seconds // 60,
            mine = g.name == mine,
        }
    end
    return ok(out)
end)

-- Peringkat wilayah: jumlah zona yang dikuasai tiap gang + perang yang sedang berjalan.
action('turfBoard', false, 'any', function(ctx)
    return ok(turf.board(ctx.gang and ctx.gang.name))
end)

-- Kas gang
local function bankLog(g, name, kind, amount, note)
    MySQL.prepare('INSERT INTO crew_bank_log (gang, name, kind, amount, note, created_at) VALUES (?, ?, ?, ?, ?, ?)', {
        g.name, name, kind, amount, note or '', os.time(),
    })
end

action('bank', false, 'member', function(ctx)
    local g = ctx.gang
    local rows = MySQL.query.await('SELECT name, kind, amount, note, created_at FROM crew_bank_log WHERE gang = ? ORDER BY id DESC LIMIT ?', {
        g.name, config.BankLogLimit,
    }) or {}
    local log = {}
    for i = 1, #rows do
        local r = rows[i]
        log[i] = { name = r.name, kind = r.kind, amount = r.amount, note = r.note, at = r.created_at }
    end
    return ok({ balance = links.balance(g.name), log = log, canManage = ctx.grade >= DEPUTY })
end)

action('deposit', true, 'member', function(ctx, p)
    local g = ctx.gang
    local amount = util.int(p.amount, 1, config.BankMax)
    if not amount then return fail('Jumlah tidak valid.') end
    local balance = links.balance(g.name)
    if not balance then return fail('Kas gang belum tersedia.') end
    if balance + amount > config.BalanceMax then
        return fail(('Kas gang maksimal Rp %s.'):format(lib.math.groupdigits(config.BalanceMax, '.')))
    end
    -- bank di qbx_core boleh minus, jadi saldo dicek dulu
    if (exports.qbx_core:GetMoney(ctx.src, 'bank') or 0) < amount
        or not exports.qbx_core:RemoveMoney(ctx.src, 'bank', amount, 'crew-deposit') then
        return fail('Saldo bank kamu tidak cukup.')
    end
    if not links.addAccount(g.name, amount) then
        exports.qbx_core:AddMoney(ctx.src, 'bank', amount, 'crew-deposit-refund')
        return fail('Kas gang belum tersedia.')
    end
    bankLog(g, ctx.name, 'deposit', amount)
    links.bankHistory(g.name, 'Crew / ' .. g.label, amount, 'Setoran lewat app Crew', ctx.name, g.label, 'deposit')
    pushGang(g)
    audit(ctx.src, 'CrewDeposit', ('%s setor Rp %d ke %s'):format(ctx.name, amount, g.name))
    return ok(true)
end)

action('withdraw', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    local amount = util.int(p.amount, 1, config.BankMax)
    if not amount then return fail('Jumlah tidak valid.') end
    if not links.removeAccount(g.name, amount) then return fail('Saldo kas tidak cukup.') end
    exports.qbx_core:AddMoney(ctx.src, 'bank', amount, 'crew-withdraw')
    bankLog(g, ctx.name, 'withdraw', amount)
    links.bankHistory(g.name, 'Crew / ' .. g.label, amount, 'Tarik lewat app Crew', g.label, ctx.name, 'withdraw')
    pushGang(g)
    audit(ctx.src, 'CrewWithdraw', ('%s tarik Rp %d dari %s'):format(ctx.name, amount, g.name))
    return ok(true)
end)

action('transfer', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    local amount = util.int(p.amount, 1, config.BankMax)
    if not amount then return fail('Jumlah tidak valid.') end
    local number = type(p.number) == 'string' and p.number:sub(1, 20) or nil
    local cid = links.cidByNumber(number)
    if not cid then return fail('Nomor tidak terdaftar.') end
    if not links.removeAccount(g.name, amount) then return fail('Saldo kas tidak cukup.') end
    if not exports.qbx_core:AddMoney(cid, 'bank', amount, 'crew-transfer') then
        links.addAccount(g.name, amount)
        return fail('Transfer gagal.')
    end
    local target = charNameByCid(cid)
    bankLog(g, ctx.name, 'transfer', amount, 'ke ' .. target)
    links.bankHistory(g.name, 'Crew / ' .. g.label, amount, 'Transfer ke ' .. target, g.label, target, 'withdraw')
    local src = sourceOf(cid)
    if src then links.notify(src, g.label, ('Kamu menerima transfer Rp %d'):format(amount)) end
    pushGang(g)
    audit(ctx.src, 'CrewTransfer', ('%s transfer Rp %d dari %s ke %s (%s)'):format(ctx.name, amount, g.name, target, cid))
    return ok(true)
end)

-- Lamaran & undangan (wakil ke atas)
action('applications', false, 'deputy', function(ctx)
    local rows = MySQL.query.await("SELECT id, name, message, created_at FROM crew_applications WHERE gang = ? AND kind = 'apply' AND created_at > ? ORDER BY id", {
        ctx.gang.name, os.time() - APP_TTL,
    }) or {}
    local list = {}
    for i = 1, #rows do
        list[i] = { id = rows[i].id, name = rows[i].name, message = rows[i].message, at = rows[i].created_at }
    end
    return ok(list)
end)

action('decide', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    local id = util.int(p.id, 1, 2147483647)
    local row = id and MySQL.single.await("SELECT citizenid, name, created_at FROM crew_applications WHERE id = ? AND gang = ? AND kind = 'apply'", { id, g.name })
    if not row then return fail('Lamaran tidak ditemukan.') end
    if row.created_at < os.time() - APP_TTL then
        MySQL.update.await('DELETE FROM crew_applications WHERE id = ?', { id })
        return fail('Lamaran sudah kedaluwarsa.')
    end

    if p.accept ~= true then
        MySQL.update.await('DELETE FROM crew_applications WHERE id = ?', { id })
        local src = sourceOf(row.citizenid)
        if src then
            links.notify(src, g.label, 'Lamaranmu ditolak.')
            TriggerClientEvent('f_crew:client:refresh', src)
        end
        pushGang(g, DEPUTY)
        return ok(true)
    end

    if g.members >= g.maxMembers then return fail('Gang sudah penuh.') end
    if hasAnyGang(row.citizenid) then
        MySQL.update.await('DELETE FROM crew_applications WHERE id = ?', { id })
        return fail('Pelamar sudah bergabung dengan gang lain.')
    end
    return joinGang(row.citizenid, g)
end)

action('invite', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    local number = type(p.number) == 'string' and p.number:sub(1, 20) or nil
    local cid = links.cidByNumber(number)
    if not cid then return fail('Nomor tidak terdaftar.') end
    if cid == ctx.cid then return fail('Tidak bisa mengundang diri sendiri.') end
    if g.members >= g.maxMembers then return fail('Gang sudah penuh.') end
    if hasAnyGang(cid) then return fail('Orang itu sudah punya gang.') end
    local exists = MySQL.scalar.await("SELECT COUNT(*) FROM crew_applications WHERE gang = ? AND citizenid = ? AND kind = 'invite' AND created_at > ?", {
        g.name, cid, os.time() - APP_TTL,
    }) or 0
    if exists > 0 then return fail('Undangan untuk orang itu sudah dikirim.') end

    local name = charNameByCid(cid)
    MySQL.insert.await("INSERT INTO crew_applications (gang, citizenid, name, kind, message, created_at) VALUES (?, ?, ?, 'invite', '', ?)", {
        g.name, cid, name, os.time(),
    })
    local src = sourceOf(cid)
    if src then
        links.notify(src, 'Undangan gang', ('%s mengundangmu bergabung ke %s'):format(ctx.name, g.label))
        TriggerClientEvent('f_crew:client:refresh', src)
    end
    audit(ctx.src, 'CrewInvite', ('%s mengundang %s (%s) ke %s'):format(ctx.name, name, cid, g.name))
    return ok(name)
end)

-- Rank, kick, kepemimpinan
action('setGrade', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    if p.cid == ctx.cid then return fail('Tidak bisa mengubah rank sendiri.') end
    local current = memberGrade(g.name, p.cid)
    if not current then return fail('Bukan anggota gang ini.') end
    if current >= ctx.grade then return fail('Rank orang itu sama atau lebih tinggi darimu.') end
    local grade = util.int(p.grade, 0, ctx.grade - 1)
    if not grade or grade >= BOSS then return fail('Rank tidak valid.') end
    if grade == current then return ok(true) end

    exports.qbx_core:AddPlayerToGang(p.cid, g.name, grade)
    local src = sourceOf(p.cid)
    if src then links.notify(src, g.label, 'Rank kamu sekarang ' .. gradeName(g, grade)) end
    pushGang(g)
    audit(ctx.src, 'CrewGrade', ('%s mengubah rank %s di %s: %d -> %d'):format(ctx.name, p.cid, g.name, current, grade))
    return ok(true)
end)

action('kick', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    if p.cid == ctx.cid then return fail('Gunakan menu keluar gang.') end
    local current = memberGrade(g.name, p.cid)
    if not current then return fail('Bukan anggota gang ini.') end
    if current >= ctx.grade then return fail('Rank orang itu sama atau lebih tinggi darimu.') end

    local src = sourceOf(p.cid)
    removeMember(p.cid, g, true)
    if src then links.notify(src, g.label, 'Kamu dikeluarkan dari gang.') end
    pushGang(g)
    audit(ctx.src, 'CrewKick', ('%s mengeluarkan %s dari %s'):format(ctx.name, p.cid, g.name))
    return ok(true)
end)

action('handover', true, 'boss', function(ctx, p)
    local g = ctx.gang
    if p.cid == ctx.cid then return fail('Pilih anggota lain.') end
    local current = memberGrade(g.name, p.cid)
    if not current then return fail('Bukan anggota gang ini.') end

    exports.qbx_core:AddPlayerToGang(p.cid, g.name, BOSS)
    exports.qbx_core:AddPlayerToGang(ctx.cid, g.name, DEPUTY)
    g.owner = p.cid
    MySQL.update.await('UPDATE crew_gangs SET owner = ? WHERE name = ?', { p.cid, g.name })
    local src = sourceOf(p.cid)
    if src then links.notify(src, g.label, 'Kamu sekarang Boss ' .. g.label) end
    notifyGang(g, nil, g.label, 'Kepemimpinan gang telah diserahkan', src)
    pushGang(g)
    audit(ctx.src, 'CrewHandover', ('%s menyerahkan kepemimpinan %s ke %s'):format(ctx.name, g.name, p.cid))
    return ok(true)
end)

action('disband', true, 'boss', function(ctx, p)
    local g = ctx.gang
    if type(p.confirm) ~= 'string' or p.confirm:lower() ~= g.label:lower() then
        return fail('Ketik nama gang dengan benar untuk konfirmasi.')
    end
    audit(ctx.src, 'CrewDisbandRequest', ('%s (%s) membubarkan %s'):format(ctx.name, ctx.cid, g.name))
    disbandGang(g, ctx.cid, true, 'boss')
    return ok(true)
end)

-- Pengumuman & pengaturan
action('announce', true, 'deputy', function(ctx, p)
    local g = ctx.gang
    local text = util.text(p.text, config.AnnounceMax)
    g.announcement = text
    g.announcedAt = text ~= '' and os.time() or 0
    MySQL.update.await('UPDATE crew_gangs SET announcement = ?, announced_at = ? WHERE name = ?', { text, g.announcedAt, g.name })
    if text ~= '' then notifyGang(g, nil, g.label .. ' - Pengumuman', text) end
    pushGang(g)
    return ok(true)
end)

action('settings', true, 'boss', function(ctx, p)
    local g = ctx.gang
    local maxMembers = util.int(p.maxMembers, config.MaxMembersMin, config.MaxMembersMax)
    if not maxMembers then
        return fail(('Batas anggota %d-%d.'):format(config.MaxMembersMin, config.MaxMembersMax))
    end
    if maxMembers < g.members then return fail('Batas anggota tidak boleh di bawah jumlah anggota sekarang.') end

    g.description = util.text(p.description, config.DescMax)
    g.color = util.color(p.color) or g.color
    g.tag = TAGS[p.tag] and p.tag or g.tag
    g.recruit = RECRUIT[p.recruit] and p.recruit or g.recruit
    g.maxMembers = maxMembers
    MySQL.update.await('UPDATE crew_gangs SET description = ?, color = ?, tag = ?, recruit = ?, max_members = ? WHERE name = ?', {
        g.description, g.color, g.tag, g.recruit, g.maxMembers, g.name,
    })
    turf.gangChanged(g)
    eachOnline(g, nil, function(src) setTagState(src, g.tag) end)
    pushGang(g)
    return ok(true)
end)

action('renameGrades', true, 'boss', function(ctx, p)
    local g = ctx.gang
    if type(p.names) ~= 'table' then return fail('Data tidak valid.') end
    local names = {}
    for i = 1, 4 do
        local n = util.text(p.names[i], config.GradeNameMax)
        if n == '' then return fail('Nama rank tidak boleh kosong.') end
        names[i] = n
    end
    g.grades = names
    MySQL.update.await('UPDATE crew_gangs SET grades = ? WHERE name = ?', { json.encode(names), g.name })
    links.registerGangs({ g })
    -- anggota online langsung dapat nama rank baru (dikumpulkan dulu: event-nya mengubah Sessions)
    local cids = {}
    eachOnline(g, nil, function(src) cids[#cids + 1] = Sessions[src].cid end)
    for i = 1, #cids do exports.qbx_core:SetPlayerPrimaryGang(cids[i], g.name) end
    pushGang(g)
    return ok(true)
end)

-- Garasi (boss): lokasi diambil dari posisi pemain di server, bukan dari client.
action('setGarage', true, 'boss', function(ctx)
    local g = ctx.gang
    if GetPlayerRoutingBucket(ctx.src) ~= 0 then return fail('Tidak bisa diatur di lokasi ini.') end
    local ped = GetPlayerPed(ctx.src)
    if ped == 0 then return fail('Posisi tidak ditemukan.') end
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c = GetEntityCoords(ent)
    local h = GetEntityHeading(ent)
    local round = function(v) return math.floor(v * 100 + 0.5) / 100 end
    g.garage = { x = round(c.x), y = round(c.y), z = round(c.z), h = round(h) }
    MySQL.update.await('UPDATE crew_gangs SET garage = ? WHERE name = ?', { json.encode(g.garage), g.name })
    links.syncGarage(g)
    pushGang(g)
    audit(ctx.src, 'CrewGarage', ('%s memindah garasi %s ke %.2f, %.2f, %.2f'):format(ctx.name, g.name, g.garage.x, g.garage.y, g.garage.z))
    return ok(true)
end)

action('removeGarage', true, 'boss', function(ctx)
    local g = ctx.gang
    if not g.garage then return ok(true) end
    g.garage = nil
    MySQL.update.await('UPDATE crew_gangs SET garage = NULL WHERE name = ?', { g.name })
    links.syncGarage(g, true)
    pushGang(g)
    audit(ctx.src, 'CrewGarage', ('%s menghapus lokasi garasi %s'):format(ctx.name, g.name))
    return ok(true)
end)

action('gps', false, 'member', function(ctx)
    local c = ctx.gang.garage
    if not c then return fail('Gang belum punya garasi.') end
    return ok({ x = c.x, y = c.y })
end)

-- Dispatcher ----------------------------------------------------------------------------------

local NEED_MSG = {
    free = 'Kamu sudah punya gang.',
    member = 'Kamu bukan anggota gang.',
    deputy = 'Hanya Wakil atau Boss.',
    boss = 'Hanya Boss.',
}

local function limited(src, write)
    local now = GetGameTimer()
    local l = lastCall[src]
    if not l then
        l = { w = 0, t = 0, n = 0 }
        lastCall[src] = l
    end
    if write then
        if now - l.w < 1000 then return true end
        l.w = now
        return false
    end
    if now - l.t > 1000 then
        l.t = now
        l.n = 0
    end
    l.n = l.n + 1
    return l.n > 8
end

local function context(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return nil end
    local pd = p.PlayerData
    local pg = pd.gang
    local g = pg and Gangs[pg.name] or nil
    -- qbx_core tetap memakai nama gang lama saat login walau gang itu sudah dihapus (labelnya
    -- "No Gang"). Anggap tanpa gang dan bersihkan sekalian supaya HUD & script lain ikut benar.
    if pg and pg.name ~= 'none' and not g and not exports.qbx_core:GetGang(pg.name) then
        exports.qbx_core:SetPlayerPrimaryGang(pd.citizenid, 'none')
        pg = nil
    end
    return {
        src = src,
        cid = pd.citizenid,
        name = util.charName(pd.charinfo),
        gang = g,
        grade = g and pg.grade and pg.grade.level or -1,
        anyGang = (pg ~= nil and pg.name ~= 'none') or next(pd.gangs or {}) ~= nil,
    }
end

lib.callback.register('f_crew:server:call', function(src, name, payload)
    if not ready then return fail('Crew sedang dimuat, coba lagi.') end
    local a = type(name) == 'string' and actions[name]
    if not a then return fail('Aksi tidak dikenal.') end
    if limited(src, a.write) then return fail('Terlalu cepat, coba lagi.') end
    local ctx = context(src)
    if not ctx then return fail('Karakter belum dimuat.') end

    local need = a.need
    if (need == 'free' and ctx.anyGang)
        or (need == 'member' and not ctx.gang)
        or (need == 'deputy' and (not ctx.gang or ctx.grade < DEPUTY))
        or (need == 'boss' and (not ctx.gang or ctx.grade < BOSS)) then
        return fail(NEED_MSG[need])
    end

    if type(payload) ~= 'table' then payload = {} end
    if not a.write then
        local success, res = pcall(a.fn, ctx, payload)
        if not success then
            lib.print.error(('[f_crew] %s: %s'):format(name, res))
            return fail('Terjadi kesalahan di server.')
        end
        return res
    end
    local key = ctx.gang and ctx.gang.name or ('p:' .. ctx.cid)
    return withLock(key, function() return a.fn(ctx, payload) end)
end)

-- mm_radio minta daftar channel gang saat login / restart.
---Hasil aksi app (teks dari UI) -> notifikasi HP pemain itu sendiri. Hanya ke HP-nya sendiri,
---dipotong 120 karakter dan dibatasi 1 per 0,5 detik supaya tidak bisa dipakai spam.
local selfNotifyAt = {}
RegisterNetEvent('f_crew:server:selfNotify', function(msg)
    local src = source
    if type(msg) ~= 'string' or msg == '' then return end
    local now = GetGameTimer()
    if (selfNotifyAt[src] or 0) > now then return end
    selfNotifyAt[src] = now + 500
    links.notify(src, 'Crew', msg:sub(1, 120))
end)
AddEventHandler('playerDropped', function() selfNotifyAt[source] = nil end)

lib.callback.register('f_crew:server:radioChannels', function()
    local list = {}
    for _, g in pairs(Gangs) do
        if g.radio then list[#list + 1] = { g.radio, g.name, g.label } end
    end
    return list
end)

-- Wilayah: resource server lain melapor aktivitas pemain (zona dicari dari posisi di server).
-- exports.f_crew:AddTurfActivity(src, 'drugselling' | 'carjacking')
exports('AddTurfActivity', function(src, activity)
    if not ready then return end
    turf.activity(src, activity)
end)

-- Graffiti perang (f_graffiti). Hanya bisa dipanggil resource server.
-- exports.f_crew:GetWarGraffitiZone(src, x, y) -> zoneId?, label?
-- exports.f_crew:GetWarParticipant(zoneId, src) -> gang?
-- exports.f_crew:AddWarGraffitiPoints(zoneId, gang, 1 | -1) -> boolean
exports('GetWarGraffitiZone', function(src, x, y)
    if not ready then return nil end
    return turf.graffitiZone(tonumber(src) or -1, tonumber(x) or 0, tonumber(y) or 0)
end)
exports('GetWarParticipant', function(zoneId, src)
    if not ready then return nil end
    return turf.graffitiParticipant(zoneId, tonumber(src) or -1)
end)
exports('AddWarGraffitiPoints', function(zoneId, gang, sign)
    if not ready then return false end
    return turf.graffitiPoints(zoneId, gang, tonumber(sign) or 1)
end)

-- Apakah pemain online anggota crew bertag 'gang' (bukan 'community'). Dipakai f_police (rampok).
-- exports.f_crew:IsGang(src)
exports('IsGang', function(src)
    local s = Sessions[tonumber(src) or -1]
    local g = s and Gangs[s.gang]
    return g ~= nil and g.tag == 'gang'
end)

-- Admin: reset peringkat antar gang ---------------------------------------------------------

lib.addCommand('resetgang', {
    help = 'Reset peringkat antar gang (app Crew) ke 0',
    restricted = 'group.admin',
}, function(src)
    if not ready then return end
    MySQL.update.await('UPDATE crew_gangs SET total_seconds = 0')
    local now = os.time()
    for _, g in pairs(Gangs) do g.totalSeconds = 0 end
    for _, s in pairs(Sessions) do s.gangSince = now end
    audit(src > 0 and src or nil, 'CrewGangBoardReset', 'Peringkat antar gang direset oleh admin')
    if src > 0 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Crew', description = 'Peringkat antar gang direset.', type = 'success' })
    end
end)

-- Integrasi yang start belakangan / di-restart ------------------------------------------------

AddEventHandler('onResourceStart', function(res)
    if not ready then return end
    if res == 'f_garages' then
        for _, g in pairs(Gangs) do links.syncGarage(g) end
    elseif res == 'pma-voice' then
        for _, g in pairs(Gangs) do links.radioLock(g) end
    elseif res == 'Renewed-Banking' then
        SetTimeout(2000, function()
            for _, g in pairs(Gangs) do links.ensureAccount(g) end
        end)
    end
end)

-- Start ---------------------------------------------------------------------------------------

local function cleanupInactive()
    -- tunggu banking siap supaya sisa kas bisa dikembalikan ke boss
    local deadline = os.time() + 60
    while not links.started('Renewed-Banking') and os.time() < deadline do Wait(1000) end
    Wait(3000)
    local cutoff = os.time() - config.InactiveDays * DAY
    local stale = {}
    for _, g in pairs(Gangs) do
        if g.lastActive < cutoff then stale[#stale + 1] = g end
    end
    for i = 1, #stale do
        local g = stale[i]
        if Gangs[g.name] then disbandGang(g, g.owner, false, 'tidak aktif') end
    end
end

CreateThread(function()
    db.ensureSchema()
    local now = os.time()
    MySQL.update.await('DELETE FROM crew_applications WHERE created_at < ?', { now - APP_TTL })
    MySQL.update.await('DELETE FROM crew_bank_log WHERE created_at < ?', { now - config.BankLogDays * DAY })
    MySQL.update.await('DELETE FROM crew_gangs WHERE name IS NULL')

    local rows = MySQL.query.await('SELECT * FROM crew_gangs') or {}
    local list = {}
    for i = 1, #rows do
        local g = rowToGang(rows[i])
        addToCache(g)
        list[#list + 1] = g
    end
    links.registerGangs(list)

    local counts = MySQL.query.await("SELECT `group` AS gang, COUNT(*) AS total FROM player_groups WHERE type = 'gang' GROUP BY `group`") or {}
    for i = 1, #counts do
        local g = Gangs[counts[i].gang]
        if g then g.members = counts[i].total end
    end
    -- waktu main bekas anggota tidak perlu disimpan
    MySQL.update.await([[
        DELETE pt FROM crew_playtime pt
        LEFT JOIN player_groups pg ON pg.citizenid = pt.citizenid AND pg.`group` = pt.gang AND pg.type = 'gang'
        WHERE pg.citizenid IS NULL
    ]])

    for _, g in pairs(Gangs) do
        links.syncGarage(g)
        links.radioLock(g)
    end

    turf.start({ Gangs = Gangs, Sessions = Sessions, notify = links.notify, audit = audit })
    ready = true
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then sessionStart(src) end
    end
    lib.print.info(('[f_crew] %d gang dimuat'):format(#list))

    cleanupInactive()
end)
