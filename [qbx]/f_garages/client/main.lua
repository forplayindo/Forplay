local config = require 'config.client'
if not config.enableClient then return end
local VEHICLES = exports.qbx_core:GetVehiclesByName()

---@enum ProgressColor
local ProgressColor = {
    GREEN = 'green.5',
    YELLOW = 'yellow.5',
    RED = 'red.5'
}

---@param percent number
---@return string
local function getProgressColor(percent)
    if percent >= 75 then
        return ProgressColor.GREEN
    elseif percent > 25 then
        return ProgressColor.YELLOW
    else
        return ProgressColor.RED
    end
end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'), 'error')
            return
        end

        local netId = lib.callback.await('f_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then return end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
end

---@param vehicle PlayerVehicle
---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function displayVehicleInfo(vehicle, garageName, garageInfo, accessPoint)
    local engine = qbx.math.round(vehicle.props.engineHealth / 10)
    local body = qbx.math.round(vehicle.props.bodyHealth / 10)
    local engineColor = getProgressColor(engine)
    local bodyColor = getProgressColor(body)
    local fuelColor = getProgressColor(vehicle.props.fuelLevel)
    local vehicleLabel = ('%s %s'):format(VEHICLES[vehicle.modelName].brand, VEHICLES[vehicle.modelName].name)

    local options = {
        {
            title = locale('menu.information'),
            icon = 'circle-info',
            description = locale('menu.description', vehicleLabel, vehicle.props.plate, lib.math.groupdigits(vehicle.depotPrice)),
            readOnly = true,
        },
        {
            title = locale('menu.body'),
            icon = 'car-side',
            readOnly = true,
            progress = body,
            colorScheme = bodyColor,
        },
        {
            title = locale('menu.engine'),
            icon = 'oil-can',
            readOnly = true,
            progress = engine,
            colorScheme = engineColor,
        },
        {
            title = locale('menu.fuel'),
            icon = 'gas-pump',
            readOnly = true,
            progress = vehicle.props.fuelLevel,
            colorScheme = fuelColor,
        }
    }

    if vehicle.state == VehicleState.OUT then
        if garageInfo.type == GarageType.DEPOT then
            options[#options + 1] = {
                title = 'Ambil kendaraan',
                icon = 'fa-truck-ramp-box',
                description = ('Rp %s'):format(lib.math.groupdigits(vehicle.depotPrice)),
                arrow = true,
                onSelect = function()
                    takeOutOfGarage(vehicle.id, garageName, accessPoint)
                end,
            }
        else
            options[#options + 1] = {
                title = 'Kendaraanmu sudah dikeluarkan...',
                icon = VehicleType.CAR,
                readOnly = true,
            }
        end
    elseif vehicle.state == VehicleState.GARAGED then
        options[#options + 1] = {
            title = locale('menu.take_out'),
            icon = 'car-rear',
            arrow = true,
            onSelect = function()
                takeOutOfGarage(vehicle.id, garageName, accessPoint)
            end,
        }
    elseif vehicle.state == VehicleState.IMPOUNDED then
        options[#options + 1] = {
            title = locale('menu.veh_impounded'),
            icon = 'building-shield',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'vehicleList',
        title = garageInfo.label,
        menu = 'garageMenu',
        options = options,
    })

    lib.showContext('vehicleList')
end

---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function openGarageMenu(garageName, garageInfo, accessPoint)
    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('f_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    table.sort(vehicleEntities, function(a, b)
        return a.modelName < b.modelName
    end)

    local options = {}
    for i = 1, #vehicleEntities do
        local vehicleEntity = vehicleEntities[i]
        local vehicleLabel = ('%s %s'):format(VEHICLES[vehicleEntity.modelName].brand, VEHICLES[vehicleEntity.modelName].name)

        options[#options + 1] = {
            title = vehicleLabel,
            description = vehicleEntity.props.plate,
            arrow = true,
            onSelect = function()
                displayVehicleInfo(vehicleEntity, garageName, garageInfo, accessPoint)
            end,
        }
    end

    lib.registerContext({
        id = 'garageMenu',
        title = garageInfo.label,
        options = options,
    })

    lib.showContext('garageMenu')
