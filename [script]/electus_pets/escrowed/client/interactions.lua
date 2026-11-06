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

local petsData, versions = {}, {}

local function receivePet(pet)
    if type(pet) ~= 'table' then return end
    local netId = tonumber(pet.netId)
    if not netId or (pet.revision and pet.revision <= (versions[netId] or -1)) then return end
    pet.netId = netId
    petsData[netId] = pet
    versions[netId] = pet.revision or versions[netId] or 0
    for _, owned in ipairs(CurrentPets) do
        if owned.netId == netId then owned.leash = pet.leashOwner ~= nil end
    end
end

RegisterNetEvent('electus_pets:loadAllPets', function(loadedPets, revision)
    if type(loadedPets) ~= 'table' then return end
    local present = {}
    for _, pet in pairs(loadedPets) do
        if type(pet) == 'table' and tonumber(pet.netId) then
            present[tonumber(pet.netId)] = true
            receivePet(pet)
        end
    end
    for netId in pairs(petsData) do
        if not present[netId] and (not revision or (versions[netId] or 0) <= revision) then
            petsData[netId] = nil
            versions[netId] = revision or versions[netId]
            if ClearSyncedPetVisuals then ClearSyncedPetVisuals(netId) end
            RemoveLocalPet(netId)
        end
    end
end)

RegisterNetEvent('electus_pets:insertPet', receivePet)

-- Pause the owner's follow tasks before the interacting player starts the scene.
local function ownedPet(netId)
    for _, pet in ipairs(CurrentPets) do if pet.netId == netId then return pet end end
end

lib.callback.register('electus_pets:preparePetting', function(netId, token)
    local pet = ownedPet(netId)
    if not pet or pet.pettingSession or pet.currentVehicle or pet.action == 'riding' then return false end
    if pet.action and pet.action ~= '' and pet.action ~= 'follow' and pet.action ~= 'idle' then return false end
    pet.previousPettingAction, pet.pettingSession = pet.action, token
    pet.action = 'petting'
    return true
end)

RegisterNetEvent('electus_pets:finishPetting', function(netId, token)
    local pet = ownedPet(netId)
    if not pet or pet.pettingSession ~= token then return end
    local deadline = GetGameTimer() + 1500
    while DoesEntityExist(pet.petId) and not NetworkHasControlOfEntity(pet.petId) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(pet.petId)
        Wait(0)
    end
    if pet.pettingSession ~= token then return end
    local resume = pet.previousPettingAction
    pet.pettingSession, pet.previousPettingAction = nil, nil
    if pet.action ~= 'petting' then return end
    pet.action = resume or ''
    if DoesEntityExist(pet.petId) and NetworkHasControlOfEntity(pet.petId) then
        if resume == 'follow' then Follow(pet) else ClearPedTasks(pet.petId) end
    end
end)

