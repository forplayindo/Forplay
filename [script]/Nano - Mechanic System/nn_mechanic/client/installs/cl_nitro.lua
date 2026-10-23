if not bridge then
    bridge = exports.community_bridge:Bridge()
end

local ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local ANIM_CLIP = "machinic_loop_mechandplayer"

installState = {}
installState.inProgress = false
installState.vehicle = nil
installState.vehiclePlate = nil
installState.itemName = nil
installState.itemSlot = nil
installState.currentStep = 1
installState.steps = nil

function IsElectricVehicle(vehicle)
    local entityExists, model, displayName, lowerDisplayName, isElectric
    entityExists = DoesEntityExist(vehicle)
    if not entityExists then
        return false
    end
    model = GetEntityModel(vehicle)
    displayName = GetDisplayNameFromVehicleModel(model)
    lowerDisplayName = string.lower(displayName)
    isElectric = Config.Nitro.electricVehicles[lowerDisplayName]
    return true == isElectric
end

function GetVehicleEngineLevel(vehicle)
    local entityExists, modLevel
    entityExists = DoesEntityExist(vehicle)
    if not entityExists then
        return 0
    end
    modLevel = GetVehicleMod(vehicle, 11)
    return modLevel + 1
end

function FindClosestVehicle(maxDistance)
    local playerPed, playerCoords, findHandle, currentVehicle, foundVehicle, closestVehicle, closestDistance, currentVehicleExists, vehicleCoords, distanceToVehicle
    playerPed = PlayerPedId()
    playerCoords = GetEntityCoords(playerPed)
    findHandle, currentVehicle = FindFirstVehicle()
    foundVehicle = true
    closestVehicle = nil
    closestDistance = maxDistance + 1
    while foundVehicle do
        currentVehicleExists = DoesEntityExist(currentVehicle)
        if currentVehicleExists then
            vehicleCoords = GetEntityCoords(currentVehicle)
            distanceToVehicle = #(playerCoords - vehicleCoords)
            if maxDistance >= distanceToVehicle and closestDistance > distanceToVehicle then
                closestVehicle = currentVehicle
                closestDistance = distanceToVehicle
            end
        end
        foundVehicle, currentVehicle = FindNextVehicle(findHandle)
    end
    EndFindVehicle(findHandle)
    return closestVehicle, closestDistance
end

function ResetNitroInstallState()
    local newState
    newState = {}
    newState.inProgress = false
    newState.vehicle = nil
    newState.vehiclePlate = nil
    newState.itemName = nil
    newState.itemSlot = nil
    newState.currentStep = 1
    newState.steps = nil
    installState = newState
    State.repairInProgress = false
    if InstallFlow then
        if InstallFlow.IsActive() then
            InstallFlow.SyncUI()
        end
    end
end

function CloseNitroInstallMenu()
    local openPage, currentMenuId
    openPage = State.openPage
    if "menu" == openPage then
        currentMenuId = State.currentMenuId
        if "nitro_install_menu" == currentMenuId or "install_flow_menu" == currentMenuId then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = false,
                    page = "menu"
                }
            })
            State.openPage = nil
            State.currentMenuId = nil
        end
    end
end

function IsNitroInstallActive()
    if installState then
        return installState.inProgress == true
    end
    return false
end

