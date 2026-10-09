local config = require 'config.server'
local sharedConfig = require 'config.shared'
local theftConfig = sharedConfig.theft

-- Every timed action (lockpick, hotwire, duplicate, security upgrade) is started through the server,
-- which validates it and remembers when it started. The finish is only accepted for that same
-- action and vehicle, and not earlier than the action can really take, so skipping the minigame
-- or progress bar with a forged event does nothing.

---@class PendingAction
---@field action string
---@field vehicle number
---@field startedAt integer
---@field minTime integer
---@field data table

---@type table<integer, PendingAction>
local pending = {}
---@type table<integer, integer>
local lastTheft = {}

AddEventHandler('playerDropped', function()
    pending[source] = nil
    lastTheft[source] = nil
end)

---@param src integer
---@param action string
---@param vehicle number
---@param minTime integer
---@param data? table
local function startAction(src, action, vehicle, minTime, data)
    pending[src] = { action = action, vehicle = vehicle, startedAt = GetGameTimer(), minTime = minTime, data = data or {} }
end

---@param src integer
---@param action string
---@return PendingAction?
local function takeAction(src, action)
    local entry = pending[src]
    pending[src] = nil
    if not entry or entry.action ~= action or not DoesEntityExist(entry.vehicle) then return end
    if GetGameTimer() - entry.startedAt < entry.minTime then return end
    return entry
end

---@param src integer
---@return {name: string, onduty: boolean}?
local function getJob(src)
    return exports.qbx_core:GetPlayer(src)?.PlayerData.job
end

---@param src integer
---@param item string
---@return boolean
local function hasItem(src, item)
    return exports.ox_inventory:Search(src, 'count', item) > 0
end

-------------------
---- Alarm ----
-------------------

---@param vehicle number
local function triggerAlarm(vehicle)
    if not theftConfig.alarm.enabled then return end

    local netOwner = NetworkGetEntityOwner(vehicle)
    if netOwner and netOwner > 0 then
        TriggerClientEvent('f_vehiclekeys:client:alarm', netOwner, NetworkGetNetworkIdFromEntity(vehicle), theftConfig.alarm.duration)
    end

    if theftConfig.alarm.notifyOwner then
        local _, owner = GetOwnedVehicleInfo(vehicle)
        local ownerPlayer = owner and exports.qbx_core:GetPlayerByCitizenId(owner)
        if ownerPlayer then
            exports.qbx_core:Notify(ownerPlayer.PlayerData.source, locale('notify.alarm_owner', qbx.getVehiclePlate(vehicle)), 'error')
        end
    end
end

-------------------
---- Theft ----
-------------------

---@param src integer
---@param netId integer
---@param kind 'lockpick'|'hotwire'
---@param advanced boolean
---@return table? minigame settings, or nil when not allowed
lib.callback.register('f_vehiclekeys:server:startTheft', function(src, netId, kind, advanced)
    if kind ~= 'lockpick' and kind ~= 'hotwire' then return end
    advanced = advanced == true

    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle then return end

    local now = GetGameTimer()
    if lastTheft[src] and now - lastTheft[src] < theftConfig.cooldown then
        exports.qbx_core:Notify(src, locale('notify.theft_cooldown'), 'error')
        return
    end

    local toolItem = advanced and 'advancedlockpick' or 'lockpick'
    if not hasItem(src, toolItem) then return end

    if kind == 'lockpick' then
        if not IsPlayerNearVehicle(src, vehicle, config.theftDistance) then return end
        if (Entity(vehicle).state.doorslockstate or GetVehicleDoorLockStatus(vehicle)) < 2 then return end
        if GetPedInVehicleSeat(vehicle, -1) ~= 0 then return end
        if GetVehicleConfig(vehicle).lockpickImmune then return end
    else
        if GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then return end
        if CanAccessVehicle(src, vehicle) then return end
    end

    local tier = GetSecurityTier(vehicle)
    local difficulty = GetTheftDifficulty(exports.qbx_core:GetVehicleClass(GetEntityModel(vehicle)), tier, advanced)
    if not difficulty then
        exports.qbx_core:Notify(src, locale('notify.cannot_steal'), 'error')
        return
    end

    local jammer = NeedsJammer(difficulty, tier)
    if jammer and not hasItem(src, theftConfig.jammer.item) then
        exports.qbx_core:Notify(src, locale('notify.need_jammer'), 'error')
        return
    end

    lastTheft[src] = now
    local minTime = (kind == 'lockpick' and theftConfig.minLockpickTime or theftConfig.minHotwireTime)
        + (jammer and theftConfig.minJammerTime or 0)
    startAction(src, kind, vehicle, minTime, { tool = toolItem, jammer = jammer })

    if tier >= theftConfig.alarm.onStartMinTier then
        triggerAlarm(vehicle)
    end

    local settings = theftConfig.difficulties[difficulty]
    return {
        difficulty = difficulty,
        pins = settings.pins,
        timeLimit = kind == 'lockpick' and settings.timeLimit or theftConfig.hotwireTimes[difficulty],
        jammer = jammer and { difficulty = theftConfig.jammer.difficulty, timeLimit = theftConfig.jammer.timeLimit } or nil,
    }
end)

