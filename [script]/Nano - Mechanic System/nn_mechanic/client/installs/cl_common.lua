local commonRepairState = {
    inProgress = false,
    vehicle = nil,
    vehicleNetId = nil,
    modId = nil,
    modIndex = nil,
    currentStep = 1,
    steps = nil,
    prop = nil,
    waitingForDeposit = false,
    waitingForInstall = false,
    expectedReferenceNumber = nil,
    hasValidPart = false,
}
_G.commonRepairState = commonRepairState

local MECHANIC_ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local MECHANIC_ANIM_NAME = "machinic_loop_mechandplayer"

local StartMechanicAlphaAnimFunc
local ClearMechanicAlphaAnimFunc
local ResetCommonRepairStateFunc
local IsCommonRepairActiveFunc
local GetCurrentRepairStepFunc
local GetNextRepairStepFunc
local BuildCommonRepairMenuItemsFunc
local ShowCommonRepairMenuFunc
local HideCommonRepairMenuFunc
local AdvanceToNextStepFunc
local RunMinigameFunc
local AttachRepairPropFunc
local RunProgressBarStepFunc
local RunInstallStepFunc
local RunStepFunc
local ValidateCommonRepairPartFunc
local GetCommonRepairPartNameFunc
local CommonRepairItemMatchesPartEventFunc
local ExecuteCommonRepairInstallFunc
local DepositCommonRepairPartFunc
local StartChangeFunc
local CommonRepairActionNuiCallback
local TestCommonRepairCommand

StartMechanicAlphaAnimFunc = function(ped)
    if not ped then
        if State and State.Ped then
            ped = State.Ped
        else
            ped = PlayerPedId()
        end
    end

    if not ped or not DoesEntityExist(ped) then
        return
    end

    RequestAnimDict(MECHANIC_ANIM_DICT)
    while not HasAnimDictLoaded(MECHANIC_ANIM_DICT) do
        Wait(10)
    end

    TaskPlayAnim(ped, MECHANIC_ANIM_DICT, MECHANIC_ANIM_NAME, 4.0, 4.0, -1, 1, 0, false, false, false)
end
_G.StartMechanicAlphaAnim = StartMechanicAlphaAnimFunc

ClearMechanicAlphaAnimFunc = function(ped)
    if not ped then
        if State and State.Ped then
            ped = State.Ped
        else
            ped = PlayerPedId()
        end
    end

    if ped and DoesEntityExist(ped) then
        ClearPedTasksImmediately(ped)
    end
end
_G.ClearMechanicAlphaAnim = ClearMechanicAlphaAnimFunc

ResetCommonRepairStateFunc = function()
    if commonRepairState.prop and DoesEntityExist(commonRepairState.prop) then
        DeleteEntity(commonRepairState.prop)
    end

    local newCommonRepairState = {
        inProgress = false,
        vehicle = nil,
        vehicleNetId = nil,
        modId = nil,
        modIndex = nil,
        currentStep = 1,
        steps = nil,
        prop = nil,
        waitingForDeposit = false,
        waitingForInstall = false,
        expectedReferenceNumber = nil,
        hasValidPart = false,
    }
    commonRepairState = newCommonRepairState
    _G.commonRepairState = commonRepairState

    if State then
        State.repairInProgress = false
    end

    if bridge and bridge.HelpText and bridge.HelpText.HideHelpText then
        bridge.HelpText.HideHelpText()
    end

    if InstallFlow and InstallFlow.IsActive then
        if InstallFlow.IsActive() then
            if InstallFlow.SyncUI then
                InstallFlow.SyncUI()
            end
        end
    end
end

IsCommonRepairActiveFunc = function()
    return commonRepairState and commonRepairState.inProgress
end
_G.IsCommonRepairActive = IsCommonRepairActiveFunc

GetCurrentRepairStepFunc = function()
    if commonRepairState and commonRepairState.steps and commonRepairState.currentStep then
        return commonRepairState.steps[commonRepairState.currentStep]
    end
    return nil
end

GetNextRepairStepFunc = function()
    if not commonRepairState or not commonRepairState.steps then
        return nil
    end

    local nextStepIndex = commonRepairState.currentStep + 1
    if nextStepIndex > #commonRepairState.steps then
        return nil
    end

    return commonRepairState.steps[nextStepIndex]
