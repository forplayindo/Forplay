-- ============================================
-- Bolt Minigame System
-- ============================================

-- Global state
local boltsObjects = {}
local activeBolts = {}
local screwdriverProp = nil
local minigameActive = false
local currentBoltIndex = 1
local minigameCam = nil

-- Constants
local TRANSITION_DELAY = 500
local MOVE_SPEED = 0.05
local GOLDEN_RATIO = 1.618033988749895

-- ============================================
-- Bone Configuration
-- ============================================
local boneConfig = {}

-- Front bumper configuration
boneConfig.bumper_f = {
    boltOffset = vector3(0, -0.13, -0.18),
    boltRot = vector3(0.0, 0.0, 0.0),
    maxDepth = -0.15,
    targetRotation = 180.0,
    depthAxis = "x",
    depthDirection = -1,
    screwdriverOffset = vector3(0.22, 0.0, 0.0),
    screwdriverRotation = vector3(90.0, 180.0, 0.0),
    cameraSettings = { distance = 1.6, height = 0.3, sideOffset = 1.5 }
}

-- Rear bumper configuration
boneConfig.bumper_r = {
    boltOffset = vector3(0, 0, -0.28),
    boltRot = vector3(180.0, 0.0, 0.0),
    maxDepth = 0.15,
    targetRotation = 180.0,
    depthAxis = "x",
    depthDirection = -1,
    screwdriverOffset = vector3(-0.22, 0.0, 0.0),
    screwdriverRotation = vector3(90.0, 0.0, 0.0),
    cameraSettings = { distance = 1.0, height = 0.3, sideOffset = -1.5 }
}

-- Left front wheel configuration
boneConfig.wheel_lf = {
    boltOffset = vector3(0, 0, -0.28),
    boltRot = vector3(180.0, 0.0, 0.0),
    maxDepth = 0.15,
    targetRotation = 180.0,
    depthAxis = "y",
    depthDirection = -1,
    screwdriverOffset = vector3(0.0, -0.24, 0.0),
    screwdriverRotation = vector3(90.0, -90.0, 0.0),
    cameraSettings = { distance = 1.0, height = 0.3, sideOffset = 0.5 },
    boltOffsets = {
        vector3(0.0, -0.05, 0.32),
        vector3(0.0, -0.05, 0.21),
        vector3(-0.05, -0.05, 0.26),
        vector3(0.05, -0.05, 0.26)
    },
    boltRotations = {
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0)
    }
}

-- Right front wheel configuration
boneConfig.wheel_rf = {
    boltOffset = vector3(0, 0, -0.28),
    boltRot = vector3(180.0, 0.0, 0.0),
    maxDepth = 0.15,
    targetRotation = 180.0,
    depthAxis = "y",
    depthDirection = 1,
    screwdriverOffset = vector3(0.0, 0.24, 0.0),
    screwdriverRotation = vector3(90.0, 90.0, 0.0),
    cameraSettings = { distance = -1.0, height = 0.3, sideOffset = 0.5 },
    boltOffsets = {
        vector3(0.0, -0.05, 0.32),
        vector3(0.0, -0.05, 0.21),
        vector3(-0.05, -0.05, 0.26),
        vector3(0.05, -0.05, 0.26)
    },
    boltRotations = {
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0)
    }
}

-- Left rear wheel configuration
boneConfig.wheel_lr = {
    boltOffset = vector3(0, 0, -0.28),
    boltRot = vector3(180.0, 0.0, 0.0),
    maxDepth = 0.15,
    targetRotation = 180.0,
    depthAxis = "y",
    depthDirection = -1,
    screwdriverOffset = vector3(0.0, -0.24, 0.0),
    screwdriverRotation = vector3(90.0, -90.0, 0.0),
    cameraSettings = { distance = 1.0, height = 0.3, sideOffset = 0.5 },
    boltOffsets = {
        vector3(0.0, -0.05, 0.32),
        vector3(0.0, -0.05, 0.21),
        vector3(-0.05, -0.05, 0.26),
        vector3(0.05, -0.05, 0.26)
    },
    boltRotations = {
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0),
        vector3(-90.0, 90.0, 0.0)
    }
}

