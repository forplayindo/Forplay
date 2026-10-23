-- ============================================
-- Spray Gun & Vehicle Respray System
-- ============================================

-- Constants
local PARTICLE_ASSET = "scr_playerlamgraff"
local PARTICLE_NAME = "scr_lamgraff_paint_spray"
local SPRAY_DISTANCE = 2.0
local SPRAY_RANGE = 8.0
local SPRAY_SPEED = 0.1
local UPDATE_INTERVAL = 75  -- milliseconds
local MAX_PAINT_TYPE = 5
local TOLERANCE = 2

-- State
local bridge = exports.community_bridge.Bridge()
local currentSprayGun = nil
local selectedSpraySide = nil
local State = State or {}

-- ============================================
-- Color Utility Functions
-- ============================================

local function clampColor(value)
    value = tonumber(value) or 0
    value = math.floor(value + 0.5)
    return math.max(0, math.min(255, value))
end

local function lerp(startValue, endValue, t)
    return startValue + (endValue - startValue) * t
end

-- ============================================
-- Color Comparison Functions
-- ============================================

local function isColorMatching(currentColor, targetColor, tolerance)
    tolerance = tolerance or TOLERANCE
    local rDiff = math.abs((tonumber(currentColor.r) or 0) - (tonumber(targetColor.r) or 0))
    return tolerance >= rDiff
end

local function isValueEqual(val1, val2)
    return (tonumber(val1) or 0) == (tonumber(val2) or 0)
end

-- ============================================
-- Respray Order Management
-- ============================================

local function validateResprayMatch(currentColor, paintType, side)
    local order = State.resprayOrder
    if not order or not order.inProgress then
        return true, nil
    end
    
    local resprayData = order.resprayData
    if not resprayData then
        return true, nil
    end
    
    local expectedPaintType, expectedColorIndex, expectedRGB
    
    if side == "primary" then
        expectedPaintType = resprayData.primaryPaintType
        expectedColorIndex = resprayData.primaryColorIndex
        expectedRGB = resprayData.primary
    else
        expectedPaintType = resprayData.secondaryPaintType
        expectedColorIndex = resprayData.secondaryColorIndex
        expectedRGB = resprayData.secondary
    end
    
    -- Check if using color index (stock color)
    if expectedColorIndex ~= nil then
        if not isValueEqual(paintType, expectedPaintType) then
            return false, t("wrong_paint_type_ref") .. (expectedColorIndex or "")
        end
        return true, nil
    end
    
    -- Check custom RGB color
    if expectedRGB then
        if expectedRGB.r ~= 0 or expectedRGB.g ~= 0 or expectedRGB.b ~= 0 then
            if not isColorMatching(currentColor, expectedRGB) then
                local expectedStr = string.format("RGB(%d,%d,%d)", expectedRGB.r, expectedRGB.g, expectedRGB.b)
                return false, t("wrong_color_expected") .. expectedStr
            end
        end
        
        if not isValueEqual(paintType, expectedPaintType) then
            return false, t("wrong_paint_type")
        end
        
        return true, nil
    end
    
    return true, nil
end

local function getCurrentRespraySide()
    local order = State.resprayOrder
    if not order or not order.inProgress then
        return nil
    end
    
    if not order.primaryDone then
        return "primary"
    elseif not order.secondaryDone then
        return "secondary"
    end
    
    return nil
end

local function getVehicleCurrentColor(vehicle, side)
    SetVehicleModKit(vehicle, 0)
    
    local paintType, colorIndex, isCustom, rgb
    
    if side == "primary" then
        paintType, colorIndex = GetVehicleModColor_1(vehicle)
        isCustom = GetIsVehiclePrimaryColourCustom(vehicle)
        if isCustom then
            local r, g, b = GetVehicleCustomPrimaryColour(vehicle)
            rgb = { r = r, g = g, b = b }
        end
    else
        paintType, colorIndex = GetVehicleModColor_2(vehicle)
        isCustom = GetIsVehicleSecondaryColourCustom(vehicle)
        if isCustom then
            local r, g, b = GetVehicleCustomSecondaryColour(vehicle)
            rgb = { r = r, g = g, b = b }
        end
    end
    
    return {
        paintType = paintType,
        colorIndex = colorIndex,
        isCustom = isCustom,
        rgb = rgb
    }
end

