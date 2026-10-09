local config = require 'config.shared'
local offices, rules = config.offices, config.rules
local ox = exports.ox_inventory
local DAY = 86400

local Docs, DocOrder = {}, {}
for i, d in ipairs(config.documents) do
    Docs[d.key] = d
    DocOrder[i] = d
end

local OfficeByJob = {}
for key, office in pairs(offices) do
    office.key = key
    OfficeByJob[office.job] = key
end

local ACTION_LABEL = { new = 'Baru', renew = 'Perpanjang', lost = 'Hilang', pay = 'Bayar', redeem = 'Tebus' }

local Prices = {}    -- [priceKey] = value set by the boss (falls back to config defaults)
local Requests = {}  -- [id] = request; only 'unpaid' and 'paid' are kept in memory
local ByInvoice = {} -- [invoiceId] = { requestId, ... }
local Cooldowns = {}
local Vehicles = {}  -- qbx shared vehicles by model

---------------------------------------------------------------------------
-- Util
---------------------------------------------------------------------------
local function getPlayer(src) return exports.qbx_core:GetPlayer(src) end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end

local function near(src, point, dist)
    local c = coordsOf(src)
    return c ~= nil and #(c - point) <= dist
end

local function throttle(src, action, ms)
    local key = src .. ':' .. action
    local now = GetGameTimer()
    if Cooldowns[key] and now - Cooldowns[key] < ms then return false end
    Cooldowns[key] = now
    return true
end

local function fullName(player)
    local c = player.PlayerData.charinfo or {}
    return ('%s %s'):format(c.firstname or '', c.lastname or '')
end

