local config = require 'config.client'
local sharedConfig = require 'config.shared'

---The vehicle the player sits in, otherwise the closest vehicle in remote range the player
---holds the key item (or has job access) for.
---@return number? vehicle
local function getKeyFobVehicle()
    if cache.vehicle then
        return CanUseKeyFob(cache.vehicle, true) and cache.vehicle or nil
    end

    local coords = GetEntityCoords(cache.ped)
    local vehicles = lib.getNearbyVehicles(coords, config.keyFobDistance, true)
    table.sort(vehicles, function(a, b)
        return #(a.coords - coords) < #(b.coords - coords)
    end)

    for i = 1, #vehicles do
        local vehicle = vehicles[i].vehicle
        if CanUseKeyFob(vehicle) then
            return vehicle
        end
    end
end

---@type table<number, true> display vehicles inside a garage interior (f_vipgarage), only sat in to pick them
local garageDisplayVehicles = {}

AddEventHandler('f_vehiclekeys:client:garageDisplayVehicle', function(vehicle)
    if type(vehicle) ~= 'number' or not DoesEntityExist(vehicle) then return end
    garageDisplayVehicles[vehicle] = true
    -- forget it once the garage deletes it
    CreateThread(function()
        while DoesEntityExist(vehicle) do Wait(2000) end
        garageDisplayVehicles[vehicle] = nil
    end)
end)

---if the player does not have ignition access to the vehicle:
---check whether to give keys if engine is on
---disable the engine and listen for search keys if applicable to the vehicle
local function onEnteringDriverSeat()
    local vehicle = cache.vehicle
    EngineBind:disable(false)
    CreateThread(function()
        while cache.seat == -1 do
            if IsControlJustPressed(0, 23) then -- vehicle enter/leave input
                EngineBind:disable(true)
            end
            Wait(0)
        end
    end)
    local vehicleConfig = GetVehicleConfig(vehicle)
    if vehicleConfig.shared then return end
    if garageDisplayVehicles[vehicle] then return end

    local isVehicleAccessible = GetIsVehicleAccessible(vehicle)
    if isVehicleAccessible then return end

    local isVehicleRunning = GetIsVehicleEngineRunning(vehicle)
    if config.getKeysWhenEngineIsRunning and isVehicleRunning then
        lib.print.debug("giving keys because engine is running")
        TriggerServerEvent('f_vehiclekeys:server:playerEnteredVehicleWithEngineOn', VehToNet(vehicle))
        return
    end

    lib.print.debug("player does not have access to vehicle ignition. Disabling engine.")
    SetVehicleNeedsToBeHotwired(vehicle, false)
    CreateThread(function()
        local nextCheck = 0
        while not isVehicleAccessible and cache.seat == -1 do
            SetVehicleEngineOn(vehicle, false, true, true)
            DisableControlAction(0, 71, true)
            Wait(0)
            -- the key check reads the inventory, so it runs twice a second instead of every frame
            if GetGameTimer() >= nextCheck then
                nextCheck = GetGameTimer() + 500
                isVehicleAccessible = GetIsVehicleAccessible(vehicle)
            end
        end
        if lib.progressActive() then
            lib.cancelProgress()
        end
        DisableKeySearch()
    end)

    -- player vehicles use physical keys, there is nothing to find inside them
    if vehicleConfig.findKeysChance ~= 0.0 and not Entity(vehicle).state.owner then
        EnableKeySearch()
    end
end

lib.onCache('seat', function(newSeat)
    if newSeat ~= -1 then return end
    Wait(0) -- needed to update cache.seat
    onEnteringDriverSeat()
end)

lib.onCache('vehicle', function(vehicle)
    if not vehicle then return end
    SetVehicleKeepEngineOnWhenAbandoned(vehicle, config.keepEngineOnWhenAbandoned)
end)

-----------------------
------ Key Binds ------
-----------------------

local togglelocksBind
togglelocksBind = lib.addKeybind({
    name = 'togglelocks',
    description = locale('info.toggle_locks'),
    defaultKey = 'L',
    onPressed = function()
        -- the remote stays usable while walking, so the same key hides it again
        if IsKeyFobOpen() then
            return CloseKeyFob()
        end

        togglelocksBind:disable(true)
        local vehicle = getKeyFobVehicle()
        if vehicle then
            OpenKeyFobForVehicle(vehicle)
        else
            exports.qbx_core:Notify(locale('notify.no_keys_nearby'), 'error')
        end
        Wait(500)
        togglelocksBind:disable(false)
    end
})

local function toggleEngine(vehicle)
    if not GetIsVehicleAccessible(vehicle) then return end
    local engineOn = GetIsVehicleEngineRunning(vehicle)

    local vehicleModel = GetEntityModel(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)
    local anim = config.anims.toggleEngine.model[vehicleModel]
        or config.anims.toggleEngine.class[vehicleClass]
        or config.anims.toggleEngine.default
    if next(anim) then
        lib.playAnim(cache.ped, anim.dict, anim.clip, 8.0, 8.0,-1, 48, 0)
        Wait(0)
        CreateThread(function()
            while IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) do
                if IsControlJustPressed(0, 23) then -- enter/exit vehicle input
                    ClearPedTasks(cache.ped)
                    return
                end
                Wait(0)
            end
        end)

        --- aethestic wait so that the engine toggles when the player appears to touch the button/key
        Wait(anim.delay or 0)
    end

    if cache.vehicle then
        SetVehicleEngineOn(vehicle, not engineOn, false, true)
    end
end

