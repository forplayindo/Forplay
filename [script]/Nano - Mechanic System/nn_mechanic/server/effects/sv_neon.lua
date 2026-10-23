-- server/effects/sv_neon.lua
local bridge = exports.community_bridge.Bridge(exports.community_bridge)

-- Track neon effects per vehicle plate
local vehicleNeonCache = {}

-- Save neon effect to database
function SaveNeonEffect(plate, effect, color, zones)
    if not plate then
        return false
    end
    
    local zonesJson = json.encode(zones or {})
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_data SET neon_effect = ?, neon_color = ?, neon_zones = ?, updated_at = NOW() WHERE plate = ?',
            {effect or 'static', color or '#FFFFFF', zonesJson, plate}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_data (plate, neon_effect, neon_color, neon_zones, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
            {plate, effect or 'static', color or '#FFFFFF', zonesJson}
        )
    end
    
    return true
end

function LoadNeonEffect(plate)
    if not plate then
        return nil
    end
    
    if vehicleNeonCache[plate] and vehicleNeonCache[plate].lastFetchedAt and GetGameTimer() - vehicleNeonCache[plate].lastFetchedAt < 30000 then
        return vehicleNeonCache[plate].effect
    end
    
    local result = MySQL.single.await('SELECT neon_effect, neon_color, neon_zones FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        local effectData = {
            effect = result.neon_effect or 'static',
            color = result.neon_color or '#FFFFFF',
            zones = json.decode(result.neon_zones or '{}')
        }
        
        vehicleNeonCache[plate] = {
            effect = effectData,
            lastFetchedAt = GetGameTimer()
        }
        
        return effectData
    end
    
    return nil
end

lib.callback.register("nn_mechanic:getVehicleNeonEffect", function(src, plate)
    local effectData = LoadNeonEffect(plate)
    return effectData and effectData.effect or 'static'
end)

lib.callback.register("nn_mechanic:getVehicleNeonColor", function(src, plate)
    local effectData = LoadNeonEffect(plate)
    return effectData and effectData.color or '#FFFFFF'
end)

lib.callback.register("nn_mechanic:getVehicleNeonLights", function(src, plate)
    local effectData = LoadNeonEffect(plate)
    local zones = effectData and effectData.zones or {}
    return json.encode(zones)
end)

RegisterNetEvent("nn_mechanic:takeControlNeonEffect", function(plate)
    local src = source
    
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        if tonumber(playerId) ~= src then
            TriggerClientEvent("nn_mechanic:releaseControlNeonEffect", playerId, plate)
        end
    end
end)

RegisterNetEvent("nn_mechanic:updateNeonEffect", function(plate, effect, color, zones)
    local src = source
    
    if not IsPlayerShopOwnerOrManager(src, plate) then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "System", t("no_permission") }
        })
        return
    end
    
    SaveNeonEffect(plate, effect, color, zones)
    
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent("nn_mechanic:updateNeonEffect", playerId, plate, effect)
    end
end)

function IsPlayerShopOwnerOrManager(src, plate)
    local playerIdentifier = GetPlayerIdentifierByType(src, 'license')
    
    local shopResult = MySQL.single.await([[
        SELECT s.id 
        FROM mechanic_shops s
        WHERE s.id = (SELECT shop_id FROM mechanic_customer_vehicles WHERE plate = ? LIMIT 1)
    ]], {plate})
    
    local shopId = shopResult and shopResult.id
    
    if shopId then
        local employeeResult = MySQL.single.await([[
            SELECT role 
            FROM mechanic_shop_employees 
            WHERE shop_id = ? AND identifier = ?
        ]], {shopId, playerIdentifier})
        
        if employeeResult and (employeeResult.role == 'manager' or employeeResult.role == 'owner') then
            return true
        end
    end
    
    local ownerResult = MySQL.single.await([[
        SELECT owner 
        FROM mechanic_shops 
        WHERE id = (SELECT shop_id FROM mechanic_customer_vehicles WHERE plate = ? LIMIT 1)
    ]], {plate})
    
    return ownerResult and ownerResult.owner == playerIdentifier
end