---@param src integer
---@param kind 'lockpick'|'hotwire'
---@param success boolean
---@param reason? string
---@return boolean
lib.callback.register('f_vehiclekeys:server:finishTheft', function(src, kind, success, reason)
    if kind ~= 'lockpick' and kind ~= 'hotwire' then return false end

    if not success then
        local entry = pending[src]
        pending[src] = nil
        if not entry or entry.action ~= kind or reason == 'cancelled' then return false end
        if not DoesEntityExist(entry.vehicle) then return false end

        local vehicleConfig = GetVehicleConfig(entry.vehicle)
        local breakChance = entry.data.tool == 'advancedlockpick' and vehicleConfig.removeAdvancedLockpickChance or vehicleConfig.removeNormalLockpickChance
        if reason == 'broken' or math.random() <= breakChance then
            exports.ox_inventory:RemoveItem(src, entry.data.tool, 1)
        end
        if theftConfig.alarm.onFail then
            triggerAlarm(entry.vehicle)
        end
        return false
    end

    local entry = takeAction(src, kind)
    if not entry then return false end
    local vehicle = entry.vehicle

    if kind == 'lockpick' then
        if not IsPlayerNearVehicle(src, vehicle, config.theftDistance) then return false end
    elseif GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(src) then
        return false
    end

    -- the jammer is used up when a jammer-protected vehicle is bypassed
    if entry.data.jammer and not exports.ox_inventory:RemoveItem(src, theftConfig.jammer.item, 1) then return false end

    if kind == 'lockpick' then
        SetLockState(vehicle, 'unlock')
    else
        GiveSessionKeys(src, vehicle)
        -- rep wilayah gang (f_crew mencari zonanya dari posisi pemain di server)
        if GetResourceState('f_crew') == 'started' then
            pcall(function() exports.f_crew:AddTurfActivity(src, 'carjacking') end)
        end
    end
    return true
end)

-------------------------
---- Security upgrade ----
-------------------------

---@param src integer
---@param vehicle number
---@return integer? vehicleId, integer? nextTier, string? error locale key
local function validateUpgrade(src, vehicle)
    local securityConfig = sharedConfig.security
    if not HasAllowedJob(getJob(src), securityConfig.jobs, securityConfig.requireOnDuty) then return nil, nil, 'notify.wrong_job' end
    if not IsPlayerNearVehicle(src, vehicle, config.theftDistance) then return nil, nil, 'notify.vehicle_not_near' end

    local vehicleId = GetOwnedVehicleInfo(vehicle)
    if not vehicleId then return nil, nil, 'notify.not_player_vehicle' end

    local nextTier = GetSecurityTier(vehicle) + 1
    local upgrade = securityConfig.upgrades[nextTier]
    if not upgrade then return nil, nil, 'notify.security_maxed' end
    if not hasItem(src, upgrade.item) then return nil, nil, 'notify.missing_item' end
    return vehicleId, nextTier
end

lib.callback.register('f_vehiclekeys:server:startUpgrade', function(src, netId)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle then return end

    local vehicleId, nextTier, err = validateUpgrade(src, vehicle)
    if not vehicleId then
        exports.qbx_core:Notify(src, locale(err), 'error')
        return
    end

    local duration = sharedConfig.security.upgrades[nextTier].duration
    startAction(src, 'upgrade', vehicle, duration - 1000, { tier = nextTier })
    return { duration = duration, label = sharedConfig.security.upgrades[nextTier].label }
end)

