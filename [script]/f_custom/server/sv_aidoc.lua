local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('hhfw:docOnline', function(source, cb)
    local src = source
    local Ply = QBCore.Functions.GetPlayer(src)
    local xPlayers = QBCore.Functions.GetPlayers()
    local doctorOnDuty = 0
    local canPay = false
    
    if Ply.PlayerData.money["cash"] >= Config.Price then
        canPay = true
    elseif Ply.PlayerData.money["bank"] >= Config.Price then
        canPay = true
    end
    
    for i = 1, #xPlayers, 1 do
        local xPlayer = QBCore.Functions.GetPlayer(xPlayers[i])
        if xPlayer.PlayerData.job.name == 'ambulance' and xPlayer.PlayerData.job.onduty then
            doctorOnDuty = doctorOnDuty + 1
        end
    end

    cb(doctorOnDuty, canPay)
end)


RegisterServerEvent('hhfw:charge')
AddEventHandler('hhfw:charge', function()
	local src = source
	local xPlayer = QBCore.Functions.GetPlayer(src)
	if xPlayer.PlayerData.money["cash"] >= Config.Price then
		xPlayer.Functions.RemoveMoney("cash", Config.Price)
	else
		xPlayer.Functions.RemoveMoney("bank", Config.Price)
	end
	TriggerEvent("qb-bossmenu:server:addAccountMoney", 'ambulance', Config.Price)
end)