-- Right rear wheel configuration
boneConfig.wheel_rr = {
    boltOffset = vector3(0, 0, -0.28),
    boltRot = vector3(180.0, 0.0, 0.0),
    maxDepth = 0.15,
    targetRotation = 180.0,
    depthAxis = "y",
    depthDirection = 1,
    screwdriverOffset = vector3(0.0, 0.24, 0.0),
    screwdriverRotation = vector3(90.0, 90.0, 0.0),
    cameraSettings = { distance = -1.0, height = 0.3, sideOffset = 0.5 },
    boltOffsets = {
        vector3(0.0, -0.05, 0.32),
        vector3(0.0, -0.05, 0.21),
        vector3(-0.05, -0.05, 0.26),
        vector3(0.05, -0.05, 0.26)
    },
    boltRotations = {
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0),
        vector3(90.0, 90.0, 0.0)
    }
}

-- ============================================
-- Utility Functions
-- ============================================

local function worldToLocal(entity, worldPos)
    local entityX, entityY, entityZ = GetEntityCoords(entity)
    local rightVec, forwardVec, upVec = GetEntityMatrix(entity)
    local localPos = vector3(worldPos.x - entityX, worldPos.y - entityY, worldPos.z - entityZ)
    
    return vector3(
        localPos.x * rightVec.x + localPos.y * rightVec.y + localPos.z * rightVec.z,
        localPos.x * forwardVec.x + localPos.y * forwardVec.y + localPos.z * forwardVec.z,
        localPos.x * upVec.x + localPos.y * upVec.y + localPos.z * upVec.z
    )
end

local function localToWorld(entity, localPos)
    local entityX, entityY, entityZ = GetEntityCoords(entity)
    local rightVec, forwardVec, upVec = GetEntityMatrix(entity)
    
    return vector3(
        entityX + rightVec.x * localPos.x + forwardVec.x * localPos.y + upVec.x * localPos.z,
        entityY + rightVec.y * localPos.x + forwardVec.y * localPos.y + upVec.y * localPos.z,
        entityZ + rightVec.z * localPos.x + forwardVec.z * localPos.y + upVec.z * localPos.z
    )
end

local function getBoneWorldPosition(entity, boneName)
    local boneIndex = GetEntityBoneIndexByName(entity, boneName)
    if boneIndex == -1 then
        return nil, -1
    end
    
    local boneX, boneY, boneZ = GetWorldPositionOfEntityBone(entity, boneIndex)
    local worldPos = vector3(boneX, boneY, boneZ)
    local localPos = worldToLocal(entity, worldPos)
    
    return localPos, boneIndex
end

-- ============================================
-- Resource Cleanup
-- ============================================
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    
    -- Clean up bolt objects
    for _, bolt in pairs(boltsObjects) do
        if DoesEntityExist(bolt) then
            DetachEntity(bolt)
            DeleteEntity(bolt)
        end
    end
    
    -- Clean up screwdriver prop
    if screwdriverProp and DoesEntityExist(screwdriverProp) then
        DeleteEntity(screwdriverProp)
        screwdriverProp = nil
    end
end)

