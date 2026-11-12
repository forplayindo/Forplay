-- Toko bengkel (server). Konsep seperti apotek EMS & f_cafe:
--  warga pesan di meja bengkel (maks. `limit` item per pembelian, diatur mekanik) -> bayar cash
--  (langsung lunas) atau transfer (invoice f_phone) -> pesanan lunas muncul di menu mekanik ->
--  mekanik menyerahkan barang (pembeli harus dekat) -> item masuk inventory pembeli.
--  Uang masuk rekening organisasi mechanic. Lunas tapi tidak dilayani -> uang kembali otomatis.
local cfg = require 'config.shop'
local jobCfg = require 'config.shared'

---@type table<string, table>
local Orders = {}
---@type table<string, string> invoice id -> code
local ByInvoice = {}
local throttles = {}

local MENU = {}
for _, m in ipairs(cfg.items) do MENU[m.item] = m end

local function notify(src, msg, typ) exports.qbx_core:Notify(src, msg, typ or 'inform', 6000) end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end

local function near(src, point, dist)
    local c = coordsOf(src)
    return c ~= nil and #(c - point) <= dist
end

local function throttle(src, key, ms)
    local now = GetGameTimer()
    local id = src .. key
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == jobCfg.jobType and job.onduty, player
end

local function onDuty()
    return (exports.qbx_core:GetDutyCountType(jobCfg.jobType)) or 0
end

local function sourceOf(cid)
    local p = exports.qbx_core:GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil
end

local function getLimit()
    local v = GetResourceKvpInt('shop_limit')
    return (v and v > 0) and v or cfg.defaultLimit
end

local function lastPurchaseLeft(cid)
    if (cfg.orderCooldown or 0) <= 0 then return 0 end
    local last = GetResourceKvpInt('shop_last_' .. cid) or 0
    return math.max(0, last + cfg.orderCooldown * 60 - os.time())
end

local function societyAdd(amount)
    if amount <= 0 then return end
    pcall(function() exports['f_banking']:addAccountMoney(cfg.job, amount) end)
end

