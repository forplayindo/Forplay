-- Stok Gudang Bengkel (server). Angka di database (mechanic_stock), bukan item di stash, supaya
-- bahan tidak bisa diambil / dicuri karyawan. API global `Stock` dipakai panel perbaikan:
--   Stock.Counts() -> { item = jumlah } · Stock.Take({ item = n }) -> ok, itemKurang · Stock.Add(item, n)
--   HasToolBag(src) -> Tas Perkakas yang masih berlaku dibawa?
-- Perubahan terjadi di memori dulu (atomik, tanpa yield) lalu disimpan ke database.
local cfg = require 'config.shared'
local SC = require 'config.stock'
local BILL = (require 'config.server').billing

Stock = {}

local Qty, Def = {}, {}
for _, it in ipairs(SC.items) do
    Def[it.item] = it
    Qty[it.item] = 0
end
local ready = false
local throttles = {}

local function notify(src, msg, typ) exports.qbx_core:Notify(src, msg, typ or 'inform', 6000) end

local function throttle(src, key, ms)
    local id, now = src .. key, GetGameTimer()
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

local function persist(item)
    MySQL.prepare('INSERT INTO mechanic_stock (item, qty) VALUES (?, ?) ON DUPLICATE KEY UPDATE qty = VALUES(qty)', { item, Qty[item] })
end

local function label(item)
    local def = exports.ox_inventory:Items(item)
    return def and def.label or cfg.itemLabels[item] or item
end
Stock.Label = label

function Stock.Ready() return ready end
function Stock.Counts() return Qty end

---Potong stok sekaligus; gagal tanpa mengubah apa pun kalau ada yang kurang.
---@param need table<string, integer>
---@return boolean ok, string? missing
function Stock.Take(need)
    if not ready then return false, next(need) end
    for item, n in pairs(need) do
        if (Qty[item] or 0) < n then return false, item end
    end
    for item, n in pairs(need) do
        Qty[item] = Qty[item] - n
        persist(item)
    end
    return true
end

function Stock.Add(item, n)
    if not Def[item] or n <= 0 then return end
    Qty[item] = (Qty[item] or 0) + math.floor(n)
    persist(item)
end

---------------------------------------------------------------------------
-- Tas Perkakas (durability ox_inventory = waktu kedaluwarsa, sama seperti tas EMS)
---------------------------------------------------------------------------
local function expired(slot)
    local d = slot.metadata and tonumber(slot.metadata.durability)
    return d ~= nil and d > 100 and d <= os.time()
end

local function bagSlots(src)
    return exports.ox_inventory:Search(src, 'slots', SC.bag) or {}
end

function HasToolBag(src)
    for _, slot in pairs(bagSlots(src)) do
        if not expired(slot) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Akses
---------------------------------------------------------------------------
local function mechanicOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or job.type ~= cfg.jobType or not job.onduty then return end
    return player, job
end

local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= dist
end

local function nearPoint(src) return near(src, SC.point.coords, SC.point.distance + 2.0) end
local function nearSupplier(src) return near(src, SC.supplier.coords, SC.supplier.distance + 2.0) end

---------------------------------------------------------------------------
-- Rekening organisasi (f_banking)
---------------------------------------------------------------------------
local function balance()
    local ok, v = pcall(function() return exports['f_banking']:getAccountMoney(BILL.job) end)
    return ok and tonumber(v) or 0
end

local function societyRemove(amount, reason)
    local ok, removed = pcall(function() return exports['f_banking']:removeAccountMoney(BILL.job, amount) end)
    if not ok or not removed then return false end
    pcall(function()
        exports['f_banking']:handleTransaction(BILL.job, BILL.label, amount, reason, BILL.label, 'Supplier', 'withdraw')
    end)
    return true
end

