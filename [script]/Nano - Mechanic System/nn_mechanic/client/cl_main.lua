if not bridge then
    bridge = exports.community_bridge.Bridge()
end

if not State then
    State = {}
end

State.openPage = nil
State.zones = {}
State.points = {}
State.employee = nil
State.shop = nil
State.currentShopId = nil
State.currentPointId = nil
State.isCapturingLocation = false
State.captureType = nil

if type(SetupManagementZone) ~= "function" then SetupManagementZone = function() end end
if type(SetupPointsZones) ~= "function" then SetupPointsZones = function(recreate) end end
if type(SetupShopVehicleUpgradeZones) ~= "function" then SetupShopVehicleUpgradeZones = function() end end
if type(CleanupShopVehicleUpgradeZones) ~= "function" then CleanupShopVehicleUpgradeZones = function() end end
if type(SetupColorMixingStations) ~= "function" then SetupColorMixingStations = function() end end
if type(CleanupColorMixingStations) ~= "function" then CleanupColorMixingStations = function() end end
if type(SetupPublicShopCatalogPoints) ~= "function" then SetupPublicShopCatalogPoints = function() end end
if type(SetupPublicShopManagementZones) ~= "function" then SetupPublicShopManagementZones = function() end end
if type(SetupLiftZones) ~= "function" then SetupLiftZones = function() end end
State.capturedShopLocation = nil
State.capturedManagementLocation = nil
State.cameraMovementActive = false

State.vehicleUpgradeCapture = {
    isCapturing = false,
    upgradeId = nil,
    locationType = nil,
    shopId = nil
}

State.pointCapture = {
    isCapturing = false,
    pointName = nil,
    pointType = nil,
    shopId = nil
}

State.vehicleProps = nil
State.servicePointsCtx = {}
State.currentPointCtxIndex = nil
State.repairInProgress = false
State.currentPartData = nil
State.currentMenuId = nil
State.menuControlsThread = nil
State.liftStates = {}
State.activeLiftIndex = nil
State.liftArmsHeight = {}
State.carLifts = {}
State.carLiftArms = {}
State.movingLifts = {}
State.colorMixingStations = {}
State.shopBlips = {}
State.pointMarkers = {}

State.compressor = {
    compressor = nil,
    rope = nil,
    dummyObj = nil,
    vehicle = nil,
    wheelIndex = nil,
    boneName = nil,
    plate = nil
}

RuntimeLifts = {}

function GetPointKey(shopId, pointId)
    return string.format("%s_%s", shopId, pointId)
end

function GetAllPartDepositCoords()
    local coords = {}
    local points = State.points or {}
    
    for shopId, shopPoints in pairs(points) do
        for pointId, pointData in pairs(shopPoints or {}) do
            if pointData.type == "part_deposit" and pointData.enabled then
                table.insert(coords, vector3(
                    pointData.coords.x,
                    pointData.coords.y,
                    pointData.coords.z
                ))
            end
        end
    end
    
    return coords
end

-- function CreateLiftConfig(shopId, pointId, pointData)
--     if pointData.type ~= "car_lift" or not pointData.spawnCoords or not pointData.lift or not pointData.lift.style then
--         return nil
--     end
    
--     if not pointData.enabled then
--         return nil
--     end
    
--     local style = tonumber(pointData.lift.style) or pointData.lift.style
--     local liftStyle = Config.NanoLiftStyles[style]
--     if not liftStyle then
--         return nil
--     end
    
--     local baseZ = pointData.spawnCoords.z
--     local liftHeight = 2.1
    
--     local vehicleOffset = liftStyle.vehicleOffset
--     if type(vehicleOffset) == "number" then
--         vehicleOffset = vector3(0.0, 0.0, vehicleOffset)
--     elseif not vehicleOffset then
--         vehicleOffset = vector3(0.0, 0.0, 0.0)
--     end
    
--     return {
--         base = vector4(
--             pointData.spawnCoords.x,
--             pointData.spawnCoords.y,
--             pointData.spawnCoords.z,
--             pointData.spawnCoords.heading or 0.0
--         ),
--         prop = liftStyle.body,
--         armsProp = liftStyle.arms,
--         armsOffset = liftStyle.armsOffset or vector3(0.0, 0.0, 0.0),
--         armsRotation = liftStyle.armsRotation or vector3(0.0, 0.0, 0.0),
--         vehicleOffset = vehicleOffset,
--         interactionCoords = pointData.coords and vector3(
--             pointData.coords.x,
--             pointData.coords.y,
--             pointData.coords.z
--         ) or nil,
--         maxZ = baseZ + liftHeight,
--         minZ = baseZ - 0.02,
--         style = style,
--         shopId = shopId,
--         pointId = pointId
--     }
--     end
-- end

