-- Global wheel prop for carrying wheels
wheelProp = nil

-- Initialize state
State.wheelSwap = nil

-- Wheel bone mappings for 4-wheel vehicles
local WHEEL_BONES_4_WHEEL = {
    [0] = "wheel_lf",
    [1] = "wheel_rf",
    [2] = "wheel_lr",
    [3] = "wheel_rr"
}

-- Wheel bone mappings for bikes
local WHEEL_BONES_BIKE = {
    [0] = "wheel_lf",
    [4] = "wheel_lr"
}

-- Map bone names to wheel indices
local BONE_TO_WHEEL_INDEX = {
    wheel_lf = 0,
    wheel_rf = 1,
    wheel_lr = 2,
    wheel_rr = 3
}

-- Check if vehicle is a bike
function IsBikeClass(vehicleClass)
    return vehicleClass == 8 or vehicleClass == 13
end

-- Get wheel index for a given bone name
function GetWheelIndex(vehicle, boneName)
    local vehicleClass = GetVehicleClass(vehicle)
    
    if IsBikeClass(vehicleClass) then
        if boneName == "wheel_lf" then return 0 end
        if boneName == "wheel_lr" then return 4 end
        return nil
    end
    
    return BONE_TO_WHEEL_INDEX[boneName]
end

-- Get display name for a wheel
function GetWheelDisplayName(vehicle, boneName)
    local vehicleClass = GetVehicleClass(vehicle)
    
    if IsBikeClass(vehicleClass) then
        if boneName == "wheel_lf" then return "Front" end
        if boneName == "wheel_lr" then return "Rear" end
        return nil
    end
    
    local wheelIndex = BONE_TO_WHEEL_INDEX[boneName]
    local wheelNames = {
        [0] = "Front Left",
        [1] = "Front Right",
        [2] = "Rear Left",
        [3] = "Rear Right"
    }
    return wheelNames[wheelIndex]
end

-- Get existing wheel bones on a vehicle
function GetVehicleWheelBones(vehicle)
    local bones = {}
    local count = 0
    
    local boneMap = IsBikeClass(GetVehicleClass(vehicle)) and WHEEL_BONES_BIKE or WHEEL_BONES_4_WHEEL
    
    for wheelIndex, boneName in pairs(boneMap) do
        local boneId = GetEntityBoneIndexByName(vehicle, boneName)
        if boneId ~= -1 then
            bones[wheelIndex] = boneName
            count = count + 1
        end
    end
    
    return bones, count
end

-- Check if vehicle is attached to a lift
function IsVehicleAttachedToLift(vehicle)
    local vehicleNetId = VehToNet(vehicle)
    
    for _, liftState in pairs(State.liftStates) do
        if liftState and liftState.isAttached and liftState.vehicleNetId == vehicleNetId then
            return true
        end
    end
    
    return false
end

-- Set vehicle wheel X offsets synced across network
function SetVehicleWheelXOffsetsSynced(vehicle, offsets)
    if not vehicle or not DoesEntityExist(vehicle) or type(offsets) ~= "table" then
        return
    end
    
    local currentOffsets = {}
    for i = 0, 4 do
        currentOffsets[i] = GetVehicleWheelXOffset(vehicle, i)
    end
    
    for wheelIndex, offset in pairs(offsets) do
        if type(wheelIndex) == "number" and wheelIndex >= 0 and wheelIndex <= 4 and type(offset) == "number" then
            currentOffsets[wheelIndex] = offset
        end
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId and netId ~= 0 then
        TriggerServerEvent("nn_mechanic:setVehicleWheelXOffsets", netId, currentOffsets)
    end
end

-- Handle wheel X offsets state bag changes
AddStateBagChangeHandler("nn_wheel_x_offsets", nil, function(stateBagName, _, offsets)
    if type(offsets) ~= "table" then
        return
    end
    
    local vehicle = GetEntityFromStateBagName(stateBagName)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    
    for wheelIndex, offset in pairs(offsets) do
        if type(wheelIndex) == "number" and type(offset) == "number" then
            SetVehicleWheelXOffset(vehicle, wheelIndex, offset)
        end
    end
end)

-- Create new wheel swap state
function CreateWheelSwapState(vehicle, wheelItem, callback)
    local bones, boneCount = GetVehicleWheelBones(vehicle)
    
    if boneCount == 0 then
        bridge.Notify.SendNotify(t("no_wheels_found") or "No wheels found on this vehicle", "error")
        return nil
    end
    
    -- Save original wheel X offsets
    local originalOffsets = {}
    for wheelIndex, boneName in pairs(bones) do
        originalOffsets[wheelIndex] = GetVehicleWheelXOffset(vehicle, wheelIndex)
    end
    
    return {
        inProgress = true,
        stage = "remove",
        vehicle = vehicle,
        vehicleNetId = VehToNet(vehicle),
        expectedWheelRef = wheelItem.referenceNumber,
        targetModIndex = wheelItem.modIndex,
        targetWheelType = wheelItem.wheelId or 0,
        wheelBones = bones,
        wheelCount = boneCount,
        originalWheelXOffsets = originalOffsets,
        removed = {},
        installed = {},
        removedCount = 0,
        installedCount = 0,
        currentRemoveIndex = nil,
        onComplete = callback,
        hasWheelItem = false,
        firstInstallDone = false
    }
