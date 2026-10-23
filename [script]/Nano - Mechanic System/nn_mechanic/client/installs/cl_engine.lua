local ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local ANIM_CLIP = "machinic_loop_mechandplayer"

-- Animation helper
function PlayWorkingAnimation()
    local ped = PlayerPedId()
    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do
        Wait(50)
    end
    TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 4.0, 4.0, -1, 1, 0, false, false, false)
end

-- Load and request model
function RequestModelHash(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(50)
    end
    return hash
end

-- UI State Management
local currentMenuHash = nil

function CloseAllMenus()
    SetNuiFocus(false, false)
    State.openPage = nil
    State.currentMenuId = nil
    currentMenuHash = nil
end

function CloseCurrentMenu()
    if State.openPage == "menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
        currentMenuHash = nil
    end
end

-- Menu display helper
function ShowMenu(items)
    local menuHash = {}
    for i, item in ipairs(items) do
        local label = item.label or ""
        local icon = item.icon or ""
        local callback = item.nuiCallback or ""
        local disabled = tostring(item.disabled)
        menuHash[i] = label .. icon .. callback .. disabled
    end
    
    local newHash = table.concat(menuHash, "|")
    
    if newHash ~= currentMenuHash then
        currentMenuHash = newHash
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = "setMenuData",
            data = { menuId = "engine_menu", items = items }
        })
    end
    
    if State.openPage ~= "menu" or State.currentMenuId ~= "engine_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = true, page = "menu" }
        })
        State.openPage = "menu"
        State.currentMenuId = "engine_menu"
    end
    
    StartMenuControlsThread()
end

-- Find nearest storage location
function FindNearestStorageLocation(playerCoords)
    local allDepots = GetAllPartDepositCoords() or {}
    local nearestPos = nil
    local nearestDist = nil
    
    for _, pos in pairs(allDepots) do
        local dist = #(playerCoords - pos)
        if not nearestDist or nearestDist > dist then
            nearestDist = dist
            nearestPos = pos
        end
    end
    
    return nearestPos, nearestDist
end

-- Get vehicle hood position
function GetVehicleHoodPos(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return nil
    end
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 1.6, 0.6)
end

-- Check if two entities are near each other
function IsEntityNearEntity(entity1, entity2)
    if not entity1 or not entity2 or not DoesEntityExist(entity1) or not DoesEntityExist(entity2) then
        return false
    end
    local pos1 = GetEntityCoords(entity2)
    local pos2 = GetVehicleHoodPos(entity1)
    return #(pos1 - pos2) < 3.5
end

-- Check if player is near an entity
function IsPlayerNearEntity(entity, radius)
    if not entity or not DoesEntityExist(entity) then
        return false
    end
    radius = radius or 3.5
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    local entityPos = GetEntityCoords(entity)
    return #(playerPos - entityPos) <= radius
end

-- Get engine drop position
function GetEngineDropPosition(vehicle)
    local hoodPos = GetVehicleHoodPos(vehicle)
    if not hoodPos then
        return nil
    end
    local _, forward, right = GetEntityMatrix(vehicle)
    local dropPos = hoodPos + (right * 0.4) + (forward * -0.8)
    return dropPos
end

-- Open UI page
function OpenUIPage(page)
    TriggerScreenblurFadeIn(500)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = page }
    })
    State.openPage = page
    PlayWorkingAnimation()
end

-- Close UI page
function CloseUIPage(page)
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = page }
    })
    if State.openPage == page then
        State.openPage = nil
    end
    ClearPedTasks(PlayerPedId())
end

