--[[
 ______     __         ______     ______     __   __     ______     _____        ______     __  __        __  __     ______     __   __   __     __   __    
/\  ___\   /\ \       /\  ___\   /\  __ \   /\ "-.\ \   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \/ /    /\  ___\   /\ \ / /  /\ \   /\ "-.\ \   
\ \ \____  \ \ \____  \ \  __\   \ \  __ \  \ \ \-.  \  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  _"-.  \ \  __\   \ \ \'/   \ \ \  \ \ \-.  \  
 \ \_____\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_\\"\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_____\  \ \__|    \ \_\  \ \_\\"\_\ 
  \/_____/   \/_____/   \/_____/   \/_/\/_/   \/_/ \/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_____/   \/_/      \/_/   \/_/ \/_/ 
 ______   __     __  __     ______     _____        ______     __  __        __  __     ______     ______     __     __    __        __  __     ______     ______     ______     ______     ______     ______    
/\  ___\ /\ \   /\_\_\_\   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \_\ \   /\  __ \   /\___  \   /\ \   /\ "-./  \      /\ \_\ \   /\  ___\   /\  == \   /\  == \   /\  ___\   /\  == \   /\  __ \   
\ \  __\ \ \ \  \/_/\_\/_  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  __ \  \ \  __ \  \/_/  /__  \ \ \  \ \ \-./\ \     \ \  __ \  \ \  __\   \ \  __<   \ \  __<   \ \  __\   \ \  __<   \ \  __ \  
 \ \_\    \ \_\   /\_\/\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_\ \_\   /\_____\  \ \_\  \ \_\ \ \_\     \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\ 
  \/_/     \/_/   \/_/\/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_/\/_/   \/_____/   \/_/   \/_/  \/_/      \/_/\/_/   \/_____/   \/_/ /_/   \/_/ /_/   \/_____/   \/_/ /_/   \/_/\/_/ 
                                                                                                                                                                    
]]

local isGuardAreaIncreasing = false
local isGuardAreaDecreasing = false
local isGuardAreaConfirming = false
local isGuardAreaCancelling = false

local guardAreaSize = 5.0
local guardAreaMarker

local petsAttacking = {}
local guardedAreas = {}

-- Keybind registration for guard area control
local function RegisterGuardAreaKeybinds(lib, config)
    local keyActions = config.KeyActions

    lib.addKeybind({
        name = "increaseGuardArea",
        description = "Increase Guard Area",
        defaultKey = keyActions.increaseGuardArea,
        onPressed = function()
            isGuardAreaIncreasing = true
        end,
        onReleased = function()
            isGuardAreaIncreasing = false
        end
    })

    lib.addKeybind({
        name = "decreaseGuardArea",
        description = "Decrease Guard Area",
        defaultKey = keyActions.decreaseGuardArea,
        onPressed = function()
            isGuardAreaDecreasing = true
        end,
        onReleased = function()
            isGuardAreaDecreasing = false
        end
    })

    lib.addKeybind({
        name = "confirmGuardArea",
        description = "Confirm Guard Area",
        defaultKey = keyActions.confirmGuardArea,
        onPressed = function()
            isGuardAreaConfirming = true
        end,
        onReleased = function()
            isGuardAreaConfirming = false
        end
    })

    lib.addKeybind({
        name = "cancelGuardArea",
        description = "Cancel Guard Area",
        defaultKey = keyActions.cancelKey,
        onPressed = function()
            isGuardAreaCancelling = true
        end,
        onReleased = function()
            isGuardAreaCancelling = false
        end
    })
end

-- Function to create and manage the guard area marker and input
function CreateGuardArea(petInfo, targetCoords)
    local keyActions = Config.KeyActions
    local markerData = {
        up = keyActions.increaseGuardArea,
        down = keyActions.decreaseGuardArea,
        confirm = keyActions.confirmGuardArea,
        cancelKey = keyActions.cancelKey
    }

    -- Display help text for creating guard area
    HelpText(L("createGuardArea", markerData))

    -- Thread for handling marker movement and input
    CreateThread(function()
        local currentMarkerSize = guardAreaSize

        while true do
            Wait(0)

            -- Get current mouse coordinates in the world
            targetCoords = GetWorldCoordsFromScreen()

            -- Handle increasing guard area size
            if isGuardAreaIncreasing then
                isGuardAreaIncreasing = false
                if currentMarkerSize < 7.5 then
                    currentMarkerSize = currentMarkerSize + 0.5
                end
            end

            -- Handle decreasing guard area size
            if isGuardAreaDecreasing then
                isGuardAreaDecreasing = false
                if currentMarkerSize > 2.0 then
                    currentMarkerSize = currentMarkerSize - 0.5
                end
            end

            -- Handle confirming guard area
            if isGuardAreaConfirming then
                isGuardAreaConfirming = false
                -- Assume GuardArea is an exported function from another resource
                if GuardArea then
                    GuardArea(petInfo, targetCoords, currentMarkerSize)
                end
                break -- Exit the marker creation loop
            end

            -- Handle cancelling guard area creation
            if isGuardAreaCancelling then
                isGuardAreaCancelling = false
                break -- Exit the marker creation loop
            end

            -- Draw the marker
            local markerType = 1
            local markerPos = targetCoords
            local drawPosOffset = {x = 0.0, y = 0.0, z = 0.0}
            local scale = {x = currentMarkerSize * 2.0, y = currentMarkerSize * 2.0, z = 1.0}
            local rotation = {x = 0.0, y = 0.0, z = 0.0}
            local color = {r = 150, g = 0, b = 200, a = 0} -- Purple marker
            local bobUpAndDown = false
            local faceCamera = false
            local p19 = 0
            local p20 = 0
            local p21 = 0
            local rotate = false

            DrawMarker(markerType, markerPos.x, markerPos.y, markerPos.z,
                       drawPosOffset.x, drawPosOffset.y, drawPosOffset.z,
                       rotation.x, rotation.y, rotation.z,
                       scale.x, scale.y, scale.z,
                       color.r, color.g, color.b, color.a,
                       bobUpAndDown, faceCamera, p19, p20, p21, rotate, false, 0, false)
        end
        -- Hide help text after marker creation is finished or cancelled
        HideHelpText()
    end)
