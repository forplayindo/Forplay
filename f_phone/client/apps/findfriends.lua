---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/friends: roster CRUD, share requests and the watch toggle.
proxyCallback('f_phone:friends:list',    'f_phone:server:friends:list')
proxyCallback('f_phone:friends:add',     'f_phone:server:friends:add')
proxyCallback('f_phone:friends:remove',  'f_phone:server:friends:remove')
proxyCallback('f_phone:friends:share',   'f_phone:server:friends:share')
proxyCallback('f_phone:friends:respond', 'f_phone:server:friends:respond')
proxyCallback('f_phone:friends:status',  'f_phone:server:friends:status')
proxyCallback('f_phone:friends:watch',   'f_phone:server:friends:watch')

---Server push: a fresh friends snapshot (positions + share state), streamed while watching.
---Forwarded under the maps action name.
---@param data table { friends = snapshot } from server/friends/init.lua
RegisterNetEvent('f_phone:client:friends:update', function(data)
    SendNUIMessage({ action = 'f_phone:maps:friends:update', data = data })
end)
