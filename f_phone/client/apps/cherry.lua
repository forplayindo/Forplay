---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/cherry: profile CRUD, deck swipes, match threads, reactions and
-- blocking.
proxyCallback('f_phone:cherry:state',         'f_phone:server:cherry:state')
proxyCallback('f_phone:cherry:saveProfile',   'f_phone:server:cherry:saveProfile')
proxyCallback('f_phone:cherry:swipe',         'f_phone:server:cherry:swipe')
proxyCallback('f_phone:cherry:rewind',        'f_phone:server:cherry:rewind')
proxyCallback('f_phone:cherry:resetDeck',     'f_phone:server:cherry:resetDeck')
proxyCallback('f_phone:cherry:thread',        'f_phone:server:cherry:thread')
proxyCallback('f_phone:cherry:send',          'f_phone:server:cherry:send')
proxyCallback('f_phone:cherry:react',         'f_phone:server:cherry:react')
proxyCallback('f_phone:cherry:unmatch',       'f_phone:server:cherry:unmatch')
proxyCallback('f_phone:cherry:block',         'f_phone:server:cherry:block')
proxyCallback('f_phone:cherry:blockedList',   'f_phone:server:cherry:blockedList')
proxyCallback('f_phone:cherry:unblock',       'f_phone:server:cherry:unblock')
proxyCallback('f_phone:cherry:watch',         'f_phone:server:cherry:watch')
proxyCallback('f_phone:cherry:deleteAccount', 'f_phone:server:cherry:deleteAccount')

---Server push: relays a message that arrived in one of our match threads.
---@param payload table { matchId, message } from server/cherry/actions.lua
RegisterNetEvent('f_phone:client:cherry:message', function(payload)
    SendNUIMessage({ action = 'f_phone:cherry:message', data = payload })
end)

---Server push: relays a fresh match card.
---@param payload table serialized match record from server/cherry/actions.lua
RegisterNetEvent('f_phone:client:cherry:match', function(payload)
    SendNUIMessage({ action = 'f_phone:cherry:match', data = payload })
end)

---Server push: relays an updated thread-message reaction set.
---@param payload table reaction patch from server/cherry/actions.lua
RegisterNetEvent('f_phone:client:cherry:reaction', function(payload)
    SendNUIMessage({ action = 'f_phone:cherry:reaction', data = payload })
end)

---Server push: relays a matched partner's fresh profile card.
---@param payload table { username, partner } from server/cherry/actions.lua
RegisterNetEvent('f_phone:client:cherry:partner', function(payload)
    SendNUIMessage({ action = 'f_phone:cherry:partner', data = payload })
end)

---Server push: relays an unmatch/block notice.
---@param payload table { matchId } from server/cherry/actions.lua
RegisterNetEvent('f_phone:client:cherry:unmatch', function(payload)
    SendNUIMessage({ action = 'f_phone:cherry:unmatch', data = payload })
end)
