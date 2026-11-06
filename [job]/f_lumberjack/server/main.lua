local config = require 'config.server'
local sharedConfig = require 'config.shared'

local crews = {}      -- id -> crew
local crewOf = {}     -- source -> crew id
local invites = {}    -- target source -> { crew = id, expires = os.time() }
local nextCrewId = 0

local trees = {}      -- index -> { available, reservedBy, reservedUntil, cutStart }
-- kayu di tanah milik kru, dilihat semua pemain: batang utuh ('trunk') atau potongan ('piece')
local items = {}      -- id -> { crew, kind, x, y, z, h, front, back, claimAt, cutBy, cutUntil, cutStart }
local nextItemId = 0
local carrying = {}   -- source -> { id, item, role = 'piece' | 'front' | 'back', partner, since }
local stationBusy = {}
local per = sharedConfig.piecesPerTrunk

for i, c in ipairs(sharedConfig.trees) do
    trees[i] = { available = true, coords = c }
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function notify(src, msg, typ)
    exports.qbx_core:Notify(src, msg, typ or 'inform')
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

local function playersNear(coords, dist)
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local c = pedCoords(src)
        if c and #(c - coords) <= dist then list[#list + 1] = src end
    end
    return list
end

local function emitNear(coords, event, ...)
    for _, src in ipairs(playersNear(coords, config.syncDistance)) do
        TriggerClientEvent(event, src, ...)
    end
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

local function truckValid(crew)
    return crew.vehicle and DoesEntityExist(crew.vehicle)
end

local function isDriver(src, crew)
    if not truckValid(crew) then return false end
    return GetPedInVehicleSeat(crew.vehicle, -1) == GetPlayerPed(src)
end

-- pemain di belakang truk (untuk memasukkan kayu ke bak)
local function behindTruck(crew, src)
    local c = pedCoords(src)
    if not c then return false end
    local v = GetEntityCoords(crew.vehicle)
    if #(c - v) > config.loadDistance then return false end
    local h = math.rad(GetEntityHeading(crew.vehicle))
    local d = c - v
    return d.x * -math.sin(h) + d.y * math.cos(h) < -1.0
end

local function isNum(v, min, max)
    return type(v) == 'number' and v == v and v >= min and v <= max
end

local function isUnemployed(src)
    local player = getPlayer(src)
    return player ~= nil and player.PlayerData.job.name == 'unemployed'
end

local function hasChainsaw(src)
    return exports.ox_inventory:GetItemCount(src, 'chainsaw') > 0
end

---------------------------------------------------------------------------
-- kayu di tanah (semua pemain melihat, hanya kru pemilik yang bisa memakai)
---------------------------------------------------------------------------
local function units(item)
    return item.kind == 'trunk' and sharedConfig.piecesPerTrunk or 1
end

local function public(item)
    return { crew = item.crew, kind = item.kind, x = item.x, y = item.y, z = item.z, h = item.h, front = item.front, back = item.back }
end

local function addItem(crewId, kind, x, y, z, h)
    nextItemId += 1
    local item = { crew = crewId, kind = kind, x = x, y = y, z = z, h = h }
    items[nextItemId] = item
    return nextItemId, item
end

local function broadcastAdd(list)
    local out = {}
    for id, item in pairs(list) do out[id] = public(item) end
    TriggerClientEvent('f_lumberjack:client:itemsAdd', -1, out)
end

local function broadcastClaim(id, item)
    TriggerClientEvent('f_lumberjack:client:itemClaim', -1, id, item.front, item.back)
end

-- kayu krumu yang belum dimuat (di tanah + sedang dipanggul), dalam potongan
local function groundUnits(crewId)
    local n = 0
    for _, item in pairs(items) do
        if item.crew == crewId then n += units(item) end
    end
    for _, c in pairs(carrying) do
        if c.item.crew == crewId and c.role ~= 'back' then n += units(c.item) end
    end
    return n
end

local function claimFresh(item)
    return item.claimAt and os.time() - item.claimAt <= sharedConfig.claimTimeout
end

local function clearClaims(src)
    for id, item in pairs(items) do
        if item.front == src or item.back == src then
            if item.front == src then item.front = nil end
            if item.back == src then item.back = nil end
            broadcastClaim(id, item)
        end
    end
end

---------------------------------------------------------------------------
-- memanggul
---------------------------------------------------------------------------
local function startCarry(src, id, item, role, partner)
    carrying[src] = { id = id, item = item, role = role, partner = partner, since = GetGameTimer() }
    TriggerClientEvent('f_lumberjack:client:carry', src, { id = id, kind = item.kind, role = role, partner = partner })
end

local function endCarry(src)
    if not carrying[src] then return end
    carrying[src] = nil
    TriggerClientEvent('f_lumberjack:client:carry', src, nil)
end

-- kayu yang dipanggul jatuh ke tanah: di depan pemain (potongan) / di belakang pemain depan (batang besar)
local function dropCarry(src)
    local c = carrying[src]
    if not c then return end
    local item = c.item
    local front = c.role == 'front' and src or c.role == 'back' and c.partner or src
    endCarry(src)
    if c.partner then endCarry(c.partner) end

    local ped = GetPlayerPed(front)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
        local r = math.rad(h)
        local d = item.kind == 'trunk' and -2.0 or 0.8
        item.x, item.y, item.z, item.h = p.x - math.sin(r) * d, p.y + math.cos(r) * d, p.z - 1.0, h
    end
    item.front, item.back, item.claimAt = nil, nil, nil
    items[c.id] = item
    broadcastAdd({ [c.id] = item })
end

