-- Server authority untuk deathscreen:
--   * countdown dihitung di sini (os.time), client cuma menampilkan
--   * saat waktu habis server sendiri yang mengirim player ke kasur rumah sakit (f_ambulancejob
--     CheckIn). Biaya dipotong f_ambulancejob saat player bangun dari kasur.
--   * dispatch / dokter AI / sync divalidasi (harus benar-benar tergeletak) dan punya cooldown.
--     Dokter AI hanya dibayar & dihidupkan dari server.

local L = Config.Locale
local AI = Config.AiDoctor

local DEATH_BAG = 'f_medical:deathState'
local ALIVE = 1

-- Detik menunggu client siap (animasi transisi) sebelum server memasukkan player ke kasur
local BED_READY_TIMEOUT = 10
-- Detik jeda sebelum mencoba lagi kalau semua kasur penuh
local BEDS_FULL_RETRY = 15

-- rumah sakit & kasur dibaca langsung dari config f_ambulancejob supaya tidak dobel
local ambulanceHospitals = {}
do
    local raw = LoadResourceFile('f_ambulancejob', 'config/shared.lua')
    local chunk = raw and load(raw, '@f_ambulancejob/config/shared.lua')
    local ok, cfg = pcall(chunk or error)
    if ok and type(cfg) == 'table' and cfg.locations and cfg.locations.hospitals then
        ambulanceHospitals = cfg.locations.hospitals
    else
        print('^1[f_deathscreen]^0 gagal membaca f_ambulancejob/config/shared.lua, rumah sakit tidak tersedia')
    end
end

---@class DownedEntry
---@field deadline integer os.time() saat player dibawa ke rumah sakit
---@field lastDispatch integer
---@field lastSync integer
---@field respawning boolean sedang dipindah ke rumah sakit
---@field respawnAt integer
---@field bedReady boolean CheckIn sudah dikirim
---@field hospital string? key rumah sakit f_ambulancejob
---@field ai boolean? dokter AI sedang menangani
---@field aiAt integer?
---@field notified table<integer, true> EMS yang dapat blip dari pasien ini
---@field emsAt integer? heartbeat terakhir EMS yang menangani (countdown dijeda)
---@field pausedLeft integer? sisa countdown saat dijeda

---@type table<integer, DownedEntry>
local downed = {}

local function markDowned(src)
    if downed[src] then return end
    downed[src] = {
        deadline     = os.time() + Config.BleedoutTime,
        lastDispatch = 0,
        lastSync     = 0,
        respawning   = false,
        respawnAt    = 0,
        bedReady     = false,
        notified     = {},
    }
end

local function clearDowned(src)
    local d = downed[src]
    if not d then return end
    for ems in pairs(d.notified) do
        TriggerClientEvent('f_deathscreen:client:removeBlip', ems, src)
    end
    downed[src] = nil
end

AddStateBagChangeHandler(DEATH_BAG, nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    if value and value ~= ALIVE then
        markDowned(src)
    else
        clearDowned(src)
    end
end)

AddEventHandler('playerDropped', function()
    clearDowned(source)
end)

-- resource restart di tengah sesi: ambil ulang status dari state bag
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local state = src and Player(src).state[DEATH_BAG]
        if state and state ~= ALIVE then markDowned(src) end
    end
end)

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function remainingOf(d)
    if d.emsAt then return d.pausedLeft end
    return math.max(0, d.deadline - os.time())
end

-- sisa countdown pasien (detik) untuk panel Cek Pasien f_ambulancejob; nil kalau tidak tergeletak
exports('GetRemaining', function(src)
    local d = downed[src]
    return d and remainingOf(d) or nil
end)

-- EMS sedang menangani (panel Cek Pasien terbuka / tindakan berjalan): countdown dijeda seperti
-- dokter AI. f_ambulancejob memanggil ini berulang sebagai heartbeat; kalau heartbeat berhenti
-- (EMS keluar game, crash) countdown lanjut sendiri setelah EMS_HOLD detik.
local EMS_HOLD = 20

local function resumeFromEms(src, d)
    if not d.emsAt then return end
    d.deadline = os.time() + (d.pausedLeft or 0)
    d.emsAt, d.pausedLeft = nil, nil
    TriggerClientEvent('f_deathscreen:client:emsTreating', src, false, remainingOf(d))
end

exports('SetEmsTreating', function(src, active)
    local d = downed[src]
    if not d or d.respawning or d.ai then return end
    if active then
        if not d.emsAt then
            d.pausedLeft = math.max(0, d.deadline - os.time())
            TriggerClientEvent('f_deathscreen:client:emsTreating', src, true, d.pausedLeft)
        end
        d.emsAt = os.time()
    else
        resumeFromEms(src, d)
    end
end)

