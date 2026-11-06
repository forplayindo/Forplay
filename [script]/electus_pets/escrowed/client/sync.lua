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

-- The ped/tasks are networked. Cosmetics and leashes are local visuals rebuilt
-- from server records, so every observer sees one copy without stealing control.
local visuals = {}

local function deleteProp(prop)
    if prop and DoesEntityExist(prop) and GetEntityType(prop) == 3 then DeleteEntity(prop) end
end

local function clearLeash(view)
    deleteProp(view.handle)
    view.handle, view.holder = nil, nil
end

function ClearSyncedPetVisuals(netId)
    local view = visuals[netId]
    if not view then return end
    for _, prop in pairs(view.props) do deleteProp(prop) end
    for hash in pairs(view.models) do SetModelAsNoLongerNeeded(hash) end
    clearLeash(view)
    visuals[netId] = nil
end

local function modelReady(view, hash)
    local now = GetGameTimer()
    local pending = view.models[hash]
    if pending and now < pending.retryAt then return false end
    if HasModelLoaded(hash) then return true end
    if not pending then
        pending = { deadline = now + 5000, retryAt = now }
        view.models[hash] = pending
    elseif now >= pending.deadline then
        SetModelAsNoLongerNeeded(hash)
        pending.deadline, pending.retryAt = now + 15000, now + 10000
        return false
    end
    RequestModel(hash)
    return false
end

local function releaseModel(view, hash)
    view.models[hash] = nil
    SetModelAsNoLongerNeeded(hash)
end