-- ============================================
-- Bolt Placement
-- ============================================
function PlaceBolts(vehicle, boneName, boltOffsets, boltRotations, makeActive)
    -- Load bolt model
    RequestModel("bolt")
    while not HasModelLoaded("bolt") do
        Wait(100)
    end
    
    local localPos, boneIndex = getBoneWorldPosition(vehicle, boneName)
    if not localPos then
        print(string.format("[ERROR] Bone \"%s\" not found on vehicle", boneName))
        return nil
    end
    
    local config = boneConfig[boneName] or boneConfig.bumper_f
    local vehicleRot = GetEntityRotation(vehicle, 2)
    
    -- Create bolts
    for index, offset in ipairs(boltOffsets) do
        local anchorWorld = localToWorld(vehicle, vector3(localPos.x + offset.x, localPos.y + offset.y, localPos.z + offset.z))
        local boltWorld = localToWorld(vehicle, anchorWorld)
        
        local customRot = boltRotations and boltRotations[index] or vector3(0, 0, 0)
        
        local bolt = CreateObject("bolt", 
            boltWorld.x + config.boltOffset.x,
            boltWorld.y + config.boltOffset.y,
            boltWorld.z + config.boltOffset.z,
            true, true, false)
        
        SetEntityRotation(bolt, vehicleRot.x + customRot.x, vehicleRot.y + customRot.y, vehicleRot.z + customRot.z)
        FreezeEntityPosition(bolt, true)
        SetEntityCollision(bolt, false, false)
        
        table.insert(boltsObjects, bolt)
        
        if makeActive then
            table.insert(activeBolts, {
                entity = bolt,
                vehicle = vehicle,
                initialRot = vector3(vehicleRot.x + customRot.x, vehicleRot.y + customRot.y, vehicleRot.z + customRot.z),
                initialAnchorLocal = anchorWorld,
                currentRotation = 0.0,
                currentDepth = 0.0,
                targetRotation = config.targetRotation,
                maxDepth = config.maxDepth,
                isComplete = false,
                objectOffset = config.boltOffset,
                coords = vector3(boltWorld.x + config.boltOffset.x, boltWorld.y + config.boltOffset.y, boltWorld.z + config.boltOffset.z),
                customRotation = customRot
            })
        end
    end
    
    -- Return camera position for bone
    local boneLocalPos, _ = getBoneWorldPosition(vehicle, boneName)
    local camWorldPos = localToWorld(vehicle, vector3(0.0, boneLocalPos.y, boneLocalPos.z))
    
    return camWorldPos
end

-- ============================================
-- Screwdriver Management
-- ============================================
function CreateScrewdriver(boneName)
    if screwdriverProp and DoesEntityExist(screwdriverProp) then
        DeleteEntity(screwdriverProp)
    end
    
    RequestModel("prop_tool_screwdvr03")
    while not HasModelLoaded("prop_tool_screwdvr03") do
        Wait(100)
    end
    
    screwdriverProp = CreateObject("prop_tool_screwdvr03", 0.0, 0.0, 0.0, true, true, false)
    SetEntityCollision(screwdriverProp, false, false)
    FreezeEntityPosition(screwdriverProp, true)
    
    local config = boneConfig[boneName] or boneConfig.bumper_f
    local vehicle = activeBolts[1].vehicle
    local vehicleRot = GetEntityRotation(vehicle, 2)
    
    SetEntityRotation(screwdriverProp, 
        vehicleRot.x + config.screwdriverRotation.x,
        vehicleRot.y + config.screwdriverRotation.y,
        vehicleRot.z + config.screwdriverRotation.z,
        2, true)
end

function UpdateScrewdriverPosition(boltWorldPos, boneName)
    if not screwdriverProp or not DoesEntityExist(screwdriverProp) then
        return
    end
    
    local config = boneConfig[boneName] or boneConfig.bumper_f
    local vehicle = activeBolts[1].vehicle
    local rightVec, forwardVec, upVec = GetEntityMatrix(vehicle)
    
    local screwdriverPos = vector3(
        boltWorldPos.x + rightVec.x * config.screwdriverOffset.x + forwardVec.x * config.screwdriverOffset.y + upVec.x * config.screwdriverOffset.z,
        boltWorldPos.y + rightVec.y * config.screwdriverOffset.x + forwardVec.y * config.screwdriverOffset.y + upVec.y * config.screwdriverOffset.z,
        boltWorldPos.z + rightVec.z * config.screwdriverOffset.x + forwardVec.z * config.screwdriverOffset.y + upVec.z * config.screwdriverOffset.z
    )
    
    SetEntityCoords(screwdriverProp, screwdriverPos.x, screwdriverPos.y, screwdriverPos.z, false, false, false, true)
