-- Initialize bridge if needed
if not bridge then
    bridge = exports.community_bridge.Bridge()
end

-- Animation constants
local ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local ANIM_CLIP = "machinic_loop_mechandplayer"

-- Repair state
local repairState = {
    inProgress = false,
    vehicle = nil,
    vehiclePlate = nil,
    vehicleVin = nil,
    vehicleModel = nil,
    procedureId = nil,
    procedure = nil,
    currentStepIndex = 1,
    stepStatuses = {},
    healthBefore = nil,
    executingStep = false
}

-- Check if player has all required items
function HasRequiredItems(items)
    items = items or {}
    
    for _, itemReq in ipairs(items) do
        local count = itemReq.count or 1
        local hasItem = bridge.Callback.Trigger("nn_mechanic:hasItem", itemReq.item, count)
        
        if not hasItem then
            return false, itemReq.item, count
        end
    end
    
    return true
end

-- Consume required items
function ConsumeRequiredItems(items)
    items = items or {}
    
    for _, itemReq in ipairs(items) do
        local count = itemReq.count or 1
        local success = bridge.Callback.Trigger("nn_mechanic:consumeItem", itemReq.item, count)
        
        if not success then
            return false
        end
    end
    
    return true
end

-- Check vehicle condition (hood open, engine off, near vehicle)
function CheckVehicleCondition(vehicle, condition)
    if condition == "hoodOpen" then
        local angle = GetVehicleDoorAngleRatio(vehicle, 4)
        return angle > 0.1
        
    elseif condition == "engineOff" then
        return not GetIsVehicleEngineRunning(vehicle)
        
    elseif condition == "nearVehicle" then
        local pedPos = GetEntityCoords(PlayerPedId())
        local vehiclePos = GetEntityCoords(vehicle)
        return #(pedPos - vehiclePos) < 5.0
    end
    
    return true
end

-- Get repair procedure by ID
function GetRepairProcedure(procedureId)
    local procedures = Data.RepairConfig and Data.RepairConfig.Procedures
    return procedures and procedures[procedureId]
end

-- Get vehicle health band for a specific target
function GetVehicleHealthBand(vehicle, target)
    local healthValue = nil
    
    if target == "engine" then
        healthValue = GetVehicleEngineHealth(vehicle)
    elseif target == "body" then
        healthValue = GetVehicleBodyHealth(vehicle)
    else
        return nil, 0
    end
    
    local targetName = (target == "engine") and "Engine" or "Body"
    local bands = Data.RepairConfig and Data.RepairConfig.Bands and Data.RepairConfig.Bands[targetName]
    
    if not bands then
        return nil, healthValue
    end
    
    for _, band in ipairs(bands) do
        if healthValue >= band.min and healthValue <= band.max then
            return band, healthValue
        end
    end
    
    return bands[#bands], healthValue
end

-- Validate that a repair procedure is suitable for the vehicle's current condition
function ValidateRepairSuitability(procedure, vehicle)
    local band, healthValue = GetVehicleHealthBand(vehicle, procedure.targets)
    
    if not band then
        return false, "Could not determine vehicle condition"
    end
    
    local allowedBands = procedure.allowedBands or {}
    for _, allowedBand in ipairs(allowedBands) do
        if allowedBand == band.id then
            return true, nil
        end
    end
    
    return false, "This repair is not suitable for the current damage level"
end

-- Build repair menu items from current procedure
function BuildRepairMenuItems()
    local items = {}
    
    for stepIndex, step in ipairs(repairState.procedure.steps) do
        local status = repairState.stepStatuses[stepIndex] or "pending"
        local isCompleted = (status == "completed")
        local isLocked = (stepIndex > repairState.currentStepIndex)
        
        table.insert(items, {
            label = step.label,
            disabled = isLocked or isCompleted or repairState.executingStep,
            nuiCallback = "obd:executeStep",
            callbackData = { stepIndex = stepIndex }
        })
    end
    
    table.insert(items, {
        label = "Cancel",
        nuiCallback = "obd:cancelRepair",
        callbackData = {}
    })
    
    return items
end

-- Show repair menu
function ShowRepairMenu()
    if not repairState.inProgress then
        return
    end
    
    local menuItems = BuildRepairMenuItems()
    
    TriggerScreenblurFadeOut(300)
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "obd_repair_menu",
            items = menuItems
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = "obd_repair_menu"
    StartMenuControlsThread()
end

-- Hide repair menu
function HideRepairMenu()
    if State.openPage == "menu" and State.currentMenuId == "obd_repair_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
end

-- Run progress bar with animation
function RunProgressBar(label, duration)
    duration = duration or 3000
    
    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do
        Wait(30)
    end
    
    ClearPedTasksImmediately(PlayerPedId())
    SetPedCanRagdoll(PlayerPedId(), false)
    
    local success = bridge.ProgressBar.Open({
        duration = duration,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = ANIM_DICT, clip = ANIM_CLIP, flag = 1 }
    })
    
    SetPedCanRagdoll(PlayerPedId(), true)
    
    return success == true
