local config = require 'config.server'
local sharedConfig = require 'config.shared'

local crews = {}      -- id -> crew
local crewOf = {}     -- source -> crew id
local invites = {}    -- target source -> { crew = id, expires = os.time() }
local nextCrewId = 0

local locations = sharedConfig.locations
local depot = sharedConfig.depot
local difficulties = {}
for _, d in ipairs(sharedConfig.difficulties) do difficulties[d.key] = d end

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

local function getCrew(src)
    local id = crewOf[src]
    return id and crews[id]
end

local function isMember(crew, src)
    for i = 1, #crew.members do
        if crew.members[i] == src then return i end
    end
end

local function vanValid(crew)
    return crew.vehicle and DoesEntityExist(crew.vehicle)
end

local function isDriver(src, crew)
    if not vanValid(crew) then return false end
    return GetPedInVehicleSeat(crew.vehicle, -1) == GetPlayerPed(src)
end

local function nearVan(src, crew)
    if not vanValid(crew) then return false end
    local c = pedCoords(src)
    return c ~= nil and #(c - GetEntityCoords(crew.vehicle)) <= config.vanDistance
end

local function stopCoords(crew, num)
    local index = crew.route and crew.route[num or crew.stopNum]
    return index and locations[index].coords
end

---------------------------------------------------------------------------
-- route & packages
---------------------------------------------------------------------------
local function shuffled(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function buildRoute(diff)
    local byZone = {}
    for index, loc in ipairs(locations) do
        byZone[loc.zone] = byZone[loc.zone] or {}
        table.insert(byZone[loc.zone], index)
    end

    local picked = {}
    for zone, count in pairs(diff.stops) do
        for _, index in ipairs(shuffled(byZone[zone] or {})) do
            if count <= 0 then break end
            picked[#picked + 1] = index
            count -= 1
        end
    end

    -- nearest neighbour from the depot: city first, Sandy / Paleto last
    local route, pos = {}, depot.coords
    while #picked > 0 do
        local best, bestDist = 1, math.huge
        for i, index in ipairs(picked) do
            local dist = #(pos - locations[index].coords)
            if dist < bestDist then best, bestDist = i, dist end
        end
        local index = table.remove(picked, best)
        route[#route + 1] = index
        pos = locations[index].coords
    end
    return route
end

-- grid of 4 per row behind the pile point, facing its heading
local function pileSpot(i)
    local p = depot.pile
    local h = math.rad(p.w)
    local rx, ry = math.cos(h), math.sin(h)
    local fx, fy = -math.sin(h), math.cos(h)
    local side, fwd = ((i - 1) % 4 - 1.5) * 1.1, ((i - 1) // 4) * 1.1
    return vec3(p.x + rx * side + fx * fwd, p.y + ry * side + fy * fwd, p.z)
end

-- one member drives, the rest deliver: every stop gets 1 small package per deliverer
-- (solo 1, 2 orang 1, 3 orang 2, 4 orang 3). A big stop swaps 2 small for 1 big carried
-- together (kru 2 orang: the driver gets out to help). Every stop pays packageWorth x members,
-- split over its packages by weight (big = 2), so pay per person stays the same at any crew size.
local function buildPackages(crew)
    local diff = difficulties[crew.difficulty]
    local members = #crew.members
    local deliverers = math.max(1, members - 1)
    local bigStops = {}
    if members >= 2 then
        local order = {}
        for i = 1, #crew.route do order[i] = i end
        order = shuffled(order)
        for i = 1, math.min(diff.big or 0, #order) do bigStops[order[i]] = true end
    end
    local stopWorth = config.packageWorth * members * crew.mult

    local list = {}
    for stop = 1, #crew.route do
        local big = bigStops[stop]
        local small = big and math.max(0, deliverers - 2) or deliverers
        local weight = (big and 2 or 0) + small
        local function add(isBig)
            list[#list + 1] = {
                stop = stop,
                big = isBig or nil,
                sign = math.random() < config.signChance or nil,
                worth = math.floor(stopWorth * (isBig and 2 or 1) / weight),
                state = 'ground', -- ground (pile / dropped) -> held -> van -> done
            }
        end
        if big then add(true) end
        for _ = 1, small do add(false) end
    end
    for i, pkg in ipairs(list) do pkg.pos = pileSpot(i) end
    return list
end

---------------------------------------------------------------------------
-- sync
---------------------------------------------------------------------------
local function payload(crew)
    local members = {}
    for i, src in ipairs(crew.members) do
        members[i] = { id = src, name = crew.names[src], delivered = crew.delivered[src] or 0 }
    end
    local packages
    if crew.packages then
        packages = {}
        for i, p in ipairs(crew.packages) do
            packages[i] = { stop = p.stop, big = p.big, sign = p.sign, state = p.state, pos = p.pos, front = p.front, back = p.back }
        end
    end
    local data = {
        id = crew.id,
        leader = crew.leader,
        phase = crew.phase,
        atDepot = crew.atDepot,
        difficulty = crew.difficulty,
        members = members,
        pool = crew.pool,
        share = math.floor(crew.pool / #crew.members),
        netId = crew.netId,
        stopNum = crew.stopNum,
        totalStops = crew.route and #crew.route or 0,
        packages = packages,
    }
    if crew.phase == 'route' then
        local loc = locations[crew.route[crew.stopNum]]
        data.stop = { index = crew.route[crew.stopNum], label = loc.label, coords = loc.coords }
    end
    return data
end

local function sync(crew)
    local data = payload(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_courierjob:client:sync', src, data)
    end
end

local function notifyCrew(crew, msg, typ)
    for _, src in ipairs(crew.members) do notify(src, msg, typ) end
end

local function refreshMenus(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_courierjob:client:menuRefresh', src)
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
        pool = 0,   -- team pay, split equally at the end of every route
        delivered = {},
        carrying = {},
        phase = 'lobby',
        phaseAt = os.time(),
    }
    crews[crew.id] = crew
    crewOf[leader] = crew.id
    return crew
end

local function payAmount(src, amount)
    if amount <= 0 then return end
    local player = getPlayer(src)
    if not player then
        lib.print.warn(('[f_courierjob] %s offline, gaji %s hangus'):format(src, amount))
        return
    end
    player.Functions.AddMoney('bank', amount, 'courier-payslip')
    notify(src, ('Gaji kurir paket %s (bagian rata dari kru) masuk ke rekening bank.'):format(rupiah(amount)), 'success')
end

local function payout(crew)
    local share = math.floor(crew.pool / #crew.members)
    crew.pool = 0
    for _, src in ipairs(crew.members) do payAmount(src, share) end
end

local function deleteVan(crew)
    if vanValid(crew) then DeleteEntity(crew.vehicle) end
    crew.vehicle, crew.netId = nil, nil
end

-- a package in someone's hands goes down where they stand; a lift still waiting for a partner is cancelled
local function releaseCarry(crew, src)
    local index = crew.carrying[src]
    if not index then return end
    local pkg = crew.packages and crew.packages[index]
    crew.carrying[src] = nil
    if not pkg then return end
    if pkg.state == 'held' then
        pkg.state = 'ground'
        pkg.pos = (pkg.front and pedCoords(pkg.front)) or pedCoords(src) or pkg.pos
    end
    for _, carrier in ipairs({ pkg.front, pkg.back }) do crew.carrying[carrier] = nil end
    pkg.front, pkg.back = nil, nil
end

local function endCrew(crew, reason)
    if not crews[crew.id] then return end
    payout(crew)
    for _, src in ipairs(crew.members) do
        crewOf[src] = nil
        TriggerClientEvent('f_courierjob:client:ended', src, reason)
    end
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    deleteVan(crew)
    crews[crew.id] = nil
end

local function removeMember(crew, src, reason)
    local index = isMember(crew, src)
    if not index then return end

    if #crew.members == 1 then
        return endCrew(crew, reason)
    end

    releaseCarry(crew, src)
    -- leaving early takes the equal share earned so far, the rest stays with the crew
    local share = math.floor(crew.pool / #crew.members)
    crew.pool -= share
    payAmount(src, share)
    if vanValid(crew) then exports.f_vehiclekeys:RemoveKeys(src, crew.vehicle, true) end
    table.remove(crew.members, index)
    crewOf[src] = nil
    TriggerClientEvent('f_courierjob:client:ended', src, reason)

    -- nobody left to carry the other end: big packages become normal ones
    if #crew.members == 1 and crew.packages then
        for _, p in ipairs(crew.packages) do
            if p.big and p.state ~= 'done' then
                if p.front and p.state ~= 'held' then crew.carrying[p.front] = nil end
                p.big, p.front = nil, p.state == 'held' and p.front or nil
            end
        end
    end

    if crew.leader == src then
        crew.leader = crew.members[1]
        notifyCrew(crew, ('%s keluar, %s sekarang menjadi ketua kru.'):format(crew.names[src] or 'Ketua', crew.names[crew.leader]), 'inform')
    else
        notifyCrew(crew, ('%s keluar dari kru.'):format(crew.names[src] or 'Anggota'), 'inform')
    end
    sync(crew)
    refreshMenus(crew)
end

local function startLoading(crew)
    crew.packages = buildPackages(crew)
    crew.carrying = {}
    crew.stopNum = 1
    crew.atDepot = nil
    crew.phase, crew.phaseAt = 'load', os.time()
    for _, member in ipairs(crew.members) do
        exports.f_vehiclekeys:GiveKeys(member, crew.vehicle, true)
    end
end

---------------------------------------------------------------------------
-- menu (job centre, and the depot after a finished route)
---------------------------------------------------------------------------
-- side job for jobless citizens only: police / EMS / other workers already earn a paycheck
local NOT_UNEMPLOYED = 'Kurir paket hanya untuk warga yang belum punya pekerjaan.'

local function isUnemployed(src)
    local player = getPlayer(src)
    return player ~= nil and player.PlayerData.job.name == 'unemployed'
end

local function atMenu(src)
    if isNear(src, sharedConfig.jobCentre, sharedConfig.jobCentreDistance) then return true end
    local crew = getCrew(src)
    return crew ~= nil and crew.atDepot == true and isNear(src, depot.coords, config.menuDistance)
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

    local diffs = {}
    for i, d in ipairs(sharedConfig.difficulties) do
        local total = 0
        for _, n in pairs(d.stops) do total += n end
        diffs[i] = { key = d.key, label = d.label, desc = d.desc, stops = total, bonus = d.bonus }
    end

    return {
        me = src,
        maxCrew = sharedConfig.maxCrew,
        difficulties = diffs,
        crew = crew and payload(crew) or nil,
        nearby = nearby,
        worth = { package = config.packageWorth, km = config.kmWorth },
    }
end

-- side job: the player's own job is never touched (no paycheck), only jobless players may work
lib.callback.register('f_courierjob:server:getMenu', function(src)
    if not atMenu(src) then return { err = 'Buka menu ini di loket Cari Pekerjaan balai kota.' } end
    if not isUnemployed(src) then return { err = NOT_UNEMPLOYED .. ' Berhenti dulu dari pekerjaanmu.' } end
    return menuData(src)
end)

lib.callback.register('f_courierjob:server:invite', function(src, target)
    target = tonumber(target)
    if not target or target == src or not atMenu(src) or not isUnemployed(src) then return { ok = false } end
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
    TriggerClientEvent('f_courierjob:client:invite', target, charName(src))
    return { ok = true, data = menuData(src) }
end)

lib.callback.register('f_courierjob:server:respond', function(src, accept)
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
    crewOf[src] = crew.id
    notifyCrew(crew, ('%s bergabung ke kru kurir.'):format(crew.names[src]), 'success')
    sync(crew)
    refreshMenus(crew)
    return true
end)

lib.callback.register('f_courierjob:server:kick', function(src, target)
    target = tonumber(target)
    local crew = getCrew(src)
    if not crew or crew.leader ~= src or crew.phase ~= 'lobby' or target == src then return false end
    if not target or not isMember(crew, target) then return false end
    removeMember(crew, target, 'Kamu dikeluarkan dari kru kurir oleh ketua.')
    return menuData(src)
end)

lib.callback.register('f_courierjob:server:start', function(src, diffKey)
    local diff = difficulties[diffKey]
    if not diff or not atMenu(src) then return { ok = false, msg = 'Tidak bisa memulai di sini.' } end
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then
        return { ok = false, msg = 'Hanya ketua kru yang bisa memulai.' }
    end
    if crew and crew.atDepot and not isNear(src, depot.coords, config.menuDistance) then
        return { ok = false, msg = 'Mulai rute berikutnya dari depot GoPostal.' }
    end
    if not isUnemployed(src) then return { ok = false, msg = NOT_UNEMPLOYED } end
    -- a member may have taken a job after joining the lobby
    for _, member in ipairs(crew and crew.members or {}) do
        if not isUnemployed(member) then
            return { ok = false, msg = ('%s sudah punya pekerjaan, keluarkan dulu dari kru.'):format(crew.names[member] or 'Anggota') }
        end
    end

    crew = crew or newCrew(src)
    crew.difficulty = diff.key
    crew.mult = 1 + (diff.bonus or 0) / 100
    crew.route = buildRoute(diff)
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end

    if crew.atDepot and vanValid(crew) then
        -- next route straight from the depot: same van, same crew
        startLoading(crew)
        notifyCrew(crew, ('Rute %s (%s titik). Muat semua paket dari tumpukan ke van.'):format(diff.label, #crew.route), 'success')
    else
        crew.atDepot = nil
        crew.phase, crew.phaseAt = 'depot', os.time()
        notifyCrew(crew, ('Kerja kurir %s dimulai (%s titik). Ambil van di depot GoPostal, lokasi ditandai di GPS.'):format(diff.label, #crew.route), 'success')
    end
    sync(crew)
    return { ok = true }
end)

lib.callback.register('f_courierjob:server:leave', function(src)
    local crew = getCrew(src)
    if not crew then return false end
    if crew.leader == src and crew.phase == 'lobby' then
        endCrew(crew, crew.atDepot and 'Kerja kurir selesai, terima kasih!' or 'Kru dibubarkan.')
    elseif crew.leader == src then
        endCrew(crew, 'Ketua membatalkan kerja kurir.')
    else
        removeMember(crew, src, 'Kamu keluar dari kru kurir.')
    end
    return true
end)

---------------------------------------------------------------------------
-- work
---------------------------------------------------------------------------
local function vehicleNear(coords, radius)
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - coords) <= radius then return true end
    end
    return false
end

lib.callback.register('f_courierjob:server:spawnVan', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'depot' or vanValid(crew) then return false end
    if not isNear(src, depot.coords, config.spawnDistance) then return false end

    local spot
    for _, s in ipairs(depot.vanSpawns) do
        if not vehicleNear(s.xyz, 3.0) then
            spot = s
            break
        end
    end
    if not spot then
        notify(src, 'Semua tempat parkir van sedang terisi, kosongkan dulu.', 'error')
        return false
    end

    local veh = CreateVehicleServerSetter(joaat(config.vehicle), 'automobile', spot.x, spot.y, spot.z, spot.w)
    local ok = pcall(lib.waitFor, function()
        if DoesEntityExist(veh) and GetVehicleNumberPlateText(veh) ~= '' then return true end
    end, nil, 5000)
    if not ok then
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        notify(src, 'Gagal memunculkan van, coba lagi.', 'error')
        return false
    end

    SetVehicleNumberPlateText(veh, ('%s %04d'):format(config.platePrefix, math.random(0, 9999)))
    Entity(veh).state:set('fuel', 100.0, true)
    crew.vehicle, crew.netId = veh, NetworkGetNetworkIdFromEntity(veh)
    exports.f_vehiclekeys:SetLockState(veh, 'unlock')

    startLoading(crew)
    notifyCrew(crew, 'Van siap! Muat semua paket dari tumpukan ke pintu belakang van.', 'success')
    sync(crew)
    return true
end)

-- pick up a package: from the pile / ground, or from the van at the current stop.
-- Big packages need two: the first lifts the front (and walks), the partner lifts the back.
lib.callback.register('f_courierjob:server:lift', function(src, index)
    local crew = getCrew(src)
    if not crew or (crew.phase ~= 'load' and crew.phase ~= 'route') or not crew.packages then return { ok = false } end
    local pkg = crew.packages[index]
    if not pkg or pkg.state == 'held' or pkg.state == 'done' then return { ok = false, msg = 'Paket itu sudah diangkat.' } end
    local current = crew.carrying[src]
    if current and current ~= index then return { ok = false, msg = 'Tanganmu masih penuh.' } end

    if pkg.state == 'ground' then
        if not isNear(src, pkg.pos, config.groundDistance) then return { ok = false } end
    elseif pkg.state == 'van' then
        if crew.phase ~= 'route' or pkg.stop ~= crew.stopNum then return { ok = false, msg = 'Paket itu bukan untuk titik ini.' } end
        if not nearVan(src, crew) then return { ok = false } end
        if #(GetEntityCoords(crew.vehicle) - stopCoords(crew)) > config.vanStopDistance then
            return { ok = false, msg = 'Parkir van lebih dekat ke titik antar.' }
        end
    end

    if not pkg.big then
        pkg.state, pkg.front, pkg.from, pkg.at = 'held', src, pkg.state, os.time()
        crew.carrying[src] = index
    elseif not pkg.front then
        pkg.front = src
        crew.carrying[src] = index
        sync(crew)
        return { ok = true, wait = true }
    elseif pkg.front == src then
        return { ok = true, wait = true }
    else
        local frontCoords, myCoords = pedCoords(pkg.front), pedCoords(src)
        if not frontCoords or not myCoords or #(frontCoords - myCoords) > config.partnerDistance then
            return { ok = false, msg = 'Dekati rekanmu yang mengangkat bagian depan.' }
        end
        pkg.back, pkg.state, pkg.from, pkg.at = src, 'held', pkg.state, os.time()
        crew.carrying[src] = index
    end
    sync(crew)
    return { ok = true }
end)

lib.callback.register('f_courierjob:server:cancelLift', function(src)
    local crew = getCrew(src)
    local index = crew and crew.carrying[src]
    local pkg = index and crew.packages and crew.packages[index]
    if not pkg or pkg.state == 'held' or pkg.front ~= src then return false end
    pkg.front = nil
    crew.carrying[src] = nil
    sync(crew)
    return true
end)

lib.callback.register('f_courierjob:server:drop', function(src)
    local crew = getCrew(src)
    local index = crew and crew.carrying[src]
    local pkg = index and crew.packages and crew.packages[index]
    if not pkg or pkg.state ~= 'held' then return false end
    releaseCarry(crew, src)
    sync(crew)
    return true
end)

-- put the held package into the van (loading at the depot, or back in during the route)
lib.callback.register('f_courierjob:server:load', function(src)
    local crew = getCrew(src)
    local index = crew and crew.carrying[src]
    local pkg = index and crew.packages and crew.packages[index]
    if not pkg or pkg.state ~= 'held' or pkg.front ~= src then return false end
    if os.time() - pkg.at < config.minCarrySeconds then return false end
    if not nearVan(src, crew) or (pkg.back and not nearVan(pkg.back, crew)) then
        return false, 'Dekati pintu belakang van.'
    end

    crew.carrying[src] = nil
    if pkg.back then crew.carrying[pkg.back] = nil end
    pkg.state, pkg.front, pkg.back, pkg.pos = 'van', nil, nil, nil

    if crew.phase == 'load' then
        local loaded = 0
        for _, p in ipairs(crew.packages) do
            if p.state == 'van' then loaded += 1 end
        end
        if loaded == #crew.packages then
            crew.phase, crew.phaseAt = 'route', os.time()
            notifyCrew(crew, ('Semua paket dimuat! Titik 1/%s: %s'):format(#crew.route, locations[crew.route[1]].label), 'success')
        end
    end
    sync(crew)
    return true
end)

local function kmPay(crew, from, to)
    return #(from - to) / 1000 * config.kmWorth * #crew.members * crew.mult
end

lib.callback.register('f_courierjob:server:deliver', function(src)
    local crew = getCrew(src)
    local index = crew and crew.carrying[src]
    local pkg = index and crew.packages and crew.packages[index]
    if not pkg or crew.phase ~= 'route' or pkg.state ~= 'held' or pkg.front ~= src then return { ok = false } end
    if pkg.stop ~= crew.stopNum then return { ok = false, msg = 'Paket ini untuk titik lain.' } end
    local target = stopCoords(crew)
    if not isNear(src, target, config.deliverDistance) or (pkg.back and not isNear(pkg.back, target, config.deliverDistance)) then
        return { ok = false, msg = 'Bawa paket ke penerima.' }
    end
    if os.time() - pkg.at < (pkg.sign and config.signSeconds or config.minCarrySeconds) then return { ok = false } end

    crew.carrying[src] = nil
    if pkg.back then crew.carrying[pkg.back] = nil end
    for _, carrier in ipairs({ pkg.front, pkg.back }) do
        crew.delivered[carrier] = (crew.delivered[carrier] or 0) + 1
    end
    pkg.state, pkg.front, pkg.back = 'done', nil, nil

    local worth = pkg.worth
    crew.pool += worth

    for _, p in ipairs(crew.packages) do
        if p.stop == crew.stopNum and p.state ~= 'done' then
            sync(crew)
            return { ok = true, worth = worth }
        end
    end

    -- stop finished: distance pay from the previous stop (or the depot)
    local from = crew.stopNum > 1 and stopCoords(crew, crew.stopNum - 1) or depot.coords
    crew.pool += math.floor(kmPay(crew, from, target))
    if crew.stopNum < #crew.route then
        crew.stopNum += 1
        notifyCrew(crew, ('Titik selesai! Lanjut ke titik %s/%s: %s'):format(crew.stopNum, #crew.route, locations[crew.route[crew.stopNum]].label), 'success')
    else
        crew.phase, crew.phaseAt = 'return', os.time()
        notifyCrew(crew, 'Semua paket terkirim! Bawa van kembali ke depot GoPostal.', 'success')
    end
    sync(crew)
    return { ok = true, worth = worth }
end)

lib.callback.register('f_courierjob:server:finish', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'return' or not isDriver(src, crew) then return false end
    if #(GetEntityCoords(crew.vehicle) - depot.coords) > config.depotDistance then return false end

    crew.pool += math.floor(kmPay(crew, stopCoords(crew, #crew.route), depot.coords))
    payout(crew)
    crew.phase, crew.phaseAt, crew.atDepot = 'lobby', os.time(), true
    crew.packages, crew.carrying = nil, {}
    notifyCrew(crew, 'Rute selesai! Pilih rute berikutnya di menu, atau selesai kerja.', 'success')
    sync(crew)
    for _, member in ipairs(crew.members) do
        TriggerClientEvent('f_courierjob:client:routeDone', member)
    end
    return true
end)

-- destroyed / sunk van, reported by a crew member's client: the job is over
lib.callback.register('f_courierjob:server:vanLost', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase == 'lobby' or crew.phase == 'depot' then return false end
    endCrew(crew, 'Van rusak, kerja kurir dibatalkan. Ambil kerja lagi di balai kota.')
    return true
end)

---------------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    invites[src] = nil
    local crew = getCrew(src)
    if crew then removeMember(crew, src, 'Terputus dari server.') end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, crew in pairs(crews) do deleteVan(crew) end
end)

-- abandoned / lost vans and stale crews, every 30 seconds
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, crew in pairs(crews) do
            if crew.phase == 'lobby' then
                if crew.atDepot and now - crew.phaseAt > config.depotLobbyTimeout then
                    endCrew(crew, 'Kerja kurir selesai, terima kasih!')
                elseif not crew.atDepot and now - crew.phaseAt > config.lobbyTimeout then
                    endCrew(crew, 'Kru dibubarkan karena tidak segera mulai.')
                end
            elseif crew.phase == 'depot' then
                if now - crew.phaseAt > config.depotTimeout then endCrew(crew, 'Van tidak diambil, kerja kurir dibatalkan.') end
            elseif not vanValid(crew) then
                endCrew(crew, 'Van kurir hilang, kerja dibatalkan.')
            else
                local vanCoords = GetEntityCoords(crew.vehicle)
                local someoneNear = false
                for _, src in ipairs(crew.members) do
                    local c = pedCoords(src)
                    if c and #(c - vanCoords) <= config.abandonDistance then
                        someoneNear = true
                        break
                    end
                end
                if someoneNear then
                    crew.awaySince = nil
                elseif not crew.awaySince then
                    crew.awaySince = now
                    notifyCrew(crew, 'Van kurir ditinggal terlalu jauh! Kembali dalam 5 menit atau kerja batal.', 'error')
                elseif now - crew.awaySince > config.abandonSeconds then
                    endCrew(crew, 'Van ditinggal terlalu lama, kerja kurir dibatalkan.')
                end
            end
        end
    end
end)
