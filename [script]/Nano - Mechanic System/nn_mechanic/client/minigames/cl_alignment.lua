-- Camera management
local minigameCam = nil

local function createCamera(camCoord, targetCoord)
    if DoesCamExist(minigameCam) then
        DestroyCam(minigameCam, false)
    end
    
    minigameCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(minigameCam, camCoord.x, camCoord.y, camCoord.z)
    PointCamAtCoord(minigameCam, targetCoord.x, targetCoord.y, targetCoord.z)
    SetCamActive(minigameCam, true)
    RenderScriptCams(true, true, 1500, true, true)
    
    return minigameCam
end

-- Wheel alignment configuration
local wheelConfig = {
    wheel_rf = { distance = -1.6, height = 0.0, sideOffset = 0.8, offset = 0.9 },
    wheel_lf = { distance = 1.6, height = 0.0, sideOffset = -0.4, offset = -0.9 },
    wheel_lr = { distance = 1.6, height = 0.0, sideOffset = -0.4, offset = -0.9 },
    wheel_rr = { distance = -1.6, height = 0.0, sideOffset = 0.8, offset = 0.9 }
}

local function calculateCameraPosition(vehicle, boneName)
    if not DoesEntityExist(vehicle) then
        return
    end
    
    local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
    if boneIndex == -1 then
        return
    end
    
    local ctx = ctx or {}
    local bonePosX, bonePosY, bonePosZ = ctx.initialBonePos and 
        ctx.initialBonePos.x or GetWorldPositionOfEntityBone(vehicle, boneIndex)
    
    local rightVec, forwardVec, upVec = GetEntityMatrix(vehicle)
    local config = wheelConfig[boneName]
    
    local distance = config.distance
    local height = 0.0
    local sideOffset = config.sideOffset
    local offset = config.offset
    
    local camPos = vector3(
        bonePosX - rightVec.x * distance + upVec.x * height + forwardVec.x * sideOffset,
        bonePosY - rightVec.y * distance + upVec.y * height + forwardVec.y * sideOffset,
        bonePosZ - rightVec.z * distance + upVec.z * height + forwardVec.z * sideOffset
    )
    
    local targetPos = vector3(
        bonePosX + forwardVec.x * offset,
        bonePosY + forwardVec.y * offset,
        bonePosZ + forwardVec.z * offset
    )
    
    return camPos, targetPos
end

-- Debug command registration
if Config.Debug then
    RegisterCommand("create_wheel_camera", function(source, args)
        local boneName = args[1]
        if not boneName then
            print("[ERROR] Usage: /create_wheel_camera <boneName>")
            return
        end
        
        local vehicle = GetClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, 0, 70)
        print(vehicle, boneName, "vehicle and bone")
        
        createCamera(ctx, vehicle, boneName, tonumber(args[2]), tonumber(args[3]))
    end)
end

-- Minigame state
local minigameState = {
    vehicle = nil,
    boneName = nil,
    bonePos = nil,
    targetCoords = nil,
    randomizedCoords = nil,
    vehicleRot = nil,
    initialGapLeft = nil,
    initialGapTop = nil,
    initialFlush = nil
}

local wheelProp = nil

-- Wheel alignment constants
local ALIGNMENT = {
    MAX_GAP = 4.0,
    MIN_GAP = 0.0,
    WIDTH = 0.4,
    HEIGHT = 0.4,
    RADIUS_X = 3.0,
    RADIUS_Y = 5.0
}

