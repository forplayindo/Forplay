local config = lib.loadJson('f_flipvehicle.config')

---@param vehicle number
local function isFlipped(vehicle)
    return IsEntityUpsidedown(vehicle) or math.abs(GetEntityRoll(vehicle)) > 60.0
end

---@param vehicle number? id of the vehicle, default closes vehicle
---@param flipTest boolean? costom fliping task
local function flipVehicle(vehicle, flipTest)
    if cache.vehicle then return end
    if not vehicle then vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), config.maxDistance, false) end
    if not vehicle then return exports.qbx_core:Notify(locale('error.no_vehicle_nearby'), 'error') end
    local peedCoords = GetEntityCoords(cache.ped)
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(peedCoords - vehicleCoords) > config.maxDistance then
        return exports.qbx_core:Notify(locale('error.no_vehicle_nearby'), 'error')
    end

    if flipTest or lib.progressBar({
        label = locale('progress.flipping_car'),
        duration = config.flipingTime,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    }) then
        -- dibalikkan oleh pemilik entity (lewat server), kalau tidak mobil milik client lain tidak bergerak
        TriggerServerEvent('f_flipvehicle:server:flip', VehToNet(vehicle))
        exports.qbx_core:Notify(locale('success.flipped_car'), 'success')
    else
        exports.qbx_core:Notify(locale('error.canceled'), 'error')
    end
end

AddStateBagChangeHandler('flipVehicle', nil, function(bagName, _, value)
    if not value then return end

    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle == 0 or NetworkGetEntityOwner(vehicle) ~= cache.playerId then return end

    SetEntityRotation(vehicle, 0.0, 0.0, GetEntityHeading(vehicle), 2, true)
    SetVehicleOnGroundProperly(vehicle)
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_flipvehicle:flip',
        icon = 'fa-solid fa-car-burst',
        label = locale('target.flip_vehicle'),
        distance = 2.5,
        canInteract = function(entity)
            return not cache.vehicle and isFlipped(entity)
        end,
        onSelect = function(data)
            flipVehicle(data.entity)
        end,
    },
})

---@deprecated use FlipVehicle instead
exports('flipVehicle', flipVehicle)

exports('FlipVehicle', flipVehicle)
