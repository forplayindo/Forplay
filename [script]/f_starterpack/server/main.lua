-- Starterpack warga baru. Semua dicek dan dibuat di server:
--  * klaim dikunci per citizenid lewat INSERT IGNORE (tidak bisa dobel walau event di-spam)
--  * kendaraan dibuat server: plat f_vehicles, simpan lewat CreatePlayerVehicle, kunci fisik f_vehiclekeys
local busy = {}

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_starterpack (
        citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
        claimed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )]])
end)

local function hasClaimed(citizenid)
    return MySQL.scalar.await('SELECT 1 FROM f_starterpack WHERE citizenid = ?', { citizenid }) ~= nil
end

local function vehicleData()
    return exports.qbx_core:GetVehiclesByName()[Config.Vehicle.model]
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

local function canCarryAll(src)
    for _, entry in ipairs(Config.Items) do
        if not exports.ox_inventory:CanCarryItem(src, entry.item, entry.amount) then return false end
    end
    return true
end

local function giveVehicle(src, citizenid, spot)
    local v = Config.Vehicle
    local plate = exports.f_vehicles:GeneratePlate()
    local vehicleId, err = exports.f_vehicles:CreatePlayerVehicle({
        model = v.model,
        citizenid = citizenid,
        props = { plate = plate, fuelLevel = v.fuel },
    })
    if not vehicleId then
        print(('^1[f_starterpack] gagal membuat kendaraan untuk %s: %s^7'):format(citizenid, json.encode(err)))
        return
    end

    local _, veh = qbx.spawnVehicle({
        model = v.model,
        spawnSource = spot,
        warp = GetPlayerPed(src),
        bucket = GetPlayerRoutingBucket(src),
        props = { plate = plate },
    })
    if not veh or veh == 0 then
        print(('^1[f_starterpack] kendaraan %s (id %s) gagal di-spawn, ambil lewat garasi^7'):format(plate, vehicleId))
        return
    end

    Entity(veh).state:set('vehicleid', vehicleId, true)
    Entity(veh).state:set('fuel', v.fuel, true)
    exports.f_vehicles:EnsureAppearance(veh, vehicleId)
    exports.f_vehiclekeys:GiveKeys(src, veh)
    exports.qbx_core:Notify(src, Config.Text.vehicle:format(plate), 'success', 7000)
end

local function claim(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, Config.Text.failed end
    local citizenid = player.PlayerData.citizenid
    local ped = GetPlayerPed(src)

    if #(GetEntityCoords(ped) - Config.Ped.coords.xyz) > Config.ClaimRadius then return false, Config.Text.too_far end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, Config.Text.in_vehicle end
    if hasClaimed(citizenid) then return false, Config.Text.already end
    if not canCarryAll(src) then return false, Config.Text.no_space end

    local spot
    if Config.Vehicle.enabled then
        if not vehicleData() then return false, Config.Text.bad_model end
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

-- Data untuk NUI: isi paket + status klaim karakter ini
lib.callback.register('f_starterpack:info', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local items = {}
    for i, entry in ipairs(Config.Items) do
        local data = exports.ox_inventory:Items(entry.item)
        items[i] = { name = entry.item, label = data and data.label or entry.item, amount = entry.amount }
    end

    local vehicle
    if Config.Vehicle.enabled then
        local data = vehicleData()
        vehicle = {
            model = Config.Vehicle.model,
            label = data and ('%s %s'):format(data.brand or '', data.name or Config.Vehicle.model):gsub('^%s+', '') or Config.Vehicle.model,
        }
    end

    return {
        title = Config.Welcome.title,
        message = Config.Welcome.message,
        items = items,
        vehicle = vehicle,
        claimed = hasClaimed(player.PlayerData.citizenid),
    }
end)

lib.callback.register('f_starterpack:claim', function(source)
    if busy[source] then return false, Config.Text.busy end
    busy[source] = true
    local ok, result, msg = pcall(claim, source)
    busy[source] = nil
    if not ok then
        print(('^1[f_starterpack] error: %s^7'):format(result))
        return false, Config.Text.failed
    end
    return result, msg
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
