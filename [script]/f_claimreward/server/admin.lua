-- f_claimreward — aksi admin. Setiap callback dicek lisensi di server (config.admins).
local L = FR.config.limits
local CATEGORIES = { bundle = true, vehicle = true, item = true, other = true }

local itemList, vehicleList

local function items()
    if not itemList then
        itemList = {}
        for name, it in pairs(exports.ox_inventory:Items()) do
            itemList[#itemList + 1] = { name = name, label = it.label or name }
        end
        table.sort(itemList, function(a, b) return a.label:lower() < b.label:lower() end)
    end
    return itemList
end

local function vehicleOptions()
    if not vehicleList then
        vehicleList = {}
        for model, v in pairs(FR.vehicles()) do
            vehicleList[#vehicleList + 1] = { model = model, label = v.label }
        end
        table.sort(vehicleList, function(a, b) return a.label:lower() < b.label:lower() end)
    end
    return vehicleList
end

local function adminName(src)
    local _, cid, name = FR.getPlayer(src)
    return ('%s (%s)'):format(name ~= '' and name or GetPlayerName(src), cid or src)
end

local function audit(src, msg)
    lib.print.info(('[admin] %s: %s'):format(GetPlayerName(src), msg))
    lib.logger(src, 'f_claimreward', msg)
end

local function admin(name, fn)
    lib.callback.register('f_claimreward:' .. name, function(src, data)
        if not FR.isAdmin(src) then return { ok = false, msg = 'Tidak ada akses.' } end
        if FR.limited(src, name, 300) then return { ok = false, msg = 'Pelan-pelan.' } end
        return fn(src, type(data) == 'table' and data or {})
    end)
end

---------------------------------------------------------------------------
-- Data awal
---------------------------------------------------------------------------
admin('adminBoot', function()
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local p = exports.qbx_core:GetPlayer(tonumber(id))
        if p then
            local ci = p.PlayerData.charinfo or {}
            players[#players + 1] = { id = tonumber(id), cid = p.PlayerData.citizenid, name = ('%s %s'):format(ci.firstname or '', ci.lastname or '') }
        end
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    return { ok = true, items = items(), vehicles = vehicleOptions(), players = players }
end)

---------------------------------------------------------------------------
-- Kode referral
---------------------------------------------------------------------------
local function codeList()
    local out = {}
    for i, row in ipairs(MySQL.query.await('SELECT * FROM f_reward_codes ORDER BY created_at DESC LIMIT 200') or {}) do
        local rewards = FR.sanitize(json.decode(row.rewards) or {}) or {}
        out[i] = {
            code = row.code, rewards = FR.displayList(rewards), expiresAt = row.expires_at,
            maxUses = row.max_uses, uses = row.uses, createdBy = row.created_by, createdAt = row.created_at,
        }
    end
    return out
end

admin('adminCodes', function()
    return { ok = true, codes = codeList(), now = os.time() }
end)

admin('adminSaveCode', function(src, data)
    local code = tostring(data.code or ''):upper():gsub('%s', '')
    if not code:match('^[A-Z0-9_%-]+$') or #code < 3 or #code > 24 then
        return { ok = false, msg = 'Kode 3-24 karakter: huruf, angka, - atau _.' }
    end
    local rewards, err = FR.sanitize(data.rewards)
    if not rewards then return { ok = false, msg = err } end
    local minutes = FR.int(data.minutes)
    if not minutes or minutes < 1 or minutes > L.minutes then return { ok = false, msg = 'Masa berlaku tidak valid.' } end
    local maxUses = FR.int(data.maxUses) or 0
    if maxUses < 0 or maxUses > 100000 then return { ok = false, msg = 'Kuota tidak valid.' } end

    local now = os.time()
    local existing = MySQL.scalar.await('SELECT expires_at FROM f_reward_codes WHERE code = ?', { code })
    if existing and existing > now then return { ok = false, msg = 'Kode ini masih aktif. Hapus dulu atau pakai kode lain.' } end
    if existing then
        MySQL.query.await('DELETE FROM f_reward_code_claims WHERE code = ?', { code })
        MySQL.query.await('DELETE FROM f_reward_codes WHERE code = ?', { code })
    end

    MySQL.insert.await([[INSERT INTO f_reward_codes (code, rewards, expires_at, max_uses, uses, created_by, created_at)
        VALUES (?, ?, ?, ?, 0, ?, ?)]], { code, json.encode(rewards), now + minutes * 60, maxUses, adminName(src), now })
    audit(src, ('buat kode %s (%d menit, kuota %d): %s'):format(code, minutes, maxUses, json.encode(rewards)))
    return { ok = true, msg = ('Kode %s dibuat, berlaku %d menit.'):format(code, minutes), codes = codeList(), now = now }
end)

admin('adminDeleteCode', function(src, data)
    local code = tostring(data.code or ''):upper()
    MySQL.query.await('DELETE FROM f_reward_code_claims WHERE code = ?', { code })
    MySQL.query.await('DELETE FROM f_reward_codes WHERE code = ?', { code })
    audit(src, 'hapus kode ' .. code)
    return { ok = true, msg = ('Kode %s dihapus.'):format(code), codes = codeList(), now = os.time() }
end)

---------------------------------------------------------------------------
-- Toko
---------------------------------------------------------------------------
local function shopList()
    local out = {}
    for i, e in ipairs(FR.shop) do
        out[i] = {
            id = e.id, label = e.label, description = e.description, category = e.category,
            rewards = e.rewards, display = e.display, price = e.price,
            limit = e.limit, expiresAt = e.expiresAt, active = e.active, sort = e.sort,
        }
    end
    return out
end

admin('adminShop', function()
    return { ok = true, shop = shopList(), now = os.time() }
end)

admin('adminSaveShop', function(src, data)
    local label = tostring(data.label or ''):sub(1, 60):match('^%s*(.-)%s*$')
    if label == '' then return { ok = false, msg = 'Nama barang kosong.' } end
    local description = tostring(data.description or ''):sub(1, 200)
    local category = CATEGORIES[data.category] and data.category or nil
    if not category then return { ok = false, msg = 'Kategori tidak valid.' } end
    local rewards, err = FR.sanitize(data.rewards)
    if not rewards then return { ok = false, msg = err } end
    local price = FR.int(data.price)
    if not price or price < 1 or price > L.coins then return { ok = false, msg = 'Harga tidak valid.' } end
    local limit = FR.int(data.limit) or 0
    if limit < 0 or limit > 1000 then return { ok = false, msg = 'Batas beli tidak valid.' } end
    local sort = FR.int(data.sort) or 0
    local active = data.active and 1 or 0

    -- minutes: -1 = tetap seperti sebelumnya, 0 = selamanya, >0 = berlaku sekian menit dari sekarang
    local minutes = FR.int(data.minutes) or 0
    if minutes > L.minutes then return { ok = false, msg = 'Masa berlaku tidak valid.' } end
    local id = FR.int(data.id)
    local old = id and FR.shopById[id]
    if id and not old then return { ok = false, msg = 'Barang tidak ditemukan.' } end
    local expiresAt = minutes > 0 and os.time() + minutes * 60 or (minutes < 0 and old and old.expiresAt) or 0

    local params = { label, description, category, json.encode(rewards), price, limit, expiresAt, active, sort }
    if old then
        params[#params + 1] = id
        MySQL.update.await([[UPDATE f_reward_shop SET label = ?, description = ?, category = ?, rewards = ?, price = ?,
            buy_limit = ?, expires_at = ?, active = ?, sort = ? WHERE id = ?]], params)
    else
        id = MySQL.insert.await([[INSERT INTO f_reward_shop (label, description, category, rewards, price, buy_limit, expires_at, active, sort)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], params)
    end
    FR.loadShop()
    audit(src, ('simpan toko #%s %s: %d koin'):format(id, label, price))
    return { ok = true, msg = ('"%s" disimpan.'):format(label), id = id, shop = shopList(), now = os.time() }
end)

admin('adminDeleteShop', function(src, data)
    local id = FR.int(data.id)
    local e = id and FR.shopById[id]
    if not e then return { ok = false, msg = 'Barang tidak ditemukan.' } end
    MySQL.query.await('DELETE FROM f_reward_shop_buys WHERE shop_id = ?', { id })
    MySQL.query.await('DELETE FROM f_reward_shop WHERE id = ?', { id })
    FR.loadShop()
    audit(src, ('hapus toko #%d %s'):format(id, e.label))
    return { ok = true, msg = ('"%s" dihapus.'):format(e.label), shop = shopList(), now = os.time() }
end)

---------------------------------------------------------------------------
-- Beri / kurangi koin
---------------------------------------------------------------------------
admin('adminGive', function(src, data)
    local target = tostring(data.target or ''):gsub('%s', '')
    local amount = FR.int(data.amount)
    if not amount or amount == 0 or math.abs(amount) > L.coins then return { ok = false, msg = 'Jumlah tidak valid.' } end

    local cid, tsrc
    local id = tonumber(target)
    if id and GetPlayerName(id) then
        local p = exports.qbx_core:GetPlayer(id)
        if not p then return { ok = false, msg = 'Pemain itu belum memilih karakter.' } end
        cid, tsrc = p.PlayerData.citizenid, id
    else
        target = target:upper()
        if target:match('^[A-Z0-9]+$') and MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ?', { target }) then
            cid = target
            local p = exports.qbx_core:GetPlayerByCitizenId(cid)
            tsrc = p and p.PlayerData.source
        end
    end
    if not cid then return { ok = false, msg = 'Pemain tidak ditemukan (isi ID server online atau citizenid).' } end

    FR.addCoins(cid, amount)
    FR.log(cid, 'admin', { amount = amount, by = adminName(src) })
    audit(src, ('%+d Koin ke %s'):format(amount, cid))
    if tsrc then
        FR.notify(tsrc, amount > 0 and ('Kamu menerima %d Koin dari admin. Cek /%s'):format(amount, FR.config.command)
            or ('%d Koin kamu dikurangi admin.'):format(-amount), amount > 0 and 'success' or 'inform')
    end
    return { ok = true, msg = ('%+d Koin untuk %s.'):format(amount, cid) }
end)

---------------------------------------------------------------------------
-- Pemenang (verifikasi Legendary, kendaraan & hadiah manual)
---------------------------------------------------------------------------
local function winnerList(status)
    local query = status == 'menunggu'
        and "SELECT * FROM f_reward_winners WHERE status = 'menunggu' ORDER BY id DESC LIMIT 200"
        or 'SELECT * FROM f_reward_winners ORDER BY id DESC LIMIT 200'
    return MySQL.query.await(query) or {}
end

admin('adminWinners', function(_, data)
    local used, cap = FR.assetWeek()
    return { ok = true, winners = winnerList(data.status), weekAssets = used, weekCap = cap }
end)

admin('adminMarkWinner', function(src, data)
    local id = FR.int(data.id)
    local done = id and MySQL.update.await("UPDATE f_reward_winners SET status = 'selesai', handled_by = ?, handled_at = ? WHERE id = ? AND status = 'menunggu'",
        { adminName(src), os.time(), id }) == 1
    if not done then return { ok = false, msg = 'Sudah ditandai / tidak ditemukan.' } end
    audit(src, ('tandai hadiah #%d sudah diberikan'):format(id))
    return { ok = true, msg = 'Ditandai sudah diberikan.', winners = winnerList(data.status) }
end)
