Admin = Admin or {}

local function lower(s) return tostring(s or ''):lower() end
local function safeNum(x) return tonumber(x) or 0 end

function Admin.GetAdminIdentifier(src)
    if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetIdentifier then
        return Bridge.QBCore_GetIdentifier(src)
    elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetIdentifier then
        return Bridge.QBox_GetIdentifier(src)
    elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetIdentifier then
        return Bridge.ESX_GetIdentifier(src)
    elseif Bridge and Bridge.Framework == 'standalone' and Bridge.Standalone_GetIdentifier then
        return Bridge.Standalone_GetIdentifier(src)
    end
    return tostring(src)
end

function Admin.GetAdminName(src)
    if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetPlayerName then
        return Bridge.QBCore_GetPlayerName(src)
    elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetPlayerName then
        return Bridge.QBox_GetPlayerName(src)
    elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetPlayerName then
        return Bridge.ESX_GetPlayerName(src)
    elseif Bridge and Bridge.Framework == 'standalone' and Bridge.Standalone_GetPlayerName then
        return Bridge.Standalone_GetPlayerName(src)
    end
    return GetPlayerName(src) or 'Unknown'
end

function Admin.NormalizeMoneyTypeUI(moneyType)
    moneyType = lower(moneyType)
    if moneyType == 'crypto' then return 'dirty' end
    if moneyType == 'black_money' then return 'dirty' end
    if moneyType == 'money' then return 'cash' end
    if moneyType == 'cash' or moneyType == 'bank' or moneyType == 'dirty' then
        return moneyType
    end
    return 'cash'
end