local function societyRemove(amount)
    if amount <= 0 then return end
    pcall(function() exports['f_banking']:removeAccountMoney(cfg.job, amount) end)
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_shop_orders` (
            `code` VARCHAR(10) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL DEFAULT '',
            `order_lines` LONGTEXT NOT NULL,
            `total` BIGINT NOT NULL,
            `method` VARCHAR(10) NOT NULL,
            `status` VARCHAR(12) NOT NULL,
            `invoice_id` VARCHAR(64) NULL,
            `created_at` INT NOT NULL,
            `paid_at` INT NULL,
            `updated_at` INT NOT NULL,
            PRIMARY KEY (`code`),
            INDEX `status_idx` (`status`)
        )
    ]])
    local rows = MySQL.query.await("SELECT * FROM mechanic_shop_orders WHERE status IN ('unpaid', 'paid')") or {}
    for _, r in ipairs(rows) do
        local ok, lines = pcall(json.decode, r.order_lines)
        local o = {
            code = r.code, citizenid = r.citizenid, name = r.name, lines = ok and lines or {}, total = r.total,
            method = r.method, status = r.status, invoice = r.invoice_id, created = r.created_at, paidAt = r.paid_at,
        }
        Orders[o.code] = o
        if o.invoice then ByInvoice[o.invoice] = o.code end
    end
end)

local function saveOrder(o)
    MySQL.prepare.await([[
        INSERT INTO mechanic_shop_orders (code, citizenid, name, order_lines, total, method, status, invoice_id, created_at, paid_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = VALUES(status), paid_at = VALUES(paid_at), updated_at = VALUES(updated_at)
    ]], { o.code, o.citizenid, o.name, json.encode(o.lines), o.total, o.method, o.status, o.invoice, o.created, o.paidAt, os.time() })
end

local function setStatus(o, status)
    o.status = status
    saveOrder(o)
    if status ~= 'unpaid' and status ~= 'paid' then
        Orders[o.code] = nil
        if o.invoice then ByInvoice[o.invoice] = nil end
    end
end

local function newCode()
    local code
    repeat code = ('%04d'):format(math.random(0, 9999)) until not Orders[code]
    return code
end

local function activeOrderOf(cid)
    for _, o in pairs(Orders) do
        if o.citizenid == cid then return o end
    end
end

local function broadcastMechanics(msg)
    local _, sources = exports.qbx_core:GetDutyCountType(jobCfg.jobType)
    for i = 1, #(sources or {}) do notify(sources[i], msg, 'inform') end
end

---------------------------------------------------------------------------
-- Invoice f_phone
---------------------------------------------------------------------------
local function invoiceAvailable() return GetResourceState('f_phone') == 'started' end

local function invoiceCreate(src, player, amount, code)
    if not invoiceAvailable() then return end
    local chars, t = 'abcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 16 do
        local n = math.random(1, #chars)
        t[i] = chars:sub(n, n)
    end
    local id = 'bill_' .. table.concat(t)
    local okNum, number = pcall(function() return exports['f_phone']:getPhoneNumber(src) end)
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, 'pending', ?)
    ]], { id, cfg.job, ('%s · #%s'):format(cfg.label, code), cfg.job, cfg.label,
          player.PlayerData.citizenid, charName(player), okNum and number or nil, amount, ('Pesanan toko bengkel #%s'):format(code), os.time() })
    if not ok then return end
    pcall(function()
        exports['f_phone']:notify(src, { appId = 'bank', app = 'Bank', title = cfg.label,
            body = ('Tagihan Rp %d pesanan toko bengkel #%s. Buka Bank > Invoices untuk membayar.'):format(amount, code), time = 'now' })
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
-- Pesanan
---------------------------------------------------------------------------
local function onPaid(o)
    o.paidAt = os.time()
    setStatus(o, 'paid')
    local src = sourceOf(o.citizenid)
    if src then notify(src, ('Pembayaran #%s diterima. Tunggu mekanik di meja bengkel untuk menyerahkan barang.'):format(o.code), 'success') end
    broadcastMechanics(('Pesanan toko bengkel baru #%s dari %s (Rp %d)'):format(o.code, o.name, o.total))
end

local function refund(o, reason)
    societyRemove(o.total)
    exports.qbx_core:AddMoney(o.citizenid, 'bank', o.total, 'mechanic-shop-refund')
    setStatus(o, 'refunded')
    local src = sourceOf(o.citizenid)
    if src then notify(src, ('Pesanan toko bengkel #%s dibatalkan (%s). Rp %d dikembalikan ke bank.'):format(o.code, reason, o.total), 'error') end
end

lib.callback.register('f_mechanicjob:server:shopMenu', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid
    local active = activeOrderOf(cid)
    return {
        label = cfg.label,
        items = cfg.items,
        limit = getLimit(),
        transfer = invoiceAvailable(),
        cooldown = lastPurchaseLeft(cid),
        staff = onDuty(),
        active = active and { code = active.code, status = active.status, total = active.total, method = active.method } or nil,
    }
end)

lib.callback.register('f_mechanicjob:server:shopOrder', function(src, cart, method)
    if not throttle(src, 'order', 3000) then return { error = 'Tunggu sebentar.' } end
    if method ~= 'cash' and method ~= 'transfer' then return { error = 'Metode pembayaran tidak valid.' } end
    if not near(src, cfg.counter, 4.0) then return { error = 'Kamu harus berada di meja bengkel.' } end
    if onDuty() <= 0 then return { error = 'Tidak ada mekanik yang bertugas. Coba lagi nanti.' } end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan.' } end
    local cid = player.PlayerData.citizenid
    if activeOrderOf(cid) then return { error = 'Kamu masih punya pesanan yang belum selesai.' } end
    local wait = lastPurchaseLeft(cid)
    if wait > 0 then return { error = ('Kamu baru saja membeli. Tunggu %d menit lagi.'):format(math.ceil(wait / 60)) } end

    if type(cart) ~= 'table' then return { error = 'Keranjang tidak valid.' } end
    local lines, total, count = {}, 0, 0
    for item, qty in pairs(cart) do
        local m = MENU[item]
        qty = math.floor(tonumber(qty) or 0)
        if not m or qty < 0 then return { error = 'Keranjang tidak valid.' } end
        if qty > 0 then
            lines[#lines + 1] = { item = m.item, label = m.label, qty = qty, price = m.price }
            total += m.price * qty
            count += qty
        end
    end
    local limit = getLimit()
    if count <= 0 then return { error = 'Keranjang masih kosong.' } end
    if count > limit then return { error = ('Maksimal %d item per pembelian.'):format(limit) } end

    local o = {
        code = newCode(), citizenid = cid, name = charName(player), lines = lines, total = total,
        method = method, status = 'unpaid', created = os.time(),
    }

    if method == 'cash' then
        if exports.ox_inventory:GetItemCount(src, cfg.cashItem) < total then return { error = ('Uang cash kamu kurang (Rp %d).'):format(total) } end
        if not exports.ox_inventory:RemoveItem(src, cfg.cashItem, total) then return { error = 'Gagal mengambil uang cash.' } end
        societyAdd(total)
        Orders[o.code] = o
        onPaid(o)
        return { ok = true, code = o.code, paid = true }
    end

    if not invoiceAvailable() then return { error = 'Pembayaran transfer sedang tidak tersedia.' } end
    local invoiceId = invoiceCreate(src, player, total, o.code)
    if not invoiceId then return { error = 'Gagal membuat invoice.' } end
    o.invoice = invoiceId
    Orders[o.code] = o
    ByInvoice[invoiceId] = o.code
    saveOrder(o)
    return { ok = true, code = o.code, paid = false, timeout = cfg.invoiceTimeout }
end)

lib.callback.register('f_mechanicjob:server:shopCancel', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    local o = player and activeOrderOf(player.PlayerData.citizenid)
    if not o then return { error = 'Tidak ada pesanan.' } end
    if o.status ~= 'unpaid' then return { error = 'Pesanan sudah dibayar, tunggu mekanik.' } end
    if o.invoice and not invoiceCancel(o.invoice, o.citizenid) then
        if invoiceStatus(o.invoice) == 'paid' then onPaid(o) return { error = 'Pesanan sudah dibayar.' } end
    end
    setStatus(o, 'cancelled')
    return { ok = true }
end)

AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' or data.job ~= cfg.job then return end
    local code = ByInvoice[data.id]
    local o = code and Orders[code]
    if not o or o.status ~= 'unpaid' then return end
    onPaid(o)
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, o in pairs(Orders) do
            if o.status == 'unpaid' and o.invoice then
                local status = invoiceStatus(o.invoice)
                if status == 'paid' then
                    onPaid(o)
                elseif now - o.created >= cfg.invoiceTimeout * 60 or status ~= 'pending' then
                    if status ~= 'pending' or invoiceCancel(o.invoice, o.citizenid) then
                        setStatus(o, 'cancelled')
                        local src = sourceOf(o.citizenid)
                        if src then notify(src, ('Invoice pesanan toko bengkel #%s kadaluarsa dan dibatalkan.'):format(o.code), 'error') end
                    elseif invoiceStatus(o.invoice) == 'paid' then
                        onPaid(o)
                    end
                end
            elseif o.status == 'paid' and now - (o.paidAt or o.created) >= cfg.refundAfter * 60 then
                refund(o, 'tidak dilayani mekanik')
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Mekanik
---------------------------------------------------------------------------
local function staffData(src)
    local list = {}
    for _, o in pairs(Orders) do
        if o.status == 'paid' then
            local target = sourceOf(o.citizenid)
            list[#list + 1] = {
                code = o.code, name = o.name, lines = o.lines, total = o.total, method = o.method, time = o.paidAt or o.created,
                online = target ~= nil,
                near = target ~= nil and coordsOf(src) ~= nil and coordsOf(target) ~= nil
                    and #(coordsOf(src) - coordsOf(target)) <= cfg.serveDistance,
            }
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    local _, player = isMechanic(src)
    return {
        orders = list,
        limit = getLimit(),
        maxLimit = cfg.maxLimit,
        canSettings = player ~= nil and player.PlayerData.job.grade.level >= cfg.settingsGrade,
    }
end

lib.callback.register('f_mechanicjob:server:shopStaff', function(src)
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas.' } end
    return staffData(src)
end)

lib.callback.register('f_mechanicjob:server:shopServe', function(src, code)
    if not throttle(src, 'serve', 1500) then return { error = 'Tunggu sebentar.' } end
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas.' } end
    if not near(src, cfg.counter, 10.0) then return { error = 'Kamu harus berada di meja bengkel.' } end

    local o = Orders[tostring(code)]
    if not o or o.status ~= 'paid' then return { error = 'Pesanan tidak ditemukan atau sudah diserahkan.' } end
    local target = sourceOf(o.citizenid)
    if not target then return { error = 'Pembeli sedang tidak ada di kota.' } end
    local a, b = coordsOf(src), coordsOf(target)
    if not a or not b or #(a - b) > cfg.serveDistance then return { error = 'Pembeli harus berdiri dekat kamu.' } end

    local weight = 0
    for _, l in ipairs(o.lines) do
        local def = exports.ox_inventory:Items(l.item)
        weight += (def and def.weight or 0) * l.qty
    end
    if not exports.ox_inventory:CanCarryWeight(target, weight) then return { error = 'Tas pembeli penuh.' } end

    for _, l in ipairs(o.lines) do exports.ox_inventory:AddItem(target, l.item, l.qty) end
    setStatus(o, 'delivered')
    if (cfg.orderCooldown or 0) > 0 then SetResourceKvpInt('shop_last_' .. o.citizenid, os.time()) end

    notify(target, ('Barang pesanan #%s sudah diterima. Terima kasih!'):format(o.code), 'success')
    local data = staffData(src)
    data.msg = ('Pesanan #%s diserahkan ke %s.'):format(o.code, o.name)
    return data
end)

lib.callback.register('f_mechanicjob:server:shopReject', function(src, code)
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas.' } end
    local o = Orders[tostring(code)]
    if not o or o.status ~= 'paid' then return { error = 'Pesanan tidak ditemukan.' } end
    refund(o, 'ditolak mekanik')
    local data = staffData(src)
    data.msg = ('Pesanan #%s ditolak, uang dikembalikan.'):format(o.code)
    return data
end)

lib.callback.register('f_mechanicjob:server:shopSetLimit', function(src, value)
    local ok, player = isMechanic(src)
    if not ok then return { error = 'Hanya mekanik yang sedang bertugas.' } end
    if player.PlayerData.job.grade.level < cfg.settingsGrade then return { error = 'Grade kamu belum bisa mengubah batas.' } end
    value = math.floor(tonumber(value) or 0)
    if value < 1 or value > cfg.maxLimit then return { error = ('Batas harus 1 - %d.'):format(cfg.maxLimit) } end
    SetResourceKvpInt('shop_limit', value)
    local data = staffData(src)
    data.msg = ('Batas pembelian diubah menjadi %d item.'):format(value)
    return data
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
