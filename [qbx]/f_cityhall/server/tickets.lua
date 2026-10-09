-- Tilang polisi. SIM/STNK yang diambil dari inventory dan kendaraan yang disita disimpan di sini
-- sampai ditebus di loket polisi (bayar + approve petugas, lihat fulfil di main.lua); denda dikirim
-- sebagai tagihan HP. Hanya tilang yang masih terbuka ada di memori (sedikit), DB ditulis saat berubah.
-- Tidak ada loop: status tagihan/kendaraan dicek (1 query) saat tab Tilang atau loket dibuka.

local config = require 'config.shared'
local tcfg = config.tickets
local ox = exports.ox_inventory

Tickets = {}

---@type table<integer, table> tilang terbuka ('held' / 'unpaid') per id
local Open = {}
---@type table<string, integer> invoice denda -> id tilang
local ByInvoice = {}

local CALLERS = { f_police = true } -- resource yang boleh memakai export tilang
local KIND_LABEL = { sim = 'SIM', stnk = 'STNK', vehicle = 'Kendaraan', fine = 'Denda' }
local CONDITION = {
    sim = 'SIM belum diambil',
    stnk = 'STNK belum diambil',
    vehicle = 'Kendaraan belum diambil',
    fine = 'Belum bayar denda',
}

local function phoneOf(cid)
    local ok, number = pcall(function() return exports['f_phone']:getPhoneNumberByIdentifier(cid, true) end)
    return ok and number or nil
end

