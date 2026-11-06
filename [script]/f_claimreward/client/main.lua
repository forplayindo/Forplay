-- f_claimreward — client hanya membuka NUI dan meneruskan permintaan ke server. Tidak ada loop.
local open = false

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('f_claimreward:open', function()
    if open then return end
    local state = lib.callback.await('f_claimreward:state', false)
    if not state then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = state })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

local calls = {
    'state', 'daily', 'checkCode', 'claimCode', 'pull', 'buy',
    'adminBoot', 'adminCodes', 'adminSaveCode', 'adminDeleteCode', 'adminShop', 'adminSaveShop',
    'adminDeleteShop', 'adminGive', 'adminWinners', 'adminMarkWinner',
}

for _, name in ipairs(calls) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await('f_claimreward:' .. name, false, data) or { ok = false, msg = 'Server tidak merespons.' })
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
