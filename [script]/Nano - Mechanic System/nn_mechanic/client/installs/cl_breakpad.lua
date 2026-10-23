local WHEEL_INDICES = {}
WHEEL_INDICES.wheel_rf = 1
WHEEL_INDICES.wheel_lf = 0
WHEEL_INDICES.wheel_lr = 2
WHEEL_INDICES.wheel_rr = 3

local function CreateBrakePadInstructions(axis, instructionStates)
    instructionStates = instructionStates or {}

    local axisDisplayName
    if axis == "front" then
        axisDisplayName = t("front")
    else
        axisDisplayName = t("rear")
    end

    local instructions = {}

    local step1 = {}
    step1.title = t("brake_instruction_attach_vehicle")
    step1.description = t("brake_instruction_attach_vehicle_desc")
    step1.completed = instructionStates[1] or false

    local step2 = {}
    step2.title = t("brake_instruction_lift_vehicle")
    step2.description = t("brake_instruction_lift_vehicle_desc")
    step2.completed = instructionStates[2] or false

    local step3 = {}
    step3.title = t("brake_instruction_remove_wheels")
    step3.description = string.format(t("brake_instruction_remove_wheels_desc"), axisDisplayName)
    step3.completed = instructionStates[3] or false

    local step4 = {}
    step4.title = t("brake_instruction_install_pads")
    step4.description = string.format(t("brake_instruction_install_pads_desc"), axisDisplayName)
    step4.completed = instructionStates[4] or false

    local step5 = {}
    step5.title = t("brake_instruction_install_wheels")
    step5.description = string.format(t("brake_instruction_install_wheels_desc"), axisDisplayName)
    step5.completed = instructionStates[5] or false

    local step6 = {}
    step6.title = t("brake_instruction_lower_vehicle")
    step6.description = t("brake_instruction_lower_vehicle_desc")
    step6.completed = instructionStates[6] or false

    instructions[1] = step1
    instructions[2] = step2
    instructions[3] = step3
    instructions[4] = step4
    instructions[5] = step5
    instructions[6] = step6

    return instructions
end

local function GetWheelBoneNamesForAxis(axis)
    local wheelBoneNames = {}
    if axis == "front" then
        wheelBoneNames[1] = "wheel_lf"
        wheelBoneNames[2] = "wheel_rf"
        return wheelBoneNames
    else
        wheelBoneNames[1] = "wheel_lr"
        wheelBoneNames[2] = "wheel_rr"
        return wheelBoneNames
    end
end

local function GetVehicleWheelXOffsetsForAxis(vehicle, axis)
    local wheelBoneNames = GetWheelBoneNamesForAxis(axis)
    local offsets = {}

    for _, wheelBoneName in ipairs(wheelBoneNames) do
        local wheelIndex = WHEEL_INDICES[wheelBoneName]
        local offset = GetVehicleWheelXOffset(vehicle, wheelIndex)
        offsets[wheelBoneName] = offset
    end
    return offsets
end

local function SetVehicleWheelXOffsetsForAxis(vehicle, axis, offsets)
    local wheelBoneNames = GetWheelBoneNamesForAxis(axis)
    local wheelOffsetsToSet = {}

    for _, wheelBoneName in ipairs(wheelBoneNames) do
        local wheelIndex = WHEEL_INDICES[wheelBoneName]
        local offset = 0
        if offsets and offsets[wheelBoneName] then
            offset = offsets[wheelBoneName]
        end
        wheelOffsetsToSet[wheelIndex] = offset
    end
    SetVehicleWheelXOffsetsSynced(vehicle, wheelOffsetsToSet)
end

