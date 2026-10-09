---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates: directory, duty + contact toggles, company account, and roster management all
-- proxy straight into server callbacks.
proxy('f_phone:services:directory',   'f_phone:server:services:directory')
proxy('f_phone:services:setDuty',        'f_phone:server:services:setDuty')
proxy('f_phone:services:setJobCalls',    'f_phone:server:services:setJobCalls')
proxy('f_phone:services:setJobMessages', 'f_phone:server:services:setJobMessages')
proxy('f_phone:services:deposit',     'f_phone:server:services:deposit')
proxy('f_phone:services:withdraw',    'f_phone:server:services:withdraw')
proxy('f_phone:services:hire',        'f_phone:server:services:hire')
proxy('f_phone:services:fire',        'f_phone:server:services:fire')
proxy('f_phone:services:promote',     'f_phone:server:services:promote')
proxy('f_phone:services:demote',      'f_phone:server:services:demote')
proxy('f_phone:services:quit',        'f_phone:server:services:quit')

-- Thin delegates: company calls and the company message inbox.
proxy('f_phone:services:callCompany',    'f_phone:server:services:callCompany')
proxy('f_phone:services:inbox',          'f_phone:server:services:inbox')
proxy('f_phone:services:markRead',       'f_phone:server:services:markRead')
proxy('f_phone:services:messageCompany', 'f_phone:server:services:messageCompany')
proxy('f_phone:services:replyCompany',   'f_phone:server:services:replyCompany')

-- Thin delegates for the Jobs tab (multi-job): list saved jobs + offers, switch active job,
-- accept/decline an offer.
proxy('f_phone:services:listJobs',       'f_phone:server:services:listJobs')
proxy('f_phone:services:switchJob',      'f_phone:server:services:switchJob')
proxy('f_phone:services:removeJob',      'f_phone:server:services:removeJob')
proxy('f_phone:services:acceptInvite',   'f_phone:server:services:acceptInvite')
proxy('f_phone:services:declineInvite',  'f_phone:server:services:declineInvite')

-- Thin delegates for business invoicing: send/list/cancel from the business side, received/pay
-- from the target's Banking app.
proxy('f_phone:services:invoices:list',     'f_phone:server:services:invoices:list')
proxy('f_phone:services:invoices:create',   'f_phone:server:services:invoices:create')
proxy('f_phone:services:invoices:cancel',   'f_phone:server:services:invoices:cancel')
proxy('f_phone:services:invoices:received', 'f_phone:server:services:invoices:received')
proxy('f_phone:services:invoices:pay',      'f_phone:server:services:invoices:pay')

-- Leaderboard tab (server/services/leaderboard.lua).
proxy('f_phone:services:leaderboard',       'f_phone:server:services:leaderboard')
proxy('f_phone:services:leaderboard:reset', 'f_phone:server:services:leaderboard:reset')

-- Lamaran kerja (server/services/applications.lua).
proxy('f_phone:services:apply',                'f_phone:server:services:apply')
proxy('f_phone:services:applications',         'f_phone:server:services:applications')
proxy('f_phone:services:applications:accept',  'f_phone:server:services:applications:accept')
proxy('f_phone:services:applications:reject',  'f_phone:server:services:applications:reject')

---Server nudge: ada lamaran baru untuk boss; bagian Lamaran Masuk refetch. No payload.
RegisterNetEvent('f_phone:client:services:applications', function()
    SendNUIMessage({ action = 'f_phone:services:applications' })
end)

---Server nudge: leaderboard job ini di-reset boss; tab yang terbuka refetch. No payload.
RegisterNetEvent('f_phone:client:services:leaderboard', function()
    SendNUIMessage({ action = 'f_phone:services:leaderboard' })
end)

---Server nudge: re-pull invoices (a new one was sent, paid, or cancelled). No payload.
RegisterNetEvent('f_phone:client:services:invoices', function()
    SendNUIMessage({ action = 'f_phone:services:invoices' })
end)

---Server nudge: re-pull the jobs/offers list. No payload.
RegisterNetEvent('f_phone:client:services:jobsChanged', function()
    SendNUIMessage({ action = 'f_phone:services:jobsChanged' })
end)

---Server nudge: a boss should re-pull the employee roster (someone joined/left/ranked).
RegisterNetEvent('f_phone:client:services:rosterChanged', function()
    SendNUIMessage({ action = 'f_phone:services:rosterChanged' })
end)

---Server nudge: re-pull the company inbox (new company message / staff reply).
RegisterNetEvent('f_phone:client:services:inbox', function()
    SendNUIMessage({ action = 'f_phone:services:inbox' })
end)

---Drops a GPS waypoint on the company's coords; nil-guarded.
---@param payload table { coords: { x: number, y: number } }
RegisterNUICallback('f_phone:services:locate', function(payload, cb)
    local c = payload and payload.coords
    if c and c.x and c.y then
        SetNewWaypoint(c.x + 0.0, c.y + 0.0)
        cb({ success = true })
    else
        cb({ success = false, message = 'No location set' })
    end
end)

---Relays server-pushed duty changes into the app.
---@param data table duty-change payload from the server
RegisterNetEvent('f_phone:client:services:dutyChanged', function(data)
    SendNUIMessage({ action = 'f_phone:services:dutyChanged', data = data })
end)
