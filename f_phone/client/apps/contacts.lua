---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/contacts: contact CRUD, favourites, sharing, the call log and
-- number blocking.
proxyCallback('f_phone:contacts:list',         'f_phone:server:contacts:list')
proxyCallback('f_phone:contacts:add',          'f_phone:server:contacts:add')
proxyCallback('f_phone:contacts:update',       'f_phone:server:contacts:update')
proxyCallback('f_phone:contacts:delete',       'f_phone:server:contacts:delete')
proxyCallback('f_phone:contacts:favorite',     'f_phone:server:contacts:favorite')
proxyCallback('f_phone:contacts:share',        'f_phone:server:contacts:share')
proxyCallback('f_phone:contacts:logCall',      'f_phone:server:contacts:logCall')
proxyCallback('f_phone:contacts:deleteRecent', 'f_phone:server:contacts:deleteRecent')
proxyCallback('f_phone:contacts:clearRecents', 'f_phone:server:contacts:clearRecents')
proxyCallback('f_phone:contacts:block',        'f_phone:server:contacts:block')
proxyCallback('f_phone:contacts:unblock',      'f_phone:server:contacts:unblock')
proxyCallback('f_phone:contacts:blockedList',  'f_phone:server:contacts:blockedList')
proxyCallback('f_phone:contacts:isBlocked',    'f_phone:server:contacts:isBlocked')
proxyCallback('f_phone:contacts:saveCard',     'f_phone:server:contacts:saveCard')

---Server push: a nearby player shared a contact card with us; relays it to the list.
---@param contact table serialized contact from server/contacts/actions.lua
RegisterNetEvent('f_phone:client:contacts:shared', function(contact)
    SendNUIMessage({ action = 'f_phone:contacts:shared', data = contact })
end)

---Server push: another resource removed our contacts matching a number; relays it to the list.
---@param data { phone: string } bare-digits number whose contacts were removed
RegisterNetEvent('f_phone:client:contacts:removed', function(data)
    SendNUIMessage({ action = 'f_phone:contacts:removed', data = data })
end)
