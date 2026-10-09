if GetConvar('f_vehiclekeys:enableBridge', 'true') ~= 'true' then return end

function CreateQbExport(name, cb)
    AddEventHandler(('__cfx_export_qb-vehiclekeys_%s'):format(name), function(setCB)
        setCB(cb)
    end)
end

function GetVehiclesFromPlate(plate)
    if type(plate) ~= 'string' then return {} end
    plate = qbx.string.trim(plate)
    if plate == '' then return {} end

    Wait(500) -- delay needed to give client spawned vehicles time to be known to the server
    local vehicles = IsDuplicityVersion() and GetAllVehicles() or GetGamePool('CVehicle')
    local vehEntityFromPlate = {}

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if plate == qbx.getVehiclePlate(vehicle) then
            vehEntityFromPlate[#vehEntityFromPlate + 1] = vehicle
        end
    end

    return vehEntityFromPlate
end