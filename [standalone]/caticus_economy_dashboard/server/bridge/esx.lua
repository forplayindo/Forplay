if Config.Framework ~= 'esx' and Config.Framework ~= 'auto' then return end

local ESX = nil
local isESX = false

CreateThread(function()
    local success = pcall(function()
        if GetResourceState('es_extended') == 'started' then
            ESX = exports['es_extended']:getSharedObject()
            isESX = true
        end
    end)
    
    if not isESX then
        TriggerEvent('esx:getSharedObject', function(obj) 
            ESX = obj
            isESX = true
        end)
        Wait(500)
    end
    
    if isESX and ESX then
        Bridge.Framework = 'esx'
        Bridge.FrameworkObject = ESX
        
        if Config.Debug then
            print('[Economy Dashboard] ESX framework detected and loaded')
        end
    end
end)

function Bridge.ESX_GetPlayer(source)
    if not isESX then return nil end
    return ESX.GetPlayerFromId(source)
end

function Bridge.ESX_GetPlayerByIdentifier(identifier)
    if not isESX then return nil end
    return ESX.GetPlayerFromIdentifier(identifier)
end

function Bridge.ESX_GetPlayers()
    if not isESX then return {} end
    return ESX.GetPlayers()
end

function Bridge.ESX_GetPlayerMoney(source, moneyType)
    if not isESX then return 0 end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 0 end
    
    moneyType = moneyType or 'cash'
    
    if moneyType == 'cash' then
        return xPlayer.getMoney()
    elseif moneyType == 'bank' then
        return xPlayer.getAccount('bank').money
    elseif moneyType == 'dirty' or moneyType == 'black_money' then
        return xPlayer.getAccount('black_money').money
    end
    
    local account = xPlayer.getAccount(moneyType)
    return account and account.money or 0
end

function Bridge.ESX_GetAllPlayerMoney(source)
    if not isESX then return {} end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    return {
        cash = xPlayer.getMoney() or 0,
        bank = xPlayer.getAccount('bank').money or 0,
        dirty = xPlayer.getAccount('black_money').money or 0,
        crypto = 0,
    }
end

function Bridge.ESX_AddMoney(source, moneyType, amount, reason)
    if not isESX then return false end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    if moneyType == 'cash' then
        xPlayer.addMoney(amount, reason)
    elseif moneyType == 'bank' then
        xPlayer.addAccountMoney('bank', amount, reason)
    elseif moneyType == 'dirty' or moneyType == 'black_money' then
        xPlayer.addAccountMoney('black_money', amount, reason)
    else
        xPlayer.addAccountMoney(moneyType, amount, reason)
    end
    
    return true
end

function Bridge.ESX_RemoveMoney(source, moneyType, amount, reason)
    if not isESX then return false end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    if moneyType == 'cash' then
        xPlayer.removeMoney(amount, reason)
    elseif moneyType == 'bank' then
        xPlayer.removeAccountMoney('bank', amount, reason)
    elseif moneyType == 'dirty' or moneyType == 'black_money' then
        xPlayer.removeAccountMoney('black_money', amount, reason)
    else
        xPlayer.removeAccountMoney(moneyType, amount, reason)
    end
    
    return true
end

function Bridge.ESX_SetMoney(source, moneyType, amount, reason)
    if not isESX then return false end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    if moneyType == 'cash' then
        xPlayer.setMoney(amount)
    elseif moneyType == 'bank' then
        xPlayer.setAccountMoney('bank', amount, reason)
    elseif moneyType == 'dirty' or moneyType == 'black_money' then
        xPlayer.setAccountMoney('black_money', amount, reason)
    else
        xPlayer.setAccountMoney(moneyType, amount, reason)
    end
    
    return true
end

function Bridge.ESX_GetIdentifier(source)
    if not isESX then return nil end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    
    return xPlayer.getIdentifier()
end

function Bridge.ESX_GetPlayerName(source)
    if not isESX then return 'Unknown' end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 'Unknown' end
    
    return xPlayer.getName() or 'Unknown'
end

function Bridge.ESX_HasPermission(source, permission)
    if not isESX then return false end
    
    if IsPlayerAceAllowed(source, Config.AdminPermissions.acePermission) then
        return true
    end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local playerGroup = xPlayer.getGroup()
    
    for _, group in ipairs(Config.AdminPermissions.esx) do
        if playerGroup == group then
            return true
        end
    end
    
    return false
end

