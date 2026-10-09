local config = require 'config.server'
local sharedConfig = require 'config.shared'
local debug = GetConvarInt(('%s-debug'):format(GetCurrentResourceName()), 0) == 1

---@alias CitizenId string
---@alias SessionId integer
---@type table<CitizenId, table<SessionId, boolean>>
local loggedOutKeys = {} ---holds key status for some time after player logs out (Prevents frustration by crashing the client)

---@alias LogoutTime integer
---@type table<CitizenId, LogoutTime>
local logedOutTime = {} ---Life timestamp of the keys of a character who has logged out

---Gets Citizen Id based on source
---@param source number ID of the player
---@return string? citizenid The player CitizenID, nil otherwise.
local function getCitizenId(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    return player.PlayerData.citizenid
end

GetCitizenId = getCitizenId

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local citizenId = getCitizenId(src)
    if not citizenId then return end
    if loggedOutKeys[citizenId] then
        Player(src).state:set('keysList', loggedOutKeys[citizenId], true)
        loggedOutKeys[citizenId] = nil
        logedOutTime[citizenId] = nil
    end
end)

local function onPlayerUnload(src)
    local citizenId = getCitizenId(src)
    if not citizenId then return end
    loggedOutKeys[citizenId] = Player(src).state.keysList
    logedOutTime[citizenId] = os.time()
end

RegisterNetEvent('QBCore:Server:OnPlayerUnload', onPlayerUnload)

AddEventHandler('playerDropped', function()
    onPlayerUnload(source)
end)

---Removes old keys from server memory
lib.cron.new('*/'..config.runClearCronMinutes ..' * * * *', function ()
    local time = os.time()
    local seconds = config.runClearCronMinutes * 60
    for citizenId, lifetime in pairs(logedOutTime) do
        if lifetime + seconds < time then
            loggedOutKeys[citizenId] = nil
            logedOutTime[citizenId] = nil
        end
    end
end, {debug = debug})

