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

-- Bootstrap: framework adapters and inventory.lua load before this file.
assert(EP and EP.identifier, 'electus_pets: no framework adapter loaded')
local petLocks = {}
function EP.withOwnerLock(owner, action)
    if not owner or petLocks[owner] then return false end
    petLocks[owner] = true
    local ok, result = pcall(action, owner)
    petLocks[owner] = nil
    if not ok then print(('electus_pets: pet update failed: %s'):format(result)); return false end
    return result
end

function EP.withPetLock(src, action)
    return EP.withOwnerLock(EP.identifier(src), action)
end

function EP.syncPet(src, pet)
    if EP.refreshActivePet then EP.refreshActivePet(src, pet) end
    TriggerClientEvent('electus_pets:syncPet', src, { name = pet.name, skills = pet.skills,
        status = pet.status, abilities = pet.abilities, accessories = pet.accessories, sniffedItems = pet.sniffedItems })
end

function EP.registerCallback(name, handler)
    lib.callback.register(name, handler)
    if EP.ESX then
        EP.ESX.RegisterServerCallback(name, function(src, cb, ...)
            cb(handler(src, ...))
        end)
    elseif EP.QBCore then
        EP.QBCore.Functions.CreateCallback(name, function(src, cb, ...)
            cb(handler(src, ...))
        end)
    end
end

function EP.decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

function EP.near(src, coords, distance)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' and type(coords) ~= 'vector4' then return false end
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return false end
    local ped = GetPlayerPed(src)
    return ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) <= distance
end

function EP.findPetShop(src, model)
    for _, shop in pairs(Config.PetShop) do
        local requirement = shop.jobRequirement
        local allowed = requirement == 'none' or requirement == nil or requirement == EP.job(src)
            or (type(requirement) == 'table' and lib.table.contains(requirement, EP.job(src)))
        if allowed and EP.near(src, shop.markerCoords, 10.0) and lib.table.contains(shop.pets, model) then return shop end
    end
end

AddEventHandler('onResourceStart',function(resource)
    if resource~=GetCurrentResourceName() then return end
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS electus_pets (id INT AUTO_INCREMENT PRIMARY KEY, owner VARCHAR(80) NOT NULL, name VARCHAR(64) NOT NULL, data LONGTEXT NOT NULL, UNIQUE KEY owner_pet(owner,name))]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS electus_pet_houses (id INT AUTO_INCREMENT PRIMARY KEY, owner VARCHAR(80) NOT NULL, house_type VARCHAR(64) NOT NULL, coords LONGTEXT NOT NULL, pets LONGTEXT NOT NULL)]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS electus_pet_friends (owner VARCHAR(80) PRIMARY KEY, friends LONGTEXT NOT NULL)]])
end)