local function insertTicket(t)
    t.created = os.time()
    t.status = t.status or 'held'
    t.id = MySQL.insert.await([[
        INSERT INTO police_tickets (citizenid, name, phone, kind, item, metadata, vehicle_id, plate, model, price, reason,
            officer_cid, officer_name, invoice_id, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { t.cid, t.name, t.phone, t.kind, t.item, t.metadata and json.encode(t.metadata) or nil, t.vehicleId, t.plate, t.model,
          t.price, t.reason, t.officerCid, t.officerName, t.invoice, t.status, t.created, t.created })
    if not t.id then return end
    Open[t.id] = t
    if t.invoice then ByInvoice[t.invoice] = t.id end
    return t
end

---@param status 'redeemed'|'returned'|'forfeited'|'paid'|'cancelled'|'released'
local function closeTicket(t, status, by)
    Open[t.id] = nil
    if t.invoice then ByInvoice[t.invoice] = nil end
    MySQL.prepare('UPDATE police_tickets SET status = ?, handled_by = ?, updated_at = ? WHERE id = ?',
        { status, by, os.time(), t.id })
end

local function placeholders(n)
    return ('?'):rep(n, ', ')
end

---Denda yang sudah dibayar/dibatalkan di HP saat server ini tidak mendengar event-nya.
local function syncFines()
    local ids = {}
    for invoiceId in pairs(ByInvoice) do ids[#ids + 1] = invoiceId end
    if #ids == 0 then return end
    local rows = MySQL.query.await(('SELECT id, status FROM phone_service_invoices WHERE id IN (%s)'):format(placeholders(#ids)), ids) or {}
    for _, row in ipairs(rows) do
        local t = Open[ByInvoice[row.id]]
        if t and row.status == 'paid' then closeTicket(t, 'paid')
        elseif t and row.status == 'cancelled' then closeTicket(t, 'cancelled') end
    end
end

---Kendaraan yang sudah dikeluarkan dari impound lewat jalur lain (menu impound polisi) tidak ditahan lagi.
---@param cid? string hanya kendaraan milik warga ini
local function syncVehicles(cid)
    local list, ids = {}, {}
    for _, t in pairs(Open) do
        if t.kind == 'vehicle' and (not cid or t.cid == cid) then
            list[#list + 1] = t
            ids[#ids + 1] = t.vehicleId
        end
    end
    if #ids == 0 then return end
    local state = {}
    local rows = MySQL.query.await(('SELECT id, state, citizenid FROM player_vehicles WHERE id IN (%s)'):format(placeholders(#ids)), ids) or {}
    for _, row in ipairs(rows) do state[row.id] = row end
    for _, t in ipairs(list) do
        local row = state[t.vehicleId]
        if not row or row.state ~= 2 or row.citizenid ~= t.cid then closeTicket(t, 'released') end
    end
end

function Tickets.title(t)
    if t.kind == 'sim' then return 'Penebusan SIM' end
    if t.kind == 'stnk' then return ('Penebusan STNK · %s'):format(t.plate or '-') end
    if t.kind == 'vehicle' then return ('Penebusan Kendaraan · %s'):format(t.plate or '-') end
    return 'Denda Tilang'
end

function Tickets.get(id)
    return Open[tonumber(id)]
end

---Tilang yang bisa ditebus di loket oleh warga ini.
function Tickets.heldFor(cid)
    syncVehicles(cid)
    local list = {}
    for _, t in pairs(Open) do
        if t.cid == cid and t.status == 'held' then list[#list + 1] = t end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Tickets.isItemHeld(cid, item)
    for _, t in pairs(Open) do
        if t.cid == cid and t.kind == 'sim' and t.item == item then return true end
    end
    return false
end

function Tickets.isStnkHeld(vehicleId)
    for _, t in pairs(Open) do
        if t.kind == 'stnk' and t.vehicleId == vehicleId then return true end
    end
    return false
end

---Mengembalikan dokumen/kendaraan ke pemilik. Dipakai saat penebusan di-approve dan tombol Kembalikan.
---@return boolean ok, string msg, string? mailLine
local function giveBack(t, tsrc)
    if t.kind == 'vehicle' then
        local row = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE id = ?', { t.vehicleId })
        if not row or row.citizenid ~= t.cid then return false, 'Kendaraan sudah bukan milik warga ini.' end
        MySQL.update.await('UPDATE player_vehicles SET state = 0, depotprice = 0 WHERE id = ?', { t.vehicleId })
        return true, 'Kendaraan dilepas dari impound.',
            ('Kendaraan %s (%s) sudah bisa diambil gratis di Impound Lot.'):format(City.vehicleLabel(t.model), t.plate or '-')
    end

    if not tsrc then return false, 'Pemilik harus online untuk menerima dokumennya.' end
    if not ox:CanCarryItem(tsrc, t.item, 1) then return false, 'Inventory pemilik penuh.' end
    if not ox:AddItem(tsrc, t.item, 1, t.metadata) then return false, 'Gagal menyerahkan dokumen.' end
    return true, ('%s diserahkan.'):format(KIND_LABEL[t.kind]),
        ('%s Anda yang ditahan polisi sudah dikembalikan.'):format(KIND_LABEL[t.kind])
end

function Tickets.redeem(id, tsrc, cid)
    local t = Open[tonumber(id)]
    if not t or t.cid ~= cid or t.status ~= 'held' then
        return false, 'Tilang ini sudah tidak berlaku. Silakan reject untuk refund.'
    end
    local ok, msg, line = giveBack(t, tsrc)
    if ok then closeTicket(t, 'redeemed') end
    return ok, msg, line
end

-- Pembayaran denda lewat HP
AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' then return end
    local t = Open[ByInvoice[data.id]]
    if not t then return end
    closeTicket(t, 'paid')
    local src = City.sourceByCid(t.cid)
    if src then City.notify(src, ('Denda tilang Rp %d sudah lunas.'):format(t.price), 'success') end
end)

---------------------------------------------------------------------------
-- Export untuk f_police (dipanggil setelah f_police memvalidasi petugas & target)
---------------------------------------------------------------------------
local function allowed()
    return CALLERS[GetInvokingResource() or ''] == true
end

local function officerInfo(src)
    local p = City.getPlayer(src)
    return p and p.PlayerData.citizenid, p and City.fullName(p)
end

local function cleanNote(note)
    note = type(note) == 'string' and note:gsub('[<>]', ''):match('^%s*(.-)%s*$') or ''
    return note ~= '' and note:sub(1, 100) or nil
end

exports('TicketOptions', function()
    local fines, reasons = {}, {}
    for i, f in ipairs(tcfg.fines) do fines[i] = { label = f.label, price = f.price } end
    for i, r in ipairs(tcfg.vehicleReasons) do reasons[i] = { label = r.label, price = r.price } end
    return {
        fines = fines,
        vehicleReasons = reasons,
        hold = { sim = tcfg.hold.sim.price, stnk = tcfg.hold.stnk.price },
        stnkItem = tcfg.hold.stnk.item,
        simItem = tcfg.hold.sim.item,
    }
end)

---Ambil SIM/STNK dari slot inventory target.
exports('HoldDocument', function(officerSrc, targetSrc, kind, slot, note)
    if not allowed() then return false end
    local h = tcfg.hold[kind]
    local target = City.getPlayer(targetSrc)
    if not h or not target then return false, 'Data tidak valid.' end

    local item = ox:GetSlot(targetSrc, tonumber(slot) or -1)
    if not item or item.name ~= h.item then return false, ('%s tidak ditemukan di inventory target.'):format(h.label) end
    if not ox:RemoveItem(targetSrc, h.item, 1, nil, item.slot) then return false, 'Gagal mengambil dokumen.' end

    local meta = item.metadata or {}
    local cid = target.PlayerData.citizenid
    local officerCid, officerName = officerInfo(officerSrc)
    local t = insertTicket({
        cid = cid, name = City.fullName(target), phone = phoneOf(cid), kind = kind, item = h.item, metadata = meta,
        vehicleId = kind == 'stnk' and tonumber(meta.vehicleId) or nil,
        plate = kind == 'stnk' and meta.plate or nil, model = kind == 'stnk' and meta.model or nil,
        price = h.price, reason = cleanNote(note) or ('%s ditahan'):format(h.label),
        officerCid = officerCid, officerName = officerName,
    })
    if not t then
        ox:AddItem(targetSrc, h.item, 1, meta) -- jangan sampai dokumen hilang kalau DB gagal
        return false, 'Gagal menyimpan tilang.'
    end

    City.mail(cid, 'Kepolisian: Dokumen Ditahan', {
        ('%s Anda ditahan polisi%s.'):format(h.label, t.plate and (' (plat %s)'):format(t.plate) or ''),
        '',
        ('Tebus di loket Kantor Polisi sebesar Rp %d. Petugas akan menyerahkan kembali dokumen Anda.'):format(t.price),
        ('Alasan: %s'):format(t.reason),
        ('Petugas: %s'):format(officerName or '-'),
    })
    return true, ('%s milik %s ditahan.'):format(h.label, t.name)
end)

---Lisensi dicabut polisi: kartu yang sedang ditahan (tilang) ikut hangus, tidak bisa ditebus lagi.
exports('ForfeitItem', function(cid, item)
    if not allowed() then return end
    for _, t in pairs(Open) do
        if t.cid == cid and t.item == item and t.status == 'held' then closeTicket(t, 'forfeited', 'Lisensi dicabut') end
    end
end)

---Kendaraan yang sudah disita (state impound) dicatat untuk ditebus.
---@param v { id: integer, citizenid: string, plate: string, vehicle: string }
exports('HoldVehicle', function(officerSrc, v, reasonIndex)
    if not allowed() or type(v) ~= 'table' then return false end
    local reason = tcfg.vehicleReasons[tonumber(reasonIndex) or 0]
    if not reason then return false, 'Alasan tidak valid.' end

    for _, t in pairs(Open) do
        if t.kind == 'vehicle' and t.vehicleId == v.id then return true, 'Kendaraan ini sudah tercatat disita.' end
    end

    local charinfo = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { v.citizenid })
    local ci = charinfo and json.decode(charinfo) or {}
    local officerCid, officerName = officerInfo(officerSrc)
    local t = insertTicket({
        cid = v.citizenid, name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''), phone = phoneOf(v.citizenid),
        kind = 'vehicle', vehicleId = v.id, plate = v.plate, model = v.vehicle,
        price = reason.price, reason = reason.label, officerCid = officerCid, officerName = officerName,
    })
    if not t then return false, 'Gagal menyimpan tilang.' end

    City.mail(v.citizenid, 'Kepolisian: Kendaraan Disita', {
        ('Kendaraan %s (%s) Anda disita polisi.'):format(City.vehicleLabel(v.vehicle), v.plate),
        '',
        ('Tebus di loket Kantor Polisi sebesar Rp %d, lalu ambil kendaraan di Impound Lot.'):format(t.price),
        ('Alasan: %s'):format(t.reason),
        ('Petugas: %s'):format(officerName or '-'),
    })
    return true, ('Kendaraan %s disita.'):format(v.plate)
end)

---Denda: total dari jenis denda yang dipilih, ditagihkan ke HP target.
exports('IssueFine', function(officerSrc, targetSrc, indexes)
    if not allowed() or type(indexes) ~= 'table' then return false end
    local target = City.getPlayer(targetSrc)
    if not target then return false, 'Target tidak valid.' end
    if not Invoice.Available() then return false, 'Tagihan HP sedang tidak tersedia.' end

    local labels, total, seen = {}, 0, {}
    for _, i in ipairs(indexes) do
        local f = tcfg.fines[tonumber(i) or 0]
        if f and not seen[f] then
            seen[f] = true
            labels[#labels + 1] = f.label
            total += f.price
        end
    end
    if total <= 0 then return false, 'Pilih jenis denda.' end

    local cid, name = target.PlayerData.citizenid, City.fullName(target)
    local office = config.offices[tcfg.office]
    local reason = table.concat(labels, ', ')
    local invoiceId = Invoice.Create(targetSrc, office, cid, name, total, ('Denda Tilang · %s'):format(office.label), reason:sub(1, 200))
    if not invoiceId then return false, 'Gagal membuat tagihan.' end

    local officerCid, officerName = officerInfo(officerSrc)
    insertTicket({
        cid = cid, name = name, phone = phoneOf(cid), kind = 'fine', price = total, reason = reason,
        invoice = invoiceId, status = 'unpaid', officerCid = officerCid, officerName = officerName,
    })
    return true, ('Denda Rp %d dikirim ke HP %s.'):format(total, name), total
end)

---------------------------------------------------------------------------
-- Tab Tilang di meja petugas polisi
---------------------------------------------------------------------------
local function policeStaff(src)
    local player, office = City.staffOf(src)
    if not player or office.key ~= tcfg.office then return end
    return player
end

lib.callback.register('f_cityhall:getTickets', function(src)
    local player = policeStaff(src)
    if not player then return false end
    syncFines()
    syncVehicles()

    local list = {}
    for _, t in pairs(Open) do
        local detail = t.reason
        if t.kind == 'stnk' then detail = ('Plat %s · %s'):format(t.plate or '-', t.reason or '')
        elseif t.kind == 'vehicle' then detail = ('%s · %s · %s'):format(City.vehicleLabel(t.model), t.plate or '-', t.reason or '') end
        list[#list + 1] = {
            id = t.id, kind = t.kind, name = t.name, phone = t.phone, condition = CONDITION[t.kind],
            detail = detail, price = t.price, created = t.created, officer = t.officerName,
        }
    end
    table.sort(list, function(a, b) return a.created > b.created end)
    return { tickets = list, canManage = player.PlayerData.job.grade.level >= tcfg.manageGrade }
end)

lib.callback.register('f_cityhall:ticketAction', function(src, id, action)
    if not City.throttle(src, 'ticket', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player = policeStaff(src)
    if not player then return { ok = false, msg = 'Kamu harus on duty.' } end
    if player.PlayerData.job.grade.level < tcfg.manageGrade then return { ok = false, msg = 'Pangkatmu belum cukup.' } end

    local t = Open[tonumber(id)]
    if not t then return { ok = false, msg = 'Tilang tidak ditemukan.' } end
    local by = City.fullName(player)
    local tsrc = City.sourceByCid(t.cid)

    if action == 'delete' then
        if t.kind == 'vehicle' then return { ok = false, msg = 'Kendaraan tidak bisa dihapus, gunakan Kembalikan.' } end
        if t.kind == 'fine' then
            Invoice.Cancel(t.invoice, tsrc)
            closeTicket(t, 'cancelled', by)
            City.mail(t.cid, 'Kepolisian: Denda Dibatalkan', { ('Denda tilang Rp %d Anda dibatalkan.'):format(t.price) })
            return { ok = true, msg = 'Denda dibatalkan.' }
        end
        closeTicket(t, 'forfeited', by)
        City.mail(t.cid, 'Kepolisian: Dokumen Hangus', {
            ('%s Anda yang ditahan polisi dinyatakan hangus.'):format(KIND_LABEL[t.kind]),
            'Silakan ajukan pembuatan baru di loket Kantor Polisi.',
        })
        return { ok = true, msg = ('%s milik %s dihapus.'):format(KIND_LABEL[t.kind], t.name) }
    end

    if action == 'return' then
        if t.kind == 'fine' then return { ok = false, msg = 'Gunakan Hapus untuk membatalkan denda.' } end
        local ok, msg, line = giveBack(t, tsrc)
        if not ok then return { ok = false, msg = msg } end
        closeTicket(t, 'returned', by)
        City.mail(t.cid, 'Kepolisian: Tilang Dibatalkan', { line, '', ('Petugas: %s'):format(by) })
        return { ok = true, msg = msg }
    end

    return { ok = false, msg = 'Aksi tidak valid.' }
end)

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS police_tickets (
            id           INT          NOT NULL AUTO_INCREMENT,
            citizenid    VARCHAR(50)  NOT NULL,
            name         VARCHAR(128) DEFAULT NULL,
            phone        VARCHAR(20)  DEFAULT NULL,
            kind         VARCHAR(10)  NOT NULL,
            item         VARCHAR(32)  DEFAULT NULL,
            metadata     LONGTEXT     DEFAULT NULL,
            vehicle_id   INT          DEFAULT NULL,
            plate        VARCHAR(16)  DEFAULT NULL,
            model        VARCHAR(64)  DEFAULT NULL,
            price        BIGINT       NOT NULL,
            reason       VARCHAR(255) DEFAULT NULL,
            officer_cid  VARCHAR(50)  DEFAULT NULL,
            officer_name VARCHAR(128) DEFAULT NULL,
            invoice_id   VARCHAR(48)  DEFAULT NULL,
            status       VARCHAR(10)  NOT NULL,
            handled_by   VARCHAR(128) DEFAULT NULL,
            created_at   INT          NOT NULL,
            updated_at   INT          NOT NULL,
            PRIMARY KEY (id),
            INDEX idx_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    for _, row in ipairs(MySQL.query.await("SELECT * FROM police_tickets WHERE status IN ('held', 'unpaid')") or {}) do
        local t = {
            id = row.id, cid = row.citizenid, name = row.name, phone = row.phone, kind = row.kind, item = row.item,
            metadata = row.metadata and json.decode(row.metadata) or nil, vehicleId = row.vehicle_id, plate = row.plate,
            model = row.model, price = row.price, reason = row.reason, officerCid = row.officer_cid,
            officerName = row.officer_name, invoice = row.invoice_id, status = row.status, created = row.created_at,
        }
        Open[t.id] = t
        if t.invoice then ByInvoice[t.invoice] = t.id end
    end
    if GetResourceState('f_phone') == 'started' then syncFines() end
end)