lib.callback.register('f_vehiclekeys:server:finishUpgrade', function(src)
    local entry = takeAction(src, 'upgrade')
    if not entry then return false end

    local vehicleId, nextTier, err = validateUpgrade(src, entry.vehicle)
    if not vehicleId or nextTier ~= entry.data.tier then
        if err then exports.qbx_core:Notify(src, locale(err), 'error') end
        return false
    end
    if not exports.ox_inventory:RemoveItem(src, sharedConfig.security.upgrades[nextTier].item, 1) then return false end

    SetSecurityTier(entry.vehicle, vehicleId, nextTier)
    exports.qbx_core:Notify(src, locale('notify.security_upgraded', sharedConfig.security.labels[nextTier]), 'success')
    return true
end)

---------------------------
---- Key duplication ----
---------------------------

---@param src integer
---@param vehicle number
---@return integer? vehicleId, integer? ownerSource, string? error locale key
local function validateDuplicate(src, vehicle)
    local duplicateConfig = sharedConfig.duplicate
    if not HasAllowedJob(getJob(src), duplicateConfig.jobs, duplicateConfig.requireOnDuty) then return nil, nil, 'notify.wrong_job' end
    if not IsPlayerNearVehicle(src, vehicle, config.theftDistance) then return nil, nil, 'notify.vehicle_not_near' end

    local vehicleId, owner = GetOwnedVehicleInfo(vehicle)
    if not vehicleId then return nil, nil, 'notify.not_player_vehicle' end

    -- the key always goes to the registered owner, never to whoever asked for it
    local ownerPlayer = exports.qbx_core:GetPlayerByCitizenId(owner)
    if not ownerPlayer then return nil, nil, 'notify.owner_not_near' end
    local ownerSource = ownerPlayer.PlayerData.source
    if not IsPlayerNearVehicle(ownerSource, vehicle, duplicateConfig.ownerDistance) then return nil, nil, 'notify.owner_not_near' end

    if not hasItem(src, duplicateConfig.requiredItem) then return nil, nil, 'notify.missing_key_blank' end
    return vehicleId, ownerSource
end

lib.callback.register('f_vehiclekeys:server:startDuplicate', function(src, netId)
    local vehicle = GetVehicleFromNetId(netId)
    if not vehicle then return end

    local vehicleId, _, err = validateDuplicate(src, vehicle)
    if not vehicleId then
        exports.qbx_core:Notify(src, locale(err), 'error')
        return
    end

    startAction(src, 'duplicate', vehicle, sharedConfig.duplicate.duration - 1000)
    return true
end)

lib.callback.register('f_vehiclekeys:server:finishDuplicate', function(src)
    local entry = takeAction(src, 'duplicate')
    if not entry then return false end

    local vehicleId, ownerSource, err = validateDuplicate(src, entry.vehicle)
    if not vehicleId or not ownerSource then
        if err then exports.qbx_core:Notify(src, locale(err), 'error') end
        return false
    end

    if not exports.ox_inventory:CanCarryItem(ownerSource, sharedConfig.keyItem, 1) then
        exports.qbx_core:Notify(src, locale('notify.owner_inventory_full'), 'error')
        return false
    end
    if not exports.ox_inventory:RemoveItem(src, sharedConfig.duplicate.requiredItem, 1) then return false end
    if not RekeyVehicle(ownerSource, entry.vehicle, vehicleId) then return false end

    -- masuk tagihan kendaraan di f_mechanicjob (tab Tagihan, harga dari Master Harga)
    if GetResourceState('f_mechanicjob') == 'started' then
        exports.f_mechanicjob:RecordService(src, entry.vehicle, 'keydup')
    end

    local plate = qbx.getVehiclePlate(entry.vehicle)
    exports.qbx_core:Notify(src, locale('notify.duplicate_done', plate), 'success')
    exports.qbx_core:Notify(ownerSource, locale('notify.duplicate_received', plate), 'success')
    return true
end)
