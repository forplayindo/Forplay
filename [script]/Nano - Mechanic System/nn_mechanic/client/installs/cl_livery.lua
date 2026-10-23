-- Initialize bridge
if not bridge then
    bridge = exports.community_bridge.Bridge()
end

-- Initialize state if not exists
if not State then
    State = {}
end

-- Constants
local RAYCAST_DISTANCE = 8.0
local PROGRESS_INCREMENT = 0.1
local UPDATE_INTERVAL_MS = 75
local BLOWTORCH_MODEL = "prop_tool_blowtorch"
local ANIM_DICT = "weapons@first_person@aim_lt@generic@projectile@misc@stickybomb@"
local ANIM_CLIP = "aim_low_loop"
local ATTACH_BONE = 57005
local ATTACH_OFFSET_X = 0.08
local ATTACH_OFFSET_Y = -0.15
local ATTACH_OFFSET_Z = 0.0
local ATTACH_ROT_X = 98.0
local ATTACH_ROT_Y = -20.0
local ATTACH_ROT_Z = 180.0

-- Global blowtorch entity
local blowtorchEntity = nil

-- Convert rotation vector to direction vector
function RotToDir(rot)
    local radZ = math.rad(rot.z)
    local radX = math.rad(rot.x)
    local absCosX = math.abs(math.cos(radX))
    
    return vector3(
        -math.sin(radZ) * absCosX,
        math.cos(radZ) * absCosX,
        math.sin(radX)
    )
end

-- Raycast from camera
function RaycastFromCamera(distance)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotToDir(camRot)
    local targetCoords = camCoords + (direction * distance)
    
    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        targetCoords.x, targetCoords.y, targetCoords.z,
        10, PlayerPedId(), 0
    )
    
    local _, hit, _, _, hitEntity = GetShapeTestResult(rayHandle)
    return hit == 1, hitEntity
end

-- Create blowtorch prop
function CreateBlowtorchProp()
    local ped = PlayerPedId()
    
    -- Load animation dictionary
    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do
        Wait(0)
    end
    
    -- Play animation
    TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 51, 0, false, false, false)
    
    -- Load blowtorch model
    local modelHash = GetHashKey(BLOWTORCH_MODEL)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end
    
    -- Clean up existing blowtorch
    if blowtorchEntity and DoesEntityExist(blowtorchEntity) then
        DeleteEntity(blowtorchEntity)
        blowtorchEntity = nil
    end
    
    -- Create new blowtorch
    local pedCoords = GetEntityCoords(ped)
    local torch = CreateObject(modelHash, pedCoords.x, pedCoords.y, pedCoords.z + 0.2, true, true, false)
    
    -- Attach to ped's hand
    AttachEntityToEntity(torch, ped, GetPedBoneIndex(ped, ATTACH_BONE),
        ATTACH_OFFSET_X, ATTACH_OFFSET_Y, ATTACH_OFFSET_Z,
        ATTACH_ROT_X, ATTACH_ROT_Y, ATTACH_ROT_Z,
        true, true, false, true, 1, true)
    
    blowtorchEntity = torch
    return torch
end

-- Destroy blowtorch prop
function DestroyBlowtorchProp()
    if blowtorchEntity and DoesEntityExist(blowtorchEntity) then
        DeleteEntity(blowtorchEntity)
    end
    blowtorchEntity = nil
    ClearPedTasks(PlayerPedId())
end

-- Show livery HUD
function ShowLiveryHUD(progress)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "livery-hud" }
    })
    
    SendNUIMessage({
        action = "liveryHud",
        data = {
            progress = progress or 0,
            label = t("applying_livery") or "Applying livery..."
        }
    })
end

-- Update livery HUD progress
function UpdateLiveryHUD(progress)
    SendNUIMessage({
        action = "liveryHud",
        data = {
            progress = progress or 0,
            label = t("applying_livery") or "Applying livery..."
        }
    })
end

-- Hide livery HUD
function HideLiveryHUD()
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "livery-hud" }
    })
