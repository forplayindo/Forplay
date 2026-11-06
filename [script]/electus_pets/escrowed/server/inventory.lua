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

local function sniffItems(src, name)
    local pet = EP.owned(src, name)
    if not pet or not Config.Pets[pet.model] or not Config.Pets[pet.model].sniff then return {} end
    local restriction = Config.JobRestrictions.sniff
    if restriction ~= 'none' and restriction ~= EP.job(src)
        and not (type(restriction) == 'table' and lib.table.contains(restriction, EP.job(src))) then return {} end
    local items = Config.AllowedSniffedItems
    if Config.EnableLearnToSniff then items = pet.sniffedItems end
    return type(items) == 'table' and items or {}
end

EP.sniffItems = sniffItems

EP.registerCallback('electus_pets:sniffTrunk', function(src, plate, name)
    if type(plate) ~= 'string' or #plate > 16 then return false end
    local saved = EP.owned(src, name)
    local owner = EP.identifier(src)
    local active = saved and EP.activePetForStatus(owner, saved.name)
    if not active or not saved.abilities.searchVehicle or saved.dead or saved.stored
        or not EP.near(src, GetEntityCoords(active.entity), 10.0)
        or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(active.entity) then return false end
    plate = plate:match('^%s*(.-)%s*$')
    local items = sniffItems(src, name)
    if #items == 0 then return false end
    local vehicle
    for _, entity in ipairs(GetAllVehicles()) do
        if GetEntityRoutingBucket(entity) == GetPlayerRoutingBucket(src)
            and GetVehicleNumberPlateText(entity):match('^%s*(.-)%s*$') == plate:match('^%s*(.-)%s*$')
            and EP.near(src, GetEntityCoords(entity), 6.0) then vehicle = entity; break end
    end
    if not vehicle then return false end
    if Config.VehicleInventory == 'ox_inventory' then
        local inventory = exports.ox_inventory:GetInventory({ id = 'trunk' .. GetVehicleNumberPlateText(vehicle),
            netid = NetworkGetNetworkIdFromEntity(vehicle) })
        if not inventory then return false end
        local contents = exports.ox_inventory:GetInventoryItems(inventory.id) or {}
        for _, entry in pairs(contents) do
            if (entry.count or 0) > 0 and lib.table.contains(items, entry.name) then return true end
        end
    elseif Config.VehicleInventory == 'qb' or Config.VehicleInventory == 'qb-inventory' then
        local inventory = exports['qb-inventory']:GetInventory('trunk-' .. plate)
        for _, entry in pairs(inventory and inventory.items or {}) do
            if (entry.amount or 0) > 0 and lib.table.contains(items, entry.name) then return true end
        end
    elseif Config.VehicleInventory == 'custom' and Config.GetCustomVehiclePlateInventoryItems then
        for _, entry in pairs(Config.GetCustomVehiclePlateInventoryItems(plate) or {}) do
            if (entry.count or entry.amount or 0) > 0 and lib.table.contains(items, entry.name) then return true end
        end
    end
    return false
end)

-- Bag access uses an active owned pet and opens only that pet's stash.
local grants = {}
local function findBag(src, name, owner)
    local visitor = EP.identifier(src)
    if not visitor or not Config.EnablePetBags or type(name) ~= 'string' or type(owner) ~= 'string' then return end
    for _, entry in pairs(EP.activePets) do
        if entry.ready and entry.owner == owner and entry.pet.name == name and DoesEntityExist(entry.entity)
            and GetPlayerRoutingBucket(src) == GetEntityRoutingBucket(entry.entity)
            and EP.near(src, GetEntityCoords(entry.entity), 3.0) then
            local row = MySQL.single.await('SELECT data FROM electus_pets WHERE owner=? AND name=?', { owner, name })
            local pet = row and EP.decode(row.data, nil)
            if EP.identifier(src) ~= visitor or EP.activePets[entry.netId] ~= entry or not DoesEntityExist(entry.entity)
                or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity)
                or not EP.near(src, GetEntityCoords(entry.entity), 3.0) then return end
            if pet and not pet.dead and not pet.stored and pet.accessories and pet.accessories.bag then return pet end
        end
    end
end

local function openBag(src, name, owner)
    local pet = findBag(src, name, owner)
    if not pet then return end
    local stash = owner .. '-pet-' .. name
    local grant = grants[src] and grants[src][stash]
    if EP.identifier(src) ~= owner and (not grant or grant.character ~= EP.identifier(src) or grant.expires < os.time()) then return end
    if Config.Inventory == 'ox_inventory' then
        -- Access must always pass this handler; no globally open registered stash.
        exports.ox_inventory:RegisterStash(stash, name .. ' bag', Config.Bags.maxSlots, Config.Bags.maxWeight, owner)
        exports.ox_inventory:forceOpenInventory(src, 'stash', { id = stash, owner = owner })
    elseif Config.Inventory == 'qb' or Config.Inventory == 'qb-inventory' then
        exports['qb-inventory']:OpenInventory(src, stash, { label = name .. ' bag', maxweight = Config.Bags.maxWeight, slots = Config.Bags.maxSlots })
    end
end
RegisterNetEvent('electus_pets:openBagInventory', function(name, owner) openBag(source, name, owner) end)
RegisterNetEvent('electus_pets:unlockBag', function(owner, name, password)
    local src = source
    local pet = findBag(src, name, owner)
    if not pet or type(password) ~= 'string' or #password > 64 then return end
    if EP.identifier(src) ~= owner and (not pet.bagPassword or pet.bagPassword ~= password) then return end
    grants[src] = grants[src] or {}
    grants[src][owner .. '-pet-' .. name] = { character = EP.identifier(src), expires = os.time() + 30 }
    openBag(src, name, owner)
end)
RegisterNetEvent('electus_pets:registerBagPassword', function(name, password)
    if type(password) ~= 'string' or #password < 1 or #password > 64 then return end
    local src = source
    EP.withPetLock(src, function(owner)
        local pet = EP.owned(src, name)
        if not pet or not pet.accessories or not pet.accessories.bag then return end
        pet.bagPassword = password
        if not EP.savePet(owner, pet) then return end
        for _, access in pairs(grants) do access[owner .. '-pet-' .. name] = nil end
    end)
end)
AddEventHandler('playerDropped', function() grants[source] = nil end)