end

-- Create instruction steps for wheel swap
function CreateWheelSwapInstructions(wheelCount, stage, removedCount, installedCount)
    local isVehicleAttached = false
    local isRemoveComplete = removedCount >= wheelCount
    local isInstallReady = stage == "install" or stage == "done"
    local isDone = stage == "done"
    
    local instructions = {
        {
            title = t("wheel_swap_attach_vehicle") or "Attach Vehicle to Lift",
            description = t("wheel_swap_attach_vehicle_desc") or "The vehicle must be on a lift",
            completed = isVehicleAttached
        },
        {
            title = (t("wheel_swap_remove_deposit_wheels") or "Remove & Deposit Wheels") .. " (" .. removedCount .. "/" .. wheelCount .. ")",
            description = t("wheel_swap_remove_deposit_wheels_desc") or "Select a wheel to remove, then deposit it",
            completed = isRemoveComplete
        },
        {
            title = t("wheel_swap_use_wheel_item") or "Use New Wheel Item",
            description = t("wheel_swap_use_wheel_item_desc") or "Use the wheel item from your inventory",
            completed = isInstallReady
        },
        {
            title = (t("wheel_swap_install_wheels") or "Install New Wheels") .. " (" .. installedCount .. "/" .. wheelCount .. ")",
            description = t("wheel_swap_install_wheels_desc") or "Align and install each new wheel",
            completed = isDone
        }
    }
    
    return instructions
end

-- Show current wheel swap instructions
function ShowWheelSwapInstructions()
    local swap = State.wheelSwap
    if not swap then return end
    
    local instructions = CreateWheelSwapInstructions(
        swap.wheelCount,
        swap.stage,
        swap.removedCount,
        swap.installedCount
    )
    
    OpenInstructions(instructions)
end

-- Reshow instructions if wheel swap is in progress
function ReshowWheelSwapInstructionsIfInProgress()
    if not State.wheelSwap or not State.wheelSwap.inProgress then
        return
    end
    ShowWheelSwapInstructions()
end

-- Get available wheels for removal
function GetAvailableWheelsForRemoval()
    local swap = State.wheelSwap
    if not swap then return {} end
    
    local availableWheels = {}
    for wheelIndex, boneName in pairs(swap.wheelBones) do
        if not swap.removed[wheelIndex] then
            local label = t(boneName) or GetWheelDisplayName(swap.vehicle, boneName) or ("Wheel " .. wheelIndex)
            table.insert(availableWheels, {
                label = label,
                icon = "fas fa-circle",
                nuiCallback = "wheelSwapSelectWheel",
                callbackData = { wheelIndex = wheelIndex, boneName = boneName }
            })
        end
    end
    
    table.insert(availableWheels, {
        label = t("cancel") or "Cancel",
        icon = "fas fa-times",
        nuiCallback = "wheelSwapCancel",
        callbackData = {}
    })
    
    return availableWheels
end

-- Show wheel removal menu
function ShowWheelRemoveMenu()
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "remove" then
        return
    end
    
    local vehicle = swap.vehicle
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("vehicle_not_found") or "Vehicle not found", "error")
        CleanupWheelSwap(false)
        return
    end
    
    -- Check if all wheels removed
    if swap.removedCount >= swap.wheelCount then
        swap.stage = "useItem"
        ShowWheelSwapInstructions()
        bridge.Notify.SendNotify(t("all_wheels_removed_use_item") or "All wheels removed. Use the new wheel item from your inventory.", "info")
        return
    end
    
    local menuItems = GetAvailableWheelsForRemoval()
    
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "wheel_swap_menu",
            title = (t("select_wheel_to_remove") or "Select Wheel to Remove") .. " (" .. swap.removedCount .. "/" .. swap.wheelCount .. ")",
            items = menuItems
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = "wheel_swap_menu"
    StartMenuControlsThread()
end

-- Get closest wheel index and bone name
function GetClosestWheel(vehicle)
    local wheelList = {"wheel_rf", "wheel_lf", "wheel_lr", "wheel_rr"}
    local closestBone = nil
    local closestDist = nil
    
    for _, boneName in ipairs(wheelList) do
        local boneId = GetEntityBoneIndexByName(vehicle, boneName)
        if boneId ~= -1 then
            local bonePos = GetWorldPositionOfEntityBone(vehicle, boneId)
            local pedPos = GetEntityCoords(State.Ped)
            local dist = #(bonePos - pedPos)
            
            if closestDist == nil or closestDist > dist then
                closestDist = dist
                closestBone = boneName
            end
        end
    end
    
    return closestBone, closestDist
end

-- Get distance to wheel bone
function GetDistanceToWheelBone(vehicle, boneName)
    local boneId = GetEntityBoneIndexByName(vehicle, boneName)
    if boneId == -1 then
        return math.huge
    end
    
    local bonePos = GetWorldPositionOfEntityBone(vehicle, boneId)
    local pedPos = GetEntityCoords(PlayerPedId())
    return #(bonePos - pedPos)
end

