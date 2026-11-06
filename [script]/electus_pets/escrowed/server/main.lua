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

local function ident(src) return EP.identifier(src) end
local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = kind or 'inform' })
end
local function decode(v, fallback)
    return EP.decode(v, fallback)
end
local function getPets(owner)
    local rows = MySQL.query.await('SELECT data FROM electus_pets WHERE owner = ?', { owner })
    if type(rows) ~= 'table' then error('Pet database query did not return a list') end
    local out = {}
    for _, row in ipairs(rows) do
        local pet = decode(row.data, nil)
        if pet then
            NormalizePetStatus(pet)
            for _, key in ipairs({'xp','bravery','speed','health','thoughness','obedience','sniff','skillPoints'}) do pet.skills[key]=tonumber(pet.skills[key]) or 0 end
            local recoverAt = tonumber(pet.recoverAt)
            if pet.dead and recoverAt and recoverAt<=os.time() then
                pet.dead, pet.recoverAt, pet.status.health=false,nil,PetMaxHealth(pet)
                EP.savePet(owner,pet)
            end
            out[#out+1]=pet
        end
    end
    return out
end
local function savePet(owner, pet)
    if type(pet) ~= 'table' or type(pet.name) ~= 'string' then return false end
    NormalizePetStatus(pet)
    local payload = json.encode(pet)
    return MySQL.update.await('UPDATE electus_pets SET data = ? WHERE owner = ? AND name = ?', { payload, owner, pet.name }) == 1
end
local function getPet(owner, petName)
    if not owner or type(petName) ~= 'string' then return nil end
    local row = MySQL.single.await('SELECT data FROM electus_pets WHERE owner = ? AND name = ?', { owner, petName })
    local pet = row and decode(row.data, nil)
    if pet then NormalizePetStatus(pet) end
    return pet, owner
end
local function owned(src, petName)
    return getPet(ident(src), petName)
end
local function insertPet(owner, model, name, variation, startingPoints)
    if not Config.Pets[model] then return false end
    name = tostring(name or Config.Pets[model].label):sub(1, 32)
    if not name:find('%S') then return false end
    if type(variation) ~= 'table' then variation = (Config.PetVariations[model] or {})[1] or { componentId = 0, textureId = 0 } end
    local validVariation = not Config.PetVariations[model] and variation.componentId == 0 and variation.textureId == 0
    for _, entry in ipairs(Config.PetVariations[model] or {}) do
        if variation.componentId == entry.componentId and variation.textureId == entry.textureId then validVariation = true; break end
    end
    if not validVariation then return false end
    local existing = MySQL.scalar.await('SELECT 1 FROM electus_pets WHERE owner = ? AND name = ?', { owner, name })
    if existing then return false end
    local pet = {
        name=name, model=model, owner=owner, variation=variation or {componentId=0, textureId=0},
        bornAt=os.time(), stored=false, dead=false, sniffedItems={}, accessories={}, abilities={},
        skills={ xp=0, level=1, bravery=0, speed=0, health=0, thoughness=0, obedience=0, sniff=0, skillPoints=startingPoints or 0 },
        status={ hunger=100, thirst=100, health=200, tracker=false }, dailyTasks={}, sex=math.random(0,1)==0 and 'male' or 'female',
        breedingSeed=math.random(100000,999999), numOfBreedings=0
    }
    local id=MySQL.insert.await('INSERT INTO electus_pets (owner,name,data) VALUES (?,?,?)', {owner,name,json.encode(pet)})
    return type(id)=='number' and id>0
end

EP.getPets, EP.savePet, EP.owned, EP.insertPet = getPets, savePet, owned, insertPet
EP.getPet = getPet

EP.registerCallback('electus_pets:getPets', function(src)
    local owner=ident(src)
    if not owner then return { error = 'player_not_ready' } end
    local ok, pets = pcall(function()
        EP.syncPets(src)
        return getPets(owner)
    end)
    if not ok then
        print(('electus_pets: getPets failed for player %s: %s'):format(src, pets))
        return { error = 'pets_load_failed' }
    end
    return pets
end)
EP.registerCallback('electus_pets:getDeadPets', function(src)
    local owner=ident(src); if not owner then return {} end
    local out={}; for _,p in ipairs(getPets(owner)) do if p.dead then out[#out+1]=p end end; return out
end)
EP.registerCallback('electus_pets:hasItem', function(src,item)
    return type(item)=='string' and EP.itemCount(src,item)>0 or false
end)
EP.registerCallback('electus_pets:hasItems', function(src,items)
    local out={}; if type(items)~='table' then return out end
    for _,name in ipairs(items) do if type(name)=='string' and EP.itemCount(src,name)>0 then out[#out+1]=name end end
    return out
end)
EP.registerCallback('electus_pets:updateAccessories', function(src, request, item, action)
    return EP.withPetLock(src, function(owner)
        local pet = owned(src, type(request)=='table' and request.name)
        if not pet or type(item)~='string' or #item>80 then return false end
        local slot
        for category, entries in pairs(Config.AccessoryShop.shopItems) do
            for _, entry in ipairs(entries) do if entry.name==item and category~='items' then slot=category end end
        end
        if not slot then return false end
        pet.accessories=pet.accessories or {}
        if action=='removeItem' then
            if not (Config.AddonAccessories[pet.model] or {})[item] or pet.accessories[slot] or not EP.removeItem(src,item,1) then return false end
            pet.accessories[slot]=item
        elseif action=='addItem' then
            if pet.accessories[slot]~=item or not EP.addItem(src,item,1) then return false end
            pet.accessories[slot]=nil
        else return false end
        local ok, saved=pcall(savePet,owner,pet)
        if not ok or not saved then
            if action=='removeItem' then EP.addItem(src,item,1) else EP.removeItem(src,item,1) end
            return false
        end
        EP.syncPet(src,pet)
        return true
    end)
end)
EP.registerCallback('electus_pets:searchPlayer', function(src, target, request)
    target = tonumber(target)
    if not target or target < 1 or target % 1 ~= 0 or not EP.identifier(target) then return false end
    local saved = owned(src, type(request) == 'table' and request.name or request)
    local entry = saved and EP.activePetForStatus(ident(src), saved.name)
    if not entry or saved.dead or saved.stored or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(target)
        or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity)
        or not EP.near(src, GetEntityCoords(entry.entity), 10.0) then return false end
    local player, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if not DoesEntityExist(player) or not DoesEntityExist(targetPed)
        or #(GetEntityCoords(player) - GetEntityCoords(targetPed)) > 5.0 then return false end
    for _, item in ipairs(EP.sniffItems(src, saved.name)) do
        if EP.itemCount(target, item) > 0 then return true end
    end
    return false
end)
EP.registerCallback('electus_pets:getItemLabel', function(_,item)
    return EP.itemLabel(item)
end)
EP.registerCallback('electus_pets:getJobsName', function(_,requested)
    local jobs={}; for name,data in pairs(EP.jobs()) do
        if type(requested)~='table' or lib.table.contains(requested,name) then jobs[#jobs+1]={name=name,label=data.label} end
    end; return jobs
end)
EP.registerCallback('electus_pets:confirmDogHump', function() return false end)

RegisterNetEvent('electus_pets:purchasePet',function(model,variation,payment,name)
    local src=source; local owner=ident(src); local def=Config.Pets[type(model)=='table' and model.model or model]
    model=type(model)=='table' and model.model or model
    local shop=EP.findPetShop(src,model)
    if not owner or not def or not shop then return end
    local price=math.floor((def.price or 0)*(shop.priceModifier or 1.0)); if price<1 then return end
    local account=payment=='cash' and 'cash' or payment=='bank' and 'bank'
    if not account or not EP.removeMoney(src,account,price) then return notify(src,'Insufficient funds.','error') end
    local ok,created=pcall(insertPet,owner,model,name,variation,shop.startingSkillPoints)
    if not ok or not created then
        EP.addMoney(src,account,price)
        return notify(src,'Pet could not be created.','error')
    end
    local purchased=owned(src,tostring(name or def.label):sub(1,32))
    if purchased then TriggerClientEvent('electus_pets:spawnPet',src,purchased) end
    notify(src,'Pet purchased.','success')
end)
RegisterNetEvent('electus_pets:updateStatus',function(pet)
    -- Legacy requests may refresh the UI, but cannot overwrite server status.
    local saved=owned(source,type(pet)=='table' and pet.name)
    if saved then EP.syncPet(source,saved) end
end)
local function upgradeSkill(src,pet,skill)
    return EP.withPetLock(src,function()
    local saved=owned(src,type(pet)=='table' and pet.name); if not saved then return false end
    skill=skill or pet.lastUpgrade
    local upgrade=Config.SkillsUpgrade[skill=='sniff' and 'sniffing' or skill]
    saved.skills.skillPoints=math.max(0,tonumber(saved.skills.skillPoints) or 0)
    if not upgrade or saved.skills.skillPoints<upgrade.cost then return end
    local key=skill=='sniffing' and 'sniff' or skill
    saved.skills[key]=(tonumber(saved.skills[key]) or 0)+1
    saved.skills.skillPoints=saved.skills.skillPoints-upgrade.cost
    if not savePet(ident(src),saved) then return false end
    EP.syncPet(src,saved)
    return { skills=saved.skills,abilities=saved.abilities }
    end)
end
EP.registerCallback('electus_pets:upgradeSkill',upgradeSkill)
RegisterNetEvent('electus_pets:updateSkills',function(pet,skill) upgradeSkill(source,pet,skill) end)
local function unlockAbility(src,pet,ability)
    return EP.withPetLock(src,function()
    local saved=owned(src,type(pet)=='table' and pet.name)
    if not saved or not Config.AbilitiesUpgrade[ability] then return end
    local upgrade=Config.AbilitiesUpgrade[ability]
    saved.abilities=saved.abilities or {}
    if saved.abilities[ability] or (saved.skills.skillPoints or 0)<upgrade.cost then return end
    if upgrade.requireBraveryLevel and (saved.skills.bravery or 0)<upgrade.requireBraveryLevel then return end
    if upgrade.requireSniffLevel and (saved.skills.sniff or 0)<upgrade.requireSniffLevel then return end
    saved.skills.skillPoints=saved.skills.skillPoints-upgrade.cost
    saved.abilities[ability]=true
    if not savePet(ident(src),saved) then return false end
    EP.syncPet(src,saved)
    return { skills=saved.skills,abilities=saved.abilities }
    end)
end
EP.registerCallback('electus_pets:unlockAbility',unlockAbility)
RegisterNetEvent('electus_pets:unlockAbility',function(pet,ability) unlockAbility(source,pet,ability) end)
RegisterNetEvent('electus_pets:petDeath',function(pet)
    local owner=ident(source)
    for _,entry in pairs(EP.activePets) do
        if entry.owner==owner and type(pet)=='table' and entry.pet.name==pet.name
            and DoesEntityExist(entry.entity) and GetEntityHealth(entry.entity)<=0 then EP.updatePetStatus(entry,true); break end
    end
end)
RegisterNetEvent('electus_pets:transferPet', function(request, target)
    local src = source
    local result = EP.withPetLock(src, function(owner)
        local targetId = tonumber(target)
        if not targetId or targetId == src or not GetPlayerName(targetId) then return false end
        local dest = ident(targetId)
        if not dest or dest == owner or GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId) then return false end
        return EP.withOwnerLock(dest, function()
            local saved = owned(src, type(request) == 'table' and request.name or request)
            if not saved or saved.stored or saved.dead then return false end
            local active = EP.activePetForStatus(owner, saved.name)
            if not active or not EP.near(targetId, GetEntityCoords(GetPlayerPed(src)), 3.0) then return false end
            local count = 0
            for _, entry in pairs(EP.activePets) do if entry.owner == dest then count = count + 1 end end
            if count >= Config.MaxAmountPetOutside then return false end
            if MySQL.scalar.await('SELECT 1 FROM electus_pets WHERE owner=? AND name=?', { dest, saved.name }) then return false end
            EP.capturePetStatus(active, saved)
            if saved.dead or ident(src) ~= owner or ident(targetId) ~= dest then return false end
            saved.owner, saved.houseId, saved.bagPassword = dest, nil, nil
            local transferred = MySQL.transaction.await({
                { query = 'DELETE FROM electus_pets WHERE owner=? AND name=?', values = { owner, saved.name } },
                { query = 'INSERT INTO electus_pets(owner,name,data) VALUES(?,?,?)', values = { dest, saved.name, json.encode(saved) } }
            })
            if not transferred then return false end
            EP.removeActivePet(active.netId, true)
            TriggerClientEvent('electus_pets:removeTransferedPet', src, saved)
            if ident(targetId) == dest then
                TriggerClientEvent('electus_pets:spawnPet', targetId, saved)
                notify(targetId, ('You received %s.'):format(saved.name), 'success')
            end
            return true
        end)
    end)
    notify(src, result and 'Pet transferred.' or 'Pet transfer failed. Check distance, ownership and the recipient pet limit.', result and 'success' or 'error')
end)
RegisterNetEvent('electus_pets:addStatus',function(pet,food,water)
    if type(pet)~='table' then return end
    if (tonumber(food) or 0)>0 and (tonumber(water) or 0)<=0 then EP.careForPet(source,pet.name,'feed')
    elseif (tonumber(water) or 0)>0 and (tonumber(food) or 0)<=0 then EP.careForPet(source,pet.name,'water') end
end)
local function learnSniffItem(src, name, item)
    return EP.withPetLock(src, function(owner)
        local saved = owned(src, name)
        local entry = saved and EP.activePetForStatus(owner, saved.name)
        if not Config.EnableLearnToSniff or not entry or saved.dead or saved.stored
            or not (Config.Pets[saved.model] or {}).sniff or type(item) ~= 'string'
            or not lib.table.contains(Config.AllowedSniffedItems, item) or EP.itemCount(src, item) < 1
            or not EP.near(src, GetEntityCoords(entry.entity), 4.0)
            or GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entry.entity) then return false end
        local restriction = Config.JobRestrictions.sniff
        if restriction and restriction ~= 'none' and restriction ~= EP.job(src)
            and not (type(restriction) == 'table' and lib.table.contains(restriction, EP.job(src))) then return false end
        local now = os.time()
        local delay = math.max(0, (Config.Delays.newItemToSniffDelay or 100000) / 1000)
        local last = tonumber(saved.sniffLearnAt)
        if last and last <= now and now - last < delay then return false end
        saved.sniffedItems = saved.sniffedItems or {}
        if lib.table.contains(saved.sniffedItems, item) then return false end
        saved.sniffedItems[#saved.sniffedItems+1], saved.sniffLearnAt = item, now
        if not savePet(owner, saved) then return false end
        EP.syncPet(src, saved)
        return { sniffedItems = saved.sniffedItems }
    end)
end
EP.registerCallback('electus_pets:learnSniffItem', learnSniffItem)
RegisterNetEvent('electus_pets:learnNewSniffItem', function(pet)
    if type(pet) == 'table' then learnSniffItem(source, pet.name, pet.newSniffItem) end
end)
RegisterNetEvent('electus_pets:payVetBill',function(pet,payment)
    local src=source
    EP.withPetLock(src,function(owner)
        local saved=owned(src,type(pet)=='table' and pet.name)
        local account=payment=='cash' and 'cash' or payment=='bank' and 'bank'
        if not saved or not saved.dead or not account or not EP.removeMoney(src,account,Config.VetPrice) then return end
        saved.dead,saved.stored,saved.recoverAt=false,false,nil
        saved.status.health=PetMaxHealth(saved)
        local ok,persisted=pcall(savePet,owner,saved)
        if not ok or not persisted then EP.addMoney(src,account,Config.VetPrice); return end
        TriggerClientEvent('electus_pets:spawnPet',src,saved)
    end)
end)
RegisterNetEvent('electus_pets:purchaseAccessories',function(basket,payment)
    local src=source; if type(basket)~='table' or #basket>50 then return end
    local account=payment=='cash' and 'cash' or payment=='bank' and 'bank'; if not account then return end
    local total=0
    for _,it in ipairs(basket) do
        if type(it)~='table' or type(it.name)~='string' then return end
        local found=false
        for _,category in pairs(Config.AccessoryShop.shopItems) do for _,entry in ipairs(category) do if entry.name==it.name then total=total+entry.price; found=true end end end
        if not found then return end
    end
    if EP.removeMoney(src,account,total) then
        for _,it in ipairs(basket) do
            if not EP.addItem(src,it.name,1) then
                for _,category in pairs(Config.AccessoryShop.shopItems) do
                    for _,entry in ipairs(category) do if entry.name==it.name then EP.addMoney(src,account,entry.price) end end
                end
            end
        end
    end
end)

