-- Kasir bengkel (server). Tagihan "Bayar di Kasir" (perbaikan) & order kustom (f_customs) disimpan di
-- mechanic_bills (channel = 'kasir') dan disalin ke memori saat start, jadi membuka kasir tidak query DB.
--  Status: unpaid (belum bayar) -> wait (invoice transfer di HP) -> paid (kustom lunas, menunggu dipasang)
--          -> done (perbaikan lunas / kustom terpasang). cancelled = dihapus mekanik / semua item dihapus.
--  Warga: harus dekat meja kasir. Cash = item uang dipotong, Transfer = invoice f_phone.
--  Mekanik on duty: daftar belum bayar + hapus; Master Harga untuk grade >= config.customs priceGrade.
local cfg = require 'config.shared'
local CUS = require 'config.customs'
local BILL = (require 'config.server').billing
local SHOP = require 'config.shop'

Kasir = {}

---@type table<integer, table>
local Bills = {}
---@type table<string, integer> invoice id -> bill id
local ByInvoice = {}
local throttles = {}

local function notify(src, msg, typ) exports.qbx_core:Notify(src, msg, typ or 'inform', 7000) end

local function throttle(src, key, ms)
    local now, id = GetGameTimer(), src .. key
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

local function sourceOf(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil
end

local function nearCashier(src, extra)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - cfg.cashier.coords) <= cfg.cashier.distance + (extra or 0)
end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty, player
end

local function societyAdd(amount)
    if amount <= 0 then return end
    pcall(function() exports['Renewed-Banking']:addAccountMoney(BILL.job, amount) end)
end

local function broadcastMechanics(msg)
    local _, sources = exports.qbx_core:GetDutyCountType(cfg.jobType)
    for i = 1, #(sources or {}) do notify(sources[i], msg) end
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local function rowToBill(r)
    local ok, items = pcall(json.decode, r.items)
    return {
        id = r.id, kind = r.kind, citizenid = r.citizenid, name = r.customer_name, plate = r.plate,
        vehicleid = r.vehicleid, items = ok and items or {}, total = r.total, status = r.status,
        invoice = r.invoice_id, createdBy = r.created_by, createdByName = r.created_by_name,
        createdAt = r.created_at, paidAt = r.settled_at, method = r.method,
    }
end

CreateThread(function()
    while not Billing.ready do Wait(100) end
    local rows = MySQL.query.await([[
        SELECT * FROM mechanic_bills
        WHERE channel = 'kasir' AND (status IN ('unpaid', 'wait') OR (kind = 'custom' AND status = 'paid'))
    ]]) or {}
    for _, r in ipairs(rows) do
        local b = rowToBill(r)
        Bills[b.id] = b
        if b.invoice and b.status == 'wait' then ByInvoice[b.invoice] = b.id end
    end
end)

local function save(b)
    MySQL.update.await([[
        UPDATE mechanic_bills SET items = ?, total = ?, status = ?, invoice_id = ?, method = ?, settled_at = ? WHERE id = ?
    ]], { json.encode(b.items), b.total, b.status, b.invoice, b.method, b.paidAt, b.id })
end

local function setStatus(b, status)
    b.status = status
    if b.invoice and status ~= 'wait' then ByInvoice[b.invoice] = nil end
    save(b)
    if status == 'cancelled' or status == 'done' then Bills[b.id] = nil end
end

---Tagihan baru di kasir.
---@param b { kind: 'repair'|'custom', citizenid: string, name: string, plate: string, vehicleid?: integer, items: table[], total: integer, createdBy: string, createdByName: string }
---@return table? bill
function Kasir.Add(b)
    b.status, b.createdAt = 'unpaid', os.time()
    local id = MySQL.insert.await([[
        INSERT INTO mechanic_bills (citizenid, customer_name, plate, items, total, status, created_by, created_by_name, created_at, kind, channel, vehicleid)
        VALUES (?, ?, ?, ?, ?, 'unpaid', ?, ?, ?, ?, 'kasir', ?)
    ]], { b.citizenid, b.name, b.plate, json.encode(b.items), b.total, b.createdBy, b.createdByName, b.createdAt, b.kind, b.vehicleid })
    if not id then return end
    b.id = id
    Bills[id] = b
    return b
