local sharedConfig = require 'config.shared'

local MAX_PLACE_DIST = 4.0  -- jarak maks titik pasang dari pemain (meter)
local MAX_REMOVE_DIST = 6.0 -- jarak maks pemain ke objek saat mengambil (meter)
local COOLDOWN = 2000       -- jeda antar pasang/ambil per pemain (ms)

local lastAction = {}

---Hanya polisi on-duty, dengan jeda antar aksi (anti spam executor)
---@param src number
---@return boolean ok
---@return string? error
local function canAct(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not IsLeoAndOnDuty(player) then return false, 'error.on_duty_police_only' end

    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < COOLDOWN then return false, 'error.too_fast' end
    lastAction[src] = now

    return true
end

---@param src number
---@param coords vector3
---@param maxDist number
---@return boolean
local function isNear(src, coords, maxDist)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords) <= maxDist
end

---Spawns object
---@param objects table
---@param modelHash number
---@param coords vector4
---@param zOffset number
---@param isFixed boolean?
---@return number? netid
local function spawnObject(objects, modelHash, coords, zOffset, isFixed)
    local object = CreateObject(modelHash, coords.x, coords.y, coords.z - zOffset, true, true, false)
    SetEntityHeading(object, coords.w)
    FreezeEntityPosition(object, true)

    local exists = lib.waitFor(function ()
        if DoesEntityExist(object) then return true end
    end, ('Failed to spawn prop %s'):format(modelHash), sharedConfig.timeout)

    if exists then
        local netid = NetworkGetNetworkIdFromEntity(object)
        objects[#objects+1] = netid
        if isFixed then
            local coordsState = GlobalState.fixedCoords
            coordsState[netid] = GetEntityCoords(object)
            GlobalState.fixedCoords = coordsState
        end

        return netid
    end
end

---@param objects table
---@param netid number
---@return boolean removed
local function despawnObject(objects, netid)
    for i = 1, #objects do
        if objects[i] == netid then
            local entity = NetworkGetEntityFromNetworkId(netid)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            objects[i] = objects[#objects]
            objects[#objects] = nil
            return true
        end
    end
    return false
end

---Spawns spike strip
---@param coords vector3
---@param heading number
lib.callback.register('police:server:spawnSpikeStrip', function(source, coords, heading)
    if type(coords) ~= 'vector3' or type(heading) ~= 'number' then return nil, 'error.canceled' end

    local ok, err = canAct(source)
    if not ok then return nil, err end

    local spikeStrips = GlobalState.spikeStrips
    if #spikeStrips >= sharedConfig.maxSpikes then return nil, 'error.no_spikestripe' end
    if not isNear(source, coords, MAX_PLACE_DIST) then return nil, 'error.too_far' end

    local netid = spawnObject(spikeStrips, `P_ld_stinger_s`, vector4(coords.x, coords.y, coords.z, heading), 1, true)
    if not netid then return nil, 'error.canceled' end
    GlobalState.spikeStrips = spikeStrips

    return netid
end)

---Spawns police object
---@param item string key dari `objects` di config/shared.lua
---@param coords vector3
---@param heading number
lib.callback.register('police:server:spawnObject', function(source, item, coords, heading)
    local objectConfig = type(item) == 'string' and sharedConfig.objects[item]
    if not objectConfig or type(coords) ~= 'vector3' or type(heading) ~= 'number' then return nil, 'error.canceled' end

    local ok, err = canAct(source)
    if not ok then return nil, err end

    local policeObjects = GlobalState.policeObjects
    if #policeObjects >= sharedConfig.maxObjects then return nil, 'error.too_many_objects' end
    if not isNear(source, coords, MAX_PLACE_DIST) then return nil, 'error.too_far' end

    local netid = spawnObject(policeObjects, objectConfig.model, vector4(coords.x, coords.y, coords.z, heading), 0.3)
    if not netid then return nil, 'error.canceled' end
    GlobalState.policeObjects = policeObjects

    return netid
end)

RegisterNetEvent('police:server:despawnSpikeStrip', function(netid)
    local src = source
    if type(netid) ~= 'number' or not canAct(src) then return end

    local fixedCoords = GlobalState.fixedCoords
    local coords = fixedCoords[netid]
    if not coords or not isNear(src, coords, MAX_REMOVE_DIST) then return end

    local spikeStrips = GlobalState.spikeStrips
    if not despawnObject(spikeStrips, netid) then return end
    GlobalState.spikeStrips = spikeStrips

    fixedCoords[netid] = nil
    GlobalState.fixedCoords = fixedCoords
end)

RegisterNetEvent('police:server:despawnObject', function(netid)
    local src = source
    if type(netid) ~= 'number' or not canAct(src) then return end

    local entity = NetworkGetEntityFromNetworkId(netid)
    if DoesEntityExist(entity) and not isNear(src, GetEntityCoords(entity), MAX_REMOVE_DIST) then return end

    local policeObjects = GlobalState.policeObjects
    if not despawnObject(policeObjects, netid) then return end
    GlobalState.policeObjects = policeObjects
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

AddEventHandler('onResourceStart', function (resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    GlobalState.spikeStrips = {}
    GlobalState.policeObjects = {}
    GlobalState.fixedCoords = {}
end)

AddEventHandler('onResourceStop', function (resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    local spikeStrips = GlobalState.spikeStrips
    for i = 1, #spikeStrips do
        DeleteEntity(NetworkGetEntityFromNetworkId(spikeStrips[i]))
    end

    local policeObjects = GlobalState.policeObjects
    for i = 1, #policeObjects do
        DeleteEntity(NetworkGetEntityFromNetworkId(policeObjects[i]))
    end

    GlobalState.spikeStrips = nil
    GlobalState.policeObjects = nil
    GlobalState.fixedCoords = nil
end)