local function isColorMatch(vehicleColor, expectedPaintType, useColorIndex, expectedColorIndex, expectedRGB)
    if not isValueEqual(vehicleColor.paintType, expectedPaintType) then
        return false
    end
    
    if useColorIndex then
        if vehicleColor.isCustom then
            return false
        end
        return tonumber(vehicleColor.colorIndex) == tonumber(expectedColorIndex)
    else
        if not vehicleColor.isCustom or not vehicleColor.rgb then
            return false
        end
        return isColorMatching(vehicleColor.rgb, expectedRGB)
    end
end

function CheckResprayMatch(vehicle, resprayData)
    if not vehicle or not DoesEntityExist(vehicle) or type(resprayData) ~= "table" then
        return { primary = false, secondary = false }
    end
    
    local hasPrimaryIndex = resprayData.primaryColorIndex ~= nil
    local hasSecondaryIndex = resprayData.secondaryColorIndex ~= nil
    local primaryRGB, secondaryRGB
    
    if resprayData.primary then
        primaryRGB = {
            r = tonumber(resprayData.primary[1] or resprayData.primary.r) or 0,
            g = tonumber(resprayData.primary[2] or resprayData.primary.g) or 0,
            b = tonumber(resprayData.primary[3] or resprayData.primary.b) or 0
        }
    end
    
    if resprayData.secondary then
        secondaryRGB = {
            r = tonumber(resprayData.secondary[1] or resprayData.secondary.r) or 0,
            g = tonumber(resprayData.secondary[2] or resprayData.secondary.g) or 0,
            b = tonumber(resprayData.secondary[3] or resprayData.secondary.b) or 0
        }
    end
    
    return {
        primary = isColorMatch(
            getVehicleCurrentColor(vehicle, "primary"),
            resprayData.primaryPaintType,
            hasPrimaryIndex,
            resprayData.primaryColorIndex,
            primaryRGB
        ),
        secondary = isColorMatch(
            getVehicleCurrentColor(vehicle, "secondary"),
            resprayData.secondaryPaintType,
            hasSecondaryIndex,
            resprayData.secondaryColorIndex,
            secondaryRGB
        )
    }
end

function InitResprayOrder(vehicle, resprayData, orderId, partIndex, onComplete, preMarkedSides)
    State.resprayOrder = {
        inProgress = true,
        vehicle = vehicle,
        orderId = orderId,
        partIndex = partIndex,
        resprayData = resprayData,
        primaryDone = false,
        secondaryDone = false,
        onComplete = onComplete
    }
    
    bridge.Notify.SendNotify(t("respray_order_started") or "Respray order started. Use spray gun with correct color for primary color first.", "info")
    
    if type(preMarkedSides) == "table" then
        if preMarkedSides.primary then markRespraySideDone("primary") end
        if preMarkedSides.secondary then markRespraySideDone("secondary") end
    end
    
    return true
end

function markRespraySideDone(side)
    local order = State.resprayOrder
    if not order or not order.inProgress then
        return
    end
    
    if side == "primary" then
        order.primaryDone = true
        if not order.secondaryDone then
            bridge.Notify.SendNotify(t("primary_done_now_secondary") or "Primary color done! Now spray the secondary color.", "success")
        end
    else
        order.secondaryDone = true
        if not order.primaryDone then
            bridge.Notify.SendNotify(t("secondary_done_now_primary") or "Secondary color done! Now spray the primary color.", "success")
        end
    end
    
    if order.primaryDone and order.secondaryDone then
        order.inProgress = false
        bridge.Notify.SendNotify(t("respray_complete") or "Respray complete!", "success")
        if order.onComplete then
            order.onComplete(true)
        end
        State.resprayOrder = nil
    end
end

function CleanupResprayOrder(success)
    local order = State.resprayOrder
    if order and order.onComplete then
        order.onComplete(success or false)
    end
    State.resprayOrder = nil
end

function GetResprayExpectedRefNumber(side)
    local order = State.resprayOrder
    if not order or not order.resprayData then
        return nil
    end
    
    if side == "primary" then
        return order.resprayData.primaryReferenceNumber
    else
        return order.resprayData.secondaryReferenceNumber
    end
end

function IsResprayOrderInProgress()
    return State.resprayOrder and State.resprayOrder.inProgress or false
end

function GetResprayOrderVehicle()
    return State.resprayOrder and State.resprayOrder.vehicle or nil
end

-- ============================================
-- UI Menu System
-- ============================================