function BuildNitroInstallMenu()
    local menuItems = {}
    if not installState or not installState.steps then
        return menuItems
    end

    for stepIndexInMenu, stepData in ipairs(installState.steps) do
        local isCompleted = stepIndexInMenu < installState.currentStep
        local isActive = stepIndexInMenu == installState.currentStep
        local isDisabled = stepIndexInMenu > installState.currentStep
        local icon = "fas fa-circle"
        
        if isCompleted then
            icon = "fas fa-check-circle"
        elseif isDisabled then
            icon = "fas fa-lock"
        else
            if "requirement" == stepData.type then
                icon = "fas fa-car-side"
            elseif "progress" == stepData.type then
                icon = "fas fa-wrench"
            elseif "minigame" == stepData.type then
                icon = "fas fa-gamepad"
            end
        end
        
        local itemData = {
            label = string.format("%d. %s", stepIndexInMenu, stepData.label),
            icon = icon
        }
        
        if isActive then
            itemData.nuiCallback = "nitroInstallStep_" .. stepIndexInMenu
        else
            itemData.nuiCallback = nil
        end
        
        itemData.callbackData = {
            stepIndex = stepIndexInMenu
        }
        itemData.disabled = isCompleted or isDisabled
        table.insert(menuItems, itemData)
    end
    
    table.insert(menuItems, {
        label = t("cancel") or "Cancel",
        icon = "fas fa-times",
        nuiCallback = "nitro:cancel",
        callbackData = {}
    })
    
    return menuItems
end

function OpenNitroInstallMenu()
    if not installState.inProgress then
        return
    end
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
        return
    end
    local menuData = BuildNitroInstallMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "nitro_install_menu",
            items = menuData
        }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu"
        }
    })
    State.openPage = "menu"
    State.currentMenuId = "nitro_install_menu"
    StartMenuControlsThread()
end

function ProcessRequirementStep(stepData)
    local closeMenuResult, requirementType, vehicle, vehicleExists, doorRatio, openThreshold, animLoaded, progressBarResult, notificationLabel
    closeMenuResult = CloseNitroInstallMenu()
    requirementType = stepData.requirement
    if "hoodOpen" == requirementType then
        vehicle = installState.vehicle
        if not (vehicle and DoesEntityExist(vehicle)) then
            return false
        end
        doorRatio = GetVehicleDoorAngleRatio(vehicle, 4)
        openThreshold = 0.1
        if doorRatio < openThreshold then
            RequestAnimDict(ANIM_DICT)
            while true do
                animLoaded = HasAnimDictLoaded(ANIM_DICT)
                if animLoaded then
                    break
                end
                Wait(30)
            end
            progressBarResult = bridge.ProgressBar.Open({
                duration = 2000,
                label = stepData.progressLabel or t("opening_hood"),
                canCancel = true,
                disable = {
                    move = true,
                    car = true,
                    combat = true
                },
                anim = {
                    dict = ANIM_DICT,
                    clip = ANIM_CLIP,
                    flag = 1
                }
            })
            if progressBarResult then
                SetVehicleDoorOpen(vehicle, 4, false, false)
                bridge.Notify.SendNotify(t("hood_opened"), "success")
                Wait(300)
                return true
            else
                return false
            end
        else
            return true
        end
    end
    return true
end

function ProcessProgressStep(stepData)
    local closeMenuResult, animLoaded, progressBarResult, duration, label
    closeMenuResult = CloseNitroInstallMenu()
    RequestAnimDict(ANIM_DICT)
    while true do
        animLoaded = HasAnimDictLoaded(ANIM_DICT)
        if animLoaded then
            break
        end
        Wait(30)
    end
    duration = stepData.duration
    if not duration then
        duration = 3000
    end
    label = stepData.label
    progressBarResult = bridge.ProgressBar.Open({
        duration = duration,
        label = label,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = ANIM_DICT,
            clip = ANIM_CLIP,
            flag = 1
        }
    })
    ClearPedTasks(PlayerPedId())
    return true == progressBarResult
end

function ProcessMinigameStep(stepData)
    local closeMenuResult, minigameResult, minigameName, taskLabel
    closeMenuResult = CloseNitroInstallMenu()
    minigameResult = false
    minigameName = stepData.name
    if "tool_matching" == minigameName then
        taskLabel = stepData.label
        if not taskLabel then
            taskLabel = "Tool Selection"
        end
        minigameResult = StartToolMatchingMinigame({
            rounds = 3,
            difficulty = "medium",
            taskType = taskLabel
        })
    elseif "cable_routing" == minigameName then
        taskLabel = stepData.label
        if not taskLabel then
            taskLabel = "Wire Routing"
        end
        minigameResult = StartCableRoutingMinigame({
            difficulty = "medium",
            taskType = taskLabel,
            timeLimit = 30
        })
    elseif "key_press_timing" == minigameName then
        minigameResult = StartKeyPressMinigame({
            rounds = 3,
            difficulty = "medium",
            timeLimit = 30
        })
    else
        minigameResult = true
    end
    return minigameResult
