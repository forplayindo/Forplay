local activeBucketPlacement = false
local currentBucketEntity = nil
local bucketPlacementThread = nil

function CreateOilChangeInstructions(instructionStates)
    if not instructionStates then
        instructionStates = {}
    end
    
    local instructions = {}
    
    local step1 = {
        title = t("attach_vehicle"),
        description = t("oil_instruction_attach_vehicle_desc"),
        completed = instructionStates[1] or false
    }
    
    local step2 = {
        title = t("oil_instruction_lift_vehicle"),
        description = t("oil_instruction_lift_vehicle_desc"),
        completed = instructionStates[2] or false
    }
    
    local step3 = {
        title = t("oil_instruction_open_oil_cap"),
        description = t("oil_instruction_open_oil_cap_desc"),
        completed = instructionStates[3] or false
    }
    
    local step4 = {
        title = t("oil_instruction_drain_oil"),
        description = t("oil_instruction_drain_oil_desc"),
        completed = instructionStates[4] or false
    }
    
    local step5 = {
        title = t("oil_instruction_lower_lift"),
        description = t("oil_instruction_lower_lift_desc"),
        completed = instructionStates[5] or false
    }
    
    local step6 = {
        title = t("oil_instruction_refill_oil"),
        description = t("oil_instruction_refill_oil_desc"),
        completed = instructionStates[6] or false
    }
    
    instructions[1] = step1
    instructions[2] = step2
    instructions[3] = step3
    instructions[4] = step4
    instructions[5] = step5
    instructions[6] = step6
    
    return instructions
end

function RevalidateOilChangeInstructions(ctx)
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange or not ctx.repairState.oilChange.inProgress then
        return
    end
    
    local lift = ctx.repairState.lift
    if lift and lift.isAttached and lift.vehicleNetId == VehToNet(ctx.vehicle) then
        CompleteInstructionStep(1)
        
        if StateInstructions.currentInstructions then
            local instructionStates = {}
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                instructionStates[i] = instruction.completed or false
            end
            SyncRepairState({ oilChange = { instructionStates = instructionStates } })
        end
    end
end

function CheckOilChangeProgress(ctx)
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange or not ctx.repairState.oilChange.inProgress then
        return
    end
    
    if not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        return
    end
    
    if not StateInstructions.currentInstructions or #StateInstructions.currentInstructions == 0 then
        if ctx.repairState.oilChange.instructionStates and #ctx.repairState.oilChange.instructionStates > 0 then
            StateInstructions.currentInstructions = CreateOilChangeInstructions(ctx.repairState.oilChange.instructionStates)
        else
            return
        end
    end
    
    local liftIndex = nil
    local lift = nil
    
    if ctx.repairState.lift and ctx.repairState.lift.liftIndex then
        liftIndex = ctx.repairState.lift.liftIndex
        if State.liftStates and State.liftStates[liftIndex] then
            lift = State.liftStates[liftIndex]
        end
    end
    
    if not lift then
        lift = ctx.repairState.lift
    end
    
    local playerPos = GetEntityCoords(PlayerPedId())
    local vehiclePos = GetEntityCoords(ctx.vehicle)
    local syncRequired = false
    local isAttached = false
    local vehicleNetId = VehToNet(ctx.vehicle)
    
    if lift and lift.isAttached and lift.vehicleNetId == vehicleNetId then
        isAttached = true
    else
        local attachedTo = GetEntityAttachedTo(ctx.vehicle)
        if attachedTo and attachedTo ~= 0 and DoesEntityExist(attachedTo) then
            for liftId, liftData in pairs(RuntimeLifts) do
                local liftEntity = GetCarLiftEntity(liftId)
                if not liftEntity and HasLiftProp(liftData) then
                    liftEntity = GetClosestObjectOfType(liftData.base.x, liftData.base.y, liftData.base.z, 10.0, GetHashKey(liftData.prop), false, false, false)
                end
                
                if liftEntity and DoesEntityExist(liftEntity) and liftEntity == attachedTo then
                    isAttached = true
                    liftIndex = liftId
                    
                    if not ctx.repairState.lift then
                        ctx.repairState.lift = {}
                    end
                    
                    ctx.repairState.lift.isAttached = true
                    ctx.repairState.lift.liftIndex = liftIndex
                    ctx.repairState.lift.vehicleNetId = vehicleNetId
                    lift = ctx.repairState.lift
                    syncRequired = true
                    break
                end
            end
        end
    end
    
    if isAttached and not IsInstructionStepCompleted(1) then
        CompleteInstructionStep(1)
        syncRequired = true
    end
    
    if IsInstructionStepCompleted(1) and playerPos.z + 1.3 <= vehiclePos.z and not IsInstructionStepCompleted(2) then
        CompleteInstructionStep(2)
        syncRequired = true
    end
    
    if IsInstructionStepCompleted(4) and lift and lift.position == "min" and not IsInstructionStepCompleted(5) then
        CompleteInstructionStep(5)
        syncRequired = true
        
        if IsInstructionStepCompleted(5) and not IsInstructionStepCompleted(6) then
            RefillOil()
        end
    end
    
    if syncRequired then
        if StateInstructions.currentInstructions then
            local instructionStates = {}
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                instructionStates[i] = instruction.completed or false
            end
            SyncRepairState({ oilChange = { instructionStates = instructionStates } })
        end
        
        if StateInstructions.currentInstructions and #StateInstructions.currentInstructions > 0 then
            SendNUIMessage({
                action = "setInstructions",
                data = StateInstructions.currentInstructions
            })
        end
    end
