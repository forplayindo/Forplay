if Config.Framework ~= 'qbox' and Config.Framework ~= 'auto' then return end

local isQBox = false
local qboxResourceName = nil

CreateThread(function()
    Wait(500)
    
    local state = GetResourceState('qbx_core')
    
    if state == 'started' then
        qboxResourceName = 'qbx_core'
        isQBox = true
        Bridge.Framework = 'qbox'
        print('[Economy Dashboard] QBox (qbx_core) detected and loaded')
    elseif Config.Framework == 'qbox' then
        print('[Economy Dashboard] WARNING: qbox forced but qbx_core not found')
        if GetResourceState('qb-core') == 'started' then
            print('[Economy Dashboard] Found qb-core instead - this is QBCore, not QBox')
            print('[Economy Dashboard] Change Config.Framework to "qbcore" or "auto"')
        end
    end
end)

function Bridge.QBox_GetPlayer(source)
    if not isQBox then return nil end
    return exports.qbx_core:GetPlayer(source)
end

function Bridge.QBox_GetPlayerByCitizenId(citizenid)
    if not isQBox then return nil end
    return exports.qbx_core:GetPlayerByCitizenId(citizenid)
end

function Bridge.QBox_GetPlayers()
    if not isQBox then return {} end
    return exports.qbx_core:GetQBPlayers()
end

function Bridge.QBox_GetPlayerMoney(source, moneyType)
    if not isQBox then return 0 end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return 0 end
    
    moneyType = moneyType or 'cash'
    return Player.PlayerData.money[moneyType] or 0
end

function Bridge.QBox_GetAllPlayerMoney(source)
    if not isQBox then return {} end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return {} end
    
    return {
        cash = Player.PlayerData.money.cash or 0,
        bank = Player.PlayerData.money.bank or 0,
        dirty = Player.PlayerData.money.crypto or 0,
        crypto = 0,
    }
end

function Bridge.QBox_AddMoney(source, moneyType, amount, reason)
    if not isQBox then return false end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    return Player.Functions.AddMoney(moneyType, amount, reason)
end

function Bridge.QBox_RemoveMoney(source, moneyType, amount, reason)
    if not isQBox then return false end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    return Player.Functions.RemoveMoney(moneyType, amount, reason)
end

function Bridge.QBox_SetMoney(source, moneyType, amount, reason)
    if not isQBox then return false end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return false end
    return Player.Functions.SetMoney(moneyType, amount, reason)
end

function Bridge.QBox_GetIdentifier(source)
    if not isQBox then return nil end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return nil end
    return Player.PlayerData.citizenid
end

function Bridge.QBox_GetPlayerName(source)
    if not isQBox then return 'Unknown' end
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return 'Unknown' end
    
    local charinfo = Player.PlayerData.charinfo
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

function Bridge.QBox_HasPermission(source, permission)
    if not isQBox then return false end
    
    if IsPlayerAceAllowed(source, Config.AdminPermissions.acePermission) then
        return true
    end
    
    for _, perm in ipairs(Config.AdminPermissions.qbox) do
        if exports.qbx_core:HasPermission(source, perm) then
            return true
        end
    end
    
    return false
end

function Bridge.QBox_GetAllPlayersWithMoney()
    if not isQBox then return {} end
    
    local players = {}
    
    local success, qbxPlayers = pcall(function()
        return exports.qbx_core:GetQBPlayers()
    end)
    
    if success and qbxPlayers then
        for playerId, Player in pairs(qbxPlayers) do
            if Player then
                table.insert(players, {
                    source = playerId,
                    citizenid = Player.PlayerData.citizenid,
                    name = Bridge.QBox_GetPlayerName(playerId),
                    money = Bridge.QBox_GetAllPlayerMoney(playerId),
                })
            end
        end
    else
        for _, playerId in ipairs(GetPlayers()) do
            local pid = tonumber(playerId)
            local Player = exports.qbx_core:GetPlayer(pid)
            if Player then
                table.insert(players, {
                    source = pid,
                    citizenid = Player.PlayerData.citizenid,
                    name = Bridge.QBox_GetPlayerName(pid),
                    money = Bridge.QBox_GetAllPlayerMoney(pid),
                })
            end
        end
    end
    
    return players
end

function Bridge.QBox_GetServerTotals()
    if not isQBox then return nil end
    
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
    if Config.Debug then
        print(('[Economy Dashboard] QBCore:Server:OnMoneyChange - source: %s, type: %s, amount: %s, action: %s'):format(
            tostring(source), tostring(moneyType), tostring(amount), tostring(action)
        ))
    end
    
    if not isQBox then return end
    if not source or not amount then return end
    
    local citizenid = Bridge.QBox_GetIdentifier(source)
    if not citizenid then return end
    
    local playerName = Bridge.QBox_GetPlayerName(source)
    
    local validTypes = { cash = true, bank = true, dirty = true, crypto = true }
    if not moneyType or not validTypes[tostring(moneyType):lower()] then
        moneyType = 'cash'
    end
    
    local balanceAfter = Bridge.QBox_GetPlayerMoney(source, moneyType)
    if type(balanceAfter) ~= 'number' then
        balanceAfter = nil
    end
    
    local transactionType = (action == 'add') and 'faucet' or 'sink'
    
    if Config.Debug then
        print(('[Economy Dashboard] Logging transaction: %s Rp %s for %s'):format(transactionType, amount, citizenid))
    end
    
    if Tracking then
        Tracking.LogTransaction({
            type = transactionType,
            amount = tonumber(amount) or 0,
            moneyType = tostring(moneyType):lower(),
            playerFrom = (action == 'remove') and citizenid or nil,
            playerTo = (action == 'add') and citizenid or nil,
            playerName = playerName,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)

AddEventHandler('qbx_core:server:onMoneyChange', function(source, moneyType, amount, action, reason)
    if Config.Debug then
        print(('[Economy Dashboard] qbx_core:server:onMoneyChange - source: %s, type: %s, amount: %s, action: %s'):format(
            tostring(source), tostring(moneyType), tostring(amount), tostring(action)
        ))
    end
    
    if not isQBox then return end
    if not source or not amount then return end
    
    local citizenid = Bridge.QBox_GetIdentifier(source)
    if not citizenid then return end
    
    local playerName = Bridge.QBox_GetPlayerName(source)
    
    local validTypes = { cash = true, bank = true, dirty = true, crypto = true }
    if not moneyType or not validTypes[tostring(moneyType):lower()] then
        moneyType = 'cash'
    end
    
    local balanceAfter = Bridge.QBox_GetPlayerMoney(source, moneyType)
    if type(balanceAfter) ~= 'number' then
        balanceAfter = nil
    end
    
    local transactionType = (action == 'add') and 'faucet' or 'sink'
    
    if Config.Debug then
        print(('[Economy Dashboard] Logging transaction: %s Rp %s for %s'):format(transactionType, amount, citizenid))
    end
    
    if Tracking then
        Tracking.LogTransaction({
            type = transactionType,
            amount = tonumber(amount) or 0,
            moneyType = tostring(moneyType):lower(),
            playerFrom = (action == 'remove') and citizenid or nil,
            playerTo = (action == 'add') and citizenid or nil,
            playerName = playerName,
            reason = reason,
            balanceAfter = balanceAfter,
        })
    end
end)
