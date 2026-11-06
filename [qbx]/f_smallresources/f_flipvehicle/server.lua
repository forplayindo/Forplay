RegisterNetEvent('f_flipvehicle:server:flip', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- hanya yang berdiri di dekat kendaraan yang boleh membalikkan
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(vehicle)) > 8.0 then return end

    -- nilai selalu berubah supaya handler di pemilik entity terpanggil lagi
    Entity(vehicle).state:set('flipVehicle', os.time() .. ':' .. source, true)
end)
