local GetServiceMenuData
local servicePointMonitoringThread = nil
local isServiceMenuOpen = false
local ShowServiceMenu
local HideServiceMenu
local SyncRepairState
local FindClosestServicePoint
local LinkVehicleToServicePoint
local ToggleServiceMenuEntrypoint -- This will be the final function assigned to L4_1
local StartServicePointMonitoring
local StopServicePointMonitoring
local SetupServiceInteractions

function GetServiceMenuData(context)
    local menuItems = {}
    local isBike = false

    local vehicle = context.vehicle
    if vehicle then
        local vehicleClass = GetVehicleClass(vehicle)
        isBike = IsBikeClass(vehicleClass)
    end

    local checkTireOptions = {}
    local changeTireOptions = {}

    local function createTireMenuItem(label, nuiCallback, boneName)
        return {
            label = label,
            icon = "fas fa-wrench",
            nuiCallback = nuiCallback,
            callbackData = { boneName = boneName }
        }
    end

    if isBike then
        checkTireOptions[1] = createTireMenuItem("Front", "checkTire", "wheel_lf")
        checkTireOptions[2] = createTireMenuItem("Rear", "checkTire", "wheel_lr")

        changeTireOptions[1] = createTireMenuItem("Front", "changeTire", "wheel_lf")
        changeTireOptions[2] = createTireMenuItem("Rear", "changeTire", "wheel_lr")
    else
        checkTireOptions[1] = createTireMenuItem("Front Left", "checkTire", "wheel_lf")
        checkTireOptions[2] = createTireMenuItem("Front Right", "checkTire", "wheel_rf")
        checkTireOptions[3] = createTireMenuItem("Rear Left", "checkTire", "wheel_lr")
        checkTireOptions[4] = createTireMenuItem("Rear Right", "checkTire", "wheel_rr")

        changeTireOptions[1] = createTireMenuItem("Front Left", "changeTire", "wheel_lf")
        changeTireOptions[2] = createTireMenuItem("Front Right", "changeTire", "wheel_rf")
        changeTireOptions[3] = createTireMenuItem("Rear Left", "changeTire", "wheel_lr")
        changeTireOptions[4] = createTireMenuItem("Rear Right", "changeTire", "wheel_rr")
    end

    table.insert(menuItems, {
        label = "Tires",
        icon = "fas fa-circle",
        sub = {
            {
                label = t("check_tire") or "Check Tire",
                icon = "fas fa-search",
                sub = checkTireOptions
            },
            {
                label = t("change_tire"),
                icon = "fas fa-wrench",
                sub = changeTireOptions
            }
        }
    })

    table.insert(menuItems, {
        label = "Oil",
        icon = "fas fa-oil-can",
        sub = {
            {
                label = t("change_oil"),
                icon = "fas fa-oil-can",
                nuiCallback = "changeOil"
            }
        }
    })

    local function createBrakePadSubMenuItem(labelKey, nuiCallback, axis)
        return {
            label = t(labelKey),
            icon = "fas fa-wrench",
            nuiCallback = nuiCallback,
            callbackData = { axis = axis }
        }
    end

    table.insert(menuItems, {
        label = t("brakes"),
        icon = "fas fa-compact-disc",
        sub = {
            {
                label = t("check_brakes"),
                icon = "fas fa-search",
                nuiCallback = "checkBrakes"
            },
            {
                label = t("change_brake_pads"),
                icon = "fas fa-wrench",
                sub = {
                    createBrakePadSubMenuItem("change_front_brake_pads", "changeBrakePads", "front"),
                    createBrakePadSubMenuItem("change_rear_brake_pads", "changeBrakePads", "rear")
                }
            }
        }
    })

    table.insert(menuItems, {
        label = t("remove_vehicle_from_service"),
        icon = "fas fa-times-circle",
        nuiCallback = "removeVehicleFromService"
    })

    return menuItems
end
GetServiceMenuData = GetServiceMenuData -- L0_1

function ShowServiceMenu(context)
    if not context or not context.vehicle or not DoesEntityExist(context.vehicle) then
        return
    end

    State.openPage = "menu"
    State.currentMenuId = "service_menu"
    local menuItems = GetServiceMenuData(context)

    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "service_menu",
            items = menuItems
        }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu"
        }
    })
    StartMenuControlsThread()
