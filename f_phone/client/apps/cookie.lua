---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/cookie: cookie-clicker save/load, the leaderboard and the
-- leaderboard nickname.
proxy('f_phone:cookie:load',        'f_phone:server:cookie:load')
proxy('f_phone:cookie:save',        'f_phone:server:cookie:save')
proxy('f_phone:cookie:leaderboard', 'f_phone:server:cookie:leaderboard')
proxy('f_phone:cookie:nickname',    'f_phone:server:cookie:nickname')