end

-- Execute a requirement step (open hood, turn off engine, etc.)
function ExecuteRequirementStep(vehicle, requirement)
    if requirement == "engineOff" then
        if GetIsVehicleEngineRunning(vehicle) then
            SetVehicleEngineOn(vehicle, false, true, true)
            bridge.Notify.SendNotify(t("engine_turned_off") or "Engine turned off", "success")
            Wait(500)
        end
        return true
        
    elseif requirement == "hoodOpen" then
        if GetVehicleDoorAngleRatio(vehicle, 4) < 0.1 then
            HideRepairMenu()
            
            RequestAnimDict(ANIM_DICT)
            while not HasAnimDictLoaded(ANIM_DICT) do
                Wait(30)
            end
            
            local success = bridge.ProgressBar.Open({
                duration = 2000,
                label = t("opening_hood") or "Opening hood...",
                canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = { dict = ANIM_DICT, clip = ANIM_CLIP, flag = 1 }
            })
            
            if success then
                SetVehicleDoorOpen(vehicle, 4, false, false)
                bridge.Notify.SendNotify(t("hood_opened") or "Hood opened", "success")
                Wait(300)
                return true
            else
                return false
            end
        end
        return true
    end
    
    return true
end

-- Execute a single repair step
function ExecuteRepairStep(stepIndex)
    -- Check if already executing a step
    if repairState.executingStep then
        return false, t("repair_already_executing_step") or "Already executing a step"
    end
    
    -- Check if this is the current step
    if stepIndex ~= repairState.currentStepIndex then
        return false, t("repair_not_current_step") or "Not the current step"
    end
    
    local step = repairState.procedure.steps[stepIndex]
    if not step then
        return false, t("repair_invalid_step") or "Invalid step"
    end
    
    -- Check if step already completed
    if repairState.stepStatuses[stepIndex] == "completed" then
        return false, t("repair_step_already_completed") or "Step already completed"
    end
    
    repairState.executingStep = true
    local success = false
    
    if step.type == "requirement" then
        -- Execute requirement step (open hood, turn off engine)
        success = ExecuteRequirementStep(repairState.vehicle, step.requirement)
        
        if not success then
            -- Don't show error if requirement failed, just return false
        else
            success = CheckVehicleCondition(repairState.vehicle, step.requirement)
            if not success then
                local labels = Data.RepairConfig and Data.RepairConfig.RequirementLabels or {}
                local label = labels[step.requirement] or step.label
                bridge.Notify.SendNotify(label, "error")
            end
        end
        
    elseif step.type == "progress" then
        -- Execute progress bar step
        HideRepairMenu()
        success = RunProgressBar(step.label, step.duration)
        
    elseif step.type == "minigame" then
        -- Execute timing minigame
        HideRepairMenu()
        
        if step.minigame == "timing" then
            local difficulties = { "easy", "medium", "hard" }
            local difficulty = difficulties[step.difficulty or 1] or "medium"
            local rounds = 3 + (step.difficulty or 1)
            
            success = StartKeyPressMinigame({
                rounds = rounds,
                difficulty = difficulty,
                timeLimit = 30
            })
            
            if not success then
                bridge.Notify.SendNotify(t("minigame_failed_retry") or "Failed! Try again...", "error")
                Wait(1000)
                
                success = StartKeyPressMinigame({
                    rounds = rounds,
                    difficulty = difficulty,
                    timeLimit = 30
                })
            end
        else
            success = true
        end
    else
        success = true
    end
    
    repairState.executingStep = false
    
    if success then
        -- Mark step as completed
        repairState.stepStatuses[stepIndex] = "completed"
        
        -- Check if this was the last step
        local totalSteps = #repairState.procedure.steps
        if stepIndex >= totalSteps then
            applyRepairAndFinish()
            return true, nil
        else
            repairState.currentStepIndex = stepIndex + 1
        end
    end
    
    -- Refresh the menu
    ShowRepairMenu()
    return success, nil
end

-- Apply repair effects and finish
function applyRepairAndFinish()
    local vehicle = repairState.vehicle
    local procedure = repairState.procedure
    local target = procedure.targets
    local effect = procedure.effect
    
    HideRepairMenu()
    
    local maxHealth = 1000.0
    
    if effect == "fullRepair" then
        if target == "engine" then
            SetVehicleEngineHealth(vehicle, maxHealth)
            
            -- Also fix body if it's above threshold
            if GetVehicleBodyHealth(vehicle) > 900.0 then
                SetVehicleFixed(vehicle)
            end
            
            bridge.Notify.SendNotify(t("engine_repaired") or "Engine fully repaired!", "success")
            
        elseif target == "body" then
            SetVehicleBodyHealth(vehicle, maxHealth)
            
            -- Also fix engine if it's above threshold
            if GetVehicleEngineHealth(vehicle) > 900.0 then
                SetVehicleFixed(vehicle)
            end
            
            bridge.Notify.SendNotify(t("body_repaired") or "Body fully repaired!", "success")
        end
    end
    
    -- Save repair history
    bridge.Callback.Trigger("nn_mechanic:saveRepairHistory", {
        vehiclePlate = repairState.vehiclePlate,
        vehicleVin = repairState.vehicleVin,
        vehicleModel = repairState.vehicleModel,
        repairTarget = target,
        procedureId = repairState.procedureId,
        procedureLabel = procedure.label,
        healthBefore = repairState.healthBefore,
        healthAfter = maxHealth,
        cost = 0
    })
    
    cleanupRepair()
    
    Wait(500)
    
    if RefreshOBDData then
        RefreshOBDData()
    end
