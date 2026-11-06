-- f_petshop server: semua pembelian, status hewan, dan pengobatan divalidasi di sini.
-- Satu pemain boleh memanggil semua hewannya sekaligus.

local petsById, foodByItem, shopItems = {}, {}, {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end
-- makanan (hunger) & minuman (thirst) sama-sama diberikan lewat callback feed
for _, f in ipairs(Config.Food) do foodByItem[f.item] = f shopItems[f.item] = f end
for _, d in ipairs(Config.Drinks) do foodByItem[d.item] = d shopItems[d.item] = d end
for _, s in ipairs(Config.Supplies or {}) do shopItems[s.item] = s end

local active = {}   -- [src] = { [petId] = { id, row, dead, netId?, spawnAt? } }
local deadAt = {}   -- [petId] = vec3 posisi terakhir hewan mati (supaya tidak bisa "teleport" ke klinik)
local cooldown = {} -- [src] = { [aksi] = GetGameTimer() }
local trials = {}   -- [src] = { row, ends = os.time(), warned } hewan coba (id hewan = -src, tidak disimpan)

local function getPlayer(src) return exports.qbx_core:GetPlayer(src) end

local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = kind or 'inform' })
end

local function rp(n) return 'Rp ' .. lib.math.groupdigits(math.floor(n), '.') end

-- jeda anti-spam per pemain per jenis aksi
local function spam(src, key, ms)
    local now = GetGameTimer()
    local c = cooldown[src]
    if not c then c = {} cooldown[src] = c end
    if c[key] and now - c[key] < ms then return true end
    c[key] = now
    return false
end

local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= dist
end

local function cid(src)
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid, player
end

-- nama karakter ("Budi Santoso")
local function fullName(player)
    local c = player.PlayerData.charinfo or {}
    local name = ('%s %s'):format(c.firstname or '', c.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_pets` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `pet` VARCHAR(32) NOT NULL,
            `name` VARCHAR(32) NOT NULL,
            `hunger` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `health` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `dead` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    -- kolom yang ditambahkan belakangan (tabel lama tidak punya)
    local function addColumn(name, definition)
        local has = MySQL.scalar.await([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'f_pets' AND COLUMN_NAME = ?
        ]], { name })
        if (has or 0) == 0 then MySQL.query.await(('ALTER TABLE `f_pets` ADD COLUMN `%s` %s'):format(name, definition)) end
    end
    addColumn('variant', 'TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `name`') -- warna (toko preview 3D)
    addColumn('acc', 'TEXT NULL')                                              -- aksesoris (JSON)
    addColumn('thirst', 'TINYINT UNSIGNED NOT NULL DEFAULT 100 AFTER `hunger`') -- haus (100 = segar)

    -- pengajuan kepemilikan hewan (disetujui Admin / Owner lewat /admin)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_pet_requests` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `player_name` VARCHAR(100) NOT NULL,
            `pet` VARCHAR(32) NOT NULL,
            `variant` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `name` VARCHAR(32) NOT NULL,
            `status` VARCHAR(10) NOT NULL DEFAULT 'pending',
            `decided_by` VARCHAR(100) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `decided_at` TIMESTAMP NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    for old, new in pairs(Config.LegacyPets or {}) do
        MySQL.update.await('UPDATE f_pets SET pet = ?, variant = ? WHERE pet = ?', { new[1], new[2], old })
    end
end)

local function getRow(id, citizenid)
    return MySQL.single.await('SELECT * FROM f_pets WHERE id = ? AND citizenid = ? LIMIT 1', { id, citizenid })
end

-- lapar/haus disimpan pecahan di memori (supaya turunnya pas 8 jam), dibulatkan saat disimpan/dikirim
local function round(n) return math.floor((n or 0) + 0.5) end

local function savePet(a)
    if a.trial then return end -- hewan coba tidak disimpan
    MySQL.update('UPDATE f_pets SET hunger = ?, thirst = ?, health = ?, dead = ? WHERE id = ?',
        { round(a.row.hunger), round(a.row.thirst), round(a.row.health), a.dead and 1 or 0, a.id })
end

---------------------------------------------------------------------------
-- Entity helpers
---------------------------------------------------------------------------
local function list(src)
    local l = active[src]
    if not l then l = {} active[src] = l end
    return l
end

local function entityOf(a)
    if not a or not a.netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(a.netId)
    return (ent ~= 0 and DoesEntityExist(ent)) and ent or 0
end

---@return table? a, number? petId
local function byNetId(src, netId)
    for id, a in pairs(active[src] or {}) do
        if a.netId == netId then return a, id end
    end
end

-- cari hewan (milik siapa pun) dari netId
---@return table? a, number? ownerSrc
local function findByNet(netId)
    for src, l in pairs(active) do
        for _, a in pairs(l) do
            if a.netId == netId then return a, src end
        end
    end
end

-- aksesoris tersimpan sebagai JSON: { owned = { [prop] = true }, collars = { ["n"] = true },
-- worn = { head = prop, ..., collar = n } }
local function accOf(row)
    if not row.accT then
        local ok, t = pcall(json.decode, row.acc or '')
        t = ok and type(t) == 'table' and t or {}
        t.owned, t.collars, t.worn = t.owned or {}, t.collars or {}, t.worn or {}
        row.accT = t
    end
    return row.accT