-- Create engine swap instruction steps
function CreateEngineSwapInstructions(completedSteps)
    completedSteps = completedSteps or {}
    
    return {
        {
            title = t("engine_swap_step_open_hood"),
            description = t("engine_swap_step_open_hood_desc"),
            completed = completedSteps[1] or false
        },
        {
            title = t("engine_swap_step_battery_disconnect"),
            description = t("engine_swap_step_battery_disconnect_desc"),
            completed = completedSteps[2] or false
        },
        {
            title = t("engine_swap_step_disconnect_components"),
            description = t("engine_swap_step_disconnect_components_desc"),
            completed = completedSteps[3] or false
        },
        {
            title = t("engine_swap_step_place_hoist"),
            description = t("engine_swap_step_place_hoist_desc"),
            completed = completedSteps[4] or false
        },
        {
            title = t("engine_swap_step_attach_old_engine"),
            description = t("engine_swap_step_attach_old_engine_desc"),
            completed = completedSteps[5] or false
        },
        {
            title = t("engine_swap_step_push_to_storage"),
            description = t("engine_swap_step_push_to_storage_desc"),
            completed = completedSteps[6] or false
        },
        {
            title = t("engine_swap_step_deposit_engine"),
            description = t("engine_swap_step_deposit_engine_desc"),
            completed = completedSteps[7] or false
        },
        {
            title = t("engine_swap_step_attach_new_engine"),
            description = t("engine_swap_step_attach_new_engine_desc"),
            completed = completedSteps[8] or false
        },
        {
            title = t("engine_swap_step_push_back"),
            description = t("engine_swap_step_push_back_desc"),
            completed = completedSteps[9] or false
        },
        {
            title = t("engine_swap_step_lower_engine"),
            description = t("engine_swap_step_lower_engine_desc"),
            completed = completedSteps[10] or false
        },
        {
            title = t("engine_swap_step_reconnect_components"),
            description = t("engine_swap_step_reconnect_components_desc"),
            completed = completedSteps[11] or false
        },
        {
            title = t("engine_swap_step_reattach_hood"),
            description = t("engine_swap_step_reattach_hood_desc"),
            completed = completedSteps[12] or false
        }
    }
end

-- Cleanup engine swap
function CleanupEngineSwap()
    local swap = State.engineSwap
    if swap then
        if swap.hoistEntity and DoesEntityExist(swap.hoistEntity) then
            DeleteEntity(swap.hoistEntity)
        end
        if swap.enginePropEntity and DoesEntityExist(swap.enginePropEntity) then
            DeleteEntity(swap.enginePropEntity)
        end
    end
    State.engineSwap = nil
    State.repairInProgress = false
end

-- Smooth entity movement
function SmoothMoveEntity(entity, targetPos, duration, startPos)
    if not entity or not DoesEntityExist(entity) then
        return
    end
    
    duration = duration or 1200
    startPos = startPos or GetEntityCoords(entity)
    local startTime = GetGameTimer()
    
    while true do
        local elapsed = GetGameTimer() - startTime
        local t = elapsed / duration
        if t >= 1.0 then
            break
        end
        
        local newX = startPos.x + (targetPos.x - startPos.x) * t
        local newY = startPos.y + (targetPos.y - startPos.y) * t
        local newZ = startPos.z + (targetPos.z - startPos.z) * t
        
        SetEntityCoords(entity, newX, newY, newZ, false, false, false, true)
        Wait(0)
    end
    
    SetEntityCoords(entity, targetPos.x, targetPos.y, targetPos.z, false, false, false, true)
end

-- Push hoist functionality
function PushHoist(targetPos, onComplete)
    local swap = State.engineSwap
    if not swap or not swap.hoistEntity or not DoesEntityExist(swap.hoistEntity) then
        return false
    end
    
    if swap.pushing then
        return false
    end
    
    local ped = PlayerPedId()
    local hoist = swap.hoistEntity
    
    RequestAnimDict("missfinale_c2ig_11")
    while not HasAnimDictLoaded("missfinale_c2ig_11") do
        Wait(100)
    end
    
    TaskPlayAnim(ped, "missfinale_c2ig_11", "pushcar_offcliff_m", 4.0, 4.0, -1, 51, 0, false, false, false)
    DetachEntity(hoist, true, true)
    FreezeEntityPosition(hoist, true)
    SetEntityCollision(hoist, false, false)
    
    swap.pushing = true
    swap.pushTarget = targetPos
    
    Citizen.CreateThread(function()
        while State.engineSwap and State.engineSwap.pushing do
            local pedPos = GetEntityCoords(ped)
            local forwardVec = GetEntityForwardVector(ped)
            local targetPos = pedPos + (forwardVec * 1.6)
            
            local groundZ = targetPos.z
            local foundGround, groundZVal = GetGroundZFor_3dCoord(targetPos.x, targetPos.y, targetPos.z + 2.0, false)
            if foundGround then
                groundZ = groundZVal
            end
            
            SetEntityCoords(hoist, targetPos.x, targetPos.y, groundZ, false, false, false, true)
            SetEntityHeading(hoist, GetEntityHeading(ped) + 180.0)
            PlaceObjectOnGroundProperly(hoist)
            
            if #(GetEntityCoords(ped) - targetPos) < 1.75 then
                break
            end
            
            Wait(10)
        end
        
        if State.engineSwap then
            ClearPedTasks(ped)
            State.engineSwap.pushing = false
            State.engineSwap.pushTarget = nil
            if onComplete then
                onComplete()
            end
        end
    end)
    
    return true
