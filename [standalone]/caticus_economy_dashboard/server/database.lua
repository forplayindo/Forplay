Database = Database or {}

local _cache = {
    tables = {},
    columns = {},
}

local function cacheKey(a, b)
    return tostring(a) .. '::' .. tostring(b)
end

local function hasAwait()
    return MySQL
        and MySQL.query and MySQL.query.await
        and MySQL.insert and MySQL.insert.await
        and MySQL.update and MySQL.update.await
end

local function ensureOx()
    if not hasAwait() then
        error('[Economy Dashboard] oxmysql not loaded (MySQL.*.await missing). Ensure oxmysql is started before this resource.')
    end
end

function Database.Query(sql, params)
    ensureOx()
    return MySQL.query.await(sql, params or {})
end

function Database.Scalar(sql, params)
    ensureOx()
    if MySQL.scalar and MySQL.scalar.await then
        return MySQL.scalar.await(sql, params or {})
    end

    local rows = MySQL.query.await(sql, params or {})
    local row = rows and rows[1]
    if not row then return nil end
    for _, v in pairs(row) do
        return v
    end
    return nil
end

function Database.Insert(sql, params)
    ensureOx()
    return MySQL.insert.await(sql, params or {})
end

function Database.Update(sql, params)
    ensureOx()
    return MySQL.update.await(sql, params or {})
end

function Database.NowUtc()
    return os.date('!%Y-%m-%d %H:%M:%S')
end

function Database.TableExists(name)
    name = tostring(name or '')
    if name == '' then return false end
    if _cache.tables[name] ~= nil then
        return _cache.tables[name]
    end
    local rows = Database.Query("SHOW TABLES LIKE ?", { name })
    local ok = rows and #rows > 0
    _cache.tables[name] = ok
    return ok
end

function Database.ColumnExists(tableName, columnName)
    tableName = tostring(tableName or '')
    columnName = tostring(columnName or '')
    if tableName == '' or columnName == '' then return false end

    local key = cacheKey(tableName, columnName)
    if _cache.columns[key] ~= nil then
        return _cache.columns[key]
    end

    local rows = Database.Query(("SHOW COLUMNS FROM `%s` LIKE ?"):format(tableName), { columnName })
    local ok = rows and #rows > 0
    _cache.columns[key] = ok
    return ok
end