local function removeCrewItems(crew)
    local removed = {}
    for id, item in pairs(items) do
        if item.crew == crew.id then
            items[id] = nil
            removed[#removed + 1] = id
        end
    end
    if #removed > 0 then TriggerClientEvent('f_lumberjack:client:itemsRemove', -1, removed) end
    for _, src in ipairs(crew.members) do endCarry(src) end
end

---------------------------------------------------------------------------
-- Gudang Kayu: stok papan per citizenid (aman walau tas penuh, offline, atau restart)
---------------------------------------------------------------------------
local function citizenId(src)
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid
end

local function gudangStock(cid)
    local key = 'gudang:' .. cid
    local n = GetResourceKvpInt(key) or 0
    -- sisa papan versi lama (diambil di Mandor) pindah ke gudang
    local old = GetResourceKvpInt('sisa:' .. cid) or 0
    if old > 0 then
        n += old
        SetResourceKvpInt(key, n)
        DeleteResourceKvp('sisa:' .. cid)
    end
    return n
end

local function addGudang(cid, n)
    if not cid or n <= 0 then return end
    SetResourceKvpInt('gudang:' .. cid, gudangStock(cid) + n)
    local player = exports.qbx_core:GetPlayerByCitizenId(cid)
    if player then
        notify(player.PlayerData.source, ('+%s papan masuk Gudang Kayu-mu. Ambil di Mandor Paleto.'):format(n), 'success')
    end
end

-- members: list of { src, cid, share }, leader dapat sisa pembulatan; masuk gudang masing-masing
local function splitPapan(total, members, leader)
    if total <= 0 or #members == 0 then return end
    local given, leaderEntry = 0, nil
    for _, m in ipairs(members) do
        local n = math.floor(total * (m.share or 0) / 100)
        m.amount = n
        given += n
        if m.src == leader then leaderEntry = m end
    end
    leaderEntry = leaderEntry or members[1]
    leaderEntry.amount += total - given
    for _, m in ipairs(members) do addGudang(m.cid, m.amount) end
end

---------------------------------------------------------------------------
-- papan hasil olahan kru: crew.output (menunggu di sawmill) -> crew.cargo (di truk) -> gudang
-- tumpukan papan di sawmill hanya prop tetap untuk semua pemain, jumlahnya dicatat di sini
---------------------------------------------------------------------------
local function pendingPapan(crew)
    return (crew.cargo or 0) + (crew.output or 0)
end

local function takePending(crew, n)
    local fromCargo = math.min(n, crew.cargo or 0)
    crew.cargo = (crew.cargo or 0) - fromCargo
    crew.output = (crew.output or 0) - (n - fromCargo)
end

local function memberList(crew)
    local list = {}
    for _, src in ipairs(crew.members) do
        list[#list + 1] = { src = src, cid = crew.cids[src], share = crew.shares[src] }
    end
    return list
end

local function equalShares(crew)
    local n = #crew.members
    local each = math.floor(100 / n)
    for _, src in ipairs(crew.members) do crew.shares[src] = each end
    crew.shares[crew.leader] = (crew.shares[crew.leader] or 0) + (100 - each * n)
end

---------------------------------------------------------------------------
-- sync
---------------------------------------------------------------------------
local function payload(crew)
    local members = {}
    for i, src in ipairs(crew.members) do
        members[i] = { id = src, name = crew.names[src], share = crew.shares[src] or 0 }
    end
    return {
        id = crew.id,
        leader = crew.leader,
        phase = crew.phase,
        members = members,
        cargo = crew.cargo or 0,                                -- papan di truk, dibongkar di markas
        output = crew.output or 0,                              -- papan menunggu di tumpukan sawmill
        kind = crew.kind,
        bed = crew.bed,
        cap = crew.cap or sharedConfig.trucks.solo.capacity,
        netId = crew.netId,
        unloading = crew.unloading,
        ground = groundUnits(crew.id),
        bonus = sharedConfig.crewBonus[#crew.members] or 0,
    }
end

-- isi bak dilihat semua pemain di dekat truk
local function setTruckState(crew)
    if not truckValid(crew) then return end
    -- trunks = batang besar utuh di bak (tampil prop_log_03), sisanya potongan (prop_log_01); planks = tumpukan papan
    Entity(crew.vehicle).state:set('flj', { bed = crew.bed, trunks = crew.trunks or 0, planks = (crew.cargo or 0) > 0 }, true)
end

local function sync(crew)
    local data = payload(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_lumberjack:client:sync', src, data)
    end
    setTruckState(crew)
end

local function notifyCrew(crew, msg, typ)
    for _, src in ipairs(crew.members) do notify(src, msg, typ) end
end

local function refreshMenus(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_lumberjack:client:menuRefresh', src)
    end
end

---------------------------------------------------------------------------
-- crew lifecycle
---------------------------------------------------------------------------
local function newCrew(leader)
    nextCrewId += 1
    local crew = {
        id = nextCrewId,
        leader = leader,
        members = { leader },
        names = { [leader] = charName(leader) },
        cids = { [leader] = citizenId(leader) },
        shares = { [leader] = 100 },
        cargo = 0,   -- papan di truk; dibagi ke gudang anggota sesuai % ketua saat Bongkar papan
        bed = 0,
        phase = 'lobby',
        phaseAt = os.time(),
    }
    crews[crew.id] = crew
    crewOf[leader] = crew.id
    return crew
end

local function deleteTruck(crew)
    if truckValid(crew) then DeleteEntity(crew.vehicle) end
    crew.vehicle, crew.netId = nil, nil
end

-- papan yang belum dibongkar tidak hilang: langsung masuk gudang anggota
local function stopWork(crew)
    splitPapan(pendingPapan(crew), memberList(crew), crew.leader)
    removeCrewItems(crew)
    deleteTruck(crew)
    crew.bed, crew.trunks, crew.cargo, crew.output, crew.unloading = 0, 0, 0, 0, false
    for _, src in ipairs(crew.members) do TriggerClientEvent('f_lumberjack:client:outfit', src, false) end
end

local function endCrew(crew, reason)
    if not crews[crew.id] then return end
    -- papan from a saw run still in progress goes to these members when it finishes
    crew.endedMembers, crew.endedLeader = memberList(crew), crew.leader
    stopWork(crew)
    for _, src in ipairs(crew.members) do
        crewOf[src] = nil
        TriggerClientEvent('f_lumberjack:client:ended', src, reason)
    end
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    crews[crew.id] = nil
end

local function removeMember(crew, src, reason)
    local index = isMember(crew, src)
    if not index then return end
    if #crew.members == 1 then return endCrew(crew, reason) end

    dropCarry(src)
    clearClaims(src)

    -- leaving early takes their % of the papan not yet unloaded (into their gudang), the rest stays with the crew
    local share = math.floor(pendingPapan(crew) * (crew.shares[src] or 0) / 100)
    takePending(crew, share)
    addGudang(crew.cids[src], share)
    if truckValid(crew) then exports.f_vehiclekeys:RemoveKeys(src, crew.vehicle, true) end
    if crew.phase == 'work' then TriggerClientEvent('f_lumberjack:client:outfit', src, false) end
    table.remove(crew.members, index)
    crewOf[src] = nil
    crew.shares[src] = nil
    TriggerClientEvent('f_lumberjack:client:ended', src, reason)

    if crew.leader == src then
        crew.leader = crew.members[1]
        notifyCrew(crew, ('%s keluar, %s sekarang menjadi ketua kru.'):format(crew.names[src] or 'Ketua', crew.names[crew.leader]), 'inform')
    else
        notifyCrew(crew, ('%s keluar dari kru.'):format(crew.names[src] or 'Anggota'), 'inform')
    end
    equalShares(crew)
    sync(crew)
    refreshMenus(crew)
end

---------------------------------------------------------------------------
-- menu (NPC Mandor)
---------------------------------------------------------------------------
local NOT_UNEMPLOYED = 'Kerja penebang kayu hanya untuk warga yang belum punya pekerjaan.'

local function atNpc(src)
    return isNear(src, sharedConfig.npc.coords, config.npcDistance)
end

local function menuData(src)
    local crew = getCrew(src)
    local nearby = {}
    local myCoords = pedCoords(src)
    if myCoords and (not crew or (crew.leader == src and crew.phase == 'lobby')) then
        for _, id in ipairs(GetPlayers()) do
            local target = tonumber(id)
            if target ~= src and not crewOf[target] and isUnemployed(target) then
                local c = pedCoords(target)
                if c and #(c - myCoords) <= 10.0 then
                    local invite = invites[target]
                    nearby[#nearby + 1] = {
                        id = target,
                        name = charName(target),
                        invited = invite ~= nil and crew ~= nil and invite.crew == crew.id and invite.expires > os.time(),
                    }
                end
            end
        end
    end

    return {
        me = src,
        maxCrew = sharedConfig.maxCrew,
        crew = crew and payload(crew) or nil,
        nearby = nearby,
        price = sharedConfig.papanPrice,
        perPiece = sharedConfig.papanPerPiece,
        perTrunk = sharedConfig.piecesPerTrunk,
        capSolo = sharedConfig.trucks.solo.capacity,
        capCrew = sharedConfig.trucks.crew.capacity // sharedConfig.piecesPerTrunk,
        -- string keys: a 1..n Lua table would arrive in JS as a 0-based array
        bonusTable = { ['2'] = sharedConfig.crewBonus[2], ['3'] = sharedConfig.crewBonus[3], ['4'] = sharedConfig.crewBonus[4] },
    }
end

lib.callback.register('f_lumberjack:server:getMenu', function(src)
    if not atNpc(src) then return { err = 'Buka menu ini di Mandor Paleto.' } end
    if not isUnemployed(src) then return { err = NOT_UNEMPLOYED .. ' Berhenti dulu dari pekerjaanmu.' } end
    return menuData(src)
end)

lib.callback.register('f_lumberjack:server:invite', function(src, target)
    target = tonumber(target)
    if not target or target == src or not atNpc(src) or not isUnemployed(src) then return { ok = false } end
    if not isUnemployed(target) then return { ok = false, msg = 'Pemain itu sudah punya pekerjaan.' } end
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then
        return { ok = false, msg = 'Hanya ketua kru yang belum mulai yang bisa mengajak.' }
    end
    if crew and #crew.members >= sharedConfig.maxCrew then return { ok = false, msg = 'Kru sudah penuh.' } end
    if not getPlayer(target) or crewOf[target] then return { ok = false, msg = 'Pemain itu sudah punya kru.' } end
    local myCoords, targetCoords = pedCoords(src), pedCoords(target)
    if not myCoords or not targetCoords or #(myCoords - targetCoords) > 10.0 then
        return { ok = false, msg = 'Pemain itu terlalu jauh.' }
    end
    local invite = invites[target]
    if invite and invite.expires > os.time() then return { ok = false, msg = 'Pemain itu sedang menerima ajakan lain.' } end

    crew = crew or newCrew(src)
    invites[target] = { crew = crew.id, expires = os.time() + config.inviteTimeout }
    TriggerClientEvent('f_lumberjack:client:invite', target, charName(src))
    return { ok = true, data = menuData(src) }
end)

lib.callback.register('f_lumberjack:server:respond', function(src, accept)
    local invite = invites[src]
    invites[src] = nil
    if not invite or invite.expires < os.time() then
        if accept then notify(src, 'Ajakan sudah kedaluwarsa.', 'error') end
        return false
    end
    local crew = crews[invite.crew]
    if not crew or crew.phase ~= 'lobby' then
        if accept then notify(src, 'Kru itu sudah tidak menerima anggota.', 'error') end
        return false
    end
    if not accept then
        notify(crew.leader, ('%s menolak ajakanmu.'):format(charName(src)), 'error')
        refreshMenus(crew)
        return false
    end
    if not isUnemployed(src) then
        notify(src, NOT_UNEMPLOYED, 'error')
        return false
    end
    if crewOf[src] or #crew.members >= sharedConfig.maxCrew then
        notify(src, 'Tidak bisa bergabung ke kru itu.', 'error')
        return false
    end

    crew.members[#crew.members + 1] = src
    crew.names[src] = charName(src)
    crew.cids[src] = citizenId(src)
    crewOf[src] = crew.id
    equalShares(crew)
    notifyCrew(crew, ('%s bergabung ke kru penebang.'):format(crew.names[src]), 'success')
    sync(crew)
    refreshMenus(crew)
    return true
end)

-- ketua mengatur % bagian papan tiap anggota (total maks 100, sisanya untuk ketua)
lib.callback.register('f_lumberjack:server:setShares', function(src, list)
    local crew = getCrew(src)
    if not crew or crew.leader ~= src or type(list) ~= 'table' then return { ok = false } end
    local total, new = 0, {}
    for _, member in ipairs(crew.members) do
        local pct = tonumber(list[tostring(member)] or list[member])
        if not pct or pct ~= math.floor(pct) or pct < 0 or pct > 100 then
            return { ok = false, msg = 'Persen harus angka bulat 0-100.' }
        end
        new[member] = pct
        total += pct
    end
    if total > 100 then return { ok = false, msg = 'Total bagian melebihi 100%.' } end
    new[crew.leader] += 100 - total
    crew.shares = new
    sync(crew)
    refreshMenus(crew)
    return { ok = true, data = menuData(src) }
end)

local function vehicleNear(coords, radius)
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - coords) <= radius then return true end
    end
    return false
end

local function spawnTruck(crew)
    local spot
    for _, s in ipairs(sharedConfig.truckSpawns) do
        if not vehicleNear(s.xyz, 3.5) then
            spot = s
            break
        end
    end
    if not spot then return false, 'Parkiran truk sedang terisi, kosongkan dulu.' end

    local kind = #crew.members > 1 and 'crew' or 'solo'
    local truck = sharedConfig.trucks[kind]
    crew.kind = kind
    local veh = CreateVehicleServerSetter(joaat(truck.model), 'automobile', spot.x, spot.y, spot.z, spot.w)
    local ok = pcall(lib.waitFor, function()
        if DoesEntityExist(veh) and GetVehicleNumberPlateText(veh) ~= '' then return true end
    end, nil, 5000)
    if not ok then
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        return false, 'Gagal memunculkan truk, coba lagi.'
    end

    SetVehicleNumberPlateText(veh, ('%s %04d'):format(config.platePrefix, math.random(0, 9999)))
    Entity(veh).state:set('fuel', 100.0, true)
    crew.vehicle, crew.netId, crew.cap = veh, NetworkGetNetworkIdFromEntity(veh), truck.capacity
    for _, member in ipairs(crew.members) do exports.f_vehiclekeys:GiveKeys(member, veh, true) end
    exports.f_vehiclekeys:SetLockState(veh, 'unlock')
    return true
end

lib.callback.register('f_lumberjack:server:start', function(src)
    if not atNpc(src) then return { ok = false, msg = 'Tidak bisa memulai di sini.' } end
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then
        return { ok = false, msg = 'Hanya ketua kru yang bisa memulai.' }
    end
    if not isUnemployed(src) then return { ok = false, msg = NOT_UNEMPLOYED } end
    for _, member in ipairs(crew and crew.members or {}) do
        if not isUnemployed(member) then
            return { ok = false, msg = ('%s sudah punya pekerjaan, keluarkan dulu dari kru.'):format(crew.names[member] or 'Anggota') }
        end
    end

    local fresh = crew == nil
    crew = crew or newCrew(src)
    local ok, err = spawnTruck(crew)
    if not ok then
        if fresh then crews[crew.id], crewOf[src] = nil, nil end
        return { ok = false, msg = err }
    end
    crew.phase, crew.phaseAt = 'work', os.time()
    crew.bed, crew.trunks, crew.cargo, crew.unloading = 0, 0, 0, false
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    -- seragam langsung terpasang, tidak ada loker
    for _, member in ipairs(crew.members) do
        TriggerClientEvent('f_lumberjack:client:outfit', member, true)
        TriggerClientEvent('f_lumberjack:client:waypoint', member, sharedConfig.forest)
    end
    notifyCrew(crew, #crew.members > 1
        and 'Truk flatbed siap. Tebang pohon di hutan sawmill, angkat batangnya berdua ke bak, olah di sawmill, lalu bawa papan ke sini.'
        or 'Truk siap. Tebang pohon di hutan sawmill, potong batangnya, panggul ke bak, olah di sawmill, lalu bawa papan ke sini.', 'success')
    sync(crew)
    return { ok = true }
end)

lib.callback.register('f_lumberjack:server:leave', function(src)
    local crew = getCrew(src)
    if not crew then return false end
    if crew.leader == src then
        endCrew(crew, crew.phase == 'lobby' and 'Kru dibubarkan.' or 'Ketua membatalkan kerja.')
    else
        removeMember(crew, src, 'Kamu keluar dari kru penebang.')
    end
    return true
end)

---------------------------------------------------------------------------
-- NPC Mandor: chainsaw & Gudang Kayu
---------------------------------------------------------------------------
lib.callback.register('f_lumberjack:server:buyChainsaw', function(src)
    if not atNpc(src) then return { ok = false } end
    if not exports.ox_inventory:CanCarryItem(src, 'chainsaw', 1) then return { ok = false, msg = 'Tasmu penuh.' } end
    local player = getPlayer(src)
    if not player then return { ok = false } end
    local price = sharedConfig.chainsawPrice
    if not player.Functions.RemoveMoney('cash', price, 'beli-chainsaw')
        and not player.Functions.RemoveMoney('bank', price, 'beli-chainsaw') then
        return { ok = false, msg = ('Uangmu tidak cukup (Rp %s).'):format(lib.math.groupdigits(price, '.')) }
    end
    exports.ox_inventory:AddItem(src, 'chainsaw', 1, { durability = 100 })
    return { ok = true }
end)

-- Gudang Kayu bisa dibuka siapa saja (juga yang sudah punya pekerjaan lain), hanya di Mandor
local function gudangData(src)
    local cid = citizenId(src)
    if not cid then return { err = 'Data karakter tidak ditemukan.' } end
    return {
        stock = gudangStock(cid),
        fits = exports.ox_inventory:CanCarryAmount(src, 'papan_kayu') or 0,
        price = sharedConfig.papanPrice,
    }
end

lib.callback.register('f_lumberjack:server:gudang', function(src)
    if not atNpc(src) then return { err = 'Gudang Kayu ada di Mandor Paleto.' } end
    return gudangData(src)
end)

lib.callback.register('f_lumberjack:server:takeGudang', function(src, amount)
    if not atNpc(src) then return { ok = false } end
    local cid = citizenId(src)
    amount = tonumber(amount)
    if not cid or not amount or amount ~= math.floor(amount) or amount < 1 then
        return { ok = false, msg = 'Jumlah tidak valid.' }
    end
    local stock = gudangStock(cid)
    if stock < 1 then return { ok = false, msg = 'Gudangmu kosong.' } end
    local n = math.min(amount, stock, exports.ox_inventory:CanCarryAmount(src, 'papan_kayu') or 0)
    if n < 1 then return { ok = false, msg = 'Tasmu penuh.' } end
    SetResourceKvpInt('gudang:' .. cid, stock - n)
    if not exports.ox_inventory:AddItem(src, 'papan_kayu', n) then
        SetResourceKvpInt('gudang:' .. cid, gudangStock(cid) + n)
        return { ok = false, msg = 'Gagal memindahkan papan, coba lagi.' }
    end
    return { ok = true, msg = ('Mengambil %s papan kayu. Jual di koperasi.'):format(n), data = gudangData(src) }
end)

---------------------------------------------------------------------------
-- pohon (dipakai bersama semua pemain)
---------------------------------------------------------------------------
lib.callback.register('f_lumberjack:server:world', function()
    local avail, list = {}, {}
    for i, t in ipairs(trees) do avail[i] = t.available end
    for id, item in pairs(items) do list[id] = public(item) end
    return { trees = avail, items = list }
end)

local function wearChainsaw(src)
    local slots = exports.ox_inventory:GetSlotsWithItem(src, 'chainsaw')
    if not slots or #slots == 0 then return end
    local slot, dur
    for _, s in ipairs(slots) do
        local d = s.metadata and s.metadata.durability or 100
        if not dur or d < dur then slot, dur = s, d end
    end
    local new = dur - 100 / config.chainsawTrees
    if new <= 0.001 then
        exports.ox_inventory:RemoveItem(src, 'chainsaw', 1, nil, slot.slot)
        return true
    end
    exports.ox_inventory:SetDurability(src, slot.slot, new)
end

local function canSaw(src)
    if not hasChainsaw(src) then return false, 'Kamu butuh chainsaw (beli di Mandor Paleto).' end
    return true
end

lib.callback.register('f_lumberjack:server:reserveTree', function(src, id)
    local crew = getCrew(src)
    local tree = trees[id]
    if not crew or crew.phase ~= 'work' or not tree or carrying[src] then return { ok = false } end
    if not tree.available then return { ok = false, msg = 'Pohon ini sudah ditebang.' } end
    if not isNear(src, tree.coords, config.treeDistance) then return { ok = false } end
    local ok, msg = canSaw(src)
    if not ok then return { ok = false, msg = msg } end
    if groundUnits(crew.id) + sharedConfig.piecesPerTrunk > sharedConfig.groundLimit then
        return { ok = false, msg = 'Kayu krumu masih banyak di tanah (maks 2 pohon). Muat dulu ke truk.' }
    end
    local now = os.time()
    if tree.reservedBy and tree.reservedBy ~= src and (tree.reservedUntil or 0) >= now then
        return { ok = false, msg = 'Pohon ini sedang ditebang orang lain.' }
    end
    for _, t in ipairs(trees) do
        if t.reservedBy == src then t.reservedBy = nil end
    end
    tree.reservedBy, tree.reservedUntil, tree.cutStart = src, now + config.reserveSeconds, GetGameTimer()
    emitNear(tree.coords, 'f_lumberjack:client:sound', 'chainsaw', tree.coords)
    return { ok = true, seconds = config.cutSeconds }
end)

RegisterNetEvent('f_lumberjack:server:cancelTree', function(id)
    local tree = trees[id]
    if tree and tree.reservedBy == source then tree.reservedBy, tree.reservedUntil = nil, nil end
end)

lib.callback.register('f_lumberjack:server:fellTree', function(src, id, heading)
    local crew = getCrew(src)
    local tree = trees[id]
    if not crew or crew.phase ~= 'work' or not tree or not tree.available or tree.reservedBy ~= src then return false end
    if not isNum(heading, -360.0, 720.0) then return false end
    if GetGameTimer() - (tree.cutStart or 0) < (config.cutSeconds - 1) * 1000 then return false end
    if not isNear(src, tree.coords, config.treeDistance) then return false end
    if not hasChainsaw(src) then return false end

    tree.available, tree.reservedBy, tree.reservedUntil = false, nil, nil
    heading = heading % 360.0
    if wearChainsaw(src) then notify(src, 'Chainsaw-mu rusak. Beli yang baru di Mandor Paleto.', 'error') end

    -- one whole trunk lying along the fall direction; clients lay it on the ground
    local rad = math.rad(heading)
    local d = sharedConfig.trunk.offset
    local itemId, item = addItem(crew.id, 'trunk', tree.coords.x - math.sin(rad) * d, tree.coords.y + math.cos(rad) * d, tree.coords.z, heading)
    TriggerClientEvent('f_lumberjack:client:treeFall', -1, id, heading, { [itemId] = public(item) })
    emitNear(tree.coords, 'f_lumberjack:client:sound', 'treefall', tree.coords)
    sync(crew)

    SetTimeout(config.treeRespawn * 1000, function()
        tree.available = true
        TriggerClientEvent('f_lumberjack:client:treeBack', -1, id)
    end)
    return true
end)

---------------------------------------------------------------------------
-- batang: potong jadi potongan / angkat berdua
---------------------------------------------------------------------------
local function ownItem(src, id, kind)
    local crew = getCrew(src)
    local item = items[id]
    if not crew or crew.phase ~= 'work' or not item or item.crew ~= crew.id or item.kind ~= kind or carrying[src] then return end
    if not isNear(src, item, kind == 'trunk' and config.trunkDistance or config.itemDistance) then return end
    return crew, item
end

local function beingCut(item, src)
    return item.cutBy and item.cutBy ~= src and (item.cutUntil or 0) >= os.time()
end

lib.callback.register('f_lumberjack:server:reserveBuck', function(src, id)
    local crew, item = ownItem(src, id, 'trunk')
    if not crew then return { ok = false } end
    if #crew.members > 1 then return { ok = false, msg = 'Kru angkat batangnya berdua ke truk, tidak perlu dipotong.' } end
    local ok, msg = canSaw(src)
    if not ok then return { ok = false, msg = msg } end
    if beingCut(item, src) then return { ok = false, msg = 'Batang ini sedang dipotong anggota lain.' } end
    if claimFresh(item) and (item.front or item.back) then return { ok = false, msg = 'Batang ini sedang diangkat.' } end
    item.cutBy, item.cutUntil, item.cutStart = src, os.time() + config.reserveSeconds, GetGameTimer()
    emitNear(vec3(item.x, item.y, item.z), 'f_lumberjack:client:sound', 'chainsaw', vec3(item.x, item.y, item.z))
    return { ok = true, seconds = config.buckSeconds }
end)

RegisterNetEvent('f_lumberjack:server:cancelBuck', function(id)
    local item = items[id]
    if item and item.cutBy == source then item.cutBy, item.cutUntil = nil, nil end
end)

lib.callback.register('f_lumberjack:server:buck', function(src, id)
    local crew, item = ownItem(src, id, 'trunk')
    if not crew or item.cutBy ~= src or #crew.members > 1 then return false end
    if GetGameTimer() - (item.cutStart or 0) < (config.buckSeconds - 1) * 1000 then return false end
    if not hasChainsaw(src) then return false end

    items[id] = nil
    TriggerClientEvent('f_lumberjack:client:itemsRemove', -1, { id })
    local rad = math.rad(item.h)
    local dx, dy = -math.sin(rad), math.cos(rad)
    if sharedConfig.piece.across then dx, dy = dy, -dx end     -- menyamping: tegak lurus arah batang
    local added, n = {}, sharedConfig.piecesPerTrunk
    for i = 1, n do
        local d = (i - (n + 1) / 2) * sharedConfig.piece.spacing
        local pid, piece = addItem(crew.id, 'piece', item.x + dx * d, item.y + dy * d, item.z, item.h)
        added[pid] = piece
    end
    broadcastAdd(added)
    return true
end)

-- role 'front' | 'back'; batang terangkat saat kedua ujung dipegang anggota kru
lib.callback.register('f_lumberjack:server:claimTrunk', function(src, id, role)
    if role ~= 'front' and role ~= 'back' then return { ok = false } end
    local crew, item = ownItem(src, id, 'trunk')
    if not crew then return { ok = false } end
    if #crew.members < 2 then return { ok = false, msg = 'Batang utuh hanya bisa diangkat berdua. Potong dulu batangnya.' } end
    if beingCut(item, src) then return { ok = false, msg = 'Batang ini sedang dipotong.' } end
    if not claimFresh(item) then item.front, item.back = nil, nil end
    if item[role] and item[role] ~= src then return { ok = false, msg = 'Ujung itu sudah dipegang anggota lain.' } end

    clearClaims(src)
    item[role], item.claimAt = src, os.time()
    local other = role == 'front' and item.back or item.front
    if other and (crewOf[other] ~= crew.id or carrying[other] or not isNear(other, item, config.trunkDistance + 2.0)) then
        if role == 'front' then item.back = nil else item.front = nil end
        other = nil
    end
    if not other then
        broadcastClaim(id, item)
        return { ok = true, waiting = true }
    end

    items[id] = nil
    item.front, item.back, item.claimAt = nil, nil, nil
    TriggerClientEvent('f_lumberjack:client:itemsRemove', -1, { id })
    local front, back = role == 'front' and src or other, role == 'back' and src or other
    startCarry(front, id, item, 'front', back)
    startCarry(back, id, item, 'back', front)
    return { ok = true }
end)

RegisterNetEvent('f_lumberjack:server:unclaim', function()
    clearClaims(source)
end)

lib.callback.register('f_lumberjack:server:takePiece', function(src, id)
    local crew, item = ownItem(src, id, 'piece')
    if not crew then return false end
    items[id] = nil
    TriggerClientEvent('f_lumberjack:client:itemsRemove', -1, { id })
    startCarry(src, id, item, 'piece')
    return true
end)

RegisterNetEvent('f_lumberjack:server:drop', function()
    local src = source
    if carrying[src] then
        dropCarry(src)
        local crew = getCrew(src)
        if crew then sync(crew) end
    end
end)

-- kayu yang dipanggul masuk ke bak (batang: oleh pemain depan, butuh 3 slot)
lib.callback.register('f_lumberjack:server:load', function(src)
    local c = carrying[src]
    local crew = getCrew(src)
    if not c or not crew or crew.phase ~= 'work' or c.role == 'back' or not truckValid(crew) then return { ok = false } end
    if crew.unloading then return { ok = false, msg = 'Bak sedang dibongkar.' } end
    if (crew.cargo or 0) > 0 then return { ok = false, msg = 'Truk masih membawa papan. Bongkar dulu di markas Paleto.' } end
    if GetGameTimer() - c.since < config.minCarryMs then return { ok = false } end
    if not behindTruck(crew, src) then return { ok = false, msg = 'Berdiri di belakang bak truk.' } end
    if c.role == 'front' then
        local p = c.partner and carrying[c.partner]
        if not p or p.id ~= c.id then return { ok = false } end
    end
    local n = units(c.item)
    if crew.bed + n > crew.cap then
        return { ok = false, msg = crew.bed < crew.cap and 'Bak tidak cukup untuk batang besar.' or 'Bak truk sudah penuh.' }
    end
    endCarry(src)
    if c.partner then endCarry(c.partner) end
    crew.bed += n
    if c.item.kind == 'trunk' then crew.trunks = (crew.trunks or 0) + 1 end
    sync(crew)
    return { ok = true, bed = crew.bed }
end)

---------------------------------------------------------------------------
-- sawmill
---------------------------------------------------------------------------
lib.callback.register('f_lumberjack:server:process', function(src, index)
    local crew = getCrew(src)
    local station = sharedConfig.stations[index]
    if not crew or crew.phase ~= 'work' or not station or not isDriver(src, crew) then return { ok = false } end
    if crew.unloading then return { ok = false, msg = 'Bak sedang dibongkar.' } end
    if crew.bed < 1 then return { ok = false, msg = 'Bak truk masih kosong.' } end
    if #(GetEntityCoords(crew.vehicle) - station.xyz) > config.stationDistance then return { ok = false, msg = 'Parkir truk di stasiun olah.' } end
    local now = GetGameTimer()
    if (stationBusy[index] or 0) > now then return { ok = false, msg = 'Stasiun ini sedang dipakai, coba stasiun sebelah.' } end

    -- urutan masuk conveyor: potongan (di atas tumpukan) dulu, lalu batang besar; 1 batang = 1 prop hilang dari bak
    local trunks = crew.trunks or 0
    local seq = {}
    for _ = 1, crew.bed - trunks * per do seq[#seq + 1] = 'piece' end
    for _ = 1, trunks do seq[#seq + 1] = 'trunk' end
    local count = crew.bed
    local bonus = sharedConfig.crewBonus[#crew.members] or 0
    local total = math.floor(count * sharedConfig.papanPerPiece * (1 + bonus / 100))
    local step = config.unloadMsPerLog
    stationBusy[index] = now + #seq * step + 2000
    crew.unloading = true
    sync(crew)
    emitNear(station.xyz, 'f_lumberjack:client:sawmill', seq, step)

    CreateThread(function()
        for _, kind in ipairs(seq) do
            if crews[crew.id] ~= crew then break end
            if kind == 'trunk' then
                crew.trunks -= 1
                crew.bed -= per
            else
                crew.bed -= 1
            end
            setTruckState(crew)
            Wait(step)
        end
        if crews[crew.id] == crew then
            crew.bed, crew.trunks, crew.unloading = 0, 0, false
            sync(crew)
            notifyCrew(crew, 'Bak kosong, truk boleh jalan. Papan muncul di ujung conveyor sebentar lagi.', 'inform')
        end
        -- batang terakhir sampai di ujung conveyor -> tumpukan papan
        Wait(sharedConfig.conveyorMs)
        if crews[crew.id] == crew and crew.phase == 'work' then
            crew.output = (crew.output or 0) + total
            sync(crew)
            notifyCrew(crew, ('%s papan siap di tumpukan papan sawmill. Pindahkan ke truk lalu bawa ke markas Paleto.'):format(total), 'success')
        else
            -- kru bubar / sudah selesai kerja: papan langsung ke gudang anggota
            local members = crews[crew.id] == crew and memberList(crew) or crew.endedMembers
            splitPapan(total, members or {}, crew.endedLeader or crew.leader)
        end
    end)
    return { ok = true, count = count, total = total }
end)

-- tumpukan papan di sawmill pindah ke bak truk (tampilan), bak harus kosong dari kayu
lib.callback.register('f_lumberjack:server:movePlanks', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'work' then return { ok = false } end
    local at = sharedConfig.plankOutput.coords
    if not isNear(src, at, config.pileDistance) then return { ok = false } end
    if (crew.output or 0) <= 0 then
        return { ok = false, msg = crew.unloading and 'Kayumu masih diolah, tunggu sebentar.' or 'Tidak ada kayu yang diolah.' }
    end
    if not truckValid(crew) then return { ok = false } end
    if crew.bed > 0 then return { ok = false, msg = 'Bak masih berisi kayu, olah dulu kayunya.' } end
    if #(GetEntityCoords(crew.vehicle) - at) > config.pileTruckDistance then
        return { ok = false, msg = 'Dekatkan truk ke tumpukan papan.' }
    end
    crew.cargo = (crew.cargo or 0) + crew.output
    crew.output = 0
    sync(crew)
    return { ok = true, cargo = crew.cargo }
end)

-- bongkar papan di markas Paleto: dibagi sesuai % ketua ke Gudang Kayu tiap anggota
lib.callback.register('f_lumberjack:server:unloadPlanks', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'work' or (crew.cargo or 0) <= 0 or not truckValid(crew) then return { ok = false } end
    local truckAt = GetEntityCoords(crew.vehicle)
    if #(truckAt - sharedConfig.depot.coords) > config.depotDistance then
        return { ok = false, msg = 'Parkir truk di markas Mandor Paleto.' }
    end
    if not isNear(src, truckAt, 10.0) then return { ok = false } end
    local total = crew.cargo
    crew.cargo = 0
    splitPapan(total, memberList(crew), crew.leader)
    sync(crew)
    notifyCrew(crew, ('%s papan dibongkar ke Gudang Kayu.'):format(total), 'success')
    return { ok = true, total = total }
end)

lib.callback.register('f_lumberjack:server:finish', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'work' or not isDriver(src, crew) then return { ok = false } end
    if crew.unloading then return { ok = false, msg = 'Tunggu bak selesai dibongkar.' } end
    if #(GetEntityCoords(crew.vehicle) - sharedConfig.depot.coords) > config.depotDistance then
        return { ok = false, msg = 'Parkir truk di markas Mandor Paleto dulu.' }
    end
    stopWork(crew)
    crew.phase, crew.phaseAt = 'lobby', os.time()
    notifyCrew(crew, 'Kerja selesai. Bicara dengan Mandor untuk mulai lagi.', 'success')
    sync(crew)
    refreshMenus(crew)
    return { ok = true }
end)

---------------------------------------------------------------------------
-- admin: salin koordinat untuk kalibrasi titik markas
---------------------------------------------------------------------------
lib.addCommand('kayupos', { help = 'Salin koordinat posisimu (kalibrasi f_lumberjack)', restricted = 'group.admin' }, function(src)
    TriggerClientEvent('f_lumberjack:client:copyPos', src)
end)

-- sementara: uji Biff tanpa pasir + pilih prop potongan kayu
lib.addCommand('kayutes', {
    help = 'Uji truk & prop kayu (f_lumberjack)',
    params = { { name = 'truk', help = 'biff (default) / flatbed', optional = true } },
    restricted = 'group.admin',
}, function(src, args)
    TriggerClientEvent('f_lumberjack:client:kayutes', src, args.truk == 'flatbed' and 'flatbed' or 'biff')
end)

---------------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    invites[src] = nil
    for _, t in ipairs(trees) do
        if t.reservedBy == src then t.reservedBy = nil end
    end
    local crew = getCrew(src)
    if crew then removeMember(crew, src, 'Terputus dari server.') end
    -- not in a crew any more (shouldn't happen), still put the wood back down
    dropCarry(src)
    clearClaims(src)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, crew in pairs(crews) do
        -- papan yang belum dibongkar tetap masuk gudang anggota
        splitPapan(pendingPapan(crew), memberList(crew), crew.leader)
        deleteTruck(crew)
    end
end)

-- lost / abandoned trucks, stale crews and trunk claims, every 30 seconds
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for id, item in pairs(items) do
            if (item.front or item.back) and not claimFresh(item) then
                item.front, item.back = nil, nil
                broadcastClaim(id, item)
            end
        end
        for _, crew in pairs(crews) do
            if crew.phase == 'lobby' and now - crew.phaseAt > config.lobbyTimeout then
                endCrew(crew, 'Kru dibubarkan karena tidak segera mulai.')
            elseif crew.phase == 'work' then
                if not truckValid(crew) then
                    endCrew(crew, 'Truk hilang, kerja dibatalkan.')
                else
                    local truckCoords = GetEntityCoords(crew.vehicle)
                    local someoneNear = false
                    for _, src in ipairs(crew.members) do
                        local c = pedCoords(src)
                        if c and #(c - truckCoords) <= config.abandonDistance then
                            someoneNear = true
                            break
                        end
                    end
                    if someoneNear then
                        crew.awaySince = nil
                    elseif not crew.awaySince then
                        crew.awaySince = now
                        notifyCrew(crew, 'Truk ditinggal terlalu jauh! Kembali dalam 5 menit atau kerja batal.', 'error')
                    elseif now - crew.awaySince > config.abandonSeconds then
                        endCrew(crew, 'Truk ditinggal terlalu lama, kerja dibatalkan.')
                    end
                end
            end
        end
    end
end)
