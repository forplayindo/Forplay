--[[
    - All data to be sent to the HUD is processed.
    - Threads are created.
--]]

local Hud = {}

local Utils = require 'modules.utils.client'
local Voice = require 'modules.voice.client'
local CarControl = require 'modules.car_control.client'
local Seatbelt = require 'modules.seatbelt.client'
local Minimap = require 'modules.minimap.client'

-- hygiene bars: values and the F3 show/hide state come from f_hygiene
local function setHygiene(data)
    if type(data) ~= 'table' then return end
    local bars = Hud.data.bars
    if data.mandi then bars.mandi.value = math.floor(data.mandi + 0.5) end
    if data.kencing then bars.kencing.value = math.floor(data.kencing + 0.5) end
    if data.poop then bars.poop.value = math.floor(data.poop + 0.5) end
    if data.visible ~= nil then Hud.data.hygiene.visible = data.visible end
end
AddEventHandler('f_hud:client:setHygiene', setHygiene)

-- f_hud (re)started after f_hygiene: pull the current state once
CreateThread(function()
    Wait(1000)
    if GetResourceState('f_hygiene') == 'started' then
        local ok, state = pcall(function() return exports.f_hygiene:GetHygieneState() end)
        if ok then setHygiene(state) end
    end
end)

-- cruise control state, toggled by f_smallresources/f_cruise
local isCruiseOn = false
AddEventHandler('seatbelt:client:ToggleCruise', function()
    isCruiseOn = not isCruiseOn
end)

local Weapons = lib.load('data.weapons')

-- Load initial data
Hud.data = lib.load('data.hud') --[[@type iHud]]

local screenResolution = { x = 0, y = 0 }
local isPauseActive = false
local oldVehicle = nil
local isPlayerDeath = false

---Get game active screen resolution and save
---@return table ScreenResolution
local function getScreenResolution()
    local screenWidth, screenHeight = GetActiveScreenResolution()
    screenResolution.x = screenWidth
    screenResolution.y = screenHeight
    return { x = screenWidth, y = screenHeight }
end

---Update ClientInfo Data
---It retrieves data from the cache and refreshes the data if timeout.
local function updateClientInfo()
    local client_info = Hud.data.client_info
    client_info.time.gameHours = GetClockHours()
    client_info.time.gameMinutes = GetClockMinutes()
    if not Hud.data.client_info.active then return end
    client_info.bank.amount = cache('client.bank.amount', function()
        return client.GetPlayerBalance('bank')
    end, 2000)
    client_info.cash.amount = cache('client.cash.amount', function()
        return client.GetPlayerBalance('cash')
    end, 2000)
    if Config.DefaultHudSettings.client_info.extra_currency.active then
        client_info.extra_currency.amount = cache('client.extra_currency.amount', function()
            return client.GetPlayerBalance('extra_currency')
        end, 2000)
    end
    client_info.job.label = cache('client.job.label', function()
        return client.GetPlayerJob().label
    end, 2000)
    client_info.job.gradeLabel = cache('client.job.gradeLabel', function()
        return client.GetPlayerJob().grade
    end, 2000)
    client_info.radio.inChannel = cache('client.radio.inChannel', function()
        return Voice.GetPlayerRadio().inChannel
    end, 2000)
    client_info.radio.channel = cache('client.radio.channel', function()
        return Voice.GetPlayerRadio().channel
    end, 2000)
    client_info.weapon.name = cache('client.weapon.name', function()
        return Weapons[GetSelectedPedWeapon(cache.ped)]
    end, 1000)
    local weapon = cache.weapon or GetSelectedPedWeapon(cache.ped)
    local ammo = client_info.weapon.ammo
    if weapon and weapon ~= `WEAPON_UNARMED` then
        ammo.inWeapon = GetAmmoInPedWeapon(cache.ped, weapon)
        local _, inClip = GetAmmoInClip(cache.ped, weapon)
        ammo.inClip = inClip
    else
        ammo.inWeapon, ammo.inClip = 0, 0
    end
    -- HUD senjata hanya tampil untuk senjata api (flag 4 = gun), bukan melee/tangan kosong
    client_info.weapon.isGun = IsPedArmed(cache.ped, 4)
    client_info.player_source.source = cache.serverId
    if Config.DefaultHudSettings.client_info.gang?.active and client.GetPlayerGang then
        local gang = cache('client.gang', function() return client.GetPlayerGang() or false end, 2000)
        client_info.gang.label = gang and gang.label or nil
        client_info.gang.gradeLabel = gang and gang.grade or nil
    end
    client_info.player_name = cache('client.player_name', function()
        return client.GetPlayerName and client.GetPlayerName() or GetPlayerName(PlayerId())
    end, 5000)