end

-- Run vinyl wrap minigame
function RunVinylWrapMinigame(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    
    ShowLiveryHUD(0)
    CreateBlowtorchProp()
    
    local progress = 0.0
    local lastUpdateTime = GetGameTimer()
    local lastProgressUpdate = 0
    local success = false
    
    while true do
        local currentTime = GetGameTimer()
        local deltaTime = (currentTime - lastUpdateTime) / 1000.0
        lastUpdateTime = currentTime
        
        if deltaTime < 0 then deltaTime = 0 end
        if deltaTime > 0.05 then deltaTime = 0.05 end
        
        -- Check if vehicle still exists
        if not DoesEntityExist(vehicle) then
            success = false
            break
        end
        
        -- Check for cancel key (X)
        if IsControlJustReleased(0, 73) then
            success = false
            break
        end
        
        -- Disable movement controls during minigame
        DisableControlAction(0, 24, true)  -- Attack
        DisableControlAction(0, 69, true)  -- Vehicle attack
        DisableControlAction(0, 92, true)  -- Vehicle horn
        
        -- Check if player is aiming at the vehicle
        if IsDisabledControlPressed(0, 24) then  -- Left click / attack
            local hit, hitEntity = RaycastFromCamera(RAYCAST_DISTANCE)
            local pedPos = GetEntityCoords(PlayerPedId())
            local vehiclePos = GetEntityCoords(vehicle)
            local distanceToVehicle = #(pedPos - vehiclePos)
            
            if hit and hitEntity == vehicle and distanceToVehicle <= RAYCAST_DISTANCE then
                progress = math.min(1.0, progress + (deltaTime * PROGRESS_INCREMENT))
            end
        end
        
        -- Update HUD every UPDATE_INTERVAL_MS
        if currentTime - lastProgressUpdate >= UPDATE_INTERVAL_MS then
            lastProgressUpdate = currentTime
            UpdateLiveryHUD(math.floor(progress * 100))
        end
        
        if progress >= 1.0 then
            UpdateLiveryHUD(100)
            success = true
            break
        end
        
        Wait(0)
    end
    
    DestroyBlowtorchProp()
    HideLiveryHUD()
    
    return success
end

-- Start livery installation
function StartLiveryInstall(vehicle, liveryData, callback)
    -- Check if another repair is in progress
    if InstallFlow and InstallFlow.IsActive() then
        bridge.Notify.SendNotify(t("repair_in_progress") or "A repair is already in progress", "error")
        if callback then callback(false) end
        return false
    end
    
    -- Get vehicle if not provided
    if not vehicle or not DoesEntityExist(vehicle) then
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        vehicle = GetClosestVehicle(pedCoords.x, pedCoords.y, pedCoords.z, RAYCAST_DISTANCE, 0, 70)
    end
    
    -- Validate vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if callback then callback(false) end
        return false
    end
    
    -- Check distance to vehicle
    local pedPos = GetEntityCoords(PlayerPedId())
    local vehiclePos = GetEntityCoords(vehicle)
    if #(pedPos - vehiclePos) > RAYCAST_DISTANCE then
        bridge.Notify.SendNotify(t("get_closer_to_vehicle") or "Get closer to the vehicle", "error")
        if callback then callback(false) end
        return false
    end
    
    -- Parse livery data
    liveryData = liveryData or {}
    local modIndex = liveryData.modIndex and tonumber(liveryData.modIndex) or nil
    
    -- Create install recipe
    local recipe = InstallRecipes.livery_install({
        modIndex = modIndex,
        liveryOldMethod = liveryData.liveryOldMethod == true
    })
    
    -- Start install flow
    local started = InstallFlow.Start(recipe, {
        vehicle = vehicle,
        modId = 48,
        modIndex = modIndex,
        expectedRef = liveryData.referenceNumber or liveryData.reference,
        onComplete = callback
    })
    
    if not started and callback then
        callback(false)
    end
    
    return started
end

-- Clean up on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DestroyBlowtorchProp()
    end
end)