end

function DestroyScrewdriver()
    if screwdriverProp and DoesEntityExist(screwdriverProp) then
        DeleteEntity(screwdriverProp)
        screwdriverProp = nil
    end
end

-- ============================================
-- Bolt Physics
-- ============================================
function DropBolt(bolt)
    if not bolt or not DoesEntityExist(bolt) then
        return
    end
    
    FreezeEntityPosition(bolt, false)
    SetEntityCollision(bolt, true, true)
    
    local velocity = GetEntityVelocity(bolt)
    SetEntityVelocity(bolt, velocity.x, velocity.y, velocity.z - 0.5)
    
    CreateThread(function()
        Wait(15000)
        if bolt and DoesEntityExist(bolt) then
            DeleteEntity(bolt)
        end
    end)
end

-- ============================================
-- Camera Management
-- ============================================
function SetupCamera(vehicle, boneName, distance, height, sideOffset)
    distance = distance or 2.5
    height = height or 0.3
    sideOffset = sideOffset or 0
    
    local bonePos, boneIndex = getBoneWorldPosition(vehicle, boneName)
    if not bonePos then
        return
    end
    
    local boneWorldX, boneWorldY, boneWorldZ = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    local rightVec, forwardVec, upVec = GetEntityMatrix(vehicle)
    
    local camPos = vector3(
        boneWorldX - forwardVec.x * distance + upVec.x * height + rightVec.x * sideOffset,
        boneWorldY - forwardVec.y * distance + upVec.y * height + rightVec.y * sideOffset,
        boneWorldZ - forwardVec.z * distance + upVec.z * height + rightVec.z * sideOffset
    )
    
    if DoesCamExist(minigameCam) then
        DestroyCam(minigameCam, false)
    end
    
    minigameCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(minigameCam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(minigameCam, boneWorldX, boneWorldY, boneWorldZ)
    SetCamActive(minigameCam, true)
    RenderScriptCams(true, true, 1500, true, true)
    
    return minigameCam
end

function DestroyCamera()
    if minigameCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(minigameCam, false)
        minigameCam = nil
    end
    DestroyScrewdriver()
end

-- ============================================
-- UI Hints
-- ============================================
function ShowBoltHint(current, total)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, action = "setVisible", page = "bolt-hint" }
    })
    SendNUIMessage({
        action = "setBoltHint",
        data = { current = current, total = total }
    })
end

function HideBoltHint()
    SendNUIMessage({ action = "hideBoltHint" })
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, action = "setVisible", page = "bolt-hint" }
    })
end

