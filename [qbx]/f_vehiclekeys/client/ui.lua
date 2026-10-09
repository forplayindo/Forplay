local config = require 'config.client'

-- UI texts live under the `ui` locale namespace; the web UI expects them without the prefix
RegisterNUICallback('getLocales', function(_, cb)
    local texts = {}
    for key, value in pairs(lib.getLocales()) do
        local name = key:match('^ui%.(.+)$')
        if name then texts[name] = value end
    end
    cb(texts)
end)

--------------------
---- Minigames ----
--------------------

---@type {name: string, promise: table}?
local activeGame
---@type string? minigame whose result screen is still showing
local shownGame

---Shows a minigame (Lockpick, Hotwire or Jammer) and waits for its result.
---@param name 'Lockpick'|'Hotwire'|'Jammer'
---@param data table
---@return boolean success, string? reason
function RunMinigame(name, data)
    if activeGame then return false, 'cancelled' end
    -- minigames need the full keyboard, so an open remote is closed first
    if IsKeyFobOpen() then CloseKeyFob() end
    if shownGame and shownGame ~= name then
        SendNUIMessage({ action = 'setVisible' .. shownGame, data = false })
    end
    shownGame = name

    local p = promise.new()
    activeGame = { name = name, promise = p }
    SendNUIMessage({ action = 'setVisible' .. name, data = true })
    SendNUIMessage({ action = 'start' .. name, data = data })
    SetNuiFocus(true, true)

    local result = Citizen.Await(p)
    return result.success == true, result.reason
end

---@param name string
---@param result table
local function finishMinigame(name, result)
    local game = activeGame
    if not game or game.name ~= name then return end
    activeGame = nil
    SetNuiFocus(false, false)
    game.promise:resolve(type(result) == 'table' and result or {})

    -- let the result screen show for a moment
    SetTimeout(1500, function()
        if shownGame ~= name or (activeGame and activeGame.name == name) then return end
        shownGame = nil
        SendNUIMessage({ action = 'setVisible' .. name, data = false })
    end)
end

for _, name in ipairs({ 'Lockpick', 'Hotwire', 'Jammer' }) do
    RegisterNUICallback(name:lower() .. 'Result', function(data, cb)
        cb(1)
        finishMinigame(name, data)
    end)
end

-------------------
---- Key fob ----
-------------------

-- car key item details: vehicle name above the plate (an array keeps this order)
exports.ox_inventory:displayMetadata({
    { vehicle = locale('info.key_vehicle') },
    { plate = locale('info.key_plate') },
})

---@type string?
local fobPlate

---@param plate string
---@return number? vehicle
local function getFobVehicle(plate)
    if type(plate) ~= 'string' or plate ~= fobPlate then return end
    local vehicles = lib.getNearbyVehicles(GetEntityCoords(cache.ped), config.keyFobDistance, true)
    for i = 1, #vehicles do
        local vehicle = vehicles[i].vehicle
        if qbx.getVehiclePlate(vehicle) == plate then
            return vehicle
        end
    end
end

---@param vehicle number
---@return boolean
local function requestControl(vehicle)
    if NetworkHasControlOfEntity(vehicle) then return true end
    local timeout = GetGameTimer() + 1000
    repeat
        NetworkRequestControlOfEntity(vehicle)
        Wait(0)
    until NetworkHasControlOfEntity(vehicle) or GetGameTimer() > timeout
    return NetworkHasControlOfEntity(vehicle)
end

---@param vehicle number
---@param flashes integer
local function flashLights(vehicle, flashes)
    CreateThread(function()
        for _ = 1, flashes do
            SetVehicleLights(vehicle, 2)
            SetVehicleIndicatorLights(vehicle, 0, true)
            SetVehicleIndicatorLights(vehicle, 1, true)
            Wait(250)
            SetVehicleLights(vehicle, 0)
            SetVehicleIndicatorLights(vehicle, 0, false)
            SetVehicleIndicatorLights(vehicle, 1, false)
            Wait(250)
        end
    end)
end

local fobOpen = false

-- camera look, shooting, melee, weapon wheel and the pause menu (ESC closes the remote instead)
local blockedWhileFobOpen = { 1, 2, 24, 25, 37, 106, 140, 141, 142, 143, 199, 200, 257, 263 }

---@return boolean
function IsKeyFobOpen()
    return fobOpen
end

function CloseKeyFob()
    fobPlate = nil
    if not fobOpen then return end
    fobOpen = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setVisibleApp', data = false })
end