end

function ExecuteCurrentInstallStep()
    local inProgress, currentStepData, stepSuccess, currentStepType
    inProgress = installState.inProgress
    if not inProgress then
        return false
    end
    currentStepData = installState.steps[installState.currentStep]
    if not currentStepData then
        return false
    end
    stepSuccess = false
    currentStepType = currentStepData.type
    if "requirement" == currentStepType then
        stepSuccess = ProcessRequirementStep(currentStepData)
    elseif "progress" == currentStepType then
        stepSuccess = ProcessProgressStep(currentStepData)
    elseif "minigame" == currentStepType then
        stepSuccess = ProcessMinigameStep(currentStepData)
    end
    if stepSuccess then
        installState.currentStep = installState.currentStep + 1
        if installState.currentStep > #installState.steps then
            return true
        end
        OpenNitroInstallMenu()
    else
        bridge.Notify.SendNotify(t("nitro_install_cancelled"), "error")
        OpenNitroInstallMenu()
    end
    return false
end

function FinalizeNitroInstallation()
    local closeMenuResult, success, result, vehicleExists, entityState, errorMessage, notifyMessage
    closeMenuResult = CloseNitroInstallMenu()
    success, result = bridge.Callback.Trigger("nn_mechanic:installNitroBottle", installState.vehiclePlate, installState.itemName, installState.itemSlot)
    if success then
        bridge.Notify.SendNotify(t("nitro_installed"), "success")
        vehicleExists = installState.vehicle
        if vehicleExists then
            vehicleExists = DoesEntityExist(installState.vehicle)
            if vehicleExists then
                entityState = Entity(installState.vehicle).state
                if entityState then
                    entityState.nn_nitro_installed = true
                    entityState.nn_nitro_data = result
                end
            end
        end
    else
        errorMessage = t("nitro_install_cancelled")
        if "max_bottles" == result then
            errorMessage = t("nitro_max_bottles_reached")
        elseif "no_item" == result then
            errorMessage = t("missing_item")
        end
        bridge.Notify.SendNotify(errorMessage, "error")
    end
    ResetNitroInstallState()
end

