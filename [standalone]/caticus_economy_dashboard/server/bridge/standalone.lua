if Config.Framework ~= 'standalone' and Config.Framework ~= 'auto' then return end

local isStandalone = false

CreateThread(function()
    Wait(2500)
    
    if Config.Framework ~= 'auto' and Config.Framework ~= 'standalone' then
        return
    end
    
    if Bridge.Framework == nil then
        isStandalone = true
        Bridge.Framework = 'standalone'
        
        if Config.Debug then
            print('[Economy Dashboard] No framework detected, using standalone mode')
        end
    end
end)

function Bridge.Standalone_GetIdentifier(source)
    if not isStandalone then return nil end
    
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(id, 'steam:') then
            return id
        end
    end
    
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(id, 'license:') then
            return id
        end
    end
    
    return nil
end

function Bridge.Standalone_GetPlayerName(source)
    if not isStandalone then return 'Unknown' end
    return GetPlayerName(source) or 'Unknown'
end

function Bridge.Standalone_HasPermission(source, permission)
    if not isStandalone then return false end
    
    if IsPlayerAceAllowed(source, Config.AdminPermissions.acePermission) then
        return true
    end
    
    local steamId = nil
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(id, 'steam:') then
            steamId = id
            break
        end
    end
    
    if steamId then
        for _, allowedId in ipairs(Config.AdminPermissions.standalone) do
            if steamId == allowedId then
                return true
            end
        end
    end
    
    return false
end

exports('LogFaucet', function(identifier, amount, category, reason, moneyType, metadata)
    if Tracking then
        Tracking.LogTransaction({
            type = 'faucet',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = nil,
            playerTo = identifier,
            category = category,
            reason = reason,
            metadata = metadata,
        })
    end
    return true
end)

exports('LogSink', function(identifier, amount, category, reason, moneyType, metadata)
    if Tracking then
        Tracking.LogTransaction({
            type = 'sink',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = identifier,
            playerTo = nil,
            category = category,
            reason = reason,
            metadata = metadata,
        })
    end
    return true
end)

exports('LogTransfer', function(fromIdentifier, toIdentifier, amount, reason, moneyType, metadata)
    if Tracking then
        Tracking.LogTransaction({
            type = 'transfer',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = fromIdentifier,
            playerTo = toIdentifier,
            category = 'transfer',
            reason = reason,
            metadata = metadata,
        })
    end
    return true
end)

exports('UpdateServerTotals', function(totals)
    if not totals then return false end
    
    MySQL.insert.await([[
        INSERT INTO economy_config (`key`, `value`) 
        VALUES 
            ('cached_total_cash', ?),
            ('cached_total_bank', ?),
            ('cached_total_dirty', ?),
            ('cached_total_crypto', ?),
            ('cached_total_players', ?)
        ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
    ]], {
        tostring(totals.cash or 0),
        tostring(totals.bank or 0),
        tostring(totals.dirty or 0),
        tostring(totals.crypto or 0),
        tostring(totals.totalPlayers or 0),
    })
    
    return true
end)

RegisterNetEvent('economy_dashboard:logFaucet', function(identifier, amount, category, reason, moneyType, metadata)
    if source ~= '' then return end
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'faucet',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = nil,
            playerTo = identifier,
            category = category,
            reason = reason,
            metadata = metadata,
        })
    end
end)

RegisterNetEvent('economy_dashboard:logSink', function(identifier, amount, category, reason, moneyType, metadata)
    if source ~= '' then return end
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'sink',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = identifier,
            playerTo = nil,
            category = category,
            reason = reason,
            metadata = metadata,
        })
    end
end)

RegisterNetEvent('economy_dashboard:logTransfer', function(fromIdentifier, toIdentifier, amount, reason, moneyType, metadata)
    if source ~= '' then return end
    
    if Tracking then
        Tracking.LogTransaction({
            type = 'transfer',
            amount = amount,
            moneyType = moneyType or 'cash',
            playerFrom = fromIdentifier,
            playerTo = toIdentifier,
            category = 'transfer',
            reason = reason,
            metadata = metadata,
        })
    end
end)

function Bridge.Standalone_GetServerTotals()
    local result = MySQL.query.await([[
        SELECT `key`, `value` FROM economy_config 
        WHERE `key` IN ('cached_total_cash', 'cached_total_bank', 'cached_total_dirty', 'cached_total_crypto', 'cached_total_players')
    ]])
    
    if not result or #result == 0 then
        return nil
    end
    
    local totals = {
        cash = 0,
        bank = 0,
        dirty = 0,
        crypto = 0,
        totalPlayers = 0,
    }
    
    for _, row in ipairs(result) do
        if row.key == 'cached_total_cash' then
            totals.cash = tonumber(row.value) or 0
        elseif row.key == 'cached_total_bank' then
            totals.bank = tonumber(row.value) or 0
        elseif row.key == 'cached_total_dirty' then
            totals.dirty = tonumber(row.value) or 0
        elseif row.key == 'cached_total_crypto' then
            totals.crypto = tonumber(row.value) or 0
        elseif row.key == 'cached_total_players' then
            totals.totalPlayers = tonumber(row.value) or 0
        end
    end
    
    return totals
end

function Bridge.Standalone_GetAllPlayersWithMoney()
    local players = {}
    
    for _, playerId in ipairs(GetPlayers()) do
        local identifier = Bridge.Standalone_GetIdentifier(tonumber(playerId))
        if identifier then
            table.insert(players, {
                source = tonumber(playerId),
                citizenid = identifier,
                name = GetPlayerName(playerId) or 'Unknown',
                money = {cash = 0, bank = 0, dirty = 0, crypto = 0},
            })
        end
    end
    
    return players
end
