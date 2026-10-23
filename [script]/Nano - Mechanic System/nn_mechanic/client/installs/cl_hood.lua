-- Hood Swap System for Mechanic Job
-- Handles hood replacement/installation process with step-by-step instructions

-- Open hood swap menu
local function openHoodMenu(menuItems)
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = "setMenuData",
        data = {
            menuId = "hood_menu",
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
    
    State.openPage = "menu"
    State.currentMenuId = "hood_menu"
    StartMenuControlsThread()
end

-- Close hood menu
local function closeHoodMenu()
    if State.openPage == "menu" then
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

-- Build hood swap menu items based on current instruction step
function BuildHoodSwapMenuItems()
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        return {}
    end
    
    local currentStep = GetCurrentInstructionStep()
    if not currentStep then
        return {}
    end
    
    local instructions = StateInstructions.currentInstructions or {}
    
    -- Define step callbacks and icons
    local stepCallbacks = {
        [1] = { cb = "hoodRemoveOld", icon = "fas fa-wrench" },
        [2] = { cb = "hoodHintDeposit", icon = "fas fa-box" },
        [3] = { cb = "hoodHintUseNew", icon = "fas fa-box-open" }
    }
    
    local menuItems = {}
    
    for stepIndex, instruction in ipairs(instructions) do
        local isCompleted = instruction.completed == true
        local isFutureStep = stepIndex > currentStep
        local isCurrentStep = stepIndex == currentStep
        
        -- Determine icon
        local icon
        if isCompleted then
            icon = "fas fa-check-circle"
        elseif isFutureStep then
            icon = "fas fa-lock"
        elseif stepCallbacks[stepIndex] and stepCallbacks[stepIndex].icon then
            icon = stepCallbacks[stepIndex].icon
        else
            icon = "fas fa-circle"
        end
        
        -- Format label
        local stepTitle = instruction.title or string.format("Step %d", stepIndex)
        local label = string.format("%d. %s", stepIndex, stepTitle)
        
        -- Determine if disabled and callback
        local disabled = isCompleted or isFutureStep
        local nuiCallback = nil
        
        if isCurrentStep and stepCallbacks[stepIndex] then
            nuiCallback = stepCallbacks[stepIndex].cb
            disabled = false
        end
        
        table.insert(menuItems, {
            label = label,
            icon = icon,
            nuiCallback = nuiCallback,
            callbackData = {},
            disabled = disabled
        })
    end
    
    return menuItems
end

-- Refresh hood swap menu
local function refreshHoodSwapMenu()
    -- Check if InstallFlow is active
    if InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
        return
    end
    
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        return
    end
    
    if State.openPage == "product-tag" then
        return
    end
    
    if State.openPage == "menu" and State.currentMenuId and State.currentMenuId ~= "hood_menu" then
        return
    end
    
    local menuItems = BuildHoodSwapMenuItems()
    if #menuItems == 0 then
        return
    end
    
    openHoodMenu(menuItems)
end

-- Start hood swap process
local function startHoodSwapInternal(vehicle, expectedReferenceNumber, onComplete)
    -- Check if repair already in progress
    if State.repairInProgress or (InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive()) then
        local errorMessage = t("repair_in_progress") or "Repair already in progress"
        bridge.Notify.SendNotify(errorMessage, "error")
        if onComplete then
            onComplete(false)
        end
        return
    end
    
    -- Validate vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if onComplete then
            onComplete(false)
        end
        return
    end
    
    -- Initialize hood swap state
    State.hoodSwap = {
        inProgress = true,
        vehicle = vehicle,
        vehicleNetId = VehToNet(vehicle),
        expectedNewHoodReferenceNumber = expectedReferenceNumber,
        waitingForHood = false,
        removedHoodProp = nil,
        onComplete = onComplete
    }
    
    -- Set up instructions
    StateInstructions.currentInstructions = {
        [1] = {
            title = t("hood_step_remove_old") or "Remove Old Hood",
            description = t("hood_step_remove_old_desc") or "Remove the existing hood from the vehicle",
            completed = false
        },
        [2] = {
            title = t("hood_step_deposit") or "Deposit Old Hood",
            description = t("hood_step_deposit_desc") or "Deposit the old hood at a storage unit",
            completed = false
        },
        [3] = {
            title = t("hood_step_install_new") or "Install New Hood",
            description = t("hood_step_install_new_desc") or "Install the new hood on the vehicle",
            completed = false
        }
    }
    
    -- Start InstallFlow if available
    local flowStarted = false
    if InstallFlow and InstallFlow.Start and not InstallFlow.IsActive() then
        local recipe = InstallRecipes and InstallRecipes.hood_swap({})
        if recipe then
            flowStarted = InstallFlow.Start(recipe, { vehicle = vehicle })
        end
    end
    
    if not flowStarted then
        State.repairInProgress = true
        refreshHoodSwapMenu()
        
        -- Start refresh thread
        Citizen.CreateThread(function()
            while State.hoodSwap and State.hoodSwap.inProgress do
                refreshHoodSwapMenu()
                Wait(300)
            end
        end)
    end
end

-- Public function: Start hood swap
function startHoodSwap(referenceNumber, callback)
    if not referenceNumber or referenceNumber == "" then
        local errorMessage = t("reference_number_required") or "Reference number required"
        bridge.Notify.SendNotify(errorMessage, "error")
        if callback then
            callback(false)
        end
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 6.0, 0, 70)
    
    if not DoesEntityExist(nearestVehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if callback then
            callback(false)
        end
        return
    end
    
    startHoodSwapInternal(nearestVehicle, referenceNumber, callback)
end

-- Debug command
if Config.Debug then
    RegisterCommand("change_hood", function(_, args)
        local referenceNumber = args[1]
        if not referenceNumber or referenceNumber == "" then
            local errorMessage = t("reference_number_required") or "Reference number required"
            bridge.Notify.SendNotify(errorMessage, "error")
            return
        end
        startHoodSwap(referenceNumber)
    end, false)
end

-- Cleanup hood swap
local function cleanupHoodSwap()
    if State.hoodSwap and State.hoodSwap.removedHoodProp then
        if DoesEntityExist(State.hoodSwap.removedHoodProp) then
            DeleteEntity(State.hoodSwap.removedHoodProp)
        end
        State.hoodSwap.removedHoodProp = nil
    end
    
    State.hoodSwap = nil
    State.repairInProgress = false
end

-- NUI: Remove old hood
RegisterNUICallback("hoodRemoveOld", function(_, cb)
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = State.hoodSwap.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        cb({ success = false })
        return
    end
    
    closeHoodMenu()
    
    -- Load animation dictionary
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end
    
    -- Prepare ped for animation
    local playerPed = PlayerPedId()
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)
    
    -- Show progress bar
    local success = bridge.ProgressBar.Open({
        duration = 7000,
        label = t("hood_progress_remove") or "Removing hood...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = animDict,
            clip = "machinic_loop_mechandplayer",
            flag = 1
        }
    })
    
    SetPedCanRagdoll(playerPed, true)
    
    if not success then
        cb({ success = false })
        return
    end
    
    -- Break the hood door
    SetVehicleDoorBroken(vehicle, 4, true)
    
    -- Create hood prop
    local hoodModel = GetHashKey("imp_prop_impexp_bonnet_02a")
    RequestModel(hoodModel)
    while not HasModelLoaded(hoodModel) do
        Wait(50)
    end
    
    -- Load carry animation
    local carryAnimDict = "anim@heists@box_carry@"
    RequestAnimDict(carryAnimDict)
    while not HasAnimDictLoaded(carryAnimDict) do
        Wait(50)
    end
    
    -- Play carry idle animation
    TaskPlayAnim(playerPed, carryAnimDict, "idle", 8.0, -8.0, -1, 51, 0, false, false, false)
    
    -- Attach hood prop to ped
    local hoodProp = CreateObject(hoodModel, 0.0, 0.0, 0.0, true, true, false)
    SetEntityAsMissionEntity(hoodProp, true, true)
    AttachEntityToEntity(hoodProp, playerPed, GetPedBoneIndex(playerPed, 60309),
        0.15, 0.15, 0.0, 0.0, 90.0, 0.0, true, true, false, true, 2, true)
    
    State.hoodSwap.removedHoodProp = hoodProp
    
    -- Complete step 1
    CompleteInstructionStep(1)
    refreshHoodSwapMenu()
    
    cb({ success = true })
