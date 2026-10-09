-- Tagihan layanan mekanik (sama seperti EMS).
--  1. Setiap perbaikan di panel dicatat server (Billing.Record) per kendaraan (plat) sebagai
--     layanan belum ditagih. Mekanik tidak bisa mengarang layanan; hanya layanan `manual` di config
--     (panggilan ke lokasi, derek) yang boleh ditambahkan sendiri.
--  2. Tab Tagihan: pilih pelanggan (pemain di dekat mekanik, default pemilik kendaraan), boleh
--     diskon (tidak bisa menaikkan harga), lalu dua pilihan:
--      - "Bayar Langsung": mechanic_bills + invoice f_phone atas nama job mechanic. Dibayar lewat HP ->
--        f_phone memindahkan uang ke rekening organisasi.
--      - "Bayar di Kasir" (hanya di area bengkel): tagihan masuk Kasir (server/kasir.lua).
--  Harga layanan diambil dari Master Harga (server/prices.lua, kode `svc:<kode>`).
local cfg = require 'config.shared'
local BILL = (require 'config.server').billing

Billing = { ready = false }

---@type table<string, { id: integer, code: string, label: string, price: integer, at: integer, by: string, byName: string }[]>
local pending = {}
local seq = 0

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_bills` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `customer_name` VARCHAR(100) NOT NULL DEFAULT '',
            `plate` VARCHAR(16) NOT NULL DEFAULT '',
            `items` LONGTEXT NOT NULL,
            `total` BIGINT NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'unpaid',
            `invoice_id` VARCHAR(64) NULL,
            `created_by` VARCHAR(50) NOT NULL,
            `created_by_name` VARCHAR(100) NOT NULL DEFAULT '',
            `created_at` INT NOT NULL,
            `settled_at` INT NULL,
            `kind` VARCHAR(10) NOT NULL DEFAULT 'repair',
            `channel` VARCHAR(8) NOT NULL DEFAULT 'phone',
            `vehicleid` INT NULL,
            `method` VARCHAR(10) NULL,
            PRIMARY KEY (`id`),
            INDEX `status_idx` (`status`),
            INDEX `invoice_idx` (`invoice_id`)
        )
    ]])
    -- tabel lama (sebelum kasir & kustom): tambah kolom yang belum ada
    local add = {
        kind = "VARCHAR(10) NOT NULL DEFAULT 'repair'",
        channel = "VARCHAR(8) NOT NULL DEFAULT 'phone'",
        vehicleid = 'INT NULL',
        method = 'VARCHAR(10) NULL',
    }
    for _, col in ipairs({ 'kind', 'channel', 'vehicleid', 'method' }) do
        if not MySQL.scalar.await("SHOW COLUMNS FROM `mechanic_bills` LIKE '" .. col .. "'") then
            MySQL.query.await(('ALTER TABLE `mechanic_bills` ADD COLUMN `%s` %s'):format(col, add[col]))
        end
    end
    Billing.ready = true
end)

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end
Billing.CharName = charName

local function plateOf(veh)
    return (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
end
Billing.PlateOf = plateOf

local function servicePrice(code)
    return Prices.Get('svc:' .. code) or BILL.services[code].price
end

---Pemain berada di area bengkel (config workshop)?
function Billing.InWorkshop(coords)
    return #(coords - cfg.workshop.center) <= cfg.workshop.radius
end

---@param mechSrc number
---@param veh number
---@param code string kunci layanan di config.server billing.services
function Billing.Record(mechSrc, veh, code)
    local def = BILL.services[code]
    local mech = exports.qbx_core:GetPlayer(mechSrc)
    if not def or not mech then return end
    local plate = plateOf(veh)
    seq += 1
    pending[plate] = pending[plate] or {}
    pending[plate][#pending[plate] + 1] = {
        id = seq, code = code, label = def.label, price = servicePrice(code), at = os.time(),
        by = mech.PlayerData.citizenid, byName = charName(mech),
    }
end

-- Resource lain (f_vehiclekeys: duplikat kunci) mencatat layanannya ke tagihan kendaraan.
-- Export server-only, jadi client tidak bisa memanggilnya.
exports('RecordService', function(mechSrc, veh, code)
    if not BILL.services[code] or not DoesEntityExist(veh) then return false end
    Billing.Record(mechSrc, veh, code)
    return true
end)

function Billing.PendingCount(veh)
    return #(pending[plateOf(veh)] or {})
end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty, player
end

local function ownerCid(veh)
    local vid = tonumber(Entity(veh).state.vehicleid)
    if not vid then return end
    return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE id = ?', { vid })
end

---Pemain di dekat mekanik yang bisa ditagih.
local function customersNear(src, veh)
    local here = GetEntityCoords(GetPlayerPed(src))
    local owner = ownerCid(veh)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= src then
            local ped = GetPlayerPed(target)
            local p = ped ~= 0 and exports.qbx_core:GetPlayer(target)
            if p and #(GetEntityCoords(ped) - here) <= BILL.customerDistance then
                list[#list + 1] = { id = target, name = charName(p), owner = owner ~= nil and p.PlayerData.citizenid == owner }
            end
        end
    end
    table.sort(list, function(a, b) return (a.owner and 1 or 0) > (b.owner and 1 or 0) end)
    return list
end

local function billingData(src, veh)
    local manual = {}
    for i, code in ipairs(BILL.manual) do manual[i] = { code = code, label = BILL.services[code].label, price = servicePrice(code) } end
    return {
        pending = pending[plateOf(veh)] or {}, customers = customersNear(src, veh), manual = manual,
        inWorkshop = Billing.InWorkshop(GetEntityCoords(GetPlayerPed(src))),
    }
end

---@return string? err, number? veh
local function check(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return 'Kendaraan tidak ditemukan' end
    if not isMechanic(src) then return 'Hanya mekanik yang sedang bertugas' end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > cfg.closeDistance then return 'Kendaraan terlalu jauh' end
    return nil, veh
end

lib.callback.register('f_mechanicjob:server:billingGet', function(src, netId)
    local err, veh = check(src, netId)
    if err then return { error = err } end
    return billingData(src, veh)
end)

lib.callback.register('f_mechanicjob:server:billingAdd', function(src, netId, code)
    local err, veh = check(src, netId)
    if err then return { error = err } end
    local allowed = false
    for _, c in ipairs(BILL.manual) do if c == code then allowed = true end end
    if not allowed then return { error = 'Layanan tidak bisa ditambahkan manual' } end
    Billing.Record(src, veh, code)
    return billingData(src, veh)
end)

lib.callback.register('f_mechanicjob:server:billingDiscard', function(src, netId, id)
    local err, veh = check(src, netId)
    if err then return { error = err } end
    local list = pending[plateOf(veh)] or {}
    for i = #list, 1, -1 do
        if list[i].id == tonumber(id) then table.remove(list, i) end
    end
    return billingData(src, veh)
end)

---Invoice f_phone (Bank > Invoices) atas nama job mechanic.
local function createInvoice(mechSrc, mech, targetSrc, target, total, note)
    if GetResourceState('f_phone') ~= 'started' then return end
    local chars, t = 'abcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 16 do
        local n = math.random(1, #chars)
        t[i] = chars:sub(n, n)
    end
    local id = 'bill_' .. table.concat(t)
    local okM, mechNumber = pcall(function() return exports['f_phone']:getPhoneNumber(mechSrc) end)
    local okT, targetNumber = pcall(function() return exports['f_phone']:getPhoneNumber(targetSrc) end)
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)
    ]], {
        id, BILL.job, BILL.label, mech.PlayerData.citizenid, charName(mech), okM and mechNumber or nil,
        target.PlayerData.citizenid, charName(target), okT and targetNumber or nil,
        total, note:sub(1, 140), os.time(),
    })
    if not ok then return end
    pcall(function()
        exports['f_phone']:notify(targetSrc, {
            appId = 'bank', app = 'Bank', title = BILL.label,
            body = ('Tagihan bengkel Rp %d. Buka Bank > Invoices untuk membayar.'):format(total), time = 'now',
        })
    end)
    TriggerClientEvent('f_phone:client:services:invoices', targetSrc, {})
    return id
end

---@param targetId number pemain yang ditagih
---@param lines { id: integer, price: number }[]
---@param channel 'phone'|'kasir' Bayar Langsung (invoice HP) atau Bayar di Kasir
lib.callback.register('f_mechanicjob:server:billingSend', function(src, netId, targetId, lines, channel)
    local err, veh = check(src, netId)
    if err then return { error = err } end
    channel = channel == 'kasir' and 'kasir' or 'phone'
    if channel == 'kasir' and not Billing.InWorkshop(GetEntityCoords(GetPlayerPed(src))) then
        return { error = 'Bayar di Kasir hanya bisa di area bengkel' }
    end
    targetId = tonumber(targetId)
    local target = targetId and targetId ~= src and exports.qbx_core:GetPlayer(targetId)
    if not target then return { error = 'Pilih pelanggan yang ditagih' } end
    if #(GetEntityCoords(GetPlayerPed(targetId)) - GetEntityCoords(GetPlayerPed(src))) > BILL.customerDistance then
        return { error = 'Pelanggan harus berada di dekatmu' }
    end
    if type(lines) ~= 'table' or #lines == 0 then return { error = 'Pilih minimal satu layanan' } end

    local plate = plateOf(veh)
    local list = pending[plate] or {}
    local byId = {}
    for _, svc in ipairs(list) do byId[svc.id] = svc end

    local items, used, total = {}, {}, 0
    for _, line in ipairs(lines) do
        local svc = type(line) == 'table' and byId[tonumber(line.id)]
        if not svc or used[svc.id] then return { error = 'Data tagihan berubah, buka ulang tab Tagihan' } end
        local price = math.floor(tonumber(line.price) or -1)
        if price < 0 or price > svc.price then return { error = ('Harga %s harus 0 - Rp %d'):format(svc.label, svc.price) } end
        used[svc.id] = true
        total += price
        items[#items + 1] = { label = svc.label, price = price, normal = svc.price }
    end
    if total <= 0 then return { error = 'Total tagihan $0, tidak perlu dikirim' } end

    local _, mech = isMechanic(src)
    if channel == 'kasir' then
        local bill = Kasir.Add({
            kind = 'repair', citizenid = target.PlayerData.citizenid, name = charName(target), plate = plate,
            vehicleid = tonumber(Entity(veh).state.vehicleid), items = items, total = total,
            createdBy = mech.PlayerData.citizenid, createdByName = charName(mech),
        })
        if not bill then return { error = 'Tagihan gagal disimpan' } end
        exports.qbx_core:Notify(targetId, ('Tagihan bengkel Rp %d (#%d) menunggu di kasir. Silakan bayar di meja kasir.'):format(total, bill.id), 'inform', 8000)
    else
        local summary = {}
        for i, item in ipairs(items) do summary[i] = item.label end
        local invoiceId = createInvoice(src, mech, targetId, target, total, ('Bengkel %s: %s'):format(plate, table.concat(summary, ', ')))
        if not invoiceId then return { error = 'Invoice HP gagal dibuat (f_phone)' } end

        MySQL.insert.await([[
            INSERT INTO mechanic_bills (citizenid, customer_name, plate, items, total, status, invoice_id, created_by, created_by_name, created_at)
            VALUES (?, ?, ?, ?, ?, 'unpaid', ?, ?, ?, ?)
        ]], { target.PlayerData.citizenid, charName(target), plate, json.encode(items), total, invoiceId, mech.PlayerData.citizenid, charName(mech), os.time() })
    end

    for i = #list, 1, -1 do
        if used[list[i].id] then table.remove(list, i) end
    end
    local data = billingData(src, veh)
    data.sent = total
    data.to = charName(target)
    data.channel = channel
    return data
end)

-- tagihan "Bayar Langsung" (channel phone). Tagihan kasir diurus server/kasir.lua.
AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' or data.job ~= BILL.job or not data.id then return end
    MySQL.update("UPDATE mechanic_bills SET status = 'paid', settled_at = ? WHERE invoice_id = ? AND status = 'unpaid' AND channel = 'phone'", { os.time(), data.id })
end)