end

---Order kustom aktif (belum bayar / menunggu transfer / lunas belum dipasang) untuk kendaraan.
function Kasir.ActiveCustom(vehicleid)
    if not vehicleid then return end
    for _, b in pairs(Bills) do
        if b.kind == 'custom' and b.vehicleid == vehicleid then return b end
    end
end

---Order kustom yang sudah lunas & siap dipasang untuk kendaraan.
function Kasir.PaidCustom(vehicleid)
    local b = Kasir.ActiveCustom(vehicleid)
    return b and b.status == 'paid' and b or nil
end

function Kasir.Get(id) return Bills[tonumber(id) or 0] end

---Kustom selesai dipasang.
function Kasir.Done(b)
    setStatus(b, 'done')
end

---------------------------------------------------------------------------
-- Invoice f_phone (sama seperti toko bengkel)
---------------------------------------------------------------------------
local function invoiceAvailable() return GetResourceState('f_phone') == 'started' end

local function invoiceCreate(src, player, b)
    if not invoiceAvailable() then return end
    local chars, t = 'abcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 16 do
        local n = math.random(1, #chars)
        t[i] = chars:sub(n, n)
    end
    local id = 'bill_' .. table.concat(t)
    local okNum, number = pcall(function() return exports['f_phone']:getPhoneNumber(src) end)
    local what = b.kind == 'custom' and 'Kustom kendaraan' or 'Perbaikan kendaraan'
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, 'pending', ?)
    ]], { id, BILL.job, ('%s · #%d'):format(BILL.label, b.id), BILL.job, BILL.label,
          player.PlayerData.citizenid, Billing.CharName(player), okNum and number or nil, b.total,
          ('%s %s (#%d)'):format(what, b.plate, b.id), os.time() })
    if not ok then return end
    pcall(function()
        exports['f_phone']:notify(src, { appId = 'bank', app = 'Bank', title = BILL.label,
            body = ('Tagihan bengkel Rp %d (#%d). Buka Bank > Invoices untuk membayar.'):format(b.total, b.id), time = 'now' })
    end)
    TriggerClientEvent('f_phone:client:services:invoices', src, {})
    return id
end

local function invoiceCancel(id, cid)
    local affected = MySQL.update.await("UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { id })
    local src = sourceOf(cid)
    if src then TriggerClientEvent('f_phone:client:services:invoices', src, {}) end
    return (tonumber(affected) or 0) > 0
end

local function invoiceStatus(id)
    return MySQL.scalar.await('SELECT status FROM phone_service_invoices WHERE id = ?', { id })
end

---------------------------------------------------------------------------
-- Pembayaran
---------------------------------------------------------------------------
local function onPaid(b, method)
    b.method, b.paidAt = method, os.time()
    local custom = b.kind == 'custom'
    setStatus(b, custom and 'paid' or 'done')
    local src = sourceOf(b.citizenid)
    if src then
        notify(src, custom and ('Tagihan #%d lunas. Minta mekanik memasang modifikasi kendaraanmu.'):format(b.id)
            or ('Tagihan bengkel #%d lunas. Terima kasih!'):format(b.id), 'success')
    end
    if custom then broadcastMechanics(('Order kustom #%d (%s · %s) lunas, siap dipasang.'):format(b.id, b.name, b.plate)) end
end

---Cek invoice yang menunggu (kalau event bayar terlewat, mis. resource restart).
local function refreshWait(b)
    if b.status ~= 'wait' or not b.invoice then return end
    local s = invoiceStatus(b.invoice)
    if s == 'paid' then
        onPaid(b, 'transfer')
    elseif s ~= 'pending' then
        b.invoice = nil
        setStatus(b, 'unpaid')
    end
end

AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' or data.job ~= BILL.job or not data.id then return end
    local b = Bills[ByInvoice[data.id] or 0]
    if b and b.status == 'wait' then onPaid(b, 'transfer') end
end)