function StartWheelAlignmentMinigame(ctx)
    local vehicle = ctx.vehicle
    local boneName = ctx.boneName
    local bonePos = ctx.bonePos
    
    local vehicleHeading = GetEntityHeading(vehicle) + 90.0
    
    -- Load wheel prop model
    local wheelModel = GetHashKey("imp_prop_impexp_tyre_01b")
    RequestModel(wheelModel)
    while not HasModelLoaded(wheelModel) do
        Wait(100)
    end
    
    local targetPos = { x = bonePos.x, y = bonePos.y, z = bonePos.z }
    
    -- Generate random offset
    local randomOffset = vector3(
        math.random() * 0.8 - 0.4,
        math.random() * 0.8 - 0.4,
        math.random() * 0.8 - 0.4
    )
    
    local randomizedPos = {
        x = targetPos.x + randomOffset.x,
        y = targetPos.y + randomOffset.y,
        z = targetPos.z + randomOffset.z
    }
    
    local rightVec, forwardVec, upVec = GetEntityMatrix(vehicle)
    
    local gapLeftInitial = ALIGNMENT.MAX_GAP - (randomOffset.x * rightVec.x + randomOffset.y * rightVec.y + randomOffset.z * rightVec.z) / (ALIGNMENT.WIDTH / ALIGNMENT.RADIUS_X)
    local flushInitial = ALIGNMENT.MIN_GAP - (randomOffset.x * forwardVec.x + randomOffset.y * forwardVec.y) / (ALIGNMENT.WIDTH / ALIGNMENT.RADIUS_Y)
    local gapTopInitial = ALIGNMENT.MAX_GAP + randomOffset.z / (ALIGNMENT.HEIGHT / ALIGNMENT.RADIUS_X)
    
    -- Update state
    minigameState.vehicle = vehicle
    minigameState.boneName = boneName
    minigameState.bonePos = bonePos
    minigameState.targetCoords = targetPos
    minigameState.randomizedCoords = randomizedPos
    minigameState.vehicleRot = vehicleHeading
    
    -- Create camera
    createCamera(ctx.camPos, ctx.targetPos)
    
    -- Create wheel prop
    wheelProp = CreateObject(wheelModel, randomizedPos.x, randomizedPos.y, randomizedPos.z - 0.35, true, true, true)
    SetEntityDrawOutline(wheelProp, true)
    SetEntityCollision(wheelProp, false, false)
    SetEntityRotation(wheelProp, 0.0, 0.0, vehicleHeading, 2, true)
    FreezeEntityPosition(wheelProp, true)
    
    -- Show UI
    SendNUIMessage({
        action = "setVisibility",
        data = {
            action = "setVisible",
            page = "calibration-minigame",
            visible = true
        }
    })
    
    SendNUIMessage({
        action = "setAlignmentData",
        data = {
            initialCoords = randomizedPos,
            targetCoords = targetPos,
            initialGapLeft = gapLeftInitial,
            initialGapTop = gapTopInitial,
            initialFlush = flushInitial
        }
    })
    
    State.disableControls = true
    DisableControls()
    SetNuiFocus(true, true)
end

function CleanupWheelAlignment()
    if wheelProp and DoesEntityExist(wheelProp) then
        DeleteEntity(wheelProp)
        wheelProp = nil
    end
    
    if minigameCam and DoesCamExist(minigameCam) then
        DestroyCam(minigameCam, false)
        RenderScriptCams(false, true, 500, true, true)
        minigameCam = nil
    end
    
    -- Reset state
    for key, _ in pairs(minigameState) do
        minigameState[key] = nil
    end
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            action = "setVisible",
            page = "calibration-minigame",
            visible = false
        }
    })
    
    SetNuiFocus(false, false)
    State.disableControls = false
end

