---@type fun(nuiAction: string, serverEvent: string) NUI->server proxy factory (client.nui).
local proxy = require 'client.nui'

-- Settings -> SIM & Backup (unique-phones mode): panel snapshot, SIM eject, cloud backup.
proxy('f_phone:sim:get',            'f_phone:server:sim:get')
proxy('f_phone:sim:eject',          'f_phone:server:sim:eject')
proxy('f_phone:sim:backup:set',     'f_phone:server:sim:backup:set')
proxy('f_phone:sim:backup:sync',    'f_phone:server:sim:backup:sync')
proxy('f_phone:sim:backup:setAuto', 'f_phone:server:sim:backup:setAuto')
proxy('f_phone:sim:backup:delete',  'f_phone:server:sim:backup:delete')
proxy('f_phone:sim:backup:restore', 'f_phone:server:sim:backup:restore')

---Opens the SIM tray of the phone in `slot`. Exported for the phone item's ox_inventory `buttons`
---entry (see the README); the server re-derives the tray from the slot and force-opens it.
---@param slot number inventory slot holding the phone
exports('openSimTray', function(slot)
    TriggerServerEvent('f_phone:server:sim:openTray', slot)
end)
