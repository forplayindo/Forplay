local config = require 'config.server'

---@param veh number
---@param state string
local function setLockState(veh, state)
	if type(state) ~= 'string' or not DoesEntityExist(veh) then return end
    local vehicleConfig = GetVehicleConfig(veh)
    if vehicleConfig.noLock or vehicleConfig.shared then return end
    Entity(veh).state:set('doorslockstate', state == 'lock' and 2 or 1, true)
end
exports('SetLockState', setLockState)
SetLockState = setLockState

---@type table<string, table<integer, integer>> action -> player -> last GetGameTimer()
local cooldowns = { carjack = {}, findKeys = {} }

---@param action string
---@param src integer
---@param duration integer
---@return boolean onCooldown
local function isOnCooldown(action, src, duration)
    local now = GetGameTimer()
    local last = cooldowns[action][src]
    if last and now - last < duration then return true end
    cooldowns[action][src] = now
    return false
end

AddEventHandler('playerDropped', function()
    for _, list in pairs(cooldowns) do
        list[source] = nil
    end
end)

---@param src integer
---@param vehicle number
---@return boolean
local function isDriver(src, vehicle)
    return GetPedInVehicleSeat(vehicle, -1) == GetPlayerPed(src)
end

---@param vehicle number
---@return boolean
local function hasDeadNpcDriver(vehicle)
    local driver = GetPedInVehicleSeat(vehicle, -1)
    return driver ~= 0 and IsEntityDead(driver) and not IsPedAPlayer(driver)
end

lib.callback.register('f_vehiclekeys:server:findKeys', function(source, netId)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not isDriver(source, vehicle) then return end
    -- player vehicles use physical keys, there is nothing to find inside them
    if GetOwnedVehicleInfo(vehicle) then return end
    local plate = qbx.getVehiclePlate(vehicle)
    if plate and exports.f_vehicles:GetVehicleIdByPlate(plate) then return end
    if isOnCooldown('findKeys', source, config.findKeysCooldown) then return end
    if math.random() <= GetVehicleConfig(vehicle).findKeysChance then
        GiveSessionKeys(source, vehicle)
        return true
    end
end)

lib.callback.register('f_vehiclekeys:server:carjack', function(source, netId, weaponTypeGroup)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(source, vehicle) then return end
    if isOnCooldown('carjack', source, config.carjackCooldown) then return end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver == 0 or IsPedAPlayer(driver) or GetVehicleConfig(vehicle).carjackingImmune then return end
    -- the weapon group comes from the client, so read the weapon the ped really holds
    local weapon = GetSelectedPedWeapon(GetPlayerPed(source))
    if weapon == 0 or weapon == `WEAPON_UNARMED` then return end

    local chance = config.carjackChance[weaponTypeGroup] or 0.5
    if math.random() <= chance then
        GiveSessionKeys(source, vehicle)
        setLockState(vehicle, 'unlock')
        return true
    end
end)

RegisterNetEvent('f_vehiclekeys:server:playerEnteredVehicleWithEngineOn', function(netId)
    local src = source
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not isDriver(src, vehicle) then return end
    if not GetIsVehicleEngineRunning(vehicle) then return end
    GiveSessionKeys(src, vehicle)
end)

-- unlocks a vehicle whose NPC driver is dead, so the keys can be taken off the body
RegisterNetEvent('f_vehiclekeys:server:unlockDeadDriver', function(netId)
    local src = source
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(src, vehicle) then return end
    if not hasDeadNpcDriver(vehicle) or GetVehicleConfig(vehicle).carjackingImmune then return end
    setLockState(vehicle, 'unlock')
end)

RegisterNetEvent('f_vehiclekeys:server:tookKeys', function(netId)
    local src = source
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(src, vehicle) then return end

    -- this is meant for looting keys off a dead NPC driver's corpse - without
    -- re-checking that server side, a forged call could take keys to any
    -- nearby vehicle (including a living driver's, or another player's)
    if not hasDeadNpcDriver(vehicle) or GetVehicleConfig(vehicle).carjackingImmune then return end

    GiveSessionKeys(src, vehicle)
end)

-- the server rolls the initial lock state of NPC vehicles, so a client cannot choose "unlocked"
RegisterNetEvent('f_vehiclekeys:server:initLockState', function(netId)
    local src = source
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(src, vehicle) then return end

    local state = Entity(vehicle).state
    if state.doorslockstate or state.vehicleid then return end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver ~= 0 and IsPedAPlayer(driver) then return end

    -- a registered player vehicle (e.g. a display car inside a garage interior) is not an NPC car
    local plate = qbx.getVehiclePlate(vehicle)
    if plate and exports.f_vehicles:GetVehicleIdByPlate(plate) then return end

    local vehicleConfig = GetVehicleConfig(vehicle)
    local chance = driver ~= 0 and vehicleConfig.spawnLockedIfDriven or vehicleConfig.spawnLockedIfParked
    local locked = vehicleConfig.noLock ~= true and (type(chance) == 'number' and math.random() < chance or chance == true)
    state:set('doorslockstate', locked and 2 or 1, true)
end)

RegisterNetEvent('f_vehiclekeys:server:setLockState', function(netId, locked)
    local src = source
    if type(locked) ~= 'boolean' then return end
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(src, vehicle, config.lockDistance) then return end
    if not CanUseKeyFob(src, vehicle) then return end
    setLockState(vehicle, locked and 'lock' or 'unlock')
end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    if not (itemName == 'lockpick' or itemName == 'advancedlockpick') then return end
    exports.ox_inventory:RemoveItem(source, itemName, 1)
end)

-- kept for other resources (f_garages, f_phone). Server side callers are trusted,
-- a client must have keys (or job access) and be in range.
RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(netId, state)
    local src = tonumber(source)
    local vehicle = GetVehicleFromNetId(netId)
	if type(state) ~= 'number' or not vehicle then return end
    if src and src > 0 then
        if not IsPlayerNearVehicle(src, vehicle, config.lockDistance) or not CanUseKeyFob(src, vehicle) then return end
    end
    setLockState(vehicle, state == 2 and 'lock' or 'unlock')
end)