-- Start bolt removal minigame
function StartWheelBoltRemoval(vehicle, wheelIndex, boneName, callback)
    local config = boneConfig[boneName]
    if not config then
        bridge.Notify.SendNotify(t("wheel_config_missing") or "Wheel configuration missing", "error")
        if callback then callback(false) end
        return
    end
    
    local boltOffsets = config.boltOffsets
    local boltRotations = config.boltRotations
    
    State.disableControls = true
    DisableControls()
    bridge.Target.RemoveLocalEntity(vehicle)
    
    Citizen.CreateThread(function()
        local boltHandler = PlaceBolts(vehicle, boneName, boltOffsets, boltRotations, true)
        
        if not boltHandler then
            SetEntityVisible(State.Ped, true)
            State.disableControls = false
            if callback then callback(false) end
            return
        end
        
        StartBoltMinigame(boltHandler, boneName)
        SetEntityVisible(State.Ped, true)
        ClearMechanicAlphaAnim(State.Ped)
        State.disableControls = false
        
        -- Update wheel offset to remove the wheel
        SetVehicleWheelXOffsetsSynced(vehicle, { [wheelIndex] = -999 })
        
        -- Update wheel swap state
        local swap = State.wheelSwap
        if swap then
            swap.removed[wheelIndex] = true
            swap.removedCount = swap.removedCount + 1
            swap.currentRemoveIndex = wheelIndex
        end
        
        if callback then callback(true) end
    end)
end

-- Show wheel install menu
function ShowWheelInstallMenu()
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "install" then
        return
    end
    
    local vehicle = swap.vehicle
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("vehicle_not_found") or "Vehicle not found", "error")
        CleanupWheelSwap(false)
        return
    end
    
    -- Check if all wheels installed
    if swap.installedCount >= swap.wheelCount then
        swap.stage = "done"
        ShowWheelSwapInstructions()
        CleanupWheelSwap(true)
        return
    end
    
    local menuItems = {}
    
    for wheelIndex, boneName in pairs(swap.wheelBones) do
        if not swap.installed[wheelIndex] then
            local label = t(boneName) or GetWheelDisplayName(swap.vehicle, boneName) or ("Wheel " .. wheelIndex)
            table.insert(menuItems, {
                label = label,
                icon = "fas fa-circle",
                nuiCallback = "wheelSwapSelectWheelInstall",
                callbackData = { wheelIndex = wheelIndex, boneName = boneName }
            })
        end
    end
    
    table.insert(menuItems, {
        label = t("cancel") or "Cancel",
        icon = "fas fa-times",
        nuiCallback = "wheelSwapCancel",
        callbackData = {}
    })
    
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "wheel_swap_menu",
            title = (t("select_wheel_to_install") or "Select Wheel to Install") .. " (" .. swap.installedCount .. "/" .. swap.wheelCount .. ")",
            items = menuItems
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = "wheel_swap_menu"
    StartMenuControlsThread()
end

-- Clean up wheel swap
function CleanupWheelSwap(success)
    local swap = State.wheelSwap
    if not swap then return end
    
    local vehicle = swap.vehicle
    local onComplete = swap.onComplete
    
    -- Close any open menu
    if State.openPage == "menu" and State.currentMenuId == "wheel_swap_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    -- Restore original wheel offsets
    if DoesEntityExist(vehicle) then
        SetVehicleWheelXOffsetsSynced(vehicle, swap.originalWheelXOffsets)
        
        if success then
            local vehicleProps = getVehicleProperties(vehicle)
            TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
            setVehicleProperties(vehicle, vehicleProps)
        end
    end
    
    -- Clean up wheel prop
    if wheelProp and DoesEntityExist(wheelProp) then
        DeleteEntity(wheelProp)
        wheelProp = nil
    end
    
    -- Reset state
    State.wheelSwap = nil
    State.pendingWheelSwap = nil
    State.pendingWheelChange = nil
    State.repairInProgress = false
    State.waitingForWheel = false
    State.disableControls = false
    
    CloseInstructions()
    SetEntityVisible(State.Ped, true)
    ClearMechanicAlphaAnim(State.Ped)
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, true)
    
    if onComplete then
        onComplete(success)
    end
end

-- Continue wheel swap process
function ContinueWheelSwap(vehicle, wheelItem, callback)
    local swapState = CreateWheelSwapState(vehicle, wheelItem, callback)
    if not swapState then
        if callback then callback(false) end
        return
    end
    
    State.wheelSwap = swapState
    State.repairInProgress = true
    
    -- Close any open menu
    if State.openPage == "menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
    end
    
    ShowWheelSwapInstructions()
    ShowWheelRemoveMenu()
end

-- Start wheel swap process
function startWheelSwap(vehicle, wheelItem, callback)
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if callback then callback(false) end
        return
    end
    
    if not wheelItem or not wheelItem.referenceNumber then
        bridge.Notify.SendNotify(t("invalid_order_part") or "Invalid order part", "error")
        if callback then callback(false) end
        return
    end
    
    -- Try to use install flow if available
    if InstallFlow and InstallFlow.Start then
        local started = InstallFlow.Start(InstallRecipes.wheel_swap({}), {
            vehicle = vehicle,
            extras = {
                continue = function()
                    ContinueWheelSwap(vehicle, wheelItem, callback)
                end
            },
            onComplete = nil
        })
        
        if started then
            return
        end
    end
    
    -- Check if vehicle is on lift
    if not IsVehicleAttachedToLift(vehicle) then
        bridge.Notify.SendNotify(t("attach_vehicle_to_continue") or "Attach the vehicle to the lift to continue", "info")
        if callback then callback(false) end
        return
    end
    
    ContinueWheelSwap(vehicle, wheelItem, callback)
