---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxyCallback = require 'client.nui'

-- Thin delegates into server/gifs: read-only GIF-picker lookups.
proxyCallback('f_phone:gifs:categories', 'f_phone:server:gifs:categories')
proxyCallback('f_phone:gifs:featured',   'f_phone:server:gifs:featured')
proxyCallback('f_phone:gifs:search',     'f_phone:server:gifs:search')