end

BuildCommonRepairMenuItemsFunc = function()
    local menuItems = {}
    if not commonRepairState or not commonRepairState.steps then
        return menuItems
    end

    for stepIndex, stepData in ipairs(commonRepairState.steps) do
        local isCompleted = stepIndex < commonRepairState.currentStep
        local isCurrent = stepIndex == commonRepairState.currentStep
        local isLocked = stepIndex > commonRepairState.currentStep
        local icon = "fas fa-circle"

        if isCompleted then
            icon = "fas fa-check-circle"
        elseif isLocked then
            icon = "fas fa-lock"
        else
            if stepData.type == "remove" then
                icon = "fas fa-wrench"
            elseif stepData.type == "deposit" then
                icon = "fas fa-box"
            elseif stepData.type == "install" then
                icon = "fas fa-plus-circle"
            end
        end

        local label = stepData.menuLabel
        if not label then
            if stepData.progressbar and stepData.progressbar.label then
                label = stepData.progressbar.label
            else
                label = "Step " .. stepIndex
            end
        end

        label = string.format("%d. %s", stepIndex, label)

        local itemNuiCallback = nil
        if isCurrent and (stepData.type ~= "deposit") then
            itemNuiCallback = "commonRepairAction"
        end

        local itemDisabled = isCompleted or isLocked
        if not isCompleted and not isLocked then
            itemDisabled = (stepData.type == "deposit")
        end

        if isCurrent and stepData.type == "install" then
            local t_use_part = t and t("use_part_from_inventory") or "Use part from inventory"
            label = label .. " - " .. t_use_part
        end

        table.insert(menuItems, {
            label = label,
            icon = icon,
            nuiCallback = itemNuiCallback,
            callbackData = {
                stepIndex = stepIndex,
            },
            disabled = itemDisabled,
        })
    end
    return menuItems
end
_G.BuildCommonRepairMenuItems = BuildCommonRepairMenuItemsFunc

ShowCommonRepairMenuFunc = function()
    if not commonRepairState or not commonRepairState.inProgress then
        dprint("[common_repair] ShowCommonRepairMenu skipped: not inProgress")
        return
    end

    if InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive() then
        dprint("[common_repair] ShowCommonRepairMenu -> InstallFlow.SyncUI()")
        if InstallFlow.SyncUI then
            InstallFlow.SyncUI()
        end
        return
    end

    dprint("[common_repair] ShowCommonRepairMenu -> legacy menu render")

    local menuItems = BuildCommonRepairMenuItemsFunc()

    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "common_repair_menu",
            items = menuItems,
        },
    })
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "menu",
        },
    })

    if State then
        State.openPage = "menu"
        State.currentMenuId = "common_repair_menu"
    end
    StartMenuControlsThread()
end

HideCommonRepairMenuFunc = function()
    if InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive() then
        if State and State.openPage == "menu" and State.currentMenuId == "install_flow_menu" then
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = false,
                    page = "menu",
                },
            })
            State.openPage = nil
            State.currentMenuId = nil
        end
        return
    end

    if State and State.openPage == "menu" and State.currentMenuId == "common_repair_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = false,
                page = "menu",
            },
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
end

AdvanceToNextStepFunc = function()
    if not commonRepairState then return false end

    commonRepairState.currentStep = commonRepairState.currentStep + 1

    local totalSteps = commonRepairState.steps and #commonRepairState.steps or 0
    dprint(string.format("[common_repair] AdvanceToNextStep -> currentStep=%d / %d", commonRepairState.currentStep, totalSteps))

    if commonRepairState.currentStep > totalSteps then
        return true
    end

    local currentStepData = commonRepairState.steps[commonRepairState.currentStep]
    if currentStepData and currentStepData.type == "install" then
        local vehicle = commonRepairState.vehicle
        local modId = commonRepairState.modId
        local modIndex = commonRepairState.modIndex

        if vehicle and DoesEntityExist(vehicle) then
            local vehicleModel = GetEntityModel(vehicle)
            commonRepairState.expectedReferenceNumber = generateReferenceNumber(modId, modIndex, vehicleModel)
            commonRepairState.waitingForInstall = true
            commonRepairState.hasValidPart = false

            local notify_msg = t and t("use_correct_part_item") or "Use the correct part item from your inventory"
            if bridge and bridge.Notify and bridge.Notify.SendNotify then
                bridge.Notify.SendNotify(notify_msg, "info")
            end

            if bridge and bridge.HelpText and bridge.HelpText.ShowHelpText then
                bridge.HelpText.ShowHelpText(notify_msg)
            end
        end
    end

    ShowCommonRepairMenuFunc()
    return false