local pettingScene
lib.callback.register('electus_pets:playPetting', function(netId)
    if pettingScene or StoredPlayerPed or ControlledRidingPet or not NetworkDoesNetworkIdExist(netId) then return false end
    local pet, player = NetworkGetEntityFromNetworkId(netId), PlayerPedId()
    if not DoesEntityExist(pet) or IsEntityDead(pet) or IsEntityDead(player)
        or IsPedInAnyVehicle(player, false) or IsPedInAnyVehicle(pet, false)
        or #(GetEntityCoords(player) - GetEntityCoords(pet)) > 3.0 then return false end
    pettingScene = true
    local scene, approaching
    local ok, result = pcall(function()
        local animation = Config.Petting
        lib.requestAnimDict(animation.dict, 3000)
        local deadline = GetGameTimer() + 2000
        while not NetworkHasControlOfEntity(pet) do
            if GetGameTimer() >= deadline or not DoesEntityExist(pet) then return false end
            NetworkRequestControlOfEntity(pet)
            Wait(0)
        end
        local duration = math.max(GetAnimDuration(animation.dict, animation.playerAnim), GetAnimDuration(animation.dict, animation.petAnim)) * 1000
        if duration <= 0 then return false end
        duration = math.min(duration, animation.maxDuration or 30000, 30000)
        TaskStandStill(pet, 6000)
        Wait(250)
        local coords, rotation = GetEntityCoords(pet), GetEntityRotation(pet, 2)
        local offset = GetAnimInitialOffsetPosition(animation.dict, animation.petAnim, 0.0, 0.0, 0.0,
            rotation.x, rotation.y, rotation.z, 0.0, 2)
        local origin = coords - offset
        local start = GetAnimInitialOffsetPosition(animation.dict, animation.playerAnim,
            origin.x, origin.y, origin.z, rotation.x, rotation.y, rotation.z, 0.0, 2)
        local facing = GetAnimInitialOffsetRotation(animation.dict, animation.playerAnim,
            origin.x, origin.y, origin.z, rotation.x, rotation.y, rotation.z, 0.0, 2)
        local cancel = Config.Keys[Config.KeyActions.cancelKey]
        if #(GetEntityCoords(player) - start) > 0.2 then
            approaching = true
            TaskGoStraightToCoord(player, start.x, start.y, start.z, 1.0, -1, facing.z, 0.2)
            local approachDeadline = GetGameTimer() + (animation.approachTimeout or 3500)
            while #(GetEntityCoords(player) - start) > 0.3 do
                if GetGameTimer() >= approachDeadline or not DoesEntityExist(pet) or IsEntityDead(player)
                    or IsEntityDead(pet) or (cancel and IsControlJustReleased(0, cancel.key)) then return false end
                DisablePlayerFiring(PlayerId(), true)
                Wait(0)
            end
        end
        TaskAchieveHeading(player, facing.z, 500)
        Wait(400)
        approaching = nil
        scene = NetworkCreateSynchronisedScene(origin.x, origin.y, origin.z, rotation.x, rotation.y, rotation.z,
            2, false, false, 1.0, 0.0, 1.0)
        -- TAG_SYNC_OUT lets the last pose blend back into ordinary movement.
        NetworkAddPedToSynchronisedScene(player, scene, animation.dict, animation.playerAnim,
            animation.blendIn or 2.0, animation.blendOut or -2.0, 3090, 0, 1000.0, 0)
        NetworkAddPedToSynchronisedScene(pet, scene, animation.dict, animation.petAnim,
            animation.blendIn or 2.0, animation.blendOut or -2.0, 2066, 0, 1000.0, 0)
        NetworkStartSynchronisedScene(scene)
        local finish = GetGameTimer() + duration
        while GetGameTimer() < finish do
            if not DoesEntityExist(pet) or IsEntityDead(player) or IsEntityDead(pet) then break end
            if cancel and IsControlJustReleased(0, cancel.key) then break end
            for _, control in ipairs({ 21, 22, 23, 24, 25, 30, 31 }) do DisableControlAction(0, control, true) end
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        end
        return true
    end)
    if scene then
        NetworkStopSynchronisedScene(scene)
        Wait(Config.Petting.blendOutTime or 500)
    elseif approaching then
        ClearPedTasks(player)
    end
    pettingScene = nil
    if not ok then print(('electus_pets: petting animation failed: %s'):format(result)) end
    return ok and result == true
end)

-- Event handler for removing a pet
RegisterNetEvent('electus_pets:removePet', function(netId, revision)
    netId = tonumber(netId)
    if not netId or (revision and revision <= (versions[netId] or -1)) then return end
    versions[netId] = revision or versions[netId] or 0
    petsData[netId] = nil
    if ClearSyncedPetVisuals then ClearSyncedPetVisuals(netId) end
    RemoveLocalPet(netId)
end)

-- Function to get all loaded pet data
function GetAllPets()
    return petsData
end

-- Function to get a specific pet's data by its network ID
function GetPetByNetId(netId)
    local petData = petsData[netId]
    if not petData then
        petData = nil
    end
    return petData
end