local function RevalidateBrakePadInstructions(servicePointCtx)
    if not servicePointCtx or not servicePointCtx.repairState or not servicePointCtx.repairState.brakes or not servicePointCtx.repairState.brakes.inProgress then
        return
    end

    if not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        return
    end

    if not StateInstructions.currentInstructions or #StateInstructions.currentInstructions == 0 then
        local axis = servicePointCtx.repairState.brakes.axis or "front"
        local instructionStates = servicePointCtx.repairState.brakes.instructionStates
        if instructionStates and #instructionStates > 0 then
            StateInstructions.currentInstructions = CreateBrakePadInstructions(axis, instructionStates)
        else
            return
        end
    end

    local liftState = nil
    local liftIndex = servicePointCtx.repairState.lift and servicePointCtx.repairState.lift.liftIndex
    if liftIndex and State.liftStates and State.liftStates[liftIndex] then
        liftState = State.liftStates[liftIndex]
    end
    liftState = liftState or servicePointCtx.repairState.lift

    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleCoords = GetEntityCoords(servicePointCtx.vehicle)
    local vehicleNetId = VehToNet(servicePointCtx.vehicle)

    local hasStateChanged = false
    local isAttachedToLift = false

    if liftState and liftState.isAttached and liftState.vehicleNetId == vehicleNetId then
        isAttachedToLift = true
    else
        local attachedEntity = GetEntityAttachedTo(servicePointCtx.vehicle)
        if attachedEntity and attachedEntity ~= 0 and DoesEntityExist(attachedEntity) then
            for liftId, liftData in pairs(RuntimeLifts) do
                local liftPropEntity = GetCarLiftEntity(liftId)
                if not liftPropEntity and HasLiftProp(liftData) then
                    liftPropEntity = GetClosestObjectOfType(liftData.base.x, liftData.base.y, liftData.base.z, 10.0, GetHashKey(liftData.prop), false, false, false)
                end

                if liftPropEntity and DoesEntityExist(liftPropEntity) and liftPropEntity == attachedEntity then
                    isAttachedToLift = true
                    liftIndex = liftId
                    servicePointCtx.repairState.lift = servicePointCtx.repairState.lift or {}
                    servicePointCtx.repairState.lift.isAttached = true
                    servicePointCtx.repairState.lift.liftIndex = liftId
                    servicePointCtx.repairState.lift.vehicleNetId = vehicleNetId
                    liftState = servicePointCtx.repairState.lift
                    hasStateChanged = true
                    break
                end
            end
        end
    end

    if isAttachedToLift and not IsInstructionStepCompleted(1) then
        CompleteInstructionStep(1)
        hasStateChanged = true
    end

    if IsInstructionStepCompleted(1) and playerCoords.z <= vehicleCoords.z and not IsInstructionStepCompleted(2) then
        CompleteInstructionStep(2)
        hasStateChanged = true
    end

    if IsInstructionStepCompleted(5) and liftState and liftState.position == "min" and not IsInstructionStepCompleted(6) then
        CompleteInstructionStep(6)
        hasStateChanged = true
    end

    if hasStateChanged then
        local instructionCompletionStates = {}
        if StateInstructions.currentInstructions then
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                instructionCompletionStates[i] = instruction.completed or false
            end
        end

        SyncRepairState({
            brakes = {
                instructionStates = instructionCompletionStates
            }
        })

        if StateInstructions.currentInstructions and #StateInstructions.currentInstructions > 0 then
            SendNUIMessage({
                action = "setInstructions",
                data = StateInstructions.currentInstructions
            })
        end
    end
end