end

-- Deposit wheels after removal
function DepositWheelSwapWheels()
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "deposit" then
        return false
    end
    
    -- Clean up wheel prop
    if wheelProp and DoesEntityExist(wheelProp) then
        DeleteEntity(wheelProp)
        wheelProp = nil
    end
    
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, true)
    
    if swap.removedCount >= swap.wheelCount then
        swap.stage = "useItem"
        ShowWheelSwapInstructions()
        bridge.Notify.SendNotify(t("all_wheels_deposited_use_item") or "All wheels deposited. Use the new wheel item from your inventory.", "info")
    else
        swap.stage = "remove"
        ShowWheelSwapInstructions()
        bridge.Notify.SendNotify(t("wheel_deposited_select_next") or "Wheel deposited. Select the next wheel to remove.", "success")
        
        Citizen.SetTimeout(500, function()
            ShowWheelRemoveMenu()
        end)
    end
    
    return true
end

-- Validate wheel swap item
function ValidateWheelSwapItem(referenceNumber, itemData, itemName)
    local swap = State.wheelSwap
    if not swap then
        return false, nil
    end
    
    local stage = swap.stage
    if stage ~= "useItem" and stage ~= "install" then
        return false, nil
    end
    
    if referenceNumber == swap.expectedWheelRef then
        return true, nil
    end
    
    if itemData and IsValidPartItem(23, swap.expectedWheelRef, itemData, itemName) then
        return true, nil
    end
    
    return false, swap.expectedWheelRef
end

-- Confirm wheel swap item and proceed to installation
function ConfirmWheelSwapItem()
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "useItem" then
        return false
    end
    
    swap.stage = "install"
    swap.hasWheelItem = true
    
    ShowWheelSwapInstructions()
    WheelChopAnimation()
    
    bridge.Notify.SendNotify(t("wheel_item_valid_select") or "Wheel item verified. Select a wheel to install.", "success")
    
    Citizen.SetTimeout(500, function()
        ShowWheelInstallMenu()
    end)
    
    return true
end

-- Install wheel during swap
function InstallWheelSwapWheel()
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "install" then
        return false
    end
    
    ShowWheelInstallMenu()
    return true
end

-- Change a single wheel (not full swap)
function ChangeWheel(ctx)
    local vehicle = ctx.vehicle
    
    -- Try to use install flow
    if InstallFlow and InstallFlow.Start then
        local started = InstallFlow.Start(InstallRecipes.wheel_swap({}), {
            vehicle = vehicle,
            extras = {
                continue = function()
                    ContinueWheelChange(ctx)
                end
            }
        })
        
        if started then
            return
        end
    end
    
    if not IsVehicleAttachedToLift(vehicle) then
        bridge.Notify.SendNotify(t("attach_vehicle_to_continue") or "Attach the vehicle to the lift to continue", "info")
        return
    end
    
    ContinueWheelChange(ctx)
end

-- Continue wheel change process
function ContinueWheelChange(ctx)
    local vehicle = ctx.vehicle
    local boneName = ctx.boneName
    local wheelIndexes = {}
    local wheelIdx = GetWheelIndex(vehicle, boneName)
    wheelIndexes[boneName] = wheelIdx
    
    State.repairInProgress = true
    
    -- Close any open menu
    if State.openPage == "menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
    end
    
    -- Create instructions
    local instructions = {
        {
            title = t("attach_vehicle") or "Attach Vehicle",
            description = t("wheel_instruction_attach_vehicle_desc") or "Vehicle must be on lift",
            completed = true
        },
        {
            title = t("wheel_instruction_remove_bolts") or "Remove Bolts",
            description = t("wheel_instruction_remove_bolts_desc") or "Remove the wheel bolts",
            completed = false
        },
        {
            title = t("wheel_instruction_deposit_wheel") or "Deposit Wheel",
            description = t("wheel_instruction_deposit_wheel_desc") or "Deposit the old wheel",
            completed = false
        },
        {
            title = t("wheel_instruction_use_new_wheel") or "Use New Wheel",
            description = t("wheel_instruction_use_new_wheel_desc") or "Use new wheel item from inventory",
            completed = false
        },
        {
            title = t("wheel_instruction_attach_new_wheel") or "Attach New Wheel",
            description = t("wheel_instruction_attach_new_wheel_desc") or "Install the new wheel",
            completed = false
        }
    }
    
    local config = boneConfig[boneName]
    if not config then return end
    
    local boltOffsets = config.boltOffsets
    local boltRotations = config.boltRotations
    local enableMinigame = true
    
    OpenInstructions(instructions)
    bridge.Notify.SendNotify(t("get_closer_to_the_tire") or "Get closer to the tire", "info")
    
    Citizen.CreateThread(function()
        local requiredDistance = 1.5
        local boltCtx = {
            ctx = ctx,
            vehicle = vehicle,
            boneName = boneName,
            boltOffsets = boltOffsets,
            boltRotations = boltRotations,
            enableMinigame = enableMinigame,
            wheelIndexes = wheelIndexes
        }
        
        while State.repairInProgress do
            Wait(0)
            
            -- Check for cancel key
            if IsControlJustPressed(0, 177) then
                State.repairInProgress = false
                CloseInstructions()
                bridge.Notify.SendNotify(t("wheel_change_cancelled") or "Wheel change cancelled", "info")
                return
            end
            
            local distance = GetDistanceToWheelBone(vehicle, boneName)
            if requiredDistance >= distance then
                StartWheelBoltMinigame(boltCtx)
                return
            end
        end
    end)