end

function BuildOilBoltMenuItems(ctx)
    local items = {}
    
    items[1] = {
        label = t("place_bucket"),
        icon = "fas fa-bucket",
        nuiCallback = "placeBucket",
        callbackData = {}
    }
    
    items[2] = {
        label = t("open_oil_bolt"),
        icon = "fas fa-wrench",
        nuiCallback = "openOilBolt",
        callbackData = {}
    }
    
    return items
end

function BuildRefillOilMenuItems(ctx)
    local items = {}
    
    items[1] = {
        label = t("open_hood"),
        icon = "fas fa-car-side",
        nuiCallback = "openHood",
        callbackData = {}
    }
    
    items[2] = {
        label = t("refill_oil"),
        icon = "fas fa-oil-can",
        nuiCallback = "refillOil",
        callbackData = {}
    }
    
    return items
end

function GetOilChangeMenuItems()
    if activeBucketPlacement then
        return {}
    end
    
    local pointIndex = State.currentPointCtxIndex
    if not pointIndex then
        return {}
    end
    
    local ctx = State.servicePointsCtx[pointIndex]
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange then
        return {}
    end
    
    if not ctx.repairState.oilChange.inProgress then
        return {}
    end
    
    if not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        return {}
    end
    
    local lift = ctx.repairState.lift
    if not lift then
        for _, liftState in pairs(State.liftStates or {}) do
            if liftState and liftState.isAttached and liftState.vehicleNetId == VehToNet(ctx.vehicle) then
                lift = liftState
                break
            end
        end
    end
    
    if IsInstructionStepCompleted(2) and not IsInstructionStepCompleted(3) then
        if lift and not lift.isMoving then
            return BuildOilBoltMenuItems(ctx)
        end
        return {}
    end
    
    if IsInstructionStepCompleted(5) and not IsInstructionStepCompleted(6) then
        return BuildRefillOilMenuItems(ctx)
    end
    
    return {}
end

function SyncInstallFlowUI()
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    end
end

function CanShowOilBoltMenu()
    if activeBucketPlacement then
        return false
    end
    
    local pointIndex = State.currentPointCtxIndex
    if not pointIndex then
        return false
    end
    
    local ctx = State.servicePointsCtx[pointIndex]
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange or not ctx.repairState.oilChange.inProgress then
        return false
    end
    
    if not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        return false
    end
    
    local lift = ctx.repairState.lift
    if lift and lift.isAttached and lift.vehicleNetId == VehToNet(ctx.vehicle) then
        if IsInstructionStepCompleted(2) and not IsInstructionStepCompleted(3) then
            if not lift.isMoving then
                return true
            end
        end
    end
    
    return false
end

function HideOilBoltMenu()
    if InstallFlow and InstallFlow.IsActive() then
        if State.openPage == "menu" and State.currentMenuId == "install_flow_menu" then
            SendNUIMessage({
                action = "setVisibility",
                data = { visible = false, page = "menu" }
            })
            State.openPage = nil
            State.currentMenuId = nil
        end
    end
end

function CheckAndShowOilBoltMenu()
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    end
end

function SyncAfterMinigame(ctx)
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    end
end

