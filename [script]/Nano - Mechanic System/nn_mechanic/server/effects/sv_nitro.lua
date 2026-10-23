-- server/effects/sv_nitro.lua
local bridge = exports.community_bridge.Bridge(exports.community_bridge)

-- Track nitro installations per vehicle
local vehicleNitroData = {}

-- Load nitro data from database
function LoadNitroData(plate)
    if not plate then
        return nil
    end
    
    local result = MySQL.single.await('SELECT nitro_installed, nitro_fuel_current, nitro_fuel_max, nitro_bottles FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        return {
            installed = result.nitro_installed == 1,
            fuel = {
                current = result.nitro_fuel_current or 0,
                max = result.nitro_fuel_max or 0
            },
            bottles = json.decode(result.nitro_bottles or '[]')
        }
    end
    
    return nil
end

-- Save nitro data to database
function SaveNitroData(plate, nitroData)
    if not plate or not nitroData then
        return false
    end
    
    local bottlesJson = json.encode(nitroData.bottles or {})
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_data SET nitro_installed = ?, nitro_fuel_current = ?, nitro_fuel_max = ?, nitro_bottles = ?, updated_at = NOW() WHERE plate = ?',
            {nitroData.installed and 1 or 0, nitroData.fuel.current, nitroData.fuel.max, bottlesJson, plate}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_data (plate, nitro_installed, nitro_fuel_current, nitro_fuel_max, nitro_bottles, created_at, updated_at) VALUES (?, ?, ?, ?, ?, NOW(), NOW())',
            {plate, nitroData.installed and 1 or 0, nitroData.fuel.current, nitroData.fuel.max, bottlesJson}
        )
    end
    
    return true
end

-- Initialize nitro state for a vehicle
RegisterNetEvent("nn_mechanic:initNitroState", function(plate, netId)
    local src = source
    local loadedData = LoadNitroData(plate)
    
    if loadedData then
        SetStateBagValue(("entity:%d"):format(netId), "nn_nitro_installed", loadedData.installed)
        SetStateBagValue(("entity:%d"):format(netId), "nn_nitro_data", loadedData)
    end
end)

-- Handle nitro sync from clients
RegisterNetEvent("nn_mechanic:nitro:sync", function(netId, enableBoost, enablePurge, forcePassengerSeat)
    local src = source
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local ped = GetPlayerPed(tonumber(playerId))
        local vehicle = GetVehiclePedIsIn(ped, forcePassengerSeat or false)
        
        if vehicle ~= 0 and NetworkGetNetworkIdFromEntity(vehicle) == netId then
            TriggerClientEvent("nn_mechanic:nitro:update", playerId, src, netId, enableBoost, enablePurge, forcePassengerSeat)
        end
    end
end)

-- Save nitro fuel
RegisterNetEvent("nn_mechanic:nitro:saveFuel", function(plate, currentFuel)
    if not plate then
        return
    end
    
    local nitroData = LoadNitroData(plate)
    if nitroData then
        nitroData.fuel.current = currentFuel
        SaveNitroData(plate, nitroData)
    end
end)

-- Consume nitro bottle
RegisterNetEvent("nn_mechanic:nitro:consumeBottle", function(plate)
    local src = source
    if not plate then
        return
    end
    
    local nitroData = LoadNitroData(plate)
    if nitroData and nitroData.bottles and #nitroData.bottles > 0 then
        table.remove(nitroData.bottles, 1)
        
        -- Reset fuel from the next bottle
        if #nitroData.bottles > 0 then
            local nextBottle = nitroData.bottles[1]
            nitroData.fuel.current = nextBottle.capacity or 1500
        else
            nitroData.fuel.current = 0
        end
        
        SaveNitroData(plate, nitroData)
        
        -- Notify client of bottle consumed
        TriggerClientEvent("nn_mechanic:nitro:bottleConsumed", src, plate, nitroData)
    end
end)

-- Refresh nitro data for client
RegisterNetEvent("nn_mechanic:nitro:refreshData", function(plate)
    local src = source
    local nitroData = LoadNitroData(plate)
    
    if nitroData then
        TriggerClientEvent("nn_mechanic:nitro:dataRefresh", src, plate, nitroData)
    end
end)

-- Install nitro system
lib.callback.register("nn_mechanic:nitro:install", function(src, plate, bottleItems)
    if not plate or not bottleItems then
        return false
    end
    
    local bottles = {}
    local totalFuel = 0
    local maxFuel = 0
    
    for _, bottleItem in ipairs(bottleItems) do
        local bottleConfig = Config.Nitro.bottles[bottleItem.name]
        if bottleConfig then
            table.insert(bottles, {
                name = bottleItem.name,
                capacity = bottleConfig.capacity,
                power = bottleConfig.power,
                strength = bottleConfig.strength
            })
            totalFuel = totalFuel + bottleConfig.capacity
            maxFuel = maxFuel + bottleConfig.capacity
        end
    end
    
    local nitroData = {
        installed = true,
        fuel = {
            current = totalFuel,
            max = maxFuel
        },
        bottles = bottles
    }
    
    local success = SaveNitroData(plate, nitroData)
    
    if success then
        -- Notify any client currently in this vehicle
        TriggerClientEvent("nn_mechanic:nitro:dataRefresh", -1, plate, nitroData)
    end
    
    return success
end)