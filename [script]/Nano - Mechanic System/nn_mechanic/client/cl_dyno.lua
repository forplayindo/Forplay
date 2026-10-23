local NUI_BASE_URL = "https://cfx-nui-"
local currentResourceName = GetCurrentResourceName()
local NUI_INDEX_PATH_SUFFIX = "/web/build/index.html"
local NUI_URL = NUI_BASE_URL .. currentResourceName .. NUI_INDEX_PATH_SUFFIX

local NUI_SCREEN_WIDTH = 1920
local NUI_SCREEN_HEIGHT = 1080
local DYNO_STATION_INTERACTION_RADIUS = 30.0
local ZONE_MONITOR_INTERVAL_MS = 1000

local dynoStations = {}
local dynoStationZones = {}
local isDynoTestRunning = false
local activeDynoVehicleEntity = nil
local activeDynoStationKey = nil
local dynoTestSamples = {}
local peakHp = 0
local peakTorque = 0
local globalRenderingThreadId = nil
local isGlobalRenderingActive = false
local zoneMonitoringThreadId = nil
local isZoneMonitoringActive = false

local dynoDebugConfig = {
    active = false,
    stationKey = nil,
    offsetX = -0.016,
    offsetY = -0.07,
    offsetZ = 1.27,
    screenWidth = 1.09,
    screenHeight = 0.55,
    currentParam = 1
}

local function drawDynoScreen(station)
    local txdName = station.txdName
    local txnName = station.txnName
    if not txdName or not txnName then
        return
    end

    local tvEntity = station.tvEntity
    if not tvEntity or not DoesEntityExist(tvEntity) then
        return
    end
    -- if (GetGameTimer() - lastDraw) < 16 then
    --     return
    -- end
    -- lastDraw = GetGameTimer()
    local screenWidth = station.screenWidth or 1.09
    local screenHeight = station.screenHeight or 0.55
    local offsetX = station.offsetX or -0.016
    local offsetY = station.offsetY or -0.07
    local offsetZ = station.offsetZ or 1.27

    local halfScreenWidth = screenWidth / 2
    local coord1 = GetOffsetFromEntityInWorldCoords(tvEntity, offsetX - halfScreenWidth, offsetY, 0)
    local coord2 = GetOffsetFromEntityInWorldCoords(tvEntity, offsetX + halfScreenWidth, offsetY, 0)
    local zAnchor = GetOffsetFromEntityInWorldCoords(tvEntity, 0, 0, offsetZ)
    local screenBottomZ = zAnchor.z - (screenHeight / 2)
    local screenTopZ = zAnchor.z + (screenHeight / 2)

    DrawSpritePoly(
        coord2.x, coord2.y, screenBottomZ,
        coord2.x, coord2.y, screenTopZ,
        coord1.x, coord1.y, screenTopZ,
        255, 255, 255, 255,
        txdName, txnName,
        1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0
    )

    DrawSpritePoly(
        coord1.x, coord1.y, screenTopZ,
        coord1.x, coord1.y, screenBottomZ,
        coord2.x, coord2.y, screenBottomZ,
        255, 255, 255, 255,
        txdName, txnName,
        0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0
    )
end

local function sendNuiInitialConfig(duiObject)
    local language = Config.Language or "en"
    SendDuiMessage(duiObject, json.encode({
        action = "setConfigLanguage",
        data = { language = language }
    }))

    if Translations and Translations[language] then
        SendDuiMessage(duiObject, json.encode({
            action = "setTranslations",
            data = { translations = Translations[language] }
        }))
    end
end

local function getVehicleHandlingFloat(vehicle, handlingName, fieldName)
    return GetVehicleHandlingFloat(vehicle, handlingName, fieldName)
end

local getVehicleHandlingValue = getVehicleHandlingFloat

local function setVehicleWheelRotationSpeeds(vehicle, speed)
    local driveBiasFront = getVehicleHandlingValue(vehicle, "CHandlingData", "fDriveBiasFront")
    if driveBiasFront >= 0.5 then
        SetVehicleWheelRotationSpeed(vehicle, 0, speed)
        SetVehicleWheelRotationSpeed(vehicle, 1, speed)
    end
    if driveBiasFront <= 0.5 then
        SetVehicleWheelRotationSpeed(vehicle, 2, speed)
        SetVehicleWheelRotationSpeed(vehicle, 3, speed)
    end
end