function HideServiceMenuOnComplete()
    if InstallFlow and InstallFlow.IsActive() then
        if State.openPage == "menu" and State.currentMenuId == "install_flow_menu" then
            SendNUIMessage({
                action = "setVisibility",
                data = { visible = false, page = "menu" }
            })
            State.openPage = nil
            State.currentMenuId = nil
        end
    end
end

function RefillOil()
    local pointIndex = State.currentPointCtxIndex
    if not pointIndex then
        return
    end
    
    local ctx = State.servicePointsCtx[pointIndex]
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange or not ctx.repairState.oilChange.inProgress then
        return
    end
    
    if not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        return
    end
    
    SyncAfterMinigame(ctx)
end

RegisterNUICallback("openHood", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    if not pointIndex then
        return
    end
    
    local ctx = State.servicePointsCtx[pointIndex]
    if not ctx or not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        return
    end
    
    local vehicleCoords = GetEntityCoords(ctx.vehicle)
    
    DetachEntity(ctx.vehicle, true, true)
    SetEntityCoords(ctx.vehicle, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z)
    FreezeEntityPosition(ctx.vehicle, true)
    Wait(500)
    SetVehicleDoorOpen(ctx.vehicle, 4, false, false)
    
    cb({ success = true })
end)

RegisterNUICallback("refillOil", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    local ctx = State.servicePointsCtx[pointIndex]
    
    if not ctx or not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found_for_oil_change"), "error")
        cb({ success = false })
        return
    end
    
    local requiredOilType = ctx.repairState and ctx.repairState.oilChange and ctx.repairState.oilChange.requiredOilType
    
    if not requiredOilType then
        bridge.Notify.SendNotify(t("no_vehicle_found_for_oil_change"), "error")
        cb({ success = false })
        return
    end
    
    local hasOil = bridge.Callback.Trigger("nn_mechanic:hasOilType", requiredOilType)
    if not hasOil then
        local msg = t("oil_type_required") or "You need the correct oil type for this vehicle"
        bridge.Notify.SendNotify(msg, "error")
        cb({ success = false })
        return
    end
    
    HideServiceMenuOnComplete()
    Wait(500)
    TriggerScreenblurFadeIn(500)
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "fluid-minigame" }
    })
    
    State.openPage = "fluid-minigame"
    cb({ success = true })
end)

function CreateOilCanProp()
    local propHash = GetHashKey("v_ind_cs_oiltub")
    RequestModel(propHash)
    
    while not HasModelLoaded(propHash) do
        Wait(100)
    end
    
    local offsetX, offsetY, offsetZ = 0.1, 0.0, 0.1
    local rotX, rotY, rotZ = 364.0, 180.0, 90.0
    
    local prop = CreateObject(propHash, GetEntityCoords(PlayerPedId()), true, true, false)
    AttachEntityToEntity(prop, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 60309), 
                         offsetX, -offsetY, offsetZ, rotX, rotY, rotZ, true, true, false, true, 2, true)
    
    TaskPlayAnim(PlayerPedId(), "weapons@misc@jerrycan@", "fire", 8.0, -8.0, -1, 49, 0, false, false, false)
    
    return prop
end

