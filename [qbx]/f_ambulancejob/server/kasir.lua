-- Kasir EMS (server). Satu titik kasir untuk dua tampilan:
--  * Pasien  : bayar tagihan kasir (cash -> rekening organisasi, transfer -> invoice HP),
--              ambil obat sendiri kalau tidak ada EMS bertugas.
--  * Petugas : Approval (serahkan obat / konfirmasi, pasien harus dekat), Belum Dibayar (Batal /
--              Tagih Paksa), Stok Gudang, Supplier (Boss), Daftar Harga (Boss), Pengaturan.

local pharmacy = require 'config.pharmacy'
local serverCfg = require 'config.server'

local throttles = {}

local function throttle(src, key, ms)
    local id, now = src .. key, GetGameTimer()
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function emsOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or job.type ~= 'ems' or not job.onduty then return end
    return player, job
end

local function distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return math.huge end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

---Status invoice HP sekaligus untuk banyak tagihan (1 query).
---@return table<string, string> invoice id -> status
local function invoiceStatuses(bills)
    local ids = {}
    for _, b in ipairs(bills) do
        if b.invoice_id then ids[#ids + 1] = b.invoice_id end
    end
    local map = {}
    if #ids == 0 then return map end
    for _, r in ipairs(MySQL.query.await('SELECT id, status FROM phone_service_invoices WHERE id IN (?)', { ids }) or {}) do
        map[r.id] = r.status
    end
    return map
end

local function billView(b, invoices)
    return {
        id = b.id, kind = b.kind, kindLabel = Billing.KindLabel[b.kind] or b.kind, channel = b.channel,
        name = b.patient_name, items = b.items, total = b.total, status = b.status, method = b.method,
        by = b.created_by_name, at = b.created_at, paidAt = b.settled_at, deliver = b.deliver,
        invoice = b.invoice_id ~= nil and invoices[b.invoice_id] == 'pending',
    }
end

local function viewList(bills)
    local invoices, out = invoiceStatuses(bills), {}
    for i, b in ipairs(bills) do out[i] = billView(b, invoices) end
    return out
end

---------------------------------------------------------------------------
-- Pasien
---------------------------------------------------------------------------
local function patientData(player)
    local cid = player.PlayerData.citizenid
    local bills = Billing.Query([[
        citizenid = ? AND ((status = 'unpaid' AND channel = 'kasir') OR (status IN ('paid', 'collected') AND deliver = 'pending'))
        ORDER BY id ASC LIMIT 20
    ]], { cid })
    return {
        name = charName(player),
        bills = viewList(bills),
        ems = Billing.EmsOnDuty(),
        transfer = GetResourceState('f_phone') == 'started',
        cash = exports.ox_inventory:GetItemCount(player.PlayerData.source, pharmacy.cashItem) or 0,
    }
end

local function ownBill(player, id)
    local bill = Billing.Get(id)
    if not bill or bill.citizenid ~= player.PlayerData.citizenid then return end
    return bill
end

lib.callback.register('f_ambulancejob:server:kasirPatient', function(src)
    if not NearKasir(src) then return { error = 'Kamu harus berada di kasir.' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan.' } end
    return patientData(player)
end)

---@param method 'cash'|'transfer'
lib.callback.register('f_ambulancejob:server:kasirPay', function(src, id, method)
    if not throttle(src, 'pay', 2000) then return { error = 'Tunggu sebentar.' } end
    if not NearKasir(src) then return { error = 'Kamu harus berada di kasir.' } end
    local player = exports.qbx_core:GetPlayer(src)
    local bill = player and ownBill(player, id)
    if not bill or bill.status ~= 'unpaid' or bill.channel ~= 'kasir' then return { error = 'Tagihan tidak ditemukan atau sudah dibayar.' } end

    if method == 'cash' then
        -- invoice transfer yang masih menunggu dibatalkan dulu (cegah bayar dobel)
        if bill.invoice_id and Billing.InvoiceStatus(bill.invoice_id) == 'pending' then
            local affected = MySQL.update.await("UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { bill.invoice_id })
            if (tonumber(affected) or 0) == 0 then return { error = 'Tagihan baru saja dibayar lewat HP.' } end
            TriggerClientEvent('f_phone:client:services:invoices', src, {})
        end
        if (exports.ox_inventory:GetItemCount(src, pharmacy.cashItem) or 0) < bill.total then
            return { error = ('Uang tunai kamu kurang (Rp %s).'):format(Billing.FormatMoney(bill.total)) }
        end
        if not exports.ox_inventory:RemoveItem(src, pharmacy.cashItem, bill.total) then return { error = 'Gagal mengambil uang tunai.' } end
        if not Billing.MarkPaid(bill, 'cash', 'Kasir') then
            exports.ox_inventory:AddItem(src, pharmacy.cashItem, bill.total)
            return { error = 'Tagihan ini sudah dibayar.' }
        end
        serverCfg.depositSociety(pharmacy.job, bill.total)
        local data = patientData(player)
        data.msg = ('Tagihan #%d lunas (cash).'):format(bill.id)
        return data
    elseif method == 'transfer' then
        if bill.invoice_id and Billing.InvoiceStatus(bill.invoice_id) == 'pending' then
            return { error = 'Invoice sudah dikirim ke HP. Bayar lewat Bank > Invoices.' }
        end
        local invoiceId = Billing.CreateInvoice(src, player, bill.total, ('%s #%d'):format(Billing.KindLabel[bill.kind] or 'Tagihan', bill.id),
            { cid = pharmacy.job, name = pharmacy.label })
        if not invoiceId then return { error = 'Pembayaran transfer sedang tidak tersedia.' } end
        MySQL.update.await('UPDATE ems_bills SET invoice_id = ? WHERE id = ?', { invoiceId, bill.id })
        local data = patientData(player)
        data.msg = ('Invoice tagihan #%d dikirim ke HP. Bayar lewat Bank > Invoices.'):format(bill.id)
        return data
    end
    return { error = 'Metode pembayaran tidak valid.' }
end)

-- ambil obat sendiri (hanya saat tidak ada EMS bertugas)
lib.callback.register('f_ambulancejob:server:kasirClaim', function(src, id)
    if not throttle(src, 'claim', 1500) then return { error = 'Tunggu sebentar.' } end
    if not NearKasir(src) then return { error = 'Kamu harus berada di kasir.' } end
    local player = exports.qbx_core:GetPlayer(src)
    local bill = player and ownBill(player, id)
    if not bill or bill.deliver ~= 'pending' or (bill.status ~= 'paid' and bill.status ~= 'collected') then
        return { error = 'Tidak ada obat untuk diambil.' }
    end
    if Billing.EmsOnDuty() > 0 then return { error = 'Ada petugas EMS bertugas. Minta petugas di kasir menyerahkan obatmu.' } end
    local err = Billing.GiveItems(src, bill)
    if err then return { error = err } end
    local data = patientData(player)
    data.msg = ('Obat tagihan #%d sudah masuk tas kamu.'):format(bill.id)
    return data
end)

---------------------------------------------------------------------------
-- Petugas
---------------------------------------------------------------------------
local function staffData(src, player, job)
    local approvalRows = Billing.Query('approval = 1 ORDER BY settled_at ASC LIMIT 50')
    local approvals = viewList(approvalRows)
    for i, b in ipairs(approvalRows) do
        local target = Billing.SourceOf(b.citizenid)
        approvals[i].online = target ~= nil
        approvals[i].near = target ~= nil and distance(src, target) <= pharmacy.serveDistance
    end
    local unpaidRows = Billing.Query("status = 'unpaid' ORDER BY id DESC LIMIT 100")
    local unpaid, sum = viewList(unpaidRows), 0
    for _, b in ipairs(unpaidRows) do sum += b.total end
    local withEms, withoutEms = Pharmacy.Limits()
    return {
        name = charName(player),
        grade = job.grade and job.grade.name or '',
        boss = IsEmsBoss(job),
        canSettings = (job.grade and job.grade.level or 0) >= pharmacy.settingsGrade,
        approvals = approvals,
        unpaid = unpaid,
        unpaidSum = sum,
        stock = Stock.List(),
        balance = Stock.Balance(),
        maxPerBuy = Stock.MaxPerBuy,
        prices = Prices.List(),
        limits = { withEms = withEms, withoutEms = withoutEms, max = pharmacy.maxLimit },
        timeout = pharmacy.orderTimeout,
    }
end

---@return table? player, table? job, string? error
local function staffCheck(src)
    local player, job = emsOf(src)
    if not player then return nil, nil, 'Hanya EMS yang sedang bertugas.' end
    if not NearKasir(src) then return nil, nil, 'Kamu harus berada di kasir.' end
    return player, job
end

local function reply(src, player, job, msg, err)
    local data = staffData(src, player, job)
    data.msg, data.error = msg, err
    return data
end

lib.callback.register('f_ambulancejob:server:kasirStaff', function(src)
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    return staffData(src, player, job)
end)

lib.callback.register('f_ambulancejob:server:kasirApprove', function(src, id)
    if not throttle(src, 'approve', 1500) then return { error = 'Tunggu sebentar.' } end
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    local bill = Billing.Get(id)
    if not bill or not bill.approval then return reply(src, player, job, nil, 'Tagihan sudah tidak ada di daftar Approval.') end
    local target = Billing.SourceOf(bill.citizenid)
    if not target then return reply(src, player, job, nil, 'Pasien sedang tidak ada di kota.') end
    if distance(src, target) > pharmacy.serveDistance then return reply(src, player, job, nil, 'Pasien harus berdiri dekat kamu.') end

    if bill.deliver == 'pending' then
        local giveErr = Billing.GiveItems(target, bill)
        if giveErr then
            exports.qbx_core:Notify(target, 'Tas kamu penuh, obat belum bisa diserahkan. Kosongkan tas dulu.', 'error', 7000)
            return reply(src, player, job, nil, giveErr)
        end
        exports.qbx_core:Notify(target, ('Obat tagihan #%d sudah diterima. Semoga lekas sembuh!'):format(bill.id), 'success', 7000)
    else
        MySQL.update.await('UPDATE ems_bills SET approval = 0 WHERE id = ?', { bill.id })
        exports.qbx_core:Notify(target, ('Tagihan #%d sudah dikonfirmasi petugas. Terima kasih.'):format(bill.id), 'success', 7000)
    end
    return reply(src, player, job, ('Tagihan #%d selesai (%s).'):format(bill.id, bill.patient_name))
end)

lib.callback.register('f_ambulancejob:server:kasirCancel', function(src, id)
    if not throttle(src, 'cancel', 1000) then return { error = 'Tunggu sebentar.' } end
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    local bill = Billing.Get(id)
    if not bill then return reply(src, player, job, nil, 'Tagihan tidak ditemukan.') end
    local cancelErr = Billing.Cancel(bill, charName(player))
    if cancelErr then return reply(src, player, job, nil, cancelErr) end
    local target = Billing.SourceOf(bill.citizenid)
    if target then exports.qbx_core:Notify(target, ('Tagihan EMS #%d dibatalkan oleh petugas.'):format(bill.id), 'inform', 7000) end
    return reply(src, player, job, ('Tagihan #%d dibatalkan.'):format(bill.id))
end)

lib.callback.register('f_ambulancejob:server:kasirCollect', function(src, id)
    if not throttle(src, 'collect', 1500) then return { error = 'Tunggu sebentar.' } end
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    local bill = Billing.Get(id)
    if not bill then return reply(src, player, job, nil, 'Tagihan tidak ditemukan.') end
    local collectErr = Billing.ForceCollect(bill, charName(player))
    if collectErr then return reply(src, player, job, nil, collectErr) end
    return reply(src, player, job, ('Tagihan #%d Rp %s ditarik dari bank %s.'):format(bill.id, Billing.FormatMoney(bill.total), bill.patient_name))
end)

lib.callback.register('f_ambulancejob:server:kasirPrices', function(src, changes)
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    if not IsEmsBoss(job) then return reply(src, player, job, nil, 'Hanya Boss yang bisa mengubah harga.') end
    local setErr = Prices.Set(changes)
    if setErr then return reply(src, player, job, nil, setErr) end
    return reply(src, player, job, 'Daftar harga disimpan.')
end)

lib.callback.register('f_ambulancejob:server:kasirLimits', function(src, withEms, withoutEms)
    local player, job, err = staffCheck(src)
    if not player then return { error = err } end
    if (job.grade and job.grade.level or 0) < pharmacy.settingsGrade then return reply(src, player, job, nil, 'Grade kamu belum bisa mengubah pengaturan.') end
    local setErr = Pharmacy.SetLimits(withEms, withoutEms)
    if setErr then return reply(src, player, job, nil, setErr) end
    return reply(src, player, job, 'Pengaturan batas pesanan disimpan.')
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