function StartMenuControlsThread(menuId)
    if State.menuControlsThread then
        return
    end
    
    State.menuControlsThread = Citizen.CreateThread(function()
        while State.openPage == "menu" do
            if not State.currentMenuId then
                Wait(100)
            else
                -- Disable movement controls
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
            end
            Wait(0)
        end
        State.menuControlsThread = nil
    end)
end

local function closeMenu()
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "menu" }
    })
    
    if State.openPage == "menu" and State.currentMenuId == "spray_gun_menu" then
        State.openPage = nil
        State.currentMenuId = nil
    end
end

local function updateSprayHUD(side, progress)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "spray-hud" }
    })
    SendNUIMessage({
        action = "sprayHud",
        data = { progress = progress or 0, side = side }
    })
end

local function hideSprayHUD()
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "spray-hud" }
    })
end

-- Menu callbacks
RegisterNUICallback("sprayGunSelectSide", function(data, cb)
    selectedSpraySide = data and data.side or nil
    closeMenu()
    cb({ success = true })
end)

RegisterNUICallback("sprayGunCancel", function(_, cb)
    selectedSpraySide = "cancel"
    closeMenu()
    cb({ success = true })
end)

local function showSprayGunMenu()
    selectedSpraySide = nil
    
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "spray_gun_menu",
            items = {
                { label = "Spray Primary Color", icon = "fas fa-paint-roller", nuiCallback = "sprayGunSelectSide", callbackData = { side = "primary" } },
                { label = "Spray Secondary Color", icon = "fas fa-paint-brush", nuiCallback = "sprayGunSelectSide", callbackData = { side = "secondary" } },
                { label = "Cancel", icon = "fas fa-times-circle", nuiCallback = "sprayGunCancel" }
            }
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = "spray_gun_menu"
    StartMenuControlsThread("spray_gun_menu")
    
    while selectedSpraySide == nil do
        Wait(0)
    end
    
    return selectedSpraySide ~= "cancel" and selectedSpraySide or nil
end

-- ============================================
-- Raycast Helpers
-- ============================================

local function rotationToDirection(rotation)
    local rotZRad = math.rad(rotation.z)
    local rotXRad = math.rad(rotation.x)
    local absCosX = math.abs(math.cos(rotXRad))
    return vector3(-math.sin(rotZRad) * absCosX, math.cos(rotZRad) * absCosX, math.sin(rotXRad))
end

local function getAimTarget(range)
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = rotationToDirection(camRot) * range
    local targetPos = camPos + direction
    
    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, targetPos.x, targetPos.y, targetPos.z, 10, PlayerPedId(), 0)
    local _, hit, hitPos, _, hitEntity = GetShapeTestResult(rayHandle)
    
    return hit, hitPos, hitEntity
end

local function getNearestVehicle()
    local hit, _, hitEntity = getAimTarget(SPRAY_RANGE)
    
    if hit and hitEntity and hitEntity ~= 0 and IsEntityAVehicle(hitEntity) then
        return hitEntity
    end
    
    local player = PlayerPedId()
    local playerPos = GetEntityCoords(player)
    local vehicle = GetClosestVehicle(playerPos.x, playerPos.y, playerPos.z, SPRAY_RANGE, 0, 70)
    
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    
    return nil
end

-- ============================================
-- Vehicle Painting Functions
-- ============================================

local function applyVehicleColor(vehicle, side, paintType, rgb)
    SetVehicleModKit(vehicle, 0)
    
    local _, extraColor = GetVehicleExtraColours(vehicle)
    local extraColorIndex = extraColor or 0
    
    if side == "primary" then
        ClearVehicleCustomPrimaryColour(vehicle)
        SetVehicleModColor_1(vehicle, paintType, 0, extraColorIndex)
        SetVehicleCustomPrimaryColour(vehicle, rgb[1], rgb[2], rgb[3])
    else
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleModColor_2(vehicle, paintType, 0)
        SetVehicleCustomSecondaryColour(vehicle, rgb[1], rgb[2], rgb[3])
    end
end

local function applyStockColor(vehicle, side, paintType, colorIndex)
    SetVehicleModKit(vehicle, 0)
    
    if side == "primary" then
        ClearVehicleCustomPrimaryColour(vehicle)
        local _, extraColor = GetVehicleExtraColours(vehicle)
        SetVehicleModColor_1(vehicle, paintType, colorIndex, extraColor or 0)
    else
        ClearVehicleCustomSecondaryColour(vehicle)
        SetVehicleModColor_2(vehicle, paintType, colorIndex)
    end
