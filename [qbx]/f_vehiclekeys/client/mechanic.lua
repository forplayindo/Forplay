local sharedConfig = require 'config.shared'
local duplicateConfig = sharedConfig.duplicate
local securityConfig = sharedConfig.security

local busy = false

---@param duration integer
---@param label string
---@param anim {dict: string, clip: string}
---@return boolean completed
local function runProgress(duration, label, anim)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = anim.dict, clip = anim.clip, flag = 1 },
    })
end

---The server checks job, distance, owner and the key blank at both start and finish,
---and the key is always given to the vehicle owner.
---@param vehicle number
local function duplicateKey(vehicle)
    if busy then return end
    busy = true

    if lib.callback.await('f_vehiclekeys:server:startDuplicate', false, VehToNet(vehicle)) then
        TaskTurnPedToFaceEntity(cache.ped, vehicle, 1000)
        Wait(1000)
        if runProgress(duplicateConfig.duration, locale('progress.duplicating_key'), duplicateConfig.anim) then
            lib.callback.await('f_vehiclekeys:server:finishDuplicate', false)
        end
    end

    busy = false
end

---@param vehicle number
local function upgradeSecurity(vehicle)
    if busy then return end
    busy = true

    local upgrade = lib.callback.await('f_vehiclekeys:server:startUpgrade', false, VehToNet(vehicle))
    if upgrade then
        TaskTurnPedToFaceEntity(cache.ped, vehicle, 1000)
        Wait(1000)
        if runProgress(upgrade.duration, locale('progress.upgrading_security', upgrade.label), securityConfig.anim) then
            lib.callback.await('f_vehiclekeys:server:finishUpgrade', false)
        end
    end

    busy = false
end

---@param entity number
---@return boolean
local function isPlayerVehicle(entity)
    return Entity(entity).state.owner ~= nil
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_vehiclekeys:duplicate',
        icon = 'fas fa-key',
        label = locale('target.duplicate_key'),
        distance = 2.5,
        canInteract = function(entity)
            return not busy
                and HasAllowedJob(QBX.PlayerData.job, duplicateConfig.jobs, duplicateConfig.requireOnDuty)
                and isPlayerVehicle(entity)
        end,
        onSelect = function(data)
            duplicateKey(data.entity)
        end,
    },
    {
        name = 'f_vehiclekeys:security',
        icon = 'fas fa-shield-halved',
        label = locale('target.upgrade_security'),
        distance = 2.5,
        canInteract = function(entity)
            return not busy
                and HasAllowedJob(QBX.PlayerData.job, securityConfig.jobs, securityConfig.requireOnDuty)
                and isPlayerVehicle(entity)
                and securityConfig.upgrades[(Entity(entity).state.securityTier or 1) + 1] ~= nil
        end,
        onSelect = function(data)
            upgradeSecurity(data.entity)
        end,
    },
})
