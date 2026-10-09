local RESOURCE = GetCurrentResourceName()

local function dbg(msg)
    if Config.Debug then
        print(('[Economy Dashboard] %s'):format(msg))
    end
end

local function frameworkLabel()
    local fw = Bridge and Bridge.Framework or 'unknown'
    if fw == 'qbcore' then return 'QBCore' end
    if fw == 'qbox' then return 'QBox' end
    if fw == 'esx' then return 'ESX' end
    if fw == 'standalone' then return 'Standalone' end
    return 'Unknown'
end

local function getIdentifiers(src)
    local ids = {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        ids[#ids + 1] = tostring(id)
    end
    return ids
end

local function splitIdentifier(id)
    id = tostring(id or '')
    local t, v = id:match('^([^:]+):(.*)$')
    if not t then return nil, nil end
    return t:lower(), v
end

local function isStandaloneWhitelisted(src)
    local allow = Config.AdminPermissions and Config.AdminPermissions.standalone
    if type(allow) ~= 'table' then return false end

    local ids = getIdentifiers(src)
    local parsedIds = {}
    for _, id in ipairs(ids) do
        local t, v = splitIdentifier(id)
        if t and v then
            parsedIds[#parsedIds + 1] = { t = t, v = v, raw = id }
        end
    end

    for _, allowed in ipairs(allow) do
        allowed = tostring(allowed or ''):lower():gsub('%s+', '')
        if allowed ~= '' then
            for _, id in ipairs(ids) do
                if id:lower() == allowed then return true end
            end

            if not allowed:find(':', 1, true) then
                for _, p in ipairs(parsedIds) do
                    if tostring(p.v):lower() == allowed then return true end
                end
            else
                local at, av = splitIdentifier(allowed)
                if at and av and (at == 'license' or at == 'license2') then
                    for _, p in ipairs(parsedIds) do
                        if (p.t == 'license' or p.t == 'license2') and tostring(p.v):lower() == tostring(av):lower() then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function notify(src, message, msgType)
    TriggerClientEvent('economy_dashboard:notify', src, message, msgType or 'info')
end

local function hasAccess(src)
    if Config.AdminPermissions and Config.AdminPermissions.acePermission then
        if IsPlayerAceAllowed(src, Config.AdminPermissions.acePermission) then
            return true
        end
    end

    if isStandaloneWhitelisted(src) then
        return true
    end

    if Bridge then
        if Bridge.QBCore_HasPermission and Bridge.QBCore_HasPermission(src) then return true end
        if Bridge.QBox_HasPermission and Bridge.QBox_HasPermission(src) then return true end
        if Bridge.ESX_HasPermission and Bridge.ESX_HasPermission(src) then return true end
        if Bridge.Standalone_HasPermission and Bridge.Standalone_HasPermission(src) then return true end
    end

    return false
end

local function send(src, msg)
    TriggerClientEvent('economy_dashboard:nuiMessage', src, msg)
end

local function sendAction(src, action, data)
    send(src, { action = action, data = data })
end

local function getServerTotals()
    local totals
    if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetServerTotals then
        totals = Bridge.QBCore_GetServerTotals()
    elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetServerTotals then
        totals = Bridge.QBox_GetServerTotals()
    elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetServerTotals then
        totals = Bridge.ESX_GetServerTotals()
    elseif Bridge and Bridge.Framework == 'standalone' and Bridge.Standalone_GetServerTotals then
        totals = Bridge.Standalone_GetServerTotals()
    end

    totals = totals or { cash = 0, bank = 0, dirty = 0, crypto = 0, totalPlayers = 0 }

    if not Config.TrackCash then totals.cash = 0 end
    if not Config.TrackBank then totals.bank = 0 end
    if not Config.TrackDirty then totals.dirty = 0 end
    if not Config.TrackCrypto then totals.crypto = 0 end

    totals.onlinePlayers = #GetPlayers()
    totals.totalWealth = (tonumber(totals.cash) or 0) + (tonumber(totals.bank) or 0) + (tonumber(totals.dirty) or 0) + (tonumber(totals.crypto) or 0)
    return totals
end

local function getCurrentBalance(citizenid)
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        if Bridge and Bridge.Framework == 'qbcore' and Bridge.QBCore_GetIdentifier then
            if Bridge.QBCore_GetIdentifier(src) == citizenid then
                local money = Bridge.QBCore_GetAllPlayerMoney(src)
                return { online = true, cash = money.cash or 0, bank = money.bank or 0, dirty = money.dirty or 0, crypto = money.crypto or 0 }
            end
        elseif Bridge and Bridge.Framework == 'qbox' and Bridge.QBox_GetIdentifier then
            if Bridge.QBox_GetIdentifier(src) == citizenid then
                local money = Bridge.QBox_GetAllPlayerMoney(src)
                return { online = true, cash = money.cash or 0, bank = money.bank or 0, dirty = money.dirty or 0, crypto = money.crypto or 0 }
            end
        elseif Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetIdentifier then
            if Bridge.ESX_GetIdentifier(src) == citizenid then
                local money = Bridge.ESX_GetAllPlayerMoney(src)
                return { online = true, cash = money.cash or 0, bank = money.bank or 0, dirty = money.dirty or 0, crypto = money.crypto or 0 }
            end
        end
    end

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') then
        local rows = Database.Query([[
            SELECT
                CAST(COALESCE(JSON_EXTRACT(money, '$.cash'), 0) AS SIGNED) AS cash,
                CAST(COALESCE(JSON_EXTRACT(money, '$.bank'), 0) AS SIGNED) AS bank,
                CAST(COALESCE(JSON_EXTRACT(money, '$.crypto'), 0) AS SIGNED) AS dirty
            FROM players
            WHERE citizenid = ?
            LIMIT 1
        ]], { citizenid })
        if rows and rows[1] then
            return {
                online = false,
                cash = tonumber(rows[1].cash) or 0,
                bank = tonumber(rows[1].bank) or 0,
                dirty = tonumber(rows[1].dirty) or 0,
                crypto = 0,
            }
        end
    end

    if Bridge and Bridge.Framework == 'esx' then
        if Database and Database.TableExists and Database.TableExists('users') then
            local hasAccounts = Database.ColumnExists and Database.ColumnExists('users', 'accounts')
            local hasMoney = Database.ColumnExists and Database.ColumnExists('users', 'money')

            local selectCols = {}
            if hasAccounts then selectCols[#selectCols + 1] = "accounts" end
            if hasMoney then selectCols[#selectCols + 1] = "money" end

            if #selectCols > 0 then
                local rows = Database.Query(("SELECT %s FROM users WHERE identifier = ? LIMIT 1"):format(table.concat(selectCols, ", ")), { citizenid })
                if rows and rows[1] then
                    local cash = hasMoney and (tonumber(rows[1].money) or 0) or 0
                    local bank, dirty = 0, 0

                    if hasAccounts and rows[1].accounts then
                        local ok, accounts = pcall(json.decode, rows[1].accounts)
                        if ok and accounts then
                            if accounts[1] and accounts[1].name then
                                for _, acc in ipairs(accounts) do
                                    if acc.name == 'money' and not hasMoney then cash = tonumber(acc.money) or cash end
                                    if acc.name == 'bank' then bank = tonumber(acc.money) or 0 end
                                    if acc.name == 'black_money' then dirty = tonumber(acc.money) or 0 end
                                end
                            else
                                if not hasMoney then cash = tonumber(accounts.money) or cash end
                                bank = tonumber(accounts.bank) or 0
                                dirty = tonumber(accounts.black_money) or 0
                            end
                        end
                    end

                    return { online = false, cash = cash, bank = bank, dirty = dirty, crypto = 0 }
                end
            end

            if Database.TableExists('user_accounts') then
                local bankRow = Database.Query("SELECT money FROM user_accounts WHERE identifier = ? AND account_name = 'bank' LIMIT 1", { citizenid })
                local dirtyRow = Database.Query("SELECT money FROM user_accounts WHERE identifier = ? AND account_name = 'black_money' LIMIT 1", { citizenid })

                local bank = bankRow and bankRow[1] and tonumber(bankRow[1].money) or 0
                local dirty = dirtyRow and dirtyRow[1] and tonumber(dirtyRow[1].money) or 0

                local cash = 0
                if hasMoney then
                    local cashRow = Database.Query("SELECT money FROM users WHERE identifier = ? LIMIT 1", { citizenid })
                    cash = cashRow and cashRow[1] and tonumber(cashRow[1].money) or 0
                end

                return { online = false, cash = cash, bank = bank, dirty = dirty, crypto = 0 }
            end
        end
    end

    return nil
end

local function buildOverview()
    local totals = getServerTotals()
    local today = Database.GetTodayFlow()
    local snapshots = Database.GetSnapshotsFromTransactions(30)

    local players, wealthValues = Analytics.GetWealthList()
    local wealthBrackets = Analytics.ComputeWealthBrackets(wealthValues)

    local comp = Database.GetFlowComparison(7)
    local gini = Analytics.ComputeGini(wealthValues)

    local flowRatio = (comp.faucets.current > 0) and (comp.sinks.current / comp.faucets.current) or 0
    local flowScore = (flowRatio >= 0.8 and flowRatio <= 1.1) and 90 or (flowRatio >= 0.6 and flowRatio <= 1.3) and 70 or 45
    local giniScore = (gini < 0.35) and 90 or (gini < 0.45) and 70 or (gini < 0.55) and 55 or 35
    local velocity = today.txCount or 0
    local velocityScore = (velocity > 500) and 90 or (velocity > 200) and 75 or (velocity > 50) and 55 or 35
    local activityRatio = (totals.totalPlayers and totals.totalPlayers > 0) and (totals.onlinePlayers / totals.totalPlayers) or 0
    local activityScore = (activityRatio >= 0.25) and 85 or (activityRatio >= 0.10) and 65 or 40

    local score = math.floor((flowScore + giniScore + velocityScore + activityScore) / 4)
    local status = (score >= 80) and 'excellent' or (score >= 65) and 'good' or (score >= 45) and 'fair' or 'poor'

    local newAlerts = Database.GetAlerts('new', 200) or {}

    return {
        serverName = frameworkLabel(),
        totals = totals,
        today = today,
        snapshots = snapshots,
        wealthBrackets = wealthBrackets,
        economyScore = {
            score = score,
            status = status,
            breakdown = {
                flow = flowScore,
                gini = giniScore,
                velocity = velocityScore,
                activity = activityScore,
            }
        },
        timeComparison = comp,
        alerts = newAlerts,
    }
end

local function buildInflation()
    local mode = Config.InflationMode or 'both'
    if mode == 'disabled' then
        return { inflationMode = 'disabled', inflation = { cpi = 100, rate = 0, items = {} }, recentPriceChanges = {} }
    end

    local basket = Config.InflationBasket or {}
    local items = {}
    local sumIndex = 0
    local count = 0

    for _, b in ipairs(basket) do
        local name = b.item
        local base = tonumber(b.basePrice) or 1
        if base <= 0 then base = 1 end

        local current = Database.GetLatestPrice(name) or base
        local idx = (current / base) * 100
        sumIndex = sumIndex + idx
        count = count + 1

        items[#items + 1] = {
            name = name,
            basePrice = base,
            currentPrice = current,
            change = ((current - base) / base) * 100,
        }
    end

    local cpi = (count > 0) and (sumIndex / count) or 100
    local rate = 0
    local snap = Database.Query([[
        SELECT cpi_value
        FROM economy_inflation_snapshots
        ORDER BY snapshot_date DESC
        LIMIT 2
    ]])
    if snap and #snap >= 2 then
        local latest = tonumber(snap[1].cpi_value) or cpi
        local prev = tonumber(snap[2].cpi_value) or latest
        if prev ~= 0 then
            rate = ((latest - prev) / prev) * 100
        end
        cpi = latest
    end

    return {
        inflationMode = mode,
        inflation = {
            cpi = cpi,
            rate = rate,
            items = items,
        },
        recentPriceChanges = Database.GetRecentPriceChanges(10) or {},
    }
end

local function buildAnalytics()
    local _, wealthValues = Analytics.GetWealthList()
    local gini = Analytics.ComputeGini(wealthValues)
    local dist = Analytics.ComputeWealthPercentiles(wealthValues)

    local topEarners = Database.Query([[
        SELECT citizenid, player_name AS name, total_earned
        FROM economy_player_profiles
        ORDER BY total_earned DESC
        LIMIT 10
    ]]) or {}

    local topSpenders = Database.Query([[
        SELECT citizenid, player_name AS name, total_spent
        FROM economy_player_profiles
        ORDER BY total_spent DESC
        LIMIT 10
    ]]) or {}

    local inflation = buildInflation()

    return {
        gini = gini,
        wealthDistribution = dist,
        wealthBrackets = Analytics.ComputeWealthBrackets(wealthValues),
        topRichest = Analytics.GetTopRichest(10),
        topEarners = topEarners,
        topSpenders = topSpenders,
        inflation = inflation.inflation,
        inflationMode = inflation.inflationMode,
        recentPriceChanges = inflation.recentPriceChanges,
    }
end

local function refreshTab(src, tab, payload)
    tab = tostring(tab or 'overview')
    payload = payload or {}

    if tab == 'overview' then
        sendAction(src, 'updateDashboard', buildOverview())
        return
    end

    if tab == 'faucets' then
        local top = Database.GetCategoryTable('faucet', payload.startDate, payload.endDate, payload.category)
        sendAction(src, 'updateFaucets', { categories = Database.GetDistinctCategories('faucet'), topFaucets = top })
        return
    end

    if tab == 'sinks' then
        local top = Database.GetCategoryTable('sink', payload.startDate, payload.endDate, payload.category)
        sendAction(src, 'updateSinks', { categories = Database.GetDistinctCategories('sink'), topSinks = top })
        return
    end

    if tab == 'analytics' then
        sendAction(src, 'updateAnalytics', buildAnalytics())
        return
    end

    if tab == 'alerts' then
        local status = tostring(payload.status or 'new')
        local alerts = Database.GetAlerts(status, 100) or {}
        sendAction(src, 'updateAlerts', { alerts = alerts })
        sendAction(src, 'updateAlertCounts', Database.GetAlertCounts())
        return
    end

    if tab == 'admin' then
        send(src, { action = 'updateAuditLog', data = Database.GetAuditLog(100) or {} })
        return
    end
end

RegisterCommand(Config.OpenCommand or 'economydash', function(src)
    if src == 0 then
        print('[Economy Dashboard] /economydash is player-only')
        return
    end
    if not hasAccess(src) then
        notify(src, 'Economy Dashboard: akses ditolak (bukan admin).', 'error')
        if Config.Debug then
            dbg(('Denied command open for %s (%s)'):format(src, frameworkLabel()))
            dbg(('Identifiers: %s'):format(table.concat(getIdentifiers(src), ', ')))
        end
        return
    end
    TriggerClientEvent('economy_dashboard:clientOpen', src, 'overview')
end, false)

RegisterNetEvent('economy_dashboard:requestOpen', function(tab)
    local src = source
    if not hasAccess(src) then
        notify(src, 'Economy Dashboard: akses ditolak. Ketik /ecowhoami untuk melihat identifier/grup-mu.', 'error')
        if Config.Debug then
            dbg(('Denied open for %s (%s)'):format(src, frameworkLabel()))
            dbg(('Identifiers: %s'):format(table.concat(getIdentifiers(src), ', ')))
        end
        return
    end
    TriggerClientEvent('economy_dashboard:clientOpen', src, tab or 'overview')
end)

RegisterCommand('ecowhoami', function(src)
    if src == 0 then
        print('[Economy Dashboard] /ecowhoami is player-only')
        return
    end

    local ids = getIdentifiers(src)
    notify(src, ('Framework: %s'):format(frameworkLabel()), 'info')
    notify(src, ('Ace "%s": %s'):format(
        tostring(Config.AdminPermissions and Config.AdminPermissions.acePermission or 'economy.dashboard'),
        (Config.AdminPermissions and Config.AdminPermissions.acePermission and IsPlayerAceAllowed(src, Config.AdminPermissions.acePermission)) and 'ALLOWED' or 'NO'
    ), 'info')
    notify(src, ('Standalone allowlist match: %s'):format(isStandaloneWhitelisted(src) and 'YES' or 'NO'), 'info')
    notify(src, ('Identifiers: %s'):format(table.concat(ids, ', ')), 'info')

    if Bridge and Bridge.Framework == 'esx' and Bridge.ESX_GetPlayerName and Bridge.ESX_GetIdentifier then
        local ok, group = pcall(function()
            local ESX = Bridge.FrameworkObject
            local xPlayer = ESX and ESX.GetPlayerFromId(src) or nil
            return xPlayer and xPlayer.getGroup and xPlayer.getGroup() or nil
        end)
        if ok and group then
            notify(src, ('ESX group: %s'):format(tostring(group)), 'info')
        end
    end

    if Bridge and Bridge.Framework == 'qbcore' and Bridge.FrameworkObject then
        local ok, perm = pcall(function()
            local QBCore = Bridge.FrameworkObject
            return QBCore.Functions.GetPermission(src)
        end)
        if ok and perm then
            notify(src, ('QBCore permission: %s'):format(tostring(perm)), 'info')
        end
    end
end, false)

RegisterNetEvent('economy_dashboard:refreshData', function(tab, payload)
    local src = source
    if not hasAccess(src) then return end
    refreshTab(src, tab, payload)
end)

RegisterNetEvent('economy_dashboard:uiClosed', function()
end)

RegisterNetEvent('economy_dashboard:nui', function(endpoint, data)
    local src = source
    if not hasAccess(src) then return end
    endpoint = tostring(endpoint or '')
    data = data or {}

    if endpoint == 'searchPlayers' then
        local q = tostring(data.query or '')
        local players = Database.SearchPlayersUniversal(q, 25) or {}
        sendAction(src, 'updatePlayerSearch', { players = players })
        return
    end

    if endpoint == 'getPlayerProfile' then
        local citizenid = tostring(data.citizenid or '')
        if citizenid == '' then return end
        local profile = Database.GetPlayerProfile(citizenid)
        if not profile then
            local name = Database.GetFrameworkPlayerName(citizenid)
            local totals = Database.GetPlayerTotalsFromTransactions(citizenid)
            profile = {
                citizenid = citizenid,
                player_name = name or citizenid,
                total_earned = totals.total_earned or 0,
                total_spent = totals.total_spent or 0,
                total_received = 0,
                total_sent = 0,
                primary_income_source = nil,
                primary_expense_sink = nil,
                peak_wealth = 0,
                peak_wealth_date = nil,
                first_seen = nil,
                last_transaction = totals.last_transaction,
                transaction_count = totals.transaction_count or 0,
                flag_status = 'none',
                flag_reason = nil,
                flag_date = nil,
                notes = nil,
                updated_at = nil,
            }

            Database.EnsureProfileExists(citizenid, name)
        end
        local txs = Database.GetPlayerTransactions(citizenid, 25) or {}
        local current = getCurrentBalance(citizenid)
        sendAction(src, 'updatePlayerProfile', { profile = profile, transactions = txs, currentBalance = current })
        return
    end

    if endpoint == 'updateAlertStatus' then
        local alertId = tonumber(data.alertId)
        local status = tostring(data.status or '')
        if not alertId or status == '' then return end
        Database.UpdateAlertStatus(alertId, status, Admin.GetAdminIdentifier(src))
        send(src, { action = 'alertStatusUpdated' })
        sendAction(src, 'updateAlertCounts', Database.GetAlertCounts())
        return
    end

    if endpoint == 'adminSearchPlayers' then
        local q = tostring(data.query or '')
        local players = Database.SearchPlayersUniversal(q, 25) or {}
        sendAction(src, 'updateAdminSearch', { players = players })
        return
    end

    if endpoint == 'adminAddMoney' or endpoint == 'adminRemoveMoney' or endpoint == 'adminSetMoney' then
        local citizenid = tostring(data.citizenid or '')
        local moneyType = tostring(data.moneyType or 'cash')
        local amount = tonumber(data.amount) or 0
        local reason = tostring(data.reason or 'Economy Dashboard')
        if citizenid == '' or amount <= 0 then
            send(src, { action = 'adminResult', success = false, message = 'Missing Citizen ID or Amount' })
            return
        end

        local ok, oldVal, newVal
        if endpoint == 'adminAddMoney' then
            ok, oldVal, newVal = Admin.AddMoney(src, citizenid, moneyType, amount, reason)
        elseif endpoint == 'adminRemoveMoney' then
            ok, oldVal, newVal = Admin.RemoveMoney(src, citizenid, moneyType, amount, reason)
        else
            ok, oldVal, newVal = Admin.SetMoney(src, citizenid, moneyType, amount, reason)
        end

        if ok then
            if Tracking and oldVal ~= nil and newVal ~= nil then
                local delta = (tonumber(newVal) or 0) - (tonumber(oldVal) or 0)
                if delta > 0 then
                    Tracking.LogTransaction({
                        type = 'faucet',
                        amount = delta,
                        moneyType = Admin.NormalizeMoneyTypeUI(moneyType),
                        playerTo = citizenid,
                        category = 'admin',
                        subcategory = endpoint,
                        reason = reason,
                    })
                elseif delta < 0 then
                    Tracking.LogTransaction({
                        type = 'sink',
                        amount = math.abs(delta),
                        moneyType = Admin.NormalizeMoneyTypeUI(moneyType),
                        playerFrom = citizenid,
                        category = 'admin',
                        subcategory = endpoint,
                        reason = reason,
                    })
                end
            end

            Database.InsertAdminLog({
                admin_id = Admin.GetAdminIdentifier(src),
                admin_name = Admin.GetAdminName(src),
                action = endpoint,
                target_player = citizenid,
                target_name = nil,
                money_type = Admin.NormalizeMoneyTypeUI(moneyType),
                amount = amount,
                old_value = oldVal,
                new_value = newVal,
                reason = reason,
            })

            if Config.Discord and Config.Discord.enabled then
                Discord.Send('admin', 'Admin Money Action', ('%s changed %s for %s: %s → %s (reason: %s)'):format(
                    Admin.GetAdminName(src),
                    Admin.NormalizeMoneyTypeUI(moneyType),
                    citizenid,
                    tostring(oldVal),
                    tostring(newVal),
                    reason
                ), 0xffb800)
            end

            send(src, { action = 'adminResult', success = true, message = 'Money updated successfully' })
            send(src, { action = 'updateAuditLog', data = Database.GetAuditLog(100) or {} })
        else
            send(src, { action = 'adminResult', success = false, message = 'Failed to update money (player/table not found?)' })
        end
        return
    end

    if endpoint == 'adminBulkWipeDirty' then
        local wiped = Admin.BulkWipeDirtyOnline(src, tostring(data.reason or 'Bulk wipe dirty'))
        Database.InsertAdminLog({
            admin_id = Admin.GetAdminIdentifier(src),
            admin_name = Admin.GetAdminName(src),
            action = 'adminBulkWipeDirty',
            target_player = nil,
            target_name = nil,
            money_type = 'dirty',
            amount = wiped,
            old_value = nil,
            new_value = nil,
            reason = tostring(data.reason or 'Bulk wipe dirty'),
        })
        send(src, { action = 'adminResult', success = true, message = ('Wiped dirty money for %d online players'):format(wiped) })
        send(src, { action = 'updateAuditLog', data = Database.GetAuditLog(100) or {} })
        return
    end

    if endpoint == 'exportData' then
        local rows = Admin.ExportAllPlayerBalances()
        send(src, { action = 'exportComplete', data = rows })
        return
    end

    if endpoint == 'testDiscordWebhook' then
        local kind = tostring(data.webhookType or 'alert')
        local ok = Discord.Test(kind)
        send(src, { action = 'adminResult', success = ok, message = ok and 'Webhook test sent' or 'Webhook disabled/not configured' })
        return
    end

    if endpoint == 'getInflationBasket' then
        sendAction(src, 'updateInflationBasket', Config.InflationBasket or {})
        return
    end

    if endpoint == 'logPrices' then
        local prices = data.prices or {}
        if Config.InflationMode == 'automatic' then
            send(src, { action = 'pricesLogged', success = false, message = 'Manual price updates disabled (automatic mode)' })
            return
        end

        local loggedBy = Admin.GetAdminIdentifier(src)
        local inserted = 0
        for _, p in ipairs(prices) do
            local name = tostring(p.name or '')
            local price = tonumber(p.price) or 0
            if name ~= '' and price >= 0 then
                Database.InsertPrice(name, math.floor(price), loggedBy, 'manual')
                inserted = inserted + 1
            end
        end

        send(src, { action = 'pricesLogged', success = inserted > 0, message = inserted > 0 and ('Logged %d prices'):format(inserted) or 'No prices logged' })
        return
    end
end)

RegisterCommand('ecodebug', function(src, args)
    local sub = tostring(args[1] or ''):lower()
    if src ~= 0 and not hasAccess(src) then return end

    if sub == 'totals' then
        local t = getServerTotals()
        print(('[Economy Dashboard] Totals: cash=%s bank=%s dirty=%s crypto=%s players=%s online=%s'):format(
            t.cash, t.bank, t.dirty, t.crypto, t.totalPlayers, t.onlinePlayers
        ))
    elseif sub == 'today' then
        local d = Database.GetTodayFlow()
        print(('[Economy Dashboard] Today: faucets=%s sinks=%s net=%s tx=%s'):format(d.faucets, d.sinks, d.netFlow, d.txCount))
    elseif sub == 'test' then
        if Tracking then
            Tracking.LogTransaction({ type = 'faucet', amount = 12345, moneyType = 'cash', playerTo = 'test', category = 'jobs', reason = 'ecodebug test' })
            Tracking.Flush()
            print('[Economy Dashboard] Inserted test transaction.')
        end
    else
        print('[Economy Dashboard] Usage: ecodebug totals | today | test')
    end
end, true)

CreateThread(function()
    Wait(3000)
    print(('[Economy Dashboard] Loaded. Framework: %s'):format(frameworkLabel()))
end)

