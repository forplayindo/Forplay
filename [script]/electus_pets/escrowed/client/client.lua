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

-- State lives in client/main.lua and client/riding.lua.
DoesInteract = false
Command = 1
local IsPlayerRiding = false

local function playPetClip(pet, name, animation)
    if not pet or not DoesEntityExist(pet.petId) then return false end
    local generation = (pet.animationGeneration or 0) + 1
    pet.animationGeneration, pet.anim = generation, nil
    if not pet.currentVehicle then
        pet.followGeneration = (pet.followGeneration or 0) + 1
        pet.followThreadGeneration = nil
        if pet.targetDoor then ReleasePetVehicleSeat(pet) end
    end
    ClearPedTasks(pet.petId)
    if not animation then return false end
    local loaded = pcall(lib.requestAnimDict, animation.dict, 3000)
    if pet.animationGeneration ~= generation or not DoesEntityExist(pet.petId) or pet.action == 'removed' then return false end
    if not loaded then Notify(L('animationFailed')); return false end
    pet.anim = name
    TaskPlayAnim(pet.petId, animation.dict, animation.anim, 8.0, -8.0, -1,
        animation.loop == 1 and 1 or 0, 0.0, false, false, false)
    if animation.await then Wait(math.min(30000, GetAnimDuration(animation.dict, animation.anim) * 1000)) end
    return pet.animationGeneration == generation and DoesEntityExist(pet.petId) and pet.action ~= 'removed'
end

function PlayPetAnimation(pet, name)
    return playPetClip(pet, name, pet and name and (Config.PetAnims[pet.model] or {})[name])
end

function PlayPetEmote(pet, definition)
    return playPetClip(pet, definition.emote, definition)
end

function AddSniffedItem(pet, item)
    if not pet or type(item) ~= 'string' or not Config.EnableLearnToSniff
        or not (Config.Pets[pet.model] or {}).sniff or not DoesEntityExist(pet.petId) then return false end
    if pet.currentVehicle or pet.pettingSession or (pet.action and pet.action ~= '' and pet.action ~= 'idle'
        and pet.action ~= 'follow') then Notify(L('fetchBusy')); return false end
    pet.sniffedItems = pet.sniffedItems or {}
    for _, known in ipairs(pet.sniffedItems) do
        if known == item then Notify(L('alreadySniffedItem')); return false end
    end
    if pet.sniffTimer and GetGameTimer() - pet.sniffTimer < Config.Delays.newItemToSniffDelay then
        Notify(L('cannotSniffNewItems')); return false
    end
    local allowed = false
    for _, name in ipairs(Config.AllowedSniffedItems) do if name == item then allowed = true; break end end
    if not allowed or not HasItem(item) then return false end
    local previous, player = pet.action, PlayerPedId()
    AnimHandler(pet)
    pet.action = 'learnSniff'
    CreateThread(function()
        local completed, cancelled = false, false
        local cancel = Config.Keys[Config.KeyActions.cancelKey]
        local function valid()
            return pet.action == 'learnSniff' and DoesEntityExist(pet.petId) and not IsEntityDead(pet.petId)
                and not IsEntityDead(player) and not IsPedInAnyVehicle(player, false)
        end
        local ok, err = pcall(function()
            lib.requestAnimDict('pickup_object', 3000)
            if not valid() then cancelled = true; return end
            TaskPlayAnim(player, 'pickup_object', 'pickup_low', 2.7, 2.7, 2000, 48, 0.0, false, false, false)
            local target = GetOffsetFromEntityInWorldCoords(player, 0.0, 1.0, 0.0)
            TaskGoToCoordAnyMeans(pet.petId, target.x, target.y, target.z, 2.0, 0, false, 786603, 0.0)
            local deadline = GetGameTimer() + 10000
            while valid() and #(target - GetEntityCoords(pet.petId)) > 1.0 do
                if cancel and IsControlJustReleased(0, cancel.key) then cancelled = true; return end
                if GetGameTimer() >= deadline then return end
                Wait(0)
            end
            if not valid() then cancelled = true; return end
            if not PlayPetAnimation(pet, 'pickUp') then return end
            Wait(1500)
            if not valid() then cancelled = true; return end
            local result = lib.callback.await('electus_pets:learnSniffItem', false, pet.name, item)
            if type(result) ~= 'table' or type(result.sniffedItems) ~= 'table' then return end
            if not valid() then cancelled = true; return end
            pet.sniffedItems, pet.sniffTimer = result.sniffedItems, GetGameTimer()
            completed = true
            DailyTaskCheck(pet, 'sniffNewItem')
            UpdatePetUI()
        end)
        StopAnimTask(player, 'pickup_object', 'pickup_low', 2.0)
        if pet.action == 'learnSniff' then
            pet.action = previous or ''
            if DoesEntityExist(pet.petId) then
                if previous == 'follow' then Follow(pet) else ClearPedTasks(pet.petId) end
            end
        end
        if not ok then print(('electus_pets: scent learning failed: %s'):format(err)) end
        if not completed and not cancelled then Notify(L('sniffFailed')) end
    end)
    return true