function CreateLiftConfig(shopId, pointId, pointData)
    if pointData.type ~= "car_lift" or not pointData.spawnCoords or not pointData.lift or not pointData.lift.style then
        return nil
    end
    
    if not pointData.enabled then
        return nil
    end
    
    local style = tonumber(pointData.lift.style) or pointData.lift.style
    local liftStyle = Config.NanoLiftStyles[style]
    if not liftStyle then
        return nil
    end
    
    local baseZ = pointData.spawnCoords.z
    local liftHeight = 2.1
    
    local vehicleOffset = liftStyle.vehicleOffset
    if type(vehicleOffset) == "number" then
        vehicleOffset = vector3(0.0, 0.0, vehicleOffset)
    elseif not vehicleOffset then
        vehicleOffset = vector3(0.0, 0.0, 0.0)
    end
    
    return {
        base = vector4(
            pointData.spawnCoords.x,
            pointData.spawnCoords.y,
            pointData.spawnCoords.z,
            pointData.spawnCoords.heading or 0.0
        ),
        prop = liftStyle.body,
        armsProp = liftStyle.arms,
        armsOffset = liftStyle.armsOffset or vector3(0.0, 0.0, 0.0),
        armsRotation = liftStyle.armsRotation or vector3(0.0, 0.0, 0.0),
        vehicleOffset = vehicleOffset,
        interactionCoords = pointData.coords and vector3(
            pointData.coords.x,
            pointData.coords.y,
            pointData.coords.z
        ) or nil,
        maxZ = baseZ + liftHeight,
        minZ = baseZ - 0.02,
        style = style,
        shopId = shopId,
        pointId = pointId
    }
end

function InitializeLifts()
    RuntimeLifts = {}
    local points = State.points or {}
    
    for shopId, shopPoints in pairs(points) do
        for pointId, pointData in pairs(shopPoints or {}) do
            if pointData.type == "car_lift" then
                local liftConfig = CreateLiftConfig(shopId, pointId, pointData)
                if liftConfig then
                    local liftKey = string.format("shop_%s_lift_%s", shopId, pointId)
                    RuntimeLifts[liftKey] = liftConfig
                end
            end
        end
    end
end

-- Create point marker
function CreatePointMarker(shopId, pointId, pointData)
    if not pointData.coords or not pointData.markerEnabled or not pointData.enabled then
        return
    end
    
    local markerKey = GetPointKey(shopId, pointId)
    if State.pointMarkers[markerKey] then
        return
    end
    
    local markerConfig = Config.PointMarkers
    if not markerConfig then
        return
    end
    
    local colors = markerConfig.colors
    local color = (colors and colors[pointData.type]) or { r = 255, g = 255, b = 255 }
    
    local zOffset = markerConfig.zOffset or -0.5
    local position = vector3(
        pointData.coords.x,
        pointData.coords.y,
        pointData.coords.z + zOffset
    )
    
    local marker = bridge.Marker.Create({
        position = position,
        marker = markerConfig.markerType or 1,
        size = markerConfig.size or vector3(2.0, 2.0, 1.0),
        color = vector3(color.r, color.g, color.b),
        alpha = markerConfig.alpha or 150,
        bobUpAndDown = markerConfig.bobUpAndDown == true,
        drawDistance = markerConfig.drawDistance or 50.0
    })
    
    if marker then
        State.pointMarkers[markerKey] = marker
    end
end

-- Remove point marker
function RemovePointMarker(shopId, pointId)
    local markerKey = GetPointKey(shopId, pointId)
    local marker = State.pointMarkers[markerKey]
    
    if marker then
        bridge.Marker.Remove(marker)
        State.pointMarkers[markerKey] = nil
    end
end

-- Update point marker visibility
function UpdatePointMarker(shopId, pointId, pointData)
    local markerKey = GetPointKey(shopId, pointId)
    local hasMarker = State.pointMarkers[markerKey] ~= nil
    local shouldHaveMarker = pointData and pointData.markerEnabled and pointData.enabled
    
    if shouldHaveMarker and not hasMarker then
        CreatePointMarker(shopId, pointId, pointData)
    elseif not shouldHaveMarker and hasMarker then
        RemovePointMarker(shopId, pointId)
    end
end

-- Refresh all point markers
function RefreshAllPointMarkers()
    -- Remove all existing markers
    for markerKey, marker in pairs(State.pointMarkers) do
        bridge.Marker.Remove(marker)
    end
    State.pointMarkers = {}
    
    -- Recreate markers for enabled points
    local points = State.points or {}
    for shopId, shopPoints in pairs(points) do
        for pointId, pointData in pairs(shopPoints or {}) do
            if pointData.markerEnabled and pointData.enabled then
                CreatePointMarker(shopId, pointId, pointData)
            end
        end
    end
end

-- Destroy all point markers
function DestroyAllPointMarkers()
    for _, marker in pairs(State.pointMarkers) do
        bridge.Marker.Remove(marker)
    end
    State.pointMarkers = {}
end

-- Vehicle upgrade marker helpers
function GetVehicleUpgradeMarkerKey(shopId, upgradeId)
    return string.format("vehicle_%s_%s", shopId, upgradeId)
end

function CreateVehicleUpgradeMarker(shopId, upgradeId, upgradeData)
    if not upgradeData.interactionLocation or not upgradeData.markerEnabled then
        return
    end
    
    local markerKey = GetVehicleUpgradeMarkerKey(shopId, upgradeId)
    if State.vehicleUpgradeMarkers[markerKey] then
        return
    end
    
    local markerConfig = Config.PointMarkers
    if not markerConfig then
        return
    end
    
    local color = (markerConfig.colors and markerConfig.colors.customer_garage) or { r = 245, g = 158, b = 11 }
    local zOffset = markerConfig.zOffset or -0.5
    
    local marker = bridge.Marker.Create({
        position = vector3(
            upgradeData.interactionLocation.x,
            upgradeData.interactionLocation.y,
            upgradeData.interactionLocation.z + zOffset
        ),
        marker = markerConfig.markerType or 1,
        size = markerConfig.size or vector3(2.0, 2.0, 1.0),
        color = vector3(color.r, color.g, color.b),
        alpha = markerConfig.alpha or 150,
        bobUpAndDown = markerConfig.bobUpAndDown == true,
        drawDistance = markerConfig.drawDistance or 50.0
    })
    
    if marker then
        State.vehicleUpgradeMarkers[markerKey] = marker
    end
