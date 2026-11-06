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

local function active(owner, name)
    for _, entry in pairs(EP.activePets) do
        if entry.owner == owner and entry.pet.name == name and entry.ready and DoesEntityExist(entry.entity) then return entry end
    end
end
EP.activePetForStatus = active

-- Accrue only time spent outside. The saved remainder survives storage/restarts.
function EP.capturePetStatus(entry, pet)
    local status = NormalizePetStatus(pet)
    local now = os.time()
    local interval = math.max(1, tonumber((Config.Delays or {}).statusRemoval) or 450)
    local elapsed = status.needSeconds + math.max(0, now - (entry.statusAt or now))
    local steps = math.floor(elapsed / interval)
    local hungry, thirsty = status.hunger, status.thirst
    local observed = status.health
    if entry.ready and DoesEntityExist(entry.entity) then
        local health = GetEntityHealth(entry.entity)
        local initializing = health <= 0 and entry.initialHealthUntil and now < entry.initialHealthUntil
        if not initializing and (health <= 0 or not entry.healthPendingUntil or now >= entry.healthPendingUntil or health == status.health) then
            observed = math.max(0, math.min(PetMaxHealth(pet), health))
            entry.healthPendingUntil = nil
        end
    end
    status.hunger, status.thirst = math.max(0, hungry - steps), math.max(0, thirsty - steps)
    status.needSeconds = elapsed % interval
    local emptySteps = math.min(steps, math.max(0, steps - math.ceil(math.min(hungry, thirsty)) + 1))
    status.health = math.max(0, observed - emptySteps * 10)
    if status.health <= 0 then
        pet.dead, pet.stored, pet.recoverAt = true, true, now + (Config.PetRecoverTime or 20) * 60
    end
    return { now = now, observed = observed, delta = status.health - observed }
end

function EP.commitPetStatus(entry, pet, effects)
    entry.statusAt, entry.pet = effects.now, pet
    if effects.delta ~= 0 then entry.healthPendingUntil = effects.now + 3 end
    if EP.identifier(entry.source) == entry.owner then
        EP.syncPet(entry.source, pet)
        if effects.delta ~= 0 and not pet.dead then
            entry.healthRevision = (entry.healthRevision or 0) + 1
            TriggerClientEvent('electus_pets:applyHealth', entry.source, pet.name, entry.netId, pet.status.health, effects.delta, entry.healthRevision)
        end
    end
    if pet.dead then EP.removeActivePet(entry.netId, true) end
end

function EP.updatePetStatus(entry, forceSave)
    return EP.withOwnerLock(entry.owner, function(owner)
        if EP.activePets[entry.netId] ~= entry or not entry.ready then return false end
        if not forceSave and DoesEntityExist(entry.entity) then
            local known = NormalizePetStatus(entry.pet)
            local interval = math.max(1, tonumber((Config.Delays or {}).statusRemoval) or 450)
            local due = known.needSeconds + math.max(0, os.time() - (entry.statusAt or os.time())) >= interval
            if not due and GetEntityHealth(entry.entity) == known.health then return true end
        end
        local pet = EP.getPet(owner, entry.pet.name)
        if not pet or pet.stored or pet.dead then return false end
        local status = NormalizePetStatus(pet)
        local health, hunger, thirst = status.health, status.hunger, status.thirst
        local effects = EP.capturePetStatus(entry, pet)
        if not forceSave and status.health == health and status.hunger == hunger and status.thirst == thirst then return true end
        if not EP.savePet(owner, pet) then return false end
        EP.commitPetStatus(entry, pet, effects)
        return true
    end)
end

function EP.careForPet(src, name, kind)
    if kind ~= 'feed' and kind ~= 'water' then return false end
    return EP.withPetLock(src, function(owner)
        local pet = EP.owned(src, name)
        local entry = pet and active(owner, name)
        if not entry or pet.dead or pet.stored or not EP.near(src, GetEntityCoords(entry.entity), 10.0)
            or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity) then return { error = 'tooFarAway' } end
        local effects = EP.capturePetStatus(entry, pet)
        if pet.dead then
            if EP.savePet(owner, pet) then EP.commitPetStatus(entry, pet, effects) end
            return { error = 'careFailed' }
        end
        local feeding = kind == 'feed'
        local key = feeding and 'hunger' or 'thirst'
        if pet.status[key] >= 100 then return { error = feeding and 'notHungry' or 'notThirsty' } end
        local item = feeding and Config.Items.petFood or Config.Items.petWater
        local gain = tonumber(feeding and Config.PetFeeding.feedGain or Config.PetFeeding.waterGain)
        if not gain or gain ~= gain or gain <= 0 or gain == math.huge then return { error = 'careFailed' } end
        if not EP.removeItem(src, item, 1) then return { error = feeding and 'noFood' or 'noWater' } end
        pet.status[key] = math.min(100, pet.status[key] + gain)
        if feeding and pet.abilities.addHealthEating then
            local heal = tonumber((Config.AbilitiesUpgrade.addHealthEating or {}).amountOfHealth) or 0
            if heal == heal and heal > 0 and heal < math.huge then
                pet.status.health = math.min(PetMaxHealth(pet), pet.status.health + heal)
            end
        end
        effects.delta = pet.status.health - effects.observed
        local ok, saved = pcall(EP.savePet, owner, pet)
        if not ok or not saved then EP.addItem(src, item, 1); return { error = 'careFailed' } end
        EP.commitPetStatus(entry, pet, effects)
        local reward = (Config.RewardsXP or {})[feeding and 'eat' or 'drink'] or 0
        local awarded, err = pcall(EP.awardXP, src, name, reward)
        if not awarded then print(('electus_pets: care XP failed: %s'):format(err)) end
        return { success = true }
    end)
end
EP.registerCallback('electus_pets:careForPet', EP.careForPet)

EP.registerCallback('electus_pets:setStatus', function(src, name, key, enabled)
    if (key ~= 'tracker' and key ~= 'autoAttack') or type(enabled) ~= 'boolean' then return false end
    return EP.withPetLock(src, function(owner)
        local pet = EP.owned(src, name)
        if not pet then return false end
        NormalizePetStatus(pet)
        if key == 'autoAttack' and enabled and (not pet.abilities.autoAttack or not (Config.Pets[pet.model] or {}).attack) then return false end
        pet.status[key] = enabled
        if not EP.savePet(owner, pet) then return false end
        EP.syncPet(src, pet)
        return true
    end)
end)

CreateThread(function()
    while true do
        Wait(5000)
        for _, entry in pairs(EP.activePets) do
            local ok, err = pcall(EP.updatePetStatus, entry, false)
            if not ok then print(('electus_pets: status update failed: %s'):format(err)) end
        end
    end
end)
