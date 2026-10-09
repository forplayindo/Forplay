-- Master Harga: harga awal dari config (config/customs.lua catalog + config/server.lua billing.services
-- dengan kode `svc:<kode>`), ditimpa tabel mechanic_prices. Dibaca sekali saat start, disimpan di memori.
local CUS = require 'config.customs'
local BILL = (require 'config.server').billing

Prices = {}
Prices.Max = 100000000

local defaults, overrides, order = {}, {}, {}

for _, c in ipairs(CUS.catalog) do
    local items = {}
    for i, it in ipairs(c.items) do
        defaults[it.code] = it.price
        items[i] = { code = it.code, label = it.label }
    end
    order[#order + 1] = { cat = c.cat, items = items }
end

do
    local svc = {}
    for code, def in pairs(BILL.services) do
        defaults['svc:' .. code] = def.price
        svc[#svc + 1] = { code = 'svc:' .. code, label = def.label }
    end
    table.sort(svc, function(a, b) return a.label < b.label end)
    order[#order + 1] = { cat = 'Layanan Perbaikan', items = svc }
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `mechanic_prices` (
            `code` VARCHAR(48) NOT NULL,
            `price` BIGINT NOT NULL,
            PRIMARY KEY (`code`)
        )
    ]])
    for _, r in ipairs(MySQL.query.await('SELECT code, price FROM mechanic_prices') or {}) do
        if defaults[r.code] then overrides[r.code] = r.price end
    end
end)

---@param code string
---@return integer?
function Prices.Get(code)
    return overrides[code] or defaults[code]
end

function Prices.Exists(code) return defaults[code] ~= nil end

---Semua harga (kode -> harga) untuk tampilan client.
function Prices.All()
    local out = {}
    for code, price in pairs(defaults) do out[code] = overrides[code] or price end
    return out
end

---Daftar per kategori untuk Master Harga.
function Prices.List()
    local out = {}
    for i, c in ipairs(order) do
        local items = {}
        for j, it in ipairs(c.items) do
            items[j] = { code = it.code, label = it.label, price = Prices.Get(it.code), default = defaults[it.code] }
        end
        out[i] = { cat = c.cat, items = items }
    end
    return out
end

---@param changes table<string, number>
---@return string? err, integer? count
function Prices.Save(changes)
    if type(changes) ~= 'table' then return 'Data tidak valid' end
    local rows, n = {}, 0
    for code, value in pairs(changes) do
        if type(code) ~= 'string' or not defaults[code] then return 'Kode harga tidak dikenal' end
        local price = math.floor(tonumber(value) or -1)
        if price < 0 or price > Prices.Max then return ('Harga harus 0 - Rp %d'):format(Prices.Max) end
        n += 1
        if n > 200 then return 'Terlalu banyak perubahan' end
        rows[#rows + 1] = { code, price }
    end
    if n == 0 then return 'Tidak ada perubahan' end
    for _, r in ipairs(rows) do
        MySQL.prepare.await('INSERT INTO mechanic_prices (code, price) VALUES (?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price)', r)
        overrides[r[1]] = r[2]
    end
    return nil, n
end
