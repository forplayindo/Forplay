-- Stok Gudang obat EMS (server). Angka di database (ems_stock), bukan item inventory.
-- API global `Stock` dipakai modul lain (apotek, Cek Pasien, operasi, donor):
--   Stock.Get(key) -> jumlah · Stock.Has({ key = n }) -> ok, keyKurang · Stock.Take({ key = n }) -> ok, keyKurang
--   Stock.Add(key, n)
-- Semua perubahan terjadi di memori dulu (atomik, tanpa yield) lalu disimpan ke database.

local cfg = require 'config.stock'

Stock = {}

local Qty = {}          ---@type table<string, integer>
local Def = {}          ---@type table<string, table>
for _, it in ipairs(cfg.items) do
    Def[it.key] = it
    Qty[it.key] = 0
end
local ready = false
local throttles = {}

local function persist(key)
    MySQL.prepare('INSERT INTO ems_stock (item, qty) VALUES (?, ?) ON DUPLICATE KEY UPDATE qty = VALUES(qty)', { key, Qty[key] })
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ems_stock` (
            `item` VARCHAR(32) NOT NULL,
            `qty` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`item`)
        )
    ]])
    for _, r in ipairs(MySQL.query.await('SELECT item, qty FROM ems_stock') or {}) do
        if Def[r.item] then Qty[r.item] = math.max(0, tonumber(r.qty) or 0) end
    end
    ready = true
end)

function Stock.Ready() return ready end

function Stock.Get(key) return Qty[key] or 0 end

function Stock.Label(key) return Def[key] and Def[key].label or key end

---@param need table<string, integer>
---@return boolean ok, string? missing
function Stock.Has(need)
    for key, n in pairs(need) do
        if (Qty[key] or 0) < n then return false, key end
    end
    return true
end

---Potong stok sekaligus; gagal tanpa mengubah apa pun kalau ada yang kurang.
---@param need table<string, integer>
---@return boolean ok, string? missing
function Stock.Take(need)
    if not ready then return false, next(need) end
    local ok, missing = Stock.Has(need)
    if not ok then return false, missing end
    for key, n in pairs(need) do
        Qty[key] = Qty[key] - n
        persist(key)
    end
    return true
end

function Stock.Add(key, n)
    if not Def[key] or n <= 0 then return end
    Qty[key] = (Qty[key] or 0) + math.floor(n)
    persist(key)
end

exports('GetStock', Stock.Get)
-- dipakai f_petshop: potong Stok Gudang saat EMS menyembuhkan hewan. Mengembalikan ok, labelKurang
exports('TakeStock', function(need)
    local ok, missing = Stock.Take(need)
    return ok, missing and Stock.Label(missing) or nil
end)

---------------------------------------------------------------------------
-- Rekening organisasi (Renewed-Banking)
---------------------------------------------------------------------------
local function balance()
    local ok, v = pcall(function() return exports['Renewed-Banking']:getAccountMoney(cfg.job) end)
    return ok and tonumber(v) or 0
end

local function societyRemove(amount, reason)
    local ok, removed = pcall(function() return exports['Renewed-Banking']:removeAccountMoney(cfg.job, amount) end)
    if not ok or not removed then return false end
    pcall(function()
        exports['Renewed-Banking']:handleTransaction(cfg.job, cfg.label, amount, reason, cfg.label, 'Supplier', 'withdraw')
    end)
    return true
end

---------------------------------------------------------------------------
-- Akses
---------------------------------------------------------------------------
local function emsOf(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    if not job or job.type ~= 'ems' or not job.onduty then return end
    return player, job
end

local function isBoss(job) return job.isboss == true or (job.grade and job.grade.isboss == true) end
IsEmsBoss = isBoss

function NearKasir(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, k in ipairs(cfg.kasir) do
        if #(pos - k.coords) <= cfg.menuDistance then return true end
    end
    return false
end

local function throttle(src, key, ms)
    local id, now = src .. key, GetGameTimer()
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

---------------------------------------------------------------------------
-- Menu Kasir petugas: tab Stok Gudang + Supplier (data lain di server/kasir.lua)
---------------------------------------------------------------------------
function Stock.List()
    local list = {}
    for i, it in ipairs(cfg.items) do
        list[i] = { key = it.key, label = it.label, emoji = it.emoji, use = it.use, qty = Qty[it.key] or 0,
            hpp = it.hpp, units = it.units, unitLabel = it.unitLabel }
    end
    return list
end

Stock.Balance = balance
Stock.MaxPerBuy = cfg.maxPerBuy

local function staffData()
    return { stock = Stock.List(), balance = balance() }
end

---@param cart table<string, integer> key -> jumlah pembelian
lib.callback.register('f_ambulancejob:server:supplierBuy', function(src, cart)
    if not throttle(src, 'buy', 1500) then return { error = 'Tunggu sebentar.' } end
    local player, job = emsOf(src)
    if not player then return { error = 'Hanya EMS yang sedang bertugas.' } end
    if not isBoss(job) then return { error = 'Hanya Boss yang bisa membeli ke supplier.' } end
    if not NearKasir(src) then return { error = 'Kamu harus berada di kasir.' } end
    if not ready then return { error = 'Stok gudang belum siap, coba lagi.' } end
    if type(cart) ~= 'table' then return { error = 'Pesanan tidak valid.' } end

    local lines, cost = {}, 0
    for key, raw in pairs(cart) do
        local d, n = Def[key], tonumber(raw)
        if not d or not d.hpp or not n or n ~= math.floor(n) or n < 0 or n > cfg.maxPerBuy then
            return { error = 'Pesanan tidak valid.' }
        end
        if n > 0 then
            lines[#lines + 1] = { key = key, n = n }
            cost += d.hpp * n
        end
    end
    if #lines == 0 then return { error = 'Belum ada item yang dipilih.' } end

    if not societyRemove(cost, 'Pembelian obat ke supplier') then
        local data = staffData()
        data.error = ('Saldo organisasi tidak cukup (butuh Rp %s).'):format(Billing.FormatMoney(cost))
        return data
    end

    local parts = {}
    for _, l in ipairs(lines) do
        local d = Def[l.key]
        Stock.Add(l.key, l.n * (d.units or 1))
        parts[#parts + 1] = ('%dx %s'):format(l.n, d.label)
    end

    local data = staffData()
    data.msg = ('Membeli %s seharga Rp %s. Stok gudang bertambah.'):format(table.concat(parts, ', '), Billing.FormatMoney(cost))
    return data
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
