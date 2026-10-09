AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then client.onLogout() end
end)

RegisterNetEvent('qbx_core:client:onGroupUpdate', function(groupName, groupGrade)
    local groups = PlayerData.groups
    if not groupGrade then
        groups[groupName] = nil
    else
        groups[groupName] = groupGrade
    end
    client.setPlayerData('groups', groups)
end)

RegisterNetEvent('qbx_core:client:setGroups', function(groups)
    client.setPlayerData('groups', groups)
end)

-- Item status (hunger/thirst/stress) is applied server-side by f_consumables after the server
-- confirms the item was used; qbx_core rejects hunger/thirst written from the client.
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus() end