EngineBind = lib.addKeybind({
    name = 'toggleengine',
    description = locale('info.engine'),
    defaultKey = config.keySearchBind,
    onPressed = function()
        if cache.seat == -1 then
            EngineBind:disable(true)
            toggleEngine(cache.vehicle)
            Wait(1000)
            EngineBind:disable(false)
        end
    end
})

-----------------------
---- Client Events ----
-----------------------

local isTakingKeys = false
RegisterNetEvent('QBCore:Client:VehicleInfo', function(data)
    if not LocalPlayer.state.isLoggedIn or data.event ~= 'Entering' then return end
    local vehicleConfig = GetVehicleConfig(data.vehicle)
    if vehicleConfig.noLock or isTakingKeys then return end
    isTakingKeys = true
    local driver = GetPedInVehicleSeat(data.vehicle, -1)

    if driver ~= 0 and IsEntityDead(driver) and not (vehicleConfig.carjackingImmune or IsPedAPlayer(driver)) then
        TriggerServerEvent('f_vehiclekeys:server:unlockDeadDriver', data.netId)
        if lib.progressCircle({
            duration = 2500,
            label = locale('progress.takekeys'),
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
            },
        }) then
            TriggerServerEvent('f_vehiclekeys:server:tookKeys', VehToNet(data.vehicle))
        end
    end
    isTakingKeys = false
end)

RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
    local vehicle = cache.vehicle
    if vehicle then
        if GetKeySearchEnabled() then
            DisableKeySearch()
            Hotwire(vehicle, isAdvanced)
            EnableKeySearch()
        else
            Hotwire(vehicle, isAdvanced)
        end
    else
        LockpickDoor(isAdvanced)
    end
end)

RegisterNetEvent('f_vehiclekeys:client:OnLostKeys', function()
    if cache.seat == -1 then
        onEnteringDriverSeat()
    end
end)

for _, info in pairs(sharedConfig.sharedKeys) do
    if info.enableAutolock then
        lib.onCache('vehicle', function (vehicle)
            local leftVehicle = cache.vehicle
            if not vehicle and leftVehicle then
                local isShared = AreKeysJobShared(leftVehicle)
                local isAutolockEnabled = sharedConfig.sharedKeys[QBX.PlayerData.job.name]?.enableAutolock

                if isShared and isAutolockEnabled then
                    TriggerServerEvent('f_vehiclekeys:server:setLockState', NetworkGetNetworkIdFromEntity(leftVehicle), true)
                end
            end
        end)
        break
    end
end

local isExitGuardRunning = false

---GTA only locks doors from the outside. While the player sits in a locked vehicle the exit key is
---blocked until it is unlocked. Runs only in that situation, and stops once unlocked or outside.
---@param vehicle number
local function guardLockedExit(vehicle)
    if isExitGuardRunning then return end
    isExitGuardRunning = true

    CreateThread(function()
        local nextNotify = 0
        while cache.vehicle == vehicle and GetVehicleDoorLockStatus(vehicle) >= 2 and not IsEntityDead(vehicle) do
            DisableControlAction(0, 75, true) -- exit vehicle
            if IsDisabledControlJustPressed(0, 75) and GetGameTimer() >= nextNotify then
                nextNotify = GetGameTimer() + 2000
                exports.qbx_core:Notify(locale('notify.locked_inside'), 'error')
            end
            Wait(0)
        end
        isExitGuardRunning = false
    end)
end

qbx.entityStateHandler('doorslockstate', function(entity, _, value)
    if entity == 0 then return end
    SetVehicleDoorsLocked(entity, value)
    if value >= 2 and entity == cache.vehicle then
        guardLockedExit(entity)
    end
end)

-- also when entering (or spawning into) a vehicle that is already locked
lib.onCache('vehicle', function(vehicle)
    if not vehicle then return end
    SetTimeout(500, function()
        if cache.vehicle == vehicle and GetVehicleDoorLockStatus(vehicle) >= 2 then
            guardLockedExit(vehicle)
        end
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    if cache.seat == -1 then
        onEnteringDriverSeat()
    end
end)

---@type table<number, integer> vehicle -> time the initial lock state was requested
local lockStateRequested = {}

---The server rolls whether an NPC vehicle starts locked, the client only asks once per vehicle.
local function onVehicleAttemptToEnter(vehicle)
    local state = Entity(vehicle).state
    if state.doorslockstate or state.owner or garageDisplayVehicles[vehicle] then return end
    if not NetworkGetEntityIsNetworked(vehicle) then return end

    local ped = GetPedInVehicleSeat(vehicle, -1)
    if IsPedAPlayer(ped) then return end

    local now = GetGameTimer()
    if lockStateRequested[vehicle] and now - lockStateRequested[vehicle] < 5000 then return end
    lockStateRequested[vehicle] = now
    TriggerServerEvent('f_vehiclekeys:server:initLockState', NetworkGetNetworkIdFromEntity(vehicle))
end

local isLoggedIn = false

local function playerEnterVehLoop()
    CreateThread(function()
        while isLoggedIn do
            local vehicle = GetVehiclePedIsTryingToEnter(cache.ped)
            if vehicle ~= 0 then
                onVehicleAttemptToEnter(vehicle)
            end
            Wait(100)
        end
    end)
end

CreateThread(function()
    if LocalPlayer.state.isLoggedIn then
        playerEnterVehLoop()
    end
end)

AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(cache.serverId), function(_, _, value)
    isLoggedIn = value
    if not value then return end
    playerEnterVehLoop()
end)
