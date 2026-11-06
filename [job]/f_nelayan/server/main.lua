local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Kru nelayan (maks 4). Ikan bukan item: semua hitungan di sini, klien hanya menampilkan.
-- Dek tug muat 8 peti x jumlah anggota; peti di dermaga dibagi rata (kuota) lalu tiap anggota
-- memuat bagiannya ke bison sendiri dan menjualnya sendiri.
local crews = {}        -- id -> crew
local crewOf = {}       -- source -> crew id
local invites = {}      -- target source -> { crew = id, expires = os.time() }
local nextCrewId = 0

local NET = sharedConfig.netItem

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function notify(src, msg, typ)
    exports.qbx_core:Notify(src, msg, typ or 'inform')
end

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function charName(src)
    local player = getPlayer(src)
    if not player then return ('ID %s'):format(src) end
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname or '', info.lastname or '')
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    return GetEntityCoords(ped)
end

local function isNear(src, coords, dist)
    local c = pedCoords(src)
    return c ~= nil and #(c - vec3(coords.x, coords.y, coords.z)) <= dist
end

local function valid(ent)
    return ent and DoesEntityExist(ent)
end

local function nearEntity(src, ent, dist)
    if not valid(ent) then return false end
    local c = pedCoords(src)
    return c ~= nil and #(c - GetEntityCoords(ent)) <= dist
end

local function getCrew(src)
    local id = crewOf[src]
    return id and crews[id]
end

local function isMember(crew, src)
    for i = 1, #crew.members do
        if crew.members[i] == src then return i end
    end
end

local function notifyCrew(crew, msg, typ)
    for _, src in ipairs(crew.members) do notify(src, msg, typ) end
end

local function boatDocked(crew)
    return valid(crew.boat) and #(GetEntityCoords(crew.boat) - sharedConfig.dock) <= sharedConfig.dockRadius
end

local function onBoat(src, crew)
    return nearEntity(src, crew.boat, config.onBoatDistance)
end

