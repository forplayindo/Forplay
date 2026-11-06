-- Derek: flatbed (tow & mekanik) + job Derek dengan misi NPC. Semua keputusan di server:
-- statebag f_towed di flatbed, kendaraan misi, jumlah antaran, deposit truk, gaji.
local cfg = require 'config.shared'
local tow = require 'config.tow'

local FLATBED = {}
for _, model in ipairs(tow.flatbeds) do FLATBED[joaat(model)] = true end

local deposits = {} ---@type table<string, number> citizenid -> deposit truk yang ditahan
local trucks = {}   ---@type table<string, number> citizenid -> entity flatbed derek
local missions = {} ---@type table<number, { spot: integer?, veh: number?, done: integer }> per source

local function rp(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1.'):reverse()
    return 'Rp ' .. s:gsub('^%.', '')
end

local function getJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    return player and player.PlayerData.job, player
end

local function canTow(src)
    local job = getJob(src)
    return job and job.onduty and (job.name == tow.job or job.type == cfg.jobType)
end

local function isTowJob(src)
    local job, player = getJob(src)
    return job and job.name == tow.job and job.onduty, player
end

local function near(src, point, dist)
    return #(GetEntityCoords(GetPlayerPed(src)) - point.xyz) <= dist
end

local function deleteIfExists(entity)
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function nextSpot(last)
    local idx
    repeat idx = math.random(1, #tow.spots) until idx ~= last or #tow.spots == 1
    return idx
end

-- Naik / turunkan kendaraan di bak flatbed --------------------------------------------------

lib.callback.register('f_mechanicjob:tow:set', function(src, flatNet, targetNet)
    if not canTow(src) then return false end

    local flatbed = NetworkGetEntityFromNetworkId(tonumber(flatNet) or 0)
    if flatbed == 0 or not DoesEntityExist(flatbed) or not FLATBED[GetEntityModel(flatbed)] then return false end

    local flatCoords = GetEntityCoords(flatbed)
    if not near(src, flatCoords, 10.0) then return false end

    local state = Entity(flatbed).state
    if not targetNet then
        state:set('f_towed', nil, true)
        return true
    end

    local current = state.f_towed
    if current and DoesEntityExist(NetworkGetEntityFromNetworkId(current)) then return false end

    local target = NetworkGetEntityFromNetworkId(tonumber(targetNet) or 0)
    if target == 0 or target == flatbed or not DoesEntityExist(target) or GetEntityType(target) ~= 2 then return false end
    if GetPedInVehicleSeat(target, -1) ~= 0 then return false end
    if #(GetEntityCoords(target) - flatCoords) > 14.0 then return false end

    state:set('f_towed', targetNet, true)
    return true
end)

-- Job Derek: flatbed dengan deposit --------------------------------------------------------

lib.callback.register('f_mechanicjob:tow:takeTruck', function(src)
    local ok, player = isTowJob(src)
    if not ok then return { error = 'Hanya job Derek yang sedang bertugas' } end
    if not near(src, tow.truck.coords, 5.0) then return { error = 'Kamu terlalu jauh' } end

    local cid = player.PlayerData.citizenid
    if trucks[cid] and DoesEntityExist(trucks[cid]) then return { error = 'Kembalikan dulu flatbed yang kamu pakai' } end

    local spawn = tow.truck.coords
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - spawn.xyz) < 3.0 then return { error = 'Tempat keluar kendaraan masih terhalang' } end
    end

    -- deposit hanya ditarik sekali; truk yang hilang (dihapus kota) boleh diambil lagi tanpa bayar
    local paid
    if not deposits[cid] then
        local price = tow.truck.deposit
        local method = player.PlayerData.money.cash >= price and 'cash' or player.PlayerData.money.bank >= price and 'bank'
        if not method then return { error = ('Butuh deposit %s'):format(rp(price)) } end
        if not player.Functions.RemoveMoney(method, price, 'tow-deposit') then return { error = 'Pembayaran deposit gagal' } end
        deposits[cid] = price
        paid = ('Deposit %s dibayar %s'):format(rp(price), method == 'cash' and 'tunai' or 'dari bank')
    end

    local netId, veh = qbx.spawnVehicle({ model = joaat(tow.truck.model), spawnSource = spawn, warp = GetPlayerPed(src) })
    if not netId then return { error = 'Kendaraan gagal dimunculkan' } end
    local plate = ('TOWR%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('f_mech:towTruck', cid, true)
    trucks[cid] = veh
    TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
    return { net = netId, message = paid }
end)

lib.callback.register('f_mechanicjob:tow:returnTruck', function(src, netId)
    local job, player = getJob(src)
    if not job or job.name ~= tow.job then return { error = 'Hanya job Derek' } end

    local cid = player.PlayerData.citizenid
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or veh ~= trucks[cid] or not DoesEntityExist(veh) then return { error = 'Ini bukan flatbed milikmu' } end
    if #(GetEntityCoords(veh) - tow.truck.coords.xyz) > 20.0 then return { error = 'Bawa flatbed ke tempat pengambilan' } end
    local towed = Entity(veh).state.f_towed
    if towed and DoesEntityExist(NetworkGetEntityFromNetworkId(towed)) then return { error = 'Turunkan dulu kendaraan di bak' } end

    DeleteEntity(veh)
    trucks[cid] = nil
    local amount = deposits[cid]
    deposits[cid] = nil
    if amount then
        player.Functions.AddMoney('bank', amount, 'tow-deposit-refund')
        return { message = ('Deposit %s dikembalikan ke bank'):format(rp(amount)) }
    end
    return {}
end)

-- Job Derek: misi NPC -----------------------------------------------------------------------

---@return integer? spot nomor lokasi baru, nil = misi dimatikan
local function toggleMission(src)
    local m = missions[src]
    if m then
        if m.veh and DoesEntityExist(m.veh) and GetEntityAttachedTo(m.veh) == 0 then DeleteEntity(m.veh) end
        m.spot, m.veh = nil, nil
        if m.done == 0 then missions[src] = nil end
        return
    end
    missions[src] = { spot = nextSpot(), done = 0 }
    return missions[src].spot
end

lib.callback.register('f_mechanicjob:tow:toggleNpc', function(src)
    if not isTowJob(src) then return false, 'Hanya job Derek yang sedang bertugas' end
    local m = missions[src]
    if m and not m.spot then
        m.spot = nextSpot() -- masih ada antaran yang belum digaji: lanjutkan
        return m.spot
    end
    return toggleMission(src) or false
end)

lib.callback.register('f_mechanicjob:tow:spawnNpc', function(src)
    local m = missions[src]
    if not m or not m.spot or (m.veh and DoesEntityExist(m.veh)) then return end
    local spot = tow.spots[m.spot]
    if not near(src, spot.coords, 80.0) then return end

    local netId, veh = qbx.spawnVehicle({ model = joaat(spot.model), spawnSource = spot.coords })
    if not netId then return end
    m.veh = veh
    return netId
end)

lib.callback.register('f_mechanicjob:tow:deliver', function(src, netId)
    local m = missions[src]
    if not m or not m.veh or not isTowJob(src) then return end
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh ~= m.veh or not DoesEntityExist(veh) or GetEntityAttachedTo(veh) ~= 0 then return end
    if #(GetEntityCoords(veh) - tow.dropoff) > tow.dropoffRadius then return end

    DeleteEntity(veh)
    m.done += 1
    m.veh = nil
    m.spot = nextSpot(m.spot)
    return m.spot
end)

lib.callback.register('f_mechanicjob:tow:payslip', function(src)
    local ok, player = isTowJob(src)
    if not ok then return { error = 'Hanya job Derek yang sedang bertugas' } end
    if not near(src, tow.depot.coords, 6.0) then return { error = 'Kamu terlalu jauh' } end
    local m = missions[src]
    if not m or m.done < 1 then return { error = 'Kamu belum mengantar kendaraan apa pun' } end

    local drops = m.done
    local base = math.random(tow.pay.min, tow.pay.max)
    local bonus = drops > 5 and math.ceil((base / 10) * ((3 * (drops / 5)) + 2)) or 0
    local price = base * drops + bonus
    local payment = price - math.ceil(price / 100 * tow.pay.tax)

    deleteIfExists(m.veh)
    missions[src] = nil
    player.Functions.AddJobReputation(1)
    player.Functions.AddMoney('bank', payment, 'tow-salary')
    return { message = ('Kamu mendapat %s untuk %d kendaraan'):format(rp(payment), drops) }
end)

lib.addCommand('npc', { help = 'Nyalakan/matikan misi NPC job Derek' }, function(src)
    TriggerClientEvent('jobs:client:ToggleNpc', src)
end)

AddEventHandler('playerDropped', function()
    local m = missions[source]
    if m then deleteIfExists(m.veh) end
    missions[source] = nil
end)
