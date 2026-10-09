RegisterNetEvent('gx_notify:send')
AddEventHandler('gx_notify:send', function(text, title, typex, position, duration, id)
    Gx_Notify(text, title, typex, position, duration, id)
end)

function Gx_Notify(text, tittle, typex, position, duration, id)
    if not id then
        local id = source
    end
    if Config.Notify == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', id, {
            title = tittle,
            description = text,
            type = typex,
            position = position,
            duration = duration
        })
    elseif Config.Notify == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(id)
        xPlayer.showNotification(text)
    elseif Config.Notify == 'qb' then
        TriggerClientEvent('QBCore:Notify', id, text)
    elseif Config.Notify == 'custom' then
        Custom_Notify(text, id)
    end
end