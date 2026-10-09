local logger = require '@qbx_core.modules.logger'

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.f_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@type table<string, integer> slot key -> game time the reservation expires
local reservedSlots = {}

---Picks the first spawn slot that is not reserved and has no vehicle nearby, then reserves it.
---Must not yield between checking and reserving, so simultaneous requests always get different slots.
---@param garageName string
---@param accessPointIndex integer
---@param spawns vector4[]
---@return vector4? spawn, string? slotKey
local function reserveSpawnSlot(garageName, accessPointIndex, spawns)
    local now = GetGameTimer()
    local radius = Config.distanceCheck or 0
    local vehicleCoords = {}
    if radius > 0 then
        local vehicles = GetAllVehicles()
        for i = 1, #vehicles do
            vehicleCoords[i] = GetEntityCoords(vehicles[i])
        end
    end

    for i = 1, #spawns do
        local key = ('%s:%d:%d'):format(garageName, accessPointIndex, i)
        if (reservedSlots[key] or 0) < now then
            local pos = spawns[i].xyz
            local free = true
            for v = 1, #vehicleCoords do
                if #(vehicleCoords[v] - pos) < radius then
                    free = false
                    break
                end
            end
            if free then
                reservedSlots[key] = now + Config.spawnReserveTime
                return spawns[i], key
            end
        end
    end
end

---@param player table
---@param depotPrice integer
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        return true
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        return true
    end
    return false
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('f_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end

    local accessPoint = garage.accessPoints[accessPointIndex]
    if not accessPoint then
        logger.log({
            source = source,
            message = string.format(
                'Attempted to spawn a vehicle from a non-existent access point index: %d for garage: %s',
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })

        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if not IsInsideZone(accessPoint.zone, playerCoords, 3.0) then
        logger.log({
            source = source,
            message = string.format(
                'Player attempted to spawn a vehicle but was outside the garage zone. Coords: %s, Access Point Index: %d, Garage: %s',
                playerCoords,
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.anticheat,
            event = 'suspicious',
            color = 'white'
        })

        return
    end
    local garageType = GetGarageType(garageName)

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.f_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    -- reserved before paying, so a player never pays for a vehicle that has nowhere to spawn
    local spawnCoords, slotKey = reserveSpawnSlot(garageName, accessPointIndex, accessPoint.spawns)
    if not spawnCoords then
        exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
        return
    end

    if garageType == GarageType.DEPOT and playerVehicle.depotPrice then
        local player = exports.qbx_core:GetPlayer(source)
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        local canPay = payDepotPrice(player, playerVehicle.depotPrice)

        if not canPay then
            reservedSlots[slotKey] = nil
            exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
            return
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local ok, netId, veh = pcall(qbx.spawnVehicle, { spawnSource = spawnCoords, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})
    if not ok or not netId then
        reservedSlots[slotKey] = nil
        error(netId or 'failed to spawn vehicle')
    end

    if Config.doorsLocked then
        if GetResourceState('f_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    TriggerEvent('f_garages:server:vehicleSpawned', veh)
    -- jaring pengaman: pasang ulang modif dari database sekali (kalau saat spawn tidak terpasang sempurna)
    exports.f_vehicles:EnsureAppearance(veh, vehicleId)
    return netId
end)

function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end