-- Key constants for debug editor
local KeyCodes = {
    LEFT = 37,
    RIGHT = 39,
    UP = 38,
    DOWN = 40,
    PGUP = 33,
    PGDN = 34,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    U = 85,
    O = 79,
    R = 82,
    COMMA = 188,
    PERIOD = 190,
    LBRACKET = 219,
    RBRACKET = 221,
    ENTER = 13,
    BACKSPACE = 8
}

-- Helper function to draw text on screen
function DrawText(text, x, y, scale)
    scale = scale or 0.34
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(2, 0, 0, 0, 200)
    SetTextEdge(2, 0, 0, 0, 200)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

-- Helper to attach entity to ped with specific offsets
function AttachEntityToPed(entity, ped, bone, offX, offY, offZ, rotX, rotY, rotZ)
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, bone),
        offX, offY, offZ, rotX, rotY, rotZ,
        true, true, false, true, 1, true)
end

-- Debug: Livery prop attach editor
if Config.Debug then
    RegisterCommand("livery_attach_test", function(_, args)
        if Config.Debug == false then
            print("[livery_attach_test] Config.Debug is false, ignoring")
            return
        end
        
        -- Parse arguments
        local modelName = (args and args[1] and args[1] ~= "") and args[1] or BLOWTORCH_MODEL
        local boneId = tonumber(args and args[2]) or ATTACH_BONE
        
        -- Default offset/rotation values
        local offX = ATTACH_OFFSET_X
        local offY = ATTACH_OFFSET_Y
        local offZ = ATTACH_OFFSET_Z
        local rotX = ATTACH_ROT_X
        local rotY = ATTACH_ROT_Y
        local rotZ = ATTACH_ROT_Z
        local posStep = 0.005
        local rotStep = 1.0
        
        Citizen.CreateThread(function()
            local ped = PlayerPedId()
            
            -- Load animation
            RequestAnimDict(ANIM_DICT)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(ANIM_DICT) and GetGameTimer() < timeout do
                Wait(0)
            end
            
            TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 51, 0, false, false, false)
            
            -- Load model
            local modelHash = type(modelName) == "string" and GetHashKey(modelName) or modelName
            RequestModel(modelHash)
            timeout = GetGameTimer() + 2000
            while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
                Wait(0)
            end
            
            if not HasModelLoaded(modelHash) then
                print(string.format("[livery_attach_test] Failed to load model: %s", tostring(modelName)))
                ClearPedTasks(ped)
                return
            end
            
            -- Create prop
            local prop = CreateObject(modelHash, 0.0, 0.0, 0.0, true, true, false)
            AttachEntityToPed(prop, ped, boneId, offX, offY, offZ, rotX, rotY, rotZ)
            
            print("[livery_attach_test] Edit mode active. Press Enter to print values, Backspace to exit.")
            
            -- Editor loop
            while true do
                ped = PlayerPedId()
                
                -- Disable controls
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                
                local updated = false
                
                -- Position adjustments
                if IsRawKeyDown(KeyCodes.LEFT) then
                    offX = offX - posStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.RIGHT) then
                    offX = offX + posStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.UP) then
                    offY = offY + posStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.DOWN) then
                    offY = offY - posStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.PGUP) then
                    offZ = offZ + posStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.PGDN) then
                    offZ = offZ - posStep
                    updated = true
                end
                
                -- Rotation adjustments
                if IsRawKeyDown(KeyCodes.I) then
                    rotX = rotX - rotStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.K) then
                    rotX = rotX + rotStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.J) then
                    rotY = rotY - rotStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.L) then
                    rotY = rotY + rotStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.U) then
                    rotZ = rotZ - rotStep
                    updated = true
                end
                if IsRawKeyDown(KeyCodes.O) then
                    rotZ = rotZ + rotStep
                    updated = true
                end
                
                -- Step size adjustments
                if IsRawKeyReleased(KeyCodes.PERIOD) then
                    posStep = math.min(posStep * 2.0, 0.5)
                end
                if IsRawKeyReleased(KeyCodes.COMMA) then
                    posStep = math.max(posStep * 0.5, 0.0001)
                end
                if IsRawKeyReleased(KeyCodes.LBRACKET) then
                    rotStep = math.max(rotStep * 0.5, 0.1)
                end
                if IsRawKeyReleased(KeyCodes.RBRACKET) then
                    rotStep = math.min(rotStep * 2.0, 45.0)
                end
                
                -- Reset to defaults
                if IsRawKeyReleased(KeyCodes.R) then
                    offX = ATTACH_OFFSET_X
                    offY = ATTACH_OFFSET_Y
                    offZ = ATTACH_OFFSET_Z
                    rotX = ATTACH_ROT_X
                    rotY = ATTACH_ROT_Y
                    rotZ = ATTACH_ROT_Z
                    updated = true
                    print("[livery_attach_test] Reset to defaults.")
                end
                
                -- Print values
                if IsRawKeyReleased(KeyCodes.ENTER) then
                    local output = string.format([[
                    
-- Copy these into cl_livery.lua:
local WRAP_PROP_BONE  = %d
local WRAP_PROP_OFF_X = %.4f
local WRAP_PROP_OFF_Y = %.4f
local WRAP_PROP_OFF_Z = %.4f
local WRAP_PROP_ROT_X = %.2f
local WRAP_PROP_ROT_Y = %.2f
local WRAP_PROP_ROT_Z = %.2f
]], boneId, offX, offY, offZ, rotX, rotY, rotZ)
                    print(output)
                end
                
                -- Exit
                if IsRawKeyReleased(KeyCodes.BACKSPACE) then
                    break
                end
                
                -- Apply updates
                if updated then
                    AttachEntityToPed(prop, ped, boneId, offX, offY, offZ, rotX, rotY, rotZ)
                end
                
                -- Draw UI
                DrawText("~y~LIVERY PROP ATTACH EDITOR", 0.02, 0.02, 0.4)
                DrawText(string.format("~w~model: ~y~%s   ~w~bone: ~y~%d", tostring(modelName), boneId), 0.02, 0.055, 0.32)
                DrawText(string.format("~w~offset:  X=%.4f  Y=%.4f  Z=%.4f", offX, offY, offZ), 0.02, 0.085, 0.32)
                DrawText(string.format("~w~rot:     X=%.2f   Y=%.2f   Z=%.2f", rotX, rotY, rotZ), 0.02, 0.11, 0.32)
                DrawText(string.format("~w~step:    pos=%.4f   rot=%.2f", posStep, rotStep), 0.02, 0.135, 0.32)
                DrawText("~b~[Arrows]~w~ X/Y  ~b~[PgUp/PgDn]~w~ Z", 0.02, 0.175, 0.3)
                DrawText("~b~[I/K]~w~ rotX  ~b~[J/L]~w~ rotY  ~b~[U/O]~w~ rotZ", 0.02, 0.198, 0.3)
                DrawText("~b~[, / .]~w~ pos step  ~b~[ [ / ] ]~w~ rot step  ~b~[R]~w~ reset", 0.02, 0.221, 0.3)
                DrawText("~g~[Enter]~w~ print values   ~r~[Backspace]~w~ exit", 0.02, 0.244, 0.3)
                
                Wait(0)
            end
            
            -- Cleanup
            if prop and DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            ClearPedTasks(PlayerPedId())
            SetModelAsNoLongerNeeded(modelHash)
            print("[livery_attach_test] Exited edit mode.")
        end)
    end, false)
    
    -- Add chat suggestion
    TriggerEvent("chat:addSuggestion", "/livery_attach_test", "Open the livery prop attach editor", {
        { name = "propModel", help = string.format("optional, default %s", BLOWTORCH_MODEL) },
        { name = "bone", help = string.format("optional, default %d", ATTACH_BONE) }
    })
end