end

RunMinigameFunc = function(minigameType)
    if not minigameType then
        return true
    end

    if minigameType == "key_press_timing" then
        return StartKeyPressMinigame()
    elseif minigameType == "tool_matching" then
        return StartToolMatchingMinigame()
    elseif minigameType == "cable_routing" then
        return StartCableRoutingMinigame()
    end

    return true
end

AttachRepairPropFunc = function(stepData)
    if not stepData or not stepData.propAttach then
        return
    end

    local propModelHash = GetHashKey(stepData.propAttach.prop)
    RequestModel(propModelHash)
    while not HasModelLoaded(propModelHash) do
        Wait(50)
    end

    local animDict = "anim@heists@box_carry@"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end

    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 51, 0, false, false, false)

    local pedCoords = GetEntityCoords(playerPed)
    local propZ = pedCoords.z + 0.2
    local prop = CreateObject(propModelHash, pedCoords.x, pedCoords.y, propZ, false, false, false)

    local boneId = stepData.propAttach.bone or 60309
    local offsetCoords = stepData.propAttach.coords or {x = 0.0, y = 0.0, z = 0.0}
    local rotation = stepData.propAttach.rotation or {x = 0.0, y = 0.0, z = 0.0}

    AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, boneId),
        offsetCoords.x, offsetCoords.y, offsetCoords.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true)

    commonRepairState.prop = prop
end

RunProgressBarStepFunc = function(stepData)
    if not commonRepairState or not stepData or not stepData.progressbar then
        return false
    end

    HideCommonRepairMenuFunc()

    if stepData.minigame then
        local minigameSuccess = RunMinigameFunc(stepData.minigame)
        if not minigameSuccess then
            ShowCommonRepairMenuFunc()
            return false
        end
    end

    if stepData.progressbar.animation and stepData.progressbar.animation.dict then
        local animDict = stepData.progressbar.animation.dict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(50)
        end
    end

    ClearPedTasksImmediately(PlayerPedId())
    SetPedCanRagdoll(PlayerPedId(), false)

    local progressBarConfig = {
        duration = stepData.progressbar.duration or 5000,
        label = stepData.progressbar.label or (t and t("removing_part") or "Removing part"),
        canCancel = true,
        disable = {move = true, car = true, combat = true},
    }

    if stepData.progressbar.animation then
        progressBarConfig.anim = {
            dict = stepData.progressbar.animation.dict,
            clip = stepData.progressbar.animation.clip,
            flag = stepData.progressbar.animation.flag or 1,
        }
    end

    local progressSuccess = bridge.ProgressBar.Open(progressBarConfig)
    SetPedCanRagdoll(PlayerPedId(), true)

    if not progressSuccess then
        ShowCommonRepairMenuFunc()
        return false
    end

    local nextStepData = GetNextRepairStepFunc()
    if nextStepData and nextStepData.type == "deposit" then
        AttachRepairPropFunc(nextStepData)
        commonRepairState.waitingForDeposit = true
        local notify_msg = t and t("hood_go_to_deposit") or "Go to the storage deposit"
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify(notify_msg, "info")
        end
    end

    return true
end