RegisterNUICallback("FluidRefillResult", function(data, cb)
    if State.openPage ~= "fluid-minigame" then
        cb({ success = false, error = "not_in_minigame" })
        return
    end
    
    local success = data.success
    
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "fluid-minigame" }
    })
    
    State.openPage = nil
    
    if not success then
        Citizen.CreateThread(function()
            Wait(500)
            
            local pointIndex = State.currentPointCtxIndex
            if not pointIndex then
                return
            end
            
            local ctx = State.servicePointsCtx[pointIndex]
            if ctx and ctx.repairState and ctx.repairState.oilChange and ctx.repairState.oilChange.inProgress then
                if ctx.repairState.menus then
                    ctx.repairState.menus.refillOilMenu = false
                end
                RefillOil()
            end
        end)
        
        cb({ success = false })
        return
    end
    
    local pointIndex = State.currentPointCtxIndex
    local ctx = State.servicePointsCtx[pointIndex]
    
    if not ctx or not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found_for_oil_change"), "error")
        cb({ success = false })
        return
    end
    
    local requiredOilType = ctx.repairState and ctx.repairState.oilChange and ctx.repairState.oilChange.requiredOilType
    
    if not requiredOilType then
        bridge.Notify.SendNotify(t("no_vehicle_found_for_oil_change"), "error")
        cb({ success = false })
        return
    end
    
    local oilProp = CreateOilCanProp()
    
    bridge.ProgressBar.Open({
        duration = 8000,
        label = t("refilling_oil"),
        canCancel = false,
        disable = { move = true, combat = true },
        anim = { dict = "weapons@misc@jerrycan@", clip = "fire", flag = 49 }
    }, function(completed)
        ClearPedTasksImmediately(State.Ped)
        DeleteEntity(oilProp)
        
        if completed then
            local oilItemKey = "mechanic_oil_" .. requiredOilType:lower()
            TriggerServerEvent("nn_mechanic:removeOilItem", oilItemKey)
            
            local vehicleNetId = VehToNet(ctx.vehicle)
            TriggerServerEvent("nn_mechanic:changeOilForVehicle", vehicleNetId)
            
            CompleteInstructionStep(6)
            
            if StateInstructions.currentInstructions then
                local instructionStates = {}
                for i, instruction in ipairs(StateInstructions.currentInstructions) do
                    instructionStates[i] = instruction.completed or false
                end
                
                SyncRepairState({
                    oilChange = {
                        instructionStates = instructionStates,
                        inProgress = false
                    },
                    menus = { refillOilMenu = false }
                })
            end
            
            SetVehicleDoorShut(ctx.vehicle, 4, false)
            FreezeEntityPosition(ctx.vehicle, false)
            
            HideServiceMenuOnComplete()
            CloseInstructions()
            
            bridge.Notify.SendNotify(t("oil_change_completed"), "success")
            
            if InstallFlow and InstallFlow.IsActive() then
                InstallFlow.SyncUI()
            end
        end
    end)
    
    cb({ success = true })
end)

RegisterNUICallback("changeOil", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    if not pointIndex then
        cb({ success = false })
        return
    end
    
    local ctx = State.servicePointsCtx[pointIndex]
    if not ctx or not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        cb({ success = false })
        return
    end
    
    local vehicle = ctx.vehicle
    local vehicleClass = GetVehicleClass(vehicle)
    local requiredOilType = Config.OilClasses[vehicleClass]
    
    if not requiredOilType then
        bridge.Notify.SendNotify(t("wrong_oil_type"), "error")
        cb({ success = false })
        return
    end
    
    if requiredOilType == "none" then
        bridge.Notify.SendNotify(t("this_vehicle_does_not_require_oil_changes"), "error")
        cb({ success = false })
        return
    end
    
    local hasOil = bridge.Callback.Trigger("nn_mechanic:hasOilType", requiredOilType)
    if not hasOil then
        bridge.Notify.SendNotify(t("no_oil_in_inventory"), "error")
        cb({ success = false })
        return
    end
    
    local instructions = CreateOilChangeInstructions()
    OpenInstructions(instructions)
    
    SyncRepairState({
        oilChange = {
            inProgress = true,
            requiredOilType = requiredOilType,
            bucketPlaced = false,
            oilBoltOpen = false,
            oilDraining = false,
            particleActive = false
        }
    })
    
    RevalidateOilChangeInstructions(ctx)
    
    if InstallFlow and InstallFlow.Start then
        if not InstallFlow.IsActive() then
            InstallFlow.Start(InstallRecipes.oil_change({}), { vehicle = ctx.vehicle, ctxIndex = pointIndex })
        end
    else
        Citizen.CreateThread(function()
            Wait(500)
            if IsInstructionStepCompleted(2) and not IsInstructionStepCompleted(3) then
                CheckAndShowOilBoltMenu()
            end
        end)
    end
    
    cb({ success = true })
end)