local function emsOnDuty()
    local count, sources = exports.qbx_core:GetDutyCountType(Config.EmsJobType)
    return count or 0, sources or {}
end

local function formatMoney(n)
    local s = tostring(math.floor(n))
    local k
    repeat s, k = s:gsub('^(%d+)(%d%d%d)', '%1,%2') until k == 0
    return s
end

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or player.PlayerData.citizenid
end

---Kirim email lewat f_phone Mail; fallback ke notifikasi phone kalau player belum punya akun mail
local function sendMail(src, player, subject, lines, from)
    local cid = player.PlayerData.citizenid
    local body = table.concat(lines, '\n')

    local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(cid) end)
    if okA and type(addresses) == 'table' and #addresses > 0 then
        local to = {}
        for i = 1, #addresses do to[i] = addresses[i].email end
        local okS, res = pcall(function()
            return exports['f_phone']:sendMail({ to = to, subject = subject, body = body, from = { name = from, email = '' } })
        end)
        if okS and res and (res.delivered or 0) > 0 then return end
    end

    pcall(function()
        exports['f_phone']:notify(src, { appId = 'mail', app = 'Mail', title = subject, body = lines[4] or subject, time = 'now' })
    end)
end

local function hospitalLabel(key)
    local h = ambulanceHospitals[key]
    return h and h.label or key
end

---@return string? key rumah sakit f_ambulancejob
local function pickHospital(src, player)
    local meta = player.PlayerData.metadata or {}
    if Config.JailHospital and (meta.injail or 0) > 0 and ambulanceHospitals[Config.JailHospital] then
        return Config.JailHospital
    end

    if Config.HospitalMode == 'fixed' and ambulanceHospitals[Config.FixedHospital] then
        return Config.FixedHospital
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local best, bestDist
    for _, key in ipairs(Config.Hospitals) do
        local h = ambulanceHospitals[key]
        if h and h.coords then
            local dist = #(coords - h.coords)
            if not bestDist or dist < bestDist then best, bestDist = key, dist end
        end
    end
    return best
end

-------------------------------------------------------------------------------
-- Countdown habis -> kasur rumah sakit
-------------------------------------------------------------------------------

local function sendToHospital(src, d)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then
        downed[src] = nil
        return
    end

    local key = pickHospital(src, player)
    if not key then
        print(('^1[f_deathscreen]^0 tidak ada rumah sakit valid untuk player %d, cek Config.Hospitals'):format(src))
        d.deadline = os.time() + 30
        return
    end

    d.respawning = true
    d.respawnAt  = os.time()
    d.bedReady   = false
    d.hospital   = key
    -- client memutar transisi dulu, lalu memanggil readyForBed
    TriggerClientEvent('f_deathscreen:client:respawn', src, hospitalLabel(key))
end

local function putInBed(src, d)
    d.bedReady = true
    local called, ok = pcall(function() return exports.f_ambulancejob:CheckIn(0, src, d.hospital) end)
    if not called or not ok then
        -- semua kasur penuh: tunggu sebentar lalu coba lagi
        d.respawning = false
        d.bedReady   = false
        d.deadline   = os.time() + BEDS_FULL_RETRY
        TriggerClientEvent('f_deathscreen:client:bedsFull', src)
    end
end

RegisterNetEvent('f_deathscreen:server:readyForBed', function()
    local src = source
    local d = downed[src]
    if not d or not d.respawning or d.bedReady then return end
    putInBed(src, d)
end)

-------------------------------------------------------------------------------
-- Dokter AI
-------------------------------------------------------------------------------

local function aiRevive(src, d)
    d.ai = nil
    TriggerClientEvent('f_medical:client:playerRevived', src)
end

---@return table response untuk UI
local function callAiDoctor(src, d)
    if d.ai then return { ok = false, reason = 'aibusy' } end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false } end

    local price = math.floor(tonumber(AI.Price) or 0)
    local bank = player.PlayerData.money and player.PlayerData.money.bank or 0
    if bank < price then
        return { ok = false, reason = 'nomoney', price = formatMoney(price) }
    end
    if price > 0 and not player.Functions.RemoveMoney('bank', price, 'ai-doctor') then
        return { ok = false, reason = 'nomoney', price = formatMoney(price) }
    end

    if price > 0 and Config.Society then
        pcall(function() exports['f_banking']:addAccountMoney(Config.Society, price) end)
    end

    local lines = {}
    for i, line in ipairs(L.aiMailBody) do lines[i] = line end
    lines[1] = lines[1]:format(charName(player))
    lines[3] = lines[3]:format(AI.Label)
    lines[4] = lines[4]:format(formatMoney(price))
    lines[7] = lines[7]:format(AI.Label)
    sendMail(src, player, L.aiMailSubject, lines, AI.Label)

    d.ai   = true
    d.aiAt = os.time()
    TriggerClientEvent('f_deathscreen:client:aiDoctor', src, AI.ReviveTime)

    return { ok = true, ai = true, price = formatMoney(price) }
