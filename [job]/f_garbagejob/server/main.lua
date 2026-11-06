local config = require 'config.server'
local sharedConfig = require 'config.shared'

local crews = {}      -- id -> crew
local crewOf = {}     -- source -> crew id
local invites = {}    -- target source -> { crew = id, expires = os.time() }
local nextCrewId = 0

local locations = sharedConfig.locations
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

local function truckValid(crew)
    return crew.vehicle and DoesEntityExist(crew.vehicle)
end

local function isDriver(src, crew)
    if not truckValid(crew) then return false end
    return GetPedInVehicleSeat(crew.vehicle, -1) == GetPlayerPed(src)
end

local function bagWorth(crew)
    return math.floor(math.random(config.bagLowerWorth, config.bagUpperWorth) * crew.mult)
end

---------------------------------------------------------------------------
-- route
---------------------------------------------------------------------------
local depotCoords = sharedConfig.depot.coords

local function shuffled(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function pickFrom(pool, count, used, out)
    for _, index in ipairs(shuffled(pool)) do
        if count <= 0 then break end
        if not used[index] then
            used[index] = true
            out[#out + 1] = index
            count -= 1
        end
    end
    return count
end

local function buildRoute(diff)
    local byZone, byRegion = {}, {}
    for index, loc in ipairs(locations) do
        byZone[loc.zone] = byZone[loc.zone] or {}
        table.insert(byZone[loc.zone], index)
        if loc.region then
            byRegion[loc.region] = byRegion[loc.region] or {}
            table.insert(byRegion[loc.region], index)
        end
    end

    local used, picked = {}, {}
    for zone, count in pairs(diff.stops) do
        if zone == 'jauh' then
            -- far stops come from one direction per shift, so the route never zigzags across the city
            local regions = {}
            for region, list in pairs(byRegion) do
                if #list >= count then regions[#regions + 1] = region end
            end
            local left = count
            if #regions > 0 then
                left = pickFrom(byRegion[regions[math.random(#regions)]], left, used, picked)
            end
            pickFrom(byZone.jauh or {}, left, used, picked)
        else
            pickFrom(byZone[zone] or {}, count, used, picked)
        end
    end

    -- nearest neighbour from the depot: near stops first, far ones last
    local route, pos = {}, depotCoords
    while #picked > 0 do
        local best, bestDist = 1, math.huge
        for i, index in ipairs(picked) do
            local dist = #(pos - locations[index].coords.xyz)
            if dist < bestDist then best, bestDist = i, dist end
        end
        local index = table.remove(picked, best)
        route[#route + 1] = index
        pos = locations[index].coords.xyz
    end
    return route
end

local function bagOffsets(loc, count)
    local list = {}
    local h = math.rad(loc.coords.w or 0.0)
    local rx, ry = math.cos(h), math.sin(h)    -- right vector
    local fx, fy = -math.sin(h), math.cos(h)   -- forward vector
    for i = 1, count do
        local side, fwd
        if loc.container then
            -- piles beside the dumpster, never inside it
            side = (i % 2 == 0 and 1 or -1) * (1.4 + math.random() * 1.4)
            fwd = math.random() * 1.2 - 0.2
        else
            local ang = math.random() * math.pi * 2
            local dist = 0.8 + math.random() * 1.6
            side, fwd = math.cos(ang) * dist, math.sin(ang) * dist
        end
        list[i] = {
            x = rx * side + fx * fwd,
            y = ry * side + fy * fwd,
            state = 0, -- 0 ground, 1 carried, 2 in truck
        }
    end
    return list
end

local function activateStop(crew)
    local index = crew.route[crew.stopNum]
    local loc = locations[index]
    local count = math.random(config.minBagsPerStop, config.maxBagsPerStop) + (#crew.members - 1) * config.extraBagsPerMember
    crew.stop = {
        index = index,
        bags = bagOffsets(loc, count),
        container = loc.container and 'idle' or nil,
    }
    crew.carrying = {}
end

---------------------------------------------------------------------------
-- sync
---------------------------------------------------------------------------
local function payload(crew)
    local members = {}
    for i, src in ipairs(crew.members) do
        members[i] = { id = src, name = crew.names[src], bags = crew.bags[src] or 0 }
    end
    local data = {
        id = crew.id,
        leader = crew.leader,
        phase = crew.phase,
        difficulty = crew.difficulty,
        members = members,
        pool = crew.pool,
        share = math.floor(crew.pool / #crew.members),
        netId = crew.netId,
        stopNum = crew.stopNum,
        totalStops = crew.route and #crew.route or 0,
    }
    if crew.phase == 'route' and crew.stop then
        local loc = locations[crew.stop.index]
        data.stop = {
            index = crew.stop.index,
            label = loc.label,
            coords = loc.coords,
            container = crew.stop.container,
            bags = crew.stop.bags,
        }
    end
    return data
end

local function sync(crew)
    local data = payload(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_garbagejob:client:sync', src, data)
    end
end

local function notifyCrew(crew, msg, typ)
    for _, src in ipairs(crew.members) do notify(src, msg, typ) end
end

local function refreshMenus(crew)
    for _, src in ipairs(crew.members) do
        TriggerClientEvent('f_garbagejob:client:menuRefresh', src)
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
        pool = 0,   -- team pay from every bag and container, split equally (drivers who never pick up a bag included)
        bags = {},
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
        lib.print.warn(('[f_garbagejob] %s offline, gaji %s hangus'):format(src, amount))
        return
    end
    player.Functions.AddMoney('bank', amount, 'garbage-payslip')
    notify(src, ('Gaji kerja sampah %s (bagian rata dari kru) masuk ke rekening bank.'):format(rupiah(amount)), 'success')
end

local function giveKeys(crew, src)
    if not truckValid(crew) then return end
    exports.f_vehiclekeys:GiveKeys(src, crew.vehicle, true)
end

local function deleteTruck(crew)
    if truckValid(crew) then DeleteEntity(crew.vehicle) end
    crew.vehicle, crew.netId = nil, nil
end

local function endCrew(crew, reason)
    if not crews[crew.id] then return end
    -- the team pool is split equally, drivers who never picked up a bag included
    local share = math.floor(crew.pool / #crew.members)
    crew.pool = 0
    for _, src in ipairs(crew.members) do
        payAmount(src, share)
        crewOf[src] = nil
        TriggerClientEvent('f_garbagejob:client:ended', src, reason)
    end
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end
    deleteTruck(crew)
    crews[crew.id] = nil
end

local function checkStop(crew)
    local stop = crew.stop
    if not stop then return end
    for _, bag in ipairs(stop.bags) do
        if bag.state ~= 2 then return end
    end
    if stop.container and stop.container ~= 'done' then return end

    if crew.stopNum < #crew.route then
        crew.stopNum += 1
        activateStop(crew)
        notifyCrew(crew, ('Titik selesai! Lanjut ke titik %s/%s: %s'):format(crew.stopNum, #crew.route, locations[crew.stop.index].label), 'success')
    else
        crew.phase, crew.phaseAt, crew.stop = 'return', os.time(), nil
        notifyCrew(crew, 'Semua titik selesai! Bawa truk kembali ke depo.', 'success')
    end
end

local function removeMember(crew, src, reason)
    local index = isMember(crew, src)
    if not index then return end

    if #crew.members == 1 then
        return endCrew(crew, reason)
    end

    -- a bag in their hands goes back on the ground
    local carried = crew.carrying[src]
    if carried and crew.stop and crew.stop.bags[carried.bag] then
        crew.stop.bags[carried.bag].state = 0
    end
    crew.carrying[src] = nil

    -- leaving early takes the equal share earned so far, the rest stays with the crew
    local share = math.floor(crew.pool / #crew.members)
    crew.pool -= share
    payAmount(src, share)
    if truckValid(crew) then exports.f_vehiclekeys:RemoveKeys(src, crew.vehicle, true) end
    table.remove(crew.members, index)
    crewOf[src] = nil
    TriggerClientEvent('f_garbagejob:client:ended', src, reason)

    if crew.leader == src then
        crew.leader = crew.members[1]
        notifyCrew(crew, ('%s keluar, %s sekarang menjadi ketua kru.'):format(crew.names[src] or 'Ketua', crew.names[crew.leader]), 'inform')
    else
        notifyCrew(crew, ('%s keluar dari kru.'):format(crew.names[src] or 'Anggota'), 'inform')
    end
    sync(crew)
    refreshMenus(crew)
end

---------------------------------------------------------------------------
-- menu (job centre)
---------------------------------------------------------------------------
-- side job for jobless citizens only: police / EMS / other workers already earn a paycheck
local NOT_UNEMPLOYED = 'Kerja sampah hanya untuk warga yang belum punya pekerjaan.'

local function isUnemployed(src)
    local player = getPlayer(src)
    return player ~= nil and player.PlayerData.job.name == 'unemployed'
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
        bagWorth = { config.bagLowerWorth, config.bagUpperWorth },
    }
end

local function atJobCentre(src)
    return isNear(src, sharedConfig.jobCentre, sharedConfig.jobCentreDistance)
end

-- side job: the player's own job is never touched (no paycheck), only jobless players may work
lib.callback.register('f_garbagejob:server:getMenu', function(src)
    if not atJobCentre(src) then return { err = 'Buka menu ini di loket Cari Pekerjaan balai kota.' } end
    if not isUnemployed(src) then return { err = NOT_UNEMPLOYED .. ' Berhenti dulu dari pekerjaanmu.' } end
    return menuData(src)
end)

lib.callback.register('f_garbagejob:server:invite', function(src, target)
    target = tonumber(target)
    if not target or target == src or not atJobCentre(src) or not isUnemployed(src) then return { ok = false } end
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
    TriggerClientEvent('f_garbagejob:client:invite', target, charName(src))
    return { ok = true, data = menuData(src) }
end)

lib.callback.register('f_garbagejob:server:respond', function(src, accept)
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
    notifyCrew(crew, ('%s bergabung ke kru sampah.'):format(crew.names[src]), 'success')
    sync(crew)
    refreshMenus(crew)
    return true
end)

lib.callback.register('f_garbagejob:server:start', function(src, diffKey)
    local diff = difficulties[diffKey]
    if not diff or not atJobCentre(src) then return { ok = false, msg = 'Tidak bisa memulai di sini.' } end
    local crew = getCrew(src)
    if crew and (crew.leader ~= src or crew.phase ~= 'lobby') then
        return { ok = false, msg = 'Hanya ketua kru yang bisa memulai.' }
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
    crew.stopNum = 1
    crew.phase, crew.phaseAt = 'depot', os.time()
    for target, invite in pairs(invites) do
        if invite.crew == crew.id then invites[target] = nil end
    end

    notifyCrew(crew, ('Shift %s dimulai (%s titik). Ambil truk sampah di depo, lokasi ditandai di GPS.'):format(diff.label, #crew.route), 'success')
    sync(crew)
    return { ok = true }
end)

lib.callback.register('f_garbagejob:server:leave', function(src)
    local crew = getCrew(src)
    if not crew then return false end
    if crew.leader == src and crew.phase == 'lobby' then
        endCrew(crew, 'Kru dibubarkan.')
    elseif crew.leader == src then
        endCrew(crew, 'Ketua membatalkan shift.')
    else
        removeMember(crew, src, 'Kamu keluar dari kru sampah.')
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

lib.callback.register('f_garbagejob:server:spawnTruck', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'depot' or truckValid(crew) then return false end
    if not isNear(src, depotCoords, config.spawnDistance) then return false end

    local spot
    for _, s in ipairs(sharedConfig.depot.truckSpawns) do
        if not vehicleNear(s.xyz, 3.0) then
            spot = s
            break
        end
    end
    if not spot then
        notify(src, 'Semua tempat parkir truk sedang terisi, kosongkan dulu.', 'error')
        return false
    end

    -- master2 is not in qbx_core shared vehicles, so spawn it directly with a known type
    local veh = CreateVehicleServerSetter(joaat(config.vehicle), 'automobile', spot.x, spot.y, spot.z, spot.w)
    local ok = pcall(lib.waitFor, function()
        if DoesEntityExist(veh) and GetVehicleNumberPlateText(veh) ~= '' then return true end
    end, nil, 5000)
    if not ok then
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        notify(src, 'Gagal memunculkan truk, coba lagi.', 'error')
        return false
    end

    local plate = ('%s %04d'):format(config.platePrefix, math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('fuel', 100.0, true)

    crew.vehicle, crew.netId = veh, NetworkGetNetworkIdFromEntity(veh)
    for _, member in ipairs(crew.members) do giveKeys(crew, member) end
    exports.f_vehiclekeys:SetLockState(veh, 'unlock')

    crew.phase, crew.phaseAt = 'route', os.time()
    activateStop(crew)
    notifyCrew(crew, ('Truk siap! Titik 1/%s: %s'):format(#crew.route, locations[crew.stop.index].label), 'success')
    sync(crew)
    return true
end)

lib.callback.register('f_garbagejob:server:takeBag', function(src, bagIndex)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'route' or not crew.stop or crew.carrying[src] then return false end
    local bag = crew.stop.bags[bagIndex]
    if not bag or bag.state ~= 0 then return false end
    if not isNear(src, locations[crew.stop.index].coords, config.stopDistance) then return false end

    bag.state = 1
    crew.carrying[src] = { bag = bagIndex, at = os.time() }
    sync(crew)
    return true
end)

lib.callback.register('f_garbagejob:server:depositBag', function(src)
    local crew = getCrew(src)
    local carried = crew and crew.carrying[src]
    if not carried or not crew.stop or not truckValid(crew) then return false end
    if os.time() - carried.at < config.minCarrySeconds then return false end
    local coords = pedCoords(src)
    -- bags are thrown up into the hopper on top, from anywhere close around the truck
    if not coords or #(coords - GetEntityCoords(crew.vehicle)) > config.truckThrowDistance then
        notify(src, 'Dekati truk untuk melempar kantong.', 'error')
        return false
    end

    crew.carrying[src] = nil
    crew.stop.bags[carried.bag].state = 2
    local worth = bagWorth(crew)
    crew.pool += worth
    crew.bags[src] = (crew.bags[src] or 0) + 1
    checkStop(crew)
    sync(crew)
    return worth
end)

lib.callback.register('f_garbagejob:server:attachContainer', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'route' or not crew.stop or crew.stop.container ~= 'idle' then return false end
    if not isDriver(src, crew) then return false end
    local loc = locations[crew.stop.index]
    if #(GetEntityCoords(crew.vehicle) - loc.coords.xyz) > config.containerTruckDistance then return false end

    crew.stop.container = 'attached'
    crew.stop.attachedAt = os.time()
    sync(crew)
    return true
end)

lib.callback.register('f_garbagejob:server:detachContainer', function(src)
    local crew = getCrew(src)
    if not crew or not crew.stop or crew.stop.container ~= 'attached' then return false end
    if not isDriver(src, crew) then return false end
    crew.stop.container = 'idle'
    crew.stop.attachedAt = nil
    sync(crew)
    return true
end)

lib.callback.register('f_garbagejob:server:emptyContainer', function(src)
    local crew = getCrew(src)
    if not crew or not crew.stop or crew.stop.container ~= 'attached' then return false end
    if not isDriver(src, crew) then return false end
    if os.time() - (crew.stop.attachedAt or 0) < config.minEmptySeconds then return false end

    crew.stop.container = 'done'
    local worth = 0
    for _ = 1, config.containerWorthBags do worth += bagWorth(crew) end
    crew.pool += worth
    checkStop(crew)
    sync(crew)
    return worth
end)

lib.callback.register('f_garbagejob:server:finish', function(src)
    local crew = getCrew(src)
    if not crew or crew.phase ~= 'return' or not isDriver(src, crew) then return false end
    if #(GetEntityCoords(crew.vehicle) - depotCoords) > config.depotDistance then return false end
    endCrew(crew, 'Shift selesai, terima kasih sudah membersihkan kota!')
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
    for _, crew in pairs(crews) do deleteTruck(crew) end
end)

-- abandoned / lost trucks and stale crews, every 30 seconds
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for _, crew in pairs(crews) do
            if crew.phase == 'lobby' and now - crew.phaseAt > config.lobbyTimeout then
                endCrew(crew, 'Kru dibubarkan karena tidak segera mulai.')
            elseif crew.phase == 'depot' and now - crew.phaseAt > config.depotTimeout then
                endCrew(crew, 'Truk tidak diambil, shift dibatalkan.')
            elseif crew.phase == 'route' or crew.phase == 'return' then
                if not truckValid(crew) then
                    endCrew(crew, 'Truk sampah hilang, shift dibatalkan.')
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
                        notifyCrew(crew, 'Truk sampah ditinggal terlalu jauh! Kembali dalam 5 menit atau shift batal.', 'error')
                    elseif now - crew.awaySince > config.abandonSeconds then
                        endCrew(crew, 'Truk ditinggal terlalu lama, shift dibatalkan.')
                    end
                end
            end
        end
    end
end)