RegisterNUICallback("openOilBolt", function(data, cb)
    local pointIndex = State.currentPointCtxIndex
    local ctx = State.servicePointsCtx[pointIndex]
    
    if not ctx or not ctx.repairState or not ctx.repairState.oilChange or not ctx.repairState.oilChange.bucketPlaced then
        bridge.Notify.SendNotify(t("bucket_must_be_placed_first"), "error")
        cb({ success = false })
        return
    end
    
    ctx = State.servicePointsCtx[State.currentPointCtxIndex]
    if not ctx or not ctx.vehicle or not DoesEntityExist(ctx.vehicle) then
        cb({ success = false })
        return
    end
    
    local vehiclePos = GetEntityCoords(ctx.vehicle)
    local playerPos = GetEntityCoords(State.Ped)
    
    local distance = math.sqrt((vehiclePos.x - playerPos.x)^2 + (vehiclePos.y - playerPos.y)^2)
    
    if distance > 1.5 then
        bridge.Notify.SendNotify(t("not_under_vehicle"), "error")
        cb({ success = false })
        return
    end
    
    bridge.ProgressBar.Open({
        duration = 4000,
        label = t("opening_oil_bolt"),
        canCancel = false,
        disable = { move = true, combat = true },
        anim = { dict = "amb@prop_human_movie_bulb@idle_a", clip = "idle_a", flag = 49 }
    }, function(completed)
        if completed then
            local vehicleCoords = GetEntityCoords(ctx.vehicle)
            TriggerServerEvent("nn_mechanic:startOilParticle", VehToNet(ctx.vehicle), vehicleCoords)
            
            CompleteInstructionStep(3)
            
            if StateInstructions.currentInstructions then
                local instructionStates = {}
                for i, instruction in ipairs(StateInstructions.currentInstructions) do
                    instructionStates[i] = instruction.completed or false
                end
                SyncRepairState({ oilChange = { instructionStates = instructionStates } })
            end
            
            HideOilBoltMenu()
            HideServiceMenuOnComplete()
            
            bridge.ProgressBar.Open({
                duration = 10000,
                label = t("oil_draining"),
                canCancel = false,
                disable = { move = false, combat = false }
            }, function(drainingCompleted)
                if drainingCompleted then
                    TriggerServerEvent("nn_mechanic:stopOilParticle", VehToNet(ctx.vehicle))
                    CompleteInstructionStep(4)
                    
                    if StateInstructions.currentInstructions then
                        local instructionStates = {}
                        for i, instruction in ipairs(StateInstructions.currentInstructions) do
                            instructionStates[i] = instruction.completed or false
                        end
                        SyncRepairState({ oilChange = { instructionStates = instructionStates } })
                    end
                    
                    bridge.Notify.SendNotify(t("oil_draining_completed"), "success")
                    
                    if currentBucketEntity and DoesEntityExist(currentBucketEntity) then
                        DeleteEntity(currentBucketEntity)
                        currentBucketEntity = nil
                    end
                    
                    State.openPage = nil
                    State.currentMenuId = nil
                    ShowInstructionsIfExists()
                end
            -- })
            end)
        end
    end)
    
    cb({ success = true })
end)