end

---Update Compass Data
local function updateCompassStreet()
    local compassInfo = Hud.data.compass
    local playerCoords = GetEntityCoords(cache.ped)
    local streetHash, crossingRoadHash = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
    compassInfo.street1 = GetStreetNameFromHashKey(streetHash)
    compassInfo.street2 = GetStreetNameFromHashKey(crossingRoadHash)
end

---Update Compass Data
---It works if it is active and in use.
local function updateCompassHeading()
    if not Hud.data.compass.active or
        (Hud.data.compass.onlyInVehicle and not Hud.data.vehicle_info.entity) then
        return
    end
    local camRotZ = GetGameplayCamRot(0).z
    local heading = math.floor(360.0 - ((camRotZ + 360.0) % 360.0))
    Hud.data.compass.heading = heading
end

---Update Navigation Data
---It works if it is active and in use.
local function updateNavigation()
    if not Hud.data.navigation_widget.active then return end
    local navigation = Hud.data.navigation_widget
    local compassInfo = Hud.data.compass
    if IsWaypointActive() then
        local waypointBlip = GetFirstBlipInfoId(8) -- 8 is the id for waypoint blips
        if waypointBlip ~= 0 then
            local waypointCoord = GetBlipInfoIdCoord(waypointBlip)
            local streetHash, crossingRoadHash = GetStreetNameAtCoord(waypointCoord.x, waypointCoord.y, waypointCoord.z)
            local streetName = GetStreetNameFromHashKey(streetHash)
            local crossingStreetName = GetStreetNameFromHashKey(crossingRoadHash)

            navigation.navigation.isDestinationActive = true
            navigation.navigation.currentStreet = (compassInfo.street1 or '') .. ' ' .. (compassInfo.street2 or '')
            navigation.navigation.destinationStreet = streetName
            if crossingStreetName ~= nil and crossingStreetName ~= '' then
                navigation.navigation.destinationStreet =
                    navigation.navigation.destinationStreet ..
                    ' & ' .. crossingStreetName
            end
        end
    else
        if navigation.navigation.isDestinationActive then
            navigation.navigation.isDestinationActive = false
        end
    end
end

---Update Bar Data
local function updateBars()
    local bars = Hud.data.bars
    local ped = cache.ped
    local playerId = cache.playerId
    --armor
    bars.armor.value = GetPedArmour(ped)
    --health
    local maxHealth = GetEntityMaxHealth(ped)
    local baseHealth = GetEntityHealth(ped)
    local adjustedHealth = maxHealth == 175 and (baseHealth + 25) or baseHealth
    local health = math.clamp(adjustedHealth - 100, 0, 100)
    if isPlayerDeath then
        health = 0
    end
    bars.health.value = health
    --hunger
    bars.hunger.value = PlayerData.hunger
    --oxygen
    local oxygen = 100
    if IsEntityInWater(ped) then
        oxygen = GetPlayerUnderwaterTimeRemaining(playerId) * 10
    end
    bars.oxygen.value = math.floor(oxygen + 0.5)
    --stamina
    local stamina = 100 - GetPlayerSprintStaminaRemaining(playerId)
    bars.stamina.value = math.floor(stamina + 0.5)
    --stress
    bars.stress.value = PlayerData.stress
    --thirst
    bars.thirst.value = PlayerData.thirst
    --voice
    local function valueToPercentageVoice(value)
        return (value >= 3 and 100) or (value == 2 and 50) or (value == 1 and 25) or 0
    end
    bars.voice.talkRange = Voice.GetTalkRange()
    bars.voice.value = valueToPercentageVoice(bars.voice.talkRange)
    bars.voice.isTalking = NetworkIsPlayerTalking(playerId)
    -- #
end

