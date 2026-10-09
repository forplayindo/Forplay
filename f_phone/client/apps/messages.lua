---@type fun(nuiAction: string, serverEvent: string, onAccepted?: fun(), transform?: fun(res: table)) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'
---@type fun(res: table) Completes an HTTP upload slot with this client's server address (client.uploadurl).
local uploadUrl = require 'client.uploadurl'

-- Thin delegates into server/messages: thread listing, sending, group management, read
-- receipts, deletes and reactions.
proxyCallback('f_phone:messages:list',        'f_phone:server:messages:list')
proxyCallback('f_phone:messages:thread',      'f_phone:server:messages:thread')
proxyCallback('f_phone:messages:send',        'f_phone:server:messages:send')
proxyCallback('f_phone:messages:uploadVoice', 'f_phone:server:messages:uploadVoice')
proxyCallback('f_phone:messages:voiceSlot', 'f_phone:server:messages:voiceSlot')
proxyCallback('f_phone:messages:voiceDone', 'f_phone:server:messages:voiceDone')
proxyCallback('f_phone:messages:httpSlot', 'f_phone:server:messages:httpSlot', nil, uploadUrl)
proxyCallback('f_phone:messages:createGroup', 'f_phone:server:messages:createGroup')
proxyCallback('f_phone:messages:addGroupMember', 'f_phone:server:messages:addGroupMember')
proxyCallback('f_phone:messages:updateGroup', 'f_phone:server:messages:updateGroup')
proxyCallback('f_phone:messages:removeGroupMember', 'f_phone:server:messages:removeGroupMember')
proxyCallback('f_phone:messages:markRead',    'f_phone:server:messages:markRead')
proxyCallback('f_phone:messages:typing',      'f_phone:server:messages:typing')
proxyCallback('f_phone:messages:delete',      'f_phone:server:messages:delete')
proxyCallback('f_phone:messages:react',       'f_phone:server:messages:react')

---Server push: relays an updated conversation slice.
---@param conversation table conversation slice from server/messages
RegisterNetEvent('f_phone:client:messages:incoming', function(conversation)
    SendNUIMessage({ action = 'f_phone:messages:incoming', data = conversation })
end)

---Server push: relays an updated reaction set for our copy of a message.
---@param payload table reaction patch from server/messages
RegisterNetEvent('f_phone:client:messages:reaction', function(payload)
    SendNUIMessage({ action = 'f_phone:messages:reaction', data = payload })
end)

---Server push: relays a group-removal notice.
---@param payload table removal notice from server/messages
RegisterNetEvent('f_phone:client:messages:removed', function(payload)
    SendNUIMessage({ action = 'f_phone:messages:removed', data = payload })
end)

---Server push: relays a request-card meta patch.
---@param payload table meta patch from server/messages
RegisterNetEvent('f_phone:client:messages:meta', function(payload)
    SendNUIMessage({ action = 'f_phone:messages:meta', data = payload })
end)

---Server push: relays a peer's live typing indicator for one thread.
---@param payload table typing notice from server/messages
RegisterNetEvent('f_phone:client:messages:typing', function(payload)
    SendNUIMessage({ action = 'f_phone:messages:typing', data = payload })
end)

---Server push: relays the moment a peer read our side of a 1:1 thread.
---@param payload table read receipt from server/messages
RegisterNetEvent('f_phone:client:messages:seen', function(payload)
    SendNUIMessage({ action = 'f_phone:messages:seen', data = payload })
end)