end

function RemoveVehicleUpgradeMarker(shopId, upgradeId)
    local markerKey = GetVehicleUpgradeMarkerKey(shopId, upgradeId)
    local marker = State.vehicleUpgradeMarkers[markerKey]
    
    if marker then
        bridge.Marker.Remove(marker)
        State.vehicleUpgradeMarkers[markerKey] = nil
    end
end

function UpdateVehicleUpgradeMarker(shopId, upgradeId, upgradeData)
    local markerKey = GetVehicleUpgradeMarkerKey(shopId, upgradeId)
    local hasMarker = State.vehicleUpgradeMarkers[markerKey] ~= nil
    local shouldHaveMarker = upgradeData and upgradeData.markerEnabled and upgradeData.interactionLocation
    
    if shouldHaveMarker and not hasMarker then
        CreateVehicleUpgradeMarker(shopId, upgradeId, upgradeData)
    elseif not shouldHaveMarker and hasMarker then
        RemoveVehicleUpgradeMarker(shopId, upgradeId)
    end
end

function RefreshAllVehicleUpgradeMarkers()
    -- Remove all existing markers
    for _, marker in pairs(State.vehicleUpgradeMarkers) do
        bridge.Marker.Remove(marker)
    end
    State.vehicleUpgradeMarkers = {}
    
    -- Recreate markers for current shop
    if State.shop and State.shop.vehicleUpgrades then
        for upgradeId, upgradeData in pairs(State.shop.vehicleUpgrades) do
            if upgradeData.markerEnabled and upgradeData.interactionLocation then
                CreateVehicleUpgradeMarker(State.shop.id, upgradeId, upgradeData)
            end
        end
    end
end

function DestroyAllVehicleUpgradeMarkers()
    for _, marker in pairs(State.vehicleUpgradeMarkers) do
        bridge.Marker.Remove(marker)
    end
    State.vehicleUpgradeMarkers = {}
end

-- Zone management
local activeZones = {}

function DestroyAllZones()
    for zoneId, zone in pairs(activeZones) do
        if zone.destroy then
            zone.destroy(zone)
        elseif zone.remove then
            zone.remove(zone)
        end
    end
    activeZones = {}
    State.zones = {}
end

-- Car lift arm movement
function MoveAttachedArms(liftKey, targetZ)
    local arms = State.carLiftArms[liftKey]
    if not arms or not DoesEntityExist(arms) then
        return
    end
    
    local liftConfig = RuntimeLifts[liftKey]
    local armsOffset = (liftConfig and liftConfig.armsOffset) or vector3(0.0, 0.0, 0.0)
    local currentPos = GetEntityCoords(arms)
    local newZ = targetZ + armsOffset.z
    
    SetEntityCoords(arms, currentPos.x, currentPos.y, newZ, false, false, false, false)
end

-- Spawn all lifts
function SpawnAllLifts()
    for liftKey, liftConfig in pairs(RuntimeLifts) do
        if HasLiftProp(liftConfig) then
            if State.carLifts[liftKey] and DoesEntityExist(State.carLifts[liftKey]) then
                -- Already exists
            else
                SpawnCarLift(liftKey, liftConfig)
            end
        end
    end
end

-- Delete all lifts
function DeleteAllLifts()
    for liftKey, _ in pairs(State.carLifts) do
        DeleteCarLift(liftKey)
    end
end

-- Refresh lifts (reconcile with runtime config)
function RefreshLifts()
    DestroyAllZones()
    
    -- Delete lifts that no longer exist in runtime
    for liftKey, _ in pairs(State.carLifts) do
        if not RuntimeLifts[liftKey] then
            DeleteCarLift(liftKey)
        end
    end
    
    SpawnAllLifts()
    
    -- Setup lift zones if employee has permission
    if State.employee and (State.employee.isOwner or (State.employee.permissions and State.employee.permissions.lift == true)) then
        SetupLiftZones()
    end
end

-- Get current instruction step
function GetCurrentInstructionStep()
    local instructions = StateInstructions.currentInstructions
    if not instructions or #instructions == 0 then
        return nil
    end
    
    for stepIndex, step in ipairs(instructions) do
        if not step.completed then
            return stepIndex
        end
    end
    
    return #instructions
end

