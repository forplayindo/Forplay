-- Hanya buka/tutup NUI. Tidak ada loop; data dikirim server saat /ekonomi.
local open = false

RegisterNetEvent('f_dashboard:open', function(data)
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_dashboard:refresh', false) or false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
