-- Leaderboard waktu duty untuk tab Leaderboard di app Services (HP & tablet).
--
-- Ringan: tidak ada loop/timer. Sesi duty dicatat di memori saat pemain ON duty dan baru ditulis ke
-- database saat sesi berakhir (off duty, ganti job, logout, disconnect). Saat leaderboard dibuka,
-- sesi yang masih berjalan ikut dihitung langsung. 1 poin = 1 menit on duty.
-- Reset hanya boss (isboss) dan hanya untuk job-nya sendiri; semuanya dicek di server.

---@type table Job bridge (bridge.server.job): active job, duty state, isboss.
local job    = require 'bridge.server.job'
---@type table Player bridge (bridge.server.player): citizenid / name lookups.
local player = require 'bridge.server.player'
---@type table Shared server helpers (server.util): envelopes, batched push.
local util   = require 'server.util'

local leaderboard = {}

---@type integer Baris yang dikirim ke UI.
local LIMIT = 50
---@type table<string, boolean> Job yang tidak punya leaderboard.
local NO_BOARD = { unemployed = true }

---@type table<integer, { cid: string, job: string, name: string, since: integer }> Sesi duty aktif per source.
local sessions = {}

function leaderboard.ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS phone_service_duty (
            job        VARCHAR(64)  NOT NULL,
            citizenid  VARCHAR(64)  NOT NULL,
            name       VARCHAR(128) NOT NULL DEFAULT '',
            seconds    INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (job, citizenid),
            INDEX idx_job_seconds (job, seconds)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

---Menutup sesi duty `src` (kalau ada) dan menambahkan durasinya ke database.
---@param src integer
local function stop(src)
    local s = sessions[src]
    if not s then return end
    sessions[src] = nil
    local secs = os.time() - s.since
    if secs < 1 then return end
    MySQL.prepare([[
        INSERT INTO phone_service_duty (job, citizenid, name, seconds) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds), name = VALUES(name)
    ]], { s.job, s.cid, s.name, secs })
end

---Membuka sesi duty `src` kalau pemain sedang on duty di job yang punya leaderboard.
---@param src integer
local function start(src)
    if sessions[src] then return end
    local jobName = job.getName(src)
    if not jobName or NO_BOARD[jobName] then return end
    if job.getDuty(src) ~= true then return end
    local cid = player.getIdentifier(src)
    if not cid then return end
    sessions[src] = { cid = cid, job = jobName, name = player.getName(src) or cid, since = os.time() }
end

---Sinkronkan sesi dengan status duty/job terbaru pemain.
---@param src integer
local function resync(src)
    stop(src)
    start(src)
end

-- Framework hooks (qb/qbx). Semua sumber perubahan duty & job lewat sini: kantor, HP, /duty, setjob.
AddEventHandler('QBCore:Server:PlayerLoaded', function(pl)
    local src = pl and pl.PlayerData and pl.PlayerData.source
    if src then SetTimeout(1000, function() start(src) end) end
end)
AddEventHandler('QBCore:Server:SetDuty', function(src) if src then resync(src) end end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src) if src then resync(src) end end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) if src then stop(src) end end)
AddEventHandler('playerDropped', function() stop(source) end)

-- Restart f_phone: pemain yang sudah on duty langsung dilacak lagi; sesi yang berjalan disimpan saat stop.
CreateThread(function()
    Wait(2000)
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s then start(s) end
    end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(sessions) do stop(src) end
end)

---Leaderboard job aktif pemanggil: waktu duty tersimpan + sesi yang sedang berjalan, terbesar di atas.
---@param src integer
function leaderboard.list(src)
    local myJob = job.getName(src)
    if not myJob or NO_BOARD[myJob] then return util.fail('services.reNotJob', "You're not in a job") end
    local cid = player.getIdentifier(src)

    local byCid, rows = {}, {}
    local stored = MySQL.query.await(
        'SELECT citizenid, name, seconds FROM phone_service_duty WHERE job = ? ORDER BY seconds DESC LIMIT ?',
        { myJob, LIMIT }) or {}
    for i = 1, #stored do
        local r = { citizenid = stored[i].citizenid, name = stored[i].name, seconds = tonumber(stored[i].seconds) or 0, onDuty = false }
        byCid[r.citizenid] = r
        rows[#rows + 1] = r
    end

    local now = os.time()
    for _, s in pairs(sessions) do
        if s.job == myJob then
            local r = byCid[s.cid]
            if not r then
                r = { citizenid = s.cid, name = s.name, seconds = 0 }
                byCid[s.cid] = r
                rows[#rows + 1] = r
            end
            r.seconds = r.seconds + (now - s.since)
            r.onDuty = true
        end
    end

    table.sort(rows, function(a, b) return a.seconds > b.seconds end)
    local out = {}
    for i = 1, math.min(#rows, LIMIT) do
        local r = rows[i]
        out[i] = {
            rank    = i,
            name    = r.name ~= '' and r.name or r.citizenid,
            seconds = r.seconds,
            points  = r.seconds // 60,
            onDuty  = r.onDuty == true,
            me      = r.citizenid == cid,
        }
    end

    return util.ok({
        job    = myJob,
        label  = job.getLabel(myJob) or myJob,
        isBoss = job.isBoss(src, myJob, 0) == true,
        rows   = out,
    })
end

---Reset leaderboard job pemanggil ke 0. Hanya boss.
---@param src integer
function leaderboard.reset(src)
    local myJob = job.getName(src)
    if not myJob or NO_BOARD[myJob] then return util.fail('services.reNotJob', "You're not in a job") end
    if job.isBoss(src, myJob, 0) ~= true then
        return util.fail('services.mustBossDoThat', 'You must be the boss to do that')
    end

    MySQL.update.await('DELETE FROM phone_service_duty WHERE job = ?', { myJob })
    -- Sesi yang sedang berjalan mulai dihitung dari 0 lagi.
    local now, members = os.time(), {}
    for _, s in pairs(sessions) do
        if s.job == myJob then s.since = now end
    end
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s and job.getName(s) == myJob then members[#members + 1] = s end
    end
    util.pushMany('f_phone:client:services:leaderboard', members)

    return leaderboard.list(src)
end

return leaderboard