end

-- carrier = yang sedang menggendong, seatVeh/seat = kendaraan (netId) & kursi tempat hewan mati ditaruh
-- fpetacc = aksesoris yang dipakai (prop dipasang di tiap client, kalung warna oleh pemilik)
local function setState(src, a)
    local ent = entityOf(a)
    if ent == 0 then return end
    Entity(ent).state:set('fpet', {
        id = a.id, owner = src, name = a.row.name, pet = a.row.pet, dead = a.dead,
        carrier = a.carrier, seatVeh = a.seatVeh, seat = a.seat, leash = a.leash,
    }, true)
    Entity(ent).state:set('fpetacc', accOf(a.row).worn, true)
end

local function pushStatus(src, a)
    TriggerClientEvent('f_petshop:client:status', src, {
        id = a.id, hunger = round(a.row.hunger), thirst = round(a.row.thirst), health = round(a.row.health), dead = a.dead,
    })
end

local function despawn(src, id)
    local l = active[src]
    local a = l and l[id]
    if not a then return end
    local ent = entityOf(a)
    if a.carrier then TriggerClientEvent('f_petshop:client:forceDrop', a.carrier, a.netId) end
    if ent ~= 0 then
        if a.dead then deadAt[a.id] = GetEntityCoords(ent) end
        DeleteEntity(ent)
    end
    if not a.dead then deadAt[a.id] = nil end
    savePet(a)
    l[id] = nil
    if a.trial then trials[src] = nil end -- hewan coba dipulangkan = masa coba selesai
    TriggerClientEvent('f_petshop:client:despawned', src, id)
end

local function despawnAll(src)
    for id in pairs(active[src] or {}) do despawn(src, id) end
    active[src] = nil
end

---------------------------------------------------------------------------
-- Toko
---------------------------------------------------------------------------
lib.callback.register('f_petshop:getShop', function(src)
    local citizenid, player = cid(src)
    if not citizenid then return end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM f_pets WHERE citizenid = ?', { citizenid }) or 0
    local pending = MySQL.single.await("SELECT id, pet, name FROM f_pet_requests WHERE citizenid = ? AND status = 'pending' LIMIT 1", { citizenid })
    if pending then pending.label = petsById[pending.pet] and petsById[pending.pet].label or pending.pet end
    local t = trials[src]
    return {
        owned = count,
        max = Config.MaxPets,
        cash = player.PlayerData.money.cash or 0,
        bank = player.PlayerData.money.bank or 0,
        pending = pending,
        trial = t and { label = petsById[t.row.pet].label, left = math.max(0, t.ends - os.time()) } or nil,
    }
end)

local function pay(player, method, amount, reason)
    if method ~= 'cash' and method ~= 'bank' then return false end
    return player.Functions.RemoveMoney(method, amount, reason)
end

-- hewan & warna yang dipilih di toko (dipakai untuk coba & pengajuan)
local function pickPet(petKey, variant)
    local pet = petsById[petKey]
    if not pet then return nil, nil, 'Hewan tidak ditemukan.' end
    variant = math.floor(tonumber(variant) or 0)
    local colours = pet.variants and #pet.variants.labels or 1
    if variant < 0 or variant >= colours then return nil, nil, 'Warna tidak valid.' end
    return pet, variant
end