-- Start menu controls thread
function StartMenuControlsThread()
    if State.menuControlsThread then
        return
    end
    
    State.menuControlsThread = Citizen.CreateThread(function()
        while State.openPage == "menu" and State.currentMenuId do
            -- Disable navigation controls
            DisableControlAction(0, 172, true)  -- Up
            DisableControlAction(0, 173, true)  -- Down
            DisableControlAction(0, 174, true)  -- Left
            DisableControlAction(0, 175, true)  -- Right
            DisableControlAction(0, 191, true)  -- Enter
            
            -- Handle navigation
            if IsDisabledControlJustPressed(0, 172) then
                SendNUIMessage({
                    action = "menuNavigate",
                    data = { direction = "up", menuId = State.currentMenuId }
                })
            elseif IsDisabledControlJustPressed(0, 173) then
                SendNUIMessage({
                    action = "menuNavigate",
                    data = { direction = "down", menuId = State.currentMenuId }
                })
            elseif IsDisabledControlJustPressed(0, 174) then
                SendNUIMessage({
                    action = "menuNavigate",
                    data = { direction = "left", menuId = State.currentMenuId }
                })
            elseif IsDisabledControlJustPressed(0, 175) then
                SendNUIMessage({
                    action = "menuNavigate",
                    data = { direction = "right", menuId = State.currentMenuId }
                })
            elseif IsDisabledControlJustPressed(0, 191) then
                SendNUIMessage({
                    action = "menuNavigate",
                    data = { direction = "enter", menuId = State.currentMenuId }
                })
            end
            
            Wait(0)
        end
        
        State.menuControlsThread = nil
    end)
end

-- Open management UI
function OpenManagement()
    State.openPage = "management"
    
    SendNUIMessage({
        action = "setManagementData",
        data = {
            managementData = State.shop,
            vehicleUpgrades = Config.VehicleUpgrades,
            currentEmployee = State.employee
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "management" }
    })
    
    SetNuiFocus(true, true)
    TriggerScreenblurFadeIn(500)
end

-- Open computer UI
function OpenComputer()
    State.openPage = "computer"
    
    -- Fetch shop prices and limits
    local priceData = bridge.Callback.Trigger("nn_mechanic:getShopPrices")
    local limitData = bridge.Callback.Trigger("nn_mechanic:getPriceLimits")
    
    if priceData and limitData then
        Wait(1000)
        
        SendNUIMessage({
            action = "setPriceManagementData",
            data = {
                prices = priceData.prices or {},
                limits = limitData.limits or {},
                defaultMarkup = priceData.defaultMarkup or 0.2,
                supplierPrices = priceData.supplierPrices or {}
            }
        })
        
        -- Double-send to ensure data is received
        Citizen.CreateThread(function()
            Wait(2000)
            SendNUIMessage({
                action = "setPriceManagementData",
                data = {
                    prices = priceData.prices or {},
                    limits = limitData.limits or {},
                    defaultMarkup = priceData.defaultMarkup or 0.2,
                    supplierPrices = priceData.supplierPrices or {}
                }
            })
        end)
    end
    
    -- Set permissions
    local permissions = (State.employee and State.employee.permissions) or {}
    SendNUIMessage({
        action = "setComputerPermissions",
        data = {
            canAccessPricing = permissions.prices == true,
            canAccessLogs = permissions.management == true,
            employeeRole = (State.employee and (State.employee.roleName or State.employee.role)) or nil
        }
    })
    
    -- Set supply catalog
    SendNUIMessage({
        action = "setMechSupplyCatalog",
        data = Config.MechSupplyCatalog or { categories = {}, items = {} }
    })
    
    -- Set universal items config
    SendNUIMessage({
        action = "setUniversalItemsConfig",
        data = {
            enabled = (Config.UniversalItems and Config.UniversalItems.enabled) == true,
            catalog = (Config.UniversalItems and Config.UniversalItems.catalog) or {},
            deliveryTime = (Config.UniversalItems and Config.UniversalItems.deliveryTime) or 5
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "computer" }
    })
    
    SetNuiFocus(true, true)
    TriggerScreenblurFadeIn(500)
    DisplayRadar(false)
end

-- Create shop blip
function CreateShopBlip(shopData)
    if not shopData or not shopData.shopLocation then
        return
    end
    
    -- Remove existing blip
    if State.shopBlips[shopData.id] then
        RemoveBlip(State.shopBlips[shopData.id])
        State.shopBlips[shopData.id] = nil
    end
    
    local position = vector3(
        shopData.shopLocation.x,
        shopData.shopLocation.y,
        shopData.shopLocation.z
    )
    
    local blip = AddBlipForCoord(position.x, position.y, position.z)
    SetBlipSprite(blip, shopData.blipSprite or 1)
    SetBlipColour(blip, shopData.blipColor or 0)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(shopData.name or "Mechanic Shop")
    EndTextCommandSetBlipName(blip)
    
    State.shopBlips[shopData.id] = blip
end

-- Update shop blip
function UpdateShopBlip(shopData)
    if not shopData or not State.shopBlips[shopData.id] then
        return
    end
    
    local blip = State.shopBlips[shopData.id]
    SetBlipSprite(blip, shopData.blipSprite or 1)
    SetBlipColour(blip, shopData.blipColor or 0)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(shopData.name or "Mechanic Shop")
    EndTextCommandSetBlipName(blip)
end

-- Remove shop blip
function RemoveShopBlip(shopId)
    local blip = State.shopBlips[shopId]
    if blip then
        RemoveBlip(blip)
        State.shopBlips[shopId] = nil
    end
end

-- Create all shop blips
function CreateAllShopBlips()
    print("[nn_mechanic] Triggering getAllShops callback...")
    local shops = bridge.Callback.Trigger("nn_mechanic:getAllShops")
    print("[nn_mechanic] getAllShops returned.")
    if shops then
        for _, shopData in ipairs(shops) do
            CreateShopBlip(shopData)
        end
    end
end