end

-- Build engine swap menu items
function BuildEngineSwapMenuItems()
    local swap = State.engineSwap
    if not swap or not swap.inProgress or swap.pushing then
        return {}
    end
    
    local currentStep = GetCurrentInstructionStep()
    if not currentStep then
        return {}
    end
    
    local instructions = StateInstructions.currentInstructions or {}
    
    local stepCallbacks = {
        [1] = { cb = "engineOpenHood", icon = "fas fa-car" },
        [2] = { cb = "engineBatteryDisconnect", icon = "fas fa-car-battery" },
        [3] = { cb = "engineDisconnectComponents", icon = "fas fa-plug" },
        [4] = { cb = "enginePlaceHoist", icon = "fas fa-wrench" },
        [5] = { cb = "engineAttachOldEngine", icon = "fas fa-link" },
        [6] = { cb = "enginePushToStorage", icon = "fas fa-truck-moving" },
        [7] = { cb = "engineWaitDeposit", icon = "fas fa-box" },
        [8] = { cb = "engineAttachNewEngine", icon = "fas fa-box-open" },
        [9] = { cb = "enginePushBack", icon = "fas fa-truck-moving" },
        [10] = { cb = "engineLowerEngine", icon = "fas fa-arrow-down" },
        [11] = { cb = "engineReconnectComponents", icon = "fas fa-plug" },
        [12] = { cb = "engineReattachHood", icon = "fas fa-wrench" }
    }
    
    local menuItems = {}
    
    for stepNum, instruction in ipairs(instructions) do
        local completed = instruction.completed == true
        local isCurrent = stepNum == currentStep
        local isLocked = stepNum > currentStep
        
        local icon
        if completed then
            icon = "fas fa-check-circle"
        elseif isLocked then
            icon = "fas fa-lock"
        elseif stepCallbacks[stepNum] and stepCallbacks[stepNum].icon then
            icon = stepCallbacks[stepNum].icon
        else
            icon = "fas fa-circle"
        end
        
        local title = string.format("%d. %s", stepNum, instruction.title or ("Step " .. stepNum))
        local disabled = completed or isLocked
        local callback = nil
        
        if isCurrent and not disabled then
            callback = stepCallbacks[stepNum] and stepCallbacks[stepNum].cb
            disabled = false
        end
        
        -- Special handling for step 4 (hoist placement)
        if stepNum == 4 then
            if swap.placingHoist then
                disabled = true
                callback = nil
            elseif swap.hoistEntity and DoesEntityExist(swap.hoistEntity) then
                if currentStep == 5 then
                    disabled = false
                    callback = "enginePlaceHoist"
                    icon = "fas fa-arrows-rotate"
                    title = string.format("%d. %s", stepNum, t("engine_swap_step_replace_hoist") or "Re-place Hoist")
                else
                    disabled = true
                    callback = nil
                end
            end
        end
        
        -- Special handling for push steps
        if stepNum == 6 or stepNum == 9 then
            if swap.pushing then
                disabled = true
                callback = nil
            end
        end
        
        table.insert(menuItems, {
            label = title,
            icon = icon,
            nuiCallback = callback,
            callbackData = {},
            disabled = disabled
        })
    end
    
    return menuItems
end

-- Check and show engine menu
function CheckAndShowEngineMenu()
    if InstallFlow and InstallFlow.IsActive() then
        InstallFlow.SyncUI()
        return
    end
    
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        return
    end
    
    local openPage = State.openPage
    if openPage == "product-tag" or openPage == "battery-disconnect" or 
       openPage == "disconnecting-minigame" or openPage == "connecting-minigame" then
        return
    end
    
    if openPage == "menu" and State.currentMenuId and State.currentMenuId ~= "engine_menu" then
        return
    end
    
    local items = BuildEngineSwapMenuItems()
    if #items == 0 then
        return
    end
    
    ShowMenu(items)
end