end

-- Start wheel bolt minigame for single wheel change
function StartWheelBoltMinigame(ctx)
    local vehicle = ctx.vehicle
    local boneName = ctx.boneName
    local boltOffsets = ctx.boltOffsets
    local boltRotations = ctx.boltRotations
    local enableMinigame = ctx.enableMinigame
    local wheelIndexes = ctx.wheelIndexes
    local originalCtx = ctx.ctx
    
    State.disableControls = true
    DisableControls()
    StartMechanicAlphaAnim(State.Ped)
    bridge.Target.RemoveLocalEntity(vehicle)
    
    Citizen.CreateThread(function()
        local boltHandler = PlaceBolts(vehicle, boneName, boltOffsets, boltRotations, enableMinigame)
        StartBoltMinigame(boltHandler, boneName)
        
        SetEntityVisible(State.Ped, true)
        ClearMechanicAlphaAnim(State.Ped)
        State.disableControls = false
        
        CompleteInstructionStep(2)
        
        local boneId = GetEntityBoneIndexByName(vehicle, boneName)
        local bonePos = GetWorldPositionOfEntityBone(vehicle, boneId)
        local camPos, targetPos = CalculateCameraPosition(vehicle, boneName)
        local wheelXOffset = GetVehicleWheelXOffset(vehicle, wheelIndexes[boneName])
        
        -- Store context for later
        originalCtx.wheelXOffset = wheelXOffset
        originalCtx.camPos = camPos
        originalCtx.targetPos = targetPos
        originalCtx.bonePos = bonePos
        
        -- Save to service points context if available
        local pointIndex = State.currentPointCtxIndex
        if not pointIndex then
            local vehicleNetId = VehToNet(vehicle)
            for idx, pointCtx in pairs(State.servicePointsCtx) do
                if pointCtx and pointCtx.vehicleNetId == vehicleNetId then
                    pointIndex = idx
                    break
                end
            end
        end
        
        originalCtx.vehicle = vehicle
        if originalCtx.vehicleNetId then
            originalCtx.vehicleNetId = VehToNet(vehicle)
        end
        
        local saveCtx = {
            vehicleNetId = originalCtx.vehicleNetId,
            pointId = originalCtx.pointId,
            shopId = originalCtx.shopId,
            boneName = boneName,
            bonePos = bonePos,
            camPos = camPos,
            targetPos = targetPos,
            wheelXOffset = wheelXOffset,
            inspectionData = originalCtx.inspectionData,
            employeeName = originalCtx.employeeName
        }
        
        TriggerServerEvent("nn_mechanic:setServicePointCtx", originalCtx.shopId, originalCtx.pointId, saveCtx)
        originalCtx.vehicle = vehicle
        
        if pointIndex then
            State.servicePointsCtx[pointIndex] = originalCtx
        end
        
        -- Remove the wheel
        SetVehicleWheelXOffsetsSynced(vehicle, { [wheelIndexes[boneName]] = -999 })
        WheelChopAnimation()
    end)
end

-- Install new wheel after deposit
function InstallNewWheel(ctx)
    local vehicle = ctx.vehicle
    local boneName = ctx.boneName
    local wheelIndexes = {}
    local wheelIdx = GetWheelIndex(vehicle, boneName)
    wheelIndexes[boneName] = wheelIdx
    
    WheelChopAnimation()
end

-- Wheel carrying animation
function WheelChopAnimation()
    local ped = PlayerPedId()
    
    RequestAnimDict("anim@heists@box_carry@")
    Wait(100)
    
    wheelProp = CreateObject(GetHashKey("imp_prop_impexp_tyre_01b"), 0, 0, 0, true, true, true)
    
    AttachEntityToEntity(wheelProp, ped, GetPedBoneIndex(ped, 60309), -0.05, 0.2, 0.35, -145.0, 100.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, "anim@heists@box_carry@", "idle", 5.0, 5.0, -1, 51, 0, false, false, false)
end

-- Get closest wheel bone
function GetClosestWheelBone(vehicle)
    local wheelNames = {"wheel_rf", "wheel_lf", "wheel_lr", "wheel_rr"}
    local closestBone = nil
    local closestDist = nil
    
    for _, boneName in ipairs(wheelNames) do
        local boneId = GetEntityBoneIndexByName(vehicle, boneName)
        if boneId ~= -1 then
            local bonePos = GetWorldPositionOfEntityBone(vehicle, boneId)
            local pedPos = GetEntityCoords(State.Ped)
            local dist = #(bonePos - pedPos)
            
            if closestDist == nil or closestDist > dist then
                closestDist = dist
                closestBone = boneName
            end
        end
    end
    
    return closestBone, closestDist
