-- Uang kotor. Item cash tetap satu ('money'); server mencatat berapa bagian cash yang kotor:
--  * pemain                  -> akun qbx_core Config.Account (tersimpan bersama data pemain, tampil di f_hud)
--  * stash / bagasi / drop   -> tabel f_dirtymoney_inv (drop hanya di memori)
-- Aturan:
--  * cash berkurang (belanja, bayar bisnis, kasih, dirampok, disita) -> bagian kotor terpakai duluan
--  * setor bank -> hanya bagian bersih (BlockDeposit dipanggil dari f_banking)
--  * uang pindah antar inventory -> bagian kotornya ikut pindah (hook swapItems ox_inventory)
local QBX = exports.qbx_core
local Inv = exports.ox_inventory
local ACC = Config.Account

local lastCash = {} -- [src] = cash terakhir yang terlihat (untuk event 'set' yang tidak membawa selisih)
local cleanOut = {} -- [src] = { amount, expires } pengurangan cash berikutnya diambil dari bagian bersih
local invDirty = {} -- [inventoryId] = bagian kotor di inventory non-pemain
local pending = {}  -- [key] = antrean perpindahan uang kotor yang menunggu hasil swapItems

local function rp(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
    if out:sub(1, 1) == '.' then out = out:sub(2) end
    return 'Rp ' .. out
end

local function playerDirty(p) return p.PlayerData.money[ACC] or 0 end

---Selalu dijaga: 0 <= kotor <= cash
local function setPlayerDirty(p, amount, reason)
    amount = math.max(0, math.min(math.floor(amount), p.PlayerData.money.cash or 0))
    if amount ~= playerDirty(p) then
        p.Functions.SetMoney(ACC, amount, reason or 'f_dirtymoney')
    end
end

---------------------------------------------------------------- inventory non-pemain

local function isDrop(id) return type(id) == 'string' and id:match('^drop%-%d+$') ~= nil end

local function invSet(id, amount)
    id = tostring(id)
    amount = math.max(0, math.floor(amount))
    if amount <= 0 then
        if not invDirty[id] then return end
        invDirty[id] = nil
        if not isDrop(id) then MySQL.prepare('DELETE FROM f_dirtymoney_inv WHERE inv = ?', { id }) end
        return
    end
    invDirty[id] = amount
    if not isDrop(id) then
        MySQL.prepare('INSERT INTO f_dirtymoney_inv (inv, amount) VALUES (?, ?) ON DUPLICATE KEY UPDATE amount = VALUES(amount)', { id, amount })
    end
end

---Bagian kotor di stash, dibatasi jumlah cash yang memang ada di sana
---(uang yang diambil script lain lewat RemoveItem tidak lewat hook)
local function invGet(id)
    id = tostring(id)
    local d = invDirty[id]
    if not d then return 0 end
    local count = Inv:GetItemCount(id, 'money')
    if count and d > count then
        d = count
        invSet(id, d)
    end
    return d
end

local function dirtyOf(id, invType)
    if invType == 'player' then
        local p = QBX:GetPlayer(tonumber(id))
        return p and playerDirty(p) or 0
    end
    return invGet(id)
end

---------------------------------------------------------------- perubahan cash pemain

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, actionType)
    if moneyType ~= 'cash' then return end
    local p = QBX:GetPlayer(src)
    if not p then return end

    local cash = p.PlayerData.money.cash or 0
    local prev = lastCash[src]
    if actionType == 'add' then prev = cash - amount
    elseif actionType == 'remove' then prev = cash + amount
    elseif not prev then prev = cash end
    lastCash[src] = cash

    local dirty = playerDirty(p)
    local spent = prev - cash
    local clean = cleanOut[src]
    if spent > 0 and clean then
        cleanOut[src] = nil
        if clean.expires >= GetGameTimer() then spent = math.max(0, spent - clean.amount) end
    end
    if dirty <= 0 then return end

    local newDirty = dirty
    if spent > 0 then newDirty = dirty - math.min(spent, dirty) end
    if newDirty > cash then newDirty = cash end
    if newDirty ~= dirty then setPlayerDirty(p, newDirty, 'cash berkurang') end