---Update Vehicle Data
local function updateVehicleInfo()
    local vehicle_info = Hud.data.vehicle_info
    local vehicle = cache.vehicle
    vehicle_info.entity = vehicle
    if vehicle and DoesEntityExist(vehicle) then
        if not oldVehicle or oldVehicle ~= vehicle then
            oldVehicle = vehicle
            vehicle_info.fuel.maxLevel = 100
            vehicle_info.fuel.type = CarControl.GetVehicleFuelType(vehicle)
            vehicle_info.veh_class = GetVehicleClass(vehicle)
            Hud.CheckRadarDisplay()
            Seatbelt.EnteredVehicle()
        end
        local engineRunning = GetIsVehicleEngineRunning(vehicle)
        local currentGear = nil
        if vehicle_info.gearType == 'manual' and engineRunning then
            currentGear = vehicle_info.manualGear
        else
            currentGear = engineRunning and GetVehicleCurrentGear(vehicle) or 'N'
        end
        if currentGear == 0 then
            currentGear = 'R'
        end
        local engineHealth = engineRunning and math.max(0, GetVehicleEngineHealth(vehicle)) or 1000
        local entitySpeed = GetEntitySpeed(vehicle)
        local vehicleSpeed = vehicle_info.kmH and
            entitySpeed * 3.6 or entitySpeed * 2.237
        local _, lightson, highbeams = GetVehicleLightsState(vehicle)
        vehicle_info.speed = math.floor(vehicleSpeed)
        vehicle_info.currentGear = currentGear
        vehicle_info.engineHealth = math.floor(engineHealth * .1)
        vehicle_info.fuel.level = Utils.GetVehicleFuelLevel(vehicle)
        vehicle_info.rpm = engineRunning and math.floor(GetVehicleCurrentRpm(vehicle) * 100) / 100 or 0
        vehicle_info.isSeatbeltOn = Seatbelt.GetCurrentState()
        vehicle_info.isLightOn = lightson == 1 or highbeams == 1
        vehicle_info.isCruiseOn = isCruiseOn
        Hud.data.bars.vehicle_engine.value = vehicle_info.engineHealth
    else
        if oldVehicle then
            oldVehicle = nil
            isCruiseOn = false
            vehicle_info = {
                entity = false,
                kmH = vehicle_info.kmH,
                fuel = {}
            }
            Hud.CheckRadarDisplay()
        end
    end
end

---Process config settings
function Hud.SetDefaultSettings()
    local def = Config.DefaultHudSettings
    Hud.data.bar_style = def.bar_style
    Hud.data.vehicle_hud_style = def.vehicle_hud_style
    Hud.data.is_res_style_active = def.is_res_style_active
    Hud.data.mini_map.onlyInVehicle = def.mini_map.onlyInVehicle
    Hud.data.mini_map.style = def.mini_map.style
    Hud.data.mini_map.editableByPlayers = def.mini_map.editableByPlayers
    Hud.data.compass.active = def.compass.active
    Hud.data.compass.onlyInVehicle = def.compass.onlyInVehicle
    Hud.data.compass.editableByPlayers = def.compass.editableByPlayers
    Hud.data.cinematic.active = def.cinematic.active
    Hud.data.vehicle_info.kmH = def.vehicle_info.kmH
    Hud.data.client_info.active = def.client_info.active
    Hud.data.client_info.server_info.active = def.client_info.server_info.active
    Hud.data.client_info.server_info.image = def.client_info.server_info.image
    Hud.data.client_info.server_info.name = def.client_info.server_info.name
    Hud.data.client_info.bank.active = def.client_info.bank.active
    Hud.data.client_info.cash.active = def.client_info.cash.active
    Hud.data.client_info.job.active = def.client_info.job.active
    Hud.data.client_info.player_source.active = def.client_info.player_source.active
    Hud.data.client_info.radio.active = def.client_info.radio.active
    Hud.data.client_info.real_time.active = def.client_info.real_time.active
    Hud.data.client_info.time.active = def.client_info.time.active
    Hud.data.client_info.weapon.active = def.client_info.weapon.active
    Hud.data.client_info.extra_currency.active = def.client_info.extra_currency.active
    Hud.data.bars.armor.color = def.bar_colors.armor
    Hud.data.bars.health.color = def.bar_colors.health
    Hud.data.bars.hunger.color = def.bar_colors.hunger
    Hud.data.bars.oxygen.color = def.bar_colors.oxygen
    Hud.data.bars.stamina.color = def.bar_colors.stamina
    Hud.data.bars.stress.color = def.bar_colors.stress
    Hud.data.bars.thirst.color = def.bar_colors.thirst
    Hud.data.bars.vehicle_engine.color = def.bar_colors.vehicle_engine
    Hud.data.bars.vehicle_nitro.color = def.bar_colors.vehicle_nitro
    Hud.data.bars.voice.color = def.bar_colors.voice
    Hud.data.bars.mandi.color = def.bar_colors.mandi
    Hud.data.bars.kencing.color = def.bar_colors.kencing
    Hud.data.bars.poop.color = def.bar_colors.poop
    Hud.data.music_info.active = def.music_info.active
    Hud.data.colors = Config.BarColors
    Hud.data.navigation_widget.active = def.navigation_widget.active
end

-- Radar display or hidden by options
function Hud.CheckRadarDisplay()
    DisplayRadar(false)
    if client.IsPlayerLoaded() and client.uiLoad then
        if not Hud.data.cinematic.show then
            if Hud.data.mini_map.onlyInVehicle then
                if (cache.vehicle and DoesEntityExist(cache.vehicle)) then
                    DisplayRadar(true)
                end
            else
                DisplayRadar(true)
            end
        end
    end
end