end
ShowServiceMenu = ShowServiceMenu -- L3_1

function HideServiceMenuFunc()
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "menu"
        }
    })
    if "menu" == State.openPage then
        State.openPage = nil
        State.currentMenuId = nil
    end
end
HideServiceMenu = HideServiceMenuFunc -- L4_1 (first assignment)

function SyncRepairStateFunc(updateData)
    local currentPointCtxIndex = State.currentPointCtxIndex
    if not currentPointCtxIndex then
        return
    end

    local servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    if not servicePointCtx then
        return
    end

    if not servicePointCtx.repairState then
        servicePointCtx.repairState = CreateRepairState()
    end

    servicePointCtx.repairState = MergeRepairState(servicePointCtx.repairState, updateData)

    if not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        return
    end

    local serverSyncData = {}
    serverSyncData.vehicleNetId = VehToNet(servicePointCtx.vehicle)
    serverSyncData.pointId = servicePointCtx.pointId
    serverSyncData.shopId = servicePointCtx.shopId
    serverSyncData.repairState = servicePointCtx.repairState

    TriggerServerEvent("nn_mechanic:setServicePointCtx", servicePointCtx.shopId, servicePointCtx.pointId, serverSyncData)
end
SyncRepairState = SyncRepairStateFunc -- L4_1 (second assignment)

function FindClosestServicePointFunc(playerCoords)
    local closestServicePoint = nil
    local minDistance = nil
    local closestShopId = nil
    local closestPointId = nil

    for shopId, points in pairs(State.points) do
        for pointId, pointData in pairs(points) do
            if "service" == pointData.type then
                local servicePointCoords = vector3(pointData.coords.x, pointData.coords.y, pointData.coords.z)
                local distance = #(playerCoords - servicePointCoords)
                if not minDistance or minDistance > distance then
                    minDistance = distance
                    closestServicePoint = pointData
                    closestShopId = shopId
                    closestPointId = pointId
                end
            end
        end
    end
    return closestShopId, closestPointId, closestServicePoint
end
FindClosestServicePoint = FindClosestServicePointFunc -- L4_1 (third assignment)

function LinkVehicleToServicePointFunc(vehicle, shopId, pointId)
    local contextIndex = shopId .. "_point_" .. pointId
    local serverContext = bridge.Callback.Trigger("nn_mechanic:getServicePointCtx", shopId, pointId)

    if serverContext then
        if serverContext.vehicleNetId == VehToNet(vehicle) then
            State.servicePointsCtx[contextIndex] = serverContext
            if serverContext.vehicleNetId then
                serverContext.vehicle = NetworkGetEntityFromNetworkId(serverContext.vehicleNetId)
            end
            return serverContext
        end
    end

    local newContext = {}
    newContext.vehicle = vehicle
    newContext.vehicleNetId = VehToNet(vehicle)
    newContext.pointId = pointId
    newContext.shopId = shopId
    newContext.repairState = CreateRepairState()

    State.servicePointsCtx[contextIndex] = newContext

    local serverSyncData = {}
    serverSyncData.vehicleNetId = VehToNet(vehicle)
    serverSyncData.pointId = pointId
    serverSyncData.shopId = shopId
    serverSyncData.repairState = newContext.repairState

    TriggerServerEvent("nn_mechanic:setServicePointCtx", shopId, pointId, serverSyncData)
    return newContext
end
LinkVehicleToServicePoint = LinkVehicleToServicePointFunc -- L4_1 (fourth assignment)

