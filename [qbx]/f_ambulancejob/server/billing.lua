-- Tagihan EMS (tabel ems_bills). Satu tabel untuk semua jenis tagihan:
--   kind    'tindakan' (Cek Pasien) · 'operasi' (meja operasi) · 'apotek' (pesanan obat)
--   channel 'direct' (invoice langsung ke HP pasien) · 'kasir' (dibayar di Kasir rumah sakit)
--   status  'unpaid' → 'paid' (cash/transfer) / 'collected' (tagih paksa) / 'cancelled'
--   approval 1 = sudah dibayar di kasir saat ada EMS bertugas, menunggu petugas menyerahkan/menyetujui
--   deliver 'none' (tanpa obat) · 'pending' (obat belum diterima pasien) · 'done'
-- Layanan Cek Pasien dicatat server (Billing.Record) dan dipilih EMS di tab Tagihan (boleh diskon).
-- Tagih paksa memotong BANK pasien (online/offline, boleh minus) + email; tidak ada potong otomatis.

local cfg = require 'config.treatment'
local serverCfg = require 'config.server'
local pharmacy = require 'config.pharmacy'
local BILL = serverCfg.emsBill

Billing = {}

---@class PendingService
---@field id integer
---@field code string
---@field label string
---@field price integer harga saat dicatat (batas atas diskon)
---@field at integer
---@field ems string citizenid EMS
---@field emsName string

