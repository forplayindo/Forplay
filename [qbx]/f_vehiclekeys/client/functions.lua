local config = require 'config.client'
local sharedConfig = require 'config.shared'

---Grants keys for job shared vehicles
---@param vehicle number The entity number of the vehicle.
---@param notify? boolean tell the player when access is refused because they are off duty
---@return boolean? `true` if the vehicle is shared for the player's current job, `nil` if the player has no job or is off duty.
function AreKeysJobShared(vehicle, notify)
    local shared, reason = IsJobSharedVehicle(QBX.PlayerData.job, GetEntityModel(vehicle), GetVehicleClass(vehicle))
    if notify and reason == 'off_duty' then
        exports.qbx_core:Notify(locale('notify.require_on_duty'), 'error')
    end
    return shared
end

---@type table<number, integer> vehicle -> last time the owner's first key was requested
local firstKeyRequested = {}

---Checks if the player holds the physical key (car_key item) of a player vehicle.
---@param vehicle number
---@return boolean
function HasPhysicalKey(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local state = Entity(vehicle).state

    -- player vehicle: `keyid` is a string once a key exists, false when it never had one,
    -- nil while the server is still loading it
    if not state.owner then return false end

    local keyid = state.keyid
    if keyid then
        return exports.ox_inventory:Search('count', sharedConfig.keyItem, { keyid = keyid }) > 0
    end

    -- vehicle owned before physical keys existed: the server hands the owner the first key
    if keyid == false and state.owner == QBX.PlayerData.citizenid then
        local now = GetGameTimer()
        if firstKeyRequested[vehicle] and now - firstKeyRequested[vehicle] < 10000 then return false end
        firstKeyRequested[vehicle] = now
        return lib.callback.await('f_vehiclekeys:server:giveKeys', false, VehToNet(vehicle)) == true
    end
    return false
end

---Checks if player has vehicle keys: a temporary key, or the physical key of a player vehicle.
---@param vehicle number
---@return boolean `true` if player has vehicle keys, `false` otherwise.
function HasKeys(vehicle)
    vehicle = vehicle or cache.vehicle
    if not vehicle or vehicle == 0 then return false end

    local keysList = LocalPlayer.state.keysList
    local sessionId = Entity(vehicle).state.sessionId
    if keysList and sessionId and keysList[sessionId] then
        return true
    end

    return HasPhysicalKey(vehicle)
end

exports('HasKeys', HasKeys)

---Checks if player has vehicle keys of or access to the vehicle is provided as part of his job.
---@param vehicle number The entity number of the vehicle.
---@param notify? boolean
---@return boolean? `true` if player has access to the vehicle, `nil` otherwise.
function GetIsVehicleAccessible(vehicle, notify)
    return HasKeys(vehicle) or AreKeysJobShared(vehicle, notify)
end

---The key remote needs the physical key in the inventory (or job access); temporary keys
---(job, rental, stolen vehicles) still start and drive the vehicle but cannot use the remote.
---@param vehicle number
---@param notify? boolean
---@return boolean?
function CanUseKeyFob(vehicle, notify)
    return HasPhysicalKey(vehicle) or AreKeysJobShared(vehicle, notify)
end

local alertSend = false --Variable strictly related to sendPoliceAlertAttempt, not used elsewhere
function SendPoliceAlertAttempt(crime, vehicle)
    if alertSend then return end
    alertSend = true

    local hoursOffset = (24 + GetClockHours() - config.policeAlertNightStartHour) % 24; --Hour from the start of the night hours
    local chance = hoursOffset > config.policeAlertNightDuration
        and config.policeAlertChance
        or config.policeNightAlertChance

    if math.random() <= chance then
        config.alertPolice(crime, vehicle)
    end

    SetTimeout(config.alertCooldown, function()
        alertSend = false
    end)
end

---Gets bone coords
---@param entity number The entity index.
---@param boneName string The entity bone name.
---@return vector3 `Bone coords` if exists, `entity coords` otherwise.
local function getBoneCoords(entity, boneName)
    local boneIndex = GetEntityBoneIndexByName(entity, boneName)

    return boneIndex ~= -1
        and GetWorldPositionOfEntityBone(entity, boneIndex)
        or GetEntityCoords(entity)
end

---Checks if any of the bones are close enough to the coords
---@param coords vector3
---@param entity number
---@param bones table
---@param maxDistance number
---@return boolean? `true` if bone exists, `nil` otherwise.
local function getIsCloseToAnyBone(coords, entity, bones, maxDistance)
    for i = 1, #bones do
        local boneCoords = getBoneCoords(entity, bones[i])
        if #(coords - boneCoords) < maxDistance then
            return true
        end
    end
end

local doorBones = {'door_dside_f', 'door_dside_r', 'door_pside_f', 'door_pside_r'}

---Runs one theft attempt: the server validates and picks the difficulty, the client plays the
---minigame(s), the server checks the result again.
---@param kind 'lockpick'|'hotwire'
---@param vehicle number
---@param isAdvanced boolean
---@return boolean success
local function runTheft(kind, vehicle, isAdvanced)
    local settings = lib.callback.await('f_vehiclekeys:server:startTheft', false, VehToNet(vehicle), kind, isAdvanced)
    if not settings then return false end

    local modelHash, class = GetEntityModel(vehicle), GetVehicleClass(vehicle)
    local anim = config.anims[kind].model[modelHash]
        or config.anims[kind].class[class]
        or config.anims[kind].default
    lib.playAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, kind == 'lockpick' and 17 or 16, 0, false, false, false)

    local success, reason = true, nil
    if settings.jammer then
        success, reason = RunMinigame('Jammer', settings.jammer)
    end
    if success then
        success, reason = RunMinigame(kind == 'lockpick' and 'Lockpick' or 'Hotwire', settings)
    end
    ClearPedTasks(cache.ped)

    local accepted = lib.callback.await('f_vehiclekeys:server:finishTheft', false, kind, success, reason)
    if not success and reason ~= 'cancelled' then
        SendPoliceAlertAttempt('carjack', vehicle)
        TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
    end
    return accepted == true