-- Initialize everything
function Init()
    print("[nn_mechanic] Init() starting...")
    -- Set translations
    SendNUIMessage({
        action = "setTranslations",
        data = { translations = Translations[Config.Language] }
    })
    
    print("[nn_mechanic] Triggering getPlayerShop callback...")
    -- Get player shop data
    local shopData = bridge.Callback.Trigger("nn_mechanic:getPlayerShop")
    print("[nn_mechanic] getPlayerShop returned.")
    
    if shopData then
        State.shop = shopData.shop
        State.employee = shopData.employee
        
        SetupManagementZone()
        SetupPointsZones()
        SetupShopVehicleUpgradeZones()
    end
    
    SetupColorMixingStations()
    SetupPublicShopCatalogPoints()
    
    print("[nn_mechanic] Triggering canAdminManageShops callback...")
    -- Setup admin management zones if applicable
    local canAdmin = bridge.Callback.Trigger("nn_mechanic:canAdminManageShops")
    print("[nn_mechanic] canAdminManageShops returned: " .. tostring(canAdmin))
    if canAdmin then
        SetupPublicShopManagementZones()
    end
    
    print("[nn_mechanic] Creating all shop blips...")
    CreateAllShopBlips()
    
    -- Load points if not already loaded
    if not State.points or next(State.points) == nil then
        print("[nn_mechanic] Triggering getAllPoints callback...")
        local allPoints = bridge.Callback.Trigger("nn_mechanic:getAllPoints")
        print("[nn_mechanic] getAllPoints returned.")
        if allPoints then
            State.points = allPoints
        end
    end
    
    InitializeLifts()
    SetupLiftZones()
    print("[nn_mechanic] Init() finished.")
end

-- Update ped and vehicle references periodically
Citizen.CreateThread(function()
    while true do
        State.Ped = PlayerPedId()
        State.Vehicle = GetVehiclePedIsIn(State.Ped, false)
        Wait(500)
    end
end)

-- Check if lift config has a prop
function HasLiftProp(liftConfig)
    return liftConfig and liftConfig.prop and type(liftConfig.prop) == "string"
end

-- Get closest lift spot to position
function GetClosestLiftSpot(position)
    local closestKey = nil
    local closestConfig = nil
    local closestDist = nil
    local searchRadius = Config.CarLiftSearchRadius or 25.0
    
    for liftKey, liftConfig in pairs(RuntimeLifts) do
        local liftPos = liftConfig.interactionCoords or vector3(
            liftConfig.base.x,
            liftConfig.base.y,
            liftConfig.base.z
        )
        
        local dist = #(position - liftPos)
        if dist <= searchRadius and (not closestDist or closestDist > dist) then
            closestDist = dist
            closestKey = liftKey
            closestConfig = liftConfig
        end
    end
    
    return closestKey, closestConfig, closestDist
end

-- Spawn car lift
function SpawnCarLift(liftKey, liftConfig)
    if not HasLiftProp(liftConfig) then
        return nil
    end
    
    -- Check if already exists
    if State.carLifts[liftKey] and DoesEntityExist(State.carLifts[liftKey]) then
        return State.carLifts[liftKey]
    end
    
    local modelHash = GetHashKey(liftConfig.prop)
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(modelHash) then
        return nil
    end
    
    local liftObj = CreateObject(modelHash,
        liftConfig.base.x, liftConfig.base.y, liftConfig.base.z,
        false, false, false)
    
    if not liftObj or liftObj == 0 then
        return nil
    end
    
    SetEntityHeading(liftObj, liftConfig.base.w or 0.0)
    SetEntityAsMissionEntity(liftObj, true, true)
    SetModelAsNoLongerNeeded(modelHash)
    PlaceObjectOnGroundProperly(liftObj)
    FreezeEntityPosition(liftObj, true)
    
    State.carLifts[liftKey] = liftObj
    
    -- Spawn arms if configured
    if liftConfig.armsProp then
        SpawnCarLiftArms(liftKey, liftConfig, liftObj)
    end
    
    return liftObj
end

-- Spawn car lift arms
function SpawnCarLiftArms(liftKey, liftConfig, liftObj)
    if not liftConfig.armsProp then
        return nil
    end
    
    -- Remove existing arms
    if State.carLiftArms[liftKey] and DoesEntityExist(State.carLiftArms[liftKey]) then
        DeleteEntity(State.carLiftArms[liftKey])
        State.carLiftArms[liftKey] = nil
    end
    
    local modelHash = GetHashKey(liftConfig.armsProp)
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(modelHash) then
        return nil
    end
    
    local liftPos = GetEntityCoords(liftObj)
    local liftHeading = GetEntityHeading(liftObj)
    
    local armsOffset = liftConfig.armsOffset or vector3(0.0, 0.0, -0.5)
    local armsRotation = liftConfig.armsRotation or vector3(0.0, 0.0, 0.0)
    
    -- Calculate offset position based on heading
    local radHeading = math.rad(liftHeading)
    local offsetX = armsOffset.x * math.cos(radHeading) - armsOffset.y * math.sin(radHeading)
    local offsetY = armsOffset.x * math.sin(radHeading) + armsOffset.y * math.cos(radHeading)
    
    local spawnX = liftPos.x + offsetX
    local spawnY = liftPos.y + offsetY
    local spawnZ = liftPos.z + armsOffset.z
    
    local armsObj = CreateObject(modelHash, spawnX, spawnY, spawnZ - 0.1, false, false, false)
    
    if not armsObj or armsObj == 0 then
        return nil
    end
    
    SetEntityHeading(armsObj, liftHeading + armsRotation.z)
    SetEntityRotation(armsObj, armsRotation.x, armsRotation.y, liftHeading + armsRotation.z, 2, true)
    SetEntityAsMissionEntity(armsObj, true, true)
    SetModelAsNoLongerNeeded(modelHash)
    FreezeEntityPosition(armsObj, true)
    
    State.carLiftArms[liftKey] = armsObj
    return armsObj
