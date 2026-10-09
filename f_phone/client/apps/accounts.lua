---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/accounts: the shared app-accounts engine (registration, login,
-- password resets, the saved-passwords vault) every account-based app authenticates through.
proxyCallback('f_phone:accounts:register',     'f_phone:server:accounts:register')
proxyCallback('f_phone:accounts:login',        'f_phone:server:accounts:login')
proxyCallback('f_phone:accounts:logout',       'f_phone:server:accounts:logout')
proxyCallback('f_phone:accounts:signOutAll',   'f_phone:server:accounts:signOutAll')
proxyCallback('f_phone:accounts:capacity',     'f_phone:server:accounts:capacity')
proxyCallback('f_phone:accounts:me',           'f_phone:server:accounts:me')
proxyCallback('f_phone:accounts:signInOptions', 'f_phone:server:accounts:signInOptions')
proxyCallback('f_phone:accounts:switchable',   'f_phone:server:accounts:switchable')
proxyCallback('f_phone:accounts:switch',       'f_phone:server:accounts:switch')
proxyCallback('f_phone:accounts:requestReset', 'f_phone:server:accounts:requestReset')
proxyCallback('f_phone:accounts:confirmReset', 'f_phone:server:accounts:confirmReset')
proxyCallback('f_phone:accounts:changePassword', 'f_phone:server:accounts:changePassword')
proxyCallback('f_phone:accounts:suggestCode',  'f_phone:server:accounts:suggestCode')
proxyCallback('f_phone:accounts:myNumber',     'f_phone:server:accounts:myNumber')
proxyCallback('f_phone:accounts:myEmail',      'f_phone:server:accounts:myEmail')
proxyCallback('f_phone:accounts:savePassword',   'f_phone:server:accounts:savePassword')
proxyCallback('f_phone:accounts:saveCustomPassword', 'f_phone:server:accounts:saveCustomPassword')
proxyCallback('f_phone:accounts:listPasswords',  'f_phone:server:accounts:listPasswords')
proxyCallback('f_phone:accounts:deletePassword', 'f_phone:server:accounts:deletePassword')
