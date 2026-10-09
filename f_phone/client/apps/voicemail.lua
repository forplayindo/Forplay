---@type fun(nuiAction: string, serverEvent: string, onAccepted?: fun(), transform?: fun(res: table)) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'
---@type fun(res: table) Completes an HTTP upload slot with this client's server address (client.uploadurl).
local uploadUrl = require 'client.uploadurl'

-- Thin delegates into server/voicemail. `upload` blocks for as long as the CDN takes, which is
-- why the recorder shows its own progress state until the envelope comes back.
proxyCallback('f_phone:voicemail:list',    'f_phone:server:voicemail:list')
proxyCallback('f_phone:voicemail:seen',    'f_phone:server:voicemail:seen')
proxyCallback('f_phone:voicemail:delete',  'f_phone:server:voicemail:delete')
proxyCallback('f_phone:voicemail:leave',   'f_phone:server:voicemail:leave')
proxyCallback('f_phone:voicemail:upload',  'f_phone:server:voicemail:upload')
proxyCallback('f_phone:voicemail:enabled', 'f_phone:server:voicemail:enabled')

---Server push: someone left us a voicemail. Relays the row so the Voicemail tab can show it
---without a refetch.
---@param vm table voicemail record from server/voicemail
RegisterNetEvent('f_phone:client:voicemail:new', function(vm)
    SendNUIMessage({ action = 'f_phone:voicemail:new', data = vm })
end)

-- Direct upload. The base64 route above carries the whole recording in one ordinary callback,
-- which is an un-paced event underneath and stalls the net thread for everyone while it arrives.
-- These put it on HTTPS instead, with that route kept as the fallback.
proxyCallback('f_phone:voicemail:uploadSlot', 'f_phone:server:voicemail:uploadSlot')
proxyCallback('f_phone:voicemail:uploadDone', 'f_phone:server:voicemail:uploadDone')

-- HTTP upload: the recording goes to the server over its HTTP port instead of a game network event.
proxyCallback('f_phone:voicemail:httpSlot', 'f_phone:server:voicemail:httpSlot', nil, uploadUrl)