function Bridge.ESX_GetAllPlayersWithMoney()
    if not isESX then return {} end
    
    local players = {}
    local esxPlayers = ESX.GetPlayers()
    
    for _, playerId in ipairs(esxPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            table.insert(players, {
                source = playerId,
                citizenid = xPlayer.getIdentifier(),
                name = xPlayer.getName() or 'Unknown',
                money = Bridge.ESX_GetAllPlayerMoney(playerId),
            })
        end
    end
    
    return players
end

local esxUsesAccountsTable = nil

local function checkESXAccountsMethod()
    if esxUsesAccountsTable ~= nil then
        return esxUsesAccountsTable
    end
    
    local tableCheck = MySQL.query.await("SHOW TABLES LIKE 'user_accounts'")
    esxUsesAccountsTable = tableCheck and #tableCheck > 0
    
    if Config.Debug then
        print('[Economy Dashboard] ESX uses user_accounts table: ' .. tostring(esxUsesAccountsTable))
    end
    
    return esxUsesAccountsTable
end

local function parseESXAccounts(accountsJson)
    if not accountsJson then return 0, 0, 0 end
    
    local success, accounts = pcall(json.decode, accountsJson)
    if not success or not accounts then return 0, 0, 0 end
    
    local cash, bank, dirty = 0, 0, 0
    
    if accounts[1] and accounts[1].name then
        for _, acc in ipairs(accounts) do
            if acc.name == 'money' then cash = tonumber(acc.money) or 0
            elseif acc.name == 'bank' then bank = tonumber(acc.money) or 0
            elseif acc.name == 'black_money' then dirty = tonumber(acc.money) or 0
            end
        end
    else
        cash = tonumber(accounts.money) or 0
        bank = tonumber(accounts.bank) or 0
        dirty = tonumber(accounts.black_money) or 0
    end
    
    return cash, bank, dirty
end

function Bridge.ESX_GetServerTotals()
    if not isESX then return nil end
    
    local totals = {
        cash = 0,
        bank = 0,
        dirty = 0,
        crypto = 0,
        totalPlayers = 0,
    }
    
    local playerCount = MySQL.query.await('SELECT COUNT(*) as count FROM users')
    if playerCount and playerCount[1] then
        totals.totalPlayers = tonumber(playerCount[1].count) or 0
    end
    
    if checkESXAccountsMethod() then
        local cashResult = MySQL.query.await('SELECT SUM(money) as total FROM users')
        local accountsResult = MySQL.query.await([[
            SELECT account_name, SUM(money) as total
            FROM user_accounts
            WHERE account_name IN ('bank', 'black_money')
            GROUP BY account_name
        ]])
        
        if cashResult and cashResult[1] then
            totals.cash = tonumber(cashResult[1].total) or 0
        end
        
        if accountsResult then
            for _, row in ipairs(accountsResult) do
                if row.account_name == 'bank' then
                    totals.bank = tonumber(row.total) or 0
                elseif row.account_name == 'black_money' then
                    totals.dirty = tonumber(row.total) or 0
                end
            end
        end
    else
        local result = MySQL.query.await('SELECT accounts FROM users')
        if result then
            for _, row in ipairs(result) do
                local cash, bank, dirty = parseESXAccounts(row.accounts)
                totals.cash = totals.cash + cash
                totals.bank = totals.bank + bank
                totals.dirty = totals.dirty + dirty
            end
        end
    end
    
    return totals
end

AddEventHandler('esx:addMoney', function(source, amount, reason)
    if not isESX then return end
    
    local identifier = Bridge.ESX_GetIdentifier(source)
    if not identifier then return end
    
    local balanceAfter = Bridge.ESX_GetPlayerMoney(source, 'cash')
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'faucet',
            amount = amount,
            moneyType = 'cash',
            playerFrom = nil,
            playerTo = identifier,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)

AddEventHandler('esx:removeMoney', function(source, amount, reason)
    if not isESX then return end
    
    local identifier = Bridge.ESX_GetIdentifier(source)
    if not identifier then return end
    
    local balanceAfter = Bridge.ESX_GetPlayerMoney(source, 'cash')
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'sink',
            amount = amount,
            moneyType = 'cash',
            playerFrom = identifier,
            playerTo = nil,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)

AddEventHandler('esx:addAccountMoney', function(source, account, amount, reason)
    if not isESX then return end
    
    local identifier = Bridge.ESX_GetIdentifier(source)
    if not identifier then return end
    
    local moneyType = account
    if account == 'black_money' then
        moneyType = 'dirty'
    end
    
    local balanceAfter = Bridge.ESX_GetPlayerMoney(source, moneyType)
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'faucet',
            amount = amount,
            moneyType = moneyType,
            playerFrom = nil,
            playerTo = identifier,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)

AddEventHandler('esx:removeAccountMoney', function(source, account, amount, reason)
    if not isESX then return end
    
    local identifier = Bridge.ESX_GetIdentifier(source)
    if not identifier then return end
    
    local moneyType = account
    if account == 'black_money' then
        moneyType = 'dirty'
    end
    
    local balanceAfter = Bridge.ESX_GetPlayerMoney(source, moneyType)
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'sink',
            amount = amount,
            moneyType = moneyType,
            playerFrom = identifier,
            playerTo = nil,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)
