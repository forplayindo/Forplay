local mode -- nil | 'audit' | 'pay'

local function notify(msg, typ)
    lib.notify({ title = 'Pajak Kota', description = msg, type = typ or 'inform' })
end

local function close()
    mode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open(m)
    if mode then return end
    local data = lib.callback.await('f_tax:open', false, m)
    if not data or data.err then return notify(data and data.err or 'Server tidak merespons.', 'error') end
    mode = m
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterCommand('auditpajak', function() open('audit') end, false)
RegisterCommand('bayarpajak', function() open('pay') end, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/auditpajak', 'Audit pajak perusahaan (pemerintah, on duty)')
    TriggerEvent('chat:addSuggestion', '/bayarpajak', 'Bayar pajak perusahaan (pimpinan)')
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    if not mode then return cb(false) end
    local data = lib.callback.await('f_tax:open', false, mode)
    if data and data.soft then return cb(false) end -- klik terlalu cepat, menu tetap terbuka
    if not data or data.err then
        notify(data and data.err or 'Server tidak merespons.', 'error')
        close()
        return cb(false)
    end
    cb(data)
end)

RegisterNUICallback('history', function(body, cb)
    cb(lib.callback.await('f_tax:history', false, body.job) or false)
end)

local function action(name, ...)
    local res = lib.callback.await(name, false, ...)
    if not res then
        notify('Server tidak merespons.', 'error')
        return { ok = false }
    end
    notify(res.msg, res.ok and 'success' or 'error')
    if res.data and res.data.err then close() end
    return res
end

RegisterNUICallback('setRate', function(body, cb)
    if mode ~= 'audit' then return cb({ ok = false }) end
    cb(action('f_tax:setRate', body.rate))
end)

RegisterNUICallback('pay', function(_, cb)
    if mode ~= 'pay' then return cb({ ok = false }) end
    cb(action('f_tax:pay'))
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and mode then SetNuiFocus(false, false) end
end)