-----------------------
---- Physical keys ----
-----------------------
-- Player owned vehicles (state.vehicleid) are opened with a `car_key` item. The key's `keyid`
-- contains the vehicle's key version; a mechanic duplicate bumps the version, so older keys die.

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vehicle_keys` (
            `vehicle_id` INT NOT NULL PRIMARY KEY,
            `key_version` INT NOT NULL DEFAULT 0,
            `security_tier` TINYINT NOT NULL DEFAULT 1
        )
    ]])
end)

---@type table<integer, {version: integer, tier: integer}>
local keyData = {}

local VEHICLES_BY_HASH = exports.qbx_core:GetVehiclesByHash()

---@param vehicleId integer
---@return {version: integer, tier: integer}
local function getKeyData(vehicleId)
    local data = keyData[vehicleId]
    if data then return data end

    local row = MySQL.single.await('SELECT key_version, security_tier FROM vehicle_keys WHERE vehicle_id = ?', { vehicleId })
    -- another call may have filled the cache while this one waited on the database
    data = keyData[vehicleId] or { version = row?.key_version or 0, tier = row?.security_tier or 1 }
    keyData[vehicleId] = data
    return data
end

---Returns the player vehicle id and owner citizenid, or nil for vehicles that are not player owned.
---@param vehicle number
---@return integer? vehicleId, string? owner
function GetOwnedVehicleInfo(vehicle)
    local state = Entity(vehicle).state
    local vehicleId = state.vehicleid
    if not vehicleId then return end

    local owner = state.owner or exports.f_vehicles:GetPlayerVehicle(vehicleId)?.citizenid
    if not owner then return end
    return vehicleId, owner
end

---@param vehicle number
---@return integer tier
function GetSecurityTier(vehicle)
    local vehicleId = GetOwnedVehicleInfo(vehicle)
    return vehicleId and getKeyData(vehicleId).tier or 1
end

---@param source number
---@param vehicle number
---@param vehicleId integer
---@param version integer
---@return boolean
local function addPhysicalKey(source, vehicle, vehicleId, version)
    -- the item keeps its "Car Key" label; vehicle name and plate show in the item details
    -- (registered with ox_inventory's displayMetadata on the client)
    local info = VEHICLES_BY_HASH[GetEntityModel(vehicle)]
    return exports.ox_inventory:AddItem(source, sharedConfig.keyItem, 1, {
        vehicle = info and qbx.string.trim(('%s %s'):format(info.brand or '', info.name or '')) or locale('info.unknown_vehicle'),
        plate = qbx.getVehiclePlate(vehicle),
        keyid = KeyId(vehicleId, version),
    }) and true or false
end

---Keys made before the vehicle name was stored get it added (and their old description removed).
---@param source number
---@param vehicle number
---@param keyid string
local function refreshKeyDetails(source, vehicle, keyid)
    local slots = exports.ox_inventory:GetSlotsWithItem(source, sharedConfig.keyItem, { keyid = keyid })
    if not slots then return end

    local info = VEHICLES_BY_HASH[GetEntityModel(vehicle)]
    for i = 1, #slots do
        local metadata = slots[i].metadata
        if metadata and not metadata.vehicle then
            metadata.vehicle = info and qbx.string.trim(('%s %s'):format(info.brand or '', info.name or '')) or locale('info.unknown_vehicle')
            metadata.plate = qbx.getVehiclePlate(vehicle)
            metadata.description = nil
            exports.ox_inventory:SetMetadata(source, slots[i].slot, metadata)
        end
    end
end

---Clients cannot see `vehicleid` (most scripts set it server-only), so the key id is replicated
---separately: a string for issued keys, false when the vehicle never had a key.
---@param vehicle number
---@param vehicleId integer
---@param version integer
local function setKeyState(vehicle, vehicleId, version)
    Entity(vehicle).state:set('keyid', version > 0 and KeyId(vehicleId, version) or false, true)
end

---@param source number
---@param vehicleId integer
---@return boolean
local function hasPhysicalKey(source, vehicleId)
    local version = getKeyData(vehicleId).version
    if version < 1 then return false end
    return exports.ox_inventory:Search(source, 'count', sharedConfig.keyItem, { keyid = KeyId(vehicleId, version) }) > 0
end

---Gives the owner the first key of their vehicle. Only ever happens once per vehicle,
---after that a lost key has to be duplicated by a mechanic.
---@param source number
---@param vehicle number
---@param vehicleId integer
---@return boolean
local function issueFirstKey(source, vehicle, vehicleId)
    local data = getKeyData(vehicleId)
    if data.version > 0 then return false end
    if not exports.ox_inventory:CanCarryItem(source, sharedConfig.keyItem, 1) then
        exports.qbx_core:Notify(source, locale('notify.inventory_full'), 'error')
        return false
    end

    -- claimed before any await so concurrent calls cannot issue two first keys
    data.version = 1
    setKeyState(vehicle, vehicleId, 1)
    MySQL.insert.await('INSERT INTO vehicle_keys (vehicle_id, key_version) VALUES (?, 1) ON DUPLICATE KEY UPDATE key_version = 1', { vehicleId })
    addPhysicalKey(source, vehicle, vehicleId, 1)
    exports.qbx_core:Notify(source, locale('notify.keys_taken'))
    return true
end

---Makes a new key for the owner and invalidates every older key of the vehicle.
---@param ownerSource number
---@param vehicle number
---@param vehicleId integer
---@return boolean
function RekeyVehicle(ownerSource, vehicle, vehicleId)
    if not exports.ox_inventory:CanCarryItem(ownerSource, sharedConfig.keyItem, 1) then return false end

    local data = getKeyData(vehicleId)
    local version = data.version + 1
    data.version = version
    setKeyState(vehicle, vehicleId, version)
    MySQL.insert.await('INSERT INTO vehicle_keys (vehicle_id, key_version) VALUES (?, ?) ON DUPLICATE KEY UPDATE key_version = VALUES(key_version)', { vehicleId, version })
    return addPhysicalKey(ownerSource, vehicle, vehicleId, version)
end

exports('RekeyVehicle', RekeyVehicle)

---@param vehicle number
---@param vehicleId integer
---@param tier integer
function SetSecurityTier(vehicle, vehicleId, tier)
    getKeyData(vehicleId).tier = tier
    Entity(vehicle).state:set('securityTier', tier, true)
    MySQL.insert.await('INSERT INTO vehicle_keys (vehicle_id, security_tier) VALUES (?, ?) ON DUPLICATE KEY UPDATE security_tier = VALUES(security_tier)', { vehicleId, tier })
end

----------------------
---- Session keys ----
----------------------
-- Temporary keys (NPC, job, stolen vehicles), cleared when the vehicle despawns.

--- Removing the vehicle keys from the user
---@param source number ID of the player
---@param vehicle number
---@param skipNotification? boolean
function RemoveKeys(source, vehicle, skipNotification)
    local citizenid = getCitizenId(source)
    if not citizenid then return end

    local keys = Player(source).state.keysList
    if not keys then return end

    local sessionId = Entity(vehicle).state.sessionId
    if not keys[sessionId] then return end
    keys[sessionId] = nil

    Player(source).state:set('keysList', keys, true)

    TriggerClientEvent('f_vehiclekeys:client:OnLostKeys', source)
    if not skipNotification then
        exports.qbx_core:Notify(source, locale('notify.keys_removed'))
    end

    return true
end

exports('RemoveKeys', RemoveKeys)

---Gives temporary keys, also for player owned vehicles (theft, carjack, admin).
---@param source number
---@param vehicle number
---@param skipNotification? boolean
function GiveSessionKeys(source, vehicle, skipNotification)
    local citizenid = getCitizenId(source)
    if not citizenid then return end

    local sessionId = Entity(vehicle).state.sessionId or exports.qbx_core:CreateSessionId(vehicle)
    local keys = Player(source).state.keysList or {}
    if keys[sessionId] then return end

    keys[sessionId] = true

    Player(source).state:set('keysList', keys, true)
    if not skipNotification then
        exports.qbx_core:Notify(source, locale('notify.keys_taken'))
    end
    return true
end

---Trusted (server side) key grant. The owner of a player vehicle gets its first physical key,
---everyone else gets temporary keys.
---@param source number
---@param vehicle number
---@param skipNotification? boolean
function GiveKeys(source, vehicle, skipNotification)
    local citizenid = getCitizenId(source)
    if not citizenid then return end

    local vehicleId, owner = GetOwnedVehicleInfo(vehicle)
    if vehicleId and owner == citizenid then
        -- a lost key is never replaced by taking the vehicle out again, only by a mechanic
        return issueFirstKey(source, vehicle, vehicleId)
    end

    return GiveSessionKeys(source, vehicle, skipNotification)
end

exports('GiveKeys', GiveKeys)

---@param src number
---@param vehicle number
---@return boolean
function HasKeys(src, vehicle)
    local keysList = Player(src).state.keysList
    if keysList then
        local sessionId = Entity(vehicle).state.sessionId
        if sessionId and keysList[sessionId] then
            return true
        end
    end

    return HasPhysicalKey(src, vehicle)
end

exports('HasKeys', HasKeys)

---The physical key (car_key item) of a player vehicle, without temporary keys.
---@param src number
---@param vehicle number
---@return boolean
function HasPhysicalKey(src, vehicle)
    local vehicleId, owner = GetOwnedVehicleInfo(vehicle)
    if not vehicleId then return false end

    if hasPhysicalKey(src, vehicleId) then
        refreshKeyDetails(src, vehicle, KeyId(vehicleId, getKeyData(vehicleId).version))
        return true
    end

    -- vehicles owned before physical keys existed: the owner gets the first key on first use
    if getKeyData(vehicleId).version == 0 and owner == getCitizenId(src) then
        return issueFirstKey(src, vehicle, vehicleId)
    end
    return false
end

---@param src number
---@param vehicle number
---@return boolean
function IsJobSharedForPlayer(src, vehicle)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local model = GetEntityModel(vehicle)
    return IsJobSharedVehicle(player.PlayerData.job, model, exports.qbx_core:GetVehicleClass(model)) == true
end

---Keys or job access
---@param src number
---@param vehicle number
---@return boolean
function CanAccessVehicle(src, vehicle)
    return HasKeys(src, vehicle) or IsJobSharedForPlayer(src, vehicle)
end

---Locking / unlocking from a client (key remote, phone): the physical key or job access.
---Temporary keys only start and drive a vehicle.
---@param src number
---@param vehicle number
---@return boolean
function CanUseKeyFob(src, vehicle)
    return HasPhysicalKey(src, vehicle) or IsJobSharedForPlayer(src, vehicle)
end

---Checks whether the player's ped is close enough to a vehicle to legitimately request keys for it.
---Server-side key-grant events are triggered by the client, so without this check a player could
---grant themselves keys to any vehicle on the server by spoofing its network id.
---@param source number ID of the player
---@param vehicle number
---@param maxDistance? number defaults to config.distanceToVehicle
---@return boolean
function IsPlayerNearVehicle(source, vehicle, maxDistance)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) <= (maxDistance or config.distanceToVehicle)
end

exports('IsPlayerNearVehicle', IsPlayerNearVehicle)

---@param netId integer
---@return number? vehicle
function GetVehicleFromNetId(netId)
    if type(netId) ~= 'number' then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    return vehicle
end

---------------------------------
---- Client requested keys ----
---------------------------------
-- Scripts give keys through the client (`vehiclekeys:client:SetOwner`), so a claim coming from a
-- client is only honored for: the owner's first key, or a freshly script-spawned vehicle nobody claimed.

---@type table<number, integer> vehicle entity -> os.time() of creation
local createdAt = {}
---@type table<number, integer> vehicle entity -> player that claimed it
local claimedBy = {}

AddEventHandler('entityCreated', function(entity)
    if DoesEntityExist(entity) and GetEntityType(entity) == 2 then
        createdAt[entity] = os.time()
    end
end)

AddEventHandler('entityRemoved', function(entity)
    createdAt[entity] = nil
    claimedBy[entity] = nil
end)

-- ambient traffic cannot be claimed, only script spawned (mission) or unknown population types
local claimablePopulation = { [0] = true, [6] = true, [7] = true }

---@param source number
---@param vehicle number
---@return boolean
function ClaimKeys(source, vehicle)
    local vehicleId, owner = GetOwnedVehicleInfo(vehicle)
    if vehicleId then
        -- no distance check: garage spawn slots can be far from where the owner stands, and this
        -- only ever gives the registered owner the vehicle's very first key
        if owner ~= getCitizenId(source) then return false end
        return issueFirstKey(source, vehicle, vehicleId)
    end

    if not IsPlayerNearVehicle(source, vehicle, config.newVehicleClaimDistance) then return false end

    -- a registered player vehicle spawned without `vehicleid` (yet): never hand out temporary keys,
    -- its owner uses the physical key once the vehicle is marked as owned
    local plate = qbx.getVehiclePlate(vehicle)
    if plate and exports.f_vehicles:GetVehicleIdByPlate(plate) then return false end

    local created = createdAt[vehicle]
    if not created or os.time() - created > config.newVehicleKeyWindow then return false end
    if not claimablePopulation[GetEntityPopulationType(vehicle)] then return false end
    if claimedBy[vehicle] and claimedBy[vehicle] ~= source then return false end

    claimedBy[vehicle] = source
    return GiveSessionKeys(source, vehicle, true) or false
end

lib.callback.register('f_vehiclekeys:server:giveKeys', function(source, netId)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle or not IsPlayerNearVehicle(source, vehicle, config.lockDistance) then return end
    -- only the owner's first key; never a replacement for a lost key
    local vehicleId, owner = GetOwnedVehicleInfo(vehicle)
    if not vehicleId or owner ~= getCitizenId(source) then return end
    return issueFirstKey(source, vehicle, vehicleId)
end)

AddStateBagChangeHandler('vehicleid', '', function(bagName, _, vehicleId)
    local vehicle = GetEntityFromStateBagName(bagName)
    if not vehicle or vehicle == 0 or not vehicleId then return end
    local owner = exports.f_vehicles:GetPlayerVehicle(vehicleId)?.citizenid
    if not owner then return end
    Entity(vehicle).state:set('owner', owner, true)

    CreateThread(function()
        local data = getKeyData(vehicleId)
        if not DoesEntityExist(vehicle) then return end
        setKeyState(vehicle, vehicleId, data.version)
        Entity(vehicle).state:set('securityTier', data.tier, true)

        if data.version > 0 then
            local ownerPlayer = exports.qbx_core:GetPlayerByCitizenId(owner)
            if ownerPlayer then
                refreshKeyDetails(ownerPlayer.PlayerData.source, vehicle, KeyId(vehicleId, data.version))
            end
        end
    end)
end)