end

function AddXP(petData, xpAmount)
    -- XP is awarded by validated server actions and synced through progression events.
    -- Keep the action API so client actions do not fabricate spendable points.
    UpdatePetUI()
end

function UpdatePetUI()
    if PetIndexInSkillMenu == nil or not CurrentPets[PetIndexInSkillMenu] then
        return
    end

    local petData = CurrentPets[PetIndexInSkillMenu]
    if not DoesEntityExist(petData.petId) then return end
    NormalizePetStatus(petData)
    local entityHealth = GetEntityHealth(petData.petId)
    petData.status.health = entityHealth
    local canAttack = false
    local canSniff = false

    for model, config in pairs(Config.Pets) do
        if petData.model == model then
            canAttack = config.attack
            canSniff = config.sniff
            break
        end
    end

    local canBeCarried = CanBeCarried(petData.model)
    local canBeRidden = Config.CanBeRidden[petData.model] ~= nil

    SendReactMessage("updatePet", {
        pet = petData,
        health = entityHealth,
        canAttack = canAttack,
        canSniff = canSniff,
        canBeCarried = canBeCarried,
        canBeRidden = canBeRidden,
        dailyTasks = petData.dailyTasks
    })
end

local FriendList = { jobs = {}, players = {} }
local IsFriendListLoaded = false

function GetFriendList()
    if not IsFriendListLoaded then
        TriggerServerEvent("electus_pets:requestFriendList")
        Wait(0)
    end
    return FriendList
end

RegisterNetEvent("electus_pets:receiveFriendList", function(friendData)
    friendData.jobs = GetJobsLabel(friendData.jobs)
    FriendList = friendData
    IsFriendListLoaded = true
    SendReactMessage("updateFriendList", FriendList)
end)

function GetAccessoriesInventory()
    local allItems = {}
    local availableItems = {}

    for category, items in pairs(Config.AccessoryShop.shopItems) do
        for _, item in ipairs(items) do
            table.insert(availableItems, item.name)
            allItems[item.name] = category
        end
    end

    local ownedItems = HasItems(availableItems)

    for _, item in ipairs(ownedItems) do
        item.type = allItems[item.name]
    end

    return ownedItems
end

function GetAccessoiresSlots(petData)
    local slots = {
        {item = nil, type = "head"},
        {item = nil, type = "glasses"},
        {item = nil, type = "neck"},
        {item = nil, type = "collar"},
        {item = nil, type = "bag"}
    }

    if petData.accessories then
        for accessoryType, accessoryItem in pairs(petData.accessories) do
            for _, slot in ipairs(slots) do
                if slot.type == accessoryType then
                    local itemLabel = GetItemLabel(accessoryItem)
                    slot.item = accessoryItem
                    slot.label = itemLabel
                    break
                end
            end
        end
    end

    return slots
end

function SyncUIAccessoriesInventory()
    local inventory = GetAccessoriesInventory()
    SendReactMessage("updateInventory", inventory)
end

function SyncUIAccessoriesSlots(petData)
    local slots = GetAccessoiresSlots(petData)
    SendReactMessage("updateSlots", slots)
end

