local config = require 'config.server'
local sharedConfig = require 'config.shared'
local cave = require 'shared.cave'

local STASH = 'f_mining_gudang'       -- Gudang Tambang (lobby): bijih
local STASH_HASIL = 'f_mining_hasil'  -- Gudang Hasil (atas, dekat mobil): hasil lebur + berlian
local lobby = sharedConfig.lobby
local HASIL = { diamond = true }
for _, out in pairs(sharedConfig.smelt) do HASIL[out] = true end
local PER_BAR = sharedConfig.secondsPerBar
local ORES = { 'bijih_tembaga', 'bijih_perak', 'bijih_emas' }

local caves = {}      -- [i] = { players = { [src] = true }, count, rocks = { [id] = rock }, load }
local session = {}    -- [src] = { cave, lastHit, lastActive, warned }
local carry = {}      -- [src] = { item, count, since, cid }   wadah yang sedang dibawa
local wearing = {}    -- [src] = true saat memakai baju tambang
local furnaces = {}   -- [idx] = { cid, out, ore, total, start, token }
local furnaceOf = {}  -- [cid] = idx
local pending = {}    -- [cid] = { [item] = count }   isi bak, ikut lori berikutnya
local transit = {}    -- muatan lori yang sedang jalan
local nextLori = os.time() + config.lori.interval
local furnaceToken = 0
local labels = {}

local dropTotal = 0
for _, d in ipairs(config.drops) do dropTotal = dropTotal + d.chance end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function notify(src, msg, typ)
    exports.qbx_core:Notify(src, msg, typ or 'inform')
end

