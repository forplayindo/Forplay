-- Test drive: dunia terpisah per pemain (routing bucket), kendaraan dibuat server, kunci sementara,
-- waktu dihitung server. Selesai (waktu habis / turun / mati / keluar) → kendaraan dihapus,
-- pemain kembali ke depan NPC dealer di bucket asal.
local TD = Config.TestDrive

local function returnPoint()
    local c = Config.Ped.coords
    local r = math.rad(c.w)
    return vec4(c.x - math.sin(r) * 1.4, c.y + math.cos(r) * 1.4, c.z, (c.w + 180.0) % 360.0)
end
local RETURN = returnPoint()

local function finish(src, reason)
    local t = Dealer.testing[src]
    if not t then return end
    Dealer.testing[src] = nil

    if DoesEntityExist(t.veh) then DeleteEntity(t.veh) end
    if reason == 'dropped' then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    TriggerClientEvent('f_dealer:testFinished', src, t.model, reason)
    exports.qbx_core:SetPlayerBucket(src, t.prevBucket)
    SetEntityCoords(ped, RETURN.x, RETURN.y, RETURN.z, false, false, false, false)
    SetEntityHeading(ped, RETURN.w)
end

local function start(src, model)
    if Dealer.testing[src] then return false, 'Kamu sedang test drive' end
    if not Dealer.nearDealer(src) then return false, 'Kamu terlalu jauh dari dealer' end
    local ped = GetPlayerPed(src)
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'Turun dari kendaraan dulu' end

    local v = type(model) == 'string' and Dealer.shop[model]
    if not v then return false, 'Kendaraan tidak tersedia' end

    local prevBucket = GetPlayerRoutingBucket(src)
    local bucket = TD.bucketBase + src
    SetRoutingBucketPopulationEnabled(bucket, false)
    exports.qbx_core:SetPlayerBucket(src, bucket)
    SetEntityCoords(ped, TD.coords.x, TD.coords.y, TD.coords.z, false, false, false, false)

    local _, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = TD.coords,
        warp = ped,
        bucket = bucket,
        props = { plate = TD.plate, fuelLevel = 100.0 },
    })
    if not veh or veh == 0 then
        exports.qbx_core:SetPlayerBucket(src, prevBucket)
        SetEntityCoords(ped, RETURN.x, RETURN.y, RETURN.z, false, false, false, false)
        return false, 'Kendaraan test drive gagal dibuat'
    end

    Entity(veh).state:set('fuel', 100.0, true)
    exports.f_vehiclekeys:GiveKeys(src, veh, true) -- bukan milik pemain → kunci sementara

    local token = {}
    Dealer.testing[src] = { veh = veh, model = model, prevBucket = prevBucket, token = token }
    SetTimeout(TD.seconds * 1000, function()
        local t = Dealer.testing[src]
        if t and t.token == token then finish(src, 'time') end
    end)

    TriggerClientEvent('f_dealer:testStarted', src, model, TD.seconds, NetworkGetNetworkIdFromEntity(veh))
    return true
end

lib.callback.register('f_dealer:testStart', function(source, model)
    return Dealer.guard(source, start, model)
end)

-- Client melapor turun dari kendaraan / mati / tekan batal. Hanya bisa MENGAKHIRI, tidak bisa memperpanjang.
RegisterNetEvent('f_dealer:testEnd', function()
    finish(source, 'early')
end)

AddEventHandler('playerDropped', function()
    finish(source, 'dropped')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(Dealer.testing) do finish(src, 'stop') end
end)
