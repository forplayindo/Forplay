---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/apps: the installable-app catalogue, install/uninstall state and
-- the home-screen layout.
proxyCallback('f_phone:apps:list',       'f_phone:server:apps:list')
proxyCallback('f_phone:apps:install',    'f_phone:server:apps:install')
proxyCallback('f_phone:apps:uninstall',  'f_phone:server:apps:uninstall')
proxyCallback('f_phone:apps:saveLayout', 'f_phone:server:apps:saveLayout')