local function calculateDynoValues(vehicle, throttle)
    local mass = getVehicleHandlingValue(vehicle, "CHandlingData", "fMass")
    local initialDriveForce = getVehicleHandlingValue(vehicle, "CHandlingData", "fInitialDriveForce")
    local initialDriveMaxFlatVel = getVehicleHandlingValue(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
    local driveInertia = getVehicleHandlingValue(vehicle, "CHandlingData", "fDriveInertia")

    local transmissionModLevel = GetVehicleMod(vehicle, 11) + 1
    local turboModLevel = GetVehicleMod(vehicle, 13) + 1
    local isTurboToggleModOn = IsToggleModOn(vehicle, 18)

    local transmissionMultiplier = 1.0 + (transmissionModLevel * 0.08)
    local turboMultiplier = 1.0 + (turboModLevel * 0.04)
    local turboToggleFactor = isTurboToggleModOn and 1.2 or 1.0
    local totalMultiplier = transmissionMultiplier * turboMultiplier * turboToggleFactor

    local baseHpValue = (initialDriveForce * mass * initialDriveMaxFlatVel * driveInertia / 250) * totalMultiplier
    local baseTorqueValue = baseHpValue * 0.8

    local hpCurveFactor = -2.5 * (throttle - 0.82)^2 + 1.0
    hpCurveFactor = math.max(0.1, math.min(1.0, hpCurveFactor))
    if throttle < 0.25 then
        hpCurveFactor = hpCurveFactor * (throttle / 0.25)^0.6
    end

    local torqueCurveFactor = -2.8 * (throttle - 0.5)^2 + 1.0
    torqueCurveFactor = math.max(0.2, math.min(1.0, torqueCurveFactor))
    if throttle < 0.2 then
        torqueCurveFactor = torqueCurveFactor * (throttle / 0.2)^0.4
    end

    if isTurboToggleModOn then
        if throttle > 0.4 then
            local turboBoostFactor = math.min(1.0, (throttle - 0.4) / 0.25)
            hpCurveFactor = hpCurveFactor * (1.0 + turboBoostFactor * 0.08)
            torqueCurveFactor = torqueCurveFactor * (1.0 + turboBoostFactor * 0.12)
        end
    end

    local currentHp = math.floor(baseHpValue * hpCurveFactor) + math.random(-2, 2)
    local currentTorque = math.floor(baseTorqueValue * torqueCurveFactor) + math.random(-2, 2)

    return math.max(0, currentHp), math.max(0, currentTorque)
end

local function setDynoStationState(stationKey, state, message)
    local station = dynoStations[stationKey]
    if station and station.duiObj then
        local msgPayload = {
            action = "dyno:setState",
            data = {
                state = state,
                message = message or ""
            }
        }
        SendDuiMessage(station.duiObj, json.encode(msgPayload))
    end
end

local function updateDynoStation(stationKey, data)
    local station = dynoStations[stationKey]
    if station and station.duiObj then
        local msgPayload = {
            action = "dyno:update",
            data = data
        }
        SendDuiMessage(station.duiObj, json.encode(msgPayload))
    end
end

local function updateNearbyDynoStations(playerCoords, data)
    for _, station in pairs(dynoStations) do
        if station.platform and station.duiObj then
            local stationPlatformVector = vector3(station.platform.x, station.platform.y, station.platform.z)
            if #(playerCoords - stationPlatformVector) < DYNO_STATION_INTERACTION_RADIUS then
                local msgPayload = {
                    action = "dyno:update",
                    data = data
                }
                SendDuiMessage(station.duiObj, json.encode(msgPayload))
            end
        end
    end
end

local function setNearbyDynoStationsState(playerCoords, state, message)
    for _, station in pairs(dynoStations) do
        if station.platform and station.duiObj then
            local stationPlatformVector = vector3(station.platform.x, station.platform.y, station.platform.z)
            if #(playerCoords - stationPlatformVector) < DYNO_STATION_INTERACTION_RADIUS then
                local msgPayload = {
                    action = "dyno:setState",
                    data = {
                        state = state,
                        message = message or ""
                    }
                }
                SendDuiMessage(station.duiObj, json.encode(msgPayload))
            end
        end
    end
end

local VEHICLE_DYNO_STATEBAG_KEY = "vehicleDyno"

local function handleVehicleDynoStateChange(stateBagName, _stateBagKey, stateBagValue)
    local vehicleEntity = GetEntityFromStateBagName(stateBagName)
    if not vehicleEntity or not DoesEntityExist(vehicleEntity) then
        return
    end

    local vehicleCoords = GetEntityCoords(vehicleEntity)
    local playerCoords = GetEntityCoords(PlayerPedId())
    if #(playerCoords - vehicleCoords) > DYNO_STATION_INTERACTION_RADIUS then
        return
    end

    if not stateBagValue then
        setVehicleWheelRotationSpeeds(vehicleEntity, 0)
        SetVehicleCurrentRpm(vehicleEntity, 0.2)
        SetVehicleGravity(vehicleEntity, true)
        FreezeEntityPosition(vehicleEntity, false)
        SetVehicleHandbrake(vehicleEntity, false)
        setNearbyDynoStationsState(vehicleCoords, "idle", t("dyno_tv_idle"))
        return
    end

    if stateBagValue.complete then
        setVehicleWheelRotationSpeeds(vehicleEntity, 0)
        SetVehicleCurrentRpm(vehicleEntity, 0.2)
        SetVehicleGravity(vehicleEntity, true)
        FreezeEntityPosition(vehicleEntity, false)
        SetVehicleHandbrake(vehicleEntity, false)
        if stateBagValue.dynoData then
            setNearbyDynoStationsState(vehicleCoords, "complete", t("dyno_test_complete"))
            updateNearbyDynoStations(vehicleCoords, stateBagValue.dynoData)
        end
        return
    end

    local rpm = stateBagValue.rpm
    local wheelSpeed = stateBagValue.wheelSpeed

    SetVehicleGravity(vehicleEntity, false)
    FreezeEntityPosition(vehicleEntity, true)
    SetVehicleHandbrake(vehicleEntity, true)
    SetVehicleCurrentRpm(vehicleEntity, rpm)
    setVehicleWheelRotationSpeeds(vehicleEntity, wheelSpeed)

    if stateBagValue.dynoData then
        setNearbyDynoStationsState(vehicleCoords, "testing", t("dyno_testing"))
        updateNearbyDynoStations(vehicleCoords, stateBagValue.dynoData)
    end
end

AddStateBagChangeHandler(VEHICLE_DYNO_STATEBAG_KEY, "", handleVehicleDynoStateChange)

local function startDynoTest(vehicleEntity, stationKey)
    if isDynoTestRunning then
        return
    end
    isDynoTestRunning = true
    activeDynoVehicleEntity = vehicleEntity
    activeDynoStationKey = stationKey

    dynoTestSamples = {}
    peakHp = 0
    peakTorque = 0

    SetVehicleGravity(vehicleEntity, false)
    FreezeEntityPosition(vehicleEntity, true)
    SetVehicleHandbrake(vehicleEntity, true)
    SetVehicleEngineOn(vehicleEntity, true, true, false)
    setDynoStationState(stationKey, "testing", t("dyno_testing"))

    CreateThread(function()
        local testProgressTime = 0
        local isTestCompletedSuccessfully = false

        local MAX_TEST_DURATION_MS = 33500 -- ~33.5 seconds

        while testProgressTime < MAX_TEST_DURATION_MS do
            if not isDynoTestRunning then
                break
            end
            if not DoesEntityExist(activeDynoVehicleEntity) then
                break
            end

            local frameStartTime = GetGameTimer()

            local throttle = math.min(1.0, (testProgressTime + 7500) / MAX_TEST_DURATION_MS + 0.0)
            local wheelSpeed = testProgressTime / 200 + 0.0 -- Adjust speed over time
            local rpm = math.floor(throttle * 7000 + 1000)

            local currentHp, currentTorque = calculateDynoValues(activeDynoVehicleEntity, throttle)

            if currentHp > peakHp then
                peakHp = currentHp
            end
            if currentTorque > peakTorque then
                peakTorque = currentTorque
            end

            if testProgressTime % 500 < 60 then -- Sample every 500ms
                table.insert(dynoTestSamples, {
                    rpm = rpm,
                    hp = currentHp,
                    torque = currentTorque,
                    progress = testProgressTime / MAX_TEST_DURATION_MS
                })
            end

            local dynoDataPayload = {
                rpm = throttle,
                wheelSpeed = wheelSpeed,
                dynoData = {
                    currentRpm = rpm,
                    currentHp = currentHp,
                    currentTorque = currentTorque,
                    progress = testProgressTime / MAX_TEST_DURATION_MS,
                    samples = dynoTestSamples,
                    peakHp = peakHp,
                    peakTorque = peakTorque,
                    maxRpm = 8000,
                    complete = false
                }
            }
            Entity(activeDynoVehicleEntity).state:set(VEHICLE_DYNO_STATEBAG_KEY, dynoDataPayload, true)

            Wait(50)
            testProgressTime = testProgressTime + (GetGameTimer() - frameStartTime)
        end

        if testProgressTime >= MAX_TEST_DURATION_MS then
            isTestCompletedSuccessfully = true
        end

        if isTestCompletedSuccessfully and DoesEntityExist(activeDynoVehicleEntity) then
            local finalDynoDataPayload = {
                rpm = 0.1,
                wheelSpeed = 0,
                complete = true,
                dynoData = {
                    currentRpm = 800,
                    currentHp = 0,
                    currentTorque = 0,
                    progress = 1,
                    samples = dynoTestSamples,
                    peakHp = peakHp,
                    peakTorque = peakTorque,
                    maxRpm = 8000,
                    complete = true
                }
            }
            Entity(activeDynoVehicleEntity).state:set(VEHICLE_DYNO_STATEBAG_KEY, finalDynoDataPayload, true)
            SetVehicleGravity(activeDynoVehicleEntity, true)
            SetVehicleHandbrake(activeDynoVehicleEntity, false)
            FreezeEntityPosition(activeDynoVehicleEntity, false)
            
            bridge.Notify.SendNotify(string.format("%s: %d HP / %d lb-ft", t("dyno_test_complete"), peakHp, peakTorque), "success")
        end

        isDynoTestRunning = false
        activeDynoVehicleEntity = nil
        activeDynoStationKey = nil
    end)
end

local function stopDynoTest()
    isDynoTestRunning = false
    if activeDynoVehicleEntity and DoesEntityExist(activeDynoVehicleEntity) then
        Entity(activeDynoVehicleEntity).state:set(VEHICLE_DYNO_STATEBAG_KEY, false, true)
        SetVehicleGravity(activeDynoVehicleEntity, true)
        SetVehicleHandbrake(activeDynoVehicleEntity, false)
        FreezeEntityPosition(activeDynoVehicleEntity, false)
    end
    if activeDynoStationKey then
        setDynoStationState(activeDynoStationKey, "idle", t("dyno_tv_idle"))
    end
    activeDynoVehicleEntity = nil
    activeDynoStationKey = nil
end

local function startGlobalRenderingThreadInternal()
    if globalRenderingThreadId or isGlobalRenderingActive then
        return
    end
    isGlobalRenderingActive = true
    globalRenderingThreadId = CreateThread(function()
        while true do
            if not isGlobalRenderingActive then
                break
            end

            local anyStationRequiresRendering = false
            for _, station in pairs(dynoStations) do
                local shouldRenderForDebug = dynoDebugConfig.active and (dynoDebugConfig.stationKey == station.stationKey)
                if shouldRenderForDebug then
                    anyStationRequiresRendering = true
                elseif station.shouldRender and station.duiObj and station.txdName and station.tvEntity then
                    anyStationRequiresRendering = true
                    drawDynoScreen(station)
                end
            end

            if not anyStationRequiresRendering then
                isGlobalRenderingActive = false
                globalRenderingThreadId = nil
                break
            end
            Wait(0)
        end
    end)
end

local function stopGlobalRenderingThreadInternal()
    isGlobalRenderingActive = false
    globalRenderingThreadId = nil
end

local function startZoneMonitoringThreadInternal()
    if zoneMonitoringThreadId or isZoneMonitoringActive then
        return
    end
    isZoneMonitoringActive = true
    zoneMonitoringThreadId = CreateThread(function()
        while true do
            if not isZoneMonitoringActive then
                break
            end

            local anyValidTvEntityFound = false
            local stationsToRenderCount = 0
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for _, station in pairs(dynoStations) do
                if station.tvEntity then
                    if DoesEntityExist(station.tvEntity) then
                        anyValidTvEntityFound = true
                        local tvEntityCoords = GetEntityCoords(station.tvEntity)
                        local distanceToTv = #(playerCoords - tvEntityCoords)
                        station.shouldRender = (distanceToTv <= DYNO_STATION_INTERACTION_RADIUS)
                        if station.shouldRender then
                            stationsToRenderCount = stationsToRenderCount + 1
                        end
                    end
                end
            end

            if stationsToRenderCount > 0 then
                if not isGlobalRenderingActive then
                    startGlobalRenderingThreadInternal()
                end
            elseif stationsToRenderCount == 0 then
                if isGlobalRenderingActive then
                    stopGlobalRenderingThreadInternal()
                end
            end

            if not anyValidTvEntityFound then
                isZoneMonitoringActive = false
                zoneMonitoringThreadId = nil
                break
            end
            Wait(ZONE_MONITOR_INTERVAL_MS)
        end
    end)
end

local function stopZoneMonitoringThreadInternal()
    isZoneMonitoringActive = false
    zoneMonitoringThreadId = nil
end

local function updateGlobalThreads()
    local hasAnyDynoStation = false
    for _, station in pairs(dynoStations) do
        if station.duiObj and station.txdName and station.tvEntity then
            hasAnyDynoStation = true
            break
        end
    end

    if hasAnyDynoStation then
        if not isZoneMonitoringActive then
            startZoneMonitoringThreadInternal()
        end
    elseif not hasAnyDynoStation then
        stopGlobalRenderingThreadInternal()
        stopZoneMonitoringThreadInternal()
    end
end

local function removeDynoStation(stationKey)
    local station = dynoStations[stationKey]
    if not station then
        return
    end

    local zone = dynoStationZones[stationKey]
    if zone then
        zone:destroy()
        dynoStationZones[stationKey] = nil
    end

    if station.duiObj then
        DestroyDui(station.duiObj)
        station.duiObj = nil
    end

    if station.tvEntity and DoesEntityExist(station.tvEntity) then
        DeleteEntity(station.tvEntity)
    end
    station.tvEntity = nil
    station.shouldRender = false
    dynoStations[stationKey] = nil

    updateGlobalThreads()
end

local function createDynoStation(stationKey, shopId, pointData)
    removeDynoStation(stationKey)

    local dynoConfig = pointData.dyno
    if not dynoConfig or not dynoConfig.tvStand or not dynoConfig.configured then
        return false
    end

    local TV_STAND_MODEL_HASH = GetHashKey("prop_cs_tv_stand")
    RequestModel(TV_STAND_MODEL_HASH)

    local modelLoadAttempts = 0
    while not HasModelLoaded(TV_STAND_MODEL_HASH) do
        if modelLoadAttempts >= 5000 then -- 5000ms timeout
            break
        end
        Wait(100)
        modelLoadAttempts = modelLoadAttempts + 100
    end

    if not HasModelLoaded(TV_STAND_MODEL_HASH) then
        return false
    end

    local tvStandEntity = CreateObjectNoOffset(TV_STAND_MODEL_HASH, dynoConfig.tvStand.x, dynoConfig.tvStand.y, dynoConfig.tvStand.z, false, false, false)
    if not DoesEntityExist(tvStandEntity) then
        return false
    end

    SetEntityRotation(tvStandEntity, 0.0, 0.0, dynoConfig.tvStand.heading + 0.0, 2, false)
    FreezeEntityPosition(tvStandEntity, true)
    SetEntityAsMissionEntity(tvStandEntity, true, true)
    SetModelAsNoLongerNeeded(TV_STAND_MODEL_HASH)

    local dynoTxdName = "dyno_txd_" .. stationKey .. "_" .. math.random(1, 1000000)
    local dynoTxnName = "dyno_txn_" .. stationKey .. "_" .. math.random(1, 1000000)

    local runtimeTxd = CreateRuntimeTxd(dynoTxdName)
    local duiObject = CreateDui(NUI_URL, NUI_SCREEN_WIDTH, NUI_SCREEN_HEIGHT)
    local duiHandle = GetDuiHandle(duiObject)
    CreateRuntimeTextureFromDuiHandle(runtimeTxd, dynoTxnName, duiHandle)

    Wait(4000)
    sendNuiInitialConfig(duiObject)
    Wait(1000)

    SendDuiMessage(duiObject, json.encode({
        action = "setVisibility",
        data = { page = "dyno-tv", visible = true, shopId = shopId }
    }))
    SendDuiMessage(duiObject, json.encode({
        action = "dyno:setState",
        data = { state = "idle", message = t("dyno_tv_idle") }
    }))

    dynoStations[stationKey] = {
        shopId = shopId,
        pointId = pointData.id,
        stationKey = stationKey,
        tvEntity = tvStandEntity,
        duiObj = duiObject,
        txdName = dynoTxdName,
        txnName = dynoTxnName,
        platform = dynoConfig.platform,
        offsetX = dynoDebugConfig.offsetX, -- Use default debug config values
        offsetY = dynoDebugConfig.offsetY,
        offsetZ = dynoDebugConfig.offsetZ,
        screenWidth = dynoDebugConfig.screenWidth,
        screenHeight = dynoDebugConfig.screenHeight,
        shouldRender = false
    }

    updateGlobalThreads()
    return true
end

local function createDynoZone(stationKey, stationData)
    if not stationData or not stationData.platform then
        return
    end

    local platformCoords = vector3(stationData.platform.x, stationData.platform.y, stationData.platform.z)

    local zoneState = { inside = false }
    local existingZone = dynoStationZones[stationKey]
    if existingZone then
        existingZone:destroy()
    end
    Wait(200)

    dynoStationZones[stationKey] = BoxZone:Create(
        platformCoords,
        5.0, 5.0,
        {
            name = "dyno_station_zone_" .. stationKey,
            heading = stationData.platform.heading or 0.0,
            debugPoly = false,
            minZ = platformCoords.z - 1,
            maxZ = platformCoords.z + 2
        }
    )
    Wait(200)

    if not dynoStationZones[stationKey] then
        return
    end

    dynoStationZones[stationKey]:onPlayerInOut(function(isInside)
        zoneState.inside = isInside
        if zoneState.inside then
            Citizen.CreateThread(function()
                while true do
                    local playerPed = PlayerPedId()
                    local currentVehicle = GetVehiclePedIsIn(playerPed, false)

                    if isDynoTestRunning and activeDynoStationKey == stationKey then
                        bridge.HelpText.ShowHelpText("[G] " .. t("dyno_stop_test"))
                        if IsControlJustPressed(0, 47) then -- G key
                            stopDynoTest()
                        end
                    elseif currentVehicle and currentVehicle ~= 0 then
                        if not isDynoTestRunning then
                            bridge.HelpText.ShowHelpText("[E] " .. t("dyno_start_test"))
                            if IsControlJustPressed(0, 38) then -- E key
                                SetEntityCoords(currentVehicle, stationData.platform.x, stationData.platform.y, stationData.platform.z, false, false, false, false)
                                SetEntityHeading(currentVehicle, stationData.platform.heading)
                                Wait(200)
                                startDynoTest(currentVehicle, stationKey)
                            end
                        end
                    end

                    if not zoneState.inside then
                        return
                    end
                    Wait(1)
                end
            end)
        else
            Wait(200)
            zoneState.inside = false
            bridge.HelpText.HideHelpText()
        end
    end)
end

local function loadDynoStationsInternal()
    for stationKey, _ in pairs(dynoStations) do
        removeDynoStation(stationKey)
    end

    local mechanicPoints = bridge.Callback.Trigger("nn_mechanic:getAllPoints")
    if not mechanicPoints then
        return
    end

    for shopId, shopPointData in pairs(mechanicPoints) do
        for pointId, pointData in pairs(shopPointData) do
            if pointData.type == "dyno_station" and pointData.dyno and pointData.dyno.configured and pointData.enabled then
                local combinedKey = shopId .. "_" .. pointId
                local created = createDynoStation(combinedKey, shopId, { id = pointId, dyno = pointData.dyno })
                if created and dynoStations[combinedKey] then
                    createDynoZone(combinedKey, dynoStations[combinedKey])
                end
            end
        end
    end
end

LoadDynoStations = loadDynoStationsInternal

local function setupDynoStationPointInternal(shopId, pointId)
    local mechanicPoints = State.points or bridge.Callback.Trigger("nn_mechanic:getAllPoints")

    local pointData = mechanicPoints and mechanicPoints[shopId] and mechanicPoints[shopId][pointId]
    if not pointData then
        return
    end

    if pointData.type == "dyno_station" and pointData.dyno and pointData.dyno.configured and pointData.enabled then
        local combinedKey = shopId .. "_" .. pointId
        if dynoStations[combinedKey] then
            return
        end
        local created = createDynoStation(combinedKey, shopId, { id = pointId, dyno = pointData.dyno })
        if created and dynoStations[combinedKey] then
            createDynoZone(combinedKey, dynoStations[combinedKey])
        end
    end
end

SetupDynoStationPoint = setupDynoStationPointInternal

local function cleanupAllDynoStationsInternal()
    stopGlobalRenderingThreadInternal()
    stopZoneMonitoringThreadInternal()
    for stationKey, _ in pairs(dynoStations) do
        removeDynoStation(stationKey)
    end
end

CleanupAllDynoStations = cleanupAllDynoStationsInternal

RegisterNetEvent("nn_mechanic:refreshDynoStations", function()
    LoadDynoStations()
end)

AddEventHandler("onResourceStop", function(resourceNameStopped)
    if resourceNameStopped == currentResourceName then
        stopDynoTest()
        CleanupAllDynoStations()
    end
end)

local debugParamNames = {
    [1] = "offsetX",
    [2] = "offsetY",
    [3] = "offsetZ",
    [4] = "screenWidth",
    [5] = "screenHeight"
}

local debugParamSteps = {
    [1] = 0.01,
    [2] = 0.01,
    [3] = 0.01,
    [4] = 0.01,
    [5] = 0.01
}

if Config.Debug then
    RegisterCommand("dynodebug", function()
        if dynoDebugConfig.active then
            dynoDebugConfig.active = false
            print("========== DYNO DUI FINAL OFFSETS ==========")
            print(string.format("local offsetX = %.3f", dynoDebugConfig.offsetX))
            print(string.format("local offsetY = %.3f", dynoDebugConfig.offsetY))
            print(string.format("local offsetZ = %.3f", dynoDebugConfig.offsetZ))
            print(string.format("local screenWidth = %.3f", dynoDebugConfig.screenWidth))
            print(string.format("local screenHeight = %.3f", dynoDebugConfig.screenHeight))
            print("=============================================")
            TriggerEvent("chat:addMessage", { args = { "^2[Dyno Debug]", "Disabled. Check F8 console for final values." } })
            return
        end

        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestStationKey = nil
        local minDistance = 999

        for key, station in pairs(dynoStations) do
            if station.tvEntity and DoesEntityExist(station.tvEntity) then
                local tvEntityCoords = GetEntityCoords(station.tvEntity)
                local distanceToStation = #(playerCoords - tvEntityCoords)
                if minDistance > distanceToStation then
                    minDistance = distanceToStation
                    nearestStationKey = key
                end
            end
        end

        if not nearestStationKey or minDistance > DYNO_STATION_INTERACTION_RADIUS then
            TriggerEvent("chat:addMessage", { args = { "^1[Dyno Debug]", "No dyno station nearby!" } })
            return
        end

        dynoDebugConfig.active = true
        dynoDebugConfig.stationKey = nearestStationKey
        TriggerEvent("chat:addMessage", { args = { "^2[Dyno Debug]", "Enabled! Controls:" } })
        TriggerEvent("chat:addMessage", { args = { "^3[Controls]", "LEFT/RIGHT = Switch parameter | UP/DOWN = Adjust value | SHIFT = Fine adjust | Type /dynodebug again to finish" } })

        CreateThread(function()
            while true do
                if not dynoDebugConfig.active then
                    break
                end

                local station = dynoStations[dynoDebugConfig.stationKey]
                if not station or not station.tvEntity or not DoesEntityExist(station.tvEntity) then
                    dynoDebugConfig.active = false
                    break
                end

                DisableControlAction(0, 172, true) -- INPUT_LOOK_UP_ONLY
                DisableControlAction(0, 173, true) -- INPUT_LOOK_DOWN_ONLY
                DisableControlAction(0, 174, true) -- INPUT_LOOK_LEFT_ONLY
                DisableControlAction(0, 175, true) -- INPUT_LOOK_RIGHT_ONLY
                DisableControlAction(0, 21, true) -- INPUT_SPRINT (Shift)

                local fineAdjustMultiplier = IsControlPressed(0, 21) and 0.1 or 1.0
                local currentStep = debugParamSteps[dynoDebugConfig.currentParam] * fineAdjustMultiplier

                if IsControlJustPressed(0, 174) then -- LEFT
                    dynoDebugConfig.currentParam = dynoDebugConfig.currentParam - 1
                    if dynoDebugConfig.currentParam < 1 then
                        dynoDebugConfig.currentParam = #debugParamNames
                    end
                end
                if IsControlJustPressed(0, 175) then -- RIGHT
                    dynoDebugConfig.currentParam = dynoDebugConfig.currentParam + 1
                    if dynoDebugConfig.currentParam > #debugParamNames then
                        dynoDebugConfig.currentParam = 1
                    end
                end

                if IsControlPressed(0, 172) then -- UP
                    if dynoDebugConfig.currentParam == 1 then
                        dynoDebugConfig.offsetX = dynoDebugConfig.offsetX + currentStep
                    elseif dynoDebugConfig.currentParam == 2 then
                        dynoDebugConfig.offsetY = dynoDebugConfig.offsetY + currentStep
                    elseif dynoDebugConfig.currentParam == 3 then
                        dynoDebugConfig.offsetZ = dynoDebugConfig.offsetZ + currentStep
                    elseif dynoDebugConfig.currentParam == 4 then
                        dynoDebugConfig.screenWidth = dynoDebugConfig.screenWidth + currentStep
                    elseif dynoDebugConfig.currentParam == 5 then
                        dynoDebugConfig.screenHeight = dynoDebugConfig.screenHeight + currentStep
                    end
                end

                if IsControlPressed(0, 173) then -- DOWN
                    if dynoDebugConfig.currentParam == 1 then
                        dynoDebugConfig.offsetX = dynoDebugConfig.offsetX - currentStep
                    elseif dynoDebugConfig.currentParam == 2 then
                        dynoDebugConfig.offsetY = dynoDebugConfig.offsetY - currentStep
                    elseif dynoDebugConfig.currentParam == 3 then
                        dynoDebugConfig.offsetZ = dynoDebugConfig.offsetZ - currentStep
                    elseif dynoDebugConfig.currentParam == 4 then
                        dynoDebugConfig.screenWidth = dynoDebugConfig.screenWidth - currentStep
                    elseif dynoDebugConfig.currentParam == 5 then
                        dynoDebugConfig.screenHeight = dynoDebugConfig.screenHeight - currentStep
                    end
                end

                local debugMessage = string.format([[
~y~DYNO DEBUG MODE~w~

%soffsetX: ~y~%.3f~w~
%soffsetY: ~y~%.3f~w~
%soffsetZ: ~y~%.3f~w~
%sscreenWidth: ~y~%.3f~w~
%sscreenHeight: ~y~%.3f~w~

~c~LEFT/RIGHT = Switch | UP/DOWN = Adjust | SHIFT = Fine
]],
                    dynoDebugConfig.currentParam == 1 and "~g~> " or "  ", dynoDebugConfig.offsetX,
                    dynoDebugConfig.currentParam == 2 and "~g~> " or "  ", dynoDebugConfig.offsetY,
                    dynoDebugConfig.currentParam == 3 and "~g~> " or "  ", dynoDebugConfig.offsetZ,
                    dynoDebugConfig.currentParam == 4 and "~g~> " or "  ", dynoDebugConfig.screenWidth,
                    dynoDebugConfig.currentParam == 5 and "~g~> " or "  ", dynoDebugConfig.screenHeight
                )

                SetTextFont(4)
                SetTextScale(0.35, 0.35)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(debugMessage)
                EndTextCommandDisplayText(0.01, 0.3)

                local halfScreenWidth = dynoDebugConfig.screenWidth / 2
                local coord1 = GetOffsetFromEntityInWorldCoords(station.tvEntity, dynoDebugConfig.offsetX - halfScreenWidth, dynoDebugConfig.offsetY, 0)
                local coord2 = GetOffsetFromEntityInWorldCoords(station.tvEntity, dynoDebugConfig.offsetX + halfScreenWidth, dynoDebugConfig.offsetY, 0)
                local zAnchor = GetOffsetFromEntityInWorldCoords(station.tvEntity, 0, 0, dynoDebugConfig.offsetZ)
                local screenBottomZ = zAnchor.z - (dynoDebugConfig.screenHeight / 2)
                local screenTopZ = zAnchor.z + (dynoDebugConfig.screenHeight / 2)

                DrawSpritePoly(
                    coord2.x, coord2.y, screenBottomZ,
                    coord2.x, coord2.y, screenTopZ,
                    coord1.x, coord1.y, screenTopZ,
                    255, 255, 255, 255,
                    station.txdName, station.txnName,
                    1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0
                )

                DrawSpritePoly(
                    coord1.x, coord1.y, screenTopZ,
                    coord1.x, coord1.y, screenBottomZ,
                    coord2.x, coord2.y, screenBottomZ,
                    255, 255, 255, 255,
                    station.txdName, station.txnName,
                    0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0
                )

                Wait(0)
            end
        end)
    end, false)
end