-- Start engine swap process
function startEngineSwap(referenceNumber, callback)
    if State.repairInProgress or (InstallFlow and InstallFlow.IsActive()) then
        bridge.Notify.SendNotify(t("repair_in_progress") or "Repair already in progress", "error")
        if callback then callback(false) end
        return
    end
    
    local vehicle = GetClosestVehicle(GetEntityCoords(PlayerPedId()), 6.0, 0, 70)
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if callback then callback(false) end
        return
    end
    
    local vehicleProps = getVehicleProperties(vehicle)
    
    State.engineSwap = {
        inProgress = true,
        vehicle = vehicle,
        vehicleNetId = VehToNet(vehicle),
        originalVehicleProps = vehicleProps,
        expectedNewEngineReferenceNumber = referenceNumber,
        hoistEntity = nil,
        placingHoist = false,
        enginePropEntity = nil,
        removedEngineRef = nil,
        installedEngineModIndex = nil,
        pushing = false,
        pushTarget = nil,
        onComplete = callback
    }
    
    StateInstructions.currentInstructions = CreateEngineSwapInstructions({})
    
    if InstallFlow and InstallFlow.Start then
        local started = InstallFlow.Start(InstallRecipes.engine_swap({}), { vehicle = vehicle })
        if started then
            return
        end
    end
    
    State.repairInProgress = true
    CheckAndShowEngineMenu()
    
    Citizen.CreateThread(function()
        while State.engineSwap and State.engineSwap.inProgress do
            CheckAndShowEngineMenu()
            Wait(300)
        end
    end)
end

