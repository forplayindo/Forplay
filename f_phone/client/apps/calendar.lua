---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

---@type string[] NUI action suffixes proxied 1:1 to f_phone:server:calendar:<action>.
local ACTIONS = { 'list', 'save', 'delete', 'invite', 'respond', 'uninvite' }

-- Thin delegates into server/calendar.
for _, action in ipairs(ACTIONS) do
    proxy('f_phone:calendar:' .. action, 'f_phone:server:calendar:' .. action)
end

---Server push: an organizer added us to their event; hands the whole event to the open app so the
---new invite lands without a round trip.
---@param data table { event: table } serialized for us as the invitee
RegisterNetEvent('f_phone:client:calendar:invited', function(data)
    SendNUIMessage({ action = 'f_phone:calendar:invited', data = data })
end)

---Server push: an event we are on changed (edited, cancelled, answered, or we were removed from
---it), so the app reloads.
---@param data table { eventId: string }
RegisterNetEvent('f_phone:client:calendar:refresh', function(data)
    SendNUIMessage({ action = 'f_phone:calendar:refresh', data = data })
end)