local function appearanceKey(pet)
    local parts = { pet.model, pet.owner or '', pet.name or '' }
    local variation = pet.variation or {}
    parts[#parts+1] = tostring(variation.componentId)
    parts[#parts+1] = tostring(variation.textureId)
    local slots = {}
    for slot in pairs(pet.accessories or {}) do slots[#slots+1] = slot end
    table.sort(slots)
    for _, slot in ipairs(slots) do parts[#parts+1] = slot .. '=' .. pet.accessories[slot] end
    return table.concat(parts, '|')
end

local function applyComponents(pet, entity, definitions)
    for _, definition in pairs(definitions) do
        if definition.componentId then SetPedComponentVariation(entity, definition.componentId, 0, 0, 0) end
    end
    if pet.variation then
        SetPedComponentVariation(entity, pet.variation.componentId, 0, pet.variation.textureId, 0)
    end
    for _, item in pairs(pet.accessories or {}) do
        local definition = definitions[item]
        if definition and definition.componentId then
            SetPedComponentVariation(entity, definition.componentId, 0, definition.textureId or 0, 0)
        end
    end
end

local function syncLeash(view, pet)
    local holder = pet.leashOwner and GetPlayerFromServerId(pet.leashOwner) or -1
    holder = holder ~= -1 and GetPlayerPed(holder) or 0
    if holder == 0 or not DoesEntityExist(holder) or IsPedInAnyVehicle(holder, false)
        or IsEntityDead(holder) or IsEntityDead(view.entity) then
        clearLeash(view)
        return
    end
    if view.holder ~= holder or (view.handle and (not DoesEntityExist(view.handle) or GetEntityType(view.handle) ~= 3)) then clearLeash(view) end
    if view.handle then return end
    local hash = joaat('prop_devin_rope_01')
    if not modelReady(view, hash) then return end
    local coords = GetEntityCoords(holder)
    local handle = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    releaseModel(view, hash)
    if handle == 0 then return end
    view.handle, view.holder = handle, holder
    SetEntityCollision(handle, false, false)
    AttachEntityToEntity(handle, holder, GetPedBoneIndex(holder, 6286),
        0.075, 0.0, 0.0, 0.0, 90.0, 0.0, false, false, false, false, 0, true)

end

function SyncPetVisuals()
    if CheckPetAccessoryFitting then CheckPetAccessoryFitting() end
    local pets = GetAllPets()
    for netId, view in pairs(visuals) do
        if not pets[netId] or not DoesEntityExist(view.entity) or not NetworkDoesNetworkIdExist(netId)
            or NetworkGetEntityFromNetworkId(netId) ~= view.entity then ClearSyncedPetVisuals(netId) end
    end
    for netId, pet in pairs(pets) do
        local entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        if entity ~= 0 and DoesEntityExist(entity) then
            local key = appearanceKey(pet)
            local view = visuals[netId]
            if view and view.key ~= key then ClearSyncedPetVisuals(netId); view = nil end
            local definitions = Config.AddonAccessories[pet.model] or {}
            if not view then
                view = { entity = entity, key = key, props = {}, models = {}, fits = {} }
                visuals[netId] = view
                applyComponents(pet, entity, definitions)
            end
            for slot, item in pairs(pet.accessories or {}) do
                local fit = GetPetAccessoryFit(pet.model, item)
                local bone = fit and PetAccessoryBone(entity, fit.bone)
                if fit and bone and bone >= 0 then
                    local prop = view.props[slot]
                    if not prop or not DoesEntityExist(prop) or GetEntityType(prop) ~= 3 then
                        local hash = joaat(item)
                        if modelReady(view, hash) then
                            local coords = GetEntityCoords(entity)
                            prop = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
                            releaseModel(view, hash)
                            if prop ~= 0 then
                                view.props[slot], view.fits[slot] = prop, nil
                                SetEntityCollision(prop, false, false)
                            end
                        end
                    end
                    if prop and prop ~= 0 and DoesEntityExist(prop) and GetEntityType(prop) == 3 then
                        local key = PetAccessoryFitKey(fit) .. ':' .. bone
                        if view.fits[slot] ~= key then
                            AttachPetAccessory(prop, entity, bone, fit)
                            view.fits[slot] = key
                        end
                    end
                elseif view.props[slot] then
                    deleteProp(view.props[slot])
                    view.props[slot], view.fits[slot] = nil, nil
                end
            end
            syncLeash(view, pet)
            for _, owned in ipairs(CurrentPets) do
                if owned.netId == netId then owned.accessoriesProps = view.props end
            end
        end
    end
end

local function finiteCoords(coords)
    return coords.x == coords.x and coords.y == coords.y and coords.z == coords.z
        and math.abs(coords.x) < 100000 and math.abs(coords.y) < 100000 and math.abs(coords.z) < 100000
end

function TickPetLeashes()
    local drawing = false
    for netId, view in pairs(visuals) do
        if view.handle then
            local pet = GetPetByNetId(netId)
            if not pet or not pet.leashOwner or not DoesEntityExist(view.entity) or not DoesEntityExist(view.holder)
                or not DoesEntityExist(view.handle) or GetEntityType(view.handle) ~= 3 or IsPedInAnyVehicle(view.holder, false)
                or IsEntityDead(view.entity) or IsEntityDead(view.holder) then
                clearLeash(view)
            else
                -- Draw a slack cord without attaching rope physics to the networked animal.
                local hand = GetEntityCoords(view.handle)
                local neck = GetPedBoneCoords(view.entity, 39317, 0.0, 0.0, -0.15)
                if finiteCoords(hand) and finiteCoords(neck) then
                    local distance = #(hand - neck)
                    if distance > 0.05 and distance < 20.0 then
                        local sag = math.min(0.45, 0.12 + distance * 0.04)
                        local x, y, z = hand.x, hand.y, hand.z
                        for segment = 1, 10 do
                            local t = segment / 10
                            local nextX = hand.x + (neck.x - hand.x) * t
                            local nextY = hand.y + (neck.y - hand.y) * t
                            local nextZ = hand.z + (neck.z - hand.z) * t - 4 * sag * t * (1 - t)
                            DrawLine(x, y, z, nextX, nextY, nextZ, 95, 72, 48, 255)
                            x, y, z = nextX, nextY, nextZ
                        end
                        drawing = true
                    end
                end
            end
        end
    end
    for _, pet in ipairs(CurrentPets) do
        if pet.leash and not pet.leashPending and (IsPedInAnyVehicle(PlayerPedId(), false) or IsEntityDead(PlayerPedId())) then
            DetachLeash(pet)
        end
    end
    return drawing
end

CreateThread(function()
    -- Also runs for spectators or clients without any pets of their own.
    TriggerServerEvent('electus_pets:requestPetSync')
    while true do Wait(30000); TriggerServerEvent('electus_pets:requestPetSync') end
end)
CreateThread(function()
    while true do Wait(500); SyncPetVisuals() end
end)
CreateThread(function()
    while true do
        local drawing = TickPetLeashes()
        Wait(drawing and 0 or 100)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for netId in pairs(visuals) do ClearSyncedPetVisuals(netId) end
end)
