-- Lamaran kerja untuk app Services (HP & tablet).
--
--   Calon   : tombol "Lamar" di tab Companies -> satu pesan singkat. Satu lamaran aktif per job.
--   Boss    : bagian "Lamaran Masuk" di tab Actions -> Terima / Tolak.
--   Terima  : memakai mekanisme job offer yang sudah ada (phone_job_invites, grade 0), jadi tetap
--             bisa diterima walau calon offline; calon menyetujuinya di tab Jobs.
--   Hasil   : calon diberi tahu lewat Mail (tersimpan walau offline); fallback banner kalau dia
--             tidak punya akun Mail tapi sedang online.
-- Semua izin (boss, job, kepemilikan lamaran) dicek di server.

---@type table f_phone config root (configs/config.lua).
local config   = require 'configs.config'
---@type table Job bridge (bridge.server.job): active job, label, isboss.
local job      = require 'bridge.server.job'
---@type table Player bridge (bridge.server.player): citizenid/name/source lookups.
local player   = require 'bridge.server.player'
---@type table Saved-jobs store (server.services.jobstore): job offers + saved jobs.
local jobstore = require 'server.services.jobstore'
---@type table Shared server helpers (server.util).
local util     = require 'server.util'
---@type table Company employees across frameworks (bridge.server.society): boss lookup incl. offline.
local society  = require 'bridge.server.society'

local applications = {}

local SV = config.Services or {}
---@type table<string, table> Company entries by job; only listed companies take applications.
local byJob = {}
for _, c in ipairs(SV.Companies or {}) do byJob[c.job] = c end

local MAX_MESSAGE = 300
local LIMIT = 50

local fail = util.fail

