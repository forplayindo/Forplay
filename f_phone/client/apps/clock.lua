---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/clock: alarm CRUD and the recent-timers list.
proxy('f_phone:clock:alarms:list',   'f_phone:server:clock:alarms:list')
proxy('f_phone:clock:alarms:save',   'f_phone:server:clock:alarms:save')
proxy('f_phone:clock:alarms:delete', 'f_phone:server:clock:alarms:delete')
proxy('f_phone:clock:recents:list',  'f_phone:server:clock:recents:list')
proxy('f_phone:clock:recents:add',   'f_phone:server:clock:recents:add')