function Admin.ToFrameworkMoneyType(normalized)
    normalized = lower(normalized)
    if (Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox')) and normalized == 'dirty' then
        return 'crypto'
    end
    if Bridge and Bridge.Framework == 'esx' and normalized == 'dirty' then
        return 'black_money'
    end
    return normalized
end

local function qbGetOfflineBalance(citizenid)
    local rows = Database.Query([[
        SELECT
            CAST(COALESCE(JSON_EXTRACT(money, '$.cash'), 0) AS SIGNED) AS cash,
            CAST(COALESCE(JSON_EXTRACT(money, '$.bank'), 0) AS SIGNED) AS bank,
            CAST(COALESCE(JSON_EXTRACT(money, '$.crypto'), 0) AS SIGNED) AS crypto
        FROM players
        WHERE citizenid = ?
        LIMIT 1
    ]], { citizenid })
    if not rows or not rows[1] then return nil end
    return {
        cash = safeNum(rows[1].cash),
        bank = safeNum(rows[1].bank),
        crypto = safeNum(rows[1].crypto),
    }
end

local function qbSetOfflineBalance(citizenid, key, value)
    return Database.Update(([[
        UPDATE players
        SET money = JSON_SET(COALESCE(money, '{}'), '$.%s', ?)
        WHERE citizenid = ?
    ]]):format(key), { math.floor(value), citizenid })
end

local function esxHasAccountsColumn()
    local rows = Database.Query("SHOW COLUMNS FROM `users` LIKE 'accounts'")
    return rows and #rows > 0
end

local function esxHasUserAccounts()
    local rows = Database.Query("SHOW TABLES LIKE 'user_accounts'")
    return rows and #rows > 0
end

local function parseESXAccounts(accountsJson)
    if not accountsJson then return {}, true end
    local ok, accounts = pcall(json.decode, accountsJson)
    if not ok or not accounts then return {}, false end
    return accounts, true
end

local function setESXAccountsMoney(accounts, accountName, newVal)
    newVal = math.floor(newVal)
    if accounts[1] and accounts[1].name then
        for _, acc in ipairs(accounts) do
            if acc.name == accountName then
                acc.money = newVal
                return accounts
            end
        end
        accounts[#accounts + 1] = { name = accountName, money = newVal }
        return accounts
    end

    accounts[accountName] = newVal
    return accounts
end

local function esxOfflineGetAccounts(identifier)
    local rows = Database.Query("SELECT accounts, money FROM users WHERE identifier = ? LIMIT 1", { identifier })
    if not rows or not rows[1] then return nil end
    local accounts, ok = parseESXAccounts(rows[1].accounts)
    if not ok then accounts = {} end
    return { accounts = accounts, money = safeNum(rows[1].money) }
end

local function esxOfflineSetCash(identifier, newVal)
    return Database.Update("UPDATE users SET money = ? WHERE identifier = ?", { math.floor(newVal), identifier })
end

local function esxOfflineSetAccounts(identifier, accounts)
    return Database.Update("UPDATE users SET accounts = ? WHERE identifier = ?", { json.encode(accounts), identifier })
end

local function esxOfflineSetUserAccount(identifier, accountName, newVal)
    local affected = Database.Update(
        "UPDATE user_accounts SET money = ? WHERE identifier = ? AND account_name = ?",
        { math.floor(newVal), identifier, accountName }
    )
    if not affected or affected == 0 then
        Database.Insert(
            "INSERT INTO user_accounts (identifier, account_name, money) VALUES (?, ?, ?)",
            { identifier, accountName, math.floor(newVal) }
        )
    end
end

function Admin.SetMoney(adminSrc, citizenid, moneyType, amount, reason)
    local normalized = Admin.NormalizeMoneyTypeUI(moneyType)
    local fwType = Admin.ToFrameworkMoneyType(normalized)
    amount = math.floor(math.max(0, safeNum(amount)))
    reason = tostring(reason or 'Economy Dashboard')

    if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetPlayerByCitizenId then
        local Player = Bridge.QBCore_GetPlayerByCitizenId(citizenid)
        if Player and Player.PlayerData and Player.PlayerData.source then
            local targetSrc = Player.PlayerData.source
            local old = Bridge.QBCore_GetPlayerMoney(targetSrc, fwType)
            Bridge.QBCore_SetMoney(targetSrc, fwType, amount, reason)
            return true, old, amount, targetSrc
        end
    elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetPlayerByCitizenId then
        local Player = Bridge.QBox_GetPlayerByCitizenId(citizenid)
        if Player and Player.PlayerData and Player.PlayerData.source then
            local targetSrc = Player.PlayerData.source
            local old = Bridge.QBox_GetPlayerMoney(targetSrc, fwType)
            Bridge.QBox_SetMoney(targetSrc, fwType, amount, reason)
            return true, old, amount, targetSrc
        end
    elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetPlayerByIdentifier then
        local xPlayer = Bridge.ESX_GetPlayerByIdentifier(citizenid)
        if xPlayer and xPlayer.source then
            local targetSrc = xPlayer.source
            local old = Bridge.ESX_GetPlayerMoney(targetSrc, fwType)
            Bridge.ESX_SetMoney(targetSrc, fwType, amount, reason)
            return true, old, amount, targetSrc
        end
    end

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') then
        local bal = qbGetOfflineBalance(citizenid)
        if not bal then return false, nil, nil end
        local key = (fwType == 'crypto') and 'crypto' or fwType
        local old = safeNum(bal[key])
        qbSetOfflineBalance(citizenid, key, amount)
        return true, old, amount, nil
    end

    if Bridge and Bridge.Framework == 'esx' then
        if esxHasUserAccounts() then
            local old = nil
            if fwType == 'cash' then
                local row = Database.Query("SELECT money FROM users WHERE identifier = ? LIMIT 1", { citizenid })
                old = row and row[1] and safeNum(row[1].money) or 0
                esxOfflineSetCash(citizenid, amount)
                return true, old, amount, nil
            end

            local account = (fwType == 'black_money') and 'black_money' or fwType
            local row = Database.Query("SELECT money FROM user_accounts WHERE identifier = ? AND account_name = ? LIMIT 1", { citizenid, account })
            old = row and row[1] and safeNum(row[1].money) or 0
            esxOfflineSetUserAccount(citizenid, account, amount)
            return true, old, amount, nil
        end

        if esxHasAccountsColumn() then
            local data = esxOfflineGetAccounts(citizenid)
            if not data then return false, nil, nil end

            if fwType == 'cash' then
                local old = data.money
                esxOfflineSetCash(citizenid, amount)
                return true, old, amount, nil
            end

            local accountName = (fwType == 'black_money') and 'black_money' or fwType
            local oldCash, oldBank, oldDirty = 0, 0, 0
            oldCash, oldBank, oldDirty = (function()
                local c, b, d = 0, 0, 0
                local ok, accounts = pcall(function() return data.accounts end)
                if ok and accounts then
                    if accounts[1] and accounts[1].name then
                        for _, acc in ipairs(accounts) do
                            if acc.name == 'money' then c = safeNum(acc.money)
                            elseif acc.name == 'bank' then b = safeNum(acc.money)
                            elseif acc.name == 'black_money' then d = safeNum(acc.money) end
                        end
                    else
                        c = safeNum(accounts.money); b = safeNum(accounts.bank); d = safeNum(accounts.black_money)
                    end
                end
                return c, b, d
            end)()

            local old = (accountName == 'bank' and oldBank) or (accountName == 'black_money' and oldDirty) or 0
            local newAccounts = setESXAccountsMoney(data.accounts, accountName, amount)
            esxOfflineSetAccounts(citizenid, newAccounts)
            return true, old, amount, nil
        end
    end

    return false, nil, nil
end

function Admin.GetCurrentMoney(citizenid, moneyType)
    local normalized = Admin.NormalizeMoneyTypeUI(moneyType)
    local fwType = Admin.ToFrameworkMoneyType(normalized)

    if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetPlayerByCitizenId then
        local Player = Bridge.QBCore_GetPlayerByCitizenId(citizenid)
        if Player and Player.PlayerData and Player.PlayerData.source then
            local targetSrc = Player.PlayerData.source
            return safeNum(Bridge.QBCore_GetPlayerMoney(targetSrc, fwType)), targetSrc, fwType
        end
    elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetPlayerByCitizenId then
        local Player = Bridge.QBox_GetPlayerByCitizenId(citizenid)
        if Player and Player.PlayerData and Player.PlayerData.source then
            local targetSrc = Player.PlayerData.source
            return safeNum(Bridge.QBox_GetPlayerMoney(targetSrc, fwType)), targetSrc, fwType
        end
    elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetPlayerByIdentifier then
        local xPlayer = Bridge.ESX_GetPlayerByIdentifier(citizenid)
        if xPlayer and xPlayer.source then
            local targetSrc = xPlayer.source
            return safeNum(Bridge.ESX_GetPlayerMoney(targetSrc, fwType)), targetSrc, fwType
        end
    end

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') then
        local bal = qbGetOfflineBalance(citizenid)
        if bal then
            local key = (fwType == 'crypto') and 'crypto' or fwType
            return safeNum(bal[key]), nil, fwType
        end
    end

    if Bridge and Bridge.Framework == 'esx' then
        if esxHasUserAccounts() then
            if fwType == 'cash' then
                local row = Database.Query("SELECT money FROM users WHERE identifier = ? LIMIT 1", { citizenid })
                return row and row[1] and safeNum(row[1].money) or 0, nil, fwType
            end
            local account = (fwType == 'black_money') and 'black_money' or fwType
            local row = Database.Query("SELECT money FROM user_accounts WHERE identifier = ? AND account_name = ? LIMIT 1", { citizenid, account })
            return row and row[1] and safeNum(row[1].money) or 0, nil, fwType
        end
        if esxHasAccountsColumn() then
            local data = esxOfflineGetAccounts(citizenid)
            if data then
                if fwType == 'cash' then
                    return safeNum(data.money), nil, fwType
                end
                return 0, nil, fwType
            end
        end
    end

    return 0, nil, fwType
end

function Admin.AddMoney(adminSrc, citizenid, moneyType, amount, reason)
    amount = math.floor(math.max(0, safeNum(amount)))
    local current, _, _ = Admin.GetCurrentMoney(citizenid, moneyType)
    local newVal = current + amount
    local ok, old, newAmount, targetSrc = Admin.SetMoney(adminSrc, citizenid, moneyType, newVal, reason)
    return ok, old, newAmount, targetSrc
end

function Admin.RemoveMoney(adminSrc, citizenid, moneyType, amount, reason)
    amount = math.floor(math.max(0, safeNum(amount)))
    local current, _, _ = Admin.GetCurrentMoney(citizenid, moneyType)
    local newVal = current - amount
    if newVal < 0 then newVal = 0 end
    local ok, old, newAmount, targetSrc = Admin.SetMoney(adminSrc, citizenid, moneyType, newVal, reason)
    return ok, old, newAmount, targetSrc
end

function Admin.BulkWipeDirtyOnline(adminSrc, reason)
    reason = tostring(reason or 'Bulk wipe dirty money')
    local wiped = 0

    local function wipeOne(targetSrc)
        if Bridge.Framework == 'qbcore' then
            local cur = Bridge.QBCore_GetPlayerMoney(targetSrc, 'crypto')
            if cur > 0 then
                Bridge.QBCore_RemoveMoney(targetSrc, 'crypto', cur, reason)
                wiped = wiped + 1
            end
        elseif Bridge.Framework == 'qbox' then
            local cur = Bridge.QBox_GetPlayerMoney(targetSrc, 'crypto')
            if cur > 0 then
                Bridge.QBox_RemoveMoney(targetSrc, 'crypto', cur, reason)
                wiped = wiped + 1
            end
        elseif Bridge.Framework == 'esx' then
            local cur = Bridge.ESX_GetPlayerMoney(targetSrc, 'black_money')
            if cur > 0 then
                Bridge.ESX_RemoveMoney(targetSrc, 'black_money', cur, reason)
                wiped = wiped + 1
            end
        end
    end

    for _, pid in ipairs(GetPlayers()) do
        wipeOne(tonumber(pid))
    end

    return wiped
end

function Admin.ExportAllPlayerBalances()
    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') then
        local chk = Database.Query("SHOW TABLES LIKE 'players'")
        if not chk or #chk == 0 then
            return {}
        end
        return Database.Query([[
            SELECT
                citizenid,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname,
                CAST(COALESCE(JSON_EXTRACT(money, '$.cash'), 0) AS SIGNED) AS cash,
                CAST(COALESCE(JSON_EXTRACT(money, '$.bank'), 0) AS SIGNED) AS bank,
                CAST(COALESCE(JSON_EXTRACT(money, '$.crypto'), 0) AS SIGNED) AS dirty
            FROM players
        ]])
    end

    if Bridge and Bridge.Framework == 'esx' then
        local chk = Database.Query("SHOW TABLES LIKE 'users'")
        if not chk or #chk == 0 then
            return {}
        end

        local hasAccounts = (Database.Query("SHOW COLUMNS FROM `users` LIKE 'accounts'") or {})
        local hasFirst = (Database.Query("SHOW COLUMNS FROM `users` LIKE 'firstname'") or {})
        local hasLast = (Database.Query("SHOW COLUMNS FROM `users` LIKE 'lastname'") or {})
        local hasName = (Database.Query("SHOW COLUMNS FROM `users` LIKE 'name'") or {})

        local cols = { "identifier AS citizenid", "money" }
        if #hasAccounts > 0 then cols[#cols + 1] = "accounts" end
        if #hasFirst > 0 then cols[#cols + 1] = "firstname" end
        if #hasLast > 0 then cols[#cols + 1] = "lastname" end
        if #hasName > 0 then cols[#cols + 1] = "name" end

        local rows = Database.Query(("SELECT %s FROM users"):format(table.concat(cols, ", ")))
        local out = {}
        for _, r in ipairs(rows or {}) do
            local cash, bank, dirty = 0, 0, 0
            if r.accounts then
                local ok, accounts = pcall(json.decode, r.accounts)
                if ok and accounts then
                    if accounts[1] and accounts[1].name then
                        for _, acc in ipairs(accounts) do
                            if acc.name == 'money' then cash = safeNum(acc.money)
                            elseif acc.name == 'bank' then bank = safeNum(acc.money)
                            elseif acc.name == 'black_money' then dirty = safeNum(acc.money) end
                        end
                    else
                        cash = safeNum(accounts.money)
                        bank = safeNum(accounts.bank)
                        dirty = safeNum(accounts.black_money)
                    end
                end
            else
                cash = safeNum(r.money)
            end

            out[#out + 1] = {
                citizenid = r.citizenid,
                firstname = r.firstname,
                lastname = r.lastname,
                name = r.name,
                cash = cash,
                bank = bank,
                dirty = dirty,
            }
        end
        return out
    end

    local rows = Database.Query([[
        SELECT citizenid, player_name AS name, peak_wealth AS cash
        FROM economy_player_profiles
        ORDER BY last_transaction DESC
        LIMIT 1000
    ]])
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { citizenid = r.citizenid, name = r.name, cash = safeNum(r.cash), bank = 0, dirty = 0 }
    end
    return out
end