local function publicBill(b)
    local items = {}
    for i, it in ipairs(b.items) do
        items[i] = { id = it.id, label = it.label, desc = it.desc, price = it.price, normal = it.normal }
    end
    return {
        id = b.id, kind = b.kind, name = b.name, plate = b.plate, items = items, total = b.total, status = b.status,
        by = b.kind == 'custom' and 'Order sendiri' or b.createdByName, at = b.createdAt,
    }
end

local function mineData(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan' } end
    local cid = player.PlayerData.citizenid
    local list = {}
    for _, b in pairs(Bills) do
        if b.citizenid == cid and (b.status == 'unpaid' or b.status == 'wait') then
            refreshWait(b)
            if b.status == 'unpaid' or b.status == 'wait' then list[#list + 1] = publicBill(b) end
        end
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    return {
        bills = list,
        cash = exports.ox_inventory:GetItemCount(src, SHOP.cashItem) or 0,
        bank = player.PlayerData.money.bank or 0,
        transfer = invoiceAvailable(),
    }
end

local function ownBill(src, id)
    local player = exports.qbx_core:GetPlayer(src)
    local b = Bills[tonumber(id) or 0]
    if not player or not b or b.citizenid ~= player.PlayerData.citizenid then return nil, player end
    return b, player
end

lib.callback.register('f_mechanicjob:server:kasirMine', function(src)
    if not nearCashier(src) then return { error = 'Kamu harus berada di meja kasir' } end
    return mineData(src)
end)

lib.callback.register('f_mechanicjob:server:kasirRemoveLine', function(src, billId, lineId)
    if not throttle(src, 'line', 500) then return { error = 'Tunggu sebentar' } end
    if not nearCashier(src) then return { error = 'Kamu harus berada di meja kasir' } end
    local b = ownBill(src, billId)
    if not b then return { error = 'Tagihan tidak ditemukan' } end
    if b.kind ~= 'custom' then return { error = 'Item perbaikan tidak bisa dihapus' } end
    if b.status ~= 'unpaid' then return { error = 'Batalkan transfer dulu sebelum mengubah tagihan' } end
    local found
    for i = #b.items, 1, -1 do
        if b.items[i].id == lineId then table.remove(b.items, i) found = true end
    end
    if not found then return { error = 'Item tidak ditemukan' } end
    local total = 0
    for _, it in ipairs(b.items) do total += it.price end
    b.total = total
    if #b.items == 0 then
        setStatus(b, 'cancelled')
        notify(src, ('Order kustom #%d dibatalkan.'):format(b.id))
    else
        save(b)
    end
    return mineData(src)
end)

lib.callback.register('f_mechanicjob:server:kasirPay', function(src, billId, method)
    if not throttle(src, 'pay', 2000) then return { error = 'Tunggu sebentar' } end
    if method ~= 'cash' and method ~= 'transfer' then return { error = 'Metode tidak valid' } end
    if not nearCashier(src) then return { error = 'Kamu harus berada di meja kasir' } end
    local b, player = ownBill(src, billId)
    if not b then return { error = 'Tagihan tidak ditemukan' } end
    if b.status ~= 'unpaid' then return { error = 'Tagihan ini sedang menunggu transfer' } end
    if b.total <= 0 then onPaid(b, 'cash') return mineData(src) end

    if method == 'cash' then
        if (exports.ox_inventory:GetItemCount(src, SHOP.cashItem) or 0) < b.total then return { error = ('Uang cash kurang (Rp %d)'):format(b.total) } end
        if not exports.ox_inventory:RemoveItem(src, SHOP.cashItem, b.total) then return { error = 'Gagal mengambil uang cash' } end
        societyAdd(b.total)
        onPaid(b, 'cash')
        local data = mineData(src)
        data.msg = ('Tagihan #%d dibayar cash Rp %d.'):format(b.id, b.total)
        return data
    end

    if not invoiceAvailable() then return { error = 'Pembayaran transfer sedang tidak tersedia' } end
    local invoiceId = invoiceCreate(src, player, b)
    if not invoiceId then return { error = 'Gagal membuat invoice' } end
    b.invoice = invoiceId
    ByInvoice[invoiceId] = b.id
    setStatus(b, 'wait')
    local data = mineData(src)
    data.msg = 'Invoice dikirim ke HP. Buka Bank > Invoices untuk membayar.'
    return data
end)

lib.callback.register('f_mechanicjob:server:kasirCancelTransfer', function(src, billId)
    if not throttle(src, 'cancel', 1500) then return { error = 'Tunggu sebentar' } end
    local b = ownBill(src, billId)
    if not b or b.status ~= 'wait' then return { error = 'Tagihan tidak sedang menunggu transfer' } end
    if not invoiceCancel(b.invoice, b.citizenid) then
        refreshWait(b)
        if b.status ~= 'wait' then return mineData(src) end
        return { error = 'Invoice gagal dibatalkan' }
    end
    b.invoice = nil
    setStatus(b, 'unpaid')
    return mineData(src)
end)

---------------------------------------------------------------------------
-- Menu kasir mekanik
---------------------------------------------------------------------------
local function canPrice(player)
    return player.PlayerData.job.grade.level >= CUS.priceGrade
end

local function staffData(src, player)
    local list, unpaid, wait, sum = {}, 0, 0, 0
    for _, b in pairs(Bills) do
        if b.status == 'unpaid' or b.status == 'wait' then
            refreshWait(b)
            if b.status == 'unpaid' or b.status == 'wait' then
                list[#list + 1] = publicBill(b)
                if b.status == 'unpaid' then unpaid += 1 else wait += 1 end
                sum += b.total
            end
        end
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    local okBal, balance = pcall(function() return exports['Renewed-Banking']:getAccountMoney(BILL.job) end)
    return {
        bills = list, unpaid = unpaid, wait = wait, sum = sum,
        balance = okBal and tonumber(balance) or nil,
        canPrice = canPrice(player),
        canSupply = Stock.CanBuy(player.PlayerData.job),
    }
end

lib.callback.register('f_mechanicjob:server:kasirStaff', function(src)
    local ok, player = isMechanic(src)
    if not ok then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearCashier(src, 2.0) then return { error = 'Kamu harus berada di meja kasir' } end
    return staffData(src, player)
end)

lib.callback.register('f_mechanicjob:server:kasirDelete', function(src, billId)
    if not throttle(src, 'del', 800) then return { error = 'Tunggu sebentar' } end
    local ok, player = isMechanic(src)
    if not ok then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearCashier(src, 2.0) then return { error = 'Kamu harus berada di meja kasir' } end
    local b = Bills[tonumber(billId) or 0]
    if not b or (b.status ~= 'unpaid' and b.status ~= 'wait') then return { error = 'Tagihan tidak ditemukan atau sudah dibayar' } end
    if b.status == 'wait' and not invoiceCancel(b.invoice, b.citizenid) then
        refreshWait(b)
        if b.status ~= 'wait' and b.status ~= 'unpaid' then return { error = 'Tagihan baru saja dibayar pelanggan' } end
    end
    setStatus(b, 'cancelled')
    local target = sourceOf(b.citizenid)
    if target then notify(target, ('Tagihan bengkel #%d dibatalkan oleh mekanik.'):format(b.id)) end
    local data = staffData(src, player)
    data.msg = ('Tagihan #%d dihapus.'):format(b.id)
    return data
end)

lib.callback.register('f_mechanicjob:server:pricesGet', function(src)
    local ok, player = isMechanic(src)
    if not ok then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not canPrice(player) then return { error = 'Grade kamu belum bisa membuka Master Harga' } end
    return { list = Prices.List(), max = Prices.Max }
end)

lib.callback.register('f_mechanicjob:server:pricesSave', function(src, changes)
    if not throttle(src, 'price', 1500) then return { error = 'Tunggu sebentar' } end
    local ok, player = isMechanic(src)
    if not ok then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not canPrice(player) then return { error = 'Grade kamu belum bisa mengubah harga' } end
    local err, n = Prices.Save(changes)
    if err then return { error = err } end
    return { list = Prices.List(), max = Prices.Max, msg = ('%d harga disimpan. Berlaku untuk tagihan baru.'):format(n) }
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