local function getCid(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.citizenid
end

local function sourceOf(cid)
    local player = exports.qbx_core:GetPlayerByCitizenId(cid)
    return player and player.PlayerData.source
end

local function itemLabel(name)
    if not labels[name] then
        local item = exports.ox_inventory:Items(name)
        labels[name] = item and item.label or name
    end
    return labels[name]
end

local function isNear(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= dist
end

local function gudangOf(cid)
    return { id = STASH, owner = cid }
end

local function addPending(cid, item, count)
    pending[cid] = pending[cid] or {}
    pending[cid][item] = (pending[cid][item] or 0) + count
end

local function putIn(inv, item, count)
    local n = math.min(count, exports.ox_inventory:CanCarryAmount(inv, item) or 0)
    if n > 0 and not exports.ox_inventory:AddItem(inv, item, n) then n = 0 end
    return n
end

-- hasil lebur & berlian ke Gudang Hasil (atas), bijih ke Gudang Tambang (lobby).
-- Kalau penuh: hasil meluap ke Gudang Tambang, sisanya ikut lori berikutnya. return masuk, sisa
local function addToGudang(cid, item, count)
    local n = 0
    if HASIL[item] then n = putIn({ id = STASH_HASIL, owner = cid }, item, count) end
    if n < count then n = n + putIn(gudangOf(cid), item, count - n) end
    local left = count - n
    if left > 0 then addPending(cid, item, left) end
    return n, left
end

local function toCave(i, event, ...)
    for src in pairs(caves[i].players) do
        TriggerClientEvent(event, src, ...)
    end
end

---------------------------------------------------------------------------
-- gua & batu
---------------------------------------------------------------------------
local function newRock()
    return { stage = 0, hits = 0, max = math.random(config.rockHits[1], config.rockHits[2]) }
end

for i = 1, #sharedConfig.caves do
    local rocks = {}
    for _, r in ipairs(cave.rocks) do rocks[r.id] = newRock() end
    caves[i] = { players = {}, count = 0, rocks = rocks, load = false }
end

local function rockStages(i)
    local out = {}
    for id, r in pairs(caves[i].rocks) do out[id] = r.stage end
    return out
end

local function leaveCave(src, teleport)
    local s = session[src]
    if not s then return end
    session[src] = nil
    local c = caves[s.cave]
    if c.players[src] then
        c.players[src] = nil
        c.count = c.count - 1
    end
    if GetPlayerName(src) then
        SetPlayerRoutingBucket(src, 0)
        TriggerClientEvent('f_mining:client:leftCave', src, teleport)
    end
end

lib.callback.register('f_mining:server:getCaves', function(src)
    local list = {}
    for i, label in ipairs(sharedConfig.caves) do
        list[i] = { label = label, count = caves[i].count, max = sharedConfig.maxPerCave }
    end
    return list
end)

lib.callback.register('f_mining:server:enterCave', function(src, i)
    i = tonumber(i)
    local c = i and caves[i]
    if not c then return { ok = false } end
    if session[src] then return { ok = false, msg = 'Kamu sudah di dalam gua.' } end
    if carry[src] then return { ok = false, msg = 'Taruh wadahmu dulu.' } end
    if not isNear(src, lobby.gateExit, 8.0) then return { ok = false, msg = 'Terlalu jauh dari pintu gua.' } end
    if c.count >= sharedConfig.maxPerCave then return { ok = false, msg = ('%s penuh.'):format(sharedConfig.caves[i]) } end

    session[src] = { cave = i, lastHit = 0, lastActive = os.time() }
    c.players[src] = true
    c.count = c.count + 1
    SetPlayerRoutingBucket(src, config.bucketBase + i)
    return { ok = true, label = sharedConfig.caves[i], rocks = rockStages(i), load = c.load, lori = nextLori - os.time() }
end)

lib.callback.register('f_mining:server:leaveCave', function(src)
    if not session[src] or not isNear(src, cave.gateCaveTarget, 6.0) then return false end
    leaveCave(src, true)
    return true
end)

local function wearKapak(src)
    local slots = exports.ox_inventory:GetSlotsWithItem(src, 'kapak_tambang')
    if not slots or #slots == 0 then return end
    -- habiskan kapak yang paling aus dulu
    local slot, dur
    for _, s in ipairs(slots) do
        local d = s.metadata and s.metadata.durability or 100
        if not dur or d < dur then slot, dur = s, d end
    end
    local new = dur - 100 / config.kapak.hits
    if new <= 0.001 then
        exports.ox_inventory:RemoveItem(src, 'kapak_tambang', 1, nil, slot.slot)
        return true
    end
    exports.ox_inventory:SetDurability(src, slot.slot, new)
end

local function rollDrop()
    local r = math.random() * dropTotal
    for _, d in ipairs(config.drops) do
        r = r - d.chance
        if r <= 0 then return d end
    end
    return config.drops[1]
end

lib.callback.register('f_mining:server:hit', function(src, rockId)
    local s = session[src]
    if not s or carry[src] then return { ok = false } end
    local now = GetGameTimer()
    if now - s.lastHit < config.hitCooldown then return { ok = false } end

    local c = caves[s.cave]
    local rock, def = c.rocks[rockId], cave.rockById[rockId]
    if not rock or not def or rock.stage >= 4 then return { ok = false, msg = 'Batu ini sudah hancur.' } end
    if not isNear(src, def.pos, config.hitDistance) then return { ok = false } end
    if not wearing[src] then return { ok = false, msg = 'Pakai baju tambang dulu di loker lobby.' } end
    if exports.ox_inventory:GetItemCount(src, 'kapak_tambang') < 1 then
        return { ok = false, msg = 'Kamu butuh Kapak Tambang (beli di rak lobby).' }
    end

    local drop = rollDrop()
    if not exports.ox_inventory:CanCarryItem(src, drop.item, 1) then
        return { ok = false, msg = 'Tas penuh! Setor dulu ke lori.' }
    end

    s.lastHit = now
    s.lastActive = os.time()
    s.warned = nil
    exports.ox_inventory:AddItem(src, drop.item, 1)
    local broke = wearKapak(src)

    rock.hits = rock.hits + 1
    local stage = rock.hits >= rock.max and 4 or math.floor(rock.hits * 4 / rock.max)
    if stage ~= rock.stage then
        rock.stage = stage
        toCave(s.cave, 'f_mining:client:rock', rockId, stage)
        if stage == 4 then
            local caveId = s.cave
            SetTimeout(config.rockRespawn * 1000, function()
                local fresh = newRock()
                caves[caveId].rocks[rockId] = fresh
                toCave(caveId, 'f_mining:client:rock', rockId, 0)
            end)
        end
    end

    return { ok = true, label = itemLabel(drop.item), rare = drop.rare, broke = broke }
end)

---------------------------------------------------------------------------
-- bak & lori
---------------------------------------------------------------------------
lib.callback.register('f_mining:server:deposit', function(src)
    local s = session[src]
    if not s or not isNear(src, cave.cartPark, 4.0) then return { ok = false } end
    local cid = getCid(src)
    if not cid then return { ok = false } end

    local total = 0
    for _, item in ipairs(config.depositItems) do
        local n = exports.ox_inventory:GetItemCount(src, item)
        if n > 0 and exports.ox_inventory:RemoveItem(src, item, n) then
            addPending(cid, item, n)
            total = total + n
        end
    end
    if total == 0 then return { ok = false, msg = 'Tidak ada bijih di tasmu.' } end

    local c = caves[s.cave]
    if not c.load then
        c.load = true
        toCave(s.cave, 'f_mining:client:load', true)
    end
    return { ok = true, total = total, lori = nextLori - os.time() }
end)

local function deliver(load)
    for cid, items in pairs(load) do
        local got, full = {}, false
        for item, count in pairs(items) do
            local n, left = addToGudang(cid, item, count)
            if n > 0 then got[#got + 1] = ('%dx %s'):format(n, itemLabel(item)) end
            if left > 0 then full = true end
        end
        local src = sourceOf(cid)
        if src then
            if #got > 0 then notify(src, ('Lori tiba: %s masuk gudang.'):format(table.concat(got, ', ')), 'success') end
            if full then notify(src, 'Gudang Tambang penuh! Sisa barang ikut lori berikutnya.', 'error') end
        end
    end
end

CreateThread(function()
    while true do
        Wait(config.lori.interval * 1000)
        nextLori = os.time() + config.lori.interval
        local load = pending
        pending = {}
        for i, c in ipairs(caves) do
            c.load = false
            toCave(i, 'f_mining:client:lori', config.lori.travel)
        end
        if next(load) then
            transit[load] = true
            SetTimeout(config.lori.travel * 1000, function()
                if not transit[load] then return end
                transit[load] = nil
                deliver(load)
            end)
        end
    end
end)

---------------------------------------------------------------------------
-- wadah & tungku
---------------------------------------------------------------------------
local function furnacePublic(idx)
    local f = furnaces[idx]
    if not f then return false end
    local outs = {}
    for i, e in ipairs(f.items) do outs[i] = { out = sharedConfig.smelt[e.item], count = e.count } end
    return { cid = f.cid, outs = outs, total = f.total, remaining = math.max(0, f.start + f.total * PER_BAR - os.time()) }
end

-- "20x Tembaga, 10x Batang Perak" (asOut = nama hasil lebur)
local function describe(items, asOut)
    local parts = {}
    for i, e in ipairs(items) do
        parts[i] = ('%dx %s'):format(e.count, itemLabel(asOut and sharedConfig.smelt[e.item] or e.item))
    end
    return table.concat(parts, ', ')
end

local function syncFurnace(idx)
    TriggerClientEvent('f_mining:client:furnace', -1, idx, furnacePublic(idx))
end

local function returnCarry(src, msg)
    local c = carry[src]
    if not c then return end
    carry[src] = nil
    for _, e in ipairs(c.items) do addToGudang(c.cid, e.item, e.count) end
    if GetPlayerName(src) then
        TriggerClientEvent('f_mining:client:wadah', src, false)
        if msg then notify(src, msg, 'inform') end
    end
end

lib.callback.register('f_mining:server:wadahInfo', function(src)
    if not isNear(src, lobby.gudang, 5.0) then return end
    local cid = getCid(src)
    if not cid then return end
    local rows = {}
    for i, item in ipairs(ORES) do
        rows[i] = {
            item = item,
            label = itemLabel(item),
            out = itemLabel(sharedConfig.smelt[item]),
            tas = exports.ox_inventory:GetItemCount(src, item),
            gudang = exports.ox_inventory:GetItemCount(gudangOf(cid), item),
        }
    end
    local busy = furnaceOf[cid] and furnacePublic(furnaceOf[cid])
    return {
        rows = rows,
        max = sharedConfig.wadahMax,
        perBar = PER_BAR,
        carrying = carry[src] ~= nil,
        busy = busy and { furnace = furnaceOf[cid], remaining = busy.remaining } or nil,
    }
end)

-- wadah campuran: { [bijih] = jumlah }, total maks wadahMax
lib.callback.register('f_mining:server:takeWadah', function(src, wanted)
    if type(wanted) ~= 'table' then return { ok = false } end
    local asked = 0
    for _, item in ipairs(ORES) do
        local n = math.floor(tonumber(wanted[item]) or 0)
        if n < 0 then return { ok = false } end
        asked = asked + n
    end
    if asked < 1 or asked > sharedConfig.wadahMax then return { ok = false, msg = 'Isi wadah tidak valid.' } end
    if carry[src] then return { ok = false, msg = 'Kamu sudah membawa wadah.' } end
    if not isNear(src, lobby.gudang, 5.0) then return { ok = false, msg = 'Terlalu jauh dari gudang.' } end
    local cid = getCid(src)
    if not cid then return { ok = false } end
    if furnaceOf[cid] then return { ok = false, msg = 'Tungkumu masih melebur. Tunggu sampai selesai.' } end

    local inv = gudangOf(cid)
    local items, total = {}, 0
    for _, item in ipairs(ORES) do
        local amount = math.floor(tonumber(wanted[item]) or 0)
        if amount > 0 then
            -- ambil dari tas dulu, sisanya dari gudang
            local fromTas = math.min(amount, exports.ox_inventory:GetItemCount(src, item))
            if fromTas > 0 and not exports.ox_inventory:RemoveItem(src, item, fromTas) then fromTas = 0 end
            local fromGudang = math.min(amount - fromTas, exports.ox_inventory:GetItemCount(inv, item))
            if fromGudang > 0 and not exports.ox_inventory:RemoveItem(inv, item, fromGudang) then fromGudang = 0 end
            local count = fromTas + fromGudang
            if count > 0 then
                items[#items + 1] = { item = item, count = count }
                total = total + count
            end
        end
    end
    if total == 0 then return { ok = false, msg = 'Tidak ada bijih untuk diisi.' } end

    -- isi utama (terbanyak) untuk tampilan isi wadah
    local main = items[1]
    for _, e in ipairs(items) do if e.count > main.count then main = e end end
    carry[src] = { items = items, count = total, since = os.time(), cid = cid }
    return { ok = true, item = main.item, count = total, label = describe(items) }
end)

lib.callback.register('f_mining:server:returnWadah', function(src)
    if not carry[src] or not isNear(src, lobby.gudang, 5.0) then return false end
    returnCarry(src, 'Wadah dikembalikan, bijih masuk Gudang Tambang lagi.')
    return true
end)

RegisterNetEvent('f_mining:server:dropWadah', function()
    returnCarry(source, 'Wadah jatuh, bijih dikembalikan ke Gudang Tambang.')
end)

local function finishFurnace(idx, token)
    local f = furnaces[idx]
    if not f or f.token ~= token then return end
    furnaces[idx] = nil
    furnaceOf[f.cid] = nil
    local full = false
    for _, e in ipairs(f.items) do
        local _, left = addToGudang(f.cid, sharedConfig.smelt[e.item], e.count)
        if left > 0 then full = true end
    end
    syncFurnace(idx)
    local src = sourceOf(f.cid)
    if src then
        TriggerClientEvent('f_mining:client:smelted', src, ('%s selesai dan sudah masuk Gudang Hasil (atas, dekat mulut tambang).'):format(describe(f.items, true)))
        if full then notify(src, 'Gudang Hasil & Gudang Tambang penuh! Sisa batangan ikut lori berikutnya.', 'error') end
    end
end

lib.callback.register('f_mining:server:placeWadah', function(src, idx)
    idx = tonumber(idx)
    local spot = idx and lobby.furnaces[idx]
    local c = carry[src]
    if not spot or not c then return { ok = false } end
    if furnaces[idx] then return { ok = false, msg = 'Tungku ini sedang dipakai. Cari tungku lain.' } end
    if furnaceOf[c.cid] then return { ok = false, msg = 'Kamu sudah memakai tungku lain.' } end
    if not isNear(src, spot, 4.0) then return { ok = false } end

    carry[src] = nil
    furnaceToken = furnaceToken + 1
    furnaces[idx] = { cid = c.cid, items = c.items, total = c.count, start = os.time(), token = furnaceToken }
    furnaceOf[c.cid] = idx
    local token = furnaceToken
    SetTimeout(c.count * PER_BAR * 1000, function() finishFurnace(idx, token) end)
    syncFurnace(idx)

    local secs = c.count * PER_BAR
    return {
        ok = true,
        msg = ('Peleburan dimulai: %s (± %d:%02d). Kamu boleh pergi, hasil otomatis masuk Gudang Hasil di atas.')
            :format(describe(c.items), secs // 60, secs % 60),
    }
end)

lib.callback.register('f_mining:server:getFurnaces', function()
    local list = {}
    for idx in pairs(lobby.furnaces) do list[idx] = furnacePublic(idx) end
    return list
end)

---------------------------------------------------------------------------
-- loker & rak kapak
---------------------------------------------------------------------------
RegisterNetEvent('f_mining:server:outfit', function(on)
    local src = source
    if on and not isNear(src, lobby.locker, 5.0) then return end
    wearing[src] = on and true or nil
end)

lib.callback.register('f_mining:server:buyKapak', function(src)
    if not isNear(src, lobby.toolRack, 5.0) then return { ok = false } end
    if not exports.ox_inventory:CanCarryItem(src, 'kapak_tambang', 1) then return { ok = false, msg = 'Tasmu penuh.' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false } end
    local price = sharedConfig.kapakPrice
    if not player.Functions.RemoveMoney('cash', price, 'beli-kapak-tambang')
        and not player.Functions.RemoveMoney('bank', price, 'beli-kapak-tambang') then
        return { ok = false, msg = ('Uangmu tidak cukup (Rp %s).'):format(lib.math.groupdigits(price, '.')) }
    end
    exports.ox_inventory:AddItem(src, 'kapak_tambang', 1, { durability = 100 })
    return { ok = true }
end)

---------------------------------------------------------------------------
-- AFK, keluar area, wadah kelamaan
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()
        for src, s in pairs(session) do
            local ped = GetPlayerPed(src)
            if not ped or ped == 0 or #(GetEntityCoords(ped) - cave.center) > 80.0 then
                leaveCave(src, false) -- mati / dibawa ke RS / teleport
            elseif s.warned and now - s.lastActive >= config.afkSeconds + 60 then
                notify(src, 'Kamu dipindah ke lobby karena tidak aktif.', 'error')
                leaveCave(src, true)
            elseif not s.warned and now - s.lastActive >= config.afkSeconds then
                s.warned = true
                notify(src, 'Kamu tidak aktif. 1 menit lagi dipindah ke lobby.', 'error')
            end
        end
        for src, c in pairs(carry) do
            if now - c.since >= config.wadahTimeout then
                returnCarry(src, 'Wadah terlalu lama dibawa, bijih dikembalikan ke Gudang Tambang.')
            end
        end
    end
end)

local function cleanup(src)
    leaveCave(src, false)
    returnCarry(src)
    wearing[src] = nil
end

AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('qbx_core:server:playerLoggedOut', cleanup)

---------------------------------------------------------------------------
-- gudang (stash per pemain) + hook isi
---------------------------------------------------------------------------
-- pemain hanya boleh memasukkan item tertentu (bukan stash umum); keluar bebas
local function limitStash(stash, allowed, msg)
    exports.ox_inventory:registerHook('swapItems', function(payload)
        if payload.fromInventory == payload.toInventory then return true end
        if type(payload.toInventory) ~= 'string' or not payload.toInventory:find('^' .. stash) then return true end
        local name = payload.fromSlot and payload.fromSlot.name
        if name and allowed[name] then return true end
        if type(payload.source) == 'number' then notify(payload.source, msg, 'error') end
        return false
    end, { inventoryFilter = { '^' .. stash } })
end

local function registerInventory()
    local g, h = config.gudang, config.hasil
    exports.ox_inventory:RegisterStash(STASH, 'Gudang Tambang', g.slots, g.weight, true, nil, lobby.gudang.xyz)
    exports.ox_inventory:RegisterStash(STASH_HASIL, 'Gudang Hasil Tambang', h.slots, h.weight, true, nil, sharedConfig.hasil.xyz)
    limitStash(STASH, config.gudangItems, 'Gudang Tambang hanya untuk bijih & kapak tambang.')
    limitStash(STASH_HASIL, HASIL, 'Gudang Hasil hanya untuk hasil lebur & berlian.')
end

registerInventory()

AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'ox_inventory' then registerInventory() end
end)

-- restart: semua isi bak, lori, wadah dan tungku dikembalikan ke gudang (tidak ada yang hilang)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(session) do SetPlayerRoutingBucket(src, 0) end
    for _, c in pairs(carry) do
        for _, e in ipairs(c.items) do addToGudang(c.cid, e.item, e.count) end
    end
    local now = os.time()
    for _, f in pairs(furnaces) do
        -- dilebur berurutan: yang sudah jadi batangan, sisanya kembali jadi bijih
        local done = math.min(f.total, math.max(0, (now - f.start) // PER_BAR))
        for _, e in ipairs(f.items) do
            local bars = math.min(done, e.count)
            done = done - bars
            if bars > 0 then addToGudang(f.cid, sharedConfig.smelt[e.item], bars) end
            if e.count - bars > 0 then addToGudang(f.cid, e.item, e.count - bars) end
        end
    end
    local loads = { pending }
    for load in pairs(transit) do loads[#loads + 1] = load end
    pending = {}
    for _, load in ipairs(loads) do
        for cid, items in pairs(load) do
            for item, count in pairs(items) do addToGudang(cid, item, count) end
        end
    end
end)
