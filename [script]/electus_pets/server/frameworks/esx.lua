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
local ok, ESX = pcall(function() return exports.es_extended:getSharedObject() end)
if not ok or not ESX then
    ESX = nil
    TriggerEvent(Config.CustomStringESXEvent or 'esx:getSharedObject', function(core) ESX = core end)
end
assert(ESX, 'electus_pets: es_extended shared object is unavailable; start ESX before this resource')
EP = EP or {}
EP.ESX = ESX
EP.player = ESX.GetPlayerFromId
function EP.jobs() return ESX.GetJobs() or {} end
function EP.identifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and (xPlayer.identifier or (xPlayer.getIdentifier and xPlayer.getIdentifier()))
end
function EP.job(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local job = xPlayer and (xPlayer.job or (xPlayer.getJob and xPlayer.getJob()))
    return job and job.name
end
function EP.money(src, account)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    if account == 'cash' then return xPlayer.getMoney() or 0 end
    local a = xPlayer.getAccount(account or 'bank')
    return a and a.money or 0
end
function EP.removeMoney(src, account, amount)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') or EP.money(src, account) < amount then return false end
    if account == 'cash' then return xPlayer.removeMoney(amount, 'electus-pets') ~= false end
    return xPlayer.removeAccountMoney(account or 'bank', amount, 'electus-pets') ~= false
end
function EP.addMoney(src, account, amount)
    local player = EP.player(src)
    if not player or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') then return false end
    if account == 'cash' then return player.addMoney(amount, 'electus-pets') ~= false end
    return player.addAccountMoney(account or 'bank', amount, 'electus-pets') ~= false
end