-- Target system integration for interacting with pets
if Config.TargetSystem ~= "none" then
    PetTarget:AddTargetModel((function() local out = {}; for model in pairs(Config.Pets) do out[#out+1] = model end; return out end)(), {
        options = {
            {
                icon = "fas fa-paw",
                label = "Pet Dog", -- Assuming "L" is a localization function or similar
                action = function(targetEntity)
                    local targetNetId = NetworkGetNetworkIdFromEntity(targetEntity)
                    if NetworkDoesNetworkIdExist(targetNetId) then
                        TriggerServerEvent("electus_pets:petDog", targetNetId, PedToNet(targetEntity))
                    end
                end,
                canInteract = function(targetEntity)
                    if not NetworkDoesNetworkIdExist(NetworkGetNetworkIdFromEntity(targetEntity)) then
                        return false
                    end

                    local targetNetId = NetworkGetNetworkIdFromEntity(targetEntity)
                    local petData = petsData[targetNetId]

                    if petData then
                        local petModel = petData.model
                        return Config.PettableDogs[petModel] ~= nil
                    end
                    return false
                end
            },
            {
                icon = "fas fa-suitcase",
                label = "Pet Bag", -- Assuming "L" is a localization function or similar
                action = function(targetEntity)
                    local targetNetId = NetworkGetNetworkIdFromEntity(targetEntity)
                    if NetworkDoesNetworkIdExist(targetNetId) then
                        local petData = petsData[targetNetId]
                        if petData and petData.hasBag then
                            -- Assuming SendReactMessage and ToggleNuiFrame are available exports
                            SendReactMessage("updateComponent", {
                                component = "bagLock",
                                bagData = {
                                    owner = petData.owner,
                                    petName = petData.name
                                }
                            })
                            ToggleNuiFrame(true)
                        end
                    end
                end,
                canInteract = function(targetEntity)
                    if not NetworkDoesNetworkIdExist(NetworkGetNetworkIdFromEntity(targetEntity)) then
                        return false
                    end

                    if not Config.EnablePetBags then
                        return false
                    end

                    local targetNetId = NetworkGetNetworkIdFromEntity(targetEntity)
                    local petData = petsData[targetNetId]

                    return petData and petData.hasBag
                end
            }
        },
        distance = 2.5
    })
end

-- Function to find the closest pet to a given coordinate
function GetClosestPetInAllPets(coords)
    local closestPet = nil
    local closestDistance = math.huge
    local pedsInPool = GetGamePool("CPed")

    for _, ped in ipairs(pedsInPool) do
        if ped ~= PlayerPedId() then -- Ensure it's not the player ped
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords) -- Vector subtraction for distance calculation

            if closestDistance == 0.0 then
                closestDistance = distance
            end

            if distance < closestDistance then
                local pedNetId = PedToNet(ped)
                local petData = petsData[pedNetId]

                if petData then
                    closestPet = ped
                    closestDistance = distance
                end
            end
        end
    end
    return closestPet, closestDistance
end

-- Command to interact with the pet bag
if Config.TargetSystem == "none" then
    if Config.EnablePetBags then
        RegisterCommand(Config.Commands.petBag, function()
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local closestPet, distance = GetClosestPetInAllPets(playerCoords)

            if closestPet and distance < 2.0 then
                if DoesEntityExist(closestPet) then
                    local petNetId = PedToNet(closestPet)
                    if NetworkDoesNetworkIdExist(petNetId) then
                        local petData = petsData[petNetId]
                        if petData and petData.hasBag then
                            SendReactMessage("updateComponent", {
                                component = "bagLock",
                                bagData = {
                                    owner = petData.owner,
                                    petName = petData.name
                                }
                            })
                            ToggleNuiFrame(true)
                        end
                    end
                end
            end
        end, false)
    end
end

-- Command to pet a dog
if Config.TargetSystem == "none" then
    RegisterCommand(Config.Commands.petDog, function()
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closestPet, distance = GetClosestPetInAllPets(playerCoords)

        if closestPet and distance < 2.0 then
            local petNetId = PedToNet(closestPet)
            local petData = petsData[petNetId]

            if petData then
                local petModel = petData.model
                if Config.PettableDogs[petModel] then
                    TriggerServerEvent("electus_pets:petDog", petNetId, PedToNet(closestPet))
                end
            end
        end
    end, false)
end

-- Key mappings for commands
RegisterKeyMapping(Config.Commands.petBag, "Pet Bag", "keyboard", Config.KeyActions.petBag)
RegisterKeyMapping(Config.Commands.petDog, "Pet Dog", "keyboard", Config.KeyActions.petDog)

-- Event handler for unlocking a pet bag
RegisterNetEvent("electus_pets:unlockBag", function(petNetId, petOwner)
    OpenPetBagInventory(petNetId, petOwner) -- Assuming OpenPetBagInventory is an available function
end)