local function pickSpot(prev)
    local list = sharedConfig.spots
    if #list == 1 then return 1 end
    local i
    repeat i = math.random(#list) until i ~= prev
    return i
end

-- jenis ikan acak per tarikan, bobot dari config.catchTable (spot jauh = peluang ikan mahal lebih besar)
local function rollFish(far)
    local list = far and config.catchTable.far or config.catchTable.near
    local total = 0
    for _, e in ipairs(list) do total += e[2] end
    local r = math.random() * total
    for _, e in ipairs(list) do
        r -= e[2]
        if r <= 0 then return e[1] end
    end
    return list[1][1]
end

-- daftar harga untuk menu: label, harga, peluang di spot dekat / jauh (persen)
local FISH_LIST = {}
do
    local chance = {}
    for kind, list in pairs(config.catchTable) do
        local total = 0
        for _, e in ipairs(list) do total += e[2] end
        for _, e in ipairs(list) do
            chance[e[1]] = chance[e[1]] or {}
            chance[e[1]][kind] = math.floor(e[2] / total * 100 + 0.5)
        end
    end
    for key, f in pairs(config.fish) do
        FISH_LIST[#FISH_LIST + 1] = { label = f.label, price = f.price, rare = f.rare, near = chance[key] and chance[key].near or 0, far = chance[key] and chance[key].far or 0 }
    end
    table.sort(FISH_LIST, function(a, b) return a.price < b.price end)
end

local function myTruck(crew, src)
    local t = crew.trucks[src]
    if t and valid(t.veh) then return t end
end

-- jarak datar titik p ke ruas garis a-b (zona jalur kerja)
local function distToSegment(p, a, b)
    local ax, ay, bx, by = a.x, a.y, b.x, b.y
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and math.max(0, math.min(1, ((p.x - ax) * dx + (p.y - ay) * dy) / len2)) or 0
    local cx, cy = ax + dx * t, ay + dy * t
    return math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
end

-- denda: bank dulu, kurang -> tunai
local function fine(src, amount, reason)
    local player = getPlayer(src)
    if not player then return end
    if player.Functions.RemoveMoney('bank', amount, reason) or player.Functions.RemoveMoney('cash', amount, reason) then
        notify(src, ('Kamu didenda %s.'):format(rupiah(amount)), 'error')
    else
        notify(src, ('Denda %s tidak bisa dibayar, uangmu kurang.'):format(rupiah(amount)), 'error')
    end
end

---------------------------------------------------------------------------
-- item jaring: metadata durability 100, tiap tebar -100/netUses, habis = rusak (pola kapak f_mining)
---------------------------------------------------------------------------
local function netCount(src)
    return exports.ox_inventory:Search(src, 'count', NET) or 0
end

-- pakai jaring yang paling aus dulu; true = jaring itu rusak dan hilang
local function wearNet(src, amount)
    local slots = exports.ox_inventory:GetSlotsWithItem(src, NET)
    if not slots or #slots == 0 then return end
    local slot, dur
    for _, s in ipairs(slots) do
        local d = s.metadata and s.metadata.durability or 100
        if not dur or d < dur then slot, dur = s, d end
    end
    local new = dur - amount
    if new <= 0.001 then
        exports.ox_inventory:RemoveItem(src, NET, 1, nil, slot.slot)
        return true
    end
    exports.ox_inventory:SetDurability(src, slot.slot, new)
end

---------------------------------------------------------------------------
-- sync: payload per anggota + statebag kendaraan (prop dek / bak untuk semua pemain di dekatnya)
---------------------------------------------------------------------------
local function payload(crew, src)
    local spot = crew.spot and sharedConfig.spots[crew.spot]
    local n = crew.nets[src]
    local truck = myTruck(crew, src)
    local members = {}
    for i, m in ipairs(crew.members) do
        members[i] = { id = m, name = crew.names[m], sold = crew.sold[m] or 0, earned = crew.earned[m] or 0 }
    end
    return {
        id = crew.id,
        me = src,
        leader = crew.leader,
        phase = crew.phase,
        members = members,
        boatNet = crew.boatNet,
        truckNet = truck and truck.net or nil,
        spot = spot and { label = spot.label, coords = spot.coords, far = spot.far } or nil,
        nets = netCount(src),
        net = n and { pos = n.pos, readyIn = math.max(0, n.readyAt - os.time()) } or nil,
        catch = crew.catch[src] and 1 or 0,
        catchLabel = crew.catch[src] and config.fish[crew.catch[src].f].label or nil,
        capacity = crew.capacity,
        deckFull = #crew.deckFull,
        deckEmpty = crew.capacity - #crew.deckFull,
        pier = #crew.pier,
        quota = crew.quota[src] or 0,
        truck = truck and #truck.bed or 0,
        truckReturn = truck and truck.returnBy and math.max(0, truck.returnBy - os.time()) or nil,
        carry = crew.carry[src] and crew.carry[src].from or nil,
        earned = crew.earned[src] or 0,
        sold = crew.sold[src] or 0,
    }
end

local function sync(crew)
    if valid(crew.boat) then
        local nets = {}
        for _, n in pairs(crew.nets) do nets[#nets + 1] = n.pos end
        Entity(crew.boat).state:set('fnl', { f = #crew.deckFull, w = nets }, true)
    end
    for _, t in pairs(crew.trucks) do
        if valid(t.veh) then Entity(t.veh).state:set('fnl', { t = #t.bed }, true) end
    end
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_nelayan:client:sync', src, payload(crew, src))
    end
end

local function refreshMenus(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_nelayan:client:menuRefresh', src)
    end
end

---------------------------------------------------------------------------
-- kendaraan
---------------------------------------------------------------------------
local function vehicleNear(coords, radius, except)
    for _, veh in ipairs(GetAllVehicles()) do
        if veh ~= except and #(GetEntityCoords(veh) - coords) <= radius then return true end
    end
    return false
end

local function spawnVehicle(model, kind, at)
    local veh = CreateVehicleServerSetter(joaat(model), kind, at.x, at.y, at.z, at.w)
    local ok = pcall(lib.waitFor, function()
        if DoesEntityExist(veh) and GetVehicleNumberPlateText(veh) ~= '' then return true end
    end, nil, 5000)
    if not ok then
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        return
    end
    SetVehicleNumberPlateText(veh, ('%s %04d'):format(sharedConfig.platePrefix, math.random(0, 9999)))
    Entity(veh).state:set('fuel', 100.0, true)
    exports.f_vehiclekeys:SetLockState(veh, 'unlock')
    return veh, NetworkGetNetworkIdFromEntity(veh)
end

local function deleteVehicle(veh, keyHolders)
    if not valid(veh) then return end
    for _, src in ipairs(keyHolders or {}) do exports.f_vehiclekeys:RemoveKeys(src, veh, true) end
    DeleteEntity(veh)
end

local function deleteTruck(crew, src)
    local t = crew.trucks[src]
    if t then deleteVehicle(t.veh, { src }) end
    crew.trucks[src] = nil
end

-- bison berjajar di samping tumpukan peti: slot ke-i bergeser ke kanan arah hadap truckSpawn
local function truckSlot(i)
    local s = sharedConfig.truckSpawn
    local h = math.rad(s.w)
    local d = (i - 1) * sharedConfig.truckSpacing
    return vec4(s.x + math.cos(h) * d, s.y + math.sin(h) * d, s.z, s.w)
end

-- pastikan tiap anggota punya bison di dermaga (dipakai lagi kalau masih dekat)
local function ensureTrucks(crew)
    local used = 0
    for _, src in ipairs(crew.members) do
        local t = myTruck(crew, src)
        if t and #(GetEntityCoords(t.veh) - sharedConfig.pier.xyz) > config.truckReuseDistance and #t.bed == 0 then
            deleteTruck(crew, src)
            t = nil
        end
        if t then t.returnBy, t.outSince = nil, nil end   -- dapat bagian baru: tidak wajib kembali dulu
        if not t then
            local veh, net
            for slot = used + 1, used + 6 do
                local at = truckSlot(slot)
                used = slot
                if not vehicleNear(at.xyz, config.spawnClear) then
                    veh, net = spawnVehicle(sharedConfig.truckModel, 'automobile', at)
                    break
                end
            end
            if veh then
                exports.f_vehiclekeys:GiveKeys(src, veh, true)
                crew.trucks[src] = { veh = veh, net = net, bed = {} }
            else
                notify(src, 'Parkiran bison di dermaga penuh, kosongkan lalu turunkan peti lagi.', 'error')
            end
        end
    end
end

---------------------------------------------------------------------------
-- siklus kru
---------------------------------------------------------------------------
local function newCrew(leader)
    nextCrewId += 1
    local crew = {
        id = nextCrewId, leader = leader, members = { leader }, names = { [leader] = charName(leader) },
        phase = 'lobby', phaseAt = os.time(), capacity = sharedConfig.cratesPerPlayer,
        deckFull = {}, pier = {}, quota = {}, trucks = {}, nets = {}, catch = {}, carry = {},
        earned = {}, sold = {}, sortReady = {}, shareStart = 1,
    }
    crews[crew.id] = crew
    crewOf[leader] = crew.id
    return crew
end

local function endCrew(crew, reason)
    if not crews[crew.id] then return end
    deleteVehicle(crew.boat, crew.members)
    for src in pairs(crew.trucks) do deleteTruck(crew, src) end
    for _, src in ipairs(crew.members) do
        crewOf[src] = nil
        TriggerClientEvent('f_nelayan:client:ended', src, reason)
    end
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    crews[crew.id] = nil
end

-- kuota dermaga dibagi rata; sisa bagi digilir antar trip supaya adil
local function shareOut(crew, total)
    local n = #crew.members
    local base, rem = total // n, total % n
    for i = 1, n do
        local idx = (crew.shareStart + i - 2) % n + 1
        local src = crew.members[idx]
        crew.quota[src] = (crew.quota[src] or 0) + base + (i <= rem and 1 or 0)
    end
    crew.shareStart = (crew.shareStart + rem - 1) % n + 1
end

local function removeMember(crew, src, reason)
    local index = isMember(crew, src)
    if not index then return end
    if #crew.members == 1 then return endCrew(crew, reason) end

    -- bagian yang belum terjual kembali ke tumpukan dermaga, dibagi ke anggota lain
    local back = crew.quota[src] or 0
    local carry = crew.carry[src]
    if carry then
        crew.pier[#crew.pier + 1] = carry.crate
        back += 1
    end
    local t = myTruck(crew, src)
    if t then
        for _, crate in ipairs(t.bed) do crew.pier[#crew.pier + 1] = crate end
        back += #t.bed
    end
    deleteTruck(crew, src)
    if valid(crew.boat) then exports.f_vehiclekeys:RemoveKeys(src, crew.boat, true) end
    crew.quota[src], crew.carry[src], crew.nets[src], crew.catch[src] = nil, nil, nil, nil
    table.remove(crew.members, index)
    crewOf[src] = nil
    TriggerClientEvent('f_nelayan:client:ended', src, reason)
    if back > 0 then shareOut(crew, back) end

    if crew.leader == src then
        crew.leader = crew.members[1]
        notifyCrew(crew, ('%s keluar, %s sekarang ketua kru.'):format(crew.names[src] or 'Ketua', crew.names[crew.leader]), 'inform')
    else
        notifyCrew(crew, ('%s keluar dari kru nelayan.'):format(crew.names[src] or 'Anggota'), 'inform')
    end
    sync(crew)
    refreshMenus(crew)
end

local function fishLeft(crew)
    if #crew.deckFull > 0 or #crew.pier > 0 or next(crew.carry) or next(crew.catch) or next(crew.nets) then return true end
    for _, t in pairs(crew.trucks) do
        if #t.bed > 0 then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- menu Syahbandar
---------------------------------------------------------------------------
local function menuData(src)
    local crew = getCrew(src)
    local nearby = {}
    local me = pedCoords(src)
    if me and (not crew or (crew.leader == src and crew.phase == 'lobby')) then
        for _, id in ipairs(GetPlayers()) do
            local target = tonumber(id)
            if target ~= src and not crewOf[target] then
                local c = pedCoords(target)
                if c and #(c - me) <= 10.0 then
                    local invite = invites[target]
                    nearby[#nearby + 1] = {
                        id = target, name = charName(target),
                        invited = invite ~= nil and crew ~= nil and invite.crew == crew.id and invite.expires > os.time(),
                    }
                end
            end
        end
    end
    return {
        me = src,
        maxCrew = sharedConfig.maxCrew,
        perPlayer = sharedConfig.cratesPerPlayer,
        fish = FISH_LIST,
        perfectBonus = math.floor(config.perfectBonus * 100),
        netPrice = sharedConfig.netPrice,
        netUses = sharedConfig.netUses,
        nets = netCount(src),
        crew = crew and payload(crew, src) or nil,
        nearby = nearby,
    }
end

lib.callback.register('f_nelayan:server:getMenu', function(src)
    if not isNear(src, sharedConfig.office.coords, config.officeDistance) then
        return { err = 'Temui Syahbandar di dermaga.' }
    end
    return menuData(src)
end)

-- beli jaring: tunai dulu, kurang -> bank (sama seperti kapak tambang)
lib.callback.register('f_nelayan:server:buyNet', function(src)
    if not isNear(src, sharedConfig.office.coords, config.officeDistance) then return { ok = false } end
    if not exports.ox_inventory:CanCarryItem(src, NET, 1) then return { ok = false, msg = 'Tasmu penuh.' } end
    local player = getPlayer(src)
    if not player then return { ok = false } end
    local price = sharedConfig.netPrice
    if not player.Functions.RemoveMoney('cash', price, 'beli-jaring-ikan')
        and not player.Functions.RemoveMoney('bank', price, 'beli-jaring-ikan') then
        return { ok = false, msg = ('Uangmu tidak cukup (%s).'):format(rupiah(price)) }
    end
    exports.ox_inventory:AddItem(src, NET, 1, { durability = 100 })
    local crew = getCrew(src)
    if crew then sync(crew) end
    return { ok = true, data = menuData(src) }
end)

lib.callback.register('f_nelayan:server:invite', function(src, target)
    target = tonumber(target)
    if not target or target == src or not isNear(src, sharedConfig.office.coords, config.officeDistance) then return { ok = false } end
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then
        return { ok = false, msg = 'Hanya ketua kru yang belum melaut yang bisa mengajak.' }
    end
    if crew and #crew.members >= sharedConfig.maxCrew then return { ok = false, msg = 'Kru sudah penuh.' } end
    if not getPlayer(target) or crewOf[target] then return { ok = false, msg = 'Pemain itu sudah punya kru.' } end
    local me, them = pedCoords(src), pedCoords(target)
    if not me or not them or #(me - them) > 10.0 then return { ok = false, msg = 'Pemain itu terlalu jauh.' } end
    local invite = invites[target]
    if invite and invite.expires > os.time() then return { ok = false, msg = 'Pemain itu sedang menerima ajakan lain.' } end

    crew = crew or newCrew(src)
    invites[target] = { crew = crew.id, expires = os.time() + config.inviteTimeout }
    TriggerClientEvent('f_nelayan:client:invite', target, charName(src))
    return { ok = true, data = menuData(src) }
end)

lib.callback.register('f_nelayan:server:respond', function(src, accept)
    local invite = invites[src]
    invites[src] = nil
    if not invite or invite.expires < os.time() then
        if accept then notify(src, 'Ajakan sudah kedaluwarsa.', 'error') end
        return false
    end
    local crew = crews[invite.crew]
    if not crew or crew.phase ~= 'lobby' then
        if accept then notify(src, 'Kru itu sudah melaut.', 'error') end
        return false
    end
    if not accept then
        notify(crew.leader, ('%s menolak ajakanmu.'):format(charName(src)), 'error')
        refreshMenus(crew)
        return false
    end
    if crewOf[src] or #crew.members >= sharedConfig.maxCrew then
        notify(src, 'Tidak bisa bergabung ke kru itu.', 'error')
        return false
    end
    crew.members[#crew.members + 1] = src
    crew.names[src] = charName(src)
    crewOf[src] = crew.id
    notifyCrew(crew, ('%s bergabung ke kru nelayan.'):format(crew.names[src]), 'success')
    sync(crew)
    refreshMenus(crew)
    return true
end)

lib.callback.register('f_nelayan:server:kick', function(src, target)
    target = tonumber(target)
    local crew = getCrew(src)
    if not crew or crew.leader ~= src or crew.phase ~= 'lobby' or target == src then return false end
    if not target or not isMember(crew, target) then return false end
    removeMember(crew, target, 'Kamu dikeluarkan dari kru nelayan oleh ketua.')
    return menuData(src)
end)

-- siapa saja boleh melaut, tanpa cek job / deposit. Hanya tug yang muncul; bison muncul saat peti dibongkar.
lib.callback.register('f_nelayan:server:start', function(src)
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then return { ok = false, msg = 'Hanya ketua kru yang bisa memulai.' } end
    if not isNear(src, sharedConfig.office.coords, config.officeDistance) then return { ok = false } end
    if vehicleNear(sharedConfig.boatSpawn.xyz, config.spawnClear * 3) then
        return { ok = false, msg = 'Sandaran kapal masih terisi, tunggu sebentar.' }
    end
    crew = crew or newCrew(src)
    local boat, boatNet = spawnVehicle(sharedConfig.boatModel, 'boat', sharedConfig.boatSpawn)
    if not boat then return { ok = false, msg = 'Gagal menyiapkan kapal, coba lagi.' } end
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    crew.boat, crew.boatNet = boat, boatNet
    crew.capacity = sharedConfig.cratesPerPlayer * #crew.members
    crew.spot = pickSpot()
    crew.phase, crew.phaseAt = 'work', os.time()
    for _, member in ipairs(crew.members) do exports.f_vehiclekeys:GiveKeys(member, boat, true) end
    notifyCrew(crew, ('Kapal siap (%s peti). Naik ke kapal lalu berlayar ke %s.'):format(crew.capacity, sharedConfig.spots[crew.spot].label), 'success')
    sync(crew)
    refreshMenus(crew)
    return { ok = true }
end)

lib.callback.register('f_nelayan:server:leave', function(src)
    local crew = getCrew(src)
    if not crew then return false end
    if crew.leader == src then
        endCrew(crew, crew.phase == 'lobby' and 'Kru nelayan dibubarkan.'
            or fishLeft(crew) and 'Kerja nelayan selesai. Ikan yang belum dijual hangus.' or 'Kerja nelayan selesai, terima kasih!')
    else
        removeMember(crew, src, 'Kamu keluar dari kru nelayan.')
    end
    return true
end)

---------------------------------------------------------------------------
-- di laut: tebar -> rendam -> tarik -> masukkan ke peti (tiap anggota dengan jaringnya sendiri)
---------------------------------------------------------------------------
lib.callback.register('f_nelayan:server:cast', function(src, pos)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'work' or type(pos) ~= 'vector3' then return { ok = false } end
    if netCount(src) <= 0 then return { ok = false, msg = 'Kamu tidak punya jaring. Beli di Syahbandar.' } end
    if crew.nets[src] then return { ok = false, msg = 'Jaringmu masih di laut.' } end
    if crew.catch[src] then return { ok = false, msg = 'Masukkan dulu ikan di tanganmu ke peti.' } end
    if #crew.deckFull >= crew.capacity then return { ok = false, msg = 'Semua peti penuh. Pulang dan jual hasilnya.' } end
    if not onBoat(src, crew) then return { ok = false } end
    local boatPos = GetEntityCoords(crew.boat)
    if #(pos - boatPos) > config.castDistance then return { ok = false } end
    if #(GetEntityVelocity(crew.boat)) > config.castMaxSpeed then return { ok = false, msg = 'Pelankan kapal dulu.' } end
    local spot = sharedConfig.spots[crew.spot]
    if #(boatPos.xy - spot.coords.xy) > sharedConfig.spotRadius then
        return { ok = false, msg = ('Di sini tidak ada ikan. Ke %s.'):format(spot.label) }
    end

    -- jaring baru aus saat tarikan berhasil (lihat haul), menebar saja tidak mengurangi pemakaian
    crew.nets[src] = { pos = vec3(pos.x, pos.y, 0.0), readyAt = os.time() + math.random(config.soakMin, config.soakMax) }
    sync(crew)
    return { ok = true }
end)

lib.callback.register('f_nelayan:server:haulStart', function(src)
    local crew = getCrew(src)
    local net = crew and crew.nets[src]
    if not net then return { ok = false } end
    if os.time() < net.readyAt then
        return { ok = false, msg = ('Ikan belum banyak, tunggu %s detik lagi.'):format(net.readyAt - os.time()) }
    end
    if not onBoat(src, crew) or #(GetEntityCoords(crew.boat) - net.pos) > config.haulDistance then
        return { ok = false, msg = 'Dekatkan kapal ke jaring.' }
    end
    net.haulAt = os.time()
    return { ok = true }
end)

-- 1 jaring isi ikan = 1 peti. Tarik-ulur gagal (hijau < minHits) = ikan lepas, jaring tidak aus.
-- Berhasil = jaring aus 1 pemakaian (rusak setelah netUses kali dapat ikan).
lib.callback.register('f_nelayan:server:haul', function(src, hits)
    local crew = getCrew(src)
    local net = crew and crew.nets[src]
    if not net or not net.haulAt then return { ok = false } end
    if os.time() - net.haulAt < config.haulMinSeconds then return { ok = false } end
    if not onBoat(src, crew) or #(GetEntityCoords(crew.boat) - net.pos) > config.haulDistance then
        net.haulAt = nil
        return { ok = false, msg = 'Kapal terlalu jauh dari jaring.' }
    end
    hits = math.max(0, math.min(3, math.floor(tonumber(hits) or 0)))
    crew.nets[src] = nil
    if hits < config.minHits then
        sync(crew)
        return { ok = true, empty = true, hits = hits }
    end
    if netCount(src) <= 0 then
        sync(crew)
        return { ok = false, msg = 'Jaringmu sudah tidak ada di tas, ikannya lepas.' }
    end
    local broke = wearNet(src, 100 / sharedConfig.netUses)
    local spot = sharedConfig.spots[crew.spot]
    local key = rollFish(spot.far)
    crew.catch[src] = { f = key, m = 1 + (hits >= 3 and config.perfectBonus or 0) }
    crew.sortReady[src] = os.time() + config.sortSeconds
    sync(crew)
    local fish = config.fish[key]
    return { ok = true, perfect = hits >= 3, broke = broke, fish = fish.label, rare = fish.rare }
end)

-- ikan di tangan -> peti kosong berikutnya (8 pertama, lalu menumpuk di atasnya)
lib.callback.register('f_nelayan:server:sort', function(src)
    local crew = getCrew(src)
    local crate = crew and crew.catch[src]
    if not crate then return { ok = false } end
    if #crew.deckFull >= crew.capacity then return { ok = false, msg = 'Semua peti sudah penuh.' } end
    if not onBoat(src, crew) then return { ok = false } end
    if os.time() < (crew.sortReady[src] or 0) then return { ok = false } end
    crew.catch[src] = nil
    crew.deckFull[#crew.deckFull + 1] = crate
    local full = #crew.deckFull >= crew.capacity
    sync(crew)
    if full then notifyCrew(crew, 'Semua peti di kapal penuh! Pulang ke dermaga.', 'success') end
    return { ok = true, full = full }
end)

---------------------------------------------------------------------------
-- di darat: bongkar -> tumpukan dermaga (kuota rata) -> bison masing-masing -> pasar
---------------------------------------------------------------------------
lib.callback.register('f_nelayan:server:unload', function(src)
    local crew = getCrew(src)
    if not crew or #crew.deckFull == 0 then return { ok = false } end
    if not boatDocked(crew) then return { ok = false, msg = 'Sandarkan kapal di dermaga dulu.' } end
    if not onBoat(src, crew) then return { ok = false } end
    if crew.unloadAt and os.time() - crew.unloadAt < config.unloadSeconds then return { ok = false } end
    crew.unloadAt = os.time()
    local total = #crew.deckFull
    for _, crate in ipairs(crew.deckFull) do crew.pier[#crew.pier + 1] = crate end
    crew.deckFull = {}
    shareOut(crew, total)
    ensureTrucks(crew)
    crew.spot = pickSpot(crew.spot)   -- trip berikutnya ke spot lain
    sync(crew)
    for _, m in ipairs(crew.members) do
        notify(m, ('%s peti diturunkan ke dermaga. Bagianmu %s peti, muat ke bison-mu.'):format(total, crew.quota[m] or 0), 'success')
    end
    return { ok = true }
end)

lib.callback.register('f_nelayan:server:take', function(src, from)
    local crew = getCrew(src)
    if not crew or crew.carry[src] or crew.catch[src] then return { ok = false } end
    local list
    if from == 'pier' then
        if (crew.quota[src] or 0) <= 0 then return { ok = false, msg = 'Bagianmu sudah habis diangkat.' } end
        if #crew.pier == 0 or not isNear(src, sharedConfig.pier, config.pierDistance) then return { ok = false } end
        crew.quota[src] -= 1
        list = crew.pier
    elseif from == 'truck' then
        local t = myTruck(crew, src)
        if not t or #t.bed == 0 or not nearEntity(src, t.veh, config.truckDistance) then return { ok = false } end
        if #(GetEntityCoords(t.veh) - sharedConfig.market.coords.xyz) > config.truckMarketDistance then
            return { ok = false, msg = 'Parkir bison di dekat Pasar Ikan dulu.' }
        end
        list = t.bed
    else
        return { ok = false }
    end
    crew.carry[src] = { crate = table.remove(list), from = from, at = os.time() }
    sync(crew)
    return { ok = true }
end)

-- [X] / batal: peti kembali ke asalnya
lib.callback.register('f_nelayan:server:putBack', function(src)
    local crew = getCrew(src)
    local carry = crew and crew.carry[src]
    if not carry then return false end
    local t = myTruck(crew, src)
    if carry.from == 'truck' and t then
        t.bed[#t.bed + 1] = carry.crate
    else
        crew.pier[#crew.pier + 1] = carry.crate
        crew.quota[src] = (crew.quota[src] or 0) + 1
    end
    crew.carry[src] = nil
    sync(crew)
    return true
end)

lib.callback.register('f_nelayan:server:loadTruck', function(src)
    local crew = getCrew(src)
    local carry = crew and crew.carry[src]
    if not carry or carry.from ~= 'pier' then return { ok = false } end
    if os.time() - carry.at < config.minCarrySeconds then return { ok = false } end
    local t = myTruck(crew, src)
    if not t or not nearEntity(src, t.veh, config.truckDistance) then return { ok = false, msg = 'Dekati bak bison-mu.' } end
    if #t.bed >= sharedConfig.bedCapacity then return { ok = false, msg = 'Bak bison sudah penuh.' } end
    t.bed[#t.bed + 1] = carry.crate
    crew.carry[src] = nil
    sync(crew)
    return { ok = true, done = (crew.quota[src] or 0) == 0 }
end)

lib.callback.register('f_nelayan:server:sell', function(src)
    local crew = getCrew(src)
    local carry = crew and crew.carry[src]
    if not carry or carry.from ~= 'truck' then return { ok = false } end
    if os.time() - carry.at < config.minCarrySeconds then return { ok = false } end
    if not isNear(src, sharedConfig.market.coords, config.marketDistance) then return { ok = false, msg = 'Bawa peti ke pedagang.' } end
    local player = getPlayer(src)
    if not player then return { ok = false } end

    local fish = config.fish[carry.crate.f]
    local worth = math.floor(fish.price * carry.crate.m)
    crew.carry[src] = nil
    crew.earned[src] = (crew.earned[src] or 0) + worth
    crew.sold[src] = (crew.sold[src] or 0) + 1
    player.Functions.AddMoney('bank', worth, 'fishing-sale')
    local t = myTruck(crew, src)
    local done = (not t or #t.bed == 0) and (crew.quota[src] or 0) == 0
    if done and t then
        -- bagian habis: bison wajib dikembalikan ke parkiran dermaga, tidak boleh dipakai keliling kota
        t.returnBy = os.time() + config.returnSeconds
        notify(src, ('Kembalikan bison ke parkiran dermaga dalam %s menit, atau denda %s.'):format(config.returnSeconds // 60, rupiah(config.returnFine)), 'inform')
    end
    sync(crew)
    return { ok = true, worth = worth, fish = fish.label, done = done, spot = sharedConfig.spots[crew.spot].label }
end)

-- tug / bison hancur atau tenggelam, dilaporkan klien anggota
lib.callback.register('f_nelayan:server:lost', function(src, what)
    local crew = getCrew(src)
    if not crew then return false end
    if what == 'truck' then
        if crew.trucks[src] then
            deleteTruck(crew, src)
            notify(src, 'Bison-mu rusak, peti di baknya hilang. Bison baru muncul saat peti dibongkar lagi.', 'error')
            sync(crew)
        end
    else
        endCrew(crew, 'Kapal tenggelam / rusak, kerja nelayan dibatalkan.')
    end
    return true
end)

---------------------------------------------------------------------------
-- pembersihan & pengawasan
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    invites[src] = nil
    local crew = getCrew(src)
    if crew then removeMember(crew, src, 'Terputus dari server.') end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, crew in pairs(crews) do
        deleteVehicle(crew.boat)
        for _, t in pairs(crew.trucks) do deleteVehicle(t.veh) end
    end
end)

-- tiap 5 detik: kendaraan hilang, jaring putus, kru meninggalkan kapal & bison
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for _, crew in pairs(crews) do
            if crew.phase == 'lobby' then
                if now - crew.phaseAt > config.lobbyTimeout then endCrew(crew, 'Kru nelayan dibubarkan karena tidak segera melaut.') end
            elseif not valid(crew.boat) then
                endCrew(crew, 'Kapal nelayan hilang, kerja dibatalkan.')
            else
                local changed = false
                local market = sharedConfig.market.coords
                for src, t in pairs(crew.trucks) do
                    if not valid(t.veh) then
                        crew.trucks[src] = nil
                        changed = true
                    else
                        local pos = GetEntityCoords(t.veh)
                        local noDriver = GetPedInVehicleSeat(t.veh, -1) == 0
                        if t.returnBy and noDriver and #(pos - sharedConfig.truckSpawn.xyz) <= config.returnRadius then
                            -- dikembalikan ke parkiran dermaga: bison hilang, tanpa denda
                            deleteTruck(crew, src)
                            notify(src, 'Bison dikembalikan, terima kasih.', 'success')
                            changed = true
                        elseif t.returnBy and now > t.returnBy then
                            deleteTruck(crew, src)
                            notify(src, 'Bison tidak dikembalikan tepat waktu.', 'error')
                            fine(src, config.returnFine, 'denda-bison-nelayan')
                            changed = true
                        elseif distToSegment(pos, sharedConfig.truckSpawn, market) > config.truckRouteMargin then
                            -- keluar jalur dermaga <-> Pasar Ikan: peringatan, lalu dihapus
                            if not t.outSince then
                                t.outSince = now
                                notify(src, ('Bison keluar jalur kerja! Kembali dalam %s detik atau bison ditarik.'):format(config.truckOutsideGrace), 'error')
                            elseif now - t.outSince > config.truckOutsideGrace then
                                local lost = #t.bed
                                local wasEmpty = t.returnBy ~= nil
                                deleteTruck(crew, src)
                                notify(src, lost > 0 and ('Bison ditarik karena keluar jalur. %s peti di baknya hangus.'):format(lost)
                                    or 'Bison ditarik karena keluar jalur.', 'error')
                                if wasEmpty then fine(src, config.returnFine, 'denda-bison-nelayan') end
                                changed = true
                            end
                        else
                            t.outSince = nil
                        end
                    end
                end
                local boatPos = GetEntityCoords(crew.boat)
                -- tug hanya boleh di sekitar jalur dermaga <-> spot ikan
                local spot = sharedConfig.spots[crew.spot]
                if distToSegment(boatPos, sharedConfig.dock, spot.coords) > config.tugRouteMargin then
                    if not crew.boatOutSince then
                        crew.boatOutSince = now
                        notifyCrew(crew, ('Kapal keluar area kerja! Kembali dalam %s detik atau kerja dibatalkan.'):format(config.tugOutsideGrace), 'error')
                    elseif now - crew.boatOutSince > config.tugOutsideGrace then
                        endCrew(crew, 'Kapal dibawa keluar area kerja, kerja nelayan dibatalkan.')
                        goto continue
                    end
                else
                    crew.boatOutSince = nil
                end
                for src, net in pairs(crew.nets) do
                    if #(boatPos - net.pos) > config.netBreakDistance then
                        -- jaring yang hanyut hilang dari tas (bukan aus, memang hilang di laut)
                        wearNet(src, 1000)
                        crew.nets[src] = nil
                        notify(src, 'Kapal terlalu jauh, jaringmu putus dan hanyut!', 'error')
                        changed = true
                    end
                end
                if changed then sync(crew) end

                local someoneNear = false
                for _, src in ipairs(crew.members) do
                    if nearEntity(src, crew.boat, config.abandonDistance) then someoneNear = true end
                    for _, t in pairs(crew.trucks) do
                        if nearEntity(src, t.veh, config.abandonDistance) then someoneNear = true end
                    end
                end
                if someoneNear then
                    crew.awaySince = nil
                elseif not crew.awaySince then
                    crew.awaySince = now
                    notifyCrew(crew, 'Kapal ditinggal terlalu jauh! Kembali dalam 5 menit atau kerja batal.', 'error')
                elseif now - crew.awaySince > config.abandonSeconds then
                    endCrew(crew, 'Kapal ditinggal terlalu lama, kerja nelayan dibatalkan.')
                end
            end
            ::continue::
        end
    end
end)