end

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('f_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        -- the vehicle is being stored, so the key script should not pop up its remote on exit
        TriggerEvent('f_vehiclekeys:client:skipKeyFobOnExit', vehicle)
        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        lib.callback.await('f_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(garage.groups, QBX.PlayerData) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

---@class ActiveZone
---@field garageName string
---@field garage GarageConfig
---@field accessPointIndex integer

---@type ActiveZone?
local activeZone
local busy = false

---@param vehicle number|false|nil
local function showPrompt(vehicle)
    if not activeZone then return end
    local garage = activeZone.garage
    lib.showTextUI((garage.type == GarageType.DEPOT and locale('info.impound_e')) or (vehicle and locale('info.park_e')) or locale('info.car_e'))
end

local function interact()
    local zone = activeZone
    if not zone or busy or lib.getOpenContextMenu() then return end
    if not checkCanAccess(zone.garage) then return end

    busy = true
    CreateThread(function()
        local success, result = pcall(function()
            if cache.vehicle and zone.garage.type ~= GarageType.DEPOT then
                parkVehicle(cache.vehicle, zone.garageName)
            else
                openGarageMenu(zone.garageName, zone.garage, zone.accessPointIndex)
            end
        end)
        busy = false
        assert(success, result)
    end)
end

-- only enabled while inside a garage zone, so nothing runs every frame
local interactKeybind = lib.addKeybind({
    name = 'f_garages_interact',
    description = 'Garasi: parkir / keluarkan kendaraan',
    defaultKey = config.interactKey,
    disabled = true,
    onReleased = interact,
})

lib.onCache('vehicle', function(vehicle)
    showPrompt(vehicle)
end)

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
---@return CZone
local function createZone(garageName, garage, accessPoint, accessPointIndex)
    local zone = accessPoint.zone
    local centerZ = ZoneMinZ(zone) + zone.height / 2
    local points = {}
    for i = 1, #zone.points do
        points[i] = vec3(zone.points[i].x, zone.points[i].y, centerZ)
    end

    ---@type ActiveZone
    local entry = {
        garageName = garageName,
        garage = garage,
        accessPointIndex = accessPointIndex,
    }

    return lib.zones.poly({
        points = points,
        thickness = zone.height,
        debug = config.debugPoly,
        -- same check as the server, so client and server always agree on who is inside
        contains = function(self, coords, updateDistance)
            if updateDistance then self.distance = #(self.coords - coords) end
            return IsInsideZone(zone, coords, 0)
        end,
        onEnter = function()
            activeZone = entry
            interactKeybind:disable(false)
            showPrompt(cache.vehicle)
        end,
        onExit = function()
            if activeZone ~= entry then return end
            activeZone = nil
            interactKeybind:disable(true)
            lib.hideTextUI()
        end,
    })
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
---@return integer blip
local function createBlip(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

---@type table<string, { zones: CZone[], blips: integer[] }>
local garageHandles = {}

local function removeGarage(name)
    local handles = garageHandles[name]
    if not handles then return end

    if activeZone and activeZone.garageName == name then
        activeZone = nil
        interactKeybind:disable(true)
        lib.hideTextUI()
    end
    for i = 1, #handles.zones do
        handles.zones[i]:remove()
    end
    for i = 1, #handles.blips do
        RemoveBlip(handles.blips[i])
    end
    garageHandles[name] = nil
end

local function createGarage(name, garage)
    removeGarage(name)

    local handles = { zones = {}, blips = {} }
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            handles.blips[#handles.blips + 1] = createBlip(garage, accessPoint)
        end

        handles.zones[#handles.zones + 1] = createZone(name, garage, accessPoint, i)
    end
    garageHandles[name] = handles
end

local function createGarages()
    local garages = lib.callback.await('f_garages:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('f_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

-- garasi dihapus dari editor in-game (/garasi)
RegisterNetEvent('f_garages:client:garageRemoved', function(name)
    removeGarage(name)
end)

CreateThread(function()
    createGarages()
end)

if config.pointHelperCommand then
    RegisterCommand(config.pointHelperCommand, function()
        local text
        if cache.vehicle then
            local coords = GetEntityCoords(cache.vehicle)
            text = ('vec4(%.2f, %.2f, %.2f, %.2f),'):format(coords.x, coords.y, coords.z, GetEntityHeading(cache.vehicle))
        else
            local coords = GetEntityCoords(cache.ped)
            text = ('vec2(%.2f, %.2f), -- z = %.2f'):format(coords.x, coords.y, coords.z - 1.0)
        end
        lib.setClipboard(text)
        print(text)
        exports.qbx_core:Notify(text, 'inform')
    end, false)
end
