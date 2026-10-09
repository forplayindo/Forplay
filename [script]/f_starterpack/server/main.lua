-- Starterpack warga baru. Semua dicek dan dibuat di server:
--  * klaim dikunci per citizenid lewat INSERT IGNORE (tidak bisa dobel walau event di-spam)
--  * kendaraan dibuat server: plat f_vehicles, simpan lewat CreatePlayerVehicle, kunci fisik f_vehiclekeys
local busy = {}

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_starterpack (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        claimed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )]])

    -- pindahkan data klaim dari script lama (mk_starterpack)
    local old = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'tcd_starterpack'")
    if (tonumber(old) or 0) > 0 then
        MySQL.query.await('INSERT IGNORE INTO f_starterpack (citizenid) SELECT identifier FROM tcd_starterpack WHERE received = 1')
    end
end)

local function hasClaimed(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM f_starterpack WHERE citizenid = ?', { citizenid }) ~= nil
end

local function freeSpawn()
    local vehicles = GetAllVehicles()
    for _, spot in ipairs(Config.Vehicle.spawns) do
        local free = true
        for i = 1, #vehicles do
            if #(GetEntityCoords(vehicles[i]) - spot.xyz) < 3.0 then
                free = false
                break
            end
        end
        if free then return spot end
    end
end

local function giveVehicle(src, citizenid, spot)
    local v = Config.Vehicle
    local plate = exports.f_vehicles:GeneratePlate()
    local vehicleId, err = exports.f_vehicles:CreatePlayerVehicle({
        model = v.model,
        citizenid = citizenid,
        props = { plate = plate },
    })
    if not vehicleId then
        print(('^1[f_starterpack] gagal membuat kendaraan untuk %s: %s^7'):format(citizenid, tostring(err)))
        return
    end

    local ped = GetPlayerPed(src)
    local _, veh = qbx.spawnVehicle({
        model = v.model,
        spawnSource = spot,
        warp = v.warp and ped or nil,
        bucket = GetPlayerRoutingBucket(src),
        props = { plate = plate },
    })
    if not veh or veh == 0 then return end

    Entity(veh).state:set('vehicleid', vehicleId, true)
    Entity(veh).state:set('fuel', v.fuel, true)
    exports.f_vehiclekeys:GiveKeys(src, veh)
    exports.qbx_core:Notify(src, Config.Text.vehicle:format(plate), 'success', 7000)
end

local function claim(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local citizenid = player.PlayerData.citizenid
    local ped = GetPlayerPed(src)

    if #(GetEntityCoords(ped) - Config.Ped.coords.xyz) > Config.ClaimRadius then return false, Config.Text.too_far end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, Config.Text.in_vehicle end
    if hasClaimed(citizenid) then return false, Config.Text.already end

    local spot
    if Config.Vehicle.enabled then
        if not exports.qbx_core:GetVehiclesByName()[Config.Vehicle.model] then return false, Config.Text.bad_model end
        spot = freeSpawn()
        if not spot then return false, Config.Text.no_spawn end
    end

    -- kunci klaim dulu: baris citizenid hanya bisa dibuat sekali
    if MySQL.update.await('INSERT IGNORE INTO f_starterpack (citizenid) VALUES (?)', { citizenid }) ~= 1 then
        return false, Config.Text.already
    end

    for _, entry in ipairs(Config.Items) do
        local ok, response = exports.ox_inventory:AddItem(src, entry.item, entry.amount)
        if not ok then
            print(('^1[f_starterpack] gagal memberi %s x%s ke %s: %s^7'):format(entry.item, entry.amount, citizenid, tostring(response)))
        end
    end

    if spot then giveVehicle(src, citizenid, spot) end
    return true, Config.Text.success
end

lib.callback.register('f_starterpack:status', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and hasClaimed(player.PlayerData.citizenid) or false
end)

lib.callback.register('f_starterpack:claim', function(source)
    if busy[source] then return false, Config.Text.busy end
    busy[source] = true
    local ok, result, msg = pcall(claim, source)
    busy[source] = nil
    if not ok then
        print(('^1[f_starterpack] error: %s^7'):format(result))
        return false
    end
    return result, msg
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