end

-- Function to set the pet to guard an area
function GuardArea(petData, areaCoords, areaRadius)
    petData.action = "guard"
    HideHelpText()

    -- Assume TaskWanderInArea is a native or exported function
    TaskWanderInArea(petData.petId, areaCoords.x, areaCoords.y, areaCoords.z, areaRadius, 1.0, 1.0)

    -- If pet has guardArea ability, send server event
    if petData.abilities and petData.abilities.guardArea then
        TriggerServerEvent("electus_pets:guardArea", petData, areaCoords, areaRadius)
    end
end

-- Event handler for when a pet attacks a player
local function HandleClientOwnerAttackPlayer(targetServerId, data, identifier)
    local player = GetPlayerFromServerId(targetServerId)
    if player == -1 or not NetworkDoesNetworkIdExist(data.netId) then return end
    local pet, target = NetworkGetEntityFromNetworkId(data.netId), GetPlayerPed(player)
    if not DoesEntityExist(pet) or not DoesEntityExist(target) then return end
    TaskCombatPed(pet, target, 0, 16)
    SetPedKeepTask(pet, true)
    petsAttacking[identifier] = true
    CreateThread(function()
        while DoesEntityExist(pet) and DoesEntityExist(target) and not IsEntityDead(target) do
            Wait(1000)
            if #(GetEntityCoords(pet) - GetEntityCoords(target)) > data.radius + 10.0 then break end
            if GetScriptTaskStatus(pet, joaat('SCRIPT_TASK_COMBAT')) ~= 1 then break end
        end
        petsAttacking[identifier] = nil
        TriggerServerEvent('electus_pets:removeActiveAttack', identifier)
    end)
end

-- Event handler for updating the list of guarded areas (pets being managed)
local function UpdateGuardList(newGuardList)
    guardedAreas = newGuardList
end

-- Function to request ownership of a pet entity
function RequestPetOwnership(petData)
    if not petData or not petData.netId then return end

    -- Wait until the pet entity exists
    local deadline = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(petData.netId) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end

    local petEntity = NetworkGetEntityFromNetworkId(petData.netId)

    -- Request network control of the pet
    NetworkRequestControlOfNetworkId(petData.netId)
    while not NetworkHasControlOfNetworkId(petData.netId) do
        if GetGameTimer() > deadline then return end
        Wait(0)
    end

    -- Find the pet in the current list and update its entity ID
    for i, currentPet in ipairs(guardedAreas) do -- Assuming guardedAreas holds the list of pets being managed
        if currentPet.netId == petData.netId then
            currentPet.petId = petEntity
            return
        end
    end
end

-- Thread to manage player's pets and check for potential attacks
local function PetManagementThread()
    while true do
        for _, area in ipairs(guardedAreas) do
            if NetworkDoesNetworkIdExist(area.netId) then
                local entity = NetworkGetEntityFromNetworkId(area.netId)
                local coords = GetEntityCoords(PlayerPedId())
                if DoesEntityExist(entity) and #(area.coords - coords) < area.radius and area.owner ~= GetIdentifier() then
                    TriggerServerEvent('electus_pets:attackPlayer', area.index)
                end
            end
        end
        Wait(2500)
    end
end

-- Function to check if the current player owns the guard area for a specific pet
function IsOwnerOfGuardArea(data)
    return data and data.owner == GetIdentifier() or false
end

-- Registering events
RegisterNetEvent("electus_pets:clientOwnerAttackPlayer", function(petOwnerId, attackingPetData, petIdentifier)
    HandleClientOwnerAttackPlayer(petOwnerId, attackingPetData, petIdentifier)
end)

RegisterNetEvent("electus_pets:updateGuardList", UpdateGuardList)

-- Starting the pet management thread
CreateThread(PetManagementThread)

-- Exporting functions
CreateGuardArea = CreateGuardArea
GuardArea = GuardArea
RequestPetOwnership = RequestPetOwnership
IsOwnerOfGuardArea = IsOwnerOfGuardArea

-- Registering keybinds (assuming 'lib' and 'Config' are available globally or passed in)
-- In a real scenario, 'lib' and 'Config' would likely be passed as arguments or accessed differently.
-- For this reconstruction, we assume they are accessible.
if lib and Config then
    RegisterGuardAreaKeybinds(lib, Config)
end