---@param vehicle number
---@param plate string
local function showKeyFob(vehicle, plate)
    fobPlate = plate
    -- the UI closes the remote with the key that opens it, and gets in/out of the vehicle with
    -- the enter vehicle key (both follow the player's own bindings)
    SendNUIMessage({ action = 'setVisibleApp', data = true })
    SendNUIMessage({ action = 'setData', data = { plate = plate, isLocked = GetVehicleDoorLockStatus(vehicle) >= 2 } })
    -- like a phone: the cursor clicks the remote while the player keeps walking / driving
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    if fobOpen then return end
    fobOpen = true
    CreateThread(function()
        while fobOpen do
            for i = 1, #blockedWhileFobOpen do
                DisableControlAction(0, blockedWhileFobOpen[i], true)
            end
            Wait(0)
        end
    end)
end

---Opens the remote for a vehicle the player already has access to (L keybind).
---@param vehicle number
function OpenKeyFobForVehicle(vehicle)
    local plate = qbx.getVehiclePlate(vehicle)
    if not plate then return end
    showKeyFob(vehicle, plate)
end

---Opens the remote from a used key item.
---@param plate? string
local function openKeyFob(plate)
    if type(plate) ~= 'string' or plate == '' then return end
    fobPlate = plate

    local vehicle = getFobVehicle(plate)
    if not vehicle then
        fobPlate = nil
        return exports.qbx_core:Notify(locale('notify.no_vehicle_found'), 'error')
    end
    if not HasPhysicalKey(vehicle) then
        fobPlate = nil
        return exports.qbx_core:Notify(locale('notify.key_not_working'), 'error')
    end

    showKeyFob(vehicle, plate)
end

-- ox_inventory item export (car_key)
exports('useCarKey', function(_, slot)
    openKeyFob(slot?.metadata?.plate)
end)

local fobActions = {
    toggleLock = function(vehicle, data)
        if type(data.state) ~= 'boolean' then return end
        local vehicleConfig = GetVehicleConfig(vehicle)
        if vehicleConfig.noLock or vehicleConfig.shared then return end

        TriggerServerEvent('f_vehiclekeys:server:setLockState', NetworkGetNetworkIdFromEntity(vehicle), data.state)
        exports.qbx_core:Notify(locale(data.state and 'notify.vehicle_locked' or 'notify.vehicle_unlocked'))
        qbx.playAudio({ audioName = 'Remote_Control_Fob', audioRef = 'PI_Menu_Sounds', audioSource = vehicle })
        flashLights(vehicle, data.state and 2 or 1)
        if not cache.vehicle then
            lib.playAnim(cache.ped, 'anim@mp_player_intmenu@key_fob@', 'fob_click', 3.0, 3.0, 1000, 48)
        end

        -- locking ends the remote's use (after getting in, or after getting out); unlocking keeps
        -- it up so the player can get in and still lock from inside
        if data.state then
            SetTimeout(300, CloseKeyFob)
        end
    end,
    toggleTrunk = function(vehicle)
        if not requestControl(vehicle) then return end
        if GetVehicleDoorAngleRatio(vehicle, 5) > 0.0 then
            SetVehicleDoorShut(vehicle, 5, false)
        else
            SetVehicleDoorOpen(vehicle, 5, false, false)
        end
    end,
    toggleEngine = function(vehicle)
        if not requestControl(vehicle) then return end
        local engineOn = GetIsVehicleEngineRunning(vehicle)
        SetVehicleEngineOn(vehicle, not engineOn, true, true)
        exports.qbx_core:Notify(locale(engineOn and 'notify.engine_off' or 'notify.engine_on'), 'success')
    end,
    toggleLights = function(vehicle)
        if not requestControl(vehicle) then return end
        local _, lightsOn, highbeams = GetVehicleLightsState(vehicle)
        local on = lightsOn == 1 or highbeams == 1
        SetVehicleLights(vehicle, on and 1 or 2)
    end,
    honkHorn = function(vehicle)
        CreateThread(function()
            local endTime = GetGameTimer() + 1000
            while GetGameTimer() < endTime do
                SoundVehicleHornThisFrame(vehicle)
                Wait(0)
            end
        end)
    end,
    findVehicle = function(vehicle)
        flashLights(vehicle, 6)
        local blip = AddBlipForEntity(vehicle)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 5)
        SetBlipFlashes(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(locale('info.your_vehicle'))
        EndTextCommandSetBlipName(blip)
        SetTimeout(10000, function()
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end)
    end,
}

for name, action in pairs(fobActions) do
    RegisterNUICallback(name, function(data, cb)
        cb(1)
        if type(data) ~= 'table' then return end
        local vehicle = getFobVehicle(data.plate)
        if not vehicle or not CanUseKeyFob(vehicle) then return end
        action(vehicle, data)
    end)
end

---@type table<number, integer> vehicle -> time until which leaving it does not show the remote
local skipFobOnExit = {}

-- other scripts (e.g. f_garages while parking) can tell that leaving a vehicle is not a normal exit
AddEventHandler('f_vehiclekeys:client:skipKeyFobOnExit', function(vehicle)
    if type(vehicle) ~= 'number' then return end
    skipFobOnExit[vehicle] = GetGameTimer() + 10000
end)

-- getting out of a vehicle shows its remote, so it can be locked without pressing L first
lib.onCache('vehicle', function(vehicle)
    local leftVehicle = cache.vehicle -- still the old value inside this handler
    if vehicle or not leftVehicle or fobOpen or activeGame then return end

    local skipUntil = skipFobOnExit[leftVehicle]
    skipFobOnExit[leftVehicle] = nil
    if skipUntil and GetGameTimer() < skipUntil then return end

    SetTimeout(250, function()
        if cache.vehicle or fobOpen or activeGame then return end
        if not DoesEntityExist(leftVehicle) or IsPedDeadOrDying(cache.ped, true) then return end

        local vehicleConfig = GetVehicleConfig(leftVehicle)
        if vehicleConfig.noLock or vehicleConfig.shared then return end
        if not CanUseKeyFob(leftVehicle) then return end

        OpenKeyFobForVehicle(leftVehicle)
    end)
end)

RegisterNUICallback('hideFrame', function(data, cb)
    cb(1)
    local frame = type(data) == 'table' and data.name or 'setVisibleApp'
    if frame == 'setVisibleApp' then
        CloseKeyFob()
        return
    end

    -- ESC on a minigame counts as cancelling it
    local name = frame:match('^setVisible(.+)$')
    if name then
        finishMinigame(name, { success = false, reason = 'cancelled' })
    end
end)

---------------
---- Alarm ----
---------------

-- sent by the server to the network owner of the vehicle
RegisterNetEvent('f_vehiclekeys:client:alarm', function(netId, duration)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local vehicle = NetToVeh(netId)
    if vehicle == 0 then return end
    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, duration)
    StartVehicleAlarm(vehicle)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end)