RegisterNUICallback("checkBrakes", function(requestData, cb)
    local servicePointCtx = nil
    local currentPointCtxIndex = State.currentPointCtxIndex
    if currentPointCtxIndex then
        servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    end

    if not servicePointCtx or not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        cb({ success = false })
        return
    end

    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)

    local progressBarSuccess = bridge.ProgressBar.Open({
        duration = 5000,
        label = t("checking_brakes"),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer", flag = 1 }
    })

    if not progressBarSuccess then
        bridge.Notify.SendNotify(t("brake_check_cancelled"), "error")
        SetPedCanRagdoll(State.Ped, true)
        cb({ success = false })
        return
    end

    local vehiclePlate = GetVehicleNumberPlateText(servicePointCtx.vehicle)
    local playerId = PlayerId()
    local playerName, playerServerId = bridge.Framework.GetPlayerName(playerId)
    local fullPlayerName = playerName .. " " .. playerServerId

    local brakePadData = bridge.Callback.Trigger("nn_mechanic:getBrakePadData", vehiclePlate)

    if not brakePadData then
        bridge.Notify.SendNotify(t("brake_check_failed"), "error")
        SetPedCanRagdoll(State.Ped, true)
        cb({ success = false })
        return
    end

    if not servicePointCtx.employeeName then
        servicePointCtx.employeeName = fullPlayerName
    end

    local shouldReinitializeInspectionData = true
    if servicePointCtx.inspectionData and servicePointCtx.inspectionData.vehiclePlate == vehiclePlate then
        shouldReinitializeInspectionData = false
    end

    if shouldReinitializeInspectionData then
        local vehicleModelHash = GetEntityModel(servicePointCtx.vehicle)
        local vehicleModelName = GetDisplayNameFromVehicleModel(vehicleModelHash)
        servicePointCtx.inspectionData = {
            vehiclePlate = vehiclePlate,
            vehicleModel = vehicleModelName,
            tires = {},
            brakes = nil
        }
    end

    servicePointCtx.inspectionData.brakes = {
        front = brakePadData.front,
        rear = brakePadData.rear
    }

    if servicePointCtx.vehicle and not servicePointCtx.vehicleNetId then
        servicePointCtx.vehicleNetId = VehToNet(servicePointCtx.vehicle)
    end

    local servicePointCtxData = {
        vehicleNetId = servicePointCtx.vehicleNetId,
        pointId = servicePointCtx.pointId,
        shopId = servicePointCtx.shopId,
        inspectionData = servicePointCtx.inspectionData,
        employeeName = servicePointCtx.employeeName
    }

    TriggerServerEvent("nn_mechanic:setServicePointCtx", servicePointCtx.shopId, servicePointCtx.pointId, servicePointCtxData)

    State.servicePointsCtx[currentPointCtxIndex] = servicePointCtx

    SendNUIMessage({
        action = "setNotepadData",
        data = {
            type = "fullInspection",
            inspectionData = servicePointCtx.inspectionData,
            employeeName = servicePointCtx.employeeName
        }
    })

    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "notepad" }
    })

    State.openPage = "notepad"
    SetPedCanRagdoll(State.Ped, true)
    cb({ success = true })
end)

RegisterNUICallback("changeBrakePads", function(requestData, cb)
    local servicePointCtx = nil
    local currentPointCtxIndex = State.currentPointCtxIndex
    if currentPointCtxIndex then
        servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    end

    if not servicePointCtx or not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        cb({ success = false })
        return
    end

    local axis = requestData.axis
    if not axis or (axis ~= "front" and axis ~= "rear") then
        bridge.Notify.SendNotify(t("invalid_axis"), "error")
        cb({ success = false })
        return
    end

    local repairState = servicePointCtx.repairState
    if repairState then
        if repairState.oilChange and repairState.oilChange.inProgress then
            bridge.Notify.SendNotify(t("repair_in_progress"), "error")
            cb({ success = false })
            return
        end
        if repairState.brakes and repairState.brakes.inProgress then
            bridge.Notify.SendNotify(t("brake_job_in_progress"), "error")
            cb({ success = false })
            return
        end
    end

    local vehicleClass = GetVehicleClass(servicePointCtx.vehicle)
    local requiredPadType = Config.BreakpadsClasses[vehicleClass] or "basic"

    local hasItem = bridge.Callback.Trigger("nn_mechanic:hasBrakePadItem", requiredPadType)
    if not hasItem then
        bridge.Notify.SendNotify(string.format(t("no_brake_pads_item"), requiredPadType), "error")
        cb({ success = false })
        return
    end

    if not servicePointCtx.repairState then
        servicePointCtx.repairState = CreateRepairState()
    end

    local currentWheelOffsets = GetVehicleWheelXOffsetsForAxis(servicePointCtx.vehicle, axis)

    local brakeRepairState = {
        inProgress = true,
        axis = axis,
        requiredPadType = requiredPadType,
        instructionStates = {},
        wheelsRemoved = false,
        padsInstalled = false,
        wheelsReinstalled = false
    }

    if axis == "front" and currentWheelOffsets then
        brakeRepairState.frontWheelOffsets = currentWheelOffsets
    end
    if axis == "rear" and currentWheelOffsets then
        brakeRepairState.rearWheelOffsets = currentWheelOffsets
    end

    servicePointCtx.repairState.brakes = brakeRepairState

    local instructions = CreateBrakePadInstructions(axis, {})
    OpenInstructions(instructions)

    if State.openPage == "menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
    end

    local instructionCompletionStates = {}
    for i, instruction in ipairs(instructions) do
        instructionCompletionStates[i] = instruction.completed or false
    end

    SyncRepairState({
        brakes = {
            inProgress = true,
            axis = axis,
            requiredPadType = requiredPadType,
            instructionStates = instructionCompletionStates,
            wheelsRemoved = false,
            padsInstalled = false,
            wheelsReinstalled = false,
            frontWheelOffsets = (axis == "front" and currentWheelOffsets) or nil,
            rearWheelOffsets = (axis == "rear" and currentWheelOffsets) or nil
        }
    })

    RevalidateBrakePadInstructions(servicePointCtx)

    if InstallFlow and InstallFlow.Start and not InstallFlow.IsActive() then
        local installRecipe = InstallRecipes.brake_pad({})
        InstallFlow.Start(installRecipe, {
            vehicle = servicePointCtx.vehicle,
            ctxIndex = State.currentPointCtxIndex
        })
    else
        Citizen.CreateThread(function()
            Wait(500)
            if IsInstructionStepCompleted(2) and not IsInstructionStepCompleted(5) then
                CheckAndShowBrakePadMenu()
            end
        end)
    end

    cb({ success = true })
end)