RegisterNUICallback("placeBucket", function(data, cb)
    if activeBucketPlacement then
        cb({ success = false })
        return
    end
    
    local pointIndex = State.currentPointCtxIndex
    local ctx = State.servicePointsCtx[pointIndex]
    
    if not ctx or not ctx.vehicle then
        bridge.Notify.SendNotify(t("no_vehicle_found_for_oil_change"), "error")
        cb({ success = false })
        return
    end
    
    local vehiclePos = GetEntityCoords(ctx.vehicle)
    local _, groundZ = GetGroundZFor_3dCoord(vehiclePos.x, vehiclePos.y, vehiclePos.z, true)
    
    if not groundZ then
        bridge.Notify.SendNotify("No ground found", "error")
        cb({ success = false })
        return
    end
    
    local groundPos = vector3(vehiclePos.x, vehiclePos.y, groundZ)
    local bucketHash = GetHashKey("prop_bucket_02a")
    
    RequestModel(bucketHash)
    while not HasModelLoaded(bucketHash) do
        Wait(100)
    end
    
    local angle = math.random() * 2 * math.pi
    local radius = 0.5 + math.random() * 1.0
    
    local bucketX = groundPos.x + math.cos(angle) * radius
    local bucketY = groundPos.y + math.sin(angle) * radius
    local bucketZ = groundZ + 0.1
    
    currentBucketEntity = CreateObject(bucketHash, bucketX, bucketY, bucketZ, true, true, false)
    PlaceObjectOnGroundProperly(currentBucketEntity)
    SetEntityCollision(currentBucketEntity, false, false)
    FreezeEntityPosition(currentBucketEntity, false)
    
    activeBucketPlacement = true
    
    HideOilBoltMenu()
    
    bucketPlacementThread = Citizen.CreateThread(function()
        local targetRadius = 0.25
        local moveSpeed = 0.01
        local isInMarker = false
        
        while activeBucketPlacement and currentBucketEntity and DoesEntityExist(currentBucketEntity) do
            local bucketPos = GetEntityCoords(currentBucketEntity)
            local targetPos = vector3(groundPos.x, groundPos.y, groundPos.z)
            local distanceToTarget = #(bucketPos - targetPos)
            
            isInMarker = targetRadius >= distanceToTarget
            
            local markerColor = isInMarker and {0, 255, 0, 100} or {255, 0, 0, 100}
            
            DrawMarker(1, groundPos.x, groundPos.y, groundPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                      targetRadius * 2, targetRadius * 2, 0.1, 
                      markerColor[1], markerColor[2], markerColor[3], markerColor[4], 
                      false, false, 2, false, nil, nil, false)
            
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 191, true)
            
            local moved = false
            
            if IsDisabledControlPressed(0, 172) then
                SetEntityCoords(currentBucketEntity, bucketPos.x, bucketPos.y + moveSpeed, bucketPos.z, false, false, false, false)
                moved = true
            end
            if IsDisabledControlPressed(0, 173) then
                SetEntityCoords(currentBucketEntity, bucketPos.x, bucketPos.y - moveSpeed, bucketPos.z, false, false, false, false)
                moved = true
            end
            if IsDisabledControlPressed(0, 174) then
                SetEntityCoords(currentBucketEntity, bucketPos.x - moveSpeed, bucketPos.y, bucketPos.z, false, false, false, false)
                moved = true
            end
            if IsDisabledControlPressed(0, 175) then
                SetEntityCoords(currentBucketEntity, bucketPos.x + moveSpeed, bucketPos.y, bucketPos.z, false, false, false, false)
                moved = true
            end
            
            if moved then
                bucketPos = GetEntityCoords(currentBucketEntity)
            end
            
            if IsDisabledControlJustPressed(0, 191) then
                if isInMarker then
                    SetEntityCollision(currentBucketEntity, true, true)
                    FreezeEntityPosition(currentBucketEntity, true)
                    activeBucketPlacement = false
                    
                    SyncRepairState({ oilChange = { bucketPlaced = true } })
                    bridge.Notify.SendNotify(t("bucket_placed_successfully"), "success")
                    Wait(100)
                    CheckAndShowOilBoltMenu()
                    break
                else
                    bridge.Notify.SendNotify(t("move_bucket_inside_marker"), "error")
                end
            end
            
            local newBucketPos = GetEntityCoords(currentBucketEntity)
            local _, newGroundZ = GetGroundZFor_3dCoord(newBucketPos.x, newBucketPos.y, newBucketPos.z + 1.0, true)
            
            if newGroundZ then
                SetEntityCoords(currentBucketEntity, newBucketPos.x, newBucketPos.y, newGroundZ + 0.05, false, false, false, false)
            end
            
            Wait(0)
        end
        
        currentBucketEntity = nil
        bucketPlacementThread = nil
    end)
    
    cb({ success = true })
end)

local activeParticles = {}

RegisterNetEvent("nn_mechanic:startOilParticle")
AddEventHandler("nn_mechanic:startOilParticle", function(vehicleNetId, position)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or not DoesEntityExist(vehicle) then
        return
    end
    
    if activeParticles[vehicleNetId] then
        bridge.Particle.Stop(activeParticles[vehicleNetId])
        activeParticles[vehicleNetId] = nil
    end
    
    activeParticles[vehicleNetId] = bridge.Particle.CreateOnEntity(
        "core", "veh_oil_slick", vehicle, 
        vector3(0.0, 0.0, -0.1), 
        vector3(0.0, 0.0, 0.0), 
        0.5, 
        vector3(100, 100, 100), 
        true
    )
end)

RegisterNetEvent("nn_mechanic:stopOilParticle")
AddEventHandler("nn_mechanic:stopOilParticle", function(vehicleNetId)
    if activeParticles[vehicleNetId] then
        bridge.Particle.Stop(activeParticles[vehicleNetId])
        activeParticles[vehicleNetId] = nil
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, particle in pairs(activeParticles) do
            if particle then
                bridge.Particle.Stop(particle)
            end
        end
        activeParticles = {}
        
        if currentBucketEntity and DoesEntityExist(currentBucketEntity) then
            DeleteEntity(currentBucketEntity)
        end
        
        activeBucketPlacement = false
    end
end)