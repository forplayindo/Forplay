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

local function locked(src, action)
    return EP.withPetLock(src, action)
end

local function house(src, owner, id)
    if id == -2 then
        if Config.EnablePetCommandForHouse then return { id = -2, pets = {}, maxPets = Config.MaxAmountPetInsideCommandHouse } end
        return
    end
    local row = MySQL.single.await('SELECT id,house_type,coords,pets FROM electus_pet_houses WHERE id=? AND owner=?', { id, owner })
    if not row or not Config.PetHouseModels[row.house_type] then return end
    row.coords, row.pets = EP.decode(row.coords, {}), EP.decode(row.pets, {})
    if not EP.near(src, row.coords, 5.0) then return end
    row.maxPets = Config.PetHouseModels[row.house_type].maxPets
    return row
end

EP.registerCallback('electus_pets:getPetHouseData', function(src, id)
    id = tonumber(id)
    local owner = EP.identifier(src)
    local data = owner and house(src, owner, id)
    if not data then return end
    local pets = {}
    for _, pet in ipairs(EP.getPets(owner)) do
        if pet.stored and not pet.dead and (pet.houseId == id or (id == -2 and not pet.houseId)) then pets[#pets + 1] = pet end
    end
    return { id = id, owner = owner, pets = pets, maxHouseSlots = data.maxPets,
        data = { houseType = data.house_type, coords = data.coords, pets = pets } }
end)

EP.registerCallback('electus_pets:placeHouse', function(src, kind, coords)
    if not Config.EnablePetHouse or type(kind) ~= 'string' then return false end
    local definition = Config.PetHouseModels[kind]
    if not definition or not EP.near(src, coords, 10.0) or type(coords.w) ~= 'number' or coords.w ~= coords.w then return false end
    return locked(src, function(owner)
        if not EP.removeItem(src, definition.itemName, 1) then return false end
        local ok, id = pcall(MySQL.insert.await,
            'INSERT INTO electus_pet_houses(owner,house_type,coords,pets) VALUES(?,?,?,?)', { owner, kind, json.encode(coords), '[]' })
        if not ok or type(id) ~= 'number' or id <= 0 then EP.addItem(src, definition.itemName, 1); return false end
        return id
    end)
end)

EP.registerCallback('electus_pets:storePet', function(src, id, name)
    id = tonumber(id)
    return locked(src, function(owner)
        local data = house(src, owner, id)
        local pet = EP.owned(src, name)
        if not data or not pet or pet.stored or pet.dead then return false end
        local count = 0
        for _, saved in ipairs(EP.getPets(owner)) do
            if saved.stored and (saved.houseId == id or (id == -2 and not saved.houseId)) then count = count + 1 end
        end
        if count >= data.maxPets then return false end
        local active = EP.activePetForStatus(owner, name)
        if active then EP.capturePetStatus(active, pet) end
        pet.stored, pet.houseId = true, id
        local queries = {{ query = 'UPDATE electus_pets SET data=? WHERE owner=? AND name=?', values = { json.encode(pet), owner, name } }}
        if id ~= -2 then
            data.pets[#data.pets + 1] = name
            queries[#queries + 1] = { query = 'UPDATE electus_pet_houses SET pets=? WHERE id=? AND owner=?', values = { json.encode(data.pets), id, owner } }
        end
        if not MySQL.transaction.await(queries) then return false end
        for netId, entry in pairs(EP.activePets) do
            if entry.owner == owner and entry.pet.name == name then EP.removeActivePet(netId, true) end
        end
        return true
    end)
end)

EP.registerCallback('electus_pets:withdrawPet', function(src, id, name)
    id = tonumber(id)
    return locked(src, function(owner)
        local data, pet = house(src, owner, id), EP.owned(src, name)
        if not data or not pet or not pet.stored or pet.dead or (pet.houseId ~= id and not (id == -2 and not pet.houseId)) then return false end
        local count = 0
        for _, entry in pairs(EP.activePets) do if entry.owner == owner then count = count + 1 end end
        if count >= Config.MaxAmountPetOutside then return false end
        pet.stored, pet.houseId = false, nil
        local queries = {{ query = 'UPDATE electus_pets SET data=? WHERE owner=? AND name=?', values = { json.encode(pet), owner, name } }}
        if id ~= -2 then
            for i = #data.pets, 1, -1 do if data.pets[i] == name then table.remove(data.pets, i) end end
            queries[#queries + 1] = { query = 'UPDATE electus_pet_houses SET pets=? WHERE id=? AND owner=?', values = { json.encode(data.pets), id, owner } }
        end
        return MySQL.transaction.await(queries) and pet or false
    end)
end)

EP.registerCallback('electus_pets:removeHouse', function(src, id)
    id = tonumber(id)
    if id == -2 then return false end
    return locked(src, function(owner)
        local data = house(src, owner, id)
        if not data or #data.pets > 0 then return false end
        for _, pet in ipairs(EP.getPets(owner)) do if pet.stored and pet.houseId == id then return false end end
        local item = Config.PetHouseModels[data.house_type].itemName
        if not EP.addItem(src, item, 1) then return false end
        local ok, changed = pcall(MySQL.update.await, 'DELETE FROM electus_pet_houses WHERE id=? AND owner=?', { id, owner })
        if not ok or changed ~= 1 then EP.removeItem(src, item, 1); return false end
        return true
    end)
end)

RegisterNetEvent('electus_pets:getPetHouses', function()
    local src, owner = source, EP.identifier(source)
    if not owner then return end
    local rows = MySQL.query.await('SELECT id,house_type,coords,pets FROM electus_pet_houses WHERE owner=?', { owner }) or {}
    if EP.identifier(src) ~= owner then return end
    for _, row in ipairs(rows) do TriggerClientEvent('electus_pets:spawnPetHouse', src, row.id, row.house_type, EP.decode(row.coords, {})) end
end)

if Config.Inventory ~= 'ox_inventory' then
    for kind, definition in pairs(Config.PetHouseModels) do
        local function use(src)
            if EP.itemCount(src, definition.itemName) > 0 then TriggerClientEvent('electus_pets:placeProp', src, kind) end
        end
        if EP.ESX then EP.ESX.RegisterUsableItem(definition.itemName, use)
        elseif EP.QBCore then EP.QBCore.Functions.CreateUseableItem(definition.itemName, use)
        else exports.qbx_core:CreateUseableItem(definition.itemName, use) end
    end
end