end

-- NUI Callback: Check tire condition
RegisterNUICallback("checkTire", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    local pointCtx = pointIndex and State.servicePointsCtx[pointIndex]
    
    if not pointCtx then
        for idx, ctx in pairs(State.servicePointsCtx) do
            if ctx and ctx.vehicle and DoesEntityExist(ctx.vehicle) then
                pointCtx = ctx
                pointIndex = idx
                break
            end
        end
    end
    
    if not pointCtx or not DoesEntityExist(pointCtx.vehicle) then
        cb({ success = false })
        return
    end
    
    local boneName = data.boneName
    if not boneName then
        cb({ success = false })
        return
    end
    
    local closestBone, closestDist = GetClosestWheelBone(pointCtx.vehicle)
    if closestBone ~= boneName or closestDist > 1.0 then
        bridge.Notify.SendNotify(t("get_closer_to_the_tire") or "Get closer to the tire", "error")
        cb({ success = false })
        return
    end
    
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local progressSuccess = bridge.ProgressBar.Open({
        duration = 5000,
        label = t("checking_tire") or "Checking tire...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer", flag = 1 }
    })
    
    if not progressSuccess then
        bridge.Notification.Notify(t("tire_check_failed") or "Tire check failed", "error")
        SetPedCanRagdoll(State.Ped, true)
        cb({ success = false })
        return
    end
    
    local plate = GetVehicleNumberPlateText(pointCtx.vehicle)
    local playerName = bridge.Framework.GetPlayerName(PlayerId())
    local employeeName = playerName .. " " .. (pointCtx.employeeName or "")
    
    local wheelIndex = GetWheelIndex(pointCtx.vehicle, boneName)
    if wheelIndex == nil then
        bridge.Notify.SendNotify("Invalid wheel for this vehicle", "error")
        cb({ success = false })
        return
    end
    
    local tireData = bridge.Callback.Trigger("nn_mechanic:getVehicleTireData", plate, tostring(wheelIndex))
    
    if tireData then
        local wheelDisplayName = GetWheelDisplayName(pointCtx.vehicle, boneName)
        
        if not pointCtx.employeeName then
            pointCtx.employeeName = employeeName
        end
        
        local wheelModIndex = GetVehicleMod(pointCtx.vehicle, 23)
        local wheelType = GetVehicleWheelType(pointCtx.vehicle)
        local wheelReference = generateReferenceNumber(23, wheelModIndex, nil, wheelType)
        
        if not pointCtx.inspectionData then
            pointCtx.inspectionData = {
                vehiclePlate = plate,
                vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(pointCtx.vehicle)),
                tires = {},
                wheelReferenceNumber = wheelReference
            }
        end
        
        if pointCtx.inspectionData.vehiclePlate ~= plate then
            pointCtx.inspectionData = {
                vehiclePlate = plate,
                vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(pointCtx.vehicle)),
                tires = {},
                wheelReferenceNumber = wheelReference
            }
        end
        
        if not pointCtx.inspectionData.wheelReferenceNumber then
            pointCtx.inspectionData.wheelReferenceNumber = wheelReference
        end
        
        local isBurst = tireData.burst ~= nil and tireData.burst or IsVehicleTyreBurst(pointCtx.vehicle, wheelIndex, false)
        local tireFound = false
        
        for i, tire in ipairs(pointCtx.inspectionData.tires) do
            if tire.wheelIndex == wheelIndex then
                pointCtx.inspectionData.tires[i] = {
                    wheelName = wheelDisplayName,
                    wheelIndex = wheelIndex,
                    psi = tireData.psi,
                    tread = tireData.tread,
                    burst = isBurst
                }
                tireFound = true
                break
            end
        end
        
        if not tireFound then
            table.insert(pointCtx.inspectionData.tires, {
                wheelName = wheelDisplayName,
                wheelIndex = wheelIndex,
                psi = tireData.psi,
                tread = tireData.tread,
                burst = isBurst
            })
        end
        
        -- Update service point context
        if pointCtx.vehicleNetId then
            pointCtx.vehicleNetId = VehToNet(pointCtx.vehicle)
        end
        
        local saveCtx = {
            vehicleNetId = pointCtx.vehicleNetId,
            pointId = pointCtx.pointId,
            shopId = pointCtx.shopId,
            inspectionData = pointCtx.inspectionData,
            employeeName = pointCtx.employeeName,
            boneName = pointCtx.boneName
        }
        
        TriggerServerEvent("nn_mechanic:setServicePointCtx", pointCtx.shopId, pointCtx.pointId, saveCtx)
        
        if pointIndex then
            State.servicePointsCtx[pointIndex] = pointCtx
        end
        
        SendNUIMessage({
            action = "setNotepadData",
            data = {
                type = "fullInspection",
                inspectionData = pointCtx.inspectionData,
                employeeName = pointCtx.employeeName
            }
        })
        
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = true, page = "notepad" }
        })
        
        State.openPage = "notepad"
        SetPedCanRagdoll(State.Ped, true)
        cb({ success = true })
    else
        SetPedCanRagdoll(State.Ped, true)
        cb({ success = false })
    end
