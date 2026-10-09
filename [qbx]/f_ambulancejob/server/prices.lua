-- Daftar harga EMS (server). Default dari config; Boss bisa mengubah di Kasir > Daftar Harga
-- (tersimpan di tabel ems_prices). Kode: 'item:<nama item apotek>' dan 'svc:<kode layanan>'.

local treatment = require 'config.treatment'
local pharmacy = require 'config.pharmacy'

Prices = {}

local MAX_PRICE = 100000000
local Defaults, Labels, Order = {}, {}, {}
local Custom = {}       ---@type table<string, integer>

local function define(code, label, price, group)
    Defaults[code] = price
    Labels[code] = label
    Order[#Order + 1] = { code = code, group = group }
end

for _, m in ipairs(pharmacy.items) do define('item:' .. m.item, m.label, m.price, 'apotek') end
for _, code in ipairs({ 'light', 'bleed', 'heavy', 'painkiller', 'revive', 'transfusion', 'crutch', 'surgery' }) do
    local def = treatment.billing[code]
    if def then define('svc:' .. code, def.label, def.price, 'tindakan') end
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ems_prices` (
            `code` VARCHAR(40) NOT NULL,
            `price` BIGINT NOT NULL,
            PRIMARY KEY (`code`)
        )
    ]])
    for _, r in ipairs(MySQL.query.await('SELECT code, price FROM ems_prices') or {}) do
        if Defaults[r.code] then Custom[r.code] = tonumber(r.price) end
    end
end)

---@param code string 'item:bandage' / 'svc:revive'
---@return integer
function Prices.Get(code)
    return Custom[code] or Defaults[code] or 0
end

function Prices.List()
    local out = {}
    for i, o in ipairs(Order) do
        out[i] = { code = o.code, group = o.group, label = Labels[o.code], default = Defaults[o.code], price = Prices.Get(o.code) }
    end
    return out
end

---@param changes table<string, number>
---@return string? error
function Prices.Set(changes)
    if type(changes) ~= 'table' then return 'Data harga tidak valid' end
    for code, price in pairs(changes) do
        price = tonumber(price)
        if not Defaults[code] or not price or price ~= math.floor(price) or price < 0 or price > MAX_PRICE then
            return ('Harga %s tidak valid'):format(Labels[code] or tostring(code))
        end
    end
    for code, price in pairs(changes) do
        price = math.floor(tonumber(price))
        if price == Defaults[code] then
            Custom[code] = nil
            MySQL.prepare('DELETE FROM ems_prices WHERE code = ?', { code })
        else
            Custom[code] = price
            MySQL.prepare('INSERT INTO ems_prices (code, price) VALUES (?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price)', { code, price })
        end
    end
end