local function GetWheelBoneNameForAxisAndSide(axis, side)
    local wheelBoneName
    if axis == "front" then
        if side == "left" then
            wheelBoneName = "wheel_lf"
        else
            wheelBoneName = "wheel_rf"
        end
    else
        if side == "left" then
            wheelBoneName = "wheel_lr"
        else
            wheelBoneName = "wheel_rr"
        end
    end
    return wheelBoneName
end

local function GetVehicleWheelBonePositionsForAxis(vehicle, axis)
    local wheelBoneNames = GetWheelBoneNamesForAxis(axis)
    local bonePositions = {}

    for _, wheelBoneName in ipairs(wheelBoneNames) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, wheelBoneName)
        if boneIndex ~= -1 then
            local position = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            bonePositions[wheelBoneName] = {
                x = position.x,
                y = position.y,
                z = position.z
            }
        end
    end
    return bonePositions
end

local function IsPlayerNearWheelBone(vehicle, wheelBoneName, distanceThreshold, precomputedBonePositions)
    distanceThreshold = distanceThreshold or 1.5
    local playerCoords = GetEntityCoords(PlayerPedId())

    local targetBonePosition
    if precomputedBonePositions and precomputedBonePositions[wheelBoneName] then
        local pos = precomputedBonePositions[wheelBoneName]
        targetBonePosition = vector3(pos.x, pos.y, pos.z)
    else
        local boneIndex = GetEntityBoneIndexByName(vehicle, wheelBoneName)
        if boneIndex == -1 then
            return false
        end
        targetBonePosition = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    end

    local distance = #(targetBonePosition - playerCoords)
    return distanceThreshold >= distance
end

