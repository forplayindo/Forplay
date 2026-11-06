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

-- Only trusted server code awards XP. Client skill tables are never persisted.
function EP.awardXP(src, name, amount)
    if type(amount) ~= 'number' or amount ~= amount or amount <= 0 or amount == math.huge then return false end
    local pet, owner = EP.owned(src, name)
    if not pet then return false end
    local skills = pet.skills
    skills.xp, skills.level = (skills.xp or 0) + amount, skills.level or 1
    local threshold = math.max(1, math.floor(100 * Config.XpLevelMultiplier ^ (skills.level - 1)))
    while skills.xp >= threshold do
        skills.xp = skills.xp - threshold
        skills.level = skills.level + 1
        skills.skillPoints = (skills.skillPoints or 0) + 1
        threshold = math.max(1, math.floor(100 * Config.XpLevelMultiplier ^ (skills.level - 1)))
    end
    if not EP.savePet(owner, pet) then return false end
    EP.syncPet(src, pet)
    return true
end
exports('AddPetXP', function(src, name, amount)
    return EP.withPetLock(src, function() return EP.awardXP(src, name, amount) end)
end)

-- Return fetch balls only when a server integration records a consumed ball.
-- Legacy hook for trusted server integrations; the built-in fetch uses sessions.
local pendingBalls = {}
exports('RegisterFetchedBall', function(src, item)
    if pendingBalls[src] or type(item) ~= 'string' or not EP.identifier(src) or not EP.removeItem(src, item, 1) then return false end
    pendingBalls[src] = item
    return true
end)
RegisterNetEvent('electus_pets:giveBall', function()
    local src, item = source, pendingBalls[source]
    if not item or not Config.AddBallAfterFetch then return end
    if EP.addItem(src, item, 1) then pendingBalls[src] = nil end
end)
AddEventHandler('playerDropped', function() pendingBalls[source] = nil end)