end

RegisterNetEvent('f_deathscreen:server:aiDoctorDone', function()
    local src = source
    local d = downed[src]
    if not d or not d.ai then return end
    -- tidak boleh lebih cepat dari lama CPR (anti trigger manual)
    if os.time() - d.aiAt < AI.ReviveTime then return end
    aiRevive(src, d)
end)

-------------------------------------------------------------------------------
-- Loop utama (1x per detik, hanya kalau ada yang tergeletak)
-------------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(1000)
        if next(downed) then
            local now = os.time()
            for src, d in pairs(downed) do
                if d.emsAt then
                    -- countdown berhenti selama EMS menangani; lanjut kalau heartbeat hilang
                    if now - d.emsAt >= EMS_HOLD then resumeFromEms(src, d) end
                elseif d.ai then
                    -- countdown berhenti selama dokter AI menangani; pengaman kalau client macet
                    if now - d.aiAt >= AI.Timeout then aiRevive(src, d) end
                elseif not d.respawning then
                    if now >= d.deadline then sendToHospital(src, d) end
                elseif not d.bedReady and now - d.respawnAt >= BED_READY_TIMEOUT then
                    putInBed(src, d)
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- Callbacks dari client
-------------------------------------------------------------------------------

lib.callback.register('f_deathscreen:server:getState', function(src)
    local d = downed[src]
    if not d then
        local state = Player(src).state[DEATH_BAG]
        if state and state ~= ALIVE then
            markDowned(src)
            d = downed[src]
        end
    end
    if not d then return { downed = false } end

    return {
        downed    = true,
        remaining = remainingOf(d),
        ems       = (emsOnDuty()),
        ai        = d.ai == true,
        inBed     = d.respawning,
        emsTreating = d.emsAt ~= nil,
    }
end)

---@param street string label lokasi dari client (cuma teks untuk notifikasi, koordinat tetap dari server)
lib.callback.register('f_deathscreen:server:dispatch', function(src, street)
    local d = downed[src]
    if not d or d.respawning then return { ok = false, reason = 'notdown' } end

    local now = os.time()
    local wait = Config.DispatchCooldown - (now - d.lastDispatch)
    if wait > 0 then return { ok = false, reason = 'cooldown', wait = wait } end

    local count, sources = emsOnDuty()

    -- tidak ada EMS: panggil dokter AI (bayar dari bank)
    if AI and AI.Enabled and count <= (AI.MaxEms or 0) then
        local res = callAiDoctor(src, d)
        if res.ok then
            d.lastDispatch = now
            res.ems = count
            res.cooldown = Config.DispatchCooldown
        end
        return res
    end

    d.lastDispatch = now

    street = tostring(street or ''):sub(1, 64):gsub('[<>%c]', '')
    if street == '' then street = 'unknown location' end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local sent = 0

    for i = 1, #sources do
        local ems = sources[i]
        if ems ~= src then
            sent += 1
            d.notified[ems] = true
            pcall(function()
                exports['f_phone']:emergencyAlert(ems, {
                    app   = L.alertApp,
                    appId = 'maps',
                    title = L.alertTitle,
                    body  = L.alertBody:format(street),
                    time  = 'now',
                })
            end)
            TriggerClientEvent('f_deathscreen:client:emsBlip', ems, src, coords)
        end
    end

    return { ok = true, sent = sent, ems = count, cooldown = Config.DispatchCooldown }
end)

lib.callback.register('f_deathscreen:server:sync', function(src)
    local d = downed[src]
    if not d then return { ok = false, reason = 'notdown' } end

    local now = os.time()
    local wait = Config.SyncCooldown - (now - d.lastSync)
    if wait > 0 then return { ok = false, reason = 'cooldown', wait = wait } end
    d.lastSync = now

    return {
        ok        = true,
        remaining = remainingOf(d),
        ems       = (emsOnDuty()),
        cooldown  = Config.SyncCooldown,
    }
end)