end

-- ============================================
-- Particle Effects
-- ============================================

local currentParticleFx = nil

local function stopSprayParticles()
    if currentParticleFx then
        StopParticleFxLooped(currentParticleFx, false)
        currentParticleFx = nil
    end
end

local function startSprayParticles(assetName, effectName, speed, r, g, b, attachToEntity, offset)
    if currentParticleFx then
        SetParticleFxLoopedColour(currentParticleFx, r or 0.0, g or 0.0, b or 0.0, false)
        return currentParticleFx
    end
    
    while not HasNamedPtfxAssetLoaded(assetName) do
        RequestNamedPtfxAsset(assetName)
        Wait(0)
    end
    
    UseParticleFxAssetNextCall(assetName)
    
    local offX = (offset and offset.x) or 0.0
    local offY = (offset and offset.y) or 0.0
    local offZ = (offset and offset.z) or 0.0
    
    currentParticleFx = StartNetworkedParticleFxLoopedOnEntity(
        effectName, attachToEntity,
        offX - 0.28, offY, offZ - 0.28,
        0.0, 0.0, 270.0,
        speed + 0.0,
        false, false, false, false
    )
    
    SetParticleFxLoopedColour(currentParticleFx, r or 0.0, g or 0.0, b or 0.0, false)
    
    return currentParticleFx
end

-- ============================================
-- Spray Gun Attachment
-- ============================================