function BeginNitroInstallation(itemName, itemData)
    local inProgressOrRepair, isEmployeeResult, isEmployee, closestVehicle, closestDistance, vehicleModel, isCar, allowElectric, isElectric, engineLevel, minEngineLevel, vehiclePlateRaw, vehiclePlateCleaned, nitroData, currentBottles, maxBottles, newInstallState, stepsSetup, isInstallFlowStarted
    inProgressOrRepair = installState.inProgress or State.repairInProgress
    if inProgressOrRepair then
        bridge.Notify.SendNotify(t("repair_in_progress"), "error")
        return
    end
    isEmployeeResult = bridge.Callback.Trigger("nn_mechanic:isPlayerEmployee")
    if not (isEmployeeResult and isEmployeeResult.isEmployee) then
        bridge.Notify.SendNotify(t("nitro_not_mechanic"), "error")
        return
    end
    closestVehicle, closestDistance = FindClosestVehicle(5.0)
    if not closestVehicle then
        bridge.Notify.SendNotify(t("nitro_no_vehicle_nearby"), "error")
        return
    end
    vehicleModel = GetEntityModel(closestVehicle)
    isCar = IsThisModelACar(vehicleModel)
    if not isCar then
        bridge.Notify.SendNotify(t("nitro_not_a_car"), "error")
        return
    end
    allowElectric = Config.Nitro.allowElectric
    if not allowElectric then
        isElectric = IsElectricVehicle(closestVehicle)
        if isElectric then
            bridge.Notify.SendNotify(t("nitro_electric_vehicle"), "error")
            return
        end
    end
    engineLevel = GetVehicleEngineLevel(closestVehicle)
    minEngineLevel = Config.Nitro.engineMinLevel
    if engineLevel < minEngineLevel then
        bridge.Notify.SendNotify(t("nitro_engine_too_low"), "error")
        return
    end
    vehiclePlateRaw = GetVehicleNumberPlateText(closestVehicle)
    vehiclePlateCleaned = string.gsub(vehiclePlateRaw, "%s+", "")
    nitroData = bridge.Callback.Trigger("nn_mechanic:getVehicleNitro", vehiclePlateCleaned)
    currentBottles = 0
    if nitroData then
        if nitroData.bottles then
            currentBottles = #nitroData.bottles
        end
    end
    maxBottles = Config.Nitro.maxBottles
    if currentBottles >= maxBottles then
        bridge.Notify.SendNotify(string.format(t("nitro_max_bottles_reached"), currentBottles, maxBottles), "error")
        return
    end
    newInstallState = {}
    newInstallState.inProgress = true
    newInstallState.vehicle = closestVehicle
    newInstallState.vehiclePlate = vehiclePlateCleaned
    newInstallState.itemName = itemName
    if itemData then
        newInstallState.itemSlot = itemData.slot
    else
        newInstallState.itemSlot = nil
    end
    newInstallState.currentStep = 1
    newInstallState.steps = {}
    installState = newInstallState
    stepsSetup = {}
    stepsSetup[1] = {
        type = "requirement",
        requirement = "hoodOpen",
        label = t("open_hood"),
        progressLabel = t("opening_hood")
    }
    stepsSetup[2] = {
        type = "minigame",
        name = "tool_matching",
        label = t("nitro_step_brackets")
    }
    stepsSetup[3] = {
        type = "minigame",
        name = "cable_routing",
        label = t("nitro_step_lines")
    }
    stepsSetup[4] = {
        type = "progress",
        duration = 5000,
        label = t("nitro_step_mounting")
    }
    installState.steps = stepsSetup
    isInstallFlowStarted = false
    if InstallFlow then
        if InstallFlow.Start then
            if not InstallFlow.IsActive() then
                isInstallFlowStarted = InstallFlow.Start(InstallRecipes.nitro_install({}), {vehicle = closestVehicle})
            end
        end
    end
    if not isInstallFlowStarted then
        State.repairInProgress = true
        OpenNitroInstallMenu()
    end
end

RegisterNetEvent("nn_mechanic:nitro:beginInstall", function(itemName, itemData)
    BeginNitroInstallation(itemName, itemData)
end)

for stepIndex = 1, 10 do
    RegisterNUICallback("nitroInstallStep_" .. stepIndex, function(data, cb)
        if not installState.inProgress then
            cb({success = false})
            return
        end
        if installState.currentStep ~= stepIndex then
            cb({success = false})
            return
        end
        Citizen.CreateThread(function()
            local allStepsCompleted = ExecuteCurrentInstallStep()
            if allStepsCompleted then
                FinalizeNitroInstallation()
            end
        end)
        cb({success = true})
    end)
end

RegisterNUICallback("nitro:cancel", function(data, cb)
    CloseNitroInstallMenu()
    bridge.Notify.SendNotify(t("nitro_install_cancelled"), "inform")
    ResetNitroInstallState()
    cb({success = true})
end)

if Config.Debug then
    RegisterCommand("testnitro", function(source, args)
        local itemNameArg = args[1]
        if not itemNameArg then
            itemNameArg = "nitro_bottle_small"
        end
        BeginNitroInstallation(itemNameArg, nil)
    end, false)
end