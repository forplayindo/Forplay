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

if Config.Framework ~= 'qb' then return end
local core = exports[Config.CustomStringQBExport or 'qb-core']:GetCoreObject()
EP = EP or {}
EP.QBCore = core
EP.player = core.Functions.GetPlayer
function EP.identifier(src)
    local player = EP.player(src)
    return player and player.PlayerData and player.PlayerData.citizenid
end
function EP.job(src)
    local player = EP.player(src)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
end
function EP.jobs() return core.Shared and core.Shared.Jobs or {} end
function EP.money(src, account)
    local player = EP.player(src)
    local amount = player and player.PlayerData and player.PlayerData.money and player.PlayerData.money[account or 'bank']
    return type(amount) == 'number' and amount or 0
end
function EP.removeMoney(src, account, amount)
    local player = EP.player(src)
    if not player or not EP.identifier(src) or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') or EP.money(src, account) < amount then return false end
    return player.Functions.RemoveMoney(account or 'bank', amount, 'electus-pets') == true
end
function EP.addMoney(src, account, amount)
    local player = EP.player(src)
    if not player or not EP.identifier(src) or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') then return false end
    return player.Functions.AddMoney(account or 'bank', amount, 'electus-pets') == true
end
