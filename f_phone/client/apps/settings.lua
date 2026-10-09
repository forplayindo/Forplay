---@type fun(nuiAction: string, serverEvent: string, onAccepted?: fun()) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

---Announces an accepted settings write, so listeners can re-read the snapshot.
local function announce()
    TriggerEvent('f_phone:client:settingsUpdated')
end

---Registers a settings write: the read pass-through plus the announcement.
---@param nuiAction string
---@param serverEvent string
local function writeCallback(nuiAction, serverEvent)
    proxyCallback(nuiAction, serverEvent, announce)
end

-- Thin delegates into server/settings: per-player setting reads/writes persisted to the
-- phone_settings table. Writes go through writeCallback so they announce afterwards.
proxyCallback('f_phone:settings:get',      'f_phone:server:settings:get')
writeCallback('f_phone:settings:setTones', 'f_phone:server:settings:setTones')
writeCallback('f_phone:settings:tones:add',    'f_phone:server:settings:tones:add')
writeCallback('f_phone:settings:tones:remove', 'f_phone:server:settings:tones:remove')
writeCallback('f_phone:settings:setAirplane',  'f_phone:server:settings:setAirplane')
writeCallback('f_phone:settings:setFocus',        'f_phone:server:settings:setFocus')
writeCallback('f_phone:settings:setRotationLock', 'f_phone:server:settings:setRotationLock')
writeCallback('f_phone:settings:setHour24',    'f_phone:server:settings:setHour24')
writeCallback('f_phone:settings:setCallerId',  'f_phone:server:settings:setCallerId')
writeCallback('f_phone:settings:setStreamerMode', 'f_phone:server:settings:setStreamerMode')
writeCallback('f_phone:settings:setStreamerHide', 'f_phone:server:settings:setStreamerHide')
proxyCallback('f_phone:settings:resetCooldown', 'f_phone:server:settings:resetCooldown')
writeCallback('f_phone:settings:setReopenApp', 'f_phone:server:settings:setReopenApp')
writeCallback('f_phone:settings:setSetupDone', 'f_phone:server:settings:setSetupDone')
writeCallback('f_phone:settings:setTheme',     'f_phone:server:settings:setTheme')
writeCallback('f_phone:settings:setDarkTheme', 'f_phone:server:settings:setDarkTheme')
writeCallback('f_phone:settings:setLightTheme', 'f_phone:server:settings:setLightTheme')
writeCallback('f_phone:settings:setAccent', 'f_phone:server:settings:setAccent')
writeCallback('f_phone:settings:setShell', 'f_phone:server:settings:setShell')
writeCallback('f_phone:settings:setGameTime', 'f_phone:server:settings:setGameTime')
writeCallback('f_phone:settings:setIconTheme',    'f_phone:server:settings:setIconTheme')
writeCallback('f_phone:settings:saveCustomIconTheme',   'f_phone:server:settings:saveCustomIconTheme')
writeCallback('f_phone:settings:deleteCustomIconTheme', 'f_phone:server:settings:deleteCustomIconTheme')
writeCallback('f_phone:settings:savePalette',   'f_phone:server:settings:savePalette')
writeCallback('f_phone:settings:deletePalette', 'f_phone:server:settings:deletePalette')
writeCallback('f_phone:settings:setShowAppNames', 'f_phone:server:settings:setShowAppNames')
writeCallback('f_phone:settings:setLockClock', 'f_phone:server:settings:setLockClock')
writeCallback('f_phone:settings:setSecurity',  'f_phone:server:settings:setSecurity')
writeCallback('f_phone:settings:setWallpaper', 'f_phone:server:settings:setWallpaper')
writeCallback('f_phone:settings:setBlur',      'f_phone:server:settings:setBlur')
writeCallback('f_phone:settings:setIslandPet', 'f_phone:server:settings:setIslandPet')
writeCallback('f_phone:settings:wallpapers:add',    'f_phone:server:settings:wallpapers:add')
writeCallback('f_phone:settings:wallpapers:remove', 'f_phone:server:settings:wallpapers:remove')
writeCallback('f_phone:settings:setChatTextScale', 'f_phone:server:settings:setChatTextScale')
writeCallback('f_phone:settings:setAccessibility', 'f_phone:server:settings:setAccessibility')
writeCallback('f_phone:settings:setAppLabels',     'f_phone:server:settings:setAppLabels')
writeCallback('f_phone:settings:setHomeDensity',   'f_phone:server:settings:setHomeDensity')
writeCallback('f_phone:settings:setHomeIconScale', 'f_phone:server:settings:setHomeIconScale')
writeCallback('f_phone:settings:setPhoneScale',    'f_phone:server:settings:setPhoneScale')
writeCallback('f_phone:settings:setBrightness',    'f_phone:server:settings:setBrightness')
writeCallback('f_phone:settings:setPhoneAlign',    'f_phone:server:settings:setPhoneAlign')
writeCallback('f_phone:settings:setPhoneTilt',     'f_phone:server:settings:setPhoneTilt')
writeCallback('f_phone:settings:setInterface',     'f_phone:server:settings:setInterface')
writeCallback('f_phone:settings:setVolumes',       'f_phone:server:settings:setVolumes')
writeCallback('f_phone:settings:setLocale',        'f_phone:server:settings:setLocale')
proxyCallback('f_phone:settings:versionInfo',  'f_phone:server:settings:versionInfo')
proxyCallback('f_phone:settings:getNotifPref', 'f_phone:server:settings:getNotifPref')
proxyCallback('f_phone:settings:getNotifPrefs', 'f_phone:server:settings:getNotifPrefs')
writeCallback('f_phone:settings:setNotifPref', 'f_phone:server:settings:setNotifPref')
writeCallback('f_phone:settings:factoryReset', 'f_phone:server:settings:factoryReset')