function ToggleServiceMenuFunc()
    local currentPointCtxIndex = State.currentPointCtxIndex
    if not currentPointCtxIndex then
        return
    end

    local servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    if not servicePointCtx then
        return
    end

    if not servicePointCtx.vehicle or not DoesEntityExist(servicePointCtx.vehicle) then
        return
    end

    local repairInProgress = false
    local repairState = servicePointCtx.repairState
    if State.repairInProgress then
        repairInProgress = true
    else
        if repairState then
            if repairState.oilChange and repairState.oilChange.inProgress then
                repairInProgress = true
            elseif repairState.brakes and repairState.brakes.inProgress then
                repairInProgress = true
            end
        end
    end

    if repairInProgress then
        bridge.Notify.SendNotify(t("repair_in_progress"), "error")
        return
    end

    if "menu" == State.openPage then
        HideServiceMenu()
        isServiceMenuOpen = false
    else
        if "notepad" == State.openPage then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = false,
                    page = "notepad"
                }
            })
            State.openPage = nil
        end
        ShowServiceMenu(servicePointCtx)
        isServiceMenuOpen = true
    end
end
ToggleServiceMenuEntrypoint = ToggleServiceMenuFunc -- L4_1 (fifth assignment)

function StartServicePointMonitoring(context)
    if servicePointMonitoringThread then
        return
    end

    servicePointMonitoringThread = Citizen.CreateThread(function()
        while true do
            local currentPointCtxIndex = State.currentPointCtxIndex
            if not currentPointCtxIndex then
                break
            end

            local servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
            if servicePointCtx then
                local vehicle = nil
                if servicePointCtx.vehicleNetId then
                    vehicle = NetworkGetEntityFromNetworkId(servicePointCtx.vehicleNetId)
                elseif servicePointCtx.vehicle then
                    vehicle = servicePointCtx.vehicle
                end

                local vehicleExists = false
                if vehicle then
                    vehicleExists = DoesEntityExist(vehicle)
                end

                if not vehicleExists then
                    if "menu" == State.openPage then
                        HideServiceMenu()
                        isServiceMenuOpen = false
                    end

                    local oilChangeInProgress = false
                    if servicePointCtx.repairState and servicePointCtx.repairState.oilChange and servicePointCtx.repairState.oilChange.inProgress then
                        oilChangeInProgress = true
                    end

                    if not oilChangeInProgress then
                        State.servicePointsCtx[currentPointCtxIndex] = nil
                    end
                end
            else
                if "menu" == State.openPage then
                    HideServiceMenu()
                    isServiceMenuOpen = false
                end
            end
            Wait(500)
        end
        if "menu" == State.openPage then
            HideServiceMenu()
        end
        isServiceMenuOpen = false
        servicePointMonitoringThread = nil
    end)
end
StartServicePointMonitoring = StartServicePointMonitoring -- L5_1

function StopServicePointMonitoring()
    if servicePointMonitoringThread then
        servicePointMonitoringThread = nil
    end
end
StopServicePointMonitoring = StopServicePointMonitoring -- L6_1

function SetupServiceInteractions(servicePointCtx)
    StartServicePointMonitoring(servicePointCtx)

    local isAnyRepairInProgress = false
    local repairState = servicePointCtx.repairState
    if servicePointCtx.repairState and (servicePointCtx.repairState.oilChange and servicePointCtx.repairState.oilChange.inProgress or servicePointCtx.repairState.brakes and servicePointCtx.repairState.brakes.inProgress) then
        isAnyRepairInProgress = true
    end

    local showOilBoltMenu = false
    local showRefillOil = false
    local showInstructions = false

    if servicePointCtx then
        if repairState and repairState.oilChange and repairState.oilChange.inProgress then
            local vehicle = servicePointCtx.vehicle
            if vehicle and DoesEntityExist(vehicle) then
                local lift = repairState.lift
                if lift then
                    if lift.isAttached then
                        if lift.vehicleNetId == VehToNet(vehicle) then
                            local liftIsDown = false
                            local liftPosition = "unknown"
                            local liftState = nil

                            if lift.liftIndex then
                                liftState = State.liftStates and State.liftStates[lift.liftIndex]
                            end

                            if liftState then
                                liftPosition = liftState.position or liftPosition
                                if "min" == liftState.position then
                                    liftIsDown = true
                                end
                            else
                                if "min" == lift.position then
                                    liftPosition = lift.position or liftPosition
                                    liftIsDown = true
                                end
                            end

                            local step2Completed = IsInstructionStepCompleted(2)
                            local step3Completed = IsInstructionStepCompleted(3)
                            local step4Completed = IsInstructionStepCompleted(4)
                            local step5Completed = IsInstructionStepCompleted(5)
                            local step6Completed = IsInstructionStepCompleted(6)

                            if step4Completed and not step5Completed and liftIsDown then
                                showRefillOil = true
                            elseif step3Completed and not step4Completed then
                                showInstructions = true
                            elseif step2Completed and not step3Completed then
                                if not lift.isMoving then
                                    showOilBoltMenu = true
                                end
                            elseif not step2Completed then
                                showInstructions = true
                            end
                        end
                    end
                else
                    showInstructions = true
                end
            end
        end
    end

    if "car-lift-control" == State.openPage then
        return
    end

    if servicePointCtx and servicePointCtx.vehicleNetId then
        if not State.repairInProgress and not isAnyRepairInProgress then
            if "notepad" ~= State.openPage and "instructions" ~= State.openPage and not showOilBoltMenu and not showRefillOil and not showInstructions then
                ShowServiceMenu(servicePointCtx)
            end
        end
    end

    if showRefillOil then
        RefillOil()
    elseif showOilBoltMenu then
        CheckAndShowOilBoltMenu()
    elseif showInstructions then
        ShowInstructionsIfExists()
    end