end)

---------------------------------------------------------------- konversi item lama

local function convertOldItem(src)
    local n = Inv:GetItemCount(src, Config.OldItem) or 0
    if n <= 0 then return end
    local p = QBX:GetPlayer(src)
    if not p or not Inv:RemoveItem(src, Config.OldItem, n) then return end
    if p.Functions.AddMoney('cash', n, 'konversi ' .. Config.OldItem) then
        setPlayerDirty(p, playerDirty(p) + n, 'konversi ' .. Config.OldItem)
    end
end

local function onPlayerReady(src)
    local p = QBX:GetPlayer(src)
    if not p then return end
    lastCash[src] = p.PlayerData.money.cash or 0
    if playerDirty(p) > lastCash[src] then setPlayerDirty(p, lastCash[src], 'koreksi') end
    convertOldItem(src)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    SetTimeout(5000, function() onPlayerReady(src) end) -- tunggu inventory selesai dimuat
end)

local function forget(src)
    lastCash[src] = nil
    cleanOut[src] = nil
end
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('qbx_core:server:playerLoggedOut', forget)

---------------------------------------------------------------- perpindahan antar inventory

local function moveKey(payload)
    return ('%s>%s|%s|%s'):format(payload.fromInventory, payload.toInventory, payload.action, payload.count)
end

local function planMoves(payload)
    local moves = {}
    local function add(from, fromType, to, toType, amount)
        if not to or tostring(from) == tostring(to) or (amount or 0) <= 0 then return end
        local d = math.min(amount, dirtyOf(from, fromType))
        if d > 0 then
            moves[#moves + 1] = { from = from, fromType = fromType, to = to, toType = toType, dirty = d }
        end
    end

    local fromSlot, toSlot = payload.fromSlot, payload.toSlot
    local toId = payload.toInventory == 'newdrop' and payload.dropId or payload.toInventory
    local swap = payload.action == 'swap'

    if type(fromSlot) == 'table' and fromSlot.name == 'money' then
        add(payload.fromInventory, payload.fromType, toId, payload.toType, swap and fromSlot.count or payload.count)
    end
    -- tukar slot: cash di slot tujuan pindah ke arah sebaliknya
    if swap and type(toSlot) == 'table' and toSlot.name == 'money' then
        add(payload.toInventory, payload.toType, payload.fromInventory, payload.fromType, toSlot.count)
    end
    return moves
end

-- Bagian kotor pemain asal sudah dikurangi otomatis oleh handler cash (kotor dulu),
-- jadi di sini hanya stash asal dan semua tujuan yang disesuaikan.
local function applyMoves(moves)
    for i = 1, #moves do
        local m = moves[i]
        if m.fromType ~= 'player' then invSet(m.from, invGet(m.from) - m.dirty) end
        if m.toType == 'player' then
            local p = QBX:GetPlayer(tonumber(m.to))
            if p then setPlayerDirty(p, playerDirty(p) + m.dirty, 'terima uang kotor') end
        else
            invSet(m.to, (invDirty[tostring(m.to)] or 0) + m.dirty)
        end
    end
end

local function registerHooks()
    local moneyHook = Inv:registerHook('swapItems', function(payload)
        local moves = planMoves(payload)
        if #moves > 0 then
            local key = moveKey(payload)
            pending[key] = pending[key] or {}
            pending[key][#pending[key] + 1] = moves
        end
        return true
    end, { itemFilter = { money = true } })

    AddEventHandler(moneyHook, function(success, payload)
        local key = moveKey(payload)
        local queue = pending[key]
        if not queue then return end
        local moves = table.remove(queue, 1)
        if #queue == 0 then pending[key] = nil end
        if success and moves then applyMoves(moves) end
    end)

    local oldHook = Inv:registerHook('swapItems', function() return true end, { itemFilter = { [Config.OldItem] = true } })
    AddEventHandler(oldHook, function(success, payload)
        if not success then return end
        if payload.toType == 'player' then convertOldItem(tonumber(payload.toInventory)) end
        if payload.fromType == 'player' and payload.action == 'swap' then convertOldItem(tonumber(payload.fromInventory)) end
    end)

    -- item lama yang dibuat langsung (mis. /giveitem [id] black_money [jumlah]) ikut dikonversi
    local createHook = Inv:registerHook('createItem', function() end, { itemFilter = { [Config.OldItem] = true } })
    AddEventHandler(createHook, function(success, payload)
        local src = tonumber(payload.inventoryId)
        if success and src and QBX:GetPlayer(src) then
            SetTimeout(100, function() convertOldItem(src) end)
        end
    end)
end

---------------------------------------------------------------- start

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dirtymoney_inv (
        inv VARCHAR(100) NOT NULL PRIMARY KEY,
        amount BIGINT NOT NULL DEFAULT 0
    )]])
    for _, r in ipairs(MySQL.query.await('SELECT inv, amount FROM f_dirtymoney_inv') or {}) do
        local amount = tonumber(r.amount) or 0
        if amount > 0 then invDirty[r.inv] = amount end
    end

    registerHooks()

    for _, pd in ipairs(QBX:GetPlayersData() or {}) do
        onPlayerReady(pd.source)
    end
