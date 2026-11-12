-- Pajak perusahaan. Pendapatan dicatat lewat event 'f_tax:income' yang dipicu dari
-- AddAccountMoney di f_banking (setoran karyawan job itu sendiri sudah dilewati di sana).
local Bank = 'f_banking'

local Data = {}       -- [job] = { income, count, lastPaid }
local pending = {}    -- pemasukan yang masuk sebelum tabel siap: { job, amount }
local rate = Config.DefaultRate
local loaded = false
local muted = false   -- true saat f_tax sendiri memindahkan uang (refund), jangan dihitung
local paying = {}     -- [job] = true selama proses bayar
local throttle = {}   -- [src] = { [key] = GetGameTimer() berikutnya yang diizinkan }

for _, job in ipairs(Config.Jobs) do
    Data[job] = { income = 0, count = 0 }
end

-- Pajak warga (potongan paycheck dari f_paycheck): hanya jumlah pencairan + total, sudah lunas
-- saat dipotong. Disimpan di f_tax_income dengan key khusus, tidak masuk ke Data perusahaan.
local CITIZEN = '__warga'
local Citizen = { total = 0, count = 0 }

---------------------------------------------------------------- pencatatan

-- Langsung tulis ke database tiap ada pemasukan. Pakai penambahan (bukan timpa nilai),
-- jadi urutan selesainya query async tidak berpengaruh.
local function record(job, amount)
    local d = Data[job]
    d.income = d.income + amount
    d.count = d.count + 1
    MySQL.prepare('INSERT INTO f_tax_income (job, income, tx_count) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE income = income + VALUES(income), tx_count = tx_count + 1',
        { job, amount })
end