end
SetupServiceInteractions = SetupServiceInteractions -- L7_1 (first assignment)

RegisterCommand("toggle_mechanic_notepad", function()
    local currentPointCtxIndex = State.currentPointCtxIndex
    if not currentPointCtxIndex then
        return
    end

    local servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    if not servicePointCtx or not servicePointCtx.inspectionData then
        return
    end

    if "notepad" == State.openPage then
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = false,
                page = "notepad"
            }
        })
        State.openPage = nil
    else
        if "menu" == State.openPage then
            HideServiceMenu()
            isServiceMenuOpen = false
        end

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
            data = {
                visible = true,
                page = "notepad"
            }
        })
        State.openPage = "notepad"
    end
end)

RegisterKeyMapping("toggle_mechanic_notepad", "Toggle Mechanic Notepad", "keyboard", "J")

RegisterCommand("toggle_service_menu", function()
    ToggleServiceMenuEntrypoint()
end)

RegisterKeyMapping("toggle_service_menu", "Toggle Service Menu", "keyboard", "M")

if Config.Debug then
    RegisterCommand("debug_add_vehicle_to_service", function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local closestVehicle = nil
        local minVehicleDistance = nil

        for _, vehicle in ipairs(GetGamePool("CVehicle")) do
            if vehicle and DoesEntityExist(vehicle) then
                if vehicle ~= GetVehiclePedIsIn(playerPed, false) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehicleCoords)
                    if not minVehicleDistance or minVehicleDistance > distance then
                        minVehicleDistance = distance
                        closestVehicle = vehicle
                    end
                end
            end
        end

        if not closestVehicle then
            bridge.Notify.SendNotify("No vehicle found nearby", "error")
            return
        end

        local closestServicePointData = nil
        local minServicePointDistance = nil
        local closestShopId = nil
        local closestPointId = nil

        for shopId, points in pairs(State.points) do
            for pointId, pointData in pairs(points) do
                if "service" == pointData.type then
                    local servicePointCoords = vector3(pointData.coords.x, pointData.coords.y, pointData.coords.z)
                    local distance = #(playerCoords - servicePointCoords)
                    if not minServicePointDistance or minServicePointDistance > distance then
                        minServicePointDistance = distance
                        closestServicePointData = pointData
                        closestShopId = shopId
                        closestPointId = pointId
                    end
                end
            end
        end

        if not closestServicePointData then
            bridge.Notify.SendNotify("No service point found", "error")
            return
        end

        local contextIndex = closestShopId .. "_point_" .. closestPointId
        local vehicleNetId = VehToNet(closestVehicle)

        local serverSyncData = {}
        serverSyncData.vehicleNetId = vehicleNetId
        serverSyncData.pointId = closestPointId
        serverSyncData.shopId = closestShopId
        TriggerServerEvent("nn_mechanic:setServicePointCtx", closestShopId, closestPointId, serverSyncData)

        serverSyncData.vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        SetVehicleEngineOn(closestVehicle, false, true, false)

        State.currentPointCtxIndex = contextIndex
        State.servicePointsCtx[contextIndex] = serverSyncData

        SetupServiceInteractions(serverSyncData)

        bridge.Notify.SendNotify("Vehicle added to service point", "success")
    end, false)

    RegisterCommand("debug_oil_change_setup", function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local closestVehicle = nil
        local minVehicleDistance = nil

        for _, vehicle in ipairs(GetGamePool("CVehicle")) do
            if vehicle and DoesEntityExist(vehicle) then
                if vehicle ~= GetVehiclePedIsIn(playerPed, false) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(playerCoords - vehicleCoords)
                    if not minVehicleDistance or minVehicleDistance > distance then
                        minVehicleDistance = distance
                        closestVehicle = vehicle
                    end
                end
            end
        end

        if not closestVehicle then
            bridge.Notify.SendNotify("No vehicle found nearby", "error")
            return
        end

        local closestServicePointData = nil
        local minServicePointDistance = nil
        local closestShopId = nil
        local closestPointId = nil

        for shopId, points in pairs(State.points) do
            for pointId, pointData in pairs(points) do
                if "service" == pointData.type then
                    local servicePointCoords = vector3(pointData.coords.x, pointData.coords.y, pointData.coords.z)
                    local distance = #(playerCoords - servicePointCoords)
                    if not minServicePointDistance or minServicePointDistance > distance then
                        minServicePointDistance = distance
                        closestServicePointData = pointData
                        closestShopId = shopId
                        closestPointId = pointId
                    end
                end
            end
        end

        if not closestServicePointData then
            bridge.Notify.SendNotify("No service point found", "error")
            return
        end

        local contextIndex = closestShopId .. "_point_" .. closestPointId
        local vehicleNetId = VehToNet(closestVehicle)

        local serverSyncData = {}
        serverSyncData.vehicleNetId = vehicleNetId
        serverSyncData.pointId = closestPointId
        serverSyncData.shopId = closestShopId
        TriggerServerEvent("nn_mechanic:setServicePointCtx", closestShopId, closestPointId, serverSyncData)

        serverSyncData.vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
        SetVehicleEngineOn(closestVehicle, false, true, false)

        State.currentPointCtxIndex = contextIndex
        State.servicePointsCtx[contextIndex] = serverSyncData

        SetupServiceInteractions(serverSyncData)

        Wait(500)

        local vehicleClass = GetVehicleClass(serverSyncData.vehicle)
        local requiredOilType = Config.OilClasses[vehicleClass]

        if not requiredOilType or "none" == requiredOilType then
            bridge.Notify.SendNotify("Vehicle does not require oil change", "error")
            return
        end

        local oilChangeInstructions = CreateOilChangeInstructions()
        OpenInstructions(oilChangeInstructions)

        local repairState = serverSyncData.repairState
        if not repairState then
            repairState = CreateRepairState()
            serverSyncData.repairState = repairState
        end

        repairState.oilChange = {
            inProgress = true,
            requiredOilType = requiredOilType,
            instructionStates = {}
        }

        if StateInstructions.currentInstructions then
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                repairState.oilChange.instructionStates[i] = instruction.completed or false
            end
        end

        local currentRepairStateData = {}
        currentRepairStateData.vehicleNetId = VehToNet(closestVehicle)
        currentRepairStateData.pointId = closestPointId
        currentRepairStateData.shopId = closestShopId
        currentRepairStateData.repairState = repairState

        TriggerServerEvent("nn_mechanic:setServicePointCtx", closestShopId, closestPointId, currentRepairStateData)

        Wait(500)

        local liftIndex, liftSpotData = GetClosestLiftSpot(playerCoords)
        if not liftSpotData then
            bridge.Notify.SendNotify(t("no_lift_found_nearby"), "error")
            return
        end

        local liftCarLiftEntity = GetCarLiftEntity(liftIndex)
        local vehicleCoords = GetEntityCoords(closestVehicle)
        local vehicleRotation = GetEntityRotation(closestVehicle, 2)
        local vehicleZOffset = 0.5

        if liftCarLiftEntity and DoesEntityExist(liftCarLiftEntity) then
            local liftCoords = GetEntityCoords(liftCarLiftEntity)
            vehicleZOffset = vehicleCoords.z - liftCoords.z
        end

        local attachData = {
            x = vehicleCoords.x,
            y = vehicleCoords.y,
            z = vehicleCoords.z,
            rotX = vehicleRotation.x,
            rotY = vehicleRotation.y,
            rotZ = vehicleRotation.z,
            vehicleZOffset = vehicleZOffset
        }

        TriggerServerEvent("nn_mechanic:attachVehicleToLift", liftIndex, VehToNet(closestVehicle), attachData)

        Wait(1500)

        if not repairState.lift then
            repairState.lift = {}
        end
        repairState.lift.isAttached = true
        repairState.lift.liftIndex = liftIndex
        repairState.lift.vehicleNetId = VehToNet(closestVehicle)
        repairState.lift.isMoving = false
        repairState.lift.position = "down"

        if not IsInstructionStepCompleted(1) then
            CompleteInstructionStep(1)
        end

        if StateInstructions.currentInstructions then
            local updatedInstructionStates = {}
            for i, instruction in ipairs(StateInstructions.currentInstructions) do
                updatedInstructionStates[i] = instruction.completed or false
            end
            SyncRepairState({
                lift = {
                    isAttached = true,
                    liftIndex = liftIndex,
                    vehicleNetId = VehToNet(closestVehicle),
                    isMoving = false,
                    position = "down"
                },
                oilChange = {
                    instructionStates = updatedInstructionStates
                }
            })
        end

        if Config.Debug then
            Citizen.CreateThread(function()
                Wait(1000)
                local currentCtx = State.servicePointsCtx[contextIndex]
                if not currentCtx or not currentCtx.vehicle then
                    bridge.Notify.SendNotify("Failed to get vehicle from context", "error")
                    return
                end

                local vehicle = currentCtx.vehicle
                if not DoesEntityExist(vehicle) then
                    bridge.Notify.SendNotify("Vehicle no longer exists", "error")
                    return
                end

                local carLiftEntity = GetCarLiftEntity(liftIndex)
                if not carLiftEntity then
                    if HasLiftProp(liftSpotData) then
                        carLiftEntity = GetClosestObjectOfType(
                            liftSpotData.base.x, liftSpotData.base.y, liftSpotData.base.z,
                            10.0, GetHashKey(liftSpotData.prop), false, false, false
                        )
                    end
                end

                if carLiftEntity and DoesEntityExist(carLiftEntity) then
                    local liftCoords = GetEntityCoords(carLiftEntity)
                    local minZ = liftSpotData.minZ
                    SetEntityCoords(carLiftEntity, liftCoords.x, liftCoords.y, minZ, false, false, false, false)
                    TriggerServerEvent("nn_mechanic:syncLiftPosition", liftIndex, liftCoords.x, liftCoords.y, minZ)

                    Wait(500)

                    for i = 1, 5, 1 do
                        if not IsInstructionStepCompleted(i) then
                            CompleteInstructionStep(i)
                        end
                    end

                    if currentCtx and currentCtx.repairState then
                        if not currentCtx.repairState.lift then
                            currentCtx.repairState.lift = {}
                        end
                        currentCtx.repairState.lift.height = minZ
                        currentCtx.repairState.lift.position = "min"
                        currentCtx.repairState.lift.isMoving = false
                    end

                    if StateInstructions.currentInstructions then
                        local updatedInstructionStates = {}
                        for i, instruction in ipairs(StateInstructions.currentInstructions) do
                            updatedInstructionStates[i] = instruction.completed or false
                        end
                        SyncRepairState({
                            lift = {
                                height = minZ,
                                position = "min",
                                isMoving = false
                            },
                            oilChange = {
                                instructionStates = updatedInstructionStates
                            }
                        })
                    end

                    Wait(1000)

                    if State.currentPointCtxIndex then
                        RefillOil()
                        Wait(500)
                        bridge.Notify.SendNotify("Oil change setup complete! Refill oil menu should appear.", "success")
                    else
                        bridge.Notify.SendNotify("Oil change setup complete, but you are not in a service point.", "warning")
                    end
                else
                    bridge.Notify.SendNotify("Failed to find lift entity", "error")
                end
            end)
        else
            Citizen.CreateThread(function()
                local playerZ = GetEntityCoords(State.Ped).z
                local targetZ = playerZ + 1.5

                while true do
                    local servicePointCtx = State.servicePointsCtx[contextIndex]
                    if servicePointCtx and servicePointCtx.vehicle and DoesEntityExist(servicePointCtx.vehicle) then
                        local attachedTo = GetEntityAttachedTo(servicePointCtx.vehicle)
                        if attachedTo ~= 0 and DoesEntityExist(attachedTo) then
                            local vehicleZ = GetEntityCoords(servicePointCtx.vehicle).z
                            if targetZ <= vehicleZ then
                                if not IsInstructionStepCompleted(2) then
                                    CompleteInstructionStep(2)
                                    if StateInstructions.currentInstructions then
                                        local updatedInstructionStates = {}
                                        for i, instruction in ipairs(StateInstructions.currentInstructions) do
                                            updatedInstructionStates[i] = instruction.completed or false
                                        end
                                        SyncRepairState({
                                            oilChange = {
                                                instructionStates = updatedInstructionStates
                                            }
                                        })
                                    end
                                end
                                break
                            end
                        end
                    end
                    TriggerServerEvent("nn_mechanic:moveLift", liftIndex, "up")
                    Wait(300)
                end
                Wait(2000)
                bridge.Notify.SendNotify("Oil change setup complete! Oil bolt menu should be visible.", "success")
            end)
        end
        bridge.Notify.SendNotify("Setting up oil change...", "info")
    end, false)
