---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/marketplace: listing CRUD.
proxy('f_phone:marketplace:list',   'f_phone:server:marketplace:list')
proxy('f_phone:marketplace:create', 'f_phone:server:marketplace:create')
proxy('f_phone:marketplace:update', 'f_phone:server:marketplace:update')
proxy('f_phone:marketplace:delete', 'f_phone:server:marketplace:delete')
proxy('f_phone:marketplace:reschedule', 'f_phone:server:marketplace:reschedule')
proxy('f_phone:marketplace:publishNow', 'f_phone:server:marketplace:publishNow')
proxy('f_phone:marketplace:watch',  'f_phone:server:marketplace:watch')

---Server push (fan-out to every other open phone): another player posted / edited / removed a
---listing. Forwarded straight to the NUI.
---@param payload table feed patch from server/marketplace
RegisterNetEvent('f_phone:client:marketplace:feed', function(payload)
    SendNUIMessage({ action = 'f_phone:marketplace:feed', data = payload })
end)
