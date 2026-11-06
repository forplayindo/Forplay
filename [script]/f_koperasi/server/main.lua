local config = require 'config.shared'

local prices = {}  -- item -> harga
for _, cat in ipairs(config.categories) do
    for _, e in ipairs(cat.items) do prices[e.item] = e.price end
end
local busy = {}

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

local function itemLabel(name)
    local item = exports.ox_inventory:Items(name)
    return item and item.label or name
end

local function nearKoperasi(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, c in ipairs(config.locations) do
        if #(pos - c) <= config.distance + 2.0 then return true end
    end
    return false
end

lib.callback.register('f_koperasi:server:getMenu', function(src)
    if not nearKoperasi(src) then return end
    local cats = {}
    for i, cat in ipairs(config.categories) do
        local rows = {}
        for j, e in ipairs(cat.items) do
            rows[j] = { item = e.item, label = itemLabel(e.item), price = e.price, count = exports.ox_inventory:GetItemCount(src, e.item) }
        end
        cats[i] = { label = cat.label, rows = rows }
    end
    return { categories = cats, taxRate = config.taxRate }
end)

-- wanted = { [item] = jumlah }
lib.callback.register('f_koperasi:server:sell', function(src, wanted)
    if type(wanted) ~= 'table' or busy[src] then return { ok = false } end
    if not nearKoperasi(src) then return { ok = false, msg = 'Kamu terlalu jauh dari Koperasi.' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false } end

    busy[src] = true
    local sold, gross = {}, 0
    for item, qty in pairs(wanted) do
        qty = math.floor(tonumber(qty) or 0)
        local price = prices[item]
        if price and qty > 0 then
            qty = math.min(qty, exports.ox_inventory:GetItemCount(src, item))
            if qty > 0 and exports.ox_inventory:RemoveItem(src, item, qty) then
                sold[#sold + 1] = { item = item, qty = qty }
                gross = gross + qty * price
            end
        end
    end
    if gross <= 0 then
        busy[src] = nil
        return { ok = false, msg = 'Tidak ada barang yang dijual.' }
    end

    local tax = math.floor(gross * config.taxRate / 100 + 0.5)
    local net = gross - tax
    if not player.Functions.AddMoney('bank', net, 'koperasi') then
        for _, s in ipairs(sold) do exports.ox_inventory:AddItem(src, s.item, s.qty) end -- kembalikan barang
        busy[src] = nil
        return { ok = false, msg = 'Pembayaran gagal, barang dikembalikan.' }
    end

    if tax > 0 then
        local okT, added = pcall(function() return exports['Renewed-Banking']:addAccountMoney(config.govAccount, tax) end)
        if okT and added then
            pcall(function() exports.f_tax:AddCitizenTax(tax) end)
        else
            lib.print.error(('Pajak koperasi %s (%s) gagal masuk ke rekening %s'):format(rupiah(tax), player.PlayerData.citizenid, config.govAccount))
        end
    end
    busy[src] = nil

    exports.qbx_core:Notify(src, ('Terjual %s. %s masuk rekening (pajak %s).'):format(rupiah(gross), rupiah(net), rupiah(tax)), 'success')
    return { ok = true, gross = gross, tax = tax, net = net }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
