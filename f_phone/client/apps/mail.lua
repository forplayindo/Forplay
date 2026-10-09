---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/mail: account session, mailbox listing, composing, drafts,
-- flags and folder moves.
proxyCallback('f_phone:mail:list',       'f_phone:server:mail:list')
proxyCallback('f_phone:mail:signUp',     'f_phone:server:mail:signUp')
proxyCallback('f_phone:mail:signIn',     'f_phone:server:mail:signIn')
proxyCallback('f_phone:mail:signOut',    'f_phone:server:mail:signOut')
proxyCallback('f_phone:mail:send',       'f_phone:server:mail:send')
proxyCallback('f_phone:mail:saveDraft',  'f_phone:server:mail:saveDraft')
proxyCallback('f_phone:mail:markRead',   'f_phone:server:mail:markRead')
proxyCallback('f_phone:mail:markManyRead', 'f_phone:server:mail:markManyRead')
proxyCallback('f_phone:mail:toggleFlag', 'f_phone:server:mail:toggleFlag')
proxyCallback('f_phone:mail:moveToBin',  'f_phone:server:mail:moveToBin')
proxyCallback('f_phone:mail:deleteMany', 'f_phone:server:mail:deleteMany')
proxyCallback('f_phone:mail:discardDraft', 'f_phone:server:mail:discardDraft')
proxyCallback('f_phone:mail:saveAttachment', 'f_phone:server:mail:saveAttachment')
proxyCallback('f_phone:mail:attachmentSaveStates', 'f_phone:server:mail:attachmentSaveStates')
proxyCallback('f_phone:mail:move',       'f_phone:server:mail:move')
proxyCallback('f_phone:mail:deleteAccount', 'f_phone:server:mail:deleteAccount')
proxyCallback('f_phone:mail:savedEmails', 'f_phone:server:mail:savedEmails')
proxyCallback('f_phone:mail:saveEmail',   'f_phone:server:mail:saveEmail')
proxyCallback('f_phone:mail:declineEmail', 'f_phone:server:mail:declineEmail')
proxyCallback('f_phone:mail:removeSavedEmail', 'f_phone:server:mail:removeSavedEmail')

---Server push: a mail landed in our signed-in inbox; relays it to the app.
---@param message table mail record from server/mail
RegisterNetEvent('f_phone:client:mail:received', function(message)
    SendNUIMessage({ action = 'f_phone:mail:received', data = message })
end)
