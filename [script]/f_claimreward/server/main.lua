-- f_claimreward — inti server: database, validasi & pemberian hadiah.
-- Semua keputusan (saldo, acak gacha, kode, stok) ada di server; client hanya mengirim pilihan.
local config = require 'config.server'
local ox = exports.ox_inventory
local L = config.limits

FR = { config = config }

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `f_reward_players` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `coins` INT NOT NULL DEFAULT 0,
        `pity` SMALLINT NOT NULL DEFAULT 0,
        `pulls` INT NOT NULL DEFAULT 0,
        `daily_day` TINYINT NOT NULL DEFAULT 0,
        `daily_last` VARCHAR(10) NOT NULL DEFAULT '',
        `asset_tier` TINYINT NOT NULL DEFAULT 0,
        `asset_last` INT NOT NULL DEFAULT 0
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_codes` (
        `code` VARCHAR(24) NOT NULL PRIMARY KEY,
        `rewards` LONGTEXT NOT NULL,
        `expires_at` INT NOT NULL,
        `max_uses` INT NOT NULL DEFAULT 0,
        `uses` INT NOT NULL DEFAULT 0,
        `created_by` VARCHAR(100) NOT NULL DEFAULT '',
        `created_at` INT NOT NULL DEFAULT 0
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_code_claims` (
        `code` VARCHAR(24) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `claimed_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`code`, `citizenid`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_shop` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `label` VARCHAR(60) NOT NULL,
        `description` VARCHAR(200) NOT NULL DEFAULT '',
        `category` VARCHAR(20) NOT NULL DEFAULT 'item',
        `rewards` LONGTEXT NOT NULL,
        `price` INT NOT NULL,
        `buy_limit` INT NOT NULL DEFAULT 0,
        `expires_at` INT NOT NULL DEFAULT 0,
        `active` TINYINT NOT NULL DEFAULT 1,
        `sort` INT NOT NULL DEFAULT 0
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_shop_buys` (
        `shop_id` INT NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`shop_id`, `citizenid`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_winners` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `reward` VARCHAR(120) NOT NULL,
        `detail` VARCHAR(160) NOT NULL DEFAULT '',
        `source` VARCHAR(12) NOT NULL,
        `rarity` VARCHAR(12) NOT NULL DEFAULT '',
        `asset` TINYINT NOT NULL DEFAULT 0,
        `status` VARCHAR(12) NOT NULL,
        `handled_by` VARCHAR(100) NOT NULL DEFAULT '',
        `created_at` INT NOT NULL,
        `handled_at` INT NOT NULL DEFAULT 0,
        INDEX (`status`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `f_reward_log` (
        `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `kind` VARCHAR(12) NOT NULL,
        `detail` TEXT NOT NULL,
        `created_at` INT NOT NULL,
        INDEX (`citizenid`)
    )]],
}

-- kolom yang ditambahkan setelah versi pertama (tabel lama tidak ikut berubah oleh CREATE IF NOT EXISTS)
local COLUMNS = {
    { 'f_reward_players', 'asset_tier', 'TINYINT NOT NULL DEFAULT 0' },
    { 'f_reward_players', 'asset_last', 'INT NOT NULL DEFAULT 0' },
    { 'f_reward_winners', 'asset', 'TINYINT NOT NULL DEFAULT 0' },
}

---------------------------------------------------------------------------
-- Umum
---------------------------------------------------------------------------
local admins = {}
for _, id in ipairs(config.admins) do admins[id:lower()] = true end

function FR.isAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if admins[id:lower()] then return true end
    end
    return false
end

function FR.rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

function FR.int(v)
    v = tonumber(v)
    return v and v == v and math.floor(v) or nil
end

function FR.notify(src, msg, kind)
    exports.qbx_core:Notify(src, msg, kind or 'inform')
end

---@return table? player, string? citizenid, string? name
function FR.getPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local ci = player.PlayerData.charinfo or {}
    local name = (('%s %s'):format(ci.firstname or '', ci.lastname or '')):match('^%s*(.-)%s*$')
    return player, player.PlayerData.citizenid, name
end

-- jeda per pemain per jenis aksi
local lastAction = {}
function FR.limited(src, kind, ms)
    local key = src .. kind
    local now = GetGameTimer()
    if lastAction[key] and now - lastAction[key] < ms then return true end
    lastAction[key] = now
    return false
end

-- satu aksi berjalan per karakter (cegah klik ganda / request paralel)
local busy = {}
function FR.withLock(cid, fn, ...)
    if busy[cid] then return { ok = false, msg = 'Tunggu, proses sebelumnya belum selesai.' } end
    busy[cid] = true
    local ok, res = pcall(fn, ...)
    busy[cid] = nil
    if not ok then
        lib.print.error(res)
        return { ok = false, msg = 'Terjadi kesalahan, coba lagi.' }
    end
    return res
end

function FR.log(cid, kind, detail)
    MySQL.insert('INSERT INTO f_reward_log (citizenid, kind, detail, created_at) VALUES (?, ?, ?, ?)',
        { cid, kind, json.encode(detail), os.time() })
end

function FR.announce(text)
    if GetResourceState('f_chat') ~= 'started' then return end
    pcall(function()
        exports.f_chat:SendMessage(nil, 'announce', text, { tag = 'HADIAH', color = '#f3b354', anonymous = true, name = '' })
    end)
end

---------------------------------------------------------------------------
-- Saldo (selalu query atomik, tidak ada saldo yang dipegang client)
---------------------------------------------------------------------------
function FR.row(cid)
    local row = MySQL.single.await('SELECT * FROM f_reward_players WHERE citizenid = ?', { cid })
    if row then return row end
    MySQL.insert.await('INSERT IGNORE INTO f_reward_players (citizenid) VALUES (?)', { cid })
    return { citizenid = cid, coins = 0, pity = 0, pulls = 0, daily_day = 0, daily_last = '', asset_tier = 0, asset_last = 0 }
end

---Tambah (atau kurangi, bila negatif) koin; saldo tidak pernah di bawah 0.
function FR.addCoins(cid, amount)
    MySQL.update.await([[INSERT INTO f_reward_players (citizenid, coins) VALUES (?, GREATEST(0, ?))
        ON DUPLICATE KEY UPDATE coins = GREATEST(0, coins + ?)]], { cid, amount, amount })
end

---@return boolean
function FR.spend(cid, amount)
    return MySQL.update.await('UPDATE f_reward_players SET coins = coins - ? WHERE citizenid = ? AND coins >= ?',
        { amount, cid, amount }) == 1
end

---------------------------------------------------------------------------
-- Hadiah: validasi, tampilan, pemberian
---------------------------------------------------------------------------
local vehicles
function FR.vehicles()
    if not vehicles then
        vehicles = {}
        for model, v in pairs(exports.qbx_core:GetVehiclesByName()) do
            if config.vehicleTypes[v.type] then
                local brand = v.brand and v.brand ~= '' and (v.brand .. ' ') or ''
                vehicles[model] = { label = brand .. (v.name or model), category = v.category }
            end
        end
    end
    return vehicles
end

---Membersihkan satu baris hadiah. Dipakai untuk input admin dan config.
---@return table? reward, string? err
function FR.clean(r)
    if type(r) ~= 'table' then return nil, 'Data hadiah tidak valid.' end
    local t = r.type
    if t == 'item' then
        local name, count = tostring(r.name or ''), FR.int(r.count)
        if not ox:Items(name) then return nil, ('Item "%s" tidak ada.'):format(name) end
        if not count or count < 1 or count > L.itemCount then return nil, 'Jumlah item tidak valid.' end
        return { type = 'item', name = name, count = count }
    elseif t == 'vehicle' then
        local model = tostring(r.model or '')
        if not FR.vehicles()[model] then return nil, ('Kendaraan "%s" tidak ada / bukan mobil-motor.'):format(model) end
        return { type = 'vehicle', model = model }
    elseif t == 'money' then
        local amount = FR.int(r.amount)
        if not amount or amount < 1 or amount > L.money then return nil, 'Jumlah uang tidak valid.' end
        return { type = 'money', amount = amount }
    elseif t == 'coins' then
        local amount = FR.int(r.amount)
        if not amount or amount < 1 or amount > L.coins then return nil, 'Jumlah koin tidak valid.' end
        return { type = 'coins', amount = amount }
    elseif t == 'manual' then
        local label = tostring(r.label or ''):sub(1, 60):match('^%s*(.-)%s*$')
        if label == '' then return nil, 'Nama hadiah manual kosong.' end
        local note = tostring(r.note or ''):sub(1, 120):match('^%s*(.-)%s*$')
        return { type = 'manual', label = label, note = note ~= '' and note or 'Datang ke admin untuk mengambil hadiah ini.' }
    end
    return nil, 'Jenis hadiah tidak dikenal.'
end

---@return table? rewards, string? err
function FR.sanitize(list)
    if type(list) ~= 'table' or #list == 0 then return nil, 'Hadiah masih kosong.' end
    if #list > L.rewards then return nil, ('Maksimal %d hadiah.'):format(L.rewards) end
    local out = {}
    for i = 1, #list do
        local r, err = FR.clean(list[i])
        if not r then return nil, err end
        out[i] = r
    end
    return out
end

function FR.label(r)
    if r.type == 'item' then
        local it = ox:Items(r.name)
        return ('%s x%d'):format(it and it.label or r.name, r.count)
    elseif r.type == 'vehicle' then
        local v = FR.vehicles()[r.model]
        return v and v.label or r.model
    elseif r.type == 'money' then
        return FR.rupiah(r.amount)
    elseif r.type == 'coins' then
        return ('%d Koin'):format(r.amount)
    end
    return r.label
end

---Data yang dikirim ke NUI untuk satu hadiah.
function FR.display(r)
    if r.type == 'item' then
        local it = ox:Items(r.name)
        return { type = 'item', name = r.name, count = r.count, label = it and it.label or r.name, img = 'item:' .. r.name }
    elseif r.type == 'vehicle' then
        local v = FR.vehicles()[r.model]
        return { type = 'vehicle', model = r.model, label = v and v.label or r.model, img = 'veh:' .. r.model }
    elseif r.type == 'money' then
        return { type = 'money', amount = r.amount, label = FR.rupiah(r.amount), img = 'item:money' }
    elseif r.type == 'coins' then
        return { type = 'coins', amount = r.amount, label = ('%d Koin'):format(r.amount), img = 'coin' }
    end
    return { type = 'manual', label = r.label, note = r.note, img = 'manual' }
end

function FR.displayList(list)
    local out = {}
    for i, r in ipairs(list) do out[i] = FR.display(r) end
    return out
end

---Cek muat di tas (untuk hadiah pasti: harian, kode, toko).
function FR.canReceive(src, rewards)
    local items, weight = {}, 0
    for _, r in ipairs(rewards) do
        if r.type == 'item' then items[r.name] = (items[r.name] or 0) + r.count end
    end
    for name, count in pairs(items) do
        if not ox:CanCarryItem(src, name, count) then return false end
        local it = ox:Items(name)
        weight = weight + (it and it.weight or 0) * count
    end
    if weight > 0 and not ox:CanCarryWeight(src, weight) then return false end
    return true
end

local SOURCE_LABEL = { gacha = 'Gacha', code = 'Kode', shop = 'Toko', daily = 'Harian' }

function FR.isAsset(r)
    return r.type == 'vehicle' or r.type == 'manual'
end

local function addWinner(cid, name, r, source, status, detail, rarity)
    MySQL.insert([[INSERT INTO f_reward_winners (citizenid, name, reward, detail, source, rarity, asset, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { cid, name, FR.label(r), detail or '', source, rarity or '', FR.isAsset(r) and 1 or 0, status, os.time() })
end

---Memberikan hadiah. Saldo/kode/stok sudah harus dipotong sebelum fungsi ini dipanggil.
---@param ctx table { src, player, cid, name, source }
---@param rewards table[] hasil FR.sanitize; field opsional `_rarity` dari gacha
function FR.give(ctx, rewards)
    local src, cid = ctx.src, ctx.cid
    local coins, drop, notes = 0, {}, {}

    for _, r in ipairs(rewards) do
        local legend = r._rarity == 'legendary'
        if r.type == 'item' then
            if not ox:AddItem(src, r.name, r.count) then drop[#drop + 1] = { r.name, r.count } end
            if legend then addWinner(cid, ctx.name, r, ctx.source, 'otomatis', 'Masuk tas', r._rarity) end
        elseif r.type == 'money' then
            ctx.player.Functions.AddMoney('bank', r.amount, 'f_claimreward:' .. ctx.source)
            if legend then addWinner(cid, ctx.name, r, ctx.source, 'otomatis', 'Masuk rekening', r._rarity) end
        elseif r.type == 'coins' then
            coins = coins + r.amount
            if legend then addWinner(cid, ctx.name, r, ctx.source, 'otomatis', 'Masuk saldo koin', r._rarity) end
        elseif r.type == 'vehicle' then
            local plate = exports.f_vehicles:GeneratePlate()
            local id = exports.f_vehicles:CreatePlayerVehicle({ model = r.model, citizenid = cid, garage = config.vehicleGarage, props = { plate = plate } })
            if id then
                addWinner(cid, ctx.name, r, ctx.source, 'otomatis', ('Plat %s · garasi %s'):format(plate, config.vehicleGarage), r._rarity)
                notes[#notes + 1] = ('%s (plat %s) sudah di garasi dekat Balai Kota.'):format(FR.label(r), plate)
            else
                -- tidak boleh hilang: catat untuk diberikan admin
                addWinner(cid, ctx.name, r, ctx.source, 'menunggu', 'Gagal masuk garasi, berikan manual', r._rarity)
                notes[#notes + 1] = ('%s gagal masuk garasi, hubungi admin.'):format(FR.label(r))
            end
        elseif r.type == 'manual' then
            addWinner(cid, ctx.name, r, ctx.source, 'menunggu', r.note, r._rarity)
            notes[#notes + 1] = ('%s: %s'):format(r.label, r.note)
        end
    end

    if coins > 0 then FR.addCoins(cid, coins) end

    if #drop > 0 then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            ox:CustomDrop('Hadiah', drop, GetEntityCoords(ped))
            notes[#notes + 1] = 'Tas penuh: sisa hadiah dijatuhkan di dekatmu.'
        end
    end

    for _, n in ipairs(notes) do FR.notify(src, n, 'success') end

    local labels = {}
    for i, r in ipairs(rewards) do labels[i] = FR.label(r) end
    FR.log(cid, ctx.source, labels)
    lib.logger(src, 'f_claimreward', ('%s (%s) dapat dari %s: %s'):format(ctx.name, cid, SOURCE_LABEL[ctx.source] or ctx.source, table.concat(labels, ', ')))
    return notes
end

---------------------------------------------------------------------------
-- Toko (cache di memori, diubah hanya lewat admin)
---------------------------------------------------------------------------
FR.shop, FR.shopById = {}, {}

function FR.loadShop()
    local list, byId = {}, {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM f_reward_shop ORDER BY sort ASC, id ASC') or {}) do
        local rewards = FR.sanitize(json.decode(row.rewards) or {})
        if rewards then
            local e = {
                id = row.id, label = row.label, description = row.description, category = row.category,
                rewards = rewards, display = FR.displayList(rewards),
                price = row.price, limit = row.buy_limit,
                expiresAt = row.expires_at, active = row.active == 1 or row.active == true, sort = row.sort,
            }
            list[#list + 1] = e
            byId[e.id] = e
        else
            lib.print.warn(('Barang toko #%s "%s" dilewati: hadiahnya tidak valid lagi.'):format(row.id, row.label))
        end
    end
    FR.shop, FR.shopById = list, byId
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
CreateThread(function()
    for _, q in ipairs(TABLES) do MySQL.query.await(q) end
    for _, c in ipairs(COLUMNS) do
        local exists = MySQL.scalar.await('SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { c[1], c[2] })
        if not exists then MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3])) end
    end

    -- kode yang sudah kedaluwarsa lebih dari 30 hari dibuang
    local old = os.time() - 30 * 86400
    MySQL.query.await('DELETE c FROM f_reward_code_claims c JOIN f_reward_codes k ON k.code = c.code WHERE k.expires_at < ?', { old })
    MySQL.query.await('DELETE FROM f_reward_codes WHERE expires_at < ?', { old })

    if (MySQL.scalar.await('SELECT COUNT(*) FROM f_reward_shop') or 0) == 0 then
        for i, s in ipairs(config.shopSeed) do
            local rewards, err = FR.sanitize(s.rewards)
            if rewards then
                MySQL.insert.await([[INSERT INTO f_reward_shop (label, description, category, rewards, price, buy_limit, sort)
                    VALUES (?, ?, ?, ?, ?, ?, ?)]], { s.label, s.description or '', s.category, json.encode(rewards), s.price, s.limit or 0, i })
            else
                lib.print.warn(('shopSeed "%s" dilewati: %s'):format(s.label, err))
            end
        end
    end

    FR.loadShop()
end)

AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(lastAction) do
        if key:find('^' .. src .. '%a') then lastAction[key] = nil end
    end
end)

---------------------------------------------------------------------------
-- Export untuk script lain (server saja), misal job: exports.f_claimreward:AddCoins(src, 2, 'sampah')
---------------------------------------------------------------------------
exports('AddCoins', function(src, amount, reason)
    amount = FR.int(amount)
    if not amount or amount < 1 or amount > L.coins then return false end
    local _, cid = FR.getPlayer(src)
    if not cid then return false end
    FR.addCoins(cid, amount)
    FR.log(cid, 'export', { amount = amount, reason = tostring(reason or GetInvokingResource()) })
    return true
end)