RunInstallStepFunc = function(stepData)
    if not commonRepairState or not stepData or not stepData.progressbar then
        return false
    end

    HideCommonRepairMenuFunc()

    local vehicle = commonRepairState.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    if stepData.minigame then
        local minigameSuccess = RunMinigameFunc(stepData.minigame)
        if not minigameSuccess then
            ShowCommonRepairMenuFunc()
            return false
        end
    end

    if stepData.progressbar.animation and stepData.progressbar.animation.dict then
        local animDict = stepData.progressbar.animation.dict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(50)
        end
    end

    ClearPedTasksImmediately(PlayerPedId())
    SetPedCanRagdoll(PlayerPedId(), false)

    local progressBarConfig = {
        duration = stepData.progressbar.duration or 5000,
        label = stepData.progressbar.label or (t and t("installing_part") or "Installing part"),
        canCancel = true,
        disable = {move = true, car = true, combat = true},
    }

    if stepData.progressbar.animation then
        progressBarConfig.anim = {
            dict = stepData.progressbar.animation.dict,
            clip = stepData.progressbar.animation.clip,
            flag = stepData.progressbar.animation.flag or 1,
        }
    end

    local progressSuccess = bridge.ProgressBar.Open(progressBarConfig)
    SetPedCanRagdoll(PlayerPedId(), true)

    if not progressSuccess then
        ShowCommonRepairMenuFunc()
        return false
    end

    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, commonRepairState.modId, commonRepairState.modIndex, false)

    local vehicleProps = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
    setVehicleProperties(vehicle, vehicleProps)

    return true
end

RunStepFunc = function(stepIndex)
    if not commonRepairState or not commonRepairState.steps then
        return false
    end
    local stepData = commonRepairState.steps[stepIndex]
    if not stepData then
        return false
    end

    if stepData.type == "remove" then
        return RunProgressBarStepFunc(stepData)
    elseif stepData.type == "install" then
        return RunInstallStepFunc(stepData)
    end
    return false
end

ValidateCommonRepairPartFunc = function(referenceNumber, itemHash, itemName)
    if not commonRepairState or not commonRepairState.inProgress or not commonRepairState.waitingForInstall then
        return false, nil
    end

    local expectedReferenceNumber = commonRepairState.expectedReferenceNumber
    if not expectedReferenceNumber or expectedReferenceNumber == "" then
        commonRepairState.hasValidPart = true
        return true, nil
    end

    if referenceNumber == expectedReferenceNumber then
        commonRepairState.hasValidPart = true
        return true, nil
    end

    if commonRepairState.modId ~= nil and itemHash then
        if IsValidPartItem(commonRepairState.modId, expectedReferenceNumber, itemHash, itemName) then
            commonRepairState.hasValidPart = true
            return true, nil
        end
    end

    return false, expectedReferenceNumber
end
_G.ValidateCommonRepairPart = ValidateCommonRepairPartFunc

GetCommonRepairPartNameFunc = function()
    if not commonRepairState or not commonRepairState.inProgress then
        return nil
    end
    return ModIdToPartName[commonRepairState.modId]
end
_G.GetCommonRepairPartName = GetCommonRepairPartNameFunc

CommonRepairItemMatchesPartEventFunc = function(partName, itemHash)
    local expectedPartName = GetCommonRepairPartNameFunc()
    if not expectedPartName then
        return false
    end

    if partName == expectedPartName then
        return true
    end

    if itemHash then
        if ItemMatchesModId(itemHash, commonRepairState.modId) then
            return true
        end
    end

    return false
end
_G.CommonRepairItemMatchesPartEvent = CommonRepairItemMatchesPartEventFunc