end

RegisterNUICallback("removeVehicleFromService", function(data, cb)
    local currentPointCtxIndex = State.currentPointCtxIndex
    if not currentPointCtxIndex then
        cb({ success = false })
        return
    end

    local servicePointCtx = State.servicePointsCtx[currentPointCtxIndex]
    if not servicePointCtx then
        cb({ success = false })
        return
    end

    TriggerServerEvent("nn_mechanic:clearServicePointCtx", servicePointCtx.shopId, servicePointCtx.pointId)
    State.servicePointsCtx[currentPointCtxIndex] = nil

    if "menu" == State.openPage then
        HideServiceMenu()
        isServiceMenuOpen = false
    else
        if "notepad" == State.openPage then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = false,
                    page = "notepad"
                }
            })
            State.openPage = nil
        end
    end
    State.currentPointCtxIndex = nil
    StopServicePointMonitoring()
    bridge.Notify.SendNotify(t("vehicle_removed_from_service"), "success")
    cb({ success = true })
end)

RegisterNetEvent("nn_mechanic:updateServicePointCtx", function(shopId, pointId, ctxData)
    local contextIndex = shopId .. "_point_" .. pointId

    local currentRepairState = ctxData.repairState
    if not currentRepairState then
        currentRepairState = CreateRepairState()
        ctxData.repairState = currentRepairState
    else
        local defaultRepairState = CreateRepairState()
        ctxData.repairState = MergeRepairState(defaultRepairState, currentRepairState)
    end

    State.servicePointsCtx[contextIndex] = ctxData

    if ctxData.vehicleNetId then
        ctxData.vehicle = NetworkGetEntityFromNetworkId(ctxData.vehicleNetId)
        if ctxData.vehicle and DoesEntityExist(ctxData.vehicle) then

            if ctxData.repairState and ctxData.repairState.oilChange and ctxData.repairState.oilChange.instructionStates then
                if #ctxData.repairState.oilChange.instructionStates > 0 then
                    StateInstructions.currentInstructions = CreateOilChangeInstructions(ctxData.repairState.oilChange.instructionStates)
                end
            end

            if ctxData.repairState and ctxData.repairState.brakes and ctxData.repairState.brakes.instructionStates then
                if #ctxData.repairState.brakes.instructionStates > 0 then
                    local axis = ctxData.repairState.brakes.axis or "front"
                    StateInstructions.currentInstructions = CreateBrakePadInstructions(axis, ctxData.repairState.brakes.instructionStates)
                end
            end

            if State.currentPointCtxIndex == contextIndex then
                SetupServiceInteractions(ctxData)

                local oilChangeInProgress = ctxData.repairState and ctxData.repairState.oilChange and ctxData.repairState.oilChange.inProgress
                local brakesInProgress = ctxData.repairState and ctxData.repairState.brakes and ctxData.repairState.brakes.inProgress

                if oilChangeInProgress then
                    RevalidateOilChangeInstructions(ctxData)

                    local attachedTo = GetEntityAttachedTo(ctxData.vehicle)
                    if attachedTo ~= 0 and DoesEntityExist(attachedTo) then
                        for liftIndex, liftData in pairs(RuntimeLifts) do
                            local carLiftEntity = GetCarLiftEntity(liftIndex)
                            if not carLiftEntity then
                                if HasLiftProp(liftData) then
                                    carLiftEntity = GetClosestObjectOfType(
                                        liftData.base.x, liftData.base.y, liftData.base.z,
                                        10.0, GetHashKey(liftData.prop), false, false, false
                                    )
                                end
                            end
                            if carLiftEntity and DoesEntityExist(carLiftEntity) and carLiftEntity == attachedTo then
                                State.currentOpenLift = {
                                    liftIndex = liftIndex,
                                    vehicle = ctxData.vehicle
                                }
                                State.liftMoving = false
                                break
                            end
                        end
                    end

                    Wait(500)

                    local liftIsDown = false
                    local liftState = ctxData.repairState and ctxData.repairState.lift
                    if liftState and liftState.liftIndex then
                        local stateLift = State.liftStates and State.liftStates[liftState.liftIndex]
                        if stateLift then
                            if "min" == stateLift.position then
                                liftIsDown = true
                            end
                        else
                            if "min" == liftState.position then
                                liftIsDown = true
                            end
                        end
                    end

                    local step5Completed = IsInstructionStepCompleted(5)
                    if step5Completed then
                        local step6Completed = IsInstructionStepCompleted(6)
                        if not step6Completed and liftIsDown then
                            RefillOil()
                        end
                    else
                        local step4Completed = IsInstructionStepCompleted(4)
                        if step4Completed then
                            local step5CompletedCheck = IsInstructionStepCompleted(5)
                            if not step5CompletedCheck then
                                ShowInstructionsIfExists()
                            end
                        else
                            local step2Completed = IsInstructionStepCompleted(2)
                            if step2Completed then
                                local step3Completed = IsInstructionStepCompleted(3)
                                if not step3Completed then
                                    CheckAndShowOilBoltMenu()
                                end
                            else
                                ShowInstructionsIfExists()
                            end
                        end
                    end
                elseif brakesInProgress then
                    RevalidateBrakePadInstructions(ctxData)
                    Wait(500)
                    local step2Completed = IsInstructionStepCompleted(2)
                    if step2Completed then
                        local step5Completed = IsInstructionStepCompleted(5)
                        if not step5Completed then
                            CheckAndShowBrakePadMenu()
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("nn_mechanic:clearServicePointCtx", function(shopId, pointId)
    local contextIndex = shopId .. "_point_" .. pointId
    local servicePointCtx = State.servicePointsCtx[contextIndex]

    if servicePointCtx then
        if servicePointCtx.repairState and servicePointCtx.repairState.menus then
            if servicePointCtx.repairState.menus.oilBoltMenu then
                HideOilBoltMenu()
            end
            if servicePointCtx.repairState.menus.brakePadMenu then
                HideBrakePadMenu()
            end
        end
    end

    State.servicePointsCtx[contextIndex] = nil

    if State.currentPointCtxIndex == contextIndex then
        State.currentPointCtxIndex = nil
        if "menu" == State.openPage then
            HideServiceMenu()
            isServiceMenuOpen = false
        else
            if "notepad" == State.openPage then
                SendNUIMessage({
                    action = "setVisibility",
                    data = {
                        visible = false,
                        page = "notepad"
                    }
                })
                State.openPage = nil
            end
        end
        StopServicePointMonitoring()
    end
end)