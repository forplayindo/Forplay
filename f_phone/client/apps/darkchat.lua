---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/darkchat: room lifecycle, membership, messaging, reactions and
-- nicknames.
proxy('f_phone:darkchat:rooms',    'f_phone:server:darkchat:rooms')
proxy('f_phone:darkchat:open',     'f_phone:server:darkchat:open')
proxy('f_phone:darkchat:close',    'f_phone:server:darkchat:close')
proxy('f_phone:darkchat:send',     'f_phone:server:darkchat:send')
proxy('f_phone:darkchat:react',    'f_phone:server:darkchat:react')
proxy('f_phone:darkchat:create',   'f_phone:server:darkchat:create')
proxy('f_phone:darkchat:join',     'f_phone:server:darkchat:join')
proxy('f_phone:darkchat:leave',    'f_phone:server:darkchat:leave')
proxy('f_phone:darkchat:nickname', 'f_phone:server:darkchat:nickname')
proxy('f_phone:darkchat:exit',     'f_phone:server:darkchat:exit')
proxy('f_phone:darkchat:roomInfo', 'f_phone:server:darkchat:roomInfo')
proxy('f_phone:darkchat:notifications', 'f_phone:server:darkchat:notifications')
proxy('f_phone:darkchat:kick',     'f_phone:server:darkchat:kick')
proxy('f_phone:darkchat:ban',      'f_phone:server:darkchat:ban')
proxy('f_phone:darkchat:unban',    'f_phone:server:darkchat:unban')
proxy('f_phone:darkchat:regenCode', 'f_phone:server:darkchat:regenCode')

---Server push: a message landed in a room we're a member of; relays it to an open room.
---@param data table message record from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:message', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:message', data = data })
end)

---Server push: a room's active-member presence changed; relays the updated presence.
---@param data table presence patch from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:active', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:active', data = data })
end)

---Server push: a reaction changed on a message in one of our rooms; relays the updated set.
---@param data table reaction patch from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:reaction', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:reaction', data = data })
end)

---Server push: the room's creator removed us; relays it so the app drops the room live.
---@param data table { roomId } from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:kicked', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:kicked', data = data })
end)

---Server push: a room we belong to got a fresh join code; relays it so the app shows the
---current one everywhere.
---@param data table { roomId, code } from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:code', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:code', data = data })
end)

---Server push: a private room's member count changed (join/leave/kick/ban); relays the
---authoritative count so the list and chat header update live.
---@param data table { roomId, members } from server/darkchat
RegisterNetEvent('f_phone:client:darkchat:members', function(data)
    SendNUIMessage({ action = 'f_phone:darkchat:members', data = data })
end)
