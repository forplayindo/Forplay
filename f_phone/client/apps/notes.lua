---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/notes: note CRUD and nearby sharing.
proxy('f_phone:notes:list',   'f_phone:server:notes:list')
proxy('f_phone:notes:save',   'f_phone:server:notes:save')
proxy('f_phone:notes:delete', 'f_phone:server:notes:delete')
proxy('f_phone:notes:share',  'f_phone:server:notes:share')

---Server push: a note shared to us was accepted server-side; relays it to the open app.
---@param note table note record from server/notes/actions.lua
RegisterNetEvent('f_phone:client:notes:added', function(note)
    SendNUIMessage({ action = 'f_phone:notes:added', data = note })
end)
