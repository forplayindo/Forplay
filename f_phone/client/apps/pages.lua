---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/pages: listing CRUD.
proxy('f_phone:pages:list',   'f_phone:server:pages:list')
proxy('f_phone:pages:create', 'f_phone:server:pages:create')
proxy('f_phone:pages:update', 'f_phone:server:pages:update')
proxy('f_phone:pages:delete', 'f_phone:server:pages:delete')
proxy('f_phone:pages:reschedule', 'f_phone:server:pages:reschedule')
proxy('f_phone:pages:publishNow', 'f_phone:server:pages:publishNow')
proxy('f_phone:pages:watch',  'f_phone:server:pages:watch')

---Server push (fan-out to the other phones with Pages open): another player posted / edited /
---removed a listing. Forwarded straight to the NUI.
---@param payload table feed patch from server/pages
RegisterNetEvent('f_phone:client:pages:feed', function(payload)
    SendNUIMessage({ action = 'f_phone:pages:feed', data = payload })
end)