function RemoveLocalPet(netId)
    for i = #CurrentPets, 1, -1 do
        local pet = CurrentPets[i]
        if pet.netId == netId then
            local menuSelected = PetMenuSelection == pet
            if menuSelected then PetMenuSelection = nil end
            if ControlledRidingPet == pet then StopRidingControlling(pet) end
            pet.action = 'removed'
            ReleasePetVehicleSeat(pet)
            RemoveBlipForPet(pet.name)
            for _, accessory in pairs(pet.accessoriesProps or {}) do
                if DoesEntityExist(accessory) then DeleteEntity(accessory) end
            end
            if Config.TargetSystem ~= 'none' then PetTarget:RemoveTargetEntity(pet.petId) end
            if menuSelected or PetIndexInSkillMenu == i then
                PetIndexInSkillMenu, IsInPetMenu = nil, false
                ToggleNuiFrame(false)
            elseif PetIndexInSkillMenu and PetIndexInSkillMenu > i then
                PetIndexInSkillMenu = PetIndexInSkillMenu - 1
            end
            table.remove(CurrentPets, i)
            return
        end
    end
end

function DeletePet(pet, async)
    -- Keep the entity alive until the server has captured its final health.
    if async then
        TriggerServerEvent('electus_pets:removePet', pet.netId)
    elseif lib.callback.await('electus_pets:despawnPet', false, pet.netId) ~= true then
        Notify(L('statusUpdateFailed'))
        return false
    end
    RemoveLocalPet(pet.netId)
    return true
end

local function DeletePets(async)
    for i = #CurrentPets, 1, -1 do
        if CurrentPets[i] then DeletePet(CurrentPets[i], async) end
    end
end

local function GetPets()
    return CurrentPets
end

local function AnyPetsOutside()
    return #CurrentPets > 0
end

local function IsRiding()
    return StoredPlayerPed ~= nil or ControlledRidingPet ~= nil
end

exports("DeletePets", DeletePets)
exports("GetPets", GetPets)
exports("AnyPetsOutside", AnyPetsOutside)
exports("IsRiding", IsRiding)

function DeletePetFromName(petName)
    for i, pet in ipairs(CurrentPets) do
        if pet.name == petName then
            DeletePet(pet)
            break
        end
    end
end

RegisterNetEvent('electus_pets:tryToGetPetBack', function(netId)
    local pet
    for _, candidate in ipairs(CurrentPets) do if candidate.netId == netId then pet = candidate; break end end
    if not pet or pet.recoveryInProgress then return end
    pet.recoveryInProgress = true
    local function current() return CurrentPets[GetPetIndex(pet.name)] == pet end
    local ok, err = pcall(function()
        local deadline = GetGameTimer() + 5000
        while current() and not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(0) end
        if not current() or not NetworkDoesNetworkIdExist(netId) then return end
        while current() and not NetworkHasControlOfNetworkId(netId) and GetGameTimer() < deadline do
            NetworkRequestControlOfNetworkId(netId)
            Wait(0)
        end
        if not current() or not NetworkHasControlOfNetworkId(netId) then return end
        local entity = NetworkGetEntityFromNetworkId(netId)
        if not DoesEntityExist(entity) then return end
        pet.petId = entity
        UpdateAccessories(GetPetIndex(pet.name))
        if pet.status and pet.status.tracker then RemoveBlipForPet(pet.name); AddBlipForPet(pet) end
        if pet.action == 'follow' then
            pet.followGeneration = (pet.followGeneration or 0) + 1
            pet.followThreadGeneration = nil
            Follow(pet)
        end
    end)
    pet.recoveryInProgress = nil
    if not ok then print(('electus_pets: pet recovery failed: %s'):format(err)) end
end)

