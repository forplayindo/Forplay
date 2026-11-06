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

-- OneSync entities are created from database records, never client pet data.
EP.activePets = {}
local spawning = {}
local petting, pettingPlayers, pettingSequence = {}, {}, 0
local catalogRevision, snapshotRequests = 0, {}

local function finishPetting(netId, token)
    local session = petting[netId]
    if not session or session.token ~= token then return end
    petting[netId], pettingPlayers[session.player] = nil, nil
    TriggerClientEvent('electus_pets:finishPetting', session.owner, netId, token)
end

local function publicPet(entry)
    local pet = entry.pet
    return { netId = entry.netId, model = pet.model, name = pet.name, owner = pet.owner,
        hasBag = pet.accessories and pet.accessories.bag ~= nil, accessories = pet.accessories or {},
        variation = pet.variation, leashOwner = entry.leashOwner, revision = entry.publicRevision or 0 }
end

function EP.syncPets(src)
    local pets = {}
    for netId, entry in pairs(EP.activePets) do if entry.ready then pets[netId] = publicPet(entry) end end
    TriggerClientEvent('electus_pets:accessoryFits', src, Config.AccessoryFits)
    TriggerClientEvent('electus_pets:loadAllPets', src, pets, catalogRevision)
end

function EP.publishPet(entry)
    if not entry.ready then return end
    catalogRevision = catalogRevision + 1
    entry.publicRevision = catalogRevision
    TriggerClientEvent('electus_pets:insertPet', -1, publicPet(entry))
end

RegisterNetEvent('electus_pets:requestPetSync', function()
    local src, now = source, GetGameTimer()
    if not GetPlayerName(src) or now < (snapshotRequests[src] or 0) then return end
    snapshotRequests[src] = now + 2000
    EP.syncPets(src)
end)

EP.registerCallback('electus_pets:setLeash', function(src, netId, enabled)
    local entry = EP.activePets[tonumber(netId)]
    if type(enabled) ~= 'boolean' or not entry or not entry.ready or entry.owner ~= EP.identifier(src) then return false end
    if enabled and (not DoesEntityExist(entry.entity) or GetEntityHealth(entry.entity) <= 0
        or not EP.near(src, GetEntityCoords(entry.entity), 4.0)
        or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity)
        or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 or EP.itemCount(src, Config.Items.petLeash) < 1) then return false end
    entry.leashOwner = enabled and src or nil
    EP.publishPet(entry)
    return true
end)

function EP.reconcilePetSync()
    for _, entry in pairs(EP.activePets) do
        if entry.ready and EP.identifier(entry.source) ~= entry.owner then
            EP.removeActivePet(entry.netId)
        elseif entry.ready and DoesEntityExist(entry.entity) then
            local bucket = GetPlayerRoutingBucket(entry.source)
            local changedBucket = GetEntityRoutingBucket(entry.entity) ~= bucket
            if changedBucket then SetEntityRoutingBucket(entry.entity, bucket) end
            if entry.leashOwner and (changedBucket or GetVehiclePedIsIn(GetPlayerPed(entry.source), false) ~= 0) then
                entry.leashOwner = nil
                EP.publishPet(entry)
            end
        end
    end
end
CreateThread(function()
    while true do Wait(2000); EP.reconcilePetSync() end
end)

function EP.refreshActivePet(src, pet)
    local owner = EP.identifier(src)
    for _, entry in pairs(EP.activePets) do
        if entry.owner == owner and entry.pet.name == pet.name then
            entry.pet = pet
            EP.publishPet(entry)
        end
    end
end

function EP.removeActivePet(netId, statusSaved)
    local entry = EP.activePets[netId]
    if not entry then return end
    if not statusSaved and entry.ready and EP.updatePetStatus then
        EP.updatePetStatus(entry, true)
        if EP.activePets[netId] ~= entry then return end
    end
    if petting[netId] then finishPetting(netId, petting[netId].token) end
    EP.activePets[netId] = nil
    if DoesEntityExist(entry.entity) then DeleteEntity(entry.entity) end
    catalogRevision = catalogRevision + 1
    TriggerClientEvent('electus_pets:removePet', -1, netId, catalogRevision)
end