end

local islockpickingProcessLocked = false -- lock flag
---Lockpicking the door of the closest locked vehicle.
---@param isAdvancedLockedpick boolean Determines whether an advanced lockpick was used
---@param maxDistance number? The max distance to check.
function LockpickDoor(isAdvancedLockedpick, maxDistance)
    maxDistance = maxDistance or 2
    local pedCoords = GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(pedCoords, maxDistance * 2, false) -- The difference between the door and the center of the vehicle

    if not vehicle then return end

    if GetVehicleDoorLockStatus(vehicle) < 2 then exports.qbx_core:Notify(locale('notify.vehicle_is_unlocked'), 'error') return end

    --- player may attempt to open the lock if:
    if not IsVehicleSeatFree(vehicle, -1) -- no one in the driver's seat
        or not getIsCloseToAnyBone(pedCoords, vehicle, doorBones, maxDistance) -- the player's ped is close enough to the driver's door
        or GetVehicleConfig(vehicle).lockpickImmune
    then return end

    if islockpickingProcessLocked then return end -- start of the critical section
    islockpickingProcessLocked = true -- one call per player at a time

    CreateThread(function()
        if runTheft('lockpick', vehicle, isAdvancedLockedpick) then
            TriggerServerEvent('hud:server:GainStress', math.random(1, 4))
            exports.qbx_core:Notify(locale('notify.vehicle_lockedpick'), 'success')
        else
            exports.qbx_core:Notify(locale('notify.failed_lockedpick'), 'error')
        end

        Wait(config.lockpickCooldown)
        islockpickingProcessLocked = false -- end of the critical section
    end)
end

local isHotwiringProcessLocked = false -- lock flag
---Hotwiring the vehicle the player sits in.
---@param vehicle number The entity number of the vehicle.
---@param isAdvancedLockedpick boolean Determines whether an advanced lockpick was used
function Hotwire(vehicle, isAdvancedLockedpick)
    if cache.seat ~= -1 or GetIsVehicleAccessible(vehicle) then return end

    if isHotwiringProcessLocked then return end -- start of the critical section
    isHotwiringProcessLocked = true -- one call per player at a time

    CreateThread(function()
        if runTheft('hotwire', vehicle, isAdvancedLockedpick) then
            exports.qbx_core:Notify(locale('notify.hotwired'), 'success')
        else
            exports.qbx_core:Notify(locale('notify.failed_lockedpick'), 'error')
        end

        Wait(config.hotwireCooldown)
        isHotwiringProcessLocked = false -- end of the critical section
    end)
end