local function sourceByCid(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source
end

local function formatDate(ts) return ts and os.date('%d-%m-%Y', ts) or '-' end

local function dutyList(job)
    local count, list = exports.qbx_core:GetDutyCountJob(job)
    return count or 0, list or {}
end

local function notify(src, msg, typ, duration)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Layanan Publik', description = msg, type = typ or 'info', duration = duration })
end

local function vehicleLabel(model)
    local v = Vehicles[model]
    if not v then return model end
    return (v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. v.name
end

---On-duty staff of `office` (optionally the boss only)
---@return table? player, table? office
local function staffOf(src, needDuty)
    local player = getPlayer(src)
    if not player then return end
    local job = player.PlayerData.job
    local officeKey = OfficeByJob[job.name]
    if not officeKey then return end
    if needDuty ~= false and not job.onduty then return end
    return player, offices[officeKey]
end

---Email through f_phone Mail, falling back to a phone/ox notification when the citizen has no mail account
local function mail(cid, subject, lines)
    local body = table.concat(lines, '\n')
    local src = sourceByCid(cid)

    local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(cid) end)
    if okA and type(addresses) == 'table' and #addresses > 0 then
        local to = {}
        for i = 1, #addresses do to[i] = addresses[i].email end
        local okS, res = pcall(function()
            return exports['f_phone']:sendMail({ to = to, subject = subject, body = body, from = { name = config.mailFrom, email = '' } })
        end)
        if okS and res and (res.delivered or 0) > 0 then return end
    end

    if src then
        pcall(function()
            exports['f_phone']:notify(src, { appId = 'mail', app = 'Mail', title = subject, body = lines[1], time = 'now' })
        end)
        notify(src, lines[1], 'info', 10000)
    end
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
local function priceKey(doc, action) return doc.key .. ':' .. action end

local function defaultPrice(key)
    local docKey, field = key:match('^(.-):(.+)$')
    local d = docKey and Docs[docKey]
    if not d then return end
    if d.kind == 'tax' then return field == 'percent' and d.percent or nil end
    return d.price and d.price[field]
end

local function getPrice(key)
    local value = Prices[key] or defaultPrice(key)
    if value and not key:find(':percent$') then value = math.floor(value) end
    return value
end

local function taxPrice(model)
    local d = Docs.tax
    local v = Vehicles[model]
    local amount = math.floor((v and tonumber(v.price) or 0) * getPrice('tax:percent') / 100)
    return math.max(d.min, math.min(d.max, amount))
end

---------------------------------------------------------------------------
-- Citizen data
---------------------------------------------------------------------------
local function licenseSlot(src, item)
    local found = ox:Search(src, 'slots', item)
    return found and found[1]
end

local function hasStnk(src, vehicleId, version)
    for _, slot in ipairs(ox:Search(src, 'slots', 'stnk') or {}) do
        local m = slot.metadata
        if m and tonumber(m.vehicleId) == vehicleId and m.version == version then return true end
    end
    return false
end

local VEHICLE_QUERY = [[
    SELECT pv.id, pv.vehicle, pv.plate, pv.citizenid, r.version, r.citizenid AS reg_cid, r.plate_expire, r.tax_expire
    FROM player_vehicles pv
    LEFT JOIN vehicle_registrations r ON r.vehicle_id = pv.id
]]

local function ownedVehicles(cid)
    return MySQL.query.await(VEHICLE_QUERY .. ' WHERE pv.citizenid = ? ORDER BY pv.id', { cid }) or {}
end

local function renewBlocked(expire)
    if expire and expire - os.time() > rules.renewWindowDays * DAY then
        return ('Bisa diperpanjang %d hari sebelum habis'):format(rules.renewWindowDays)
    end
end

local function pendingOf(cid)
    local set, unpaid = {}, nil
    for _, r in pairs(Requests) do
        if r.citizenid == cid then
            set[r.doc .. ':' .. (r.vehicleId or 0)] = r.status
            if r.status == 'unpaid' then unpaid = r end
        end
    end
    return set, unpaid
end

---Every service the citizen can see at `officeKey`, with the action and price decided server-side
local function buildCatalog(src, officeKey)
    local player = getPlayer(src)
    local cid = player.PlayerData.citizenid
    local pending = pendingOf(cid)
    local issued = player.PlayerData.metadata.issuedDocs or {}
    local entries, vehicles = {}, nil

    local function add(e)
        e.id = e.doc .. ':' .. (e.vehicleId or 0)
        if pending[e.id] then
            e.disabled = pending[e.id] == 'unpaid' and 'Menunggu pembayaran' or 'Sedang diproses petugas'
        end
        e.actionLabel = ACTION_LABEL[e.action]
        entries[#entries + 1] = e
    end

    for _, d in ipairs(DocOrder) do
        if d.office == officeKey then
            if d.kind == 'redeem' then
                -- one entry per held ticket; vehicleId carries the ticket id through the request row
                for _, t in ipairs(Tickets.heldFor(cid)) do
                    add({
                        doc = d.key, action = 'redeem', vehicleId = t.id, price = t.price,
                        category = 'redeem',
                        model = t.model, plate = t.plate,
                        label = Tickets.title(t),
                        sub = ('Ditahan %s · %s'):format(formatDate(t.created), t.reason or '-'),
                    })
                end
            elseif d.kind == 'license' then
                local e = { doc = d.key, label = d.label, category = 'license' }
                local slot = licenseSlot(src, d.item)
                local licences = player.PlayerData.metadata.licences or {}
                if Tickets.isItemHeld(cid, d.item) then
                    -- held by police: only the redemption above, no replacement card
                    e.action, e.sub, e.disabled = 'lost', 'Sedang ditahan polisi', 'Tebus lewat Penebusan Tilang'
                elseif d.meta and licences[d.meta] == false and (slot or issued[d.key]) then
                    -- revoked by police: renewing is not possible, the citizen has to apply again
                    e.action, e.sub = 'new', 'Lisensi dicabut · pengajuan ulang'
                elseif slot then
                    local exp = tonumber(slot.metadata and slot.metadata.expireDate)
                    e.action = 'renew'
                    e.sub = exp and ('Berlaku s/d %s'):format(formatDate(exp)) or 'Perpanjang masa berlaku'
                    e.disabled = renewBlocked(exp)
                else
                    e.action = issued[d.key] and 'lost' or 'new'
                    e.sub = e.action == 'lost' and 'Penggantian kartu hilang' or 'Pembuatan pertama'
                end
                e.price = getPrice(priceKey(d, e.action))
                add(e)
            else
                vehicles = vehicles or ownedVehicles(cid)
                for _, v in ipairs(vehicles) do
                    local registered = v.version ~= nil and v.reg_cid == cid
                    local e = {
                        doc = d.key, vehicleId = v.id, model = v.vehicle, plate = v.plate, category = 'vehicle',
                        label = ('%s · %s'):format(d.label, vehicleLabel(v.vehicle)),
                    }
                    if d.kind == 'stnk' then
                        if Tickets.isStnkHeld(v.id) then
                            e.action, e.sub = 'lost', ('Plat %s · STNK ditahan polisi'):format(v.plate)
                            e.disabled = 'Tebus lewat Penebusan Tilang'
                        elseif not registered then
                            e.action, e.sub = 'new', ('Plat %s · belum punya STNK'):format(v.plate)
                        elseif hasStnk(src, v.id, v.version) then
                            e.action, e.sub = 'renew', ('Plat %s · berlaku s/d %s'):format(v.plate, formatDate(v.plate_expire))
                            e.disabled = renewBlocked(v.plate_expire)
                        else
                            e.action, e.sub = 'lost', ('Plat %s · penggantian STNK hilang'):format(v.plate)
                        end
                        e.price = getPrice(priceKey(d, e.action))
                    else
                        e.action, e.price = 'pay', taxPrice(v.vehicle)
                        if not registered then
                            e.sub, e.disabled = ('Plat %s'):format(v.plate), 'Buat STNK dulu di kantor polisi'
                        else
                            e.sub = v.tax_expire and ('Plat %s · pajak s/d %s'):format(v.plate, formatDate(v.tax_expire))
                                or ('Plat %s · belum bayar pajak'):format(v.plate)
                            e.disabled = renewBlocked(v.tax_expire)
                        end
                    end
                    add(e)
                end
            end
        end
    end
    return entries
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
local function saveStatus(r)
    MySQL.prepare('UPDATE cityhall_requests SET status = ?, handled_by = ?, note = ?, updated_at = ? WHERE id = ?',
        { r.status, r.handledBy, r.note, os.time(), r.id })
    if r.status ~= 'unpaid' and r.status ~= 'paid' then
        Requests[r.id] = nil
    end
end

local function refreshStaff(office)
    local _, list = dutyList(office.job)
    for _, s in ipairs(list) do TriggerClientEvent('f_cityhall:client:refresh', s) end
end

local function newCode()
    return ('LP%05d'):format(math.random(0, 99999))
end

local function createRequests(lines, office, cid, name, method, status, invoiceId, code)
    local now, list = os.time(), {}
    for _, e in ipairs(lines) do
        local id = MySQL.insert.await([[
            INSERT INTO cityhall_requests (order_code, citizenid, name, office, doc, action, vehicle_id, vehicle_label, plate,
                price, method, status, invoice_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { code, cid, name, office.key, e.doc, e.action, e.vehicleId, e.vehicleId and vehicleLabel(e.model) or nil, e.plate,
              e.price, method, status, invoiceId, now, now })
        local r = {
            id = id, code = code, citizenid = cid, name = name, office = office.key, doc = e.doc, action = e.action,
            vehicleId = e.vehicleId, vehicleLabel = e.vehicleId and vehicleLabel(e.model) or nil, plate = e.plate,
            price = e.price, method = method, status = status, invoice = invoiceId, created = now,
        }
        Requests[id] = r
        list[#list + 1] = r
    end
    if invoiceId then
        local ids = {}
        for i, r in ipairs(list) do ids[i] = r.id end
        ByInvoice[invoiceId] = ids
    end
    return list
end

local function requestTitle(r)
    local d = Docs[r.doc]
    if d.kind == 'redeem' then
        local t = Tickets.get(r.vehicleId)
        return t and Tickets.title(t) or d.label
    end
    local title = ('%s (%s)'):format(d.label, ACTION_LABEL[r.action])
    if r.plate then title = ('%s · %s'):format(title, r.plate) end
    return title
end

local function onPaid(list)
    if #list == 0 then return end
    local office = offices[list[1].office]
    local titles = {}
    for i, r in ipairs(list) do
        r.status = 'paid'
        r.paidAt = os.time()
        saveStatus(r)
        titles[i] = requestTitle(r)
    end

    local first = list[1]
    local src = sourceByCid(first.citizenid)
    local staffCount, staff = dutyList(office.job)

    if staffCount > 0 then
        if src then notify(src, ('Pembayaran #%s diterima. Silakan tunggu petugas di loket.'):format(first.code), 'success', 8000) end
        local message = ('Permohonan baru: %s — %s'):format(table.concat(titles, ', '), first.name)
        for _, s in ipairs(staff) do
            notify(s, message, 'info', 10000)
            pcall(function()
                exports['f_phone']:notify(s, { appId = 'services', app = office.label, title = 'Permohonan Baru', body = message, time = 'now' })
            end)
            TriggerClientEvent('f_cityhall:client:refresh', s)
        end
    else
        mail(first.citizenid, ('%s: Petugas sedang tidak bertugas'):format(office.label), {
            ('Pembayaran #%s untuk %s sudah kami terima.'):format(first.code, table.concat(titles, ', ')),
            '',
            'Saat ini petugas sedang tidak bertugas. Silakan datang kembali ke loket saat petugas administrasi sudah bertugas untuk menyelesaikan permohonan Anda.',
        })
    end
end

AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' then return end
    local ids = ByInvoice[data.id]
    if not ids then return end
    ByInvoice[data.id] = nil
    local list = {}
    for _, id in ipairs(ids) do
        local r = Requests[id]
        if r and r.status == 'unpaid' then list[#list + 1] = r end
    end
    onPaid(list)
end)

local function checkInvoice(invoiceId, ids)
    local sample = Requests[ids[1]]
    if not sample then ByInvoice[invoiceId] = nil return end

    local status = Invoice.Status(invoiceId)
    local expired = os.time() - sample.created >= rules.invoiceTimeout * 60
    if status == 'pending' and not expired then return end

    local src = sourceByCid(sample.citizenid)
    if status == 'pending' and not Invoice.Cancel(invoiceId, src) then status = Invoice.Status(invoiceId) end

    ByInvoice[invoiceId] = nil
    local list = {}
    for _, id in ipairs(ids) do
        local r = Requests[id]
        if r and r.status == 'unpaid' then list[#list + 1] = r end
    end

    if status == 'paid' then return onPaid(list) end
    for _, r in ipairs(list) do
        r.status = 'cancelled'
        saveStatus(r)
    end
    if src then notify(src, ('Tagihan #%s kedaluwarsa dan dibatalkan.'):format(sample.code), 'error') end
end

---No polling loop: a citizen's own unpaid invoice is only re-checked (1 query) when they come back
---to a counter. Payments normally arrive instantly through the invoicePaid event above.
local function syncUnpaid(cid)
    for invoiceId, ids in pairs(ByInvoice) do
        local r = Requests[ids[1]]
        if r and r.citizenid == cid then checkInvoice(invoiceId, ids) end
    end
end

---------------------------------------------------------------------------
-- Citizen callbacks
---------------------------------------------------------------------------
lib.callback.register('f_cityhall:getServices', function(src, officeKey)
    local office = offices[officeKey]
    if not office or not near(src, office.counter, rules.counterDistance + 2.0) then return end

    local player = getPlayer(src)
    if not player then return end
    syncUnpaid(player.PlayerData.citizenid)
    local _, unpaid = pendingOf(player.PlayerData.citizenid)

    return {
        label = office.label,
        subtitle = office.subtitle,
        entries = buildCatalog(src, officeKey),
        transfer = Invoice.Available(),
        maxCart = rules.maxCart,
        unpaid = unpaid and unpaid.code or nil,
        closed = dutyList(office.job) == 0, -- services can be browsed, paying is blocked
        redeem = office.key == config.tickets.office, -- show the Penebusan tab even when empty
    }
end)

lib.callback.register('f_cityhall:placeOrder', function(src, officeKey, ids, method)
    if not throttle(src, 'order', 3000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local office = offices[officeKey]
    if not office then return { ok = false, msg = 'Loket tidak valid.' } end
    if method ~= 'cash' and method ~= 'transfer' then return { ok = false, msg = 'Metode pembayaran tidak valid.' } end
    if not near(src, office.counter, rules.counterDistance + 2.0) then return { ok = false, msg = 'Kamu harus berada di loket.' } end
    if dutyList(office.job) == 0 then
        return { ok = false, msg = 'Pelayanan sedang tutup. Silakan datang kembali saat petugas administrasi sudah bertugas.' }
    end
    if type(ids) ~= 'table' or #ids == 0 or #ids > rules.maxCart then return { ok = false, msg = 'Keranjang tidak valid.' } end

    local player = getPlayer(src)
    if not player then return { ok = false } end
    local cid, name = player.PlayerData.citizenid, fullName(player)
    syncUnpaid(cid)
    local _, unpaid = pendingOf(cid)
    if unpaid then return { ok = false, msg = ('Selesaikan dulu tagihan #%s.'):format(unpaid.code) } end

    local byId = {}
    for _, e in ipairs(buildCatalog(src, officeKey)) do byId[e.id] = e end

    local lines, seen, total = {}, {}, 0
    for _, id in ipairs(ids) do
        if type(id) ~= 'string' or seen[id] then return { ok = false, msg = 'Keranjang tidak valid.' } end
        seen[id] = true
        local e = byId[id]
        if not e or e.disabled then return { ok = false, msg = ('%s tidak bisa diajukan.'):format(e and e.label or 'Layanan') } end
        lines[#lines + 1] = e
        total += e.price
    end

    -- balance is checked up front so no request is created that the citizen cannot pay for
    local balance = tonumber(player.PlayerData.money[method == 'cash' and 'cash' or 'bank']) or 0
    if balance < total then
        return { ok = false, msg = ('Saldo %s kamu tidak cukup (butuh Rp %d).'):format(method == 'cash' and 'cash' or 'bank', total) }
    end

    local code = newCode()
    if method == 'cash' then
        if not player.Functions.RemoveMoney('cash', total, 'layanan-publik') then
            return { ok = false, msg = ('Uang cash kamu kurang (Rp %d).'):format(total) }
        end
        Society.Add(office.job, total, ('Permohonan #%s (cash)'):format(code), name)
        onPaid(createRequests(lines, office, cid, name, 'cash', 'unpaid', nil, code))
        return { ok = true, paid = true, code = code }
    end

    if not Invoice.Available() then return { ok = false, msg = 'Pembayaran transfer sedang tidak tersedia.' } end
    local invoiceId = Invoice.Create(src, office, cid, name, total, ('%s · #%s'):format(office.label, code), ('Permohonan #%s'):format(code))
    if not invoiceId then return { ok = false, msg = 'Gagal membuat tagihan.' } end
    createRequests(lines, office, cid, name, 'transfer', 'unpaid', invoiceId, code)
    return { ok = true, paid = false, code = code, timeout = rules.invoiceTimeout }
end)

---------------------------------------------------------------------------
-- Staff: request list, approve, reject
---------------------------------------------------------------------------
lib.callback.register('f_cityhall:getRequests', function(src)
    local player, office = staffOf(src)
    if not player then return false end

    local myCoords = coordsOf(src)
    local list = {}
    for _, r in pairs(Requests) do
        if r.status == 'paid' and r.office == office.key then
            local tsrc = sourceByCid(r.citizenid)
            local tc = tsrc and coordsOf(tsrc)
            list[#list + 1] = {
                id = r.id, code = r.code, name = r.name, title = requestTitle(r), vehicle = r.vehicleLabel,
                action = r.action, price = r.price, method = r.method, time = r.paidAt or r.created,
                online = tsrc ~= nil, near = tc ~= nil and myCoords ~= nil and #(tc - myCoords) <= rules.handoverDistance,
            }
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)

    local job = player.PlayerData.job
    return {
        label = office.label,
        requests = list,
        isBoss = job.isboss == true,
        dutyToggle = rules.dutyToggleJobs[job.name] == true,
        tickets = office.key == config.tickets.office,
    }
end)

local function grantLicenceMeta(target, meta)
    if not meta then return end
    local licences = target.PlayerData.metadata.licences or {}
    if licences[meta] then return end
    licences[meta] = true
    target.Functions.SetMetaData('licences', licences)
end

local function markIssued(target, docKey)
    local issued = target.PlayerData.metadata.issuedDocs or {}
    if issued[docKey] then return end
    issued[docKey] = true
    target.Functions.SetMetaData('issuedDocs', issued)
end

---Carries out an approved request. Returns ok, message (for the officer), mail line (for the citizen)
local function fulfil(r, tsrc, target)
    local d = Docs[r.doc]
    local now = os.time()

    if d.kind == 'redeem' then
        return Tickets.redeem(r.vehicleId, tsrc, r.citizenid)
    end

    if d.kind == 'license' then
        if r.action == 'renew' then
            local exp = exports.f_idcard:ExtendLicense(tsrc, d.item)
            if not exp then return false, 'Pemohon tidak membawa kartu yang akan diperpanjang.' end
            return true, ('%s diperpanjang.'):format(d.label), ('%s Anda telah diperpanjang dan berlaku hingga %s.'):format(d.label, formatDate(exp))
        end
        if d.meta and r.action ~= 'lost' then
            -- re-application after a revoke: take back the old (revoked) cards
            local old = ox:GetItemCount(tsrc, d.item) or 0
            if old > 0 then ox:RemoveItem(tsrc, d.item, old) end
        end
        if not ox:CanCarryItem(tsrc, d.item, 1) then return false, 'Inventory pemohon penuh.' end
        exports.f_idcard:CreateMetaLicense(tsrc, d.item)
        markIssued(target, d.key)
        grantLicenceMeta(target, d.meta)
        return true, ('%s diserahkan.'):format(d.label), ('%s Anda sudah diterbitkan dan diserahkan oleh petugas.'):format(d.label)
    end

    local v = MySQL.single.await(VEHICLE_QUERY .. ' WHERE pv.id = ?', { r.vehicleId })
    if not v or v.citizenid ~= r.citizenid then return false, 'Kendaraan ini sudah bukan milik pemohon. Silakan reject.' end
    local registered = v.version ~= nil and v.reg_cid == r.citizenid
    local label = vehicleLabel(v.vehicle)

    if d.kind == 'tax' then
        if not registered then return false, 'Kendaraan belum punya STNK. Silakan reject.' end
        local exp = math.max(now, v.tax_expire or 0) + rules.taxDays * DAY
        MySQL.update.await('UPDATE vehicle_registrations SET tax_expire = ? WHERE vehicle_id = ?', { exp, v.id })
        return true, 'Pajak kendaraan dibayar.', ('Pajak kendaraan %s (%s) sudah dibayar dan berlaku hingga %s.'):format(label, v.plate, formatDate(exp))
    end

    -- STNK
    if r.action == 'renew' then
        if not registered then return false, 'STNK kendaraan ini tidak terdaftar. Silakan reject.' end
        local exp = math.max(now, v.plate_expire or 0) + rules.plateDays * DAY
        MySQL.update.await('UPDATE vehicle_registrations SET plate_expire = ? WHERE vehicle_id = ?', { exp, v.id })
        return true, 'Masa berlaku plat diperpanjang.', ('Masa berlaku plat %s (%s) diperpanjang hingga %s.'):format(v.plate, label, formatDate(exp))
    end

    if not ox:CanCarryItem(tsrc, 'stnk', 1) then return false, 'Inventory pemohon penuh.' end
    local version = (v.version or 0) + 1
    if registered and r.action == 'lost' then
        MySQL.update.await('UPDATE vehicle_registrations SET version = ? WHERE vehicle_id = ?', { version, v.id })
    else
        -- first registration, or a new owner registering the vehicle in their name
        MySQL.prepare.await([[
            INSERT INTO vehicle_registrations (vehicle_id, citizenid, version, plate_expire, tax_expire, issued_at)
            VALUES (?, ?, ?, ?, NULL, ?)
            ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), version = VALUES(version),
                plate_expire = VALUES(plate_expire), tax_expire = NULL, issued_at = VALUES(issued_at)
        ]], { v.id, r.citizenid, version, now + rules.plateDays * DAY, now })
    end

    ox:AddItem(tsrc, 'stnk', 1, {
        vehicleId = v.id, version = version, citizenid = r.citizenid, owner = r.name,
        model = v.vehicle, vehicle = label, plate = v.plate, issued = now,
        description = ('%s · %s · a.n. %s'):format(v.plate, label, r.name),
    })
    local extra = r.action == 'lost' and ' STNK lama Anda sudah tidak berlaku.' or ' Jangan lupa membayar pajak kendaraan di Balai Kota.'
    return true, 'STNK diserahkan.', ('STNK kendaraan %s (%s) sudah diterbitkan.%s'):format(label, v.plate, extra)
end

lib.callback.register('f_cityhall:approve', function(src, id)
    if not throttle(src, 'handle', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, office = staffOf(src)
    if not player then return { ok = false, msg = 'Kamu harus on duty.' } end

    local r = Requests[tonumber(id)]
    if not r or r.status ~= 'paid' or r.office ~= office.key then return { ok = false, msg = 'Permohonan tidak ditemukan.' } end
    if r.citizenid == player.PlayerData.citizenid then return { ok = false, msg = 'Permohonan milikmu harus diproses petugas lain.' } end

    local tsrc = sourceByCid(r.citizenid)
    if not tsrc then return { ok = false, msg = 'Pemohon sedang tidak ada di kota.' } end
    local a, b = coordsOf(src), coordsOf(tsrc)
    if not a or not b or #(a - b) > rules.handoverDistance then return { ok = false, msg = 'Pemohon harus berdiri di dekatmu.' } end

    local target = getPlayer(tsrc)
    local ok, msg, mailLine = fulfil(r, tsrc, target)
    if not ok then return { ok = false, msg = msg } end

    r.status, r.handledBy = 'approved', fullName(player)
    saveStatus(r)
    mail(r.citizenid, ('%s: Permohonan disetujui'):format(office.label), {
        mailLine,
        '',
        ('No. permohonan: #%s'):format(r.code),
        ('Petugas: %s'):format(r.handledBy),
    })
    refreshStaff(office)
    return { ok = true, msg = ('%s — %s'):format(msg, r.name) }
end)

lib.callback.register('f_cityhall:reject', function(src, id, reason)
    if not throttle(src, 'handle', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, office = staffOf(src)
    if not player then return { ok = false, msg = 'Kamu harus on duty.' } end

    local r = Requests[tonumber(id)]
    if not r or r.status ~= 'paid' or r.office ~= office.key then return { ok = false, msg = 'Permohonan tidak ditemukan.' } end

    reason = type(reason) == 'string' and reason:gsub('[<>]', ''):match('^%s*(.-)%s*$') or ''
    if #reason < 3 or #reason > 150 then return { ok = false, msg = 'Alasan penolakan 3-150 karakter.' } end

    if not Society.Remove(office.job, r.price, ('Refund #%s'):format(r.code), r.name) then
        return { ok = false, msg = 'Saldo organisasi tidak cukup untuk refund.' }
    end
    local tsrc = sourceByCid(r.citizenid)
    if tsrc then
        getPlayer(tsrc).Functions.AddMoney('bank', r.price, 'refund-layanan-publik')
    else
        exports.qbx_core:AddMoney(r.citizenid, 'bank', r.price, 'refund-layanan-publik')
    end

    r.status, r.handledBy, r.note = 'rejected', fullName(player), reason
    saveStatus(r)
    mail(r.citizenid, ('%s: Permohonan ditolak'):format(office.label), {
        ('Permohonan %s Anda ditolak. Biaya Rp %d sudah dikembalikan ke rekening bank Anda.'):format(requestTitle(r), r.price),
        '',
        ('Alasan: %s'):format(reason),
        ('No. permohonan: #%s'):format(r.code),
        ('Petugas: %s'):format(r.handledBy),
    })
    refreshStaff(office)
    return { ok = true, msg = ('Permohonan %s ditolak dan dana dikembalikan.'):format(r.name) }
end)

lib.callback.register('f_cityhall:toggleDuty', function(src)
    local player = getPlayer(src)
    if not player then return end
    local job = player.PlayerData.job
    local officeKey = OfficeByJob[job.name]
    if not officeKey or not rules.dutyToggleJobs[job.name] then return end
    if not near(src, offices[officeKey].desk, 4.0) then return end

    local goingOnDuty = not job.onduty
    exports.qbx_core:SetJobDuty(src, goingOnDuty)
    notify(src, goingOnDuty and 'Kamu mulai bertugas.' or 'Kamu selesai bertugas.', 'info')
    return goingOnDuty
end)

---------------------------------------------------------------------------
-- Prices (boss only)
---------------------------------------------------------------------------
local function priceList(office)
    local list = {}
    for _, d in ipairs(DocOrder) do
        if d.office == office.key then
            if d.kind == 'tax' then
                list[#list + 1] = {
                    key = 'tax:percent', label = ('%s (%% harga kendaraan)'):format(d.label), percent = true,
                    value = getPrice('tax:percent'), default = d.percent,
                    min = rules.taxPercentRange.min, max = rules.taxPercentRange.max,
                    note = ('Minimal Rp %d, maksimal Rp %d per kendaraan'):format(d.min, d.max),
                }
            elseif d.price then
                for _, action in ipairs({ 'new', 'renew', 'lost' }) do
                    local key, default = priceKey(d, action), d.price[action]
                    list[#list + 1] = {
                        key = key, label = ('%s — %s'):format(d.label, ACTION_LABEL[action]),
                        value = getPrice(key), default = default,
                        min = math.ceil(default * rules.priceRange.min / 100),
                        max = math.floor(default * rules.priceRange.max / 100),
                    }
                end
            end
        end
    end
    return list
end

lib.callback.register('f_cityhall:getPrices', function(src)
    local player, office = staffOf(src)
    if not player or not player.PlayerData.job.isboss then return false end
    return priceList(office)
end)

lib.callback.register('f_cityhall:setPrice', function(src, key, value)
    if not throttle(src, 'price', 800) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, office = staffOf(src)
    if not player or not player.PlayerData.job.isboss then return { ok = false, msg = 'Hanya pimpinan yang bisa mengubah harga.' } end

    local entry
    for _, e in ipairs(priceList(office)) do
        if e.key == key then entry = e break end
    end
    value = tonumber(value)
    if not entry or not value then return { ok = false, msg = 'Data tidak valid.' } end
    value = entry.percent and (math.floor(value * 10 + 0.5) / 10) or math.floor(value)
    if value < entry.min or value > entry.max then
        return { ok = false, msg = ('Harga harus di antara %s dan %s.'):format(entry.min, entry.max) }
    end

    MySQL.prepare.await('INSERT INTO cityhall_prices (price_key, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)', { key, value })
    Prices[key] = value
    return { ok = true, msg = ('%s diubah menjadi %s.'):format(entry.label, entry.percent and (value .. '%') or ('Rp ' .. value)) }
end)

lib.addCommand('permohonan', { help = 'Buka daftar permohonan layanan publik (petugas on duty)' }, function(src)
    if not staffOf(src) then return notify(src, 'Hanya petugas administrasi yang sedang bertugas.', 'error') end
    TriggerClientEvent('f_cityhall:client:openStaff', src)
end)

---------------------------------------------------------------------------
-- Employment (job center at the government counter)
---------------------------------------------------------------------------
lib.callback.register('f_cityhall:server:applyJob', function(source, job)
    if not config.employment.enabled or not config.employment.jobs[job] then return false end
    local player = getPlayer(source)
    if not player then return false end

    local allowed = false
    for _, office in pairs(offices) do
        if office.employment and near(source, office.counter, 20.0) then allowed = true break end
    end
    if not allowed then return false end

    player.Functions.SetJob(job, 0)
    notify(source, 'Selamat atas pekerjaan barumu!', 'success')
    return true
end)

-- shared with server/tickets.lua (police tickets)
City = {
    getPlayer = getPlayer,
    coordsOf = coordsOf,
    throttle = throttle,
    fullName = fullName,
    sourceByCid = sourceByCid,
    formatDate = formatDate,
    vehicleLabel = vehicleLabel,
    notify = notify,
    mail = mail,
    staffOf = staffOf,
}

---------------------------------------------------------------------------
-- Cleanup & init
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for key in pairs(Cooldowns) do
        if key:sub(1, #prefix) == prefix then Cooldowns[key] = nil end
    end
end)

CreateThread(function()
    Vehicles = exports.qbx_core:GetVehiclesByName() or {}

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS vehicle_registrations (
            vehicle_id   INT         NOT NULL,
            citizenid    VARCHAR(50) NOT NULL,
            version      INT         NOT NULL DEFAULT 1,
            plate_expire INT         NOT NULL,
            tax_expire   INT         DEFAULT NULL,
            issued_at    INT         NOT NULL,
            PRIMARY KEY (vehicle_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS cityhall_requests (
            id            INT          NOT NULL AUTO_INCREMENT,
            order_code    VARCHAR(12)  NOT NULL,
            citizenid     VARCHAR(50)  NOT NULL,
            name          VARCHAR(128) DEFAULT NULL,
            office        VARCHAR(20)  NOT NULL,
            doc           VARCHAR(32)  NOT NULL,
            action        VARCHAR(10)  NOT NULL,
            vehicle_id    INT          DEFAULT NULL,
            vehicle_label VARCHAR(64)  DEFAULT NULL,
            plate         VARCHAR(16)  DEFAULT NULL,
            price         BIGINT       NOT NULL,
            method        VARCHAR(10)  NOT NULL,
            status        VARCHAR(10)  NOT NULL,
            invoice_id    VARCHAR(48)  DEFAULT NULL,
            handled_by    VARCHAR(128) DEFAULT NULL,
            note          VARCHAR(255) DEFAULT NULL,
            created_at    INT          NOT NULL,
            updated_at    INT          NOT NULL,
            PRIMARY KEY (id),
            INDEX idx_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS cityhall_prices (
            price_key VARCHAR(32) NOT NULL,
            value     DOUBLE      NOT NULL,
            PRIMARY KEY (price_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT * FROM cityhall_prices') or {}) do
        if defaultPrice(row.price_key) then Prices[row.price_key] = row.value end
    end

    -- finished requests older than 14 days are only history
    MySQL.update.await("DELETE FROM cityhall_requests WHERE status NOT IN ('unpaid', 'paid') AND updated_at < ?", { os.time() - 14 * DAY })
    for _, row in ipairs(MySQL.query.await("SELECT * FROM cityhall_requests WHERE status IN ('unpaid', 'paid')") or {}) do
        if Docs[row.doc] and offices[row.office] then
            local r = {
                id = row.id, code = row.order_code, citizenid = row.citizenid, name = row.name, office = row.office,
                doc = row.doc, action = row.action, vehicleId = row.vehicle_id, vehicleLabel = row.vehicle_label, plate = row.plate,
                price = row.price, method = row.method, status = row.status, invoice = row.invoice_id,
                created = row.created_at, paidAt = row.status == 'paid' and row.updated_at or nil,
            }
            Requests[r.id] = r
            if r.status == 'unpaid' and r.invoice then
                ByInvoice[r.invoice] = ByInvoice[r.invoice] or {}
                table.insert(ByInvoice[r.invoice], r.id)
            end
        end
    end
end)
