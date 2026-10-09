---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/birdy: account session, profiles, the feed, posting, likes,
-- follows, notifications and DMs.
proxyCallback('f_phone:birdy:me',            'f_phone:server:birdy:me')
proxyCallback('f_phone:birdy:register',      'f_phone:server:birdy:register')
proxyCallback('f_phone:birdy:login',         'f_phone:server:birdy:login')
proxyCallback('f_phone:birdy:logout',        'f_phone:server:birdy:logout')
proxyCallback('f_phone:birdy:profile',        'f_phone:server:birdy:profile')
proxyCallback('f_phone:birdy:profilePosts',   'f_phone:server:birdy:profilePosts')
proxyCallback('f_phone:birdy:search',         'f_phone:server:birdy:search')
proxyCallback('f_phone:birdy:trending',       'f_phone:server:birdy:trending')
proxyCallback('f_phone:birdy:hashtag',        'f_phone:server:birdy:hashtag')
proxyCallback('f_phone:birdy:updateProfile',  'f_phone:server:birdy:updateProfile')
proxyCallback('f_phone:birdy:changePassword', 'f_phone:server:birdy:changePassword')
proxyCallback('f_phone:birdy:deleteAccount',  'f_phone:server:birdy:deleteAccount')
proxyCallback('f_phone:birdy:verificationOffer',    'f_phone:server:birdy:verificationOffer')
proxyCallback('f_phone:birdy:purchaseVerification', 'f_phone:server:birdy:purchaseVerification')
proxyCallback('f_phone:birdy:feed',          'f_phone:server:birdy:feed')
proxyCallback('f_phone:birdy:post',          'f_phone:server:birdy:post')
proxyCallback('f_phone:birdy:create',        'f_phone:server:birdy:create')
proxyCallback('f_phone:birdy:reply',         'f_phone:server:birdy:reply')
proxyCallback('f_phone:birdy:toggleLike',    'f_phone:server:birdy:toggleLike')
proxyCallback('f_phone:birdy:deletePost',    'f_phone:server:birdy:deletePost')
proxyCallback('f_phone:birdy:toggleFollow',  'f_phone:server:birdy:toggleFollow')
proxyCallback('f_phone:birdy:toggleRepost', 'f_phone:server:birdy:toggleRepost')
proxyCallback('f_phone:birdy:vote',          'f_phone:server:birdy:vote')
proxyCallback('f_phone:birdy:followList',    'f_phone:server:birdy:followList')
proxyCallback('f_phone:birdy:notifications', 'f_phone:server:birdy:notifications')
proxyCallback('f_phone:birdy:notificationCount', 'f_phone:server:birdy:notificationCount')
proxyCallback('f_phone:birdy:dmResolve',     'f_phone:server:birdy:dmResolve')
proxyCallback('f_phone:birdy:dmList',        'f_phone:server:birdy:dmList')
proxyCallback('f_phone:birdy:dmThread',      'f_phone:server:birdy:dmThread')
proxyCallback('f_phone:birdy:dmSend',        'f_phone:server:birdy:dmSend')
proxyCallback('f_phone:birdy:dmReact',       'f_phone:server:birdy:dmReact')
proxyCallback('f_phone:birdy:watch',         'f_phone:server:birdy:watch')

---Server push: relays a DM that arrived for our logged-in Birdy account.
---@param data table DM record from server/birdy/init.lua
RegisterNetEvent('f_phone:client:birdy:dmReceived', function(data)
    SendNUIMessage({ action = 'f_phone:birdy:dmReceived', data = data })
end)

---Server push: relays an updated DM reaction set.
---@param data table reaction patch from server/birdy/init.lua
RegisterNetEvent('f_phone:client:birdy:dmReaction', function(data)
    SendNUIMessage({ action = 'f_phone:birdy:dmReaction', data = data })
end)

---Server push: relays a notification nudge (like, reply, follow).
---@param data table notification nudge from server/birdy/init.lua (currently empty)
RegisterNetEvent('f_phone:client:birdy:notification', function(data)
    SendNUIMessage({ action = 'f_phone:birdy:notification', data = data })
end)

---Server push: somebody posted, reposted or voted, so any open feed is now stale. A vote carries
---{ postId, poll } so the timeline patches that one card; anything else is empty and refetches.
---@param data table patch or empty payload from server/birdy/actions.lua
RegisterNetEvent('f_phone:client:birdy:feedChanged', function(data)
    SendNUIMessage({ action = 'f_phone:birdy:feedChanged', data = data or {} })
end)