RegisterNUICallback("removeBrakeWheel", function(requestData, cb)
    local servicePointCtx = nil
    local currentPointCtxIndex = State.currentPointCtxIndex
    if currentPointCtxIndex then
        servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    end

    if not servicePointCtx or not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        cb({ success = false })
        return
    end

    if not servicePointCtx.repairState or not servicePointCtx.repairState.brakes or not servicePointCtx.repairState.brakes.inProgress then
        cb({ success = false })
        return
    end

    if not IsInstructionStepCompleted(2) then
        bridge.Notify.SendNotify(t("lift_vehicle_first"), "error")
        cb({ success = false })
        return
    end

    local brakeState = servicePointCtx.repairState.brakes
    local axis = brakeState.axis
    local side = requestData.side
    if not side or (side ~= "left" and side ~= "right") then
        cb({ success = false })
        return
    end

    local wheelBoneName = GetWheelBoneNameForAxisAndSide(axis, side)

    if not IsPlayerNearWheelBone(servicePointCtx.vehicle, wheelBoneName, 2.0) then
        bridge.Notify.SendNotify(t("go_to_wheel_first"), "error")
        cb({ success = false })
        return
    end

    brakeState.removedWheelSides = brakeState.removedWheelSides or {}
    if brakeState.removedWheelSides[side] then
        bridge.Notify.SendNotify(t("wheel_already_removed"), "error")
        cb({ success = false })
        return
    end

    if axis == "front" then
        if not brakeState.frontWheelBonePositions then
            brakeState.frontWheelOffsets = GetVehicleWheelXOffsetsForAxis(servicePointCtx.vehicle, axis)
            brakeState.frontWheelBonePositions = GetVehicleWheelBonePositionsForAxis(servicePointCtx.vehicle, axis)
        end
    elseif axis == "rear" then
        if not brakeState.rearWheelBonePositions then
            brakeState.rearWheelOffsets = GetVehicleWheelXOffsetsForAxis(servicePointCtx.vehicle, axis)
            brakeState.rearWheelBonePositions = GetVehicleWheelBonePositionsForAxis(servicePointCtx.vehicle, axis)
        end
    end

    HideBrakePadMenu()

    local wheelBoneConfig = boneConfig[wheelBoneName]
    if not wheelBoneConfig or not wheelBoneConfig.boltOffsets then
        bridge.Notify.SendNotify(t("wheel_config_error"), "error")
        cb({ success = false })
        return
    end

    State.disableControls = true
    DisableControls()
    StartMechanicAlphaAnim(State.Ped)
    bridge.Target.RemoveLocalEntity(servicePointCtx.vehicle)

    local boltEntities = PlaceBolts(servicePointCtx.vehicle, wheelBoneName, wheelBoneConfig.boltOffsets, wheelBoneConfig.boltRotations, true)
    StartBoltMinigame(boltEntities, wheelBoneName)

    SetEntityVisible(State.Ped, true)
    ClearMechanicAlphaAnim(State.Ped)
    State.disableControls = false

    local wheelIndex = WHEEL_INDICES[wheelBoneName]
    SetVehicleWheelXOffsetsSynced(servicePointCtx.vehicle, { [wheelIndex] = -999 })

    brakeState.removedWheelSides[side] = true
    local allWheelsRemoved = brakeState.removedWheelSides.left and brakeState.removedWheelSides.right
    if allWheelsRemoved then
        brakeState.wheelsRemoved = true
        CompleteInstructionStep(3)
    end

    local instructionCompletionStates = {}
    if StateInstructions.currentInstructions then
        for i, instruction in ipairs(StateInstructions.currentInstructions) do
            instructionCompletionStates[i] = instruction.completed or false
        end
    end

    SyncRepairState({
        brakes = {
            removedWheelSides = brakeState.removedWheelSides,
            wheelsRemoved = allWheelsRemoved,
            instructionStates = instructionCompletionStates,
            frontWheelOffsets = brakeState.frontWheelOffsets,
            rearWheelOffsets = brakeState.rearWheelOffsets,
            frontWheelBonePositions = brakeState.frontWheelBonePositions,
            rearWheelBonePositions = brakeState.rearWheelBonePositions
        }
    })

    bridge.Notify.SendNotify(t("wheel_removed_successfully"), "success")
    Wait(500)

    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    else
        ShowBrakePadMenu(servicePointCtx)
    end

    cb({ success = true })
end)

local function BuildBrakePadMenuItems(servicePointCtx)
    if not servicePointCtx or not servicePointCtx.repairState or not servicePointCtx.repairState.brakes then
        return {}
    end

    local menuItems = {}
    local brakeState = servicePointCtx.repairState.brakes
    local axis = brakeState.axis
    local removedWheelSides = brakeState.removedWheelSides or {}

    if not brakeState.wheelsRemoved then
        if not removedWheelSides.left then
            local wheelNameTranslation = (axis == "front") and t("wheel_lf") or t("wheel_lr")
            table.insert(menuItems, {
                label = string.format(t("remove_wheel_specific"), wheelNameTranslation),
                icon = "fas fa-circle-notch",
                nuiCallback = "removeBrakeWheel",
                callbackData = { side = "left" }
            })
        end
        if not removedWheelSides.right then
            local wheelNameTranslation = (axis == "front") and t("wheel_rf") or t("wheel_rr")
            table.insert(menuItems, {
                label = string.format(t("remove_wheel_specific"), wheelNameTranslation),
                icon = "fas fa-circle-notch",
                nuiCallback = "removeBrakeWheel",
                callbackData = { side = "right" }
            })
        end
    end

    if brakeState.wheelsRemoved and not brakeState.padsInstalled then
        table.insert(menuItems, {
            label = t("install_brake_pads"),
            icon = "fas fa-wrench",
            nuiCallback = "installBrakePads",
            callbackData = {}
        })
    end

    if brakeState.padsInstalled and not brakeState.wheelsReinstalled then
        local reinstalledWheelSides = brakeState.reinstalledWheelSides or {}
        if not reinstalledWheelSides.left then
            local wheelNameTranslation = (axis == "front") and t("wheel_lf") or t("wheel_lr")
            table.insert(menuItems, {
                label = string.format(t("reinstall_wheel_specific"), wheelNameTranslation),
                icon = "fas fa-circle",
                nuiCallback = "reinstallBrakeWheel",
                callbackData = { side = "left" }
            })
        end
        if not reinstalledWheelSides.right then
            local wheelNameTranslation = (axis == "front") and t("wheel_rf") or t("wheel_rr")
            table.insert(menuItems, {
                label = string.format(t("reinstall_wheel_specific"), wheelNameTranslation),
                icon = "fas fa-circle",
                nuiCallback = "reinstallBrakeWheel",
                callbackData = { side = "right" }
            })
        end
    end

    return menuItems