end)

-- NUI Callback: Change tire
RegisterNUICallback("changeTire", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    local pointCtx = pointIndex and State.servicePointsCtx[pointIndex]
    
    if not pointCtx then
        for idx, ctx in pairs(State.servicePointsCtx) do
            if ctx and ctx.vehicle and DoesEntityExist(ctx.vehicle) then
                pointCtx = ctx
                pointIndex = idx
                break
            end
        end
    end
    
    if not pointCtx or not DoesEntityExist(pointCtx.vehicle) then
        cb({ success = false })
        return
    end
    
    if not pointCtx.inspectionData or not pointCtx.inspectionData.tires or #pointCtx.inspectionData.tires == 0 then
        bridge.Notify.SendNotify(t("check_tire_first_and_get_closer") or "Check the tire first and get closer", "error")
        cb({ success = false })
        return
    end
    
    local boneName = data.boneName
    if not boneName then
        bridge.Notify.SendNotify(t("check_tire_first_and_get_closer") or "Check the tire first and get closer", "error")
        cb({ success = false })
        return
    end
    
    local wheelIndex = GetWheelIndex(pointCtx.vehicle, boneName)
    if wheelIndex == nil then
        bridge.Notify.SendNotify(t("check_tire_first_and_get_closer") or "Check the tire first and get closer", "error")
        cb({ success = false })
        return
    end
    
    local tireFound = false
    for _, tire in ipairs(pointCtx.inspectionData.tires) do
        if tire.wheelIndex == wheelIndex then
            tireFound = true
            
            local boneId = GetEntityBoneIndexByName(pointCtx.vehicle, boneName)
            local bonePos = GetWorldPositionOfEntityBone(pointCtx.vehicle, boneId)
            local pedPos = GetEntityCoords(State.Ped)
            
            if #(bonePos - pedPos) <= 1.0 then
                if tire.tread <= 100 then
                    pointCtx.boneName = boneName
                    pointCtx.bonePos = bonePos
                    
                    if pointIndex then
                        if State.servicePointsCtx[pointIndex] then
                            State.servicePointsCtx[pointIndex].boneName = boneName
                            State.servicePointsCtx[pointIndex].bonePos = bonePos
                        end
                    end
                    
                    if pointCtx.vehicleNetId then
                        pointCtx.vehicleNetId = VehToNet(pointCtx.vehicle)
                    end
                    
                    ChangeWheel(pointCtx)
                    cb({ success = true })
                    return
                else
                    bridge.Notify.SendNotify("Tire tread is still good", "error")
                    break
                end
            else
                bridge.Notify.SendNotify("Get closer to the tire", "error")
                break
            end
        end
    end
    
    if not tireFound then
        bridge.Notify.SendNotify(t("check_tire_first_and_get_closer") or "Check the tire first and get closer", "error", 5000)
    end
    
    cb({ success = false })
end)

-- NUI Callback: Install new wheel
RegisterNUICallback("installNewWheel", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    local pointCtx = pointIndex and State.servicePointsCtx[pointIndex]
    
    if not pointCtx then
        for idx, ctx in pairs(State.servicePointsCtx) do
            if ctx and ctx.vehicle and DoesEntityExist(ctx.vehicle) and ctx.boneName then
                pointCtx = ctx
                pointIndex = idx
                break
            end
        end
    end
    
    if not pointCtx or not DoesEntityExist(pointCtx.vehicle) then
        cb({ success = false })
        return
    end
    
    if not State.waitingForWheel or not pointCtx.boneName then
        cb({ success = false })
        return
    end
    
    if wheelProp and DoesEntityExist(wheelProp) then
        DeleteEntity(wheelProp)
    end
    
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, true)
    Wait(200)
    
    StartMechanicAlphaAnim(State.Ped)
    StartWheelAlignmentMinigame(pointCtx)
    SetEntityVisible(State.Ped, true)
    ClearMechanicAlphaAnim(State.Ped)
    
    cb({ success = true })
end)

-- Cancel pending wheel operation
function CancelPendingWheelOperation()
    if InstallFlow and InstallFlow.IsActive() then
        local activeFlow = InstallFlow.GetActive()
        if activeFlow and activeFlow.id == "wheel_swap" then
            InstallFlow.Cancel(t("wheel_swap_cancelled") or "Wheel swap cancelled")
            return true
        end
    end
    return false
end

