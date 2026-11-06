local VALID = { front = true, back = true, left = true, right = true }

RegisterNetEvent('f_vehiclepush:server:push', function(data)
    if type(data) ~= 'table' or (data.direction ~= nil and not VALID[data.direction]) then return end

    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if not DoesEntityExist(vehicle) then return end

    -- hanya yang berdiri di dekat kendaraan yang boleh mendorong
    if data.direction and #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(vehicle)) > 8.0 then return end

    Entity(vehicle).state:set('pushVehicle', data.direction, true)
end)