---------------------------------------------------------------------------
-- Database + pemindahan isi stash lama (sekali jalan)
---------------------------------------------------------------------------
local function migrateStash()
    if not SC.migrateStash or SC.migrateStash == '' or GetResourceKvpInt('stock_migrated') == 1 then return end
    -- stash didaftarkan f_stash; tunggu sampai resource itu jalan
    for _ = 1, 60 do
        if GetResourceState('f_stash') == 'started' then break end
        Wait(1000)
    end
    Wait(3000)
    local items = exports.ox_inventory:GetInventoryItems(SC.migrateStash)
    if not items then return end -- stash belum terdaftar: coba lagi di start berikutnya
    local moved = 0
    for slot, it in pairs(items) do
        if it and Def[it.name] and it.count > 0 then
            if exports.ox_inventory:RemoveItem(SC.migrateStash, it.name, it.count, nil, slot) then
                Stock.Add(it.name, it.count)
                moved += it.count
            end
        end
    end
    SetResourceKvpInt('stock_migrated', 1)
    if moved > 0 then print(('^2[f_mechanicjob]^7 %d bahan dari stash %s dipindah ke Stok Gudang'):format(moved, SC.migrateStash)) end
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_stock` (
            `item` VARCHAR(32) NOT NULL,
            `qty` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`item`)
        )
    ]])
    for _, r in ipairs(MySQL.query.await('SELECT item, qty FROM mechanic_stock') or {}) do
        if Def[r.item] then Qty[r.item] = math.max(0, tonumber(r.qty) or 0) end
    end
    ready = true
    migrateStash()
end)

---------------------------------------------------------------------------
-- Titik Supplier: Stok Gudang (lihat: semua mekanik on duty, beli: grade SC.grade)
---------------------------------------------------------------------------
local function stockList()
    local list = {}
    for i, it in ipairs(SC.items) do
        list[i] = { item = it.item, label = label(it.item), price = it.price, use = it.use, qty = Qty[it.item] or 0 }
    end
    return list
end

local function stockData(job)
    return { items = stockList(), max = SC.maxPerBuy, balance = balance(), canBuy = job.grade.level >= SC.grade }
end

function Stock.CanBuy(job) return job.grade.level >= SC.grade end

lib.callback.register('f_mechanicjob:server:stockGet', function(src)
    local player, job = mechanicOf(src)
    if not player then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearSupplier(src) then return { error = 'Kamu harus berada di titik Supplier' } end
    return stockData(job)
end)

---@param cart table<string, number> item -> jumlah
lib.callback.register('f_mechanicjob:server:supplierBuy', function(src, cart)
    if not throttle(src, 'buy', 1500) then return { error = 'Tunggu sebentar' } end
    local player, job = mechanicOf(src)
    if not player then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not Stock.CanBuy(job) then return { error = 'Hanya Manager yang bisa membeli ke supplier' } end
    if not nearSupplier(src) then return { error = 'Kamu harus berada di titik Supplier' } end
    if not ready then return { error = 'Stok gudang belum siap, coba lagi' } end
    if type(cart) ~= 'table' then return { error = 'Pesanan tidak valid' } end

    local lines, cost = {}, 0
    for item, raw in pairs(cart) do
        local d, n = Def[item], math.tointeger(tonumber(raw))
        if not d or not n or n < 0 or n > SC.maxPerBuy then return { error = 'Pesanan tidak valid' } end
        if n > 0 then
            lines[#lines + 1] = { item = item, n = n }
            cost += d.price * n
        end
    end
    if #lines == 0 then return { error = 'Belum ada barang yang dipilih' } end

    if not societyRemove(cost, 'Pembelian suku cadang') then
        local data = stockData(job)
        data.error = ('Saldo rekening bengkel tidak cukup (butuh Rp %s)'):format(lib.math.groupdigits(cost, '.'))
        return data
    end
    for _, l in ipairs(lines) do Stock.Add(l.item, l.n) end

    local data = stockData(job)
    data.msg = ('Pembelian Rp %s berhasil. Stok gudang bertambah.'):format(lib.math.groupdigits(cost, '.'))
    return data
end)

---------------------------------------------------------------------------
-- Titik Gudang: Setor Bahan (item -> stok, satu arah) & Ambil Tas Perkakas
---------------------------------------------------------------------------
local function depositData(src)
    local counts = exports.ox_inventory:Search(src, 'count', (function()
        local names = {}
        for i, it in ipairs(SC.items) do names[i] = it.item end
        return names
    end)()) or {}
    local list = {}
    for i, it in ipairs(SC.items) do
        list[i] = { item = it.item, label = label(it.item), use = it.use, have = counts[it.item] or 0, qty = Qty[it.item] or 0 }
    end
    return { items = list, max = SC.maxDeposit, bag = HasToolBag(src) }
end

lib.callback.register('f_mechanicjob:server:gudangGet', function(src)
    if not mechanicOf(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearPoint(src) then return { error = 'Kamu harus berada di Gudang Bengkel' } end
    return depositData(src)
end)

---@param cart table<string, number> item -> jumlah yang disetor
lib.callback.register('f_mechanicjob:server:gudangDeposit', function(src, cart)
    if not throttle(src, 'dep', 1500) then return { error = 'Tunggu sebentar' } end
    if not mechanicOf(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearPoint(src) then return { error = 'Kamu harus berada di Gudang Bengkel' } end
    if not ready then return { error = 'Stok gudang belum siap, coba lagi' } end
    if type(cart) ~= 'table' then return { error = 'Setoran tidak valid' } end

    local total, lines = 0, {}
    for item, raw in pairs(cart) do
        local n = math.tointeger(tonumber(raw))
        if not Def[item] or not n or n < 0 or n > SC.maxDeposit then return { error = 'Setoran tidak valid' } end
        if n > 0 then lines[#lines + 1] = { item = item, n = n } end
    end
    if #lines == 0 then return { error = 'Belum ada bahan yang dipilih' } end

    for _, l in ipairs(lines) do
        -- item hanya masuk stok kalau benar-benar berhasil diambil dari tas
        if exports.ox_inventory:RemoveItem(src, l.item, l.n) then
            Stock.Add(l.item, l.n)
            total += l.n
        end
    end

    local data = depositData(src)
    if total == 0 then data.error = 'Bahan tidak ada di tasmu' return data end
    data.msg = ('%d bahan disetor ke Stok Gudang.'):format(total)
    return data
end)

lib.callback.register('f_mechanicjob:server:gudangBag', function(src)
    if not throttle(src, 'bag', 2000) then return { error = 'Tunggu sebentar' } end
    if not mechanicOf(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not nearPoint(src) then return { error = 'Kamu harus berada di Gudang Bengkel' } end
    if HasToolBag(src) then return { error = 'Kamu sudah membawa Tas Perkakas' } end
    if not exports.ox_inventory:CanCarryItem(src, SC.bag, 1) then return { error = 'Tasmu penuh' } end

    local old = {}
    for _, slot in pairs(bagSlots(src)) do
        if expired(slot) then old[#old + 1] = slot.slot end
    end
    for _, s in ipairs(old) do exports.ox_inventory:RemoveItem(src, SC.bag, 1, nil, s) end
    if not exports.ox_inventory:AddItem(src, SC.bag, 1) then return { error = 'Gagal mengambil Tas Perkakas' } end
    notify(src, 'Tas Perkakas diambil. Berlaku 2 hari.', 'success')
    return depositData(src)
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
