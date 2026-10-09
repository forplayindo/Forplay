---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/documents: folder + document CRUD, moves, duplication, image
-- import and nearby sharing.
proxy('f_phone:documents:list',         'f_phone:server:documents:list')
proxy('f_phone:documents:get',          'f_phone:server:documents:get')
proxy('f_phone:documents:createFolder', 'f_phone:server:documents:createFolder')
proxy('f_phone:documents:createDoc',    'f_phone:server:documents:createDoc')
proxy('f_phone:documents:save',         'f_phone:server:documents:save')
proxy('f_phone:documents:rename',       'f_phone:server:documents:rename')
proxy('f_phone:documents:renameFolder', 'f_phone:server:documents:renameFolder')
proxy('f_phone:documents:move',         'f_phone:server:documents:move')
proxy('f_phone:documents:delete',       'f_phone:server:documents:delete')
proxy('f_phone:documents:deleteFolder', 'f_phone:server:documents:deleteFolder')
proxy('f_phone:documents:duplicate',    'f_phone:server:documents:duplicate')
proxy('f_phone:documents:importImage',  'f_phone:server:documents:importImage')
proxy('f_phone:documents:signature:get', 'f_phone:server:documents:signature:get')
proxy('f_phone:documents:signature:set', 'f_phone:server:documents:signature:set')
proxy('f_phone:documents:sign',          'f_phone:server:documents:sign')
proxy('f_phone:documents:share',        'f_phone:server:documents:share')
proxy('f_phone:documents:signRequest:send',    'f_phone:server:documents:requestSignature')
proxy('f_phone:documents:signRequest:respond', 'f_phone:server:documents:signRequest:respond')

---Server push: a document was created for us elsewhere (an export or another resource); relays
---it to the open app so the listing updates live.
---@param data table { doc } from server/documents
RegisterNetEvent('f_phone:client:documents:added', function(data)
    SendNUIMessage({ action = 'f_phone:documents:added', data = data })
end)

---Server push: an AirShared document was accepted into our library; relays the copy plus the
---sender's name.
---@param data table { doc, fromName } from server/documents
RegisterNetEvent('f_phone:client:documents:receive', function(data)
    SendNUIMessage({ action = 'f_phone:documents:receive', data = data })
end)

---Server push: an accepted signature request; relays the preview + sign prompt payload.
---@param data table { requestId, fromName, doc } from server/documents
RegisterNetEvent('f_phone:client:documents:signRequest', function(data)
    SendNUIMessage({ action = 'f_phone:documents:signRequest', data = data })
end)
