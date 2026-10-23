-- server/effects/sv_oil.lua
local bridge = exports.community_bridge.Bridge(exports.community_bridge)

-- Track oil states per vehicle
local vehicleOilStates = {}

-- Save oil quality to database
function SaveOilState(plate, oilQuality, lastChangeKm)
    if not plate or not oilQuality then
        return false
    end
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_data SET oil_quality = ?, oil_last_change_km = ?, updated_at = NOW() WHERE plate = ?',
            {oilQuality, lastChangeKm or 0, plate}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_data (plate, oil_quality, oil_last_change_km, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())',
            {plate, oilQuality, lastChangeKm or 0}
        )
    end
    
    return true
end

-- Load oil state from database
function LoadOilState(plate)
    if not plate then
        return nil
    end
    
    local result = MySQL.single.await('SELECT oil_quality, oil_last_change_km FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        return {
            quality = result.oil_quality or 100.0,
            lastChangeKm = result.oil_last_change_km or 0
        }
    end
    
    return nil
end

-- Initialize oil state for a vehicle
RegisterNetEvent("nn_mechanic:initOilState", function(plate, netId)
    local src = source
    local loadedState = LoadOilState(plate)
    
    local oilQuality = 100.0
    if loadedState then
        oilQuality = loadedState.quality
    end
    
    SetStateBagValue(("entity:%d"):format(netId), "ns_oil_quality", oilQuality)
end)

-- Handle oil state updates
RegisterNetEvent("nn_mechanic:updateOilState", function(plate, oilQuality, lastChangeKm)
    if not plate or not oilQuality then
        return
    end
    
    SaveOilState(plate, oilQuality, lastChangeKm)
end)

-- Get recommended oil type for vehicle class
function GetRecommendedOilType(vehicleClass)
    local oilClasses = {
        [0] = "basic",      -- Compacts
        [1] = "basic",      -- Sedans
        [2] = "semi",       -- SUVs
        [3] = "semi",       -- Coupes
        [4] = "semi",       -- Muscle
        [5] = "semi",       -- Sports Classics
        [6] = "full",       -- Sports
        [7] = "full",       -- Super
        [8] = "semi",       -- Motorcycles
        [9] = "semi",       -- Off-road
        [10] = "heavy",     -- Industrial
        [11] = "heavy",     -- Utility
        [12] = "basic",     -- Vans
        [13] = "none",      -- Cycles
        [17] = "basic",     -- Service
        [18] = "full",      -- Emergency
        [19] = "full",      -- Military
        [22] = "full",      -- Open Wheel
    }
    
    return oilClasses[vehicleClass] or "semi"
end

function GetOilItemFromType(oilType)
    local oilMap = {
        basic = "mechanic_oil_basic",
        semi = "mechanic_oil_semi_synth",
        full = "mechanic_oil_full",
        heavy = "mechanic_oil_heavy"
    }
    return oilMap[oilType] or "mechanic_oil_semi_synth"
end

lib.callback.register("nn_mechanic:checkOilType", function(src, vehicleClass)
    local recommendedType = GetRecommendedOilType(vehicleClass)
    local requiredItem = GetOilItemFromType(recommendedType)
    
    return {
        hasItem = bridge.Inventory.HasItem(src, requiredItem, 1),
        requiredItem = requiredItem,
        requiredType = recommendedType
    }
end)

lib.callback.register("nn_mechanic:consumeOil", function(src, vehicleClass)
    local recommendedType = GetRecommendedOilType(vehicleClass)
    local requiredItem = GetOilItemFromType(recommendedType)
    
    return bridge.Inventory.RemoveItem(src, requiredItem, 1)
end)