ExecuteCommonRepairInstallFunc = function()
    if not commonRepairState or not commonRepairState.inProgress or not commonRepairState.waitingForInstall then
        return false
    end

    local currentStepData = GetCurrentRepairStepFunc()
    if not currentStepData or currentStepData.type ~= "install" then
        return false
    end

    if bridge and bridge.HelpText and bridge.HelpText.HideHelpText then
        bridge.HelpText.HideHelpText()
    end
    HideCommonRepairMenuFunc()

    local vehicle = commonRepairState.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        local notify_msg = t and t("vehicle_not_found") or "Vehicle not found"
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify(notify_msg, "error")
        end
        ShowCommonRepairMenuFunc()
        return false
    end

    if currentStepData.minigame then
        local minigameSuccess = RunMinigameFunc(currentStepData.minigame)
        if not minigameSuccess then
            ShowCommonRepairMenuFunc()
            return false
        end
    end

    if currentStepData.progressbar and currentStepData.progressbar.animation and currentStepData.progressbar.animation.dict then
        local animDict = currentStepData.progressbar.animation.dict
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(50)
        end
    end

    ClearPedTasksImmediately(PlayerPedId())
    SetPedCanRagdoll(PlayerPedId(), false)

    local progressBarConfig = {
        duration = (currentStepData.progressbar and currentStepData.progressbar.duration) or 5000,
        label = (currentStepData.progressbar and currentStepData.progressbar.label) or (t and t("installing_part") or "Installing part"),
        canCancel = false,
        disable = {move = true, car = true, combat = true},
    }

    if currentStepData.progressbar and currentStepData.progressbar.animation then
        progressBarConfig.anim = {
            dict = currentStepData.progressbar.animation.dict,
            clip = currentStepData.progressbar.animation.clip,
            flag = currentStepData.progressbar.animation.flag or 1,
        }
    end

    local progressSuccess = bridge.ProgressBar.Open(progressBarConfig)
    SetPedCanRagdoll(PlayerPedId(), true)
    ClearPedTasksImmediately(PlayerPedId())

    if not progressSuccess then
        ShowCommonRepairMenuFunc()
        return false
    end

    SetVehicleModKit(vehicle, 0)

    local modId = commonRepairState.modId
    local modIndex = commonRepairState.modIndex

    if modId == 50 then
        SetVehicleNumberPlateTextIndex(vehicle, modIndex or 0)
    elseif modId == 51 then
        SetVehicleWindowTint(vehicle, modIndex or 0)
    else
        SetVehicleMod(vehicle, modId, modIndex, false)
    end

    local vehicleProps = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
    setVehicleProperties(vehicle, vehicleProps)

    commonRepairState.waitingForInstall = false
    commonRepairState.expectedReferenceNumber = nil
    commonRepairState.hasValidPart = false

    local isComplete = AdvanceToNextStepFunc()
    if isComplete then
        ResetCommonRepairStateFunc()
    end

    return true, isComplete
end
_G.ExecuteCommonRepairInstall = ExecuteCommonRepairInstallFunc

DepositCommonRepairPartFunc = function()
    dprint(string.format("[common_repair] DepositCommonRepairPart entry inProgress=%s waitingForDeposit=%s currentStep=%s",
        tostring(commonRepairState.inProgress),
        tostring(commonRepairState.waitingForDeposit),
        tostring(commonRepairState.currentStep)))

    if not commonRepairState or not commonRepairState.inProgress or not commonRepairState.waitingForDeposit then
        return false
    end

    if commonRepairState.prop and DoesEntityExist(commonRepairState.prop) then
        DeleteEntity(commonRepairState.prop)
        commonRepairState.prop = nil
    end

    ClearPedTasksImmediately(PlayerPedId())
    SetPedCanRagdoll(PlayerPedId(), true)

    commonRepairState.waitingForDeposit = false
    local isComplete = AdvanceToNextStepFunc()

    dprint(string.format("[common_repair] DepositCommonRepairPart post-advance complete=%s currentStep=%s waitingForInstall=%s",
        tostring(isComplete),
        tostring(commonRepairState.currentStep),
        tostring(commonRepairState.waitingForInstall)))

    if isComplete then
        ResetCommonRepairStateFunc()
    end

    return true
end
_G.DepositCommonRepairPart = DepositCommonRepairPartFunc

local NUI_COMMON_REPAIR_ACTION = "commonRepairAction"
CommonRepairActionNuiCallback = function(data, cb)
    if not commonRepairState or not commonRepairState.inProgress then
        cb({success = false})
        return
    end

    local stepIndex = data and data.stepIndex or commonRepairState.currentStep

    if commonRepairState.currentStep ~= stepIndex then
        cb({success = false})
        return
    end

    local stepData = commonRepairState.steps and commonRepairState.steps[stepIndex]
    if not stepData then
        cb({success = false})
        return
    end

    if stepData.type == "deposit" then
        cb({success = false})
        return
    end

    local success = RunStepFunc(stepIndex)
    if success then
        local isComplete = AdvanceToNextStepFunc()
        if isComplete then
            ResetCommonRepairStateFunc()
            cb({success = true, complete = true})
            return
        end
    end
    cb({success = success})
end
RegisterNUICallback(NUI_COMMON_REPAIR_ACTION, CommonRepairActionNuiCallback)