end

local function ShowBrakePadMenu(servicePointCtx)
    if InstallFlow and InstallFlow.SyncUI then
        InstallFlow.SyncUI()
    end
end

local function HideBrakePadMenu()
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

RegisterNUICallback("installBrakePads", function(requestData, cb)
    local servicePointCtx = nil
    local currentPointCtxIndex = State.currentPointCtxIndex
    if currentPointCtxIndex then
        servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    end

    if not servicePointCtx or not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        cb({ success = false })
        return
    end

    if not servicePointCtx.repairState or not servicePointCtx.repairState.brakes or not servicePointCtx.repairState.brakes.inProgress then
        cb({ success = false })
        return
    end

    local brakeState = servicePointCtx.repairState.brakes
    if not brakeState.wheelsRemoved then
        bridge.Notify.SendNotify(t("remove_wheels_first"), "error")
        cb({ success = false })
        return
    end

    local axis = brakeState.axis
    local requiredPadType = brakeState.requiredPadType

    local hasItem = bridge.Callback.Trigger("nn_mechanic:hasBrakePadItem", requiredPadType)
    if not hasItem then
        bridge.Notify.SendNotify(string.format(t("no_brake_pads_item"), requiredPadType), "error")
        cb({ success = false })
        return
    end

    HideBrakePadMenu()

    local progressBarSuccess = bridge.ProgressBar.Open({
        duration = 10000,
        label = t("installing_brake_pads"),
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer", flag = 1 }
    })

    if progressBarSuccess then
        TriggerServerEvent("nn_mechanic:removeBrakePadItem", requiredPadType)
        TriggerServerEvent("nn_mechanic:changeBrakePads", VehToNet(servicePointCtx.vehicle), axis)

        brakeState.padsInstalled = true
        CompleteInstructionStep(4)

        local instructionCompletionStates = {}
        if StateInstructions.currentInstructions then
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                instructionCompletionStates[i] = instruction.completed or false
            end
        end

        SyncRepairState({
            brakes = {
                padsInstalled = true,
                instructionStates = instructionCompletionStates
            }
        })

        bridge.Notify.SendNotify(t("brake_pads_installed"), "success")
        Wait(500)

        if InstallFlow and InstallFlow.IsActive() then
            InstallFlow.SyncUI()
        else
            ShowBrakePadMenu(servicePointCtx)
        end
    end

    cb({ success = progressBarSuccess })
end)

