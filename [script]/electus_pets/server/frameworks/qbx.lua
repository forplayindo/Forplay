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

if Config.Framework ~= 'qbx' then return end
EP = EP or {}
function EP.player(src) return exports.qbx_core:GetPlayer(src) end
function EP.identifier(src)
    local player = EP.player(src)
    return player and player.PlayerData and player.PlayerData.citizenid
end
function EP.job(src)
    local player = EP.player(src)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
end
function EP.jobs() return exports.qbx_core:GetJobs() or {} end
function EP.money(src, account)
    if not EP.identifier(src) then return 0 end
    local amount = exports.qbx_core:GetMoney(src, account or 'bank')
    return type(amount) == 'number' and amount or 0
end
function EP.removeMoney(src, account, amount)
    if not EP.identifier(src) or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') or EP.money(src, account) < amount then return false end
    return exports.qbx_core:RemoveMoney(src, account or 'bank', amount, 'electus-pets') == true
end
function EP.addMoney(src, account, amount)
    if not EP.identifier(src) or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount == math.huge or (account ~= nil and account ~= 'cash' and account ~= 'bank') then return false end
    return exports.qbx_core:AddMoney(src, account or 'bank', amount, 'electus-pets') == true
end
