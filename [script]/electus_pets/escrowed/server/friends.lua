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

local busy = {}
local function getFriends(owner)
    local row = MySQL.single.await('SELECT friends FROM electus_pet_friends WHERE owner=?', { owner })
    local friends = EP.decode(row and row.friends, {})
    friends.jobs, friends.players = friends.jobs or {}, friends.players or {}
    return friends
end
EP.getFriends = getFriends

local function send(src)
    local owner = EP.identifier(src)
    if owner then TriggerClientEvent('electus_pets:receiveFriendList', src, getFriends(owner)) end
end
RegisterNetEvent('electus_pets:sendFriendListToClient', function() send(source) end)
RegisterNetEvent('electus_pets:requestFriendList', function() send(source) end)

local function update(src, change)
    local owner = EP.identifier(src)
    if not owner or busy[owner] then return end
    busy[owner] = true
    local ok, err = pcall(function()
        local friends = getFriends(owner)
        if not change(friends) then return end
        MySQL.update.await('INSERT INTO electus_pet_friends(owner,friends) VALUES(?,?) ON DUPLICATE KEY UPDATE friends=VALUES(friends)',
            { owner, json.encode(friends) })
        if EP.identifier(src) == owner then TriggerClientEvent('electus_pets:receiveFriendList', src, friends) end
    end)
    busy[owner] = nil
    if not ok then print(('electus_pets: friend update failed: %s'):format(err)) end
end
RegisterNetEvent('electus_pets:addJobAsFriend', function(job)
    if type(job) ~= 'string' or not lib.table.contains(Config.AllowedJobsToSetAsFriends, job) then return end
    update(source, function(friends)
        if not lib.table.contains(friends.jobs, job) then friends.jobs[#friends.jobs + 1] = job end
        return true
    end)
end)
RegisterNetEvent('electus_pets:removeJobAsFriend', function(job)
    update(source, function(friends)
        for i = #friends.jobs, 1, -1 do if friends.jobs[i] == job then table.remove(friends.jobs, i) end end
        return true
    end)
end)
RegisterNetEvent('electus_pets:addFriend', function(target)
    local src = source
    target = tonumber(target)
    local identifier = target and EP.identifier(target)
    if not identifier or target == src or not EP.near(src, GetEntityCoords(GetPlayerPed(target)), 5.0) then return end
    update(src, function(friends)
        for _, player in ipairs(friends.players) do if player.identifier == identifier then return false end end
        if #friends.players >= 100 then return false end
        friends.players[#friends.players + 1] = { identifier = identifier, name = GetPlayerName(target) }
        return true
    end)
end)
RegisterNetEvent('electus_pets:removeFriend', function(identifier)
    if type(identifier) ~= 'string' then return end
    update(source, function(friends)
        for i = #friends.players, 1, -1 do
            if friends.players[i].identifier == identifier then table.remove(friends.players, i) end
        end
        return true
    end)
end)
