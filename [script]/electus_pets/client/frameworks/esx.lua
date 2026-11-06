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

if Config.Framework ~= 'esx' then return end
local ok, core = pcall(function() return exports.es_extended:getSharedObject() end)
if ok then ESX = core end
if not ESX then
    TriggerEvent(Config.CustomStringESXEvent or 'esx:getSharedObject', function(value) ESX = value end)
end
assert(ESX, 'electus_pets: es_extended shared object is unavailable; start ESX before this resource')

local function readData()
    local data = ESX.GetPlayerData()
    return type(data) == 'table' and data or {}
end
local function isReady() return PlayerLoaded() end
PlayerData = readData()

RegisterNetEvent('esx:playerLoaded', function(data)
    -- The load event itself is authoritative; do not depend on another resource's handler order.
    LoadPetCharacter(readData, function() return true end, data)
end)
RegisterNetEvent('esx:onPlayerLogout', UnloadPetCharacter)
RegisterNetEvent('esx:setJob', SetPetPlayerJob)
RegisterNetEvent('esx:setPlayerData', function(key, value)
    if type(key) ~= 'string' then return end
    if key == 'job' then SetPetPlayerJob(value); return end
    local data = {}
    for field, current in pairs(GetFrameworkPlayerData()) do data[field] = current end
    data[key] = value
    SetPetPlayerData(data)
end)
CreateThread(function()
    Wait(1000)
    if isReady() then LoadPetCharacter(readData, isReady) end
end)

function MenuClose()
    if ESX.UI and ESX.UI.Menu and ESX.UI.Menu.CloseAll then ESX.UI.Menu.CloseAll() end
    lib.hideContext()
end
function GetJobName() return (GetFrameworkPlayerData().job or {}).name end
function GetIdentifier() return GetFrameworkPlayerData().identifier end
function GetInventory() return GetFrameworkPlayerData().inventory or {} end