-- Coba 5 menit: hewan sementara (id = -src), tidak tersimpan, otomatis pulang saat waktu habis.
lib.callback.register('f_petshop:trial', function(src, petKey, variant)
    if spam(src, 'trial', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    if not cid(src) then return { ok = false } end
    if not near(src, Config.Shop.coords, 8.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end
    if trials[src] then return { ok = false, msg = 'Kembalikan dulu hewan yang sedang kamu coba.' } end
    local pet, err
    pet, variant, err = pickPet(petKey, variant)
    if not pet then return { ok = false, msg = err } end

    trials[src] = {
        row = { id = -src, pet = pet.id, name = pet.label, variant = variant, hunger = 100, thirst = 100, health = 100, dead = false },
        ends = os.time() + Config.Trial.minutes * 60,
    }
    return { ok = true, id = -src, msg = ('Kamu mencoba %s selama %d menit. Atur lewat Menu Hewan.'):format(pet.label, Config.Trial.minutes) }
end)

lib.callback.register('f_petshop:trialReturn', function(src)
    if not trials[src] then return false end
    despawn(src, -src)
    trials[src] = nil
    return true
end)

-- staff yang boleh menyetujui (Admin & Owner, bukan Support)
local function approvers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local ok, role = pcall(function() return exports.f_admin:GetRole(tonumber(id)) end)
        if ok and (role == 'owner' or role == 'admin') then out[#out + 1] = tonumber(id) end
    end
    return out
end

-- Ajukan kepemilikan: gratis, menunggu persetujuan Admin / Owner di /admin → Pengajuan Hewan
lib.callback.register('f_petshop:request', function(src, petKey, name, variant)
    if spam(src, 'request', 2000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid, player = cid(src)
    if not citizenid then return { ok = false } end
    if not near(src, Config.Shop.coords, 8.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end
    local pet, err
    pet, variant, err = pickPet(petKey, variant)
    if not pet then return { ok = false, msg = err } end

    name = type(name) == 'string' and name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < 2 or #name > Config.NameMaxLength then
        return { ok = false, msg = ('Nama harus 2-%d karakter.'):format(Config.NameMaxLength) }
    end
    if MySQL.scalar.await("SELECT 1 FROM f_pet_requests WHERE citizenid = ? AND status = 'pending' LIMIT 1", { citizenid }) then
        return { ok = false, msg = 'Kamu masih punya pengajuan yang menunggu persetujuan.' }
    end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM f_pets WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.MaxPets then
        return { ok = false, msg = ('Kamu sudah punya %d hewan (maksimal).'):format(Config.MaxPets) }
    end

    local playerName = fullName(player)
    MySQL.insert.await('INSERT INTO f_pet_requests (citizenid, player_name, pet, variant, name) VALUES (?, ?, ?, ?, ?)',
        { citizenid, playerName, pet.id, variant, name })
    for _, staff in ipairs(approvers()) do
        notify(staff, ('Pengajuan hewan baru: %s ingin memiliki %s "%s". Buka /admin → Pengajuan Hewan.'):format(playerName, pet.label, name))
    end
    return { ok = true, msg = ('Pengajuan %s (%s) terkirim. Tunggu persetujuan admin.'):format(name, pet.label) }
end)

lib.callback.register('f_petshop:requestCancel', function(src)
    local citizenid = cid(src)
    if not citizenid then return false end
    MySQL.update.await("DELETE FROM f_pet_requests WHERE citizenid = ? AND status = 'pending'", { citizenid })
    return true
end)

---------------------------------------------------------------------------
-- Untuk f_admin (halaman Pengajuan Hewan). Hak akses dicek di f_admin.
---------------------------------------------------------------------------
exports('GetPetRequests', function()
    local rows = MySQL.query.await([[
        SELECT id, citizenid, player_name, pet, variant, name, UNIX_TIMESTAMP(created_at) AS created
        FROM f_pet_requests WHERE status = 'pending' ORDER BY id]]) or {}
    for _, r in ipairs(rows) do
        local pet = petsById[r.pet]
        r.label = pet and pet.label or r.pet
        r.icon = pet and pet.icon or '🐾'
        r.color = pet and pet.variants and pet.variants.labels[r.variant + 1] or nil
        r.owned = MySQL.scalar.await('SELECT COUNT(*) FROM f_pets WHERE citizenid = ?', { r.citizenid }) or 0
    end
    return rows, Config.MaxPets
end)

---@return boolean ok, string msg
exports('DecidePetRequest', function(id, approve, staffName)
    local r = MySQL.single.await("SELECT * FROM f_pet_requests WHERE id = ? AND status = 'pending'", { tonumber(id) or 0 })
    if not r then return false, 'Pengajuan tidak ditemukan atau sudah diproses.' end
    local pet = petsById[r.pet]
    if approve then
        if not pet then return false, 'Hewan itu sudah tidak dijual (tidak ada di config).' end
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM f_pets WHERE citizenid = ?', { r.citizenid }) or 0
        if count >= Config.MaxPets then return false, ('%s sudah punya %d hewan (maksimal).'):format(r.player_name, Config.MaxPets) end
    end
    -- tandai dulu (hanya kalau masih pending) supaya tidak bisa disetujui dua kali
    local changed = MySQL.update.await("UPDATE f_pet_requests SET status = ?, decided_by = ?, decided_at = NOW() WHERE id = ? AND status = 'pending'",
        { approve and 'approved' or 'rejected', staffName, r.id })
    if (changed or 0) == 0 then return false, 'Pengajuan sudah diproses staff lain.' end
    if approve then
        MySQL.insert.await('INSERT INTO f_pets (citizenid, pet, name, variant) VALUES (?, ?, ?, ?)', { r.citizenid, r.pet, r.name, r.variant })
    end

    local label = pet and pet.label or r.pet
    local target = exports.qbx_core:GetPlayerByCitizenId(r.citizenid)
    if target then
        notify(target.PlayerData.source, approve
            and ('Pengajuan %s (%s) DISETUJUI! Panggil lewat radial menu → Hewan.'):format(r.name, label)
            or ('Pengajuan %s (%s) ditolak admin.'):format(r.name, label), approve and 'success' or 'error')
    end
    return true, ('%s (%s) milik %s %s.'):format(r.name, label, r.player_name, approve and 'disetujui' or 'ditolak')
end)

lib.callback.register('f_petshop:buyFood', function(src, item, amount, method)
    if spam(src, 'buyFood', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid, player = cid(src)
    if not citizenid then return { ok = false } end
    if not near(src, Config.Shop.coords, 6.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end

    local food = shopItems[item] -- makanan atau perlengkapan (bola, dll)
    amount = math.floor(tonumber(amount) or 0)
    if not food or amount < 1 or amount > 50 then return { ok = false, msg = 'Jumlah tidak valid.' } end

    if not exports.ox_inventory:CanCarryItem(src, food.item, amount) then
        return { ok = false, msg = 'Tas kamu penuh.' }
    end

    local total = food.price * amount
    if not pay(player, method, total, 'beli-makanan-hewan') then
        return { ok = false, msg = method == 'bank' and 'Saldo bank tidak cukup.' or 'Uang cash tidak cukup.' }
    end

    exports.ox_inventory:AddItem(src, food.item, amount)
    return { ok = true, msg = ('Membeli %dx %s seharga %s.'):format(amount, food.label, rp(total)) }
end)

---------------------------------------------------------------------------
-- Panel kontrol: panggil / pulangkan
---------------------------------------------------------------------------
lib.callback.register('f_petshop:getMyPets', function(src)
    local citizenid = cid(src)
    if not citizenid then return end
    local rows = MySQL.query.await('SELECT id, pet, name, hunger, thirst, health, dead FROM f_pets WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    local l = active[src] or {}
    for _, r in ipairs(rows) do
        r.dead = r.dead == 1 or r.dead == true
        local a = l[r.id]
        if a then
            r.active = true
            r.hunger, r.thirst, r.health, r.dead = round(a.row.hunger), round(a.row.thirst), round(a.row.health), a.dead
        end
    end
    local t = trials[src]
    local ta = t and l[-src]
    if ta then
        rows[#rows + 1] = { id = -src, pet = t.row.pet, name = t.row.name, hunger = 100, thirst = 100, health = round(ta.row.health),
            dead = ta.dead, active = true, trial = true, left = math.max(0, t.ends - os.time()) }
    end
    return rows
end)

lib.callback.register('f_petshop:summon', function(src, id)
    if spam(src, 'summon', 300) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid = cid(src)
    if not citizenid then return { ok = false } end
    id = tonumber(id) or 0
    if list(src)[id] then return { ok = false, msg = 'Hewan itu sudah dipanggil.' } end

    if id < 0 then
        local t = trials[src]
        if id ~= -src or not t then return { ok = false, msg = 'Masa coba sudah habis.' } end
        list(src)[id] = { id = id, row = t.row, dead = false, trial = true }
        return { ok = true, row = t.row }
    end

    local row = getRow(id, citizenid)
    if not row or not petsById[row.pet] then return { ok = false, msg = 'Hewan tidak ditemukan.' } end

    row.dead = row.dead == true or row.dead == 1 -- oxmysql mengembalikan TINYINT(1) sebagai boolean
    local spawnAt = row.dead and deadAt[row.id] or nil
    list(src)[id] = { id = row.id, row = row, dead = row.dead, spawnAt = spawnAt }
    return { ok = true, row = row, spawnAt = spawnAt }
end)

-- client melapor ped sudah dibuat; server cek model & jarak sebelum dianggap sah
RegisterNetEvent('f_petshop:server:spawned', function(id, netId)
    local src = source
    local a = active[src] and active[src][id]
    if not a or a.netId then return end

    local ent, tries = 0, 0
    repeat
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent ~= 0 and DoesEntityExist(ent) then break end
        tries += 1
        Wait(100)
    until tries > 20

    local pet = petsById[a.row.pet]
    local expected = a.spawnAt or GetEntityCoords(GetPlayerPed(src))
    if ent == 0 or not DoesEntityExist(ent) or GetEntityModel(ent) ~= joaat(pet.model)
        or #(GetEntityCoords(ent) - expected) > 30.0 then
        if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        active[src][id] = nil
        TriggerClientEvent('f_petshop:client:despawned', src, id)
        return
    end

    a.netId = netId
    setState(src, a)
    pushStatus(src, a)
end)

-- id = nil -> pulangkan semua
lib.callback.register('f_petshop:dismiss', function(src, id)
    if id then
        despawn(src, tonumber(id))
    else
        despawnAll(src)
    end
    return true
end)

-- lepas (hapus permanen) hewan milik sendiri; hewan yang sedang dipanggil harus dipulangkan dulu
lib.callback.register('f_petshop:release', function(src, id)
    if spam(src, 'release', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid = cid(src)
    id = tonumber(id) or 0
    if not citizenid then return { ok = false } end
    if list(src)[id] then return { ok = false, msg = 'Pulangkan hewan itu dulu sebelum dilepas.' } end

    local row = getRow(id, citizenid)
    if not row then return { ok = false, msg = 'Hewan tidak ditemukan.' } end

    MySQL.update.await('DELETE FROM f_pets WHERE id = ? AND citizenid = ?', { id, citizenid })
    deadAt[id] = nil
    return { ok = true, msg = ('%s sudah dilepas.'):format(row.name) }
end)

RegisterNetEvent('f_petshop:server:died', function(id)
    local src = source
    local a = active[src] and active[src][id]
    if not a or a.dead or entityOf(a) == 0 then return end
    -- laporan "mati" yang telat tepat setelah disembuhkan (ped belum sempat hidup di client lain)
    if a.revivedAt and GetGameTimer() - a.revivedAt < 5000 then return end
    if a.trial then
        despawn(src, id)
        notify(src, ('%s pingsan dan dibawa kembali ke toko. Masa coba selesai.'):format(a.row.name), 'error')
        return
    end
    a.dead = true
    a.leash = nil -- tali lepas saat mati
    a.row.health = 0
    savePet(a)
    setState(src, a)
    pushStatus(src, a)
    notify(src, ('%s mati. Bawa ke %s dan minta petugas EMS menyembuhkannya.'):format(a.row.name, Config.Vet.label), 'error')
end)

---------------------------------------------------------------------------
-- Makan
---------------------------------------------------------------------------
lib.callback.register('f_petshop:feed', function(src, item, netId)
    if spam(src, 'feed', 1500) then return false end
    local a = byNetId(src, netId)
    local food = foodByItem[item]
    if not a or a.dead or not food then return false end

    local ent = entityOf(a)
    if ent == 0 or #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > 4.0 then
        notify(src, 'Hewanmu terlalu jauh.', 'error')
        return false
    end
    local drink = food.thirst ~= nil
    local key = drink and 'thirst' or 'hunger'
    if a.row[key] >= 99.5 then
        notify(src, ('%s sudah %s.'):format(a.row.name, drink and 'tidak haus' or 'kenyang'))
        return false
    end
    if not exports.ox_inventory:RemoveItem(src, food.item, 1) then
        notify(src, ('Kamu tidak punya %s.'):format(food.label), 'error')
        return false
    end

    a.row[key] = math.min(100, a.row[key] + (food.thirst or food.hunger))
    if a.row.health < 100 then a.row.health = math.min(100, a.row.health + 10) end
    savePet(a)
    pushStatus(src, a)
    notify(src, ('%s %s dengan lahap.'):format(a.row.name, drink and 'minum' or 'makan'), 'success')
    return true
end)

---------------------------------------------------------------------------
-- Gendong (siapa pun boleh menggendong hewan mati milik siapa pun)
---------------------------------------------------------------------------
lib.callback.register('f_petshop:carry', function(src, netId)
    if spam(src, 'carry', 800) then return false end
    local a, owner = findByNet(tonumber(netId) or 0)
    if not a or not a.dead then return false end
    if a.carrier and a.carrier ~= src and GetPlayerPed(a.carrier) ~= 0 then return false end

    local ent = entityOf(a)
    if ent == 0 or #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > 5.0 then return false end

    a.carrier, a.seatVeh, a.seat = src, nil, nil
    setState(owner, a)
    return true
end)

-- turunkan (vehNet/seat kosong) atau taruh di kursi kendaraan
RegisterNetEvent('f_petshop:server:drop', function(netId, vehNet, seat)
    local src = source
    local a, owner = findByNet(tonumber(netId) or 0)
    if not a then return end
    -- yang boleh melepas: yang menggendong, atau pemilik saat membereskan hewan di kendaraan yang hilang
    if a.carrier ~= src and not (a.carrier == nil and owner == src) then return end
    a.carrier = nil
    a.seatVeh = tonumber(vehNet)
    a.seat = a.seatVeh and math.floor(tonumber(seat) or 0) or nil
    setState(owner, a)
end)

---------------------------------------------------------------------------
-- Pengobatan (hidupkan kembali)
---------------------------------------------------------------------------
local function revive(ownerSrc, a)
    local ent = entityOf(a)
    if a.carrier then TriggerClientEvent('f_petshop:client:forceDrop', a.carrier, a.netId) end
    a.carrier, a.seatVeh, a.seat = nil, nil, nil
    a.dead = false
    a.revivedAt = GetGameTimer()
    a.row.health = 100
    if a.row.hunger < 30 then a.row.hunger = 30 end
    if a.row.thirst < 30 then a.row.thirst = 30 end
    savePet(a)
    setState(ownerSrc, a)
    -- yang menghidupkan secara fisik = client yang sedang mengendalikan entity (bisa bukan pemilik)
    if ent ~= 0 then
        local controller = NetworkGetEntityOwner(ent)
        TriggerClientEvent('f_petshop:client:reviveEntity', controller > 0 and controller or ownerSrc, a.netId)
    end
    pushStatus(ownerSrc, a) -- pemilik lalu mengambil kendali & menyuruhnya ikut lagi
end

-- Sembuhkan hewan: HANYA EMS bertugas, wajib Tas Darurat yang berlaku, obat dari Stok Gudang EMS
-- (sama seperti merawat pasien manusia di f_ambulancejob).
local function emsCheck(src)
    local player = getPlayer(src)
    local job = player and player.PlayerData.job
    if not job or not Config.Vet.emsJobs[job.name] or not job.onduty then
        return 'Hanya petugas EMS yang sedang bertugas.'
    end
    local ok, hasBag = pcall(function() return exports.f_ambulancejob:HasValidBag(src, Config.Vet.bag) end)
    if not ok or not hasBag then
        return 'Kamu tidak membawa Tas Darurat yang masih berlaku (ambil di Armory).'
    end
end

lib.callback.register('f_petshop:emsRevive', function(src, netId)
    if spam(src, 'ems', 2000) then return false end
    local err = emsCheck(src)
    if err then notify(src, err, 'error') return false end

    netId = tonumber(netId) or 0
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) then return false end
    local state = Entity(ent).state.fpet
    if not state or not state.dead or state.carrier then return false end
    if #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(src))) > 4.0 then return false end
    if Config.Vet.requireArea and not near(src, Config.Vet.coords, Config.Vet.radius) then
        notify(src, ('Hewan hanya bisa disembuhkan di %s.'):format(Config.Vet.label), 'error')
        return false
    end

    local owner = state.owner
    local a = byNetId(owner, netId)
    if not a then return false end

    local took, missing = exports.f_ambulancejob:TakeStock(Config.Vet.stock)
    if not took then
        notify(src, ('Stok %s di gudang habis.'):format(missing or 'obat'), 'error')
        return false
    end

    revive(owner, a)
    if owner ~= src then
        notify(owner, ('%s disembuhkan oleh petugas medis.'):format(a.row.name), 'success')
    end
    notify(src, ('%s berhasil disembuhkan.'):format(a.row.name), 'success')
    return true
end)

---------------------------------------------------------------------------
-- Lapar & haus: hanya hewan yang sedang dipanggil (hidup). 100 -> 0 dalam Config.Needs.hours jam.
---------------------------------------------------------------------------
CreateThread(function()
    local n = Config.Needs
    local drop = 100 / (n.hours * 60 / n.tickMinutes) -- per tick, pecahan
    while true do
        Wait(n.tickMinutes * 60000)
        for src, l in pairs(active) do
            for _, a in pairs(l) do
                if a.netId and not a.dead and not a.trial then
                    local r = a.row
                    local wasHungry, wasThirsty = r.hunger <= n.warnAt, r.thirst <= n.warnAt
                    r.hunger = math.max(0, r.hunger - drop)
                    r.thirst = math.max(0, r.thirst - drop)

                    if r.hunger <= 0 or r.thirst <= 0 then
                        local why = r.hunger <= 0 and r.thirst <= 0 and 'kelaparan & kehausan'
                            or r.hunger <= 0 and 'kelaparan' or 'kehausan'
                        r.health = math.max(0, r.health - n.starveDamage)
                        if r.health <= 0 then
                            a.dead = true
                            a.leash = nil
                            TriggerClientEvent('f_petshop:client:kill', src, a.id)
                            notify(src, ('%s mati %s. Bawa ke %s dan minta petugas EMS menyembuhkannya.'):format(r.name, why, Config.Vet.label), 'error')
                            setState(src, a)
                        else
                            notify(src, ('%s %s! Segera beri %s.'):format(r.name, why,
                                r.hunger <= 0 and r.thirst <= 0 and 'makan & minum' or r.hunger <= 0 and 'makan' or 'minum'), 'error')
                        end
                    else
                        -- peringatan sekali saat baru melewati batas
                        if r.hunger <= n.warnAt and not wasHungry then notify(src, ('%s lapar.'):format(r.name), 'warning') end
                        if r.thirst <= n.warnAt and not wasThirsty then notify(src, ('%s haus.'):format(r.name), 'warning') end
                    end
                    savePet(a)
                    pushStatus(src, a)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Masa coba: peringatan 1 menit sebelum habis, lalu hewan otomatis pulang ke toko
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for src, t in pairs(trials) do
            if not GetPlayerName(src) then
                trials[src] = nil
            elseif now >= t.ends then
                despawn(src, -src)
                trials[src] = nil
                notify(src, ('Masa coba %s habis, hewan kembali ke toko.'):format(t.row.name))
            elseif not t.warned and t.ends - now <= Config.Trial.warnSeconds then
                t.warned = true
                notify(src, ('Masa coba %s tinggal %d detik.'):format(t.row.name, t.ends - now), 'warning')
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Bersih-bersih
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    despawnAll(src)
    cooldown[src] = nil
    -- pemain keluar saat menggendong hewan orang lain: lepaskan status gendongnya
    for owner, l in pairs(active) do
        for _, a in pairs(l) do
            if a.carrier == src then
                a.carrier = nil
                setState(owner, a)
            end
        end
    end
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    despawnAll(src or source)
end)

---------------------------------------------------------------------------
-- Aksesoris: dibeli di toko langsung dipakai, tersimpan per hewan. Yang sudah dibeli bisa
-- dipakai/dilepas lagi gratis.
---------------------------------------------------------------------------
local FITS_FILE = 'data/accessory_fits.json'

-- hasil /petfit: { [model] = { [prop] = { x, y, z, rx, ry, rz, bone } } }
do
    local ok, t = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), FITS_FILE) or '')
    GlobalState.fpetFits = ok and type(t) == 'table' and t or {}
end

-- hewan milik pemain (dari database) + data aksesorisnya
local function ownedPet(src, petId)
    local citizenid = cid(src)
    if not citizenid then return end
    local row = getRow(tonumber(petId) or 0, citizenid)
    if not row or not petsById[row.pet] then return end
    -- pakai baris yang sedang aktif kalau hewannya dipanggil, supaya statebag ikut diperbarui
    local a = active[src] and active[src][row.id]
    if a then return a.row, a end
    return row
end

local function saveAcc(src, row, a)
    MySQL.update.await('UPDATE f_pets SET acc = ? WHERE id = ?', { json.encode(accOf(row)), row.id })
    if a then setState(src, a) end
end

-- cek apakah `value` boleh dipakai di slot ini untuk hewan ini
local function validAcc(cfg, slot, value)
    if slot == 'collar' then
        value = math.floor(tonumber(value) or -1)
        return Acc.collarAllowed(cfg) and value >= 0 and value < #Config.CollarColors, value
    end
    local item = Acc.byProp[value]
    return item ~= nil and item.slot == slot and Acc.fit(cfg.model, value) ~= nil, value
end

lib.callback.register('f_petshop:accPets', function(src)
    local citizenid = cid(src)
    if not citizenid then return {} end
    local rows = MySQL.query.await('SELECT id, pet, name, variant, acc FROM f_pets WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if petsById[r.pet] then
            local live = active[src] and active[src][r.id]
            local acc = accOf(live and live.row or r)
            out[#out + 1] = { id = r.id, pet = r.pet, name = r.name, variant = r.variant, owned = acc.owned, collars = acc.collars, worn = acc.worn }
        end
    end
    return out
end)

lib.callback.register('f_petshop:buyAcc', function(src, petId, slot, value, method)
    if spam(src, 'buyAcc', 800) then return { ok = false, msg = 'Tunggu sebentar.' } end
    if not near(src, Config.Shop.coords, 8.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end
    local row, a = ownedPet(src, petId)
    if not row then return { ok = false, msg = 'Hewan tidak ditemukan.' } end
    local cfg = petsById[row.pet]
    local valid
    valid, value = validAcc(cfg, slot, value)
    if not valid then return { ok = false, msg = 'Aksesoris ini tidak cocok untuk hewan itu.' } end

    local acc = accOf(row)
    local owned = slot == 'collar' and acc.collars[tostring(value)] or acc.owned[value]
    local label = slot == 'collar' and ('Kalung %s'):format(Config.CollarColors[value + 1]) or Acc.byProp[value].label
    if not owned then
        local price = slot == 'collar' and Acc.slots.collar.price or Acc.price(Acc.byProp[value])
        local _, player = cid(src)
        if not pay(player, method, price, 'aksesoris-hewan') then
            return { ok = false, msg = method == 'bank' and 'Saldo bank tidak cukup.' or 'Uang cash tidak cukup.' }
        end
        if slot == 'collar' then acc.collars[tostring(value)] = true else acc.owned[value] = true end
    end
    acc.worn[slot] = value
    saveAcc(src, row, a)
    return { ok = true, msg = ('%s dipakai %s.'):format(label, row.name), owned = acc.owned, collars = acc.collars, worn = acc.worn }
end)

-- pakai (yang sudah dimiliki) / lepas (value = nil)
lib.callback.register('f_petshop:wearAcc', function(src, petId, slot, value)
    if spam(src, 'wearAcc', 300) then return { ok = false } end
    local row, a = ownedPet(src, petId)
    if not row or not Acc.slots[slot] then return { ok = false } end
    local acc = accOf(row)
    if value ~= nil then
        local valid
        valid, value = validAcc(petsById[row.pet], slot, value)
        local owned = slot == 'collar' and acc.collars[tostring(value)] or acc.owned[value]
        if not valid or not owned then return { ok = false, msg = 'Aksesoris itu belum dibeli.' } end
    end
    acc.worn[slot] = value
    saveAcc(src, row, a)
    return { ok = true, owned = acc.owned, collars = acc.collars, worn = acc.worn }
end)

-- Tali anjing: pasang (butuh item, tidak berkurang) / lepas. Status tali ada di statebag fpet.leash.
lib.callback.register('f_petshop:leash', function(src, petId, on)
    if spam(src, 'leash', 500) then return end
    local a = active[src] and active[src][tonumber(petId)]
    local cfg = a and petsById[a.row.pet]
    if not a or a.dead or not cfg or not Config.Leash.kinds[cfg.kind] then return end
    if on and exports.ox_inventory:Search(src, 'count', Config.Leash.item) < 1 then
        notify(src, 'Kamu butuh Tali Anjing (beli di Toko Hewan → Perlengkapan).', 'error')
        return
    end
    a.leash = on and true or nil
    setState(src, a)
    return a.leash == true
end)

---------------------------------------------------------------------------
-- Daftar teman (per karakter): pemain & job yang tidak diserang saat hewan menjaga area
---------------------------------------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_pet_friends` (
            `citizenid` VARCHAR(50) NOT NULL,
            `data` TEXT NOT NULL,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

local friendsCache = {} -- [citizenid] = { players = { [citizenid] = nama }, jobs = { [job] = true } }

local function friendsOf(citizenid)
    local f = friendsCache[citizenid]
    if f then return f end
    local raw = MySQL.scalar.await('SELECT data FROM f_pet_friends WHERE citizenid = ?', { citizenid })
    local ok, t = pcall(json.decode, raw or '')
    f = ok and type(t) == 'table' and t or {}
    f.players, f.jobs = f.players or {}, f.jobs or {}
    friendsCache[citizenid] = f
    return f
end

local function saveFriends(citizenid)
    MySQL.update('INSERT INTO f_pet_friends (citizenid, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { citizenid, json.encode(friendsCache[citizenid]) })
end

-- data untuk tampilan Daftar Teman + pemain di dekat (untuk ditambahkan)
local function friendsView(src)
    local citizenid = cid(src)
    local f = friendsOf(citizenid)
    local players = {}
    for id, name in pairs(f.players) do players[#players + 1] = { cid = id, name = name } end
    table.sort(players, function(x, y) return x.name < y.name end)

    local jobs, all = {}, exports.qbx_core:GetJobs() or {}
    for _, job in ipairs(Config.Attack.friendJobs) do
        jobs[#jobs + 1] = { name = job, label = all[job] and all[job].label or job, on = f.jobs[job] == true }
    end

    local nearby, myPos = {}, GetEntityCoords(GetPlayerPed(src))
    for _, sid in ipairs(GetPlayers()) do
        local other = tonumber(sid) --[[@as number]]
        local p = other ~= src and getPlayer(other)
        if p and not f.players[p.PlayerData.citizenid] and #(GetEntityCoords(GetPlayerPed(other)) - myPos) <= 5.0 then
            nearby[#nearby + 1] = { id = other, name = fullName(p) }
        end
    end
    return { players = players, jobs = jobs, nearby = nearby }
end

lib.callback.register('f_petshop:friends', function(src, action, value)
    local citizenid = cid(src)
    if not citizenid then return end
    local f = friendsOf(citizenid)
    if action == 'add' then
        local other = getPlayer(tonumber(value) or 0)
        if other and tonumber(value) ~= src and near(src, GetEntityCoords(GetPlayerPed(tonumber(value))), 5.0) then
            f.players[other.PlayerData.citizenid] = fullName(other)
            saveFriends(citizenid)
        end
    elseif action == 'remove' and type(value) == 'string' then
        f.players[value] = nil
        saveFriends(citizenid)
    elseif action == 'job' and lib.table.contains(Config.Attack.friendJobs, value) then
        f.jobs[value] = not f.jobs[value] or nil
        saveFriends(citizenid)
    end
    return friendsView(src)
end)

-- Hewan boleh menyerang PEMAIN ini? (dipanggil pemilik sebelum menyuruh menyerang / saat jaga area)
lib.callback.register('f_petshop:canAttack', function(src, petId, target)
    target = tonumber(target)
    local a = active[src] and active[src][tonumber(petId)]
    local cfg = a and petsById[a.row.pet]
    if not Config.Attack.enabled or not Config.Attack.players or not cfg or not cfg.attack or a.dead then return false end
    if not target or target == src or not GetPlayerName(target) then return false end

    local owner = getPlayer(src)
    if Config.Attack.jobs and not lib.table.contains(Config.Attack.jobs, owner.PlayerData.job.name) then return false end

    local ent, victim = entityOf(a), getPlayer(target)
    if ent == 0 or not victim or #(GetEntityCoords(ent) - GetEntityCoords(GetPlayerPed(target))) > Config.Attack.range then
        return false
    end
    local f = friendsOf(owner.PlayerData.citizenid)
    if f.players[victim.PlayerData.citizenid] or f.jobs[victim.PlayerData.job.name] then return false end

    print(('[f_petshop] %s (%s) menyuruh %s menyerang %s (%s)'):format(GetPlayerName(src), src, a.row.name, GetPlayerName(target), target))
    return true
end)

-- Alat admin untuk menyetel posisi aksesoris per model hewan
lib.addCommand('petfit', { help = 'Setel posisi aksesoris hewan (admin)', restricted = 'group.admin' }, function(src)
    TriggerClientEvent('f_petshop:client:petfit', src)
end)

lib.callback.register('f_petshop:saveFit', function(src, model, prop, fit)
    if not IsPlayerAceAllowed(src, 'command.petfit') then return false end
    if type(model) ~= 'string' or not Acc.byProp[prop] or type(fit) ~= 'table' then return false end
    local v = {}
    for i = 1, 7 do
        v[i] = tonumber(fit[i])
        if not v[i] then return false end
    end
    model = model:lower()
    local fits = GlobalState.fpetFits or {}
    fits[model] = fits[model] or {}
    fits[model][prop] = v
    SaveResourceFile(GetCurrentResourceName(), FITS_FILE, json.encode(fits, { indent = true }), -1)
    GlobalState.fpetFits = fits
    return true
end)

---------------------------------------------------------------------------
-- Elus: siapa pun boleh. Pemilik hewan (yang mengendalikan ped) diberi tahu supaya hewannya
-- berhenti, menghadap si pengelus, dan memutar animasi dielus -> terlihat sama oleh semua orang.
---------------------------------------------------------------------------
RegisterNetEvent('f_petshop:server:petting', function(netId)
    local src = source
    if spam(src, 'petting', 3000) then return end
    local a, owner = findByNet(tonumber(netId))
    local ent = entityOf(a)
    if not a or a.dead or ent == 0 or not near(src, GetEntityCoords(ent), 3.0) then return end
    TriggerClientEvent('f_petshop:client:petted', owner, a.netId, src, Config.Petting.duration)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(active) do despawnAll(src) end
end)