end

-- Delete car lift
function DeleteCarLift(liftKey)
    -- Delete arms first
    if State.carLiftArms[liftKey] and DoesEntityExist(State.carLiftArms[liftKey]) then
        DeleteEntity(State.carLiftArms[liftKey])
        State.carLiftArms[liftKey] = nil
    end
    
    -- Delete lift body
    if State.carLifts[liftKey] and DoesEntityExist(State.carLifts[liftKey]) then
        DeleteEntity(State.carLifts[liftKey])
        State.carLifts[liftKey] = nil
    end
end

-- Get car lift entity (existing or find in world)
function GetCarLiftEntity(liftKey)
    local liftConfig = RuntimeLifts[liftKey]
    if not liftConfig or not HasLiftProp(liftConfig) then
        return nil
    end
    
    -- Return cached entity if exists
    if State.carLifts[liftKey] and DoesEntityExist(State.carLifts[liftKey]) then
        return State.carLifts[liftKey]
    end
    
    -- Try to find existing object in world
    local modelHash = GetHashKey(liftConfig.prop)
    local foundObj = GetClosestObjectOfType(
        liftConfig.base.x, liftConfig.base.y, liftConfig.base.z,
        5.0, modelHash, false, false, false
    )
    
    if foundObj and DoesEntityExist(foundObj) then
        State.carLifts[liftKey] = foundObj
        return foundObj
    end
    
    return nil
end

-- Get lift moving entity (arms or body)
function GetLiftMovingEntity(liftKey)
    local arms = State.carLiftArms[liftKey]
    if arms and DoesEntityExist(arms) then
        return arms, true
    end
    
    local body = State.carLifts[liftKey]
    if body and DoesEntityExist(body) then
        return body, false
    end
    
    return nil, false
end

-- Check if lift is at minimum height
function IsLiftAtMin(liftKey)
    local liftConfig = RuntimeLifts[liftKey]
    if not liftConfig then
        return false
    end
    
    local liftState = State.liftStates[liftKey]
    if liftState and liftState.isMoving then
        return false
    end
    
    local liftEntity, isArms = GetLiftMovingEntity(liftKey)
    if not liftEntity or not DoesEntityExist(liftEntity) then
        return true
    end
    
    local minZ = liftConfig.minZ
    if isArms then
        local armsOffset = liftConfig.armsOffset or vector3(0.0, 0.0, 0.0)
        minZ = minZ + armsOffset.z
    end
    
    local entityZ = GetEntityCoords(liftEntity).z
    return math.abs(entityZ - minZ) <= 0.5
end

-- Update lift movement (called each frame during movement)
function UpdateLiftMovement(liftKey, liftConfig, liftEntity, isArms)
    local currentZ = State.liftArmsHeight[liftKey]
    if not currentZ then
        return false
    end
    
    local minZ = liftConfig.minZ
    local maxZ = liftConfig.maxZ
    
    if isArms then
        local armsOffset = liftConfig.armsOffset or vector3(0.0, 0.0, 0.0)
        minZ = minZ + armsOffset.z
        maxZ = maxZ + armsOffset.z
    end
    
    local direction = State.movingLifts[liftKey]
    local shouldStop = false
    
    if currentZ >= maxZ and direction == "up" then
        currentZ = maxZ
        shouldStop = true
    elseif currentZ <= minZ and direction == "down" then
        currentZ = minZ
        shouldStop = true
    end
    
    if direction == "up" then
        currentZ = currentZ + 0.001
    elseif direction == "down" then
        currentZ = currentZ - 0.001
    end
    
    State.liftArmsHeight[liftKey] = currentZ
    
    -- Update entity position
    local currentPos = GetEntityCoords(liftEntity)
    FreezeEntityPosition(liftEntity, false)
    SetEntityCoordsNoOffset(liftEntity, currentPos.x, currentPos.y, currentZ, false, false, false)
    FreezeEntityPosition(liftEntity, true)
    
    -- Update attached arms if this is the body
    MoveAttachedArms(liftKey, currentZ)
    
    -- Update UI
    local totalRange = maxZ - minZ
    local currentHeight = math.max(0, currentZ - minZ)
    
    if not State.lastLiftUIUpdate or GetGameTimer() - State.lastLiftUIUpdate > 50 then
        State.lastLiftUIUpdate = GetGameTimer()
        SendNUIMessage({
            action = "updateLiftStatus",
            data = {
                height = currentHeight,
                maxHeight = totalRange,
                isMoving = not shouldStop,
                direction = direction
            }
        })
    end
    
    return not shouldStop
end

-- Request lift movement start
function RequestLiftStart(liftKey, direction)
    if State.movingLifts[liftKey] then
        return
    end
    
    local liftEntity, isArms = GetLiftMovingEntity(liftKey)
    local startZ = 0
    
    if liftEntity then
        startZ = GetEntityCoords(liftEntity).z
    else
        local liftConfig = RuntimeLifts[liftKey]
        if liftConfig then
            startZ = liftConfig.minZ
        end
    end
    
    TriggerServerEvent("nn_mechanic:startLiftMovement", liftKey, direction, startZ)