---Places the GTA VI minimap (modules/minimap) and refreshes radar visibility
function Hud.FixMiniMap()
    CreateThread(function()
        DisplayRadar(false)
        Minimap.Load()
        Wait(100)
        Hud.CheckRadarDisplay()
    end)
end

-- Sets the visibility of the HUD UI element
---@param state boolean visible (true) or hidden (false)
function Hud.SetVisible(state)
    if state then
        Hud.CheckRadarDisplay()
    else
        DisplayRadar(false)
    end
    if Hud.ForcePush then Hud.ForcePush() end
    client.SendReactMessage('ui:setVisible', state)
end

-- The vehicle gear is updated with data from the `hrsgears` script.
RegisterNetEvent('0r-hud:Client:SetManualGear', function(newGear)
    Hud.data.vehicle_info.manualGear = newGear
end)

RegisterNetEvent(_e('client:updatePlayerCount'), function(playerCount, maxPlayers)
    Hud.data.client_info.server_info.playerCount = playerCount
    Hud.data.client_info.server_info.maxPlayers = maxPlayers
end)

RegisterNetEvent(_e('client:setPlayerDeathStatus'), function(state)
    isPlayerDeath = state
end)

RegisterNetEvent(_e('client:setVehicleNitroValue'), function(value)
    Hud.data.bars.vehicle_nitro.value = value
end)

RegisterNetEvent('hud:client:UpdateNitrous', function(hasNitro, level, state)
    Hud.data.bars.vehicle_nitro.value = level
end)

-- Slow running thick updates secondary priority data
CreateThread(function()
    local wait = 1000 -- more slowly, if the player is not fully loaded
    while true do
        if client.load then
            wait = 500
            updateCompassStreet()
            updateClientInfo()
            updateNavigation()
            Hud.CheckRadarDisplay()
        end
        Wait(wait)
    end
end)
-- Updates priority data
-- Only pushes to NUI when something actually changed (idle = no NUI traffic, no React re-render)
local lastPayload = nil
local function pushHudData()
    local payload = json.encode(Hud.data)
    if payload ~= lastPayload then
        lastPayload = payload
        SendNuiMessage('{"action":"ui:setHudData","data":' .. payload .. '}')
    end
end
Hud.ForcePush = function() lastPayload = nil end

--- Fill and push all data right away on login instead of waiting for the next loop tick (up to 1s)
function Hud.RefreshNow()
    updateCompassStreet()
    updateClientInfo()
    updateNavigation()
    updateCompassHeading()
    updateBars()
    updateVehicleInfo()
    lastPayload = nil
    pushHudData()
end

CreateThread(function()
    while true do
        local wait = 1000 -- slow, if the player is not fully loaded
        if client.load then
            wait = Config.RefreshTimes.hud
            updateCompassHeading()
            updateBars()
            updateVehicleInfo()
            pushHudData()
            if Hud.data.vehicle_info.entity then
                wait = Config.RefreshTimes.vehicle
            end
        end
        Wait(wait)
    end
end)

--What to do if the player opens the pause menu or changes the resolution:
CreateThread(function()
    getScreenResolution()
    while true do
        if client.load and client.uiLoad then
            -- Control Pause Menu
            if IsPauseMenuActive() and not isPauseActive then
                Hud.SetVisible(false)
                DisplayRadar(false)
                isPauseActive = true
            elseif not IsPauseMenuActive() and isPauseActive then
                Hud.SetVisible(true)
                Hud.CheckRadarDisplay()
                isPauseActive = false
            end
            -- Control Active Screen Resolution
            local x, y = GetActiveScreenResolution()
            if not screenResolution.x or screenResolution.x ~= x and not isPauseActive then
                screenResolution.x = x
                screenResolution.y = y
                Wait(1000)
                Hud.FixMiniMap()
            end
        end
        Wait(1000)
    end
end)

-- Hide GTA components if option is active
-- Resmon will increase its value. This function was created to make the minimap work more adaptively on servers that use different minimaps or different scripts.
if Config.HideGTAHudComponents then
    CreateThread(function()
        local minimap = RequestScaleformMovie('minimap')
        local HavePostalMap = Config.HavePostalMap
        local nextScaleform = 0
        while true do
            Wait(0) -- HideHudComponentThisFrame must run every frame
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(3)
            HideHudComponentThisFrame(4)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            local now = GetGameTimer()
            if now >= nextScaleform then -- no need to spam the scaleform every frame
                nextScaleform = now + 1000
                BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
                ScaleformMovieMethodAddParamInt(3)
                EndScaleformMovieMethod()
                if HavePostalMap and not IsRadarHidden() then
                    SetRadarZoom(1100)
                end
            end
        end
    end)
end

return Hud