end)

-- NUI: Show deposit hint
RegisterNUICallback("hoodHintDeposit", function(_, cb)
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        cb({ success = false })
        return
    end
    
    local message = t("hood_go_to_deposit") or "Go to storage deposit and deposit the hood"
    bridge.Notify.SendNotify(message, "info")
    
    cb({ success = true })
end)

-- Deposit hood at storage
function DepositHoodAtStorage()
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        return false
    end
    
    local currentStep = GetCurrentInstructionStep()
    if currentStep ~= 2 then
        return false
    end
    
    local hoodProp = State.hoodSwap.removedHoodProp
    if not hoodProp or not DoesEntityExist(hoodProp) then
        return false
    end
    
    -- Delete the prop
    DeleteEntity(hoodProp)
    State.hoodSwap.removedHoodProp = nil
    
    -- Clear ped tasks
    ClearPedTasksImmediately(PlayerPedId())
    
    -- Complete step 2
    CompleteInstructionStep(2)
    State.hoodSwap.waitingForHood = true
    
    refreshHoodSwapMenu()
    
    return true
end

-- NUI: Show use new hood hint
RegisterNUICallback("hoodHintUseNew", function(_, cb)
    if not State.hoodSwap or not State.hoodSwap.inProgress then
        cb({ success = false })
        return
    end
    
    local message = t("hood_use_new_item") or "Use the new hood item from your inventory, then click Install"
    bridge.Notify.SendNotify(message, "info")
    
    cb({ success = true })
end)