function Database.InsertTransaction(row)
    ensureOx()
    return MySQL.insert.await([[
        INSERT INTO economy_transactions
            (transaction_type, category, subcategory, amount, player_from, player_to, money_type, balance_after, reason, metadata, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        row.transaction_type,
        row.category,
        row.subcategory,
        row.amount,
        row.player_from,
        row.player_to,
        row.money_type or 'cash',
        row.balance_after,
        row.reason,
        row.metadata and json.encode(row.metadata) or nil,
    })
end

---One round trip for the whole flushed batch instead of one INSERT per queued transaction.
function Database.InsertTransactionsBatch(rows)
    if not rows or #rows == 0 then return end

    local values, params = {}, {}
    for i = 1, #rows do
        local row = rows[i]
        values[i] = '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
        params[#params + 1] = row.transaction_type
        params[#params + 1] = row.category
        params[#params + 1] = row.subcategory
        params[#params + 1] = row.amount
        params[#params + 1] = row.player_from
        params[#params + 1] = row.player_to
        params[#params + 1] = row.money_type or 'cash'
        params[#params + 1] = row.balance_after
        params[#params + 1] = row.reason
        params[#params + 1] = row.metadata and json.encode(row.metadata) or nil
    end

    return Database.Insert(([[
        INSERT INTO economy_transactions
            (transaction_type, category, subcategory, amount, player_from, player_to, money_type, balance_after, reason, metadata, created_at)
        VALUES
            %s
    ]]):format(table.concat(values, ', ')), params)
end

---One round trip for every distinct citizenid in the flushed batch instead of one
---UpsertProfileDelta call per queued transaction (deltas for the same player are summed first).
function Database.UpsertProfileDeltasBatch(deltasByCitizenid)
    local citizenids = {}
    for citizenid in pairs(deltasByCitizenid or {}) do
        citizenids[#citizenids + 1] = citizenid
    end
    if #citizenids == 0 then return end

    local values, params = {}, {}
    for i = 1, #citizenids do
        local citizenid = citizenids[i]
        local delta = deltasByCitizenid[citizenid]
        local playerName = delta.player_name
        if playerName and tostring(playerName):gsub('%s+', '') == '' then
            playerName = nil
        end

        values[i] = '(?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)'
        params[#params + 1] = citizenid
        params[#params + 1] = playerName
        params[#params + 1] = tonumber(delta.total_earned) or 0
        params[#params + 1] = tonumber(delta.total_spent) or 0
        params[#params + 1] = tonumber(delta.total_received) or 0
        params[#params + 1] = tonumber(delta.total_sent) or 0
        params[#params + 1] = tonumber(delta.peak_wealth) or 0
    end

    return Database.Insert(([[
        INSERT INTO economy_player_profiles
            (citizenid, player_name, total_earned, total_spent, total_received, total_sent, peak_wealth, first_seen, last_transaction, transaction_count)
        VALUES
            %s
        ON DUPLICATE KEY UPDATE
            player_name = COALESCE(VALUES(player_name), player_name),
            total_earned = total_earned + VALUES(total_earned),
            total_spent = total_spent + VALUES(total_spent),
            total_received = total_received + VALUES(total_received),
            total_sent = total_sent + VALUES(total_sent),
            peak_wealth = GREATEST(peak_wealth, VALUES(peak_wealth)),
            last_transaction = NOW(),
            transaction_count = transaction_count + 1
    ]]):format(table.concat(values, ', ')), params)
end

function Database.GetTodayFlow()
    local res = Database.Query([[
        SELECT
            SUM(CASE WHEN transaction_type = 'faucet' THEN amount ELSE 0 END) AS faucets,
            SUM(CASE WHEN transaction_type = 'sink' THEN amount ELSE 0 END) AS sinks,
            COUNT(*) AS tx_count
        FROM economy_transactions
        WHERE DATE(created_at) = CURDATE()
    ]])

    local r = res and res[1] or {}
    local faucets = tonumber(r.faucets) or 0
    local sinks = tonumber(r.sinks) or 0

    return {
        faucets = faucets,
        sinks = sinks,
        netFlow = faucets - sinks,
        txCount = tonumber(r.tx_count) or 0,
    }
end

function Database.GetFlowComparison(days)
    days = tonumber(days) or 7
    if days < 1 then days = 7 end

    local res = Database.Query([[
        SELECT
            SUM(CASE WHEN transaction_type = 'faucet' THEN amount ELSE 0 END) AS faucets,
            SUM(CASE WHEN transaction_type = 'sink' THEN amount ELSE 0 END) AS sinks
        FROM economy_transactions
        WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
          AND created_at < CURDATE()
    ]], { days })
    local cur = res and res[1] or {}

    local resPrev = Database.Query([[
        SELECT
            SUM(CASE WHEN transaction_type = 'faucet' THEN amount ELSE 0 END) AS faucets,
            SUM(CASE WHEN transaction_type = 'sink' THEN amount ELSE 0 END) AS sinks
        FROM economy_transactions
        WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
          AND created_at < DATE_SUB(CURDATE(), INTERVAL ? DAY)
    ]], { days * 2, days })
    local prev = resPrev and resPrev[1] or {}

    local function pctChange(a, b)
        a = tonumber(a) or 0
        b = tonumber(b) or 0
        if b == 0 then
            return (a == 0) and 0 or 100
        end
        return ((a - b) / b) * 100
    end

    return {
        faucets = {
            current = tonumber(cur.faucets) or 0,
            previous = tonumber(prev.faucets) or 0,
            change = pctChange(cur.faucets, prev.faucets),
        },
        sinks = {
            current = tonumber(cur.sinks) or 0,
            previous = tonumber(prev.sinks) or 0,
            change = pctChange(cur.sinks, prev.sinks),
        },
    }
end

function Database.GetSnapshotsFromTransactions(days)
    days = tonumber(days) or 30
    if days < 1 then days = 30 end

    return Database.Query([[
        SELECT
            DATE(created_at) AS snapshot_date,
            SUM(CASE WHEN transaction_type = 'faucet' THEN amount ELSE 0 END) AS total_faucets,
            SUM(CASE WHEN transaction_type = 'sink' THEN amount ELSE 0 END) AS total_sinks
        FROM economy_transactions
        WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
        GROUP BY DATE(created_at)
        ORDER BY snapshot_date ASC
    ]], { days })
end

function Database.GetCategoryTable(transactionType, startDate, endDate, category)
    local where = { "transaction_type = ?" }
    local params = { transactionType }

    if startDate and startDate ~= '' then
        table.insert(where, "DATE(created_at) >= ?")
        table.insert(params, startDate)
    end
    if endDate and endDate ~= '' then
        table.insert(where, "DATE(created_at) <= ?")
        table.insert(params, endDate)
    end
    if category and category ~= '' then
        table.insert(where, "category = ?")
        table.insert(params, category)
    end

    local sql = ([[
        SELECT
            category,
            subcategory,
            SUM(amount) AS total_amount,
            COUNT(*) AS transaction_count,
            AVG(amount) AS avg_amount
        FROM economy_transactions
        WHERE %s
        GROUP BY category, subcategory
        ORDER BY total_amount DESC
        LIMIT 100
    ]]):format(table.concat(where, " AND "))

    return Database.Query(sql, params)
end

function Database.GetDistinctCategories(transactionType)
    local rows = Database.Query([[
        SELECT DISTINCT category
        FROM economy_transactions
        WHERE transaction_type = ?
        ORDER BY category ASC
    ]], { transactionType })

    local out = {}
    for _, r in ipairs(rows or {}) do
        if r.category and r.category ~= '' then
            out[#out + 1] = r.category
        end
    end
    return out
end

function Database.SearchPlayerProfiles(query, limit)
    limit = tonumber(limit) or 25
    if limit < 1 then limit = 25 end
    if limit > 100 then limit = 100 end

    query = tostring(query or ''):gsub('%%', '')
    local like = ('%%%s%%'):format(query)

    return Database.Query([[
        SELECT citizenid, player_name, total_earned, total_spent
        FROM economy_player_profiles
        WHERE citizenid LIKE ? OR player_name LIKE ?
        ORDER BY last_transaction DESC
        LIMIT ?
    ]], { like, like, limit })
end

function Database.GetPlayerProfile(citizenid)
    local rows = Database.Query([[
        SELECT *
        FROM economy_player_profiles
        WHERE citizenid = ?
        LIMIT 1
    ]], { citizenid })

    return rows and rows[1] or nil
end

function Database.GetPlayerTransactions(citizenid, limit)
    limit = tonumber(limit) or 25
    if limit < 1 then limit = 25 end
    if limit > 200 then limit = 200 end

    return Database.Query(([[
        SELECT id, transaction_type, category, subcategory, amount, money_type, reason, created_at
        FROM economy_transactions
        WHERE player_from = ? OR player_to = ?
        ORDER BY created_at DESC
        LIMIT %d
    ]]):format(limit), { citizenid, citizenid })
end

function Database.GetPlayerTotalsFromTransactions(citizenid)
    local rows = Database.Query([[
        SELECT
            SUM(CASE WHEN transaction_type = 'faucet' AND player_to = ? THEN amount ELSE 0 END) AS earned,
            SUM(CASE WHEN transaction_type = 'sink' AND player_from = ? THEN amount ELSE 0 END) AS spent,
            COUNT(*) AS tx_count,
            MAX(created_at) AS last_tx
        FROM economy_transactions
        WHERE player_from = ? OR player_to = ?
    ]], { citizenid, citizenid, citizenid, citizenid })

    local r = rows and rows[1] or {}
    return {
        total_earned = tonumber(r.earned) or 0,
        total_spent = tonumber(r.spent) or 0,
        transaction_count = tonumber(r.tx_count) or 0,
        last_transaction = r.last_tx,
    }
end

function Database.EnsureProfileExists(citizenid, playerName)
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return false end

    playerName = playerName and tostring(playerName) or nil
    if playerName and playerName:gsub('%s+', '') == '' then playerName = nil end

    Database.Insert([[
        INSERT INTO economy_player_profiles
            (citizenid, player_name, first_seen, last_transaction, transaction_count)
        VALUES
            (?, ?, NOW(), NULL, 0)
        ON DUPLICATE KEY UPDATE
            player_name = COALESCE(VALUES(player_name), player_name)
    ]], { citizenid, playerName })
    return true
end

local function normalizeQuery(q)
    q = tostring(q or '')
    q = q:gsub('%%', '')
    q = q:gsub('%s+', ' ')
    q = q:gsub('^%s+', ''):gsub('%s+$', '')
    return q
end

local function uniqPlayers(rows)
    local seen = {}
    local out = {}
    for _, r in ipairs(rows or {}) do
        local id = r.citizenid
        if id and id ~= '' and not seen[id] then
            seen[id] = true
            out[#out + 1] = r
        end
    end
    return out
end

function Database.SearchFrameworkPlayers(query, limit)
    limit = tonumber(limit) or 25
    if limit < 1 then limit = 25 end
    if limit > 100 then limit = 100 end

    query = normalizeQuery(query)
    if #query < 2 then return {} end
    local like = ('%%%s%%'):format(query)

    if Bridge and Bridge.Framework == 'esx' and Database.TableExists('users') then
        local cols = { "identifier AS citizenid" }
        local where = { "identifier LIKE ?" }
        local params = { like }

        if Database.ColumnExists('users', 'firstname') then
            cols[#cols + 1] = "firstname"
            where[#where + 1] = "firstname LIKE ?"
            params[#params + 1] = like
        end
        if Database.ColumnExists('users', 'lastname') then
            cols[#cols + 1] = "lastname"
            where[#where + 1] = "lastname LIKE ?"
            params[#params + 1] = like
        end
        if Database.ColumnExists('users', 'name') then
            cols[#cols + 1] = "name"
            where[#where + 1] = "name LIKE ?"
            params[#params + 1] = like
        end

        local nameExpr = nil
        if Database.ColumnExists('users', 'firstname') and Database.ColumnExists('users', 'lastname') then
            nameExpr = "TRIM(CONCAT(COALESCE(firstname,''),' ',COALESCE(lastname,'')))"
        elseif Database.ColumnExists('users', 'name') then
            nameExpr = "name"
        else
            nameExpr = "identifier"
        end

        local sql = (string.format([[
            SELECT
                u.identifier AS citizenid,
                %s AS player_name
            FROM users u
            WHERE (%s)
            LIMIT %d
        ]], nameExpr, table.concat(where, " OR "), limit))

        local rows = Database.Query(sql, params)

        local enriched = {}
        for _, r in ipairs(rows or {}) do
            enriched[#enriched + 1] = {
                citizenid = r.citizenid,
                player_name = r.player_name,
                total_earned = 0,
                total_spent = 0,
            }
        end

        if #enriched > 0 then
            local ids = {}
            local placeholders = {}
            for i, p in ipairs(enriched) do
                ids[i] = p.citizenid
                placeholders[i] = '?'
            end
            local prof = Database.Query(([[
                SELECT citizenid, player_name, total_earned, total_spent
                FROM economy_player_profiles
                WHERE citizenid IN (%s)
            ]]):format(table.concat(placeholders, ",")), ids)

            local map = {}
            for _, pr in ipairs(prof or {}) do
                map[pr.citizenid] = pr
            end
            for _, p in ipairs(enriched) do
                local pr = map[p.citizenid]
                if pr then
                    p.player_name = pr.player_name or p.player_name
                    p.total_earned = pr.total_earned or p.total_earned
                    p.total_spent = pr.total_spent or p.total_spent
                end
            end
        end

        return uniqPlayers(enriched)
    end

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') and Database.TableExists('players') then
        local sql = ([[
            SELECT
                citizenid,
                TRIM(CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')),''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')),'')
                )) AS player_name
            FROM players
            WHERE citizenid LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
            LIMIT %d
        ]]):format(limit)

        local rows = Database.Query(sql, { like, like, like })
        local out = {}
        for _, r in ipairs(rows or {}) do
            out[#out + 1] = {
                citizenid = r.citizenid,
                player_name = r.player_name,
                total_earned = 0,
                total_spent = 0,
            }
        end
        return uniqPlayers(out)
    end

    return {}
end

function Database.SearchPlayersUniversal(query, limit)
    local results = {}
    local q = normalizeQuery(query)
    if #q < 2 then return {} end

    local profiles = Database.SearchPlayerProfiles(q, limit) or {}
    for _, p in ipairs(profiles) do
        results[#results + 1] = p
    end

    local framework = Database.SearchFrameworkPlayers(q, limit) or {}
    for _, p in ipairs(framework) do
        results[#results + 1] = p
    end

    return uniqPlayers(results)
end

function Database.GetFrameworkPlayerName(citizenid)
    citizenid = tostring(citizenid or '')
    if citizenid == '' then return nil end

    if Bridge and Bridge.Framework == 'esx' and Database.TableExists('users') then
        local nameExpr
        if Database.ColumnExists('users', 'firstname') and Database.ColumnExists('users', 'lastname') then
            nameExpr = "TRIM(CONCAT(COALESCE(firstname,''),' ',COALESCE(lastname,'')))"
        elseif Database.ColumnExists('users', 'name') then
            nameExpr = "name"
        else
            nameExpr = "identifier"
        end
        local rows = Database.Query(("SELECT %s AS player_name FROM users WHERE identifier = ? LIMIT 1"):format(nameExpr), { citizenid })
        return rows and rows[1] and rows[1].player_name or nil
    end

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') and Database.TableExists('players') then
        local rows = Database.Query([[
            SELECT
                TRIM(CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')),''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')),'')
                )) AS player_name
            FROM players
            WHERE citizenid = ?
            LIMIT 1
        ]], { citizenid })
        return rows and rows[1] and rows[1].player_name or nil
    end

    return nil
end

function Database.UpsertProfileDelta(citizenid, delta)
    local playerName = delta.player_name
    if playerName and tostring(playerName):gsub('%s+', '') == '' then
        playerName = nil
    end

    return Database.Insert([[
        INSERT INTO economy_player_profiles
            (citizenid, player_name, total_earned, total_spent, total_received, total_sent, peak_wealth, first_seen, last_transaction, transaction_count)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, NOW(), NOW(), 1)
        ON DUPLICATE KEY UPDATE
            player_name = COALESCE(VALUES(player_name), player_name),
            total_earned = total_earned + VALUES(total_earned),
            total_spent = total_spent + VALUES(total_spent),
            total_received = total_received + VALUES(total_received),
            total_sent = total_sent + VALUES(total_sent),
            peak_wealth = GREATEST(peak_wealth, VALUES(peak_wealth)),
            last_transaction = NOW(),
            transaction_count = transaction_count + 1
    ]], {
        citizenid,
        playerName,
        tonumber(delta.total_earned) or 0,
        tonumber(delta.total_spent) or 0,
        tonumber(delta.total_received) or 0,
        tonumber(delta.total_sent) or 0,
        tonumber(delta.peak_wealth) or 0,
    })
end

function Database.GetAlerts(status, limit)
    limit = tonumber(limit) or 50
    if limit < 1 then limit = 50 end
    if limit > 200 then limit = 200 end

    return Database.Query(([[
        SELECT *
        FROM economy_alerts
        WHERE status = ?
        ORDER BY created_at DESC
        LIMIT %d
    ]]):format(limit), { status })
end

function Database.GetAlertCounts()
    local rows = Database.Query([[
        SELECT status, COUNT(*) AS count
        FROM economy_alerts
        GROUP BY status
    ]])

    local out = { new = 0, reviewed = 0, resolved = 0, dismissed = 0 }
    for _, r in ipairs(rows or {}) do
        if r.status and out[r.status] ~= nil then
            out[r.status] = tonumber(r.count) or 0
        end
    end
    return out
end

function Database.UpdateAlertStatus(alertId, status, reviewedBy)
    return Database.Update([[
        UPDATE economy_alerts
        SET status = ?, reviewed_by = ?, reviewed_at = NOW()
        WHERE id = ?
    ]], { status, reviewedBy, alertId })
end

function Database.InsertAlert(alert)
    return Database.Insert([[
        INSERT INTO economy_alerts
            (alert_type, severity, player_id, player_name, title, description, data, status, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, 'new', NOW())
    ]], {
        alert.alert_type,
        alert.severity or 'medium',
        alert.player_id,
        alert.player_name,
        alert.title,
        alert.description,
        alert.data and json.encode(alert.data) or nil,
    })
end

function Database.InsertAdminLog(entry)
    return Database.Insert([[
        INSERT INTO economy_admin_log
            (admin_id, admin_name, action, target_player, target_name, money_type, amount, old_value, new_value, reason, metadata, created_at)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        entry.admin_id,
        entry.admin_name,
        entry.action,
        entry.target_player,
        entry.target_name,
        entry.money_type,
        entry.amount,
        entry.old_value,
        entry.new_value,
        entry.reason,
        entry.metadata and json.encode(entry.metadata) or nil,
    })
end

function Database.GetAuditLog(limit)
    limit = tonumber(limit) or 50
    if limit < 1 then limit = 50 end
    if limit > 200 then limit = 200 end

    return Database.Query(([[
        SELECT *
        FROM economy_admin_log
        ORDER BY created_at DESC
        LIMIT %d
    ]]):format(limit))
end

function Database.InsertPrice(itemName, price, loggedBy, source)
    return Database.Insert([[
        INSERT INTO economy_price_history (item_name, price, logged_by, source, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], { itemName, price, loggedBy, source or 'manual' })
end

function Database.GetRecentPriceChanges(limit)
    limit = tonumber(limit) or 10
    if limit < 1 then limit = 10 end
    if limit > 200 then limit = 200 end

    return Database.Query(([[
        SELECT item_name, price, source, created_at
        FROM economy_price_history
        ORDER BY created_at DESC
        LIMIT %d
    ]]):format(limit))
end

function Database.GetLatestPrice(itemName)
    local rows = Database.Query([[
        SELECT price
        FROM economy_price_history
        WHERE item_name = ?
        ORDER BY created_at DESC
        LIMIT 1
    ]], { itemName })

    return rows and rows[1] and tonumber(rows[1].price) or nil
end