AddEventHandler('f_tax:income', function(account, amount)
    if muted or not Data[account] then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    if not loaded then
        pending[#pending + 1] = { account, amount }
        return
    end
    record(account, amount)
end)

---Dipanggil f_paycheck setelah pajak paycheck masuk ke rekening pemerintah
exports('AddCitizenTax', function(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    Citizen.total = Citizen.total + amount
    Citizen.count = Citizen.count + 1
    MySQL.prepare('INSERT INTO f_tax_income (job, income, tx_count) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE income = income + VALUES(income), tx_count = tx_count + 1',
        { CITIZEN, amount })
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_tax_income (
        job VARCHAR(50) NOT NULL PRIMARY KEY,
        income BIGINT NOT NULL DEFAULT 0,
        tx_count INT NOT NULL DEFAULT 0
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_tax_history (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        job VARCHAR(50) NOT NULL,
        amount BIGINT NOT NULL,
        income BIGINT NOT NULL,
        tx_count INT NOT NULL,
        rate DECIMAL(5,1) NOT NULL,
        paid_by VARCHAR(100) NULL,
        paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_job (job, id)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_tax_settings (
        k VARCHAR(50) NOT NULL PRIMARY KEY,
        v VARCHAR(255) NOT NULL
    )]])

    for _, r in ipairs(MySQL.query.await('SELECT job, income, tx_count FROM f_tax_income') or {}) do
        local d = Data[r.job]
        if d then
            d.income = tonumber(r.income) or 0
            d.count = tonumber(r.tx_count) or 0
        elseif r.job == CITIZEN then
            Citizen.total = tonumber(r.income) or 0
            Citizen.count = tonumber(r.tx_count) or 0
        end
    end
    for _, r in ipairs(MySQL.query.await("SELECT job, DATE_FORMAT(MAX(paid_at), '%d/%m/%Y %H:%i') AS d FROM f_tax_history GROUP BY job") or {}) do
        if Data[r.job] then Data[r.job].lastPaid = r.d end
    end
    local r = tonumber(MySQL.scalar.await('SELECT v FROM f_tax_settings WHERE k = ?', { 'rate' }))
    if r then rate = r end

    loaded = true
    for _, p in ipairs(pending) do record(p[1], p[2]) end
    pending = nil
end)

---------------------------------------------------------------- akses

local function getPlayer(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData
end

local function jobDef(job)
    local ok, def = pcall(function() return exports.qbx_core:GetJob(job) end)
    return ok and def or nil
end

local function jobLabel(job)
    local def = jobDef(job)
    return def and def.label or job
end

-- Grade minimum untuk masuk N grade tertinggi job
local function minTopGrade(job, n)
    local def = jobDef(job)
    local levels = {}
    for lvl in pairs(def and def.grades or {}) do levels[#levels + 1] = tonumber(lvl) end
    if #levels == 0 then return math.huge end
    table.sort(levels, function(a, b) return a > b end)
    return levels[math.min(n, #levels)]
end

local function gradeOf(pd)
    local g = pd.job.grade
    return tonumber(type(g) == 'table' and g.level or g) or 0
end

local function isGov(pd)
    return pd and pd.job and pd.job.name == Config.Government and pd.job.onduty == true
end

local function canSetRate(pd)
    return isGov(pd) and gradeOf(pd) >= minTopGrade(Config.Government, Config.RateTopGrades)
end

-- Job yang boleh dibayar pajaknya oleh player ini (nil = tidak punya akses)
local function payJob(pd)
    local job = pd and pd.job and pd.job.name
    if not job or not Data[job] then return end
    if gradeOf(pd) < minTopGrade(job, Config.PayTopGrades) then return end
    return job
end

local function playerName(pd)
    local c = pd.charinfo or {}
    local n = ('%s %s'):format(c.firstname or '', c.lastname or ''):match('^%s*(.-)%s*$')
    return n ~= '' and n or pd.citizenid
end

local function limited(src, key)
    local t = throttle[src]
    if not t then t = {}; throttle[src] = t end
    local now = GetGameTimer()
    if (t[key] or 0) > now then return true end
    t[key] = now + 700
    return false
end

AddEventHandler('playerDropped', function() throttle[source] = nil end)

---------------------------------------------------------------- data menu

local function taxOf(income)
    return math.floor(income * rate / 100 + 1e-9)
end

local function balanceOf(job)
    local ok, bal = pcall(function() return exports[Bank]:getAccountMoney(job) end)
    return ok and tonumber(bal) or nil
end

local function jobRow(job)
    local d = Data[job]
    return {
        name = job,
        label = jobLabel(job),
        count = d.count,
        income = d.income,
        tax = taxOf(d.income),
        balance = balanceOf(job),
        lastPaid = d.lastPaid,
    }
end

---@return table|nil payload, string|nil err
local function build(src, mode)
    if not loaded then return nil, 'Data pajak sedang dimuat, coba lagi sebentar.' end
    local pd = getPlayer(src)
    if not pd then return nil, 'Data player tidak ditemukan.' end

    if mode == 'audit' then
        if not pd.job or pd.job.name ~= Config.Government then return nil, 'Hanya untuk pegawai pemerintah.' end
        if not pd.job.onduty then return nil, 'Kamu harus on duty.' end
        local jobs = {}
        for _, job in ipairs(Config.Jobs) do jobs[#jobs + 1] = jobRow(job) end
        return { mode = 'audit', rate = rate, canRate = canSetRate(pd), minRate = Config.MinRate, maxRate = Config.MaxRate, jobs = jobs,
            citizen = { total = Citizen.total, count = Citizen.count } }
    elseif mode == 'pay' then
        local job = payJob(pd)
        if not job then return nil, 'Hanya pimpinan perusahaan yang terdaftar pajak yang bisa mengakses.' end
        return { mode = 'pay', rate = rate, jobs = { jobRow(job) } }
    end
    return nil, 'Mode tidak valid.'
end

local function reply(src, mode)
    local data, err = build(src, mode)
    return data or { err = err }
end

lib.callback.register('f_tax:open', function(src, mode)
    if limited(src, 'open') then return { err = 'Terlalu cepat.', soft = true } end
    return reply(src, mode)
end)

lib.callback.register('f_tax:history', function(src, job)
    if limited(src, 'history') then return false end
    if type(job) ~= 'string' or not Data[job] then return false end
    local pd = getPlayer(src)
    if not (isGov(pd) or payJob(pd) == job) then return false end
    return MySQL.query.await(("SELECT amount, DATE_FORMAT(paid_at, '%%d/%%m/%%Y %%H:%%i') AS date FROM f_tax_history WHERE job = ? ORDER BY id DESC LIMIT %d")
        :format(Config.HistoryLimit), { job }) or {}
end)

lib.callback.register('f_tax:setRate', function(src, value)
    if limited(src, 'rate') then return { ok = false, msg = 'Terlalu cepat.' } end
    local pd = getPlayer(src)
    if not canSetRate(pd) then return { ok = false, msg = 'Kamu tidak punya wewenang mengubah tarif pajak.' } end
    value = tonumber(value)
    if not value or value ~= value or value < Config.MinRate or value > Config.MaxRate then
        return { ok = false, msg = ('Tarif harus %s - %s%%.'):format(Config.MinRate, Config.MaxRate) }
    end
    rate = math.floor(value * 10 + 0.5) / 10
    MySQL.prepare('INSERT INTO f_tax_settings (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)', { 'rate', tostring(rate) })
    print(('^3[f_tax]^0 %s (%s) mengubah tarif pajak menjadi %s%%'):format(playerName(pd), pd.citizenid, rate))
    return { ok = true, msg = ('Tarif pajak diubah menjadi %s%%.'):format(rate), data = reply(src, 'audit') }
end)

lib.callback.register('f_tax:pay', function(src)
    if limited(src, 'pay') then return { ok = false, msg = 'Terlalu cepat.' } end
    if not loaded then return { ok = false, msg = 'Data pajak sedang dimuat.' } end
    local pd = getPlayer(src)
    local job = payJob(pd)
    if not job then return { ok = false, msg = 'Kamu tidak punya akses membayar pajak.' } end
    if paying[job] then return { ok = false, msg = 'Pembayaran sedang diproses.' } end

    local d = Data[job]
    local income, count, tax, curRate = d.income, d.count, taxOf(d.income), rate
    if tax <= 0 then return { ok = false, msg = 'Tidak ada pajak yang harus dibayar.' } end

    local bal = balanceOf(job)
    if not bal then return { ok = false, msg = 'Rekening organisasi tidak ditemukan.' } end
    if bal < tax then
        return { ok = false, msg = ('Saldo rekening organisasi kurang (Rp %d / Rp %d).'):format(math.floor(bal), tax), data = reply(src, 'pay') }
    end
    if not balanceOf(Config.GovAccount) then return { ok = false, msg = 'Rekening pemerintah tidak ditemukan.' } end

    paying[job] = true
    local removed = exports[Bank]:removeAccountMoney(job, tax)
    if not removed then
        paying[job] = nil
        return { ok = false, msg = 'Gagal memotong saldo rekening organisasi.', data = reply(src, 'pay') }
    end

    muted = true
    local added = exports[Bank]:addAccountMoney(Config.GovAccount, tax)
    if not added then exports[Bank]:addAccountMoney(job, tax) end -- refund
    muted = false
    if not added then
        paying[job] = nil
        return { ok = false, msg = 'Gagal mengirim pajak ke rekening pemerintah. Saldo dikembalikan.' }
    end

    local label, govLabel = jobLabel(job), jobLabel(Config.Government)
    local note = ('Pembayaran pajak %s (%s%%)'):format(label, curRate)
    pcall(function()
        local t = exports[Bank]:handleTransaction(job, 'Pajak Kota', tax, note, label, govLabel, 'withdraw')
        exports[Bank]:handleTransaction(Config.GovAccount, 'Pajak Kota', tax, note, label, govLabel, 'deposit', t and t.trans_id)
    end)

    -- Kurangi sebesar snapshot, bukan set 0, agar pemasukan baru tidak ikut terhapus
    d.income = math.max(0, d.income - income)
    d.count = math.max(0, d.count - count)
    d.lastPaid = os.date('%d/%m/%Y %H:%M')
    MySQL.prepare('UPDATE f_tax_income SET income = GREATEST(income - ?, 0), tx_count = GREATEST(tx_count - ?, 0) WHERE job = ?',
        { income, count, job })
    MySQL.insert('INSERT INTO f_tax_history (job, amount, income, tx_count, rate, paid_by) VALUES (?, ?, ?, ?, ?, ?)',
        { job, tax, income, count, curRate, playerName(pd) })
    paying[job] = nil

    print(('^2[f_tax]^0 %s membayar pajak %s: Rp %d (%d transaksi, pendapatan Rp %d, %s%%)'):format(playerName(pd), job, tax, count, income, curRate))
    return { ok = true, msg = ('Pajak Rp %d berhasil dibayar ke %s.'):format(tax, govLabel), data = reply(src, 'pay') }
end)