RegisterNUICallback("reinstallBrakeWheel", function(requestData, cb)
    local servicePointCtx = nil
    local currentPointCtxIndex = State.currentPointCtxIndex
    if currentPointCtxIndex then
        servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    end

    if not servicePointCtx or not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        cb({ success = false })
        return
    end

    if not servicePointCtx.repairState or not servicePointCtx.repairState.brakes or not servicePointCtx.repairState.brakes.inProgress then
        cb({ success = false })
        return
    end

    local brakeState = servicePointCtx.repairState.brakes
    if not brakeState.padsInstalled then
        bridge.Notify.SendNotify(t("install_pads_first"), "error")
        cb({ success = false })
        return
    end

    local axis = brakeState.axis
    local side = requestData.side
    if not side or (side ~= "left" and side ~= "right") then
        cb({ success = false })
        return
    end

    local wheelBoneName = GetWheelBoneNameForAxisAndSide(axis, side)

    local bonePositions = (axis == "front") and brakeState.frontWheelBonePositions or brakeState.rearWheelBonePositions

    if not IsPlayerNearWheelBone(servicePointCtx.vehicle, wheelBoneName, 2.0, bonePositions) then
        bridge.Notify.SendNotify(t("go_to_wheel_first"), "error")
        cb({ success = false })
        return
    end

    brakeState.reinstalledWheelSides = brakeState.reinstalledWheelSides or {}
    if brakeState.reinstalledWheelSides[side] then
        bridge.Notify.SendNotify(t("wheel_already_installed"), "error")
        cb({ success = false })
        return
    end

    local wheelOffsets = (axis == "front") and brakeState.frontWheelOffsets or brakeState.rearWheelOffsets

    HideBrakePadMenu()

    local progressBarSuccess = bridge.ProgressBar.Open({
        duration = 5000,
        label = t("reinstalling_wheel"),
        canCancel = false,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", clip = "machinic_loop_mechandplayer", flag = 1 }
    })

    if not progressBarSuccess then
        if InstallFlow and InstallFlow.IsActive() then
            InstallFlow.SyncUI()
        else
            ShowBrakePadMenu(servicePointCtx)
        end
        cb({ success = false })
        return
    end

    local wheelIndex = WHEEL_INDICES[wheelBoneName]
    local originalOffset = (wheelOffsets and wheelOffsets[wheelBoneName]) or 0
    SetVehicleWheelXOffsetsSynced(servicePointCtx.vehicle, { [wheelIndex] = originalOffset })

    brakeState.reinstalledWheelSides[side] = true
    local allWheelsReinstalled = brakeState.reinstalledWheelSides.left and brakeState.reinstalledWheelSides.right
    if allWheelsReinstalled then
        brakeState.wheelsReinstalled = true
        CompleteInstructionStep(5)
    end

    local instructionCompletionStates = {}
    if StateInstructions.currentInstructions then
        for i, instruction in ipairs(StateInstructions.currentInstructions) do
            instructionCompletionStates[i] = instruction.completed or false
        end
    end

    SyncRepairState({
        brakes = {
            reinstalledWheelSides = brakeState.reinstalledWheelSides,
            wheelsReinstalled = allWheelsReinstalled,
            instructionStates = instructionCompletionStates
        }
    })

    bridge.Notify.SendNotify(t("wheel_installed_successfully"), "success")
    Wait(500)

    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    elseif allWheelsReinstalled then
        ShowInstructionsIfExists()
    else
        ShowBrakePadMenu(servicePointCtx)
    end

    cb({ success = true })
end)

local function CheckAndShowBrakePadMenu()
    if InstallFlow and InstallFlow.IsActive() then
        if InstallFlow.SyncUI then
            InstallFlow.SyncUI()
        end
    end
end

local function CompleteBrakePadRepair(servicePointCtx)
    if not servicePointCtx or not servicePointCtx.repairState or not servicePointCtx.repairState.brakes or not servicePointCtx.repairState.brakes.inProgress then
        return false
    end

    if not IsInstructionStepCompleted(5) then
        return false
    end

    CompleteInstructionStep(6)
    local brakeState = servicePointCtx.repairState.brakes
    brakeState.inProgress = false

    local instructionCompletionStates = {}
    if StateInstructions.currentInstructions then
        for i, instruction in ipairs(StateInstructions.currentInstructions) do
            instructionCompletionStates[i] = instruction.completed or false
        end
    end

    SyncRepairState({
        brakes = {
            inProgress = false,
            instructionStates = instructionCompletionStates
        }
    })

    bridge.Notify.SendNotify(t("brake_pad_change_complete"), "success")

    if InstallFlow and InstallFlow.IsActive() then
        Citizen.CreateThread(function()
            Wait(3000)
            InstallFlow.SyncUI()
        end)
    else
        Citizen.CreateThread(function()
            Wait(3000)
            CloseInstructions()
            StateInstructions.currentInstructions = {}
        end)
    end

    return true
end

-- Global assignments (or re-assignments) as per original obfuscated script logic
CreateBrakePadInstructions = CreateBrakePadInstructions
RevalidateBrakePadInstructions = RevalidateBrakePadInstructions
BuildBrakePadMenuItems = BuildBrakePadMenuItems
ShowBrakePadMenu = ShowBrakePadMenu
HideBrakePadMenu = HideBrakePadMenu
CheckAndShowBrakePadMenu = CheckAndShowBrakePadMenu
CompleteBrakePadRepair = CompleteBrakePadRepair