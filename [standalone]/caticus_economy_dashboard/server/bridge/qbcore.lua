if Config.Framework ~= 'qbcore' and Config.Framework ~= 'auto' then return end

local QBCore = nil
local isQBCore = false

CreateThread(function()
    local success = pcall(function()
        QBCore = exports['qb-core']:GetCoreObject()
    end)
    
    if success and QBCore then
        isQBCore = true
        Bridge.Framework = 'qbcore'
        Bridge.FrameworkObject = QBCore
        
        if Config.Debug then
            print('[Economy Dashboard] QBCore framework detected and loaded')
        end
        
        RegisterQBCoreHooks()
    end
end)

function RegisterQBCoreHooks()
    local originalAddMoney = QBCore.Functions.AddMoney
    if originalAddMoney then
    end
end

function Bridge.QBCore_GetPlayer(source)
    if not isQBCore then return nil end
    return QBCore.Functions.GetPlayer(source)
end

function Bridge.QBCore_GetPlayerByCitizenId(citizenid)
    if not isQBCore then return nil end
    return QBCore.Functions.GetPlayerByCitizenId(citizenid)
end

function Bridge.QBCore_GetPlayers()
    if not isQBCore then return {} end
    return QBCore.Functions.GetPlayers()
end

function Bridge.QBCore_GetPlayerMoney(source, moneyType)
    if not isQBCore then return 0 end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end
    
    moneyType = moneyType or 'cash'
    local moneyMapping = {
        cash = 'cash',
        bank = 'bank',
        dirty = 'crypto',
        crypto = 'crypto',
    }
    
    return Player.PlayerData.money[moneyMapping[moneyType] or moneyType] or 0
end

function Bridge.QBCore_GetAllPlayerMoney(source)
    if not isQBCore then return {} end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end
    
    return {
        cash = Player.PlayerData.money.cash or 0,
        bank = Player.PlayerData.money.bank or 0,
        dirty = Player.PlayerData.money.crypto or 0,
        crypto = 0,
    }
end

function Bridge.QBCore_AddMoney(source, moneyType, amount, reason)
    if not isQBCore then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.AddMoney(moneyType, amount, reason)
end

function Bridge.QBCore_RemoveMoney(source, moneyType, amount, reason)
    if not isQBCore then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.RemoveMoney(moneyType, amount, reason)
end

function Bridge.QBCore_SetMoney(source, moneyType, amount, reason)
    if not isQBCore then return false end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.SetMoney(moneyType, amount, reason)
end

function Bridge.QBCore_GetIdentifier(source)
    if not isQBCore then return nil end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    
    return Player.PlayerData.citizenid
end

function Bridge.QBCore_GetPlayerName(source)
    if not isQBCore then return 'Unknown' end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 'Unknown' end
    
    local charinfo = Player.PlayerData.charinfo
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

function Bridge.QBCore_HasPermission(source, permission)
    if not isQBCore then return false end
    
    if IsPlayerAceAllowed(source, Config.AdminPermissions.acePermission) then
        return true
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerPermission = QBCore.Functions.GetPermission(source)
    
    for _, perm in ipairs(Config.AdminPermissions.qbcore) do
        if playerPermission == perm then
            return true
        end
    end
    
    return false
end

function Bridge.QBCore_GetAllPlayersWithMoney()
    if not isQBCore then return {} end
    
    local players = {}
    local qbPlayers = QBCore.Functions.GetPlayers()
    
    for _, playerId in ipairs(qbPlayers) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            table.insert(players, {
                source = playerId,
                citizenid = Player.PlayerData.citizenid,
                name = Bridge.QBCore_GetPlayerName(playerId),
                money = Bridge.QBCore_GetAllPlayerMoney(playerId),
            })
        end
    end
    
    return players
end

function Bridge.QBCore_GetServerTotals()
    if not isQBCore then return nil end
    
    local totals = {
        cash = 0,
        bank = 0,
        dirty = 0,
        crypto = 0,
        totalPlayers = 0,
    }
    
    local result = MySQL.query.await([[
        SELECT 
            SUM(JSON_EXTRACT(money, '$.cash')) as total_cash,
            SUM(JSON_EXTRACT(money, '$.bank')) as total_bank,
            SUM(JSON_EXTRACT(money, '$.crypto')) as total_dirty,
            COUNT(*) as total_players
        FROM players
    ]])
    
    if result and result[1] then
        totals.cash = tonumber(result[1].total_cash) or 0
        totals.bank = tonumber(result[1].total_bank) or 0
        totals.dirty = tonumber(result[1].total_dirty) or 0
        totals.totalPlayers = tonumber(result[1].total_players) or 0
    end
    
    return totals
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(source, moneyType, amount, action, reason)
    if not isQBCore then return end
    
    local citizenid = Bridge.QBCore_GetIdentifier(source)
    if not citizenid then return end
    
    local balanceAfter = Bridge.QBCore_GetPlayerMoney(source, moneyType)
    
    local transactionType = 'faucet'
    if action == 'remove' then
        transactionType = 'sink'
    end
    
    if Tracking then
        Tracking.LogTransaction({
            type = transactionType,
            amount = amount,
            moneyType = moneyType,
            playerFrom = (action == 'remove') and citizenid or nil,
            playerTo = (action == 'add') and citizenid or nil,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)

RegisterNetEvent('qb-core:server:MoneyChanged', function(moneyType, amount, action, reason)
end)