function MaintainPets()
    local now = GetGameTimer()
    for i = #CurrentPets, 1, -1 do
        local pet = CurrentPets[i]
        if DoesEntityExist(pet.petId) then
            if NetworkGetEntityOwner(pet.petId) == PlayerId() then
                if GetEntityHealth(pet.petId) <= 0 then
                    if not pet.deathReported then
                        pet.deathReported = true
                        TriggerServerEvent('electus_pets:petDeath', { name = pet.name })
                    end
                elseif pet.action == 'follow' and GetEntitySpeed(pet.petId) > 1.0 then
                    pet.lastWalkProgress = pet.lastWalkProgress or now
                    if now - pet.lastWalkProgress >= 60000 then
                        pet.lastWalkProgress = now
                        DailyTaskCheck(pet, 'walk')
                    end
                end
            end
        elseif not pet.recoveryInProgress and now >= (pet.nextRecoveryAt or 0) then
            pet.nextRecoveryAt = now + 5000
            TriggerServerEvent('electus_pets:tryToGetPetBack', pet.netId)
        end
    end
end

-- Breeding is disabled until its server implementation exists; maintenance never
-- changes breeding counts or starts mating scenes on its own.
CreateThread(function()
    while true do Wait(5000); MaintainPets() end
end)

-- Status decay is server-owned; the open menu still follows live damage.
CreateThread(function()
    while true do
        Wait(1000)
        if IsInPetMenu and PetIndexInSkillMenu then UpdatePetUI() end
    end
end)

local function HandleFastInteraction(pressed)
    if pressed then
        if DoesInteract then return end
        if #CurrentPets > 0 then
            DoesInteract = true
            SendReactMessage("updateComponent", {component = "commandBar"})
            ToggleNuiFrame(true)
            Interact()
        else
            IsPlayerRiding = true
        end
    else
        IsPlayerRiding = false
    end
end
lib.addKeybind({
    name = "pets_fast_interaction",
    description = "Fast interaction",
    defaultKey = Config.KeyActions.fastInteraction,
    onPressed = function() HandleFastInteraction(true) end,
    onReleased = function(pressed)
        IsPlayerRiding = false
    end
})

local function HandleCommandAction(pressed)
    if pressed then
        IsPlayerRiding = true
    else
        IsPlayerRiding = false
    end
end
lib.addKeybind({
    name = "pets_command_action",
    description = "Command Action",
    defaultKey = Config.KeyActions.commandAction,
    onPressed = function() HandleCommandAction(true) end,
    onReleased = function(pressed)
        IsPlayerRiding = false
    end
})

function Interact(selectedPet)
    DoesInteract = true
    SetNuiFocus(false, false)
    SendReactMessage('changeCommand', { id = Command })
    CreateThread(function()
        while DoesInteract do
            Wait(0)
            local coords = GetWorldCoordsFromScreen()
            DrawMarker(1, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.0, 1.0, 0.3, 0, 150, 255, 150, false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 202) then
                DoesInteract = false
            elseif IsPlayerRiding then
                IsPlayerRiding = false
                DoesInteract = false
                local pet = selectedPet
                if not pet then local _, index = GetClosestPet(); pet = CurrentPets[index] end
                if pet and DoesEntityExist(pet.petId) and #(GetEntityCoords(pet.petId) - GetEntityCoords(PlayerPedId())) <= Config.MaxCommandRange then
                    if Command == 1 then Follow(pet)
                    elseif Command == 2 then GoTo(pet, coords)
                    elseif Command == 3 then Attack(pet, coords)
                    elseif Command == 4 then SearchEntity(pet, coords) end
                end
            end
        end
        SendReactMessage('hideCommandBar', {})
        ToggleNuiFrame(false)
    end)
end

function SetPetLeash(pet, enabled)
    if not pet or pet.leashPending then return false end
    pet.leashPending = true
    local ok, accepted = pcall(lib.callback.await, 'electus_pets:setLeash', false, pet.netId, enabled)
    pet.leashPending = nil
    if ok and accepted == true then
        pet.leash = enabled
        return true
    end
    Notify(L('leashFailed'))
    return false
end

function AttachLeash(pet) return SetPetLeash(pet, true) end
function DetachLeash(pet) return SetPetLeash(pet, false) end

AddEventHandler('playerSpawned', function()
    -- Riding owns StoredPlayerPed; spawning a player is not riding.
end)

AddEventHandler('playerDropped', function()
    StoredPlayerPed = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeletePets(true)
    end
end)
AnimHandler = PlayPetAnimation
SniffNewItem = AddSniffedItem
