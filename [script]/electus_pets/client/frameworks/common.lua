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

local generation, activeCharacter, loading = 0, nil, false
local loggedOut = false
PlayerData = {}

function GetFrameworkPlayerData()
    return PlayerData or {}
end

function UnloadPetCharacter()
    generation, activeCharacter, loading = generation + 1, nil, false
    loggedOut = true
    CancelPetLoading()
    if CancelPetAccessoryFitting then CancelPetAccessoryFitting() end
    -- The server owns pet deletion and captures health before removing the ped.
    for i = #CurrentPets, 1, -1 do
        local pet = CurrentPets[i]
        if pet.action == 'riding' then StopRiding(pet) end
        RemoveLocalPet(pet.netId)
    end
    if ClearPetHouses then ClearPetHouses() end
    if ClearPetMarkers then ClearPetMarkers() end
    if ClosePetShopScene and CurrentShop then ClosePetShopScene() end
    CurrentShop, PetIndexInSkillMenu, IsInPetMenu, CarriesPet, DoesInteract = nil, nil, false, false, false
    ToggleNuiFrame(false)
    SetNuiFocusKeepInput(false)
    PlayerData = {}
    PetMenuSelection = nil
end

function LoadPetCharacter(readData, isReady, initialData)
    local expected = type(initialData) == 'table' and (initialData.citizenid or initialData.identifier)
    if loading then return false end
    if expected and activeCharacter and expected ~= activeCharacter then UnloadPetCharacter() end
    loggedOut, loading = false, true
    local token, deadline = generation, GetGameTimer() + 15000
    local data = type(initialData) == 'table' and initialData or readData()
    while not isReady() or not (data.citizenid or data.identifier) do
        if token ~= generation or GetGameTimer() >= deadline then
            if token == generation then loading = false end
            return false
        end
        Wait(100)
        if token ~= generation then return false end
        data = readData()
    end
    if token ~= generation then return false end
    local identifier = data.citizenid or data.identifier
    if activeCharacter == identifier then loading = false; return true end
    if activeCharacter then
        UnloadPetCharacter()
        token, loggedOut, loading = generation, false, true
    end
    PlayerData = data
    local ok, result = pcall(function()
        local loaded = LoadPets()
        if token ~= generation then return false end
        LoadPetHouses()
        LoadMarkers()
        TriggerServerEvent('electus_pets:sendFriendListToClient')
        TriggerServerEvent('electus_pets:requestPetSync')
        return loaded ~= false
    end)
    if token ~= generation then return false end
    loading = false
    if not ok then print(('electus_pets: character setup failed: %s'):format(result)); return false end
    if result then activeCharacter = identifier end
    return result
end

function SetPetPlayerData(data)
    if type(data) ~= 'table' then return end
    local old = PlayerData and (PlayerData.citizenid or PlayerData.identifier)
    local new = data.citizenid or data.identifier
    if old and new and old ~= new then UnloadPetCharacter() end
    if loggedOut then return end
    local previousJob = PlayerData and PlayerData.job and PlayerData.job.name
    PlayerData = data
    if previousJob ~= (data.job and data.job.name) then LoadMarkers() end
end

function SetPetPlayerJob(job)
    if loggedOut then return end
    PlayerData = PlayerData or {}
    PlayerData.job = type(job) == 'table' and job or {}
    LoadMarkers()
end

if type(Config.MidGameCharacterSwap) == 'string' and Config.MidGameCharacterSwap ~= '' then
    RegisterNetEvent(Config.MidGameCharacterSwap, UnloadPetCharacter)
end

RegisterNetEvent('electus_pets:interact', function(data)
    if type(data) == 'table' then OpenPetMenu(data.pet) end
end)

function GetItemLabel(item) return lib.callback.await('electus_pets:getItemLabel', false, item) end
function GetJobsLabel(jobs) return lib.callback.await('electus_pets:getJobsName', false, jobs) or {} end
function DoesVehicleHaveSniffedItem(plate, pet)
    Wait(2500)
    return lib.callback.await('electus_pets:sniffTrunk', false, plate, pet.name) == true
end