-- ============================================
-- Minigame Core
-- ============================================
function StartBoltMinigame(anchorPos, boneName)
    if #activeBolts == 0 then
        return
    end
    
    minigameActive = true
    currentBoltIndex = 1
    
    local vehicle = activeBolts[1].vehicle
    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    local boneWorldX, boneWorldY, boneWorldZ = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    
    local config = boneConfig[boneName] or boneConfig.bumper_f
    SetupCamera(vehicle, boneName, config.cameraSettings.distance, config.cameraSettings.height, config.cameraSettings.sideOffset)
    CreateScrewdriver(boneName)
    ShowBoltHint(0, #activeBolts)
    
    while minigameActive and currentBoltIndex <= #activeBolts do
        local bolt = activeBolts[currentBoltIndex]
        local player = PlayerPedId()
        
        if not bolt.isComplete then
            UpdateScrewdriverPosition(bolt.coords, boneName)
            
            while IsDisabledControlPressed(0, 34) do
                bolt = activeBolts[currentBoltIndex]
                if bolt then
                    bolt.currentRotation = math.min(bolt.currentRotation + 15.0, bolt.targetRotation)
                    local progress = bolt.currentRotation / bolt.targetRotation
                    
                    -- Update bolt rotation
                    SetEntityRotation(bolt.entity, 
                        bolt.initialRot.x + bolt.customRotation.x,
                        bolt.initialRot.y + bolt.customRotation.y,
                        bolt.initialRot.z + bolt.customRotation.z)
                    
                    -- Update bolt depth
                    bolt.currentDepth = progress * bolt.maxDepth
                    local config = boneConfig[boneName] or boneConfig.bumper_f
                    local depthAxis = config.depthAxis or "x"
                    local depthDir = config.depthDirection or -1
                    
                    local newAnchorLocal
                    if depthAxis == "y" then
                        newAnchorLocal = vector3(
                            bolt.initialAnchorLocal.x,
                            bolt.initialAnchorLocal.y + depthDir * bolt.currentDepth,
                            bolt.initialAnchorLocal.z
                        )
                    else
                        newAnchorLocal = vector3(
                            bolt.initialAnchorLocal.x + depthDir * bolt.currentDepth,
                            bolt.initialAnchorLocal.y,
                            bolt.initialAnchorLocal.z
                        )
                    end
                    
                    local newAnchorWorld = localToWorld(bolt.vehicle, newAnchorLocal)
                    local newBoltWorld = localToWorld(bolt.vehicle, newAnchorWorld)
                    
                    bolt.coords = vector3(
                        newBoltWorld.x + bolt.objectOffset.x,
                        newBoltWorld.y + bolt.objectOffset.y,
                        newBoltWorld.z + bolt.objectOffset.z
                    )
                    
                    SetEntityCoords(bolt.entity, bolt.coords.x, bolt.coords.y, bolt.coords.z, false, false, false, true)
                    UpdateScrewdriverPosition(bolt.coords, boneName)
                    
                    if bolt.currentRotation >= bolt.targetRotation then
                        bolt.isComplete = true
                        DropBolt(bolt.entity)
                        currentBoltIndex = currentBoltIndex + 1
                        ShowBoltHint(currentBoltIndex - 1, #activeBolts)
                        
                        if currentBoltIndex > #activeBolts then
                            minigameActive = false
                            HideBoltHint()
                            
                            -- Clean up all bolts
                            for _, obj in pairs(boltsObjects) do
                                if DoesEntityExist(obj) then
                                    DetachEntity(obj)
                                    DeleteEntity(obj)
                                end
                            end
                            activeBolts = {}
                            DestroyCamera()
                        else
                            MoveToNextBolt(boneName)
                        end
                    end
                end
                Wait(100)
            end
        end
        Wait(0)
    end
end

function MoveToNextBolt(boneName)
    -- Animate screwdriver movement to next bolt
    local nextBolt = activeBolts[currentBoltIndex]
    if not nextBolt then
        return
    end
    
    local startPos = GetEntityCoords(screwdriverProp)
    local targetPos = nextBolt.coords
    local distance = #(targetPos - startPos)
    
    local steps = math.max(15, math.floor(distance / MOVE_SPEED))
    local stepTime = math.floor(TRANSITION_DELAY * (math.random(70, 130) / 100))
    
    Wait(stepTime)
    
    -- Easing curve
    local tValues = {}
    for i = 1, steps do
        local t = i / steps
        local easeOut = 1 - (1 - t) * (1 - t)
        tValues[i] = easeOut
    end
    
    for i = 1, steps do
        if not screwdriverProp or not DoesEntityExist(screwdriverProp) then
            break
        end
        
        local t = tValues[i]
        local newPos = vector3(
            startPos.x + (targetPos.x - startPos.x) * t,
            startPos.y + (targetPos.y - startPos.y) * t,
            startPos.z + (targetPos.z - startPos.z) * t
        )
        
        UpdateScrewdriverPosition(newPos, boneName)
        Wait(math.random(5, 15))
    end
    
    if screwdriverProp and DoesEntityExist(screwdriverProp) then
        UpdateScrewdriverPosition(targetPos, boneName)
    end
end

function StopBoltMinigame()
    minigameActive = false
    HideBoltHint()
    DestroyCamera()
    activeBolts = {}
end

-- ============================================
-- Debug Commands
-- ============================================
if Config.Debug then
    RegisterCommand("place_bolts", function(source, args)
        local player = PlayerPedId()
        local vehicle = GetClosestVehicle(GetEntityCoords(player), 5.0, 0, 70)
        
        if not DoesEntityExist(vehicle) then
            return
        end
        
        local boneName = args[1] or "bumper_f"
        local config = boneConfig[boneName]
        if not config then
            return
        end
        
        local boltOffsets = config.boltOffsets or {
            vector3(0, 0, 0),
            vector3(0, 0, 0),
            vector3(0, 0, 0),
            vector3(0, 0, 0)
        }
        
        local boltRotations = config.boltRotations
        local camPos = PlaceBolts(vehicle, boneName, boltOffsets, boltRotations, true)
        StartBoltMinigame(camPos, boneName)
    end)
    
    RegisterCommand("stop_minigame", function()
        StopBoltMinigame()
    end)
    
    -- Camera testing command
    RegisterCommand("create_bone_camera", function(source, args)
        local player = PlayerPedId()
        local vehicle = GetClosestVehicle(GetEntityCoords(player), 5.0, 0, 70)
        
        if not DoesEntityExist(vehicle) then
            print("[ERROR] You must be near a vehicle")
            return
        end
        
        local boneName = args[1]
        if not boneName then
            print("[ERROR] Usage: /create_bone_camera <boneName> [distance] [height] [sideOffset]")
            print("[INFO] Example: /create_bone_camera wheel_lf 1.0 0.3 -1.5")
            return
        end
        
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        if boneIndex == -1 then
            print(string.format("[ERROR] Bone \"%s\" not found on this vehicle", boneName))
            return
        end
        
        local distance = tonumber(args[2]) or 1.0
        local height = tonumber(args[3]) or 0.3
        local sideOffset = tonumber(args[4]) or 0.0
        
        if not DoesCamExist(minigameCam) then
            minigameCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
            SetCamActive(minigameCam, true)
            RenderScriptCams(true, false, 0, true, true)
        end
        
        SetupCamera(vehicle, boneName, distance, height, sideOffset)
        
        print("========================================")
        print("Camera Settings Updated:")
        print(string.format("Bone: %s", boneName))
        print(string.format("Distance: %.2f", distance))
        print(string.format("Height: %.2f", height))
        print(string.format("Side Offset: %.2f", sideOffset))
        print("========================================")
        print("Copy this to boneConfig:")
        print(string.format("['%s'] = {", boneName))
        print("    -- Bolt settings")
        print("    boltOffset = vector3(0, 0, -0.28),")
        print("    boltRot = vector3(180.0, 0.0, 0.0),")
        print("    maxDepth = 0.15,")
        print("    targetRotation = 180.0,")
        print("    ")
        print("    -- Screwdriver settings")
        print("    screwdriverOffset = vector3(-0.22, 0.0, 0.0),")
        print("    screwdriverRotation = vector3(90.0, 0.0, 0.0),")
        print("")
        print("    cameraSettings = {")
        print(string.format("        distance = %.1f,", distance))
        print(string.format("        height = %.1f,", height))
        print(string.format("        sideOffset = %.1f", sideOffset))
        print("    }")
        print("},")
        print("========================================")
        print("Adjust values and run command again to update camera")
        print("Use /stop_bone_camera to close the camera")
    end)
    
    RegisterCommand("stop_bone_camera", function()
        if DoesCamExist(minigameCam) then
            RenderScriptCams(false, true, 500, true, false)
            DestroyCam(minigameCam, false)
            minigameCam = nil
            print("Camera closed")
        else
            print("No active camera")
        end
    end)
end