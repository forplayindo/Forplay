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

PetHouses = {}
local placing
local houseGeneration = 0

local function finishPlacement(session)
    if not session then return end
    if session.object and DoesEntityExist(session.object) then DeleteEntity(session.object) end
    session.object = nil
    if session.hash and not session.released then SetModelAsNoLongerNeeded(session.hash); session.released = true end
    if placing == session then placing = nil; HideHelpText() end
end

function CancelPetHousePlacement() finishPlacement(placing) end

function LoadPetHouses()
    if Config.EnablePetHouse then TriggerServerEvent('electus_pets:getPetHouses') end
end

function ClearPetHouses()
    houseGeneration = houseGeneration + 1
    CancelPetHousePlacement()
    for _, house in pairs(PetHouses) do
        PetTarget:RemoveTargetEntity(house.obj)
        if DoesEntityExist(house.obj) then DeleteEntity(house.obj) end
    end
    PetHouses = {}
end

function OpenPetHouse(id)
    SendReactMessage('updateComponent', { component = 'petHouse', houseId = id })
    ToggleNuiFrame(true)
end

local function spawnHouse(id, kind, coords)
    local generation, owner = houseGeneration, GetIdentifier()
    local definition = Config.PetHouseModels[kind]
    if not definition or not coords then return end
    local old = PetHouses[id]
    if old then
        PetTarget:RemoveTargetEntity(old.obj)
        if DoesEntityExist(old.obj) then DeleteEntity(old.obj) end
    end
    local hash = joaat(definition.propId)
    lib.requestModel(hash)
    if generation ~= houseGeneration or GetIdentifier() ~= owner then SetModelAsNoLongerNeeded(hash); return end
    local object = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(object, coords.w or 0.0)
    FreezeEntityPosition(object, true)
    PetHouses[id] = { id = id, obj = object, houseType = kind }
    if Config.TargetSystem ~= 'none' then
        PetTarget:AddTargetEntity(object, { options = {{ label = L('petHouse'), action = function() OpenPetHouse(id) end }}, distance = 2.5 })
    end
    SetModelAsNoLongerNeeded(hash)
end
RegisterNetEvent('electus_pets:spawnPetHouse', spawnHouse)

local function refreshHouse(id)
    local data = GetPetHouseData(id)
    if not data then return end
    local outside = {}
    for _, pet in ipairs(CurrentPets) do outside[#outside + 1] = { name = pet.name, model = pet.model } end
    SendReactMessage('updateHouseData', { house = data.pets, outside = outside,
        maxOutside = Config.MaxAmountPetOutside, maxHouseSlots = data.maxHouseSlots })
end

function InsertPetInHouse(id, name)
    if lib.callback.await('electus_pets:storePet', false, id, name) then
        DeletePetFromName(name)
        refreshHouse(id)
    end
end

function RemovePetFromHouse(name, id)
    if #CurrentPets >= Config.MaxAmountPetOutside then Notify(L('maxOutside')); return end
    local pet = lib.callback.await('electus_pets:withdrawPet', false, id, name)
    if pet then SpawnPet(pet); refreshHouse(id) end
end

function RemoveHouse(id)
    if not lib.callback.await('electus_pets:removeHouse', false, id) then return end
    local house = PetHouses[id]
    if house then
        PetTarget:RemoveTargetEntity(house.obj)
        DeleteEntity(house.obj)
        PetHouses[id] = nil
    end
end

RegisterNetEvent('electus_pets:placeProp', function(kind)
    local definition = Config.PetHouseModels[kind]
    local owner = GetIdentifier()
    if placing or not owner or not Config.EnablePetHouse or not definition or not HasItem(definition.itemName) then return end
    local session = { hash = joaat(definition.propId) }
    placing = session
    local function current() return placing == session and GetIdentifier() == owner end
    local ok, err = pcall(function()
        lib.requestModel(session.hash, 5000)
        if not current() then return end
        local coords = GetEntityCoords(PlayerPedId())
        local object = CreateObject(session.hash, coords.x, coords.y, coords.z, false, false, false)
        session.object = object
        if object == 0 or not DoesEntityExist(object) then error('House preview could not be created') end
        SetEntityAlpha(object, 150, false)
        SetEntityCollision(object, false, false)
        local heading = GetEntityHeading(PlayerPedId())
        local place = Config.Keys[Config.KeyActions.petHousePlace] or Config.Keys.ENTER
        local cancel = Config.Keys[Config.KeyActions.cancelKey]
        local left = Config.Keys[Config.KeyActions.petHouseRotateLeft]
        local right = Config.Keys[Config.KeyActions.petHouseRotateRight]
        HelpText(L('placeOrCancel', { place = Config.KeyActions.petHousePlace, cancel = Config.KeyActions.cancelKey,
            rotateL = Config.KeyActions.petHouseRotateLeft, rotateR = Config.KeyActions.petHouseRotateRight }))
        while current() and DoesEntityExist(object) do
            Wait(0)
            if not current() then break end
            coords = GetWorldCoordsFromScreen()
            SetEntityCoords(object, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityHeading(object, heading)
            DisableControlAction(0, place.key, true)
            if left and IsControlPressed(0, left.key) then heading = heading - 1.0 end
            if right and IsControlPressed(0, right.key) then heading = heading + 1.0 end
            if IsDisabledControlJustPressed(0, place.key) then
                local position = { x = coords.x, y = coords.y, z = coords.z, w = heading }
                local id = lib.callback.await('electus_pets:placeHouse', false, kind, position)
                if not current() then break end
                if id then spawnHouse(id, kind, position) else Notify(L('housePlaceFailed')) end
                break
            elseif IsControlJustPressed(0, cancel.key) then break end
        end
    end)
    finishPlacement(session)
    if not ok then
        print(('electus_pets: house placement failed: %s'):format(err))
        Notify(L('housePlaceFailed'))
    end
end)

CreateThread(function()
    while true do
        local delay = 1000
        if Config.TargetSystem == 'none' then
            local coords = GetEntityCoords(PlayerPedId())
            for id, house in pairs(PetHouses) do
                if #(coords - GetEntityCoords(house.obj)) < 2.5 then
                    delay = 0
                    if IsControlJustReleased(0, Config.Keys[Config.KeyActions.placePetHouse].key) then OpenPetHouse(id) end
                end
            end
        end
        Wait(delay)
    end
end)

if Config.EnablePetCommandForHouse then
    RegisterCommand(Config.Commands.petStorage, function() OpenPetHouse(-2) end, false)
end
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then ClearPetHouses() end end)
