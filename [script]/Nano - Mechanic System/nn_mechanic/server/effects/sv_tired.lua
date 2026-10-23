local bridge = exports.community_bridge.Bridge(exports.community_bridge)

local vehicleTireStates = {}

function SaveTireState(plate, wheelIndex, pressure, tread)
    if not plate or wheelIndex == nil then
        return false
    end
    
    local result = MySQL.single.await('SELECT 1 FROM mechanic_vehicle_tires WHERE plate = ? AND wheel_index = ?', {plate, wheelIndex})
    
    if result then
        MySQL.update.await(
            'UPDATE mechanic_vehicle_tires SET pressure = ?, tread = ?, updated_at = NOW() WHERE plate = ? AND wheel_index = ?',
            {pressure, tread, plate, wheelIndex}
        )
    else
        MySQL.insert.await(
            'INSERT INTO mechanic_vehicle_tires (plate, wheel_index, pressure, tread, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())',
            {plate, wheelIndex, pressure, tread}
        )
    end
    
    return true
end

function LoadTireStates(plate)
    if not plate then
        return {}
    end
    
    local results = MySQL.query.await('SELECT wheel_index, pressure, tread FROM mechanic_vehicle_tires WHERE plate = ?', {plate})
    
    local tireStates = {}
    for _, row in ipairs(results) do
        tireStates[row.wheel_index] = {
            pressure = row.pressure or 32.0,
            tread = row.tread or 100.0
        }
    end
    
    return tireStates
end

RegisterNetEvent("nn_mechanic:initTireStates", function(plate, netId)
    local src = source
    local loadedStates = LoadTireStates(plate)
    local stateBagKey = ("entity:%d"):format(netId)
    
    local wheelIndices = {0, 1, 2, 3}
    
    for _, wheelIndex in ipairs(wheelIndices) do
        local state = loadedStates[wheelIndex]
        local pressure = (state and state.pressure) or 32.0
        local tread = (state and state.tread) or 100.0
        
        SetStateBagValue(stateBagKey, ("ns_psi%d"):format(wheelIndex), pressure * 10.0)
        SetStateBagValue(stateBagKey, ("ns_tr%d"):format(wheelIndex), tread)
    end
end)

RegisterNetEvent("nn_mechanic:updateTireState", function(plate, wheelIndex, pressure, tread)
    if not plate or wheelIndex == nil then
        return
    end
    
    SaveTireState(plate, wheelIndex, pressure, tread)
end)

RegisterNetEvent("nn_mechanic:burstTire", function(plate, wheelIndex)
    if not plate or not wheelIndex then
        return
    end
    
    MySQL.insert.await(
        'INSERT INTO mechanic_tire_bursts (plate, wheel_index, burst_at) VALUES (?, ?, NOW())',
        {plate, wheelIndex}
    )
end)

lib.callback.register("nn_mechanic:getBaseTraction", function(src, plate)
    local result = MySQL.single.await('SELECT traction_min, traction_max FROM mechanic_vehicle_data WHERE plate = ?', {plate})
    
    if result then
        return {
            min = result.traction_min,
            max = result.traction_max
        }
    end
    
    return nil
end)

RegisterNetEvent("nn_mechanic:saveBaseTraction", function(plate, tractionMin, tractionMax)
    if not plate then
        return
    end
    
    MySQL.update.await(
        'UPDATE mechanic_vehicle_data SET traction_min = ?, traction_max = ?, updated_at = NOW() WHERE plate = ?',
        {tractionMin, tractionMax, plate}
    )
end)