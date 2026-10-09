if GetConvar('f_vehiclekeys:enableBridge', 'true') ~= 'true' then return end

---@param source number ID of the player
---@param plate? string
---@param fromClient? boolean When true (client-triggered path), keys are only granted through ClaimKeys rules.
local function giveKeys(source, plate, fromClient)
    local vehicles = plate and GetVehiclesFromPlate(plate) or {GetVehiclePedIsIn(GetPlayerPed(source), false)}
    local success = false
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) then
            local given
            if fromClient then
                given = ClaimKeys(source, vehicle)
            else
                given = GiveKeys(source, vehicle, true)
            end
            if given then
                success = true
            end
        end
    end
    if success and not fromClient then
        exports.qbx_core:Notify(source, locale('notify.keys_taken'))
    end
    return success
end

CreateQbExport('GiveKeys', giveKeys)

local function removeKeys(source, plate)
    local vehicles = GetVehiclesFromPlate(plate)
    local success = false
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) then
            if RemoveKeys(source, vehicle, true) then
                success = true
            end
        end
    end
    if success then
        exports.qbx_core:Notify(source, locale('notify.keys_removed'))
    end
    return success
end

CreateQbExport('RemoveKeys', removeKeys)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    giveKeys(source, plate, true)
end)

RegisterNetEvent('qb-vehiclekeys:server:removeKeys', function(plate)
    removeKeys(source, plate)
end)

CreateQbExport('HasKeys', function(source, plate)
    local vehicles = GetVehiclesFromPlate(plate)
    for i = 1, #vehicles do
        if HasKeys(source, vehicles[i]) then return true end
    end
    return false
end)
