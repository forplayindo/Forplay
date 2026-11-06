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

local areas, attacks = {}, {}
local function sync()
    local list = {}
    for netId, area in pairs(areas) do
        local entry = EP.activePets[netId]
        if entry and DoesEntityExist(entry.entity) then
            local friends = EP.getFriends(entry.owner)
            local players, jobs = {}, {}
            for _, player in ipairs(friends.players) do players[player.identifier] = true end
            for _, job in ipairs(friends.jobs) do jobs[job] = true end
            players[entry.owner] = true
            list[#list + 1] = { index = netId, netId = netId, pet = { netId = netId },
                coords = area.coords, radius = area.radius, owner = entry.owner,
                friends = { players = players, jobs = jobs } }
        else areas[netId] = nil; attacks[netId] = nil end
    end
    TriggerClientEvent('electus_pets:updateGuardList', -1, list)
end
RegisterNetEvent('electus_pets:guardArea', function(request, coords, radius)
    local src = source
    if type(request) ~= 'table' or type(radius) ~= 'number' or radius ~= radius or radius < 2 or radius > 7.5 then return end
    local pet = EP.owned(src, request.name)
    local entry = EP.activePets[tonumber(request.netId)]
    if not pet or not entry or entry.owner ~= EP.identifier(src) or entry.pet.name ~= pet.name
        or not pet.abilities.guardArea or not EP.near(src, coords, Config.MaxCommandRange) then return end
    areas[entry.netId] = { coords = vector3(coords.x, coords.y, coords.z), radius = radius }
    sync()
end)
RegisterNetEvent('electus_pets:attackPlayer', function(netId)
    local src = source
    netId = tonumber(netId)
    local area, entry = areas[netId], EP.activePets[netId]
    if not Config.AllowPlayerAttack or not area or not entry or attacks[netId] then return end
    if GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(entry.source) or not EP.near(src, area.coords, area.radius) then return end
    local identifier, job = EP.identifier(src), EP.job(src)
    if not identifier or identifier == entry.owner then return end
    local friends = EP.getFriends(entry.owner)
    if lib.table.contains(friends.jobs, job) then return end
    for _, player in ipairs(friends.players) do if player.identifier == identifier then return end end
    local restriction = Config.JobRestrictions.attack
    if restriction ~= 'none' and restriction ~= EP.job(entry.source)
        and not (type(restriction) == 'table' and lib.table.contains(restriction, EP.job(entry.source))) then return end
    attacks[netId] = src
    TriggerClientEvent('electus_pets:clientOwnerAttackPlayer', entry.source, src,
        { netId = netId, radius = area.radius }, netId)
end)
RegisterNetEvent('electus_pets:removeActiveAttack', function(netId)
    netId = tonumber(netId)
    local entry = EP.activePets[netId]
    if entry and (entry.owner == EP.identifier(source) or attacks[netId] == source) then attacks[netId] = nil end
end)
AddEventHandler('playerDropped', function()
    for netId, target in pairs(attacks) do if target == source then attacks[netId] = nil end end
end)
CreateThread(function()
    while true do Wait(10000); sync() end
end)
