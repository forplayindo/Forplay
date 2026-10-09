-- f_petshop server: semua pembelian, status hewan, dan pengobatan divalidasi di sini.
-- Satu pemain boleh memanggil semua hewannya sekaligus.

local petsById, foodByItem = {}, {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end
for _, f in ipairs(Config.Food) do foodByItem[f.item] = f end

local active = {}   -- [src] = { [petId] = { id, row, dead, netId?, spawnAt? } }
local deadAt = {}   -- [petId] = vec3 posisi terakhir hewan mati (supaya tidak bisa "teleport" ke klinik)
local cooldown = {} -- [src] = { [aksi] = GetGameTimer() }

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
end)

local function getRow(id, citizenid)
    return MySQL.single.await('SELECT * FROM f_pets WHERE id = ? AND citizenid = ? LIMIT 1', { id, citizenid })
end

local function savePet(a)
    MySQL.update('UPDATE f_pets SET hunger = ?, health = ?, dead = ? WHERE id = ?',
        { a.row.hunger, a.row.health, a.dead and 1 or 0, a.id })
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

-- carrier = yang sedang menggendong, seatVeh/seat = kendaraan (netId) & kursi tempat hewan mati ditaruh
local function setState(src, a)
    local ent = entityOf(a)
    if ent == 0 then return end
    Entity(ent).state:set('fpet', {
        id = a.id, owner = src, name = a.row.name, pet = a.row.pet, dead = a.dead,
        carrier = a.carrier, seatVeh = a.seatVeh, seat = a.seat,
    }, true)
end

local function pushStatus(src, a)
    TriggerClientEvent('f_petshop:client:status', src, { id = a.id, hunger = a.row.hunger, health = a.row.health, dead = a.dead })
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
    return {
        owned = count,
        max = Config.MaxPets,
        cash = player.PlayerData.money.cash or 0,
        bank = player.PlayerData.money.bank or 0,
    }
end)

local function pay(player, method, amount, reason)
    if method ~= 'cash' and method ~= 'bank' then return false end
    return player.Functions.RemoveMoney(method, amount, reason)
end

lib.callback.register('f_petshop:buyPet', function(src, petKey, name, method)
    if spam(src, 'buyPet', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid, player = cid(src)
    if not citizenid then return { ok = false } end
    if not near(src, Config.Shop.coords, 6.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end

    local pet = petsById[petKey]
    if not pet then return { ok = false, msg = 'Hewan tidak ditemukan.' } end

    name = type(name) == 'string' and name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < 2 or #name > Config.NameMaxLength then
        return { ok = false, msg = ('Nama harus 2-%d karakter.'):format(Config.NameMaxLength) }
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM f_pets WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.MaxPets then
        return { ok = false, msg = ('Kamu sudah punya %d hewan (maksimal).'):format(Config.MaxPets) }
    end

    if not pay(player, method, pet.price, 'beli-hewan') then
        return { ok = false, msg = method == 'bank' and 'Saldo bank tidak cukup.' or 'Uang cash tidak cukup.' }
    end

    local id = MySQL.insert.await('INSERT INTO f_pets (citizenid, pet, name) VALUES (?, ?, ?)', { citizenid, pet.id, name })
    return { ok = true, id = id, msg = ('%s (%s) sekarang milikmu! Atur lewat radial menu → Hewan.'):format(name, pet.label) }
end)

lib.callback.register('f_petshop:buyFood', function(src, item, amount, method)
    if spam(src, 'buyFood', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid, player = cid(src)
    if not citizenid then return { ok = false } end
    if not near(src, Config.Shop.coords, 6.0) then return { ok = false, msg = 'Kamu terlalu jauh dari toko.' } end

    local food = foodByItem[item]
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
    local rows = MySQL.query.await('SELECT id, pet, name, hunger, health, dead FROM f_pets WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    local l = active[src] or {}
    for _, r in ipairs(rows) do
        r.dead = r.dead == 1 or r.dead == true
        local a = l[r.id]
        if a then
            r.active = true
            r.hunger, r.health, r.dead = a.row.hunger, a.row.health, a.dead
        end
    end
    return rows
end)

lib.callback.register('f_petshop:summon', function(src, id)
    if spam(src, 'summon', 300) then return { ok = false, msg = 'Tunggu sebentar.' } end
    local citizenid = cid(src)
    if not citizenid then return { ok = false } end
    id = tonumber(id) or 0
    if list(src)[id] then return { ok = false, msg = 'Hewan itu sudah dipanggil.' } end

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
    a.dead = true
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
    if a.row.hunger >= 100 then
        notify(src, ('%s sudah kenyang.'):format(a.row.name))
        return false
    end
    if not exports.ox_inventory:RemoveItem(src, food.item, 1) then
        notify(src, ('Kamu tidak punya %s.'):format(food.label), 'error')
        return false
    end

    a.row.hunger = math.min(100, a.row.hunger + food.hunger)
    if a.row.health < 100 then a.row.health = math.min(100, a.row.health + 10) end
    savePet(a)
    pushStatus(src, a)
    notify(src, ('%s makan dengan lahap.'):format(a.row.name), 'success')
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
-- Rasa lapar
---------------------------------------------------------------------------
CreateThread(function()
    local h = Config.Hunger
    while true do
        Wait(h.tickMinutes * 60000)
        for src, l in pairs(active) do
            for _, a in pairs(l) do
                if a.netId and not a.dead then
                    a.row.hunger = math.max(0, a.row.hunger - h.drop)
                    if a.row.hunger == 0 then
                        a.row.health = math.max(0, a.row.health - h.starveDamage)
                        if a.row.health == 0 then
                            a.dead = true
                            TriggerClientEvent('f_petshop:client:kill', src, a.id)
                            notify(src, ('%s mati kelaparan. Bawa ke %s dan minta petugas EMS menyembuhkannya.'):format(a.row.name, Config.Vet.label), 'error')
                            setState(src, a)
                        else
                            notify(src, ('%s kelaparan! Beri makan segera.'):format(a.row.name), 'error')
                        end
                    elseif a.row.hunger <= 20 then
                        notify(src, ('%s lapar.'):format(a.row.name), 'warning')
                    end
                    savePet(a)
                    pushStatus(src, a)
                end
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(active) do despawnAll(src) end
end)