StartChangeFunc = function(vehicle, modId, modIndex)
    if not (vehicle and DoesEntityExist(vehicle)) then
        local notify_msg = t and t("no_vehicle_found") or "No vehicle found"
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify(notify_msg, "error")
        end
        return false
    end

    if (State and State.repairInProgress) or (InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive()) then
        local notify_msg = t and t("repair_in_progress") or "A repair is already in progress"
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify(notify_msg, "error")
        end
        return false
    end

    if modId == 48 then
        if StartLiveryInstall then
            return StartLiveryInstall(vehicle, {modIndex = modIndex}) ~= false
        end
    end

    local configSteps = nil
    if Config and Config.GetCommonRepairConfig then
        configSteps = Config.GetCommonRepairConfig(modId)
    end
    if not configSteps and Config and Config.CommonRepairs then
        configSteps = Config.CommonRepairs[modId]
    end

    if not configSteps then
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify("No repair config found for this mod", "error")
        end
        return false
    end

    local steps = {}
    for i = 1, 10 do
        if configSteps[i] then
            table.insert(steps, configSteps[i])
        end
    end

    if #steps == 0 then
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify("No steps defined for this repair", "error")
        end
        return false
    end

    commonRepairState.inProgress = true
    commonRepairState.vehicle = vehicle
    commonRepairState.vehicleNetId = VehToNet(vehicle)
    commonRepairState.modId = modId
    commonRepairState.modIndex = modIndex
    commonRepairState.currentStep = 1
    commonRepairState.steps = steps
    commonRepairState.prop = nil
    commonRepairState.waitingForDeposit = false
    commonRepairState.waitingForInstall = false
    commonRepairState.expectedReferenceNumber = nil
    commonRepairState.hasValidPart = false

    local firstStep = steps[1]
    if firstStep and firstStep.type == "install" then
        local vehicleModel = GetEntityModel(vehicle)
        commonRepairState.expectedReferenceNumber = generateReferenceNumber(modId, modIndex, vehicleModel)
        commonRepairState.waitingForInstall = true
        local notify_msg = t and t("use_correct_part_item") or "Use the correct part item from your inventory"
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify(notify_msg, "info")
        end
    end

    if InstallFlow and InstallFlow.Start then
        local p = promise.new()
        local installRecipe = InstallRecipes.common({modId = modId})
        local installSuccess = InstallFlow.Start(installRecipe, {
            vehicle = vehicle,
            modId = modId,
            modIndex = modIndex,
            onComplete = function(flowSuccess)
                p:resolve(flowSuccess == true)
            end,
        })

        if not installSuccess then
            ResetCommonRepairStateFunc()
            return false
        end

        local result = Citizen.Await(p)

        if commonRepairState and commonRepairState.inProgress then
            ResetCommonRepairStateFunc()
        end
        return result
    end

    if State then
        State.repairInProgress = true
    end
    ShowCommonRepairMenuFunc()

    while commonRepairState and commonRepairState.inProgress do
        Citizen.Wait(100)
        if not commonRepairState.inProgress then break end
        if not commonRepairState.steps then break end
        if commonRepairState.currentStep > #commonRepairState.steps then break end
    end

    local repairCompleted = commonRepairState and (commonRepairState.currentStep > #commonRepairState.steps)
    ResetCommonRepairStateFunc()
    return repairCompleted
end
_G.StartChange = StartChangeFunc

local DEBUG_TEST_COMMON_REPAIR_COMMAND = "testcommonrepair"
TestCommonRepairCommand = function(source, args)
    local modId = tonumber(args[1]) or 0
    local modIndex = tonumber(args[2]) or 0

    local playerPed = PlayerPedId()
    local pedCoords = GetEntityCoords(playerPed)

    local closestVehicle = GetClosestVehicle(pedCoords.x, pedCoords.y, pedCoords.z, 5.0, 0, 70)

    if not DoesEntityExist(closestVehicle) then
        if bridge and bridge.Notify and bridge.Notify.SendNotify then
            bridge.Notify.SendNotify("No vehicle found nearby", "error")
        end
        return
    end

    local result = StartChangeFunc(closestVehicle, modId, modIndex)
    print("StartChange result:", result)
end

if Config and Config.Debug then
    RegisterCommand(DEBUG_TEST_COMMON_REPAIR_COMMAND, TestCommonRepairCommand, false)
end