-- NUI Callback: Select wheel for removal
RegisterNUICallback("wheelSwapSelectWheel", function(data, cb)
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "remove" then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    local wheelIndex = data.wheelIndex
    local boneName = data.boneName
    
    -- Close menu
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "menu" }
    })
    State.openPage = nil
    State.currentMenuId = nil
    
    -- Check distance
    local distance = GetDistanceToWheelBone(vehicle, boneName)
    if distance > 2.0 then
        bridge.Notify.SendNotify(t("get_closer_to_wheel") or "Get closer to the wheel", "error")
        Citizen.SetTimeout(1000, function()
            ShowWheelRemoveMenu()
        end)
        cb({ success = false })
        return
    end
    
    -- Check if already removed
    if swap.removed[wheelIndex] then
        bridge.Notify.SendNotify(t("wheel_already_removed") or "This wheel is already removed", "error")
        ShowWheelRemoveMenu()
        cb({ success = false })
        return
    end
    
    local wheelDisplayName = t(boneName) or GetWheelDisplayName(vehicle, boneName) or "Wheel"
    bridge.Notify.SendNotify((t("removing_wheel") or "Removing") .. ": " .. wheelDisplayName, "info")
    
    StartWheelBoltRemoval(vehicle, wheelIndex, boneName, function(success)
        if success then
            ShowWheelSwapInstructions()
            swap.stage = "deposit"
            swap.currentRemoveIndex = wheelIndex
            bridge.Notify.SendNotify(t("wheel_removed_deposit") or "Wheel removed. Deposit it at storage.", "info")
        else
            bridge.Notify.SendNotify(t("wheel_removal_failed") or "Wheel removal failed", "error")
            swap.stage = "remove"
            ShowWheelRemoveMenu()
        end
    end)
    
    cb({ success = true })
end)

-- NUI Callback: Cancel wheel swap
RegisterNUICallback("wheelSwapCancel", function(_, cb)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "menu" }
    })
    State.openPage = nil
    State.currentMenuId = nil
    
    CleanupWheelSwap(false)
    cb({ success = true })
end)

-- NUI Callback: Select wheel for installation
RegisterNUICallback("wheelSwapSelectWheelInstall", function(data, cb)
    local swap = State.wheelSwap
    if not swap or swap.stage ~= "install" then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    local wheelIndex = data.wheelIndex
    local boneName = data.boneName
    
    -- Close menu
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "menu" }
    })
    State.openPage = nil
    State.currentMenuId = nil
    
    -- Check distance
    local distance = GetDistanceToWheelBone(vehicle, boneName)
    if distance > 2.0 then
        bridge.Notify.SendNotify(t("get_closer_to_wheel") or "Get closer to the wheel", "error")
        Citizen.SetTimeout(1000, function()
            ShowWheelInstallMenu()
        end)
        cb({ success = false })
        return
    end
    
    -- Check if already installed
    if swap.installed[wheelIndex] then
        bridge.Notify.SendNotify(t("wheel_already_installed") or "This wheel is already installed", "error")
        ShowWheelInstallMenu()
        cb({ success = false })
        return
    end
    
    -- First installation setup
    if not swap.firstInstallDone then
        SetVehicleModKit(vehicle, 0)
        
        if swap.targetWheelType and swap.targetWheelType >= 0 then
            SetVehicleWheelType(vehicle, swap.targetWheelType)
        end
        
        SetVehicleMod(vehicle, 23, swap.targetModIndex, false)
        
        local numMods = GetNumVehicleMods(vehicle, 24)
        if numMods > 0 and numMods > swap.targetModIndex then
            SetVehicleMod(vehicle, 24, swap.targetModIndex, false)
        end
        
        local allOffsets = {}
        for idx, _ in pairs(swap.wheelBones) do
            allOffsets[idx] = -999
        end
        SetVehicleWheelXOffsetsSynced(vehicle, allOffsets)
        
        swap.firstInstallDone = true
    end
    
    -- Clean up existing wheel prop
    if wheelProp and DoesEntityExist(wheelProp) then
        DeleteEntity(wheelProp)
        wheelProp = nil
    end
    
    local wheelDisplayName = t(boneName) or GetWheelDisplayName(vehicle, boneName) or "Wheel"
    bridge.Notify.SendNotify((t("installing_wheel") or "Installing") .. ": " .. wheelDisplayName, "info")
    
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local progressSuccess = bridge.ProgressBar.Open({
        duration = 8000,
        label = t("installing_wheel_progress") or "Installing wheel...",
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer", flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    ClearPedTasksImmediately(State.Ped)
    
    if progressSuccess then
        -- Restore original wheel offset
        local originalOffset = swap.originalWheelXOffsets[wheelIndex]
        SetVehicleWheelXOffsetsSynced(vehicle, { [wheelIndex] = originalOffset })
        
        swap.installed[wheelIndex] = true
        swap.installedCount = swap.installedCount + 1
        
        -- Fix the tire
        SetVehicleTyreBurst(vehicle, wheelIndex, false)
        SetVehicleTyreFixed(vehicle, wheelIndex)
        
        -- Reset tire data
        local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
        if plate and plate ~= "" then
            TriggerServerEvent("nn_mechanic:resetTireDataForWheel", plate, wheelIndex)
        end
        
        ShowWheelSwapInstructions()
        
        if swap.installedCount < swap.wheelCount then
            WheelChopAnimation()
            bridge.Notify.SendNotify(t("wheel_installed_select_next") or "Wheel installed. Select the next wheel to install.", "success")
            Citizen.SetTimeout(500, function()
                ShowWheelInstallMenu()
            end)
        else
            swap.stage = "done"
            ShowWheelSwapInstructions()
            bridge.Notify.SendNotify(t("all_wheels_installed") or "All wheels installed!", "success")
            CleanupWheelSwap(true)
        end
    else
        bridge.Notify.SendNotify(t("wheel_install_failed") or "Wheel installation failed", "error")
        Citizen.SetTimeout(500, function()
            ShowWheelInstallMenu()
        end)
    end
    
    cb({ success = true })
end)