---@type table<string, PendingService[]> layanan belum ditagih per citizenid pasien (memori)
local pending = {}
local seq = 0

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ems_bills` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `patient_name` VARCHAR(100) NOT NULL DEFAULT '',
            `items` LONGTEXT NOT NULL,
            `total` BIGINT NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'unpaid',
            `invoice_id` VARCHAR(64) NULL,
            `created_by` VARCHAR(50) NOT NULL,
            `created_by_name` VARCHAR(100) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL,
            `settled_at` INT NULL,
            `settled_by` VARCHAR(100) NULL,
            PRIMARY KEY (`id`),
            INDEX `status_idx` (`status`),
            INDEX `citizen_idx` (`citizenid`),
            INDEX `invoice_idx` (`invoice_id`)
        )
    ]])
    -- kolom kasir (ditambahkan ke tabel lama kalau belum ada)
    local have = {}
    for _, r in ipairs(MySQL.query.await([[
        SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ems_bills'
    ]]) or {}) do have[r.c] = true end
    local add = {
        kind = "VARCHAR(10) NOT NULL DEFAULT 'tindakan'",
        channel = "VARCHAR(10) NOT NULL DEFAULT 'direct'",
        method = 'VARCHAR(10) NULL',
        approval = 'TINYINT NOT NULL DEFAULT 0',
        deliver = "VARCHAR(10) NOT NULL DEFAULT 'none'",
    }
    for col, def in pairs(add) do
        if not have[col] then MySQL.query.await(('ALTER TABLE ems_bills ADD COLUMN `%s` %s'):format(col, def)) end
    end
end)

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function isEms(src, needDuty)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or job.type ~= 'ems' then return false end
    if needDuty and not job.onduty then return false end
    return true, player
end

local function isNear(src, target, dist)
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= dist
end

local function formatMoney(n)
    local s = tostring(math.floor(n))
    local k
    repeat s, k = s:gsub('^(%d+)(%d%d%d)', '%1.%2') until k == 0
    return s
end
Billing.FormatMoney = formatMoney

local function notify(src, msg, typ) exports.qbx_core:Notify(src, msg, typ or 'inform', 7000) end

local function sourceOf(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil
end
Billing.SourceOf = sourceOf

function Billing.EmsOnDuty()
    return (exports.qbx_core:GetDutyCountType('ems')) or 0
end

---------------------------------------------------------------------------
-- Layanan Cek Pasien (memori)
---------------------------------------------------------------------------

---@param emsSrc number
---@param patientSrc number
---@param code string kunci di config.treatment billing
function Billing.Record(emsSrc, patientSrc, code)
    local def = cfg.billing[code]
    local patient = exports.qbx_core:GetPlayer(patientSrc)
    local ems = exports.qbx_core:GetPlayer(emsSrc)
    if not def or not patient or not ems then return end

    local cid = patient.PlayerData.citizenid
    seq += 1
    pending[cid] = pending[cid] or {}
    pending[cid][#pending[cid] + 1] = {
        id = seq,
        code = code,
        label = def.label,
        price = Prices.Get('svc:' .. code),
        at = os.time(),
        ems = ems.PlayerData.citizenid,
        emsName = charName(ems),
    }
end

---@param cid string
---@return integer jumlah layanan belum ditagih (badge tab Tagihan)
function Billing.PendingCount(cid)
    return #(pending[cid] or {})
end

---------------------------------------------------------------------------
-- Tagihan (database)
---------------------------------------------------------------------------

local function decode(row)
    if not row then return end
    local ok, items = pcall(json.decode, row.items)
    row.items = ok and items or {}
    row.approval = tonumber(row.approval) == 1
    return row
end

function Billing.Get(id)
    return decode(MySQL.single.await('SELECT * FROM ems_bills WHERE id = ? LIMIT 1', { tonumber(id) or 0 }))
end

function Billing.Query(where, params)
    local rows = MySQL.query.await('SELECT * FROM ems_bills WHERE ' .. where, params or {}) or {}
    for i = 1, #rows do decode(rows[i]) end
    return rows
end

---@param o { cid: string, name: string, items: table, total: integer, kind: string, channel: string, by: string, byName: string, invoice: string?, deliver: string? }
---@return integer id
function Billing.Create(o)
    return MySQL.insert.await([[
        INSERT INTO ems_bills (citizenid, patient_name, items, total, status, invoice_id, created_by, created_by_name, created_at, kind, channel, deliver)
        VALUES (?, ?, ?, ?, 'unpaid', ?, ?, ?, ?, ?, ?, ?)
    ]], { o.cid, o.name, json.encode(o.items), o.total, o.invoice, o.by, o.byName, os.time(), o.kind, o.channel, o.deliver or 'none' })
end

---Invoice f_phone (Bank > Invoices) atas nama job ambulance. Ditulis langsung ke tabel f_phone
---supaya kita memegang id-nya (dicocokkan saat dibayar, dibatalkan saat ditagih paksa / batal).
---@param sender { cid: string, name: string, number: string? }
---@return string? invoiceId
function Billing.CreateInvoice(patientSrc, patient, total, note, sender)
    if GetResourceState('f_phone') ~= 'started' then return end
    local chars, t = 'abcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 16 do
        local n = math.random(1, #chars)
        t[i] = chars:sub(n, n)
    end
    local id = 'bill_' .. table.concat(t)

    local okP, patientNumber = pcall(function() return exports['f_phone']:getPhoneNumber(patientSrc) end)
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)
    ]], {
        id, BILL.job, BILL.label, sender.cid, sender.name, sender.number,
        patient.PlayerData.citizenid, charName(patient), okP and patientNumber or nil,
        total, note:sub(1, 140), os.time(),
    })
    if not ok then return end

    pcall(function()
        exports['f_phone']:notify(patientSrc, {
            appId = 'bank', app = 'Bank', title = BILL.label,
            body = ('Tagihan Rp %s. Buka Bank > Invoices untuk membayar.'):format(formatMoney(total)),
            time = 'now',
        })
    end)
    TriggerClientEvent('f_phone:client:services:invoices', patientSrc, {})
    return id
end

---Batalkan invoice HP yang masih pending. false kalau sudah dibayar / tidak ada.
local function cancelInvoice(id, cid)
    if not id then return false end
    local affected = MySQL.update.await("UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { id })
    local src = sourceOf(cid)
    if src then TriggerClientEvent('f_phone:client:services:invoices', src, {}) end
    return (tonumber(affected) or 0) > 0
end

local function invoiceStatus(id)
    return id and MySQL.scalar.await('SELECT status FROM phone_service_invoices WHERE id = ?', { id }) or nil
end
Billing.InvoiceStatus = invoiceStatus

---Total berat obat tagihan apotek (untuk cek tas penuh).
local function itemsWeight(items)
    local weight = 0
    for _, l in ipairs(items) do
        if l.item then
            local def = exports.ox_inventory:Items(l.item)
            weight += (def and def.weight or 0) * (l.qty or 1)
        end
    end
    return weight
end

---Serahkan obat tagihan ke tas pasien. Mengembalikan error (string) atau nil.
function Billing.GiveItems(target, bill)
    if bill.deliver ~= 'pending' then return end
    if not exports.ox_inventory:CanCarryWeight(target, itemsWeight(bill.items)) then
        return 'Tas pasien penuh, obat belum terkirim. Kosongkan tas dulu.'
    end
    local affected = MySQL.update.await("UPDATE ems_bills SET deliver = 'done', approval = 0 WHERE id = ? AND deliver = 'pending'", { bill.id })
    if (tonumber(affected) or 0) == 0 then return 'Obat tagihan ini sudah diserahkan' end
    for _, l in ipairs(bill.items) do
        if l.item and (l.qty or 0) > 0 then exports.ox_inventory:AddItem(target, l.item, l.qty) end
    end
    bill.deliver = 'done'
end

---Setelah lunas: ada EMS bertugas -> masuk daftar Approval kasir; tidak ada -> obat langsung ke tas.
local function afterPaid(bill)
    local src = sourceOf(bill.citizenid)
    if bill.channel == 'kasir' and Billing.EmsOnDuty() > 0 then
        MySQL.update.await('UPDATE ems_bills SET approval = 1 WHERE id = ?', { bill.id })
        if src then notify(src, ('Tagihan #%d lunas. Temui petugas EMS di kasir untuk %s.'):format(
            bill.id, bill.deliver == 'pending' and 'menerima obat' or 'konfirmasi'), 'success') end
        return
    end
    if bill.deliver ~= 'pending' then
        if src then notify(src, ('Tagihan #%d lunas. Terima kasih.'):format(bill.id), 'success') end
        return
    end
    local err = src and Billing.GiveItems(src, bill) or 'offline'
    if not src then return end
    if err then
        notify(src, ('Tagihan #%d lunas, tapi tas kamu penuh. Kosongkan tas lalu tekan Ambil Obat di kasir.'):format(bill.id), 'error')
    else
        notify(src, ('Tagihan #%d lunas. Obat sudah masuk tas kamu.'):format(bill.id), 'success')
    end
end

---Tandai lunas (atomik). method 'cash' / 'transfer'.
---@return boolean
function Billing.MarkPaid(bill, method, by)
    local affected = MySQL.update.await([[
        UPDATE ems_bills SET status = 'paid', method = ?, settled_at = ?, settled_by = ? WHERE id = ? AND status = 'unpaid'
    ]], { method, os.time(), by, bill.id })
    if (tonumber(affected) or 0) == 0 then return false end
    bill.status, bill.method = 'paid', method
    afterPaid(bill)
    return true
end

---Batalkan tagihan belum bayar. Pesanan apotek: stok kembali ke gudang.
---@return string? error
function Billing.Cancel(bill, by)
    if bill.status ~= 'unpaid' then return 'Tagihan ini sudah selesai' end
    if bill.invoice_id and not cancelInvoice(bill.invoice_id, bill.citizenid) and invoiceStatus(bill.invoice_id) == 'paid' then
        Billing.MarkPaid(bill, 'transfer', 'HP')
        return 'Pasien baru saja membayar lewat HP'
    end
    local affected = MySQL.update.await([[
        UPDATE ems_bills SET status = 'cancelled', settled_at = ?, settled_by = ? WHERE id = ? AND status = 'unpaid'
    ]], { os.time(), by, bill.id })
    if (tonumber(affected) or 0) == 0 then return 'Tagihan ini sudah selesai' end
    if bill.kind == 'apotek' then
        for _, l in ipairs(bill.items) do
            if l.item and (l.qty or 0) > 0 then Stock.Add(l.item, l.qty) end
        end
    end
    bill.status = 'cancelled'
end

local function sendCollectMail(cid, name, billId, total, items)
    if GetResourceState('f_phone') ~= 'started' then return end
    local lines = {}
    for i, item in ipairs(items or {}) do
        lines[i] = ('- %s%s: Rp %s'):format(item.qty and (item.qty .. '× ') or '', item.label, formatMoney(item.price * (item.qty or 1)))
    end
    local body = BILL.collectMail.body:format(name, billId, formatMoney(total), table.concat(lines, '\n'))

    local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(cid) end)
    if okA and type(addresses) == 'table' and #addresses > 0 then
        local to = {}
        for i = 1, #addresses do to[i] = addresses[i].email end
        local okS, res = pcall(function()
            return exports['f_phone']:sendMail({ to = to, subject = BILL.collectMail.subject, body = body, from = { name = BILL.label, email = '' } })
        end)
        if okS and res and (res.delivered or 0) > 0 then return end
    end
    local src = sourceOf(cid)
    if src then
        pcall(function()
            exports['f_phone']:notify(src, { appId = 'mail', app = 'Mail', title = BILL.collectMail.subject,
                body = ('Tagihan EMS #%s Rp %s ditarik dari bank'):format(billId, formatMoney(total)), time = 'now' })
        end)
    end
end

---Tagih paksa: tarik dari BANK pasien (online / offline), boleh sampai minus, lalu email.
---Pesanan apotek tidak bisa ditagih paksa (batal otomatis kalau tidak dibayar).
---@return string? error
function Billing.ForceCollect(bill, byName)
    if bill.status ~= 'unpaid' then return 'Tagihan ini sudah selesai' end
    if bill.kind == 'apotek' then return 'Pesanan apotek tidak bisa ditagih paksa' end

    -- 1. kunci invoice HP supaya pasien tidak bisa membayar bersamaan (double charge)
    local locked = true
    if bill.invoice_id and not cancelInvoice(bill.invoice_id, bill.citizenid) then
        if invoiceStatus(bill.invoice_id) == 'paid' then
            Billing.MarkPaid(bill, 'transfer', 'HP')
            return 'Pasien sudah membayar lewat HP'
        end
        locked = false -- invoice hilang / dibatalkan manual: tetap boleh ditarik
    end
    local function unlock()
        if bill.invoice_id and locked then
            MySQL.update.await("UPDATE phone_service_invoices SET status = 'pending' WHERE id = ? AND status = 'cancelled'", { bill.invoice_id })
        end
    end

    -- 2. tandai, potong (bank boleh minus), setor
    local affected = MySQL.update.await([[
        UPDATE ems_bills SET status = 'collected', method = 'paksa', settled_at = ?, settled_by = ? WHERE id = ? AND status = 'unpaid'
    ]], { os.time(), byName, bill.id })
    if (tonumber(affected) or 0) == 0 then
        unlock()
        return 'Tagihan ini sudah selesai'
    end
    if not exports.qbx_core:RemoveMoney(bill.citizenid, 'bank', bill.total, ('ems-bill-%d'):format(bill.id)) then
        MySQL.update.await("UPDATE ems_bills SET status = 'unpaid', method = NULL, settled_at = NULL, settled_by = NULL WHERE id = ?", { bill.id })
        unlock()
        return 'Gagal memotong saldo bank pasien'
    end
    serverCfg.depositSociety(BILL.job, bill.total)

    local src = sourceOf(bill.citizenid)
    if src then
        TriggerClientEvent('f_phone:client:services:invoices', src, {})
        notify(src, ('Tagihan EMS #%d Rp %s ditarik dari rekening bank kamu.'):format(bill.id, formatMoney(bill.total)), 'error')
    end
    sendCollectMail(bill.citizenid, bill.patient_name, bill.id, bill.total, bill.items)
    bill.status = 'collected'
end

-- dibayar lewat HP (Bank > Invoices): f_phone sudah memindahkan uang ke rekening organisasi
AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' or data.job ~= BILL.job or not data.id then return end
    local rows = Billing.Query("invoice_id = ? AND status = 'unpaid' LIMIT 1", { data.id })
    if rows[1] then Billing.MarkPaid(rows[1], 'transfer', 'HP') end
end)

-- invoice transfer yang terlewat event (mis. server restart): sinkron berkala
CreateThread(function()
    while true do
        Wait(60000)
        for _, bill in ipairs(Billing.Query("status = 'unpaid' AND invoice_id IS NOT NULL ORDER BY id DESC LIMIT 50")) do
            if invoiceStatus(bill.invoice_id) == 'paid' then Billing.MarkPaid(bill, 'transfer', 'HP') end
        end
    end
end)

---------------------------------------------------------------------------
-- Tab Tagihan di panel Cek Pasien
---------------------------------------------------------------------------

local function unpaidOf(cid)
    return MySQL.query.await(
        "SELECT id, total, created_at FROM ems_bills WHERE citizenid = ? AND status = 'unpaid' ORDER BY id DESC LIMIT 10", { cid }) or {}
end

local function billingData(cid)
    return { pending = pending[cid] or {}, unpaid = unpaidOf(cid), transfer = GetResourceState('f_phone') == 'started' }
end

---@return string? errorMessage, table? patient
local function checkPanel(src, target)
    target = tonumber(target)
    local patient = target and exports.qbx_core:GetPlayer(target)
    if not patient then return 'Pasien tidak ditemukan' end
    if not isEms(src, true) then return 'Hanya EMS yang sedang bertugas' end
    if not isNear(src, target, cfg.closeDistance) then return 'Pasien terlalu jauh' end
    return nil, patient
end

lib.callback.register('f_ambulancejob:server:billingGet', function(src, target)
    local err, patient = checkPanel(src, target)
    if err then return { error = err } end
    return billingData(patient.PlayerData.citizenid)
end)

lib.callback.register('f_ambulancejob:server:billingDiscard', function(src, target, id)
    local err, patient = checkPanel(src, target)
    if err then return { error = err } end
    local list = pending[patient.PlayerData.citizenid] or {}
    for i = #list, 1, -1 do
        if list[i].id == tonumber(id) then table.remove(list, i) end
    end
    return billingData(patient.PlayerData.citizenid)
end)

---@param lines { id: integer, price: number }[] layanan dipilih + harga (boleh diskon)
---@param mode 'direct'|'kasir' Bayar Langsung (invoice HP) atau Bayar di Kasir
lib.callback.register('f_ambulancejob:server:billingSend', function(src, target, lines, mode)
    local err, patient = checkPanel(src, target)
    if err then return { error = err } end
    if mode ~= 'direct' and mode ~= 'kasir' then return { error = 'Pilih cara bayar' } end
    if type(lines) ~= 'table' or #lines == 0 then return { error = 'Pilih minimal satu layanan' } end

    local cid = patient.PlayerData.citizenid
    local list = pending[cid] or {}
    local byId = {}
    for _, svc in ipairs(list) do byId[svc.id] = svc end

    local items, used, total = {}, {}, 0
    for _, line in ipairs(lines) do
        local svc = type(line) == 'table' and byId[tonumber(line.id)]
        if not svc or used[svc.id] then return { error = 'Data tagihan berubah, buka ulang tab Tagihan' } end
        local price = math.floor(tonumber(line.price) or -1)
        -- diskon boleh, menaikkan harga tidak
        if price < 0 or price > svc.price then return { error = ('Harga %s harus 0 - Rp %s'):format(svc.label, formatMoney(svc.price)) } end
        used[svc.id] = true
        total += price
        items[#items + 1] = { label = svc.label, price = price, normal = svc.price }
    end
    if total <= 0 then return { error = 'Total tagihan Rp 0, tidak perlu dikirim' } end

    local _, ems = isEms(src, true)
    local invoiceId
    if mode == 'direct' then
        local summary = {}
        for i, item in ipairs(items) do summary[i] = item.label end
        local okE, emsNumber = pcall(function() return exports['f_phone']:getPhoneNumber(src) end)
        invoiceId = Billing.CreateInvoice(tonumber(target), patient, total, 'Layanan EMS: ' .. table.concat(summary, ', '),
            { cid = ems.PlayerData.citizenid, name = charName(ems), number = okE and emsNumber or nil })
        if not invoiceId then return { error = 'Invoice HP gagal dibuat (f_phone)' } end
    end

    local id = Billing.Create({
        cid = cid, name = charName(patient), items = items, total = total, kind = 'tindakan', channel = mode,
        by = ems.PlayerData.citizenid, byName = charName(ems), invoice = invoiceId,
    })
    if mode == 'kasir' then
        notify(tonumber(target), ('Tagihan layanan EMS #%d Rp %s menunggu di Kasir rumah sakit.'):format(id, formatMoney(total)), 'inform')
    end

    for i = #list, 1, -1 do
        if used[list[i].id] then table.remove(list, i) end
    end

    local data = billingData(cid)
    data.sent = total
    data.mode = mode
    return data
end)

---Tagihan operasi langsung masuk kasir (dipanggil server/surgery.lua saat operasi selesai).
---@param services string[] kode layanan (config.treatment billing)
function Billing.SurgeryBill(doctorSrc, patientSrc, services)
    local patient = exports.qbx_core:GetPlayer(patientSrc)
    local doctor = exports.qbx_core:GetPlayer(doctorSrc)
    if not patient or not doctor or #services == 0 then return end
    local items, total = {}, 0
    for _, code in ipairs(services) do
        local def = cfg.billing[code]
        if def then
            local price = Prices.Get('svc:' .. code)
            items[#items + 1] = { label = def.label, price = price, normal = price }
            total += price
        end
    end
    if total <= 0 then return end
    local id = Billing.Create({
        cid = patient.PlayerData.citizenid, name = charName(patient), items = items, total = total, kind = 'operasi',
        channel = 'kasir', by = doctor.PlayerData.citizenid, byName = charName(doctor),
    })
    notify(patientSrc, ('Tagihan operasi #%d Rp %s menunggu di Kasir rumah sakit.'):format(id, formatMoney(total)), 'inform')
    notify(doctorSrc, ('Tagihan operasi #%d masuk kasir. Arahkan pasien ke kasir untuk membayar.'):format(id), 'inform')
end

---------------------------------------------------------------------------
-- MDT EMS (dipanggil f_phone server/mdt/bills.lua setelah cek izin terminal)
---------------------------------------------------------------------------

local KIND_LABEL = { tindakan = 'Tindakan', operasi = 'Operasi', apotek = 'Apotek' }

---@param src number
---@param payload { query?: string }
exports('MdtBillsList', function(src, payload)
    if not isEms(src, false) then return { error = 'Hanya EMS' } end
    local query = type(payload) == 'table' and tostring(payload.query or ''):sub(1, 60) or ''
    local rows
    if query ~= '' then
        local like = '%' .. query .. '%'
        rows = Billing.Query("status = 'unpaid' AND kind <> 'apotek' AND (patient_name LIKE ? OR citizenid LIKE ?) ORDER BY id DESC LIMIT 100", { like, like })
    else
        rows = Billing.Query("status = 'unpaid' AND kind <> 'apotek' ORDER BY id DESC LIMIT 100")
    end

    local out, sum = {}, 0
    for _, r in ipairs(rows) do
        sum += r.total
        out[#out + 1] = {
            id = r.id,
            citizenid = r.citizenid,
            name = r.patient_name,
            total = r.total,
            items = r.items,
            by = ('%s · %s'):format(KIND_LABEL[r.kind] or r.kind, r.created_by_name),
            createdAt = r.created_at,
        }
    end
    return { rows = out, sum = sum }
end)

---Tagih paksa dari MDT (sama dengan tombol di Kasir).
---@param src number
---@param id integer
exports('MdtBillsCollect', function(src, id)
    local okEms, ems = isEms(src, false)
    if not okEms then return { error = 'Hanya EMS' } end
    local bill = Billing.Get(id)
    if not bill then return { error = 'Tagihan tidak ditemukan' } end
    local err = Billing.ForceCollect(bill, charName(ems))
    if err then return { error = err } end
    pcall(function()
        exports['f_phone']:mdtLog(src, 'tagihan_ems', 'citizen', bill.citizenid,
            ('Tagih paksa #%d Rp %s dari bank %s'):format(bill.id, formatMoney(bill.total), bill.patient_name))
    end)
    return { ok = true, total = bill.total }
end)

Billing.KindLabel = KIND_LABEL
Billing.PharmacyCfg = pharmacy
