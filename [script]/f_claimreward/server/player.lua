-- f_claimreward — aksi pemain: state, harian, kode referral, gacha, toko.
local config = FR.config
local G = config.gacha

---------------------------------------------------------------------------
-- Harian
---------------------------------------------------------------------------
local daily = {}
for day, list in ipairs(config.daily) do
    daily[day] = assert(FR.sanitize(list), ('config daily hari %d tidak valid'):format(day))
end

local function today() return os.date('%Y-%m-%d') end
local function yesterday() return os.date('%Y-%m-%d', os.time() - 86400) end

-- hari berikutnya yang boleh diklaim (bolong sehari = kembali ke hari 1)
local function nextDay(row)
    local streak = row.daily_last == yesterday() and row.daily_day or 0
    return streak % #daily + 1
end

local dailyDisplay
local function dailyState(row)
    if not dailyDisplay then
        dailyDisplay = {}
        for day, list in ipairs(daily) do dailyDisplay[day] = FR.displayList(list) end
    end
    local claimed = row.daily_last == today()
    return { day = claimed and row.daily_day or nextDay(row), claimed = claimed, days = dailyDisplay }
end

---------------------------------------------------------------------------
-- Gacha
---------------------------------------------------------------------------
local rank, pool, others = {}, {}, 0
local legendaryChance
for i, r in ipairs(G.rarities) do
    rank[r.id] = i
    if r.id == 'legendary' then legendaryChance = r.chance else others = others + r.chance end
    pool[r.id] = {}
    for _, e in ipairs(G.pool[r.id] or {}) do
        local clean, err = FR.clean(e)
        if clean then
            clean.weight = math.max(1, FR.int(e.weight) or 1)
            clean.featured = e.featured
            pool[r.id][#pool[r.id] + 1] = clean
        else
            lib.print.warn(('gacha %s dilewati: %s'):format(r.id, err))
        end
    end
    assert(#pool[r.id] > 0, ('pool gacha "%s" kosong'):format(r.id))
end
assert(legendaryChance, 'rarity legendary wajib ada')

-- Legendaris dibagi: aset (kendaraan/rumah) dan non-aset
local A = G.assets
local assetPool, otherPool = {}, {}
for _, e in ipairs(pool.legendary) do
    local list = FR.isAsset(e) and assetPool or otherPool
    list[#list + 1] = e
end
assert(#otherPool > 0, 'pool legendary butuh minimal 1 hadiah non-aset (dipakai saat kuota aset habis)')

-- tingkat karakter (0 = 100%, 1 = 50%, 2 = 25%), naik kembali 1 tingkat tiap recoverDays tanpa aset
local function assetTier(row, now)
    local tier = row.asset_tier or 0
    if tier > 0 and (row.asset_last or 0) > 0 then
        tier = tier - math.floor((now - row.asset_last) / (A.recoverDays * 86400))
    end
    return math.max(0, math.min(#A.share - 1, tier))
end

-- kuota aset se-server per minggu (Senin 00:00 waktu server); hitungan di memori, dimuat dari DB tiap minggu baru
local week = { start = -1, count = 0 }

local function weekStart(t)
    local d = os.date('*t', t)
    return os.time({ year = d.year, month = d.month, day = d.day - (d.wday + 5) % 7, hour = 0, min = 0, sec = 0 })
end

local function loadWeek()
    local ws = weekStart(os.time())
    if week.start == ws then return end
    local used = MySQL.scalar.await("SELECT COUNT(*) FROM f_reward_winners WHERE source = 'gacha' AND asset = 1 AND created_at >= ?", { ws }) or 0
    if week.start ~= ws then week.start, week.count = ws, used end
end

function FR.assetWeek()
    loadWeek()
    return week.count, A.weeklyCap
end

local function pick(list)
    local total = 0
    for _, e in ipairs(list) do total = total + e.weight end
    local n = math.random() * total
    for _, e in ipairs(list) do
        n = n - e.weight
        if n < 0 then return e end
    end
    return list[#list]
end

---@param pity integer tarikan ke-berapa sejak Legendary terakhir (termasuk tarikan ini)
local function rollRarity(pity)
    if pity >= G.pity.hard then return 'legendary' end
    local leg = math.min(100, legendaryChance + math.max(0, pity - G.pity.softStart) * G.pity.softStep)
    if math.random() * 100 < leg then return 'legendary' end
    local n = math.random() * others
    for _, r in ipairs(G.rarities) do
        if r.id ~= 'legendary' then
            n = n - r.chance
            if n < 0 then return r.id end
        end
    end
    return G.rarities[1].id
end

-- peluang & isi pool tidak dikirim ke client; hanya label rarity dan hadiah unggulan (Epik/Legendaris)
local banner
local function bannerState()
    if banner then return banner end
    local rarities, featured = {}, {}
    for i, r in ipairs(G.rarities) do
        rarities[i] = { id = r.id, label = r.label }
        if r.id == 'legendary' or r.id == 'epic' then
            for _, e in ipairs(pool[r.id]) do
                local d = FR.display(e)
                d.rarity = r.id
                d.featured = e.featured
                featured[#featured + 1] = d
            end
        end
    end
    -- urutan etalase: hadiah utama, kendaraan/rumah, Legendaris lain, lalu Epik
    local function score(d)
        return (d.featured and 4 or 0) + ((d.type == 'vehicle' or d.type == 'manual') and 2 or 0) + rank[d.rarity]
    end
    table.sort(featured, function(a, b) return score(a) > score(b) end)
    banner = {
        title = G.title, subtitle = G.subtitle, costOne = G.costOne, costTen = G.costTen,
        hard = G.pity.hard, softStart = G.pity.softStart,
        guarantee = G.rarities[rank[G.tenGuarantee]].label, rarities = rarities, featured = featured,
    }
    return banner
end

---------------------------------------------------------------------------
-- Toko
---------------------------------------------------------------------------
local function shopState(cid)
    local now, list, limited = os.time(), {}, false
    for _, e in ipairs(FR.shop) do
        if e.active and (e.expiresAt == 0 or e.expiresAt > now) then
            list[#list + 1] = e
            if e.limit > 0 then limited = true end
        end
    end

    local bought = {}
    if limited then
        for _, row in ipairs(MySQL.query.await('SELECT shop_id, amount FROM f_reward_shop_buys WHERE citizenid = ?', { cid }) or {}) do
            bought[row.shop_id] = row.amount
        end
    end

    local out = {}
    for i, e in ipairs(list) do
        out[i] = {
            id = e.id, label = e.label, description = e.description, category = e.category,
            rewards = e.display, price = e.price,
            limit = e.limit, bought = bought[e.id] or 0, expiresAt = e.expiresAt,
        }
    end
    return out
end

---------------------------------------------------------------------------
-- Callback
---------------------------------------------------------------------------
local function balance(row)
    return { coins = row.coins, pity = row.pity }
end

lib.callback.register('f_claimreward:state', function(src)
    local player, cid = FR.getPlayer(src)
    if not player then return end
    local row = FR.row(cid)
    return {
        balance = balance(row),
        daily = dailyState(row),
        gacha = bannerState(),
        shop = shopState(cid),
        admin = FR.isAdmin(src),
        now = os.time(),
    }
end)

lib.callback.register('f_claimreward:daily', function(src)
    if FR.limited(src, 'daily', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, cid, name = FR.getPlayer(src)
    if not player then return { ok = false } end

    return FR.withLock(cid, function()
        local row = FR.row(cid)
        local date = today()
        if row.daily_last == date then return { ok = false, msg = 'Hadiah hari ini sudah diklaim. Kembali besok!' } end

        local day = nextDay(row)
        if not FR.canReceive(src, daily[day]) then return { ok = false, msg = 'Tas penuh, kosongkan dulu.' } end

        local done = MySQL.update.await('UPDATE f_reward_players SET daily_day = ?, daily_last = ? WHERE citizenid = ? AND daily_last <> ?',
            { day, date, cid, date }) == 1
        if not done then return { ok = false, msg = 'Hadiah hari ini sudah diklaim.' } end

        FR.give({ src = src, player = player, cid = cid, name = name, source = 'daily' }, daily[day])
        row = FR.row(cid)
        return { ok = true, msg = ('Hadiah Hari %d diklaim!'):format(day), balance = balance(row), daily = dailyState(row) }
    end)
end)

---------------------------------------------------------------------------
-- Kode referral
---------------------------------------------------------------------------
local attempts = {} -- citizenid -> { n, since }

local function normalize(code)
    code = tostring(code or ''):upper():gsub('%s', '')
    return code:match('^[A-Z0-9_%-]+$') and #code >= 3 and #code <= 24 and code or nil
end

local function blocked(cid)
    local a = attempts[cid]
    if not a then return false end
    if os.time() - a.since > config.codeAttempts.window then
        attempts[cid] = nil
        return false
    end
    return a.n >= config.codeAttempts.max, math.ceil((config.codeAttempts.window - (os.time() - a.since)) / 60)
end

local function failAttempt(cid)
    local a = attempts[cid]
    if not a then attempts[cid] = { n = 1, since = os.time() } else a.n = a.n + 1 end
end

---Validasi kode untuk karakter ini. Mengembalikan baris kode + hadiah, atau nil + pesan + status.
---@return table? row, any rewardsOrMsg, string? status
local function lookup(cid, raw)
    local isBlocked, minutes = blocked(cid)
    if isBlocked then return nil, ('Terlalu banyak percobaan. Coba lagi %d menit lagi.'):format(minutes) end

    local code = normalize(raw)
    local row = code and MySQL.single.await('SELECT * FROM f_reward_codes WHERE code = ?', { code })
    if not row then
        failAttempt(cid)
        return nil, 'Kode referral tidak ditemukan.'
    end
    if row.expires_at <= os.time() then return nil, 'Kode referral expired.', 'expired' end
    if MySQL.scalar.await('SELECT 1 FROM f_reward_code_claims WHERE code = ? AND citizenid = ?', { code, cid }) then
        return nil, 'Kode ini sudah kamu klaim.', 'claimed'
    end
    if row.max_uses > 0 and row.uses >= row.max_uses then return nil, 'Kuota kode ini sudah habis.', 'quota' end

    local rewards = FR.sanitize(json.decode(row.rewards) or {})
    if not rewards then return nil, 'Hadiah kode ini tidak valid, hubungi admin.' end
    return row, rewards
end

lib.callback.register('f_claimreward:checkCode', function(src, data)
    if FR.limited(src, 'code', 800) then return { ok = false, msg = 'Pelan-pelan.' } end
    local player, cid = FR.getPlayer(src)
    if not player then return { ok = false } end

    local row, rewards, status = lookup(cid, data and data.code)
    if not row then return { ok = false, msg = rewards, status = status } end
    return { ok = true, code = row.code, rewards = FR.displayList(rewards), expiresAt = row.expires_at }
end)

lib.callback.register('f_claimreward:claimCode', function(src, data)
    if FR.limited(src, 'claim', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, cid, name = FR.getPlayer(src)
    if not player then return { ok = false } end

    return FR.withLock(cid, function()
        local row, rewards, status = lookup(cid, data and data.code)
        if not row then return { ok = false, msg = rewards, status = status } end
        if not FR.canReceive(src, rewards) then return { ok = false, msg = 'Tas penuh, kosongkan dulu.' } end

        local now = os.time()
        -- update.await = affectedRows (insert.await memberi insertId, selalu 0 karena tabel ini tanpa auto-increment)
        if MySQL.update.await('INSERT IGNORE INTO f_reward_code_claims (code, citizenid, claimed_at) VALUES (?, ?, ?)', { row.code, cid, now }) ~= 1 then
            return { ok = false, msg = 'Kode ini sudah kamu klaim.', status = 'claimed' }
        end
        local counted = MySQL.update.await('UPDATE f_reward_codes SET uses = uses + 1 WHERE code = ? AND expires_at > ? AND (max_uses = 0 OR uses < max_uses)',
            { row.code, now }) == 1
        if not counted then
            MySQL.query.await('DELETE FROM f_reward_code_claims WHERE code = ? AND citizenid = ?', { row.code, cid })
            return { ok = false, msg = 'Kode baru saja expired / kuotanya habis.' }
        end

        FR.give({ src = src, player = player, cid = cid, name = name, source = 'code' }, rewards)
        return { ok = true, msg = 'Hadiah berhasil diklaim!', balance = balance(FR.row(cid)) }
    end)
end)

---------------------------------------------------------------------------
-- Gacha
---------------------------------------------------------------------------
lib.callback.register('f_claimreward:pull', function(src, data)
    if FR.limited(src, 'pull', 1200) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, cid, name = FR.getPlayer(src)
    if not player then return { ok = false } end
    local count = data and data.count == 10 and 10 or 1
    local cost = count == 10 and G.costTen or G.costOne

    return FR.withLock(cid, function()
        local row = FR.row(cid)
        if row.coins < cost then return { ok = false, msg = ('Koin tidak cukup (butuh %d).'):format(cost) } end

        loadWeek()

        -- dari sini sampai UPDATE tidak ada await: kuota mingguan dipesan tanpa bisa diserobot request lain
        local now = os.time()
        local tier, assetLast, reserved = assetTier(row, now), row.asset_last, 0
        local pity, results, best = row.pity, {}, 0
        for i = 1, count do
            pity = pity + 1
            local rid = rollRarity(pity)
            local reward
            if rid == 'legendary' then
                pity = 0
                if #assetPool > 0 and week.count < A.weeklyCap and math.random() * 100 < A.share[tier + 1] then
                    week.count, reserved = week.count + 1, reserved + 1
                    tier, assetLast = math.min(#A.share - 1, tier + 1), now
                    reward = pick(assetPool)
                else
                    reward = pick(otherPool)
                end
            else
                reward = pick(pool[rid])
            end
            results[i] = { rarity = rid, reward = reward }
            best = math.max(best, rank[rid])
        end
        if count == 10 and best < rank[G.tenGuarantee] then
            results[10] = { rarity = G.tenGuarantee, reward = pick(pool[G.tenGuarantee]) }
        end

        local paid = MySQL.update.await([[UPDATE f_reward_players SET coins = coins - ?, pity = ?, pulls = pulls + ?,
            asset_tier = ?, asset_last = ? WHERE citizenid = ? AND coins >= ? AND pity = ?]],
            { cost, pity, count, tier, assetLast, cid, cost, row.pity }) == 1
        if not paid then
            week.count = week.count - reserved
            return { ok = false, msg = 'Saldo berubah, coba lagi.' }
        end

        local rewards, out = {}, {}
        for i, res in ipairs(results) do
            local r = {}
            for k, v in pairs(res.reward) do r[k] = v end
            r.weight, r.featured, r._rarity = nil, nil, res.rarity
            rewards[i] = r
            local d = FR.display(r)
            d.rarity = res.rarity
            out[i] = d
        end
        FR.give({ src = src, player = player, cid = cid, name = name, source = 'gacha' }, rewards)

        if G.announce then
            for _, r in ipairs(rewards) do
                if r._rarity == 'legendary' then
                    FR.announce(('%s mendapatkan %s LEGENDARIS dari Gacha!'):format(name, FR.label(r)))
                end
            end
        end

        return { ok = true, results = out, balance = balance(FR.row(cid)) }
    end)
end)

---------------------------------------------------------------------------
-- Toko
---------------------------------------------------------------------------
lib.callback.register('f_claimreward:buy', function(src, data)
    if FR.limited(src, 'buy', 1200) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local player, cid, name = FR.getPlayer(src)
    if not player then return { ok = false } end
    local e = FR.shopById[FR.int(data and data.id) or -1]

    return FR.withLock(cid, function()
        if not e or not e.active or (e.expiresAt > 0 and e.expiresAt <= os.time()) then
            return { ok = false, msg = 'Barang ini sudah tidak dijual.' }
        end
        if e.limit > 0 then
            local bought = MySQL.scalar.await('SELECT amount FROM f_reward_shop_buys WHERE shop_id = ? AND citizenid = ?', { e.id, cid }) or 0
            if bought >= e.limit then return { ok = false, msg = 'Batas pembelian barang ini sudah tercapai.' } end
        end
        if not FR.canReceive(src, e.rewards) then return { ok = false, msg = 'Tas penuh, kosongkan dulu.' } end
        if not FR.spend(cid, e.price) then return { ok = false, msg = 'Koin tidak cukup.' } end

        MySQL.insert.await('INSERT INTO f_reward_shop_buys (shop_id, citizenid, amount) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE amount = amount + 1', { e.id, cid })
        FR.give({ src = src, player = player, cid = cid, name = name, source = 'shop' }, e.rewards)
        return { ok = true, msg = ('%s berhasil dibeli!'):format(e.label), balance = balance(FR.row(cid)), shop = shopState(cid) }
    end)
end)

RegisterCommand(config.command, function(src)
    if src > 0 then TriggerClientEvent('f_claimreward:open', src) end
end, false)
