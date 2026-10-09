---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'
---@type table f_phone config root (configs/config.lua): AllowMovement for keep-input restore.
local config = require 'configs.config'

---@type boolean True while the admin panel NUI is on screen.
local adminOpen = false
---@type boolean Mirror of the phone's open state (f_phone:client:openState).
local phoneOpen = false

AddEventHandler('f_phone:client:openState', function(open)
    phoneOpen = open and true or false
    -- The phone releases NUI focus when it closes; re-assert it while the panel is still up.
    if not phoneOpen and adminOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
end)

-- A wipe reloads the NUI, destroying the admin-panel React tree. Clear our open flag so the
-- openState handler above won't re-assert focus over a panel that no longer exists; main.lua
-- drops the actual focus.
AddEventHandler('f_phone:client:wipeFocus', function()
    adminOpen = false
end)

---Opens the panel. Fired by the server-side /phoneadmin command (server/admin/init.lua), which
---is the permission gate - this event never opens anything the callbacks wouldn't refuse.
---Keep-input is forced off so the game gets no movement/camera input while the panel is up
---(the phone's AllowMovement mode leaves it on).
---@param adminName string acting admin's display name for the panel header
---@param simActive boolean|nil unique-phones mode flag (shows the Numbers page)
---@param racingOn boolean|nil whether the racing app runs here (shows the Racing page)
RegisterNetEvent('f_phone:client:admin:open', function(adminName, simActive, racingOn)
    if adminOpen then return end
    adminOpen = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'f_phone:admin:open',
        data   = { adminName = adminName, sim = simActive == true, racing = racingOn == true },
    })
end)

---React to Lua: the panel requests to close (X button / Escape). With the phone still open,
---focus stays and its movement-mode keep-input is restored; otherwise focus is released.
---@param _ table|nil unused payload
---@param cb fun(result: table) NUI response
RegisterNUICallback('f_phone:admin:close', function(_, cb)
    adminOpen = false
    if phoneOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(config.Phone.AllowMovement == true)
    else
        SetNuiFocus(false, false)
    end
    cb({ ok = true })
end)

-- Thin delegates into server/admin: every callback re-checks the admin ace server-side.
proxyCallback('f_phone:admin:search',               'f_phone:server:admin:search')
proxyCallback('f_phone:admin:overview',             'f_phone:server:admin:overview')
proxyCallback('f_phone:admin:setNumber',            'f_phone:server:admin:setNumber')
proxyCallback('f_phone:admin:resetPasscode',        'f_phone:server:admin:resetPasscode')
proxyCallback('f_phone:admin:setApp',               'f_phone:server:admin:setApp')
proxyCallback('f_phone:admin:resetAccountPassword', 'f_phone:server:admin:resetAccountPassword')
proxyCallback('f_phone:admin:forceLogout',          'f_phone:server:admin:forceLogout')
proxyCallback('f_phone:admin:birdyPosts',           'f_phone:server:admin:birdyPosts')
proxyCallback('f_phone:admin:birdyDeletePost',      'f_phone:server:admin:birdyDeletePost')
proxyCallback('f_phone:admin:birdySetVerified',     'f_phone:server:admin:birdySetVerified')
proxyCallback('f_phone:admin:content',              'f_phone:server:admin:content')
proxyCallback('f_phone:admin:contentDelete',        'f_phone:server:admin:contentDelete')
proxyCallback('f_phone:admin:contentThread',        'f_phone:server:admin:contentThread')
proxyCallback('f_phone:admin:contentThreadDelete',  'f_phone:server:admin:contentThreadDelete')
proxyCallback('f_phone:admin:media',                'f_phone:server:admin:media')
proxyCallback('f_phone:admin:livePositions',        'f_phone:server:admin:livePositions')
proxyCallback('f_phone:admin:flags',                'f_phone:server:admin:flags')
proxyCallback('f_phone:admin:flagsScan',            'f_phone:server:admin:flagsScan')
proxyCallback('f_phone:admin:flagResolve',          'f_phone:server:admin:flagResolve')
proxyCallback('f_phone:admin:bin',                  'f_phone:server:admin:bin')
proxyCallback('f_phone:admin:binRestore',           'f_phone:server:admin:binRestore')
proxyCallback('f_phone:admin:messages',             'f_phone:server:admin:messages')
proxyCallback('f_phone:admin:calls',                'f_phone:server:admin:calls')
proxyCallback('f_phone:admin:mute',                 'f_phone:server:admin:mute')
proxyCallback('f_phone:admin:unmute',               'f_phone:server:admin:unmute')
proxyCallback('f_phone:admin:mutes',                'f_phone:server:admin:mutes')
proxyCallback('f_phone:admin:wipePhone',            'f_phone:server:admin:wipePhone')
proxyCallback('f_phone:admin:audit',                'f_phone:server:admin:audit')
proxyCallback('f_phone:admin:stats',                'f_phone:server:admin:stats')
proxyCallback('f_phone:admin:simLookup',            'f_phone:server:admin:simLookup')
proxyCallback('f_phone:admin:giveSim',              'f_phone:server:admin:giveSim')
proxyCallback('f_phone:admin:numbers',              'f_phone:server:admin:numbers')
proxyCallback('f_phone:admin:migrateScan',          'f_phone:server:admin:migrateScan')
proxyCallback('f_phone:admin:migrateState',         'f_phone:server:admin:migrateState')
proxyCallback('f_phone:admin:migrateStart',         'f_phone:server:admin:migrateStart')
proxyCallback('f_phone:admin:migrateStop',          'f_phone:server:admin:migrateStop')
proxyCallback('f_phone:admin:migrateWatch',         'f_phone:server:admin:migrateWatch')

---Server to React: one migration progress push. The server only sends these to admins who asked
---to watch, so this relays whatever arrives without a gate of its own.
---@param payload table { state?: table, lines?: table[], reset?: boolean }
RegisterNetEvent('f_phone:client:migrate:push', function(payload)
    SendNUIMessage({ action = 'f_phone:admin:migrate', data = payload })
end)