-- Place engine hoist
function PlaceEngineHoist(callback)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        bridge.Notify.SendNotify(t("start_engine_swap_first") or "Start an engine swap first", "error")
        if callback then callback({ success = false }) end
        return
    end
    
    if swap.placingHoist then
        if callback then callback({ success = false }) end
        return
    end
    
    local hasHoist = swap.hoistEntity and DoesEntityExist(swap.hoistEntity)
    local currentStep = GetCurrentInstructionStep()
    local canPlace = (not hasHoist and currentStep == 4) or (hasHoist and currentStep == 5)
    
    if not canPlace then
        if not hasHoist then
            bridge.Notify.SendNotify(t("engine_hoist_wrong_step") or "You can only place the hoist during the hoist placement step", "error")
        end
        if callback then callback({ success = false }) end
        return
    end
    
    swap.placingHoist = true
    CloseCurrentMenu()
    Wait(100)
    
    if not State.engineSwap or not State.engineSwap.inProgress then
        if callback then callback({ success = false }) end
        return
    end
    
    local success, pos, heading = bridge.Placeable.PlaceObject("imp_prop_engine_hoist_02a", 8.0, true)
    CloseAllMenus()
    
    if not success then
        bridge.Notify.SendNotify(t("engine_hoist_placement_cancelled") or "Hoist placement cancelled", "info")
        if callback then callback({ success = false }) end
        CheckAndShowEngineMenu()
        return
    end
    
    if hasHoist and swap.hoistEntity and DoesEntityExist(swap.hoistEntity) then
        DeleteEntity(swap.hoistEntity)
        swap.hoistEntity = nil
    end
    
    local modelHash = RequestModelHash("imp_prop_engine_hoist_02a")
    local hoist = CreateObject(modelHash, pos.x, pos.y, pos.z, true, true, false)
    
    if not hoist or not DoesEntityExist(hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_creation_failed") or "Failed to create hoist", "error")
        if callback then callback({ success = false }) end
        CheckAndShowEngineMenu()
        return
    end
    
    SetEntityHeading(hoist, heading or 0.0)
    PlaceObjectOnGroundProperly(hoist)
    SetEntityAsMissionEntity(hoist, true, true)
    
    swap.hoistEntity = hoist
    
    if not hasHoist then
        CompleteInstructionStep(4)
    end
    
    swap.placingHoist = false
    CheckAndShowEngineMenu()
    
    if not IsEntityNearEntity(swap.vehicle, hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_too_far_replace") or "Hoist is too far from the vehicle. Use \"Re-place Engine Hoist\" to move it.", "error")
    end
    
    if callback then callback({ success = true }) end
end

-- Deposit engine at storage
function DepositEngineAtStorage()
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        return false
    end
    
    local vehicle = swap.vehicle
    local engineProp = swap.enginePropEntity
    
    if not DoesEntityExist(vehicle) or not DoesEntityExist(engineProp) then
        return false
    end
    
    if GetCurrentInstructionStep() ~= 7 then
        return false
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 5000,
        label = t("engine_progress_deposit") or "Depositing engine...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "missmechanic", clip = "work_base", flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not success then
        return false
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local currentEngineKey = netId and GetStateBagValue(("entity:%d"):format(netId), "nn_custom_engine")
    
    local engineModIndex
    if currentEngineKey then
        engineModIndex = Data.CustomEngineKeyToModIndex and Data.CustomEngineKeyToModIndex[currentEngineKey]
    else
        engineModIndex = GetVehicleMod(vehicle, 11)
    end
    
    local removedRef = generateReferenceNumber(11, engineModIndex, GetEntityModel(vehicle))
    swap.removedEngineRef = removedRef
    
    TriggerServerEvent("nn_mechanic:depositEngine", removedRef, engineModIndex, GetEntityModel(vehicle), currentEngineKey)
    
    DeleteEntity(engineProp)
    swap.enginePropEntity = nil
    
    CompleteInstructionStep(7)
    CheckAndShowEngineMenu()
    
    return true
end

-- Install engine from inventory
function InstallEngineFromInventory(itemData, engineData, itemName)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        return false
    end
    
    if GetCurrentInstructionStep() ~= 8 then
        return false
    end
    
    local vehicle = swap.vehicle
    local hoist = swap.hoistEntity
    
    if not DoesEntityExist(vehicle) or not DoesEntityExist(hoist) then
        return false
    end
    
    if not IsPlayerNearEntity(hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_too_far") or "You need to be near the engine hoist", "error")
        return false
    end
    
    local expectedRef = swap.expectedNewEngineReferenceNumber
    local providedRef = engineData and (engineData.referenceNumber or engineData.reference)
    local isValidItem = false
    
    if expectedRef and expectedRef ~= "" and providedRef == expectedRef then
        if IsValidPartItem(11, expectedRef, engineData, itemName) then
            isValidItem = true
        else
            bridge.Notify.SendNotify((t("wrong_reference_number") or "Wrong reference number") .. ": " .. tostring(expectedRef), "error")
            return false
        end
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local progressSuccess = bridge.ProgressBar.Open({
        duration = 6500,
        label = t("engine_progress_attach_new") or "Attaching new engine...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "missmechanic", clip = "work_base", flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not progressSuccess then
        return false
    end
    
    local modIndex = tonumber(engineData and engineData.modIndex)
    local customEngineId = engineData and engineData.customEngineId
    
    if isValidItem and modIndex == nil and expectedRef and expectedRef ~= "" then
        local _, decodedModIndex = decodeReferenceNumber(expectedRef)
        if decodedModIndex then
            modIndex = decodedModIndex
            if Data and Data.CustomEngines and Data.CustomEngines[modIndex] then
                customEngineId = Data.CustomEngines[modIndex]
            end
        end
    end
    
    if modIndex == nil then
        return false
    end
    
    swap.installedEngineModIndex = modIndex
    swap.installedCustomEngineId = customEngineId
    
    local modelHash = RequestModelHash("prop_car_engine_01")
    local attachPos = GetOffsetFromEntityInWorldCoords(hoist, 0.0, -0.9, 1.45)
    local engineProp = CreateObject(modelHash, attachPos.x, attachPos.y, attachPos.z, true, true, false)
    
    SetEntityAsMissionEntity(engineProp, true, true)
    AttachEntityToEntity(engineProp, hoist, 0, 0.0, -0.9, 1.4, 0.0, 0.0, 0.0, true, true, false, true, 2, true)
    
    swap.enginePropEntity = engineProp
    
    TriggerServerEvent("nn_mechanic:removePartItem", itemName, itemData.slot)
    CompleteInstructionStep(8)
    CheckAndShowEngineMenu()
    
    return true
end

-- Register debug commands
if Config.Debug then
    RegisterCommand("test_push", function()
        local ped = PlayerPedId()
        local pedPos = GetEntityCoords(ped)
        
        RequestModel("imp_prop_engine_hoist_02a")
        while not HasModelLoaded("imp_prop_engine_hoist_02a") do
            Wait(100)
        end
        
        local hoist = CreateObject("imp_prop_engine_hoist_02a", pedPos.x, pedPos.y, pedPos.z, true, true, false)
        SetEntityCollision(hoist, false, false)
        
        while not DoesEntityExist(hoist) do
            Wait(100)
        end
        
        GetModelDimensions(GetEntityModel(hoist))
        
        RequestAnimDict("missfinale_c2ig_11")
        while not HasAnimDictLoaded("missfinale_c2ig_11") do
            Wait(100)
        end
        
        TaskPlayAnim(ped, "missfinale_c2ig_11", "pushcar_offcliff_m", 4.0, 4.0, -1, 51, 0, false, false, false)
        
        Citizen.CreateThread(function()
            while true do
                Wait(10)
                local pedPos = GetEntityCoords(ped)
                local forwardVec = GetEntityForwardVector(ped)
                local targetPos = pedPos + (forwardVec * 1.6)
                
                local groundZ = targetPos.z
                local foundGround, groundZVal = GetGroundZFor_3dCoord(targetPos.x, targetPos.y, targetPos.z + 2.0, false)
                if foundGround then
                    groundZ = groundZVal
                end
                
                SetEntityCoords(hoist, targetPos.x, targetPos.y, groundZ, false, false, false, true)
                SetEntityHeading(hoist, GetEntityHeading(ped) + 180.0)
                PlaceObjectOnGroundProperly(hoist)
            end
        end)
    end)
    
    RegisterCommand("change_engine", function(_, args)
        local ref = args[1]
        if not ref or ref == "" then
            bridge.Notify.SendNotify(t("reference_number_required") or "Reference number required", "error")
            return
        end
        startEngineSwap(ref)
    end)
end

-- NUI Callbacks
RegisterNUICallback("engineOpenHood", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    if not DoesEntityExist(vehicle) then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 6000,
        label = t("engine_progress_remove_hood") or "Removing hood...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = ANIM_DICT, clip = ANIM_CLIP, flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not success then
        cb({ success = false })
        return
    end
    
    SetVehicleDoorBroken(vehicle, 4, true)
    CompleteInstructionStep(1)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("engineBatteryDisconnect", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    if GetCurrentInstructionStep() ~= 2 then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    OpenUIPage("battery-disconnect")
    cb({ success = true })
end)

RegisterNUICallback("engineDisconnectComponents", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    if GetCurrentInstructionStep() ~= 3 then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    SendNUIMessage({
        action = "setDisconnectingMinigameData",
        data = { items = nil }
    })
    OpenUIPage("disconnecting-minigame")
    cb({ success = true })
end)

RegisterNUICallback("engineAttachNewEngine", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    if GetCurrentInstructionStep() ~= 8 then
        cb({ success = false })
        return
    end
    
    bridge.Notify.SendNotify(t("engine_use_engine_item") or "Use the new engine item from your inventory at the storage area", "info")
    cb({ success = true })
end)

RegisterNUICallback("engineWaitDeposit", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    bridge.Notify.SendNotify(t("engine_go_to_deposit") or "Go to the storage deposit point to deposit the engine", "info")
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("enginePlaceHoist", function(_, cb)
    PlaceEngineHoist(cb)
end)

RegisterNUICallback("engineAttachOldEngine", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    local hoist = swap.hoistEntity
    
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        cb({ success = false })
        return
    end
    
    if not DoesEntityExist(hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_not_placed") or "You need to place the engine hoist first", "error")
        cb({ success = false })
        return
    end
    
    if not IsEntityNearEntity(vehicle, hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_too_far") or "Engine hoist is too far from the vehicle", "error")
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 8000,
        label = t("engine_progress_attach_old") or "Attaching old engine...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "missmechanic", clip = "work_base", flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not success then
        cb({ success = false })
        return
    end
    
    local modelHash = RequestModelHash("prop_car_engine_01")
    local hoodPos = GetVehicleHoodPos(vehicle)
    local engineProp = CreateObject(modelHash, hoodPos.x, hoodPos.y, hoodPos.z, true, true, false)
    
    SetEntityCollision(engineProp, false, false)
    SetEntityAsMissionEntity(engineProp, true, true)
    
    local attachPos = GetOffsetFromEntityInWorldCoords(hoist, 0.0, -0.9, 1.45)
    SmoothMoveEntity(engineProp, attachPos, 1300)
    
    AttachEntityToEntity(engineProp, hoist, 0, 0.0, -0.9, 1.4, 0.0, 0.0, 0.0, true, true, false, true, 2, true)
    
    swap.enginePropEntity = engineProp
    CompleteInstructionStep(5)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("enginePushToStorage", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local hoist = swap.hoistEntity
    if not DoesEntityExist(hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_not_placed") or "You need to place the engine hoist first", "error")
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    CheckAndShowEngineMenu()
    
    local storagePos, _ = FindNearestStorageLocation(GetEntityCoords(State.Ped))
    if not storagePos then
        bridge.Notify.SendNotify(t("no_storage_found") or "No storage found", "error")
        cb({ success = false })
        return
    end
    
    local success = PushHoist(storagePos, function()
        CompleteInstructionStep(6)
        CheckAndShowEngineMenu()
    end)
    
    if success then
        bridge.Notify.SendNotify(t("push_hoist_to_storage") or "Push the hoist to the storage area", "info")
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback("enginePushBack", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    local hoist = swap.hoistEntity
    
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        cb({ success = false })
        return
    end
    
    if not DoesEntityExist(hoist) then
        bridge.Notify.SendNotify(t("engine_hoist_not_placed") or "You need to place the engine hoist first", "error")
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    CheckAndShowEngineMenu()
    
    local hoodPos = GetVehicleHoodPos(vehicle)
    if not hoodPos then
        cb({ success = false })
        return
    end
    
    local success = PushHoist(hoodPos, function()
        if State.engineSwap and State.engineSwap.hoistEntity and DoesEntityExist(State.engineSwap.hoistEntity) then
            CloseCurrentMenu()
            SetEntityVisible(State.engineSwap.hoistEntity, false, false)
            
            local success, newPos, newHeading = bridge.Placeable.PlaceObject("imp_prop_engine_hoist_02a", 6.0, true)
            CloseAllMenus()
            
            if success then
                SetEntityVisible(State.engineSwap.hoistEntity, true, false)
                SetEntityCoords(State.engineSwap.hoistEntity, newPos.x, newPos.y, newPos.z, false, false, false, true)
                SetEntityHeading(State.engineSwap.hoistEntity, newHeading or 0.0)
                PlaceObjectOnGroundProperly(State.engineSwap.hoistEntity)
                CompleteInstructionStep(9)
            else
                SetEntityVisible(State.engineSwap.hoistEntity, true, false)
                bridge.Notify.SendNotify(t("engine_hoist_placement_cancelled") or "Hoist placement cancelled", "info")
            end
            CheckAndShowEngineMenu()
        else
            CheckAndShowEngineMenu()
        end
    end)
    
    if success then
        bridge.Notify.SendNotify(t("push_hoist_back") or "Push the hoist back to the vehicle", "info")
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

RegisterNUICallback("engineLowerEngine", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    local engineProp = swap.enginePropEntity
    
    if not DoesEntityExist(vehicle) or not DoesEntityExist(engineProp) then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 5500,
        label = t("engine_progress_drop") or "Lowering engine...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "missmechanic", clip = "work2_base", flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not success then
        cb({ success = false })
        return
    end
    
    DetachEntity(engineProp, true, true)
    local dropPos = GetVehicleHoodPos(vehicle)
    SetEntityCollision(engineProp, true, true)
    local currentPos = GetEntityCoords(engineProp)
    SmoothMoveEntity(engineProp, dropPos, 1300, currentPos)
    DeleteEntity(engineProp)
    
    swap.enginePropEntity = nil
    CompleteInstructionStep(10)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("engineReconnectComponents", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    if GetCurrentInstructionStep() ~= 11 then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    SendNUIMessage({
        action = "setConnectingMinigameData",
        data = { items = nil }
    })
    OpenUIPage("connecting-minigame")
    cb({ success = true })
end)

RegisterNUICallback("engineReattachHood", function(_, cb)
    local swap = State.engineSwap
    if not swap or not swap.inProgress then
        cb({ success = false })
        return
    end
    
    local vehicle = swap.vehicle
    if not DoesEntityExist(vehicle) then
        cb({ success = false })
        return
    end
    
    CloseCurrentMenu()
    ClearPedTasksImmediately(State.Ped)
    SetPedCanRagdoll(State.Ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 6000,
        label = t("engine_progress_reattach_hood") or "Reattaching hood...",
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = ANIM_DICT, clip = ANIM_CLIP, flag = 1 }
    })
    
    SetPedCanRagdoll(State.Ped, true)
    
    if not success then
        cb({ success = false })
        return
    end
    
    local props = swap.originalVehicleProps
    if props then
        if swap.installedEngineModIndex ~= nil then
            if swap.installedEngineNativeModForProps ~= nil then
                props.modEngine = swap.installedEngineNativeModForProps
            else
                props.modEngine = swap.installedEngineModIndex
            end
        end
    end
    
    if props then
        setVehicleProperties(vehicle, props)
    end
    
    SetVehicleFixed(vehicle)
    CompleteInstructionStep(12)
    swap.inProgress = false
    
    local onComplete = swap.onComplete
    Citizen.CreateThread(function()
        Wait(800)
        CleanupEngineSwap()
        if InstallFlow and InstallFlow.IsActive() then
            InstallFlow.SyncUI()
        end
        if onComplete then
            onComplete(true)
        end
    end)
    
    cb({ success = true })
end)

-- Minigame result handlers
RegisterNUICallback("BatteryDisconnectResult", function(data, cb)
    if State.openPage ~= "battery-disconnect" then
        cb({ success = false })
        return
    end
    
    CloseUIPage("battery-disconnect")
    
    if not State.engineSwap or not State.engineSwap.inProgress then
        cb({ success = false })
        return
    end
    
    if not data.success or data.cancelled then
        bridge.Notify.SendNotify(t("engine_battery_disconnect_failed") or "Battery disconnect failed or cancelled", "error")
        CheckAndShowEngineMenu()
        cb({ success = false })
        return
    end
    
    CompleteInstructionStep(2)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("DisconnectingMinigameResult", function(data, cb)
    if State.openPage ~= "disconnecting-minigame" then
        cb({ success = false })
        return
    end
    
    CloseUIPage("disconnecting-minigame")
    
    if not State.engineSwap or not State.engineSwap.inProgress then
        cb({ success = false })
        return
    end
    
    if not data.success or data.cancelled then
        bridge.Notify.SendNotify(t("engine_disconnect_components_failed") or "Disconnect components failed or cancelled", "error")
        CheckAndShowEngineMenu()
        cb({ success = false })
        return
    end
    
    CompleteInstructionStep(3)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

RegisterNUICallback("ConnectingMinigameResult", function(data, cb)
    if State.openPage ~= "connecting-minigame" then
        cb({ success = false })
        return
    end
    
    CloseUIPage("connecting-minigame")
    
    if not State.engineSwap or not State.engineSwap.inProgress then
        cb({ success = false })
        return
    end
    
    if not data.success or data.cancelled then
        bridge.Notify.SendNotify(t("engine_reconnect_components_failed") or "Reconnect components failed or cancelled", "error")
        CheckAndShowEngineMenu()
        cb({ success = false })
        return
    end
    
    local vehicle = State.engineSwap.vehicle
    if not DoesEntityExist(vehicle) then
        cb({ success = false })
        return
    end
    
    local modIndex = State.engineSwap.installedEngineModIndex
    if modIndex == nil then
        bridge.Notify.SendNotify("Invalid engine data", "error")
        CheckAndShowEngineMenu()
        cb({ success = false })
        return
    end
    
    SetVehicleModKit(vehicle, 0)
    
    local isCustomEngine = Data.CustomEngineStartIndex and modIndex >= Data.CustomEngineStartIndex
    
    if isCustomEngine then
        local customEngineId = Data.CustomEngines and Data.CustomEngines[modIndex]
        if customEngineId and Config.EngineSwap and Config.EngineSwap.engines and Config.EngineSwap.engines[customEngineId] then
            local lastMod = GetNumVehicleMods(vehicle, 11) - 1
            if lastMod < 0 then lastMod = -1 end
            SetVehicleMod(vehicle, 11, lastMod, false)
            State.engineSwap.installedEngineNativeModForProps = lastMod
            TriggerServerEvent("nn_mechanic:setCustomEngine", VehToNet(vehicle), customEngineId)
        end
    else
        SetVehicleMod(vehicle, 11, modIndex, false)
        TriggerServerEvent("nn_mechanic:clearCustomEngine", VehToNet(vehicle))
    end
    
    local vehicleProps = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
    setVehicleProperties(vehicle, vehicleProps)
    
    CompleteInstructionStep(11)
    CheckAndShowEngineMenu()
    cb({ success = true })
end)

-- Resource cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupEngineSwap()
    end
end)