local bridge = exports.community_bridge.Bridge(exports.community_bridge)

local vehicleStanceCache = {}

function SaveStanceData(plate, stanceData)
    if not plate or not stanceData then
        return false
    end
    
    local stanceJson = json.encode(stanceData)
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_data SET stance_data = ?, updated_at = NOW() WHERE plate = ?',
            {stanceJson, plate}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_data (plate, stance_data, created_at, updated_at) VALUES (?, ?, NOW(), NOW())',
            {plate, stanceJson}
        )
    end
    
    vehicleStanceCache[plate] = stanceData
    return true
end

function LoadStanceData(plate)
    if not plate then
        return nil
    end
    
    if vehicleStanceCache[plate] then
        return vehicleStanceCache[plate]
    end
    
    local result = MySQL.single.await('SELECT stance_data FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result and result.stance_data then
        local stanceData = json.decode(result.stance_data)
        vehicleStanceCache[plate] = stanceData
        return stanceData
    end
    
    return nil
end

RegisterNetEvent("nn_mechanic:initializeVehicleStanceStateBag", function(netId, plate)
    local src = source
    
    if netId and plate then
        local stanceData = LoadStanceData(plate)
        if stanceData then
            SetStateBagValue(("entity:%d"):format(netId), "nn_vehicle_stance", stanceData)
        end
    end
end)

-- Get vehicle stance data (callback)
lib.callback.register("nn_mechanic:getVehicleStanceData", function(src, plate)
    return LoadStanceData(plate)
end)

-- Set vehicle stance data
RegisterNetEvent("nn_mechanic:setVehicleStanceData", function(plate, stanceDataJson)
    local src = source
    
    -- Check permissions
    if not IsPlayerShopOwnerOrManager(src, plate) then
        TriggerClientEvent("chat:addMessage", src, {
            args = { "System", t("no_permission") }
        })
        return
    end
    
    local stanceData = json.decode(stanceDataJson)
    if stanceData then
        SaveStanceData(plate, stanceData)
        
        -- Sync to all clients in the vehicle
        local vehicle = GetVehicleFromPlate(plate)
        if vehicle and vehicle ~= 0 then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            SetStateBagValue(("entity:%d"):format(netId), "nn_vehicle_stance", stanceData)
        end
        
        TriggerClientEvent("chat:addMessage", src, {
            args = { "System", t("stance_kit_installed") }
        })
    end
end)

-- Helper: Check if player is shop owner or manager
function IsPlayerShopOwnerOrManager(src, plate)
    local playerIdentifier = GetPlayerIdentifierByType(src, 'license')
    
    local result = MySQL.single.await([[
        SELECT s.owner, e.role 
        FROM mechanic_shops s
        JOIN mechanic_shop_employees e ON s.id = e.shop_id
        WHERE e.identifier = ? AND (s.owner = ? OR e.role = 'manager')
    ]], {playerIdentifier, playerIdentifier})
    
    return result ~= nil
end

-- Helper: Get vehicle entity from plate
function GetVehicleFromPlate(plate)
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle) == plate then
            return vehicle
        end
    end
    return nil
end

-- Clean up stance cache on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        vehicleStanceCache = {}
    end
end)