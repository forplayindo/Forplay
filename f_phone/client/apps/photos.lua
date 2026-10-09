---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/photos: photo listing, deletion, favourites, URL saves and album
-- CRUD.
proxyCallback('f_phone:photos:list',        'f_phone:server:photos:list')
proxyCallback('f_phone:photos:delete',      'f_phone:server:photos:delete')
proxyCallback('f_phone:photos:setFavorite', 'f_phone:server:photos:setFavorite')
proxyCallback('f_phone:photos:saveUrl',     'f_phone:server:photos:saveUrl')
proxyCallback('f_phone:photos:share',       'f_phone:server:photos:share')

proxyCallback('f_phone:albums:list',        'f_phone:server:albums:list')
proxyCallback('f_phone:albums:create',      'f_phone:server:albums:create')
proxyCallback('f_phone:albums:delete',      'f_phone:server:albums:delete')
proxyCallback('f_phone:albums:addPhotos',   'f_phone:server:albums:addPhotos')
proxyCallback('f_phone:albums:removePhoto', 'f_phone:server:albums:removePhoto')
proxyCallback('f_phone:albums:photos',      'f_phone:server:albums:photos')

---Server push: a photo finished saving (camera shutter or clip upload); relays it to the
---gallery and any app listening for a fresh capture.
---@param photo table photo record from server/photos/init.lua
RegisterNetEvent('f_phone:client:photos:added', function(photo)
    SendNUIMessage({ action = 'f_phone:photos:added', data = photo })
end)

---Server push: a capture upload will not arrive. Carries a stable reason code the Camera turns
---into a translated line, so the shutter overlay can say why instead of timing out in silence.
---@param payload { code: string } reason token from server/photos/init.lua
RegisterNetEvent('f_phone:client:photos:uploadFailed', function(payload)
    SendNUIMessage({ action = 'f_phone:photos:uploadFailed', data = payload })
end)
