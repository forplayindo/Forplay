-- server/effects/sv_brake.lua
local bridge = exports.community_bridge.Bridge(exports.community_bridge)

-- Track brake states per vehicle
local vehicleBrakeStates = {}

-- Get brake state for a vehicle from its state bag
function GetBrakeStateForVehicle(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil
    end
    
    local stateBagKey = ("entity:%d"):format(netId)
    local frontBrake = GetStateBagValue(stateBagKey, "ns_brake_front")
    local rearBrake = GetStateBagValue(stateBagKey, "ns_brake_rear")
    local brakeHeat = GetStateBagValue(stateBagKey, "ns_brake_heat")
    
    if not (frontBrake and rearBrake and brakeHeat) then
        return nil
    end
    
    return {
        front = frontBrake,
        rear = rearBrake,
        heat = brakeHeat
    }
end

-- Save brake state to database (called periodically)
function SaveBrakeState(plate, brakeData)
    if not plate or not brakeData then
        return false
    end
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_data SET brake_front = ?, brake_rear = ?, brake_heat = ?, updated_at = NOW() WHERE plate = ?',
            {brakeData.front, brakeData.rear, brakeData.heat, plate}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_data (plate, brake_front, brake_rear, brake_heat, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
            {plate, brakeData.front, brakeData.rear, brakeData.heat}
        )
    end
    
    return true
end

-- Load brake state from database
function LoadBrakeState(plate)
    if not plate then
        return nil
    end
    
    local result = MySQL.single.await('SELECT brake_front, brake_rear, brake_heat FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        return {
            front = result.brake_front or 100.0,
            rear = result.brake_rear or 100.0,
            heat = result.brake_heat or 0.0
        }
    end
    
    return nil
end

RegisterNetEvent("nn_mechanic:initBrakeState", function(plate, netId)
    local src = source
    local loadedState = LoadBrakeState(plate)
    
    if loadedState then
        local stateBagKey = ("entity:%d"):format(netId)
        SetStateBagValue(stateBagKey, "ns_brake_front", loadedState.front)
        SetStateBagValue(stateBagKey, "ns_brake_rear", loadedState.rear)
        SetStateBagValue(stateBagKey, "ns_brake_heat", loadedState.heat)
    else
        SetStateBagValue(("entity:%d"):format(netId), "ns_brake_front", 100.0)
        SetStateBagValue(("entity:%d"):format(netId), "ns_brake_rear", 100.0)
        SetStateBagValue(("entity:%d"):format(netId), "ns_brake_heat", 0.0)
    end
end)

RegisterNetEvent("nn_mechanic:updateBrakeState", function(plate, brakeData)
    if not plate or not brakeData then
        return
    end
    
    SaveBrakeState(plate, brakeData)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000)
    end
end)