local function spawnPet(src, request, coords)
    local owner = EP.identifier(src)
    if not owner or spawning[src] or type(request) ~= 'table' or not EP.near(src, coords, 5.0) then return end
    local spawnToken = {}
    spawning[src] = spawnToken
    local createdNetId, createdEntity, createdEntry
    local ok, result = pcall(function() return EP.withOwnerLock(owner, function()
        local pet = EP.owned(src, request.name)
        if not pet or pet.dead or pet.stored or not Config.Pets[pet.model] then return end
        NormalizePetStatus(pet)
        local count = 0
        for _, entry in pairs(EP.activePets) do
            if entry.owner == owner then
                if entry.pet.name == pet.name then return end
                count = count + 1
            end
        end
        if count >= Config.MaxAmountPetOutside then return end
        local entity = CreatePed(28, joaat(pet.model), coords.x, coords.y, coords.z, 0.0, true, true)
        createdEntity = entity
        if entity == 0 then return end
        local deadline = GetGameTimer() + 5000
        while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end
        if not DoesEntityExist(entity) then return end
        SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(src))
        SetEntityOrphanMode(entity, 2)
        local netId = NetworkGetNetworkIdFromEntity(entity)
        createdNetId = netId
        pet.owner, pet.netId = owner, netId
        local entry = { owner = owner, source = src, entity = entity, netId = netId, pet = pet }
        createdEntry = entry
        EP.activePets[netId] = entry
        local configured, accepted = pcall(lib.callback.await, 'electus_pets:setPetData', src, pet)
        if not configured or accepted ~= true or EP.identifier(src) ~= owner or spawning[src] ~= spawnToken
            or EP.activePets[netId] ~= entry or not DoesEntityExist(entity) then return false end
        entry.ready, entry.statusAt = true, os.time()
        entry.initialHealthUntil = os.time() + 3
        EP.publishPet(entry)
        return true
    end) end)
    if spawning[src] == spawnToken then spawning[src] = nil end
    if not ok or result ~= true then
        if createdEntry and EP.activePets[createdNetId] == createdEntry then EP.removeActivePet(createdNetId)
        elseif not createdEntry and createdEntity and createdEntity ~= 0 then pcall(DeleteEntity, createdEntity) end
    end
    if not ok then
        print(('electus_pets: pet spawn failed: %s'):format(result))
    end
    return ok and result == true
end
EP.registerCallback('electus_pets:spawnPet', spawnPet)
RegisterNetEvent('electus_pets:spawnPet', function(request, coords) spawnPet(source, request, coords) end)

local function despawnPet(src, netId)
    local entry = EP.activePets[tonumber(netId)]
    if not entry then return true end
    if entry.owner ~= EP.identifier(src) then return false end
    if entry.ready and not EP.updatePetStatus(entry, true) then return false end
    EP.removeActivePet(tonumber(netId), true)
    return true
end
EP.registerCallback('electus_pets:despawnPet', despawnPet)
RegisterNetEvent('electus_pets:removePet', function(netId) despawnPet(source, netId) end)

RegisterNetEvent('electus_pets:tryToGetPetBack', function(netId)
    local entry = EP.activePets[tonumber(netId)]
    if entry and entry.owner == EP.identifier(source) then
        if DoesEntityExist(entry.entity) then
            TriggerClientEvent('electus_pets:tryToGetPetBack', source, entry.netId)
        else
            local src, pet = source, entry.pet
            EP.removeActivePet(entry.netId)
            TriggerClientEvent('electus_pets:spawnPet', src, pet)
        end
    end
end)

RegisterNetEvent('electus_pets:petDog', function(netId)
    local src = source
    netId = tonumber(netId)
    local entry = EP.activePets[netId]
    if not entry or not Config.PettableDogs[entry.pet.model] or not DoesEntityExist(entry.entity) then return end
    if petting[netId] or pettingPlayers[src] or not EP.identifier(src) or EP.identifier(entry.source) ~= entry.owner then return end
    if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity) or not EP.near(src, GetEntityCoords(entry.entity), 3.0) then return end
    pettingSequence = pettingSequence + 1
    local token = pettingSequence
    petting[netId] = { token = token, player = src, owner = entry.source }
    pettingPlayers[src] = netId
    SetTimeout(45000, function() finishPetting(netId, token) end)
    local ok, played = pcall(function()
        if not lib.callback.await('electus_pets:preparePetting', entry.source, netId, token) then return false end
        if not petting[netId] or petting[netId].token ~= token then return false end
        return lib.callback.await('electus_pets:playPetting', src, netId)
    end)
    finishPetting(netId, token)
    if not ok then print(('electus_pets: petting failed: %s'):format(played)) end
    if not ok or not played then
        TriggerClientEvent('ox_lib:notify', src, { description = 'The pet cannot interact right now.', type = 'error' })
    end
end)

local function cleanup(src)
    for netId, session in pairs(petting) do
        if session.player == src or session.owner == src then finishPetting(netId, session.token) end
    end
    for netId, entry in pairs(EP.activePets) do
        if entry.source == src then EP.removeActivePet(netId) end
    end
    spawning[src] = nil
    snapshotRequests[src] = nil
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) cleanup(tonumber(src) or source) end)
AddEventHandler('esx:playerLogout', function(src) cleanup(tonumber(src) or source) end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for netId in pairs(EP.activePets) do EP.removeActivePet(netId) end
end)

-- Trusted server-only creation API for admin rewards or other resources.
exports('GivePet', function(src, model, name, variation)
    local owner = EP.identifier(src)
    return owner and EP.insertPet(owner, model, name, variation) or false
end)