-- NUI Callbacks
RegisterNUICallback("alignWheel", function(data, cb)
    if not wheelProp or not DoesEntityExist(wheelProp) then
        cb({ success = false, error = "Wheel prop not found" })
        return
    end
    
    if not minigameState.targetCoords then
        cb({ success = false, error = "Target coordinates not set" })
        return
    end
    
    local step = data.step or 0.1
    local newPos = { x = minigameState.targetCoords.x, y = minigameState.targetCoords.y, z = minigameState.targetCoords.z }
    local vehicle = minigameState.vehicle
    
    if not vehicle or not DoesEntityExist(vehicle) then
        cb({ success = false, error = "Vehicle not found" })
        return
    end
    
    local rightVec, forwardVec, upVec = GetEntityMatrix(vehicle)
    
    -- Handle alignment adjustments
    if data.action == "leftGap" then
        newPos.x = newPos.x - rightVec.x * step
        newPos.y = newPos.y - rightVec.y * step
        newPos.z = newPos.z - rightVec.z * step
    elseif data.action == "rightGap" then
        newPos.x = newPos.x + rightVec.x * step
        newPos.y = newPos.y + rightVec.y * step
        newPos.z = newPos.z + rightVec.z * step
    elseif data.action == "topGap" then
        local direction = data.direction
        local multiplier = (direction == "up") and 1 or -1
        newPos.x = newPos.x + upVec.x * step * multiplier
        newPos.y = newPos.y + upVec.y * step * multiplier
        newPos.z = newPos.z + upVec.z * step * multiplier
    elseif data.action == "flush" then
        local direction = data.direction
        local multiplier = (direction == "in") and 1 or -1
        newPos.x = newPos.x + forwardVec.x * step * multiplier
        newPos.y = newPos.y + forwardVec.y * step * multiplier
        newPos.z = newPos.z + forwardVec.z * step * multiplier
    elseif data.action == "setPosition" and data.gapLeft and data.gapTop and data.flush then
        if not minigameState.initialGapLeft then
            minigameState.initialGapLeft = data.gapLeft
            minigameState.initialGapTop = data.gapTop
            minigameState.initialFlush = data.flush
        end
        
        local gapXFactor = (data.gapLeft - ALIGNMENT.MAX_GAP) / (ALIGNMENT.WIDTH / ALIGNMENT.RADIUS_X)
        local gapZFactor = (data.gapTop - ALIGNMENT.MAX_GAP) / (ALIGNMENT.HEIGHT / ALIGNMENT.RADIUS_X)
        local flushFactor = (data.flush - ALIGNMENT.MIN_GAP) / (ALIGNMENT.WIDTH / ALIGNMENT.RADIUS_Y)
        
        newPos.x = minigameState.targetCoords.x + rightVec.x * gapXFactor + forwardVec.x * flushFactor + upVec.x * gapZFactor
        newPos.y = minigameState.targetCoords.y + rightVec.y * gapXFactor + forwardVec.y * flushFactor + upVec.y * gapZFactor
        newPos.z = minigameState.targetCoords.z + upVec.z * gapZFactor
    end
    
    SetEntityCoords(wheelProp, newPos.x, newPos.y, newPos.z, false, false, false, true)
    cb({ success = true })
end)

RegisterNUICallback("alignmentComplete", function(data, cb)
    State.disableControls = false
    ClearMechanicAlphaAnim(State.Ped)
    
    -- Find service point context
    local serviceCtx = nil
    if State.currentPointCtxIndex then
        serviceCtx = State.servicePointsCtx[State.currentPointCtxIndex]
    end
    
    if not serviceCtx and minigameState.vehicle then
        local vehicleNet = VehToNet(minigameState.vehicle)
        for _, ctx in pairs(State.servicePointsCtx) do
            if ctx and ctx.vehicleNetId == vehicleNet then
                serviceCtx = ctx
                break
            end
        end
    end
    
    if serviceCtx and serviceCtx.wheelSwapCallback then
        CleanupWheelAlignment()
        serviceCtx.wheelSwapCallback(data.success)
        cb({ success = true })
        return
    end
    
    if data.success then
        local wheelIndices = { wheel_rf = 1, wheel_lf = 0, wheel_lr = 2, wheel_rr = 3 }
        local wheelIndex = wheelIndices[serviceCtx.boneName]
        
        SetVehicleTyreBurst(serviceCtx.vehicle, wheelIndex, false)
        SetVehicleTyreFixed(serviceCtx.vehicle, wheelIndex)
        
        local wheelXOffset = serviceCtx.wheelXOffset or 0.0
        if Config.Debug and not serviceCtx.wheelXOffset then
            print("[nn_mechanic] Warning: wheelXOffset not found in ctx, using default 0.0")
        end
        
        SetVehicleWheelXOffsetsSynced(serviceCtx.vehicle, { [wheelIndex] = wheelXOffset })
        SetVehicleModKit(serviceCtx.vehicle, 0)
        SetVehicleMod(serviceCtx.vehicle, 23, serviceCtx.modIndex, false)
        
        local vehicleProps = getVehicleProperties(serviceCtx.vehicle)
        TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
        setVehicleProperties(serviceCtx.vehicle, vehicleProps)
        
        local plateText = GetVehicleNumberPlateText(serviceCtx.vehicle) or ""
        local cleanPlate = plateText:gsub("%s+", "")
        
        if cleanPlate ~= "" and wheelIndex then
            TriggerServerEvent("nn_mechanic:resetTireDataForWheel", cleanPlate, wheelIndex)
        end
        
        State.repairInProgress = false
        CleanupWheelAlignment()
        cb({ success = true })
    else
        CleanupWheelAlignment()
        State.repairInProgress = false
        cb({ success = true })
    end
end)