function applications.ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS phone_service_applications (
            id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
            job         VARCHAR(64)  NOT NULL,
            citizenid   VARCHAR(64)  NOT NULL,
            name        VARCHAR(128) NOT NULL DEFAULT '',
            message     VARCHAR(512) NOT NULL DEFAULT '',
            created_at  INT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uq_job_citizen (job, citizenid),
            INDEX idx_job (job)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

---@param jobName string
---@return string
local function labelOf(jobName)
    local e = byJob[jobName]
    return (e and e.label) or job.getLabel(jobName) or jobName
end

---Server id setiap boss online dari `jobName`.
---@param jobName string
---@return integer[]
local function onlineBosses(jobName)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s and job.getName(s) == jobName and job.isBoss(s, jobName, 0) then out[#out + 1] = s end
    end
    return out
end

---Citizenid setiap boss `jobName`, termasuk yang offline (grade dengan isboss di qbx_core).
---@param jobName string
---@return string[]
local function allBossCids(jobName)
    local out = {}
    local ok, def = pcall(function() return exports.qbx_core:GetJob(jobName) end)
    local grades = ok and type(def) == 'table' and def.grades or nil
    if not grades then return out end
    for _, e in ipairs(society.listEmployees(jobName)) do
        local g = grades[e.grade] or grades[tostring(e.grade)]
        if type(g) == 'table' and g.isboss then out[#out + 1] = e.citizenid end
    end
    return out
end

---Semua alamat Mail milik satu citizen.
---@param cid string
---@return string[]
local function mailsOf(cid)
    local ok, accounts = pcall(function() return exports['f_phone']:getMailAddresses(cid) end)
    local out = {}
    if ok and type(accounts) == 'table' then
        for i = 1, #accounts do out[#out + 1] = accounts[i].email end
    end
    return out
end

---Jumlah lamaran menunggu untuk badge Services; hanya boss dari perusahaan terdaftar yang dapat angka.
---@param src integer
---@return integer
function applications.pendingCountFor(src)
    local myJob = job.getName(src)
    if not myJob or not byJob[myJob] or not job.isBoss(src, myJob, 0) then return 0 end
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM phone_service_applications WHERE job = ?', { myJob })) or 0
end

---Perbarui badge Services untuk boss online `jobName`. Lazy require: badges juga me-require modul ini.
---@param jobName string
local function refreshBossBadges(jobName)
    local badges = require 'server.badges.init'
    for _, s in ipairs(onlineBosses(jobName)) do badges.pushApp(s, 'services') end
end

---Kabari calon lewat Mail (semua akun Mail miliknya); banner sebagai fallback kalau tidak ada akun.
---@param cid string
---@param subject string
---@param body string
---@param company string
local function tellCandidate(cid, subject, body, company)
    local to = mailsOf(cid)
    if #to > 0 then
        pcall(function()
            exports['f_phone']:sendMail({ to = to, subject = subject, body = body, from = { name = company } })
        end)
        return
    end
    local src = player.getSourceByIdentifier(cid)
    if src then
        TriggerClientEvent('f_phone:client:notify', src, {
            app = 'services', appId = 'services', title = company, body = subject, time = 'now',
        })
    end
end

---Calon mengirim lamaran ke sebuah perusahaan.
---@param src integer
---@param payload { job?: string, message?: string }
function applications.apply(src, payload)
    payload = type(payload) == 'table' and payload or {}
    local cid = player.getIdentifier(src)
    if not cid then return fail('services.playerNotFound', 'Player not found') end

    local target = type(payload.job) == 'string' and payload.job or ''
    if not byJob[target] then return fail('services.applyUnknownCompany', 'Perusahaan tidak ditemukan') end

    local message = util.limitedString(payload.message, MAX_MESSAGE)
    if not message then return fail('services.applyNeedMessage', 'Tulis pesan lamaranmu dulu') end

    if job.getName(src) == target or jobstore.getSaved(cid)[target] then
        return fail('services.theyAlreadyWorkHere', 'Kamu sudah bekerja di sini')
    end
    if not util.rateLimit(cid, 'services:apply', 60000, 3) then
        return fail('services.applyTooMany', 'Terlalu banyak lamaran, coba lagi sebentar')
    end

    local inserted = MySQL.update.await([[
        INSERT IGNORE INTO phone_service_applications (job, citizenid, name, message, created_at)
        VALUES (?, ?, ?, ?, ?)
    ]], { target, cid, player.getName(src) or cid, message, os.time() })
    if not inserted or inserted == 0 then
        return fail('services.applyAlready', 'Kamu sudah punya lamaran aktif di perusahaan ini')
    end

    local label   = labelOf(target)
    local who     = player.getName(src) or 'seseorang'
    local bosses  = onlineBosses(target)

    -- Mail ke SEMUA boss (online & offline). Mail sendiri memunculkan banner untuk yang online,
    -- jadi banner manual hanya untuk boss online yang tidak punya akun Mail.
    local to, hasMail = {}, {}
    for _, bcid in ipairs(allBossCids(target)) do
        local mails = mailsOf(bcid)
        if #mails > 0 then hasMail[bcid] = true end
        for i = 1, #mails do to[#to + 1] = mails[i] end
    end
    if #to > 0 then
        pcall(function()
            exports['f_phone']:sendMail({
                to = to, from = { name = label },
                subject = ('Lamaran baru - %s'):format(who),
                body = ('Ada lamaran baru untuk %s.\n\nPelamar: %s\nPesan:\n%s\n\nProses di Services → Actions → Lamaran Masuk.'):format(label, who, message),
            })
        end)
    end
    local bannerTo = {}
    for _, s in ipairs(bosses) do
        local bcid = player.getIdentifier(s)
        if not (bcid and hasMail[bcid]) then bannerTo[#bannerTo + 1] = s end
    end
    util.pushMany('f_phone:client:notify', bannerTo, {
        app = 'services', appId = 'services', title = label, time = 'now',
        body = ('Lamaran baru dari %s'):format(who),
    })
    util.pushMany('f_phone:client:services:applications', bosses)
    refreshBossBadges(target)

    return util.ok({ job = target })
end

---Lamaran masuk untuk job aktif pemanggil. Hanya boss.
---@param src integer
function applications.list(src)
    local myJob = job.getName(src)
    if not myJob or not job.isBoss(src, myJob, 0) then
        return fail('services.mustBossDoThat', 'You must be the boss to do that')
    end
    local rows = MySQL.query.await(
        'SELECT id, name, message, created_at FROM phone_service_applications WHERE job = ? ORDER BY created_at DESC LIMIT ?',
        { myJob, LIMIT }) or {}
    local out = {}
    for i = 1, #rows do
        out[i] = { id = rows[i].id, name = rows[i].name, message = rows[i].message, ts = (tonumber(rows[i].created_at) or 0) * 1000 }
    end
    return util.ok({ applications = out })
end

---Mengambil lamaran milik job pemanggil (boss) lalu menghapusnya dari tabel.
---@param src integer
---@param payload { id?: number }
---@return table|nil row, table|nil refusal, string|nil myJob
local function takeOwn(src, payload)
    local myJob = job.getName(src)
    if not myJob or not job.isBoss(src, myJob, 0) then
        return nil, fail('services.mustBossDoThat', 'You must be the boss to do that')
    end
    local id = math.floor(tonumber(type(payload) == 'table' and payload.id or nil) or 0)
    if id <= 0 then return nil, fail('services.applyNotFound', 'Lamaran tidak ditemukan') end
    local row = MySQL.single.await('SELECT id, job, citizenid, name FROM phone_service_applications WHERE id = ? AND job = ?', { id, myJob })
    if not row then return nil, fail('services.applyNotFound', 'Lamaran tidak ditemukan') end
    MySQL.update.await('DELETE FROM phone_service_applications WHERE id = ?', { id })
    -- Semua boss online (termasuk pemanggil) melihat daftar & badge yang sama.
    util.pushMany('f_phone:client:services:applications', onlineBosses(myJob))
    refreshBossBadges(myJob)
    return row, nil, myJob
end

---Boss menerima lamaran: kirim job offer grade 0 (bisa diterima calon kapan pun, termasuk setelah login).
---@param src integer
---@param payload { id?: number }
function applications.accept(src, payload)
    local row, refusal, myJob = takeOwn(src, payload)
    if not row then return refusal end

    local label = labelOf(myJob)
    if not jobstore.getSaved(row.citizenid)[myJob] then
        jobstore.addInvite({
            id        = jobstore.newId(),
            cid       = row.citizenid,
            job       = myJob,
            grade     = 0,
            invitedBy = player.getName(src),
            createdAt = os.time(),
        })
        local tsrc = player.getSourceByIdentifier(row.citizenid)
        if tsrc then TriggerClientEvent('f_phone:client:services:jobsChanged', tsrc, {}) end
    end

    tellCandidate(row.citizenid, ('Lamaran diterima - %s'):format(label),
        ('Halo %s,\n\nLamaranmu di %s DITERIMA. Buka Services → Jobs di HP untuk menerima tawaran kerjanya.\n\nSalam,\n%s')
            :format(row.name, label, player.getName(src) or label),
        label)

    return applications.list(src)
end

---Boss menolak lamaran: dihapus dan calon diberi tahu.
---@param src integer
---@param payload { id?: number }
function applications.reject(src, payload)
    local row, refusal, myJob = takeOwn(src, payload)
    if not row then return refusal end

    local label = labelOf(myJob)
    tellCandidate(row.citizenid, ('Lamaran ditolak - %s'):format(label),
        ('Halo %s,\n\nTerima kasih sudah melamar di %s. Mohon maaf, lamaranmu belum bisa kami terima saat ini.\n\nSalam,\n%s')
            :format(row.name, label, label),
        label)

    return applications.list(src)
end

return applications