end

-- Request lift movement stop
function RequestLiftStop(liftKey)
    if not State.movingLifts[liftKey] then
        return
    end
    
    local liftEntity, isArms = GetLiftMovingEntity(liftKey)
    local x, y, z = 0, 0, 0
    
    if liftEntity then
        local pos = GetEntityCoords(liftEntity)
        x, y, z = pos.x, pos.y, pos.z
    end
    
    TriggerServerEvent("nn_mechanic:stopLiftMovement", liftKey, x, y, z)
end

-- NUI Callbacks
RegisterNUICallback("moveLift", function(data, cb)
    local liftIndex = data.liftIndex or State.activeLiftIndex
    if not liftIndex then
        cb({})
        return
    end
    
    RequestLiftStart(liftIndex, data.direction)
    
    -- Update lift state
    UpdateLiftState({ isMoving = true }, liftIndex)
    
    -- Start sound
    local liftConfig = RuntimeLifts[liftIndex]
    if liftConfig then
        local liftEntity = GetCarLiftEntity(liftIndex)
        local soundPos = liftEntity and GetEntityCoords(liftEntity) or vector3(
            liftConfig.coords and liftConfig.coords.x or liftConfig.base.x,
            liftConfig.coords and liftConfig.coords.y or liftConfig.base.y,
            liftConfig.coords and liftConfig.coords.z or liftConfig.base.z
        )
        TriggerServerEvent("nn_mechanic:liftSoundStart", liftIndex, soundPos)
    end
    
    cb({})
end)

RegisterNUICallback("stopLift", function(data, cb)
    local liftIndex = data.liftIndex or State.activeLiftIndex
    if not liftIndex then
        cb({})
        return
    end
    
    RequestLiftStop(liftIndex)
    
    -- Stop sound
    local liftConfig = RuntimeLifts[liftIndex]
    local soundPos = nil
    if liftConfig then
        local liftEntity = GetCarLiftEntity(liftIndex)
        soundPos = liftEntity and GetEntityCoords(liftEntity) or vector3(
            liftConfig.coords and liftConfig.coords.x or liftConfig.base.x,
            liftConfig.coords and liftConfig.coords.y or liftConfig.base.y,
            liftConfig.coords and liftConfig.coords.z or liftConfig.base.z
        )
    end
    TriggerServerEvent("nn_mechanic:liftSoundStop", liftIndex, soundPos)
    
    Wait(500)
    OnLiftMovementStopped(liftIndex)
    
    -- Check if we need to show menus
    if State.openPage ~= "menu" then
        CheckAndShowOilBoltMenu()
        CheckAndShowBrakePadMenu()
    end
    
    cb({})
end)

RegisterNUICallback("hideFrame", function(_, cb)
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, action = "setVisible" }
    })
    
    -- Handle page-specific cleanup
    local openPage = State.openPage
    
    if openPage == "catalog" then
        local vehicle = GetVehiclePedIsIn(State.Ped, false)
        if vehicle and DoesEntityExist(vehicle) then
            if State.vehicleProps then
                setVehicleProperties(vehicle, State.vehicleProps)
            end
            if State.initialWindowTint ~= nil then
                SetVehicleWindowTint(vehicle, State.initialWindowTint == -1 and 0 or State.initialWindowTint)
            end
        end
        stopDragCam()
        
    elseif openPage == "tablet" then
        ToggleTablet(false)
        TriggerScreenblurFadeOut(500)
        
    elseif openPage == "lights-control" then
        if LightsControl_DisconnectAndPersist then
            LightsControl_DisconnectAndPersist()
        end
        
    elseif openPage == "fluid-minigame" then
        local pointIndex = State.currentPointCtxIndex
        if pointIndex then
            local ctx = State.servicePointsCtx[pointIndex]
            if ctx and ctx.repairState and ctx.repairState.oilChange and ctx.repairState.oilChange.inProgress then
                if IsInstructionStepCompleted(5) and not IsInstructionStepCompleted(6) then
                    if ctx.repairState.menus then
                        ctx.repairState.menus.refillOilMenu = false
                    end
                    RefillOil()
                end
            end
        end
        
    elseif openPage == "car-lift-control" then
        -- Auto-handled by lift state
    end
    
    State.openPage = nil
    State.DispatchOpen = false
    
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.OnUIClosed()
    end
    
    cb("ok")
end)