end)

---------------------------------------------------------------- exports

---Bagian kotor dari cash pemain
exports('GetDirty', function(src)
    local p = QBX:GetPlayer(src)
    return p and playerDirty(p) or 0
end)

---Bagian bersih dari cash pemain
exports('GetClean', function(src)
    local p = QBX:GetPlayer(src)
    if not p then return 0 end
    return math.max(0, (p.PlayerData.money.cash or 0) - playerDirty(p))
end)

---Beri cash kotor (hasil kriminal)
local function addDirtyCash(src, amount, reason)
    local p = QBX:GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 then return false end
    if not p.Functions.AddMoney('cash', amount, reason or 'uang-kotor') then return false end
    setPlayerDirty(p, playerDirty(p) + amount, reason)
    return true
end
exports('AddDirtyCash', addDirtyCash)

---Tandai cash yang sudah ada sebagai kotor (dipakai saat cash pindah lewat RemoveMoney/AddMoney)
exports('AddDirty', function(src, amount, reason)
    local p = QBX:GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 then return false end
    setPlayerDirty(p, playerDirty(p) + amount, reason or 'terima uang kotor')
    return true
end)

---Dipanggil sebelum setor cash ke bank. true = ditolak (notifikasi sudah dikirim).
---false = boleh; pengurangan cash berikutnya diambil dari bagian bersih.
exports('BlockDeposit', function(src, amount)
    local p = QBX:GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 then return false end
    local cash = p.PlayerData.money.cash or 0
    local dirty = playerDirty(p)
    if dirty <= 0 or amount > cash then return false end

    local clean = cash - dirty
    if amount > clean then
        QBX:Notify(src, Config.DepositRejected:format(rp(amount - clean)), 'error', 7000)
        return true
    end
    cleanOut[src] = { amount = amount, expires = GetGameTimer() + 3000 }
    return false
end)

---------------------------------------------------------------- admin

lib.addCommand(Config.AdminCommand, {
    help = 'Beri cash kotor ke pemain (tes)',
    params = {
        { name = 'target', type = 'playerId', help = 'ID pemain' },
        { name = 'amount', type = 'number', help = 'Jumlah' },
    },
    restricted = Config.AdminGroup,
}, function(source, args)
    if addDirtyCash(args.target, args.amount, 'admin ' .. tostring(source)) then
        QBX:Notify(source, ('Memberi %s uang kotor ke ID %s'):format(rp(args.amount), args.target), 'success')
    else
        QBX:Notify(source, 'Gagal memberi uang kotor', 'error')
    end
end)