function AttachSprayGun()
    local player = PlayerPedId()
    local gunHash = GetHashKey("spray_gun")
    
    RequestAnimDict("weapons@first_person@aim_lt@generic@projectile@misc@stickybomb@")
    while not HasAnimDictLoaded("weapons@first_person@aim_lt@generic@projectile@misc@stickybomb@") do
        Wait(100)
    end
    
    TaskPlayAnim(player, "weapons@first_person@aim_lt@generic@projectile@misc@stickybomb@", "aim_low_loop", 8.0, -8.0, -1, 51, 0, false, false, false)
    
    RequestModel(gunHash)
    while not HasModelLoaded(gunHash) do
        Wait(100)
    end
    
    if currentSprayGun then
        DeleteEntity(currentSprayGun)
        currentSprayGun = nil
    end
    
    local coords = GetEntityCoords(player)
    currentSprayGun = CreateObject(gunHash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    
    AttachEntityToEntity(currentSprayGun, player, GetPedBoneIndex(player, 57005), 0.16, 0.1, -0.01, 70.0, -20.0, 180.0, true, true, false, true, 1, true)
    
    return currentSprayGun
end

function DetachSprayGun()
    if currentSprayGun and DoesEntityExist(currentSprayGun) then
        DeleteEntity(currentSprayGun)
        currentSprayGun = nil
    end
end

-- ============================================
-- Help Text
-- ============================================

local function showHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ============================================
-- Stock Spray Can Handler
-- ============================================

RegisterNetEvent("nn_mechanic:useStockSprayCan", function(item)
    if not item then return end
    
    local metadata = item.metadata or item.info or {}
    local paintType = tonumber(metadata.paintType) or 0
    local colorIndex = tonumber(metadata.colorIndex) or 0
    local slot = item.slot or item.slotId
    
    -- Clamp values
    paintType = math.max(0, math.min(MAX_PAINT_TYPE, paintType))
    colorIndex = math.max(0, math.min(255, colorIndex))
    
    local vehicle = getNearestVehicle()
    
    -- Check respray order proximity
    local order = State.resprayOrder
    if order and order.inProgress and order.vehicle and DoesEntityExist(order.vehicle) then
        local playerPos = GetEntityCoords(PlayerPedId())
        local vehiclePos = GetEntityCoords(order.vehicle)
        if #(playerPos - vehiclePos) > SPRAY_RANGE then
            bridge.Notify.SendNotify(t("get_closer_to_vehicle") or "Get closer to the vehicle.", "error")
            return
        end
        vehicle = order.vehicle
    end
    
    if not vehicle or not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify("No vehicle nearby.", "error")
        return
    end
    
    local vehicleProps = getVehicleProperties(vehicle)
    if not vehicleProps then
        bridge.Notify.SendNotify("Failed to read vehicle properties.", "error")
        return
    end
    
    local isOrderVehicle = order and order.inProgress and order.vehicle == vehicle
    local side = nil
    
    if isOrderVehicle then
        side = getCurrentRespraySide()
        if not side then
            bridge.Notify.SendNotify(t("respray_already_complete") or "Respray is already complete.", "info")
            return
        end
        
        local isValid, errorMsg = validateResprayMatch({ r = 0, g = 0, b = 0 }, paintType, side)
        if not isValid then
            bridge.Notify.SendNotify(errorMsg or t("wrong_spray_color") or "Wrong spray color!", "error")
            return
        end
        
        bridge.Notify.SendNotify((t("spraying_side") or "Spraying ") .. side .. " color...", "info")
    else
        side = showSprayGunMenu()
        if not side then
            return
        end
    end
    
    updateSprayHUD(side, 0)
    local sprayGun = AttachSprayGun()
    
    local sprayProgress = 0.0
    local startTime = GetGameTimer()
    local lastUpdate = 0
    
    while true do
        local currentTime = GetGameTimer()
        local delta = (currentTime - startTime) / 1000.0
        startTime = currentTime
        
        if delta < 0 then delta = 0 end
        if delta > 0.05 then delta = 0.05 end
        
        if IsControlJustReleased(0, 73) then
            setVehicleProperties(vehicle, vehicleProps)
            stopSprayParticles()
            hideSprayHUD()
            DetachSprayGun()
            ClearPedTasks(PlayerPedId())
            return
        end
        
        DisableControlAction(0, 24, true)  -- Attack
        DisableControlAction(0, 69, true)  -- Vehicle Attack
        DisableControlAction(0, 92, true)  -- Melee Attack
        
        if IsDisabledControlPressed(0, 24) and sprayGun and DoesEntityExist(sprayGun) then
            local hit, _, hitEntity = getAimTarget(SPRAY_RANGE)
            if hit and hitEntity == vehicle then
                sprayProgress = math.min(1.0, sprayProgress + delta * SPRAY_SPEED)
                
                if not isOrderVehicle then
                    applyStockColor(vehicle, side, paintType, colorIndex)
                    SetVehicleDirtLevel(vehicle, 0.0)
                    WashDecalsFromVehicle(vehicle, 1.0)
                end
            end
            
            startSprayParticles(PARTICLE_ASSET, PARTICLE_NAME, SPRAY_DISTANCE, 1.0, 1.0, 1.0, sprayGun, vector3(0.25, 0.02, 0.0))
        else
            stopSprayParticles()
        end
        
        if currentTime - lastUpdate >= UPDATE_INTERVAL then
            lastUpdate = currentTime
            updateSprayHUD(side, math.floor(sprayProgress * 100))
        end
        
        if sprayProgress >= 1.0 then
            applyStockColor(vehicle, side, paintType, colorIndex)
            stopSprayParticles()
            updateSprayHUD(side, 100)
            hideSprayHUD()
            DetachSprayGun()
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent("nn_mechanic:consumeStockSprayCan", slot)
            TriggerServerEvent("nn_mechanic:saveVehicleProps", getVehicleProperties(vehicle))
            
            if isOrderVehicle and side then
                markRespraySideDone(side)
            end
            return
        end
        
        Wait(0)
    end
end)

-- ============================================
-- Custom Spray Gun Handler
-- ============================================

RegisterNetEvent("nn_mechanic:useSprayGun", function(item)
    if not item then return end
    
    local metadata = item.metadata or item.info or {}
    local color = metadata.color or {}
    
    local targetR = clampColor(color.r)
    local targetG = clampColor(color.g)
    local targetB = clampColor(color.b)
    local paintType = tonumber(color.paintType) or 0
    paintType = math.max(0, math.min(MAX_PAINT_TYPE, paintType))
    
    local slot = item.slot or item.slotId
    
    local vehicle = getNearestVehicle()
    
    local order = State.resprayOrder
    if order and order.inProgress and order.vehicle and DoesEntityExist(order.vehicle) then
        local playerPos = GetEntityCoords(PlayerPedId())
        local vehiclePos = GetEntityCoords(order.vehicle)
        if #(playerPos - vehiclePos) > SPRAY_RANGE then
            bridge.Notify.SendNotify(t("get_closer_to_vehicle") or "Get closer to the vehicle.", "error")
            return
        end
        vehicle = order.vehicle
    end
    
    if not vehicle or not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify("No vehicle nearby.", "error")
        return
    end
    
    local vehicleProps = getVehicleProperties(vehicle)
    if not vehicleProps then
        bridge.Notify.SendNotify("Failed to read vehicle properties.", "error")
        return
    end
    
    local isOrderVehicle = order and order.inProgress and order.vehicle == vehicle
    local side = nil
    
    if isOrderVehicle then
        side = getCurrentRespraySide()
        if not side then
            bridge.Notify.SendNotify(t("respray_already_complete") or "Respray is already complete.", "info")
            return
        end
        
        local isValid, errorMsg = validateResprayMatch({ r = targetR, g = targetG, b = targetB }, paintType, side)
        if not isValid then
            bridge.Notify.SendNotify(errorMsg or t("wrong_spray_color") or "Wrong spray color!", "error")
            return
        end
        
        bridge.Notify.SendNotify((t("spraying_side") or "Spraying ") .. side .. " color...", "info")
    else
        side = showSprayGunMenu()
        if not side then
            return
        end
    end
    
    local originalRGB
    if side == "primary" then
        if type(vehicleProps.color1) == "table" then
            originalRGB = { vehicleProps.color1[1], vehicleProps.color1[2], vehicleProps.color1[3] }
        end
    elseif side == "secondary" then
        if type(vehicleProps.color2) == "table" then
            originalRGB = { vehicleProps.color2[1], vehicleProps.color2[2], vehicleProps.color2[3] }
        end
    end
    
    if not originalRGB then
        originalRGB = { 0, 0, 0 }
    end
    
    updateSprayHUD(side, 0)
    local sprayGun = AttachSprayGun()
    
    local sprayProgress = 0.0
    local startTime = GetGameTimer()
    local lastUpdate = 0
    
    while true do
        local currentTime = GetGameTimer()
        local delta = (currentTime - startTime) / 1000.0
        startTime = currentTime
        
        if delta < 0 then delta = 0 end
        if delta > 0.05 then delta = 0.05 end
        
        if IsControlJustReleased(0, 73) then
            setVehicleProperties(vehicle, vehicleProps)
            stopSprayParticles()
            hideSprayHUD()
            DetachSprayGun()
            ClearPedTasks(PlayerPedId())
            return
        end
        
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 69, true)
        DisableControlAction(0, 92, true)
        
        if IsDisabledControlPressed(0, 24) and sprayGun and DoesEntityExist(sprayGun) then
            local hit, _, hitEntity = getAimTarget(SPRAY_RANGE)
            if hit and hitEntity == vehicle then
                sprayProgress = math.min(1.0, sprayProgress + delta * SPRAY_SPEED)
                
                local currentR = lerp(originalRGB[1], targetR, sprayProgress)
                local currentG = lerp(originalRGB[2], targetG, sprayProgress)
                local currentB = lerp(originalRGB[3], targetB, sprayProgress)
                
                applyVehicleColor(vehicle, side, paintType, { currentR, currentG, currentB })
                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)
            end
            
            startSprayParticles(PARTICLE_ASSET, PARTICLE_NAME, SPRAY_DISTANCE, targetR / 255.0, targetG / 255.0, targetB / 255.0, sprayGun, vector3(0.25, 0.02, 0.0))
        else
            stopSprayParticles()
        end
        
        if currentTime - lastUpdate >= UPDATE_INTERVAL then
            lastUpdate = currentTime
            updateSprayHUD(side, math.floor(sprayProgress * 100))
        end
        
        if sprayProgress >= 1.0 then
            applyVehicleColor(vehicle, side, paintType, { targetR, targetG, targetB })
            stopSprayParticles()
            updateSprayHUD(side, 100)
            hideSprayHUD()
            DetachSprayGun()
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent("nn_mechanic:consumeSprayGun", slot)
            TriggerServerEvent("nn_mechanic:saveVehicleProps", getVehicleProperties(vehicle))
            
            if isOrderVehicle and side then
                markRespraySideDone(side)
            end
            return
        end
        
        Wait(0)
    end
end)

if Config.Debug then
    RegisterCommand("spray", function()
        while not HasNamedPtfxAssetLoaded(PARTICLE_ASSET) do
            RequestNamedPtfxAsset(PARTICLE_ASSET)
            Wait(0)
        end
        
        UseParticleFxAssetNextCall(PARTICLE_ASSET)
        return StartNetworkedParticleFxLoopedOnEntity(
            PARTICLE_NAME, PlayerPedId(),
            0.0, 1.0, 0.0,
            0.0, 0.0, 0.0,
            SPRAY_DISTANCE + 0.0,
            false, false, false, false
        )
    end)
end