end

-- Clean up repair state
function cleanupRepair()
    repairState.inProgress = false
    repairState.vehicle = nil
    repairState.vehiclePlate = nil
    repairState.vehicleVin = nil
    repairState.vehicleModel = nil
    repairState.procedureId = nil
    repairState.procedure = nil
    repairState.currentStepIndex = 1
    repairState.stepStatuses = {}
    repairState.healthBefore = nil
    repairState.executingStep = false
    
    HideRepairMenu()
end

-- Start a new OBD repair
function StartObdRepair(vehicle, procedureId)
    -- Check if a repair is already in progress
    if repairState.inProgress then
        return false, t("repair_already_in_progress") or "A repair is already in progress"
    end
    
    -- Get the repair procedure
    local procedure = GetRepairProcedure(procedureId)
    if not procedure then
        return false, t("repair_unknown_procedure") or "Unknown repair procedure"
    end
    
    -- Check distance to vehicle
    local pedPos = GetEntityCoords(PlayerPedId())
    local vehiclePos = GetEntityCoords(vehicle)
    if #(pedPos - vehiclePos) > 5.0 then
        return false, t("repair_get_closer") or "Get closer to the vehicle"
    end
    
    -- Validate that the repair is suitable for the vehicle's condition
    local isValid, errorMsg = ValidateRepairSuitability(procedure, vehicle)
    if not isValid then
        return false, errorMsg
    end
    
    -- Check for required items
    local hasItems, missingItem, missingCount = HasRequiredItems(procedure.items)
    if not hasItems then
        local message = string.format(
            t("repair_missing_item") or "Missing item: %s x%d",
            missingItem, missingCount
        )
        return false, message
    end
    
    -- Consume required items
    local consumed = ConsumeRequiredItems(procedure.items)
    if not consumed then
        return false, t("repair_failed_consume_items") or "Failed to consume required items"
    end
    
    -- Get current health for tracking
    local band, healthValue = GetVehicleHealthBand(vehicle, procedure.targets)
    
    -- Initialize repair state
    repairState.inProgress = true
    repairState.vehicle = vehicle
    repairState.vehiclePlate = GetVehicleNumberPlateText(vehicle)
    repairState.vehicleVin = GenerateVehicleVin and GenerateVehicleVin(GetEntityModel(vehicle), repairState.vehiclePlate) or nil
    repairState.vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    repairState.procedureId = procedureId
    repairState.procedure = procedure
    repairState.currentStepIndex = 1
    repairState.healthBefore = healthValue
    repairState.executingStep = false
    
    -- Initialize step statuses
    for i = 1, #procedure.steps do
        repairState.stepStatuses[i] = "pending"
    end
    
    -- Show the repair menu
    ShowRepairMenu()
    
    return true, nil
end

-- Cancel the current repair
function CancelObdRepair()
    if repairState.inProgress then
        bridge.Notify.SendNotify(t("repair_cancelled") or "Repair cancelled", "error")
        cleanupRepair()
        return true
    end
    return false
end

-- Check if a repair is in progress
function IsRepairInProgress()
    return repairState.inProgress
end

-- NUI Callbacks
RegisterNUICallback("obd:executeStep", function(data, cb)
    local stepIndex = data.stepIndex
    if not stepIndex then
        cb({ success = false, error = "No step index" })
        return
    end
    
    local success, errorMsg = ExecuteRepairStep(stepIndex)
    cb({ success = success, error = errorMsg })
end)

RegisterNUICallback("obd:cancelRepair", function(_, cb)
    CancelObdRepair()
    cb({ success = true })
end)

RegisterNUICallback("timingMinigameResult", function(_, cb)
    cb("ok")
end)

-- Monitor for requirement steps that become possible while menu is open
Citizen.CreateThread(function()
    while true do
        Wait(500)
        
        if repairState.inProgress and not repairState.executingStep then
            if State.openPage == "menu" and State.currentMenuId == "obd_repair_menu" then
                local currentStep = repairState.procedure and repairState.procedure.steps[repairState.currentStepIndex]
                if currentStep and currentStep.type == "requirement" then
                    -- Re-show menu to refresh requirement step state
                    ShowRepairMenu()
                end
            end
        end
    end
end)