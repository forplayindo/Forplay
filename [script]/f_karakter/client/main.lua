local isOpen = false

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('f_karakter:client:open', function(days)
    if GetInvokingResource() then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', days = days })
end)

RegisterNUICallback('list', function(data, cb)
    cb(lib.callback.await('f_karakter:server:list', false, data) or { error = 'Gagal memuat' })
end)

RegisterNUICallback('delete', function(data, cb)
    cb(lib.callback.await('f_karakter:server:delete', false, data and data.citizenid) or { error = 'Gagal menghapus' })
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    close()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then close() end
end)