-- Install hood from inventory
function InstallHoodFromInventory(itemData, inventoryData, itemName)
    if not State.hoodSwap or not State.hoodSwap.inProgress or not State.hoodSwap.waitingForHood then
        return false
    end
    
    local vehicle = State.hoodSwap.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    
    local expectedRefNumber = State.hoodSwap.expectedNewHoodReferenceNumber
    local actualRefNumber = (inventoryData and (inventoryData.referenceNumber or inventoryData.reference)) or nil
    local actualItemName = (itemData and (itemData.name or itemData.item)) or "mechanic_hood"
    
    -- Validate reference number
    local isValidItem = false
    if expectedRefNumber and expectedRefNumber ~= "" and actualRefNumber ~= expectedRefNumber then
        if IsValidPartItem(7, expectedRefNumber, inventoryData, actualItemName) then
            isValidItem = true
        else
            local errorMessage = (t("wrong_reference_number") or "Wrong reference number") .. ": " .. tostring(expectedRefNumber)
            bridge.Notify.SendNotify(errorMessage, "error")
            return false
        end
    end
    
    closeHoodMenu()
    
    -- Load animation
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end
    
    local playerPed = PlayerPedId()
    ClearPedTasksImmediately(playerPed)
    SetPedCanRagdoll(playerPed, false)
    
    -- Show installation progress
    local success = bridge.ProgressBar.Open({
        duration = 8000,
        label = t("hood_progress_install") or "Installing new hood...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = animDict,
            clip = "work2_base",
            flag = 1
        }
    })
    
    SetPedCanRagdoll(playerPed, true)
    
    if not success then
        return false
    end
    
    -- Get mod index
    local modIndex = tonumber(inventoryData and inventoryData.modIndex)
    if isValidItem and modIndex == nil and expectedRefNumber and expectedRefNumber ~= "" then
        local _, decodedIndex = decodeReferenceNumber(expectedRefNumber)
        modIndex = decodedIndex
    end
    
    if modIndex == nil then
        return false
    end
    
    -- Apply the mod
    SetVehicleModKit(vehicle, 0)
    SetVehicleMod(vehicle, 7, modIndex, false)
    
    -- Save vehicle properties
    local vehicleProps = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
    setVehicleProperties(vehicle, vehicleProps)
    
    -- Fix the vehicle
    SetVehicleFixed(vehicle)
    
    -- Remove item from inventory if slot provided
    if inventoryData and inventoryData.slot then
        TriggerServerEvent("nn_mechanic:removePartItem", actualItemName, inventoryData.slot)
    end
    
    -- Complete the process
    State.hoodSwap.waitingForHood = false
    CompleteInstructionStep(3)
    
    local onComplete = State.hoodSwap.onComplete
    State.hoodSwap.inProgress = false
    
    cleanupHoodSwap()
    
    if InstallFlow and InstallFlow.IsActive and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
    end
    
    if onComplete then
        onComplete(true)
    end
    
    return true
end

-- Cleanup on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    cleanupHoodSwap()
end)