-- Event handlers
RegisterNetEvent("nn_mechanic:updateShopState")
AddEventHandler("nn_mechanic:updateShopState", function(data)
    local oldPoints = State.shop and State.shop.points
    local newPoints = data.shop.points
    
    State.shop = data.shop
    State.employee = data.employee
    
    -- Refresh UI if management is open
    if State.openPage == "management" then
        SendNUIMessage({
            action = "setManagementData",
            data = {
                managementData = State.shop,
                vehicleUpgrades = Config.VehicleUpgrades,
                currentEmployee = State.employee
            }
        })
    end
    
    SetupShopVehicleUpgradeZones()
    
    -- Check if points changed significantly
    if newPoints then
        local shouldRecreate = false
        
        if not oldPoints then
            shouldRecreate = true
        else
            local oldCount = 0
            local newCount = 0
            
            for _ in pairs(oldPoints) do oldCount = oldCount + 1 end
            for _ in pairs(newPoints) do newCount = newCount + 1 end
            
            if oldCount ~= newCount then
                shouldRecreate = true
            else
                for pointId, pointData in pairs(newPoints) do
                    local oldPoint = oldPoints[pointId]
                    if not oldPoint or oldPoint.coords ~= pointData.coords then
                        shouldRecreate = true
                        break
                    end
                end
            end
        end
        
        if shouldRecreate then
            -- Remove old zones for this shop
            local zonesToRemove = {}
            for zoneKey, _ in pairs(State.zones) do
                if string.find(zoneKey, data.shop.id .. "_point_") then
                    table.insert(zonesToRemove, zoneKey)
                end
            end
            
            for _, zoneKey in ipairs(zonesToRemove) do
                local zone = State.zones[zoneKey]
                if zone then
                    if zone.destroy then zone.destroy(zone) elseif zone.remove then zone.remove(zone) end
                    State.zones[zoneKey] = nil
                end
            end
            
            State.points[data.shop.id] = newPoints
            SetupPointsZones(true)
            InitializeLifts()
            SetupLiftZones()
        end
        
        -- Update point markers
        for pointId, pointData in pairs(newPoints) do
            UpdatePointMarker(data.shop.id, pointId, pointData)
        end
        
        -- Remove markers for points that no longer exist
        if oldPoints then
            for pointId, _ in pairs(oldPoints) do
                if not newPoints[pointId] then
                    RemovePointMarker(data.shop.id, pointId)
                end
            end
        end
    end
    
    if State.openPage == "management" then
        SendNUIMessage({
            action = "setShopData",
            data = {
                shop = State.shop,
                points = newPoints
            }
        })
    end
    
    LoadDynoStations()
end)

RegisterNetEvent("nn_mechanic:reinitializeShop")
AddEventHandler("nn_mechanic:reinitializeShop", function()
    -- Remove management zone
    if State.shop and State.shop.id then
        bridge.Target.RemoveZone("shop_management_" .. State.shop.id)
    end
    
    CleanupColorMixingStations()
    
    -- Destroy all zones
    for _, zone in pairs(State.zones) do
        if zone.destroy then
            zone.destroy(zone)
        elseif zone.remove then
            zone.remove(zone)
        end
    end
    State.zones = {}
    
    CleanupShopVehicleUpgradeZones()
    LoadDynoStations()
    Init()
end)

RegisterNetEvent("nn_mechanic:clearShopAccess")
AddEventHandler("nn_mechanic:clearShopAccess", function()
    if State.shop and State.shop.id then
        bridge.Target.RemoveZone("shop_management_" .. State.shop.id)
    end
    
    CleanupColorMixingStations()
    
    for _, zone in pairs(State.zones) do
        if zone.destroy then
            zone.destroy(zone)
        elseif zone.remove then
            zone.remove(zone)
        end
    end
    State.zones = {}
    
    CleanupShopVehicleUpgradeZones()
    
    State.shop = nil
    State.employee = nil
    State.points = {}
    State.servicePointsCtx = {}
    
    Init()
end)

-- AddEventHandler("onResourceStop", function(resourceName)
--     if resourceName ~= GetCurrentResourceName() then
--         return
--     end
    
--     for _, blip in pairs(State.shopBlips) do
--         if DoesBlipExist(blip) then
--             RemoveBlip(blip)
--         end
--     end
--     State.shopBlips = {}

--     if CleanupShopVehicleUpgradeZones then
--         CleanupShopVehicleUpgradeZones()
--     end

--     if DestroyAllPointMarkers then
--         DestroyAllPointMarkers()
--     end
    
--     if State.partDepositFlowMarkers then
--         for _, marker in pairs(State.partDepositFlowMarkers) do
--             bridge.Marker.Remove(marker)
--         end
--         State.partDepositFlowMarkers = {}
--     end
    
--     for _, ctx in pairs(State.servicePointsCtx) do
--         if ctx and ctx.vehicle then
--             bridge.Target.RemoveLocalEntity(ctx.vehicle)
--             ctx.vehicle = nil
--         end
--     end
    
--     CleanupColorMixingStations()
-- end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    
    for _, blip in pairs(State.shopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    State.shopBlips = {}
    
    if CleanupShopVehicleUpgradeZones then
        CleanupShopVehicleUpgradeZones()
    end
    
    if DestroyAllPointMarkers then
        DestroyAllPointMarkers()
    end
    
    if State.partDepositFlowMarkers then
        for _, marker in pairs(State.partDepositFlowMarkers) do
            bridge.Marker.Remove(marker)
        end
        State.partDepositFlowMarkers = {}
    end
    
    for _, ctx in pairs(State.servicePointsCtx) do
        if ctx and ctx.vehicle then
            bridge.Target.RemoveLocalEntity(ctx.vehicle)
            ctx.vehicle = nil
        end
    end
    
    if CleanupColorMixingStations then
        CleanupColorMixingStations()
    end
end)

local hasInitialized = false

RegisterNetEvent("community_bridge:Client:OnPlayerLoaded")
AddEventHandler("community_bridge:Client:OnPlayerLoaded", function()
    hasInitialized = true
    Init()
end)

Citizen.CreateThread(function()
    local delay = Config.Debug and 1000 or 1000
    Wait(delay)
    
    if not hasInitialized then
        Init()
    end
end)