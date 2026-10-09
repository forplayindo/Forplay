Analytics = Analytics or {}

local BRACKETS = {
    { name = 'Broke', max = 1000 },
    { name = 'Poor', max = 10000 },
    { name = 'Working Class', max = 50000 },
    { name = 'Middle Class', max = 200000 },
    { name = 'Upper Middle', max = 500000 },
    { name = 'Wealthy', max = 1000000 },
    { name = 'Rich', max = 5000000 },
    { name = 'Ultra Rich', max = math.huge },
}

local function safeNum(x)
    return tonumber(x) or 0
end

local function sortAsc(t)
    table.sort(t, function(a, b) return a < b end)
end

local function sortDescPlayers(t)
    table.sort(t, function(a, b) return (a.total or 0) > (b.total or 0) end)
end

function Analytics.ComputeGini(values)
    if not values or #values == 0 then return 0 end

    local v = {}
    for _, x in ipairs(values) do
        local n = safeNum(x)
        if n < 0 then n = 0 end
        v[#v + 1] = n
    end
    if #v == 0 then return 0 end

    sortAsc(v)
    local n = #v
    local sum = 0
    for i = 1, n do sum = sum + v[i] end
    if sum == 0 then return 0 end

    local cum = 0
    for i = 1, n do
        cum = cum + (i * v[i])
    end
    local g = (2 * cum) / (n * sum) - (n + 1) / n
    if g < 0 then g = 0 end
    if g > 1 then g = 1 end
    return g
end

function Analytics.ComputeWealthPercentiles(values)
    local out = { top1Percent = 0, top10Percent = 0, top50Percent = 0 }
    if not values or #values == 0 then return out end

    local v = {}
    local total = 0
    for _, x in ipairs(values) do
        local n = safeNum(x)
        if n < 0 then n = 0 end
        v[#v + 1] = n
        total = total + n
    end
    if total == 0 then return out end

    table.sort(v, function(a, b) return a > b end)
    local n = #v

    local function sumTop(pct)
        local k = math.max(1, math.floor(n * pct + 0.9999))
        local s = 0
        for i = 1, math.min(k, n) do s = s + v[i] end
        return (s / total) * 100
    end

    out.top1Percent = sumTop(0.01)
    out.top10Percent = sumTop(0.10)
    out.top50Percent = sumTop(0.50)
    return out
end

function Analytics.ComputeWealthBrackets(values)
    local counts = {}
    for _, b in ipairs(BRACKETS) do
        counts[b.name] = 0
    end

    for _, x in ipairs(values or {}) do
        local w = safeNum(x)
        if w < 0 then w = 0 end
        for _, b in ipairs(BRACKETS) do
            if w < b.max or b.max == math.huge then
                counts[b.name] = (counts[b.name] or 0) + 1
                break
            end
        end
    end

    local out = {}
    for _, b in ipairs(BRACKETS) do
        out[#out + 1] = { name = b.name, count = counts[b.name] or 0 }
    end
    return out
end

local function hasTable(name)
    local rows = Database.Query("SHOW TABLES LIKE ?", { name })
    return rows and #rows > 0
end

local function hasColumn(tableName, columnName)
    local rows = Database.Query(("SHOW COLUMNS FROM `%s` LIKE ?"):format(tableName), { columnName })
    return rows and #rows > 0
end

local function getWealth_QBCoreStyle()
    if not hasTable('players') then return nil end
    local rows = Database.Query([[
        SELECT
            citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname,
            CAST(COALESCE(JSON_EXTRACT(money, '$.cash'), 0) AS SIGNED) AS cash,
            CAST(COALESCE(JSON_EXTRACT(money, '$.bank'), 0) AS SIGNED) AS bank,
            CAST(COALESCE(JSON_EXTRACT(money, '$.crypto'), 0) AS SIGNED) AS dirty
        FROM players
    ]])

    local players = {}
    local values = {}
    for _, r in ipairs(rows or {}) do
        local cash = safeNum(r.cash)
        local bank = safeNum(r.bank)
        local dirty = safeNum(r.dirty)
        local total = cash + bank + dirty
        local name = (tostring(r.firstname or '') .. ' ' .. tostring(r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then name = nil end
        players[#players + 1] = {
            citizenid = r.citizenid,
            firstname = r.firstname,
            lastname = r.lastname,
            name = name,
            cash = cash,
            bank = bank,
            dirty = dirty,
            total = total,
        }
        values[#values + 1] = total
    end
    return players, values
end

local function parseESXAccounts(accountsJson)
    if not accountsJson then return 0, 0, 0 end
    local ok, accounts = pcall(json.decode, accountsJson)
    if not ok or not accounts then return 0, 0, 0 end

    local cash, bank, dirty = 0, 0, 0
    if accounts[1] and accounts[1].name then
        for _, acc in ipairs(accounts) do
            if acc.name == 'money' then cash = safeNum(acc.money)
            elseif acc.name == 'bank' then bank = safeNum(acc.money)
            elseif acc.name == 'black_money' then dirty = safeNum(acc.money)
            end
        end
    else
        cash = safeNum(accounts.money)
        bank = safeNum(accounts.bank)
        dirty = safeNum(accounts.black_money)
    end
    return cash, bank, dirty
end

local function getWealth_ESX()
    if not hasTable('users') then return nil end

    if hasTable('user_accounts') then
        local rows = Database.Query([[
            SELECT
                u.identifier AS citizenid,
                u.money AS cash,
                SUM(CASE WHEN ua.account_name = 'bank' THEN ua.money ELSE 0 END) AS bank,
                SUM(CASE WHEN ua.account_name = 'black_money' THEN ua.money ELSE 0 END) AS dirty
            FROM users u
            LEFT JOIN user_accounts ua
                ON ua.identifier = u.identifier
               AND ua.account_name IN ('bank', 'black_money')
            GROUP BY u.identifier, u.money
        ]])

        local players, values = {}, {}
        for _, r in ipairs(rows or {}) do
            local cash = safeNum(r.cash)
            local bank = safeNum(r.bank)
            local dirty = safeNum(r.dirty)
            local total = cash + bank + dirty
            players[#players + 1] = {
                citizenid = r.citizenid,
                name = nil,
                cash = cash,
                bank = bank,
                dirty = dirty,
                total = total,
            }
            values[#values + 1] = total
        end
        return players, values
    end

    if not hasColumn('users', 'accounts') then return nil end

    local selectName = hasColumn('users', 'name')
    local selectFirst = hasColumn('users', 'firstname')
    local selectLast = hasColumn('users', 'lastname')

    local cols = { "identifier AS citizenid", "accounts" }
    if selectName then cols[#cols + 1] = "name" end
    if selectFirst then cols[#cols + 1] = "firstname" end
    if selectLast then cols[#cols + 1] = "lastname" end

    local rows = Database.Query(("SELECT %s FROM users"):format(table.concat(cols, ", ")))

    local players, values = {}, {}
    for _, r in ipairs(rows or {}) do
        local cash, bank, dirty = parseESXAccounts(r.accounts)
        local total = cash + bank + dirty
        local name = nil
        if r.firstname or r.lastname then
            name = (tostring(r.firstname or '') .. ' ' .. tostring(r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        elseif r.name then
            name = tostring(r.name)
        end
        if name == '' then name = nil end
        players[#players + 1] = {
            citizenid = r.citizenid,
            firstname = r.firstname,
            lastname = r.lastname,
            name = name,
            cash = cash,
            bank = bank,
            dirty = dirty,
            total = total,
        }
        values[#values + 1] = total
    end
    return players, values
end

local function getWealth_FromProfiles()
    local rows = Database.Query([[
        SELECT citizenid, player_name, peak_wealth AS total
        FROM economy_player_profiles
        WHERE peak_wealth > 0
    ]])

    local players, values = {}, {}
    for _, r in ipairs(rows or {}) do
        local total = safeNum(r.total)
        players[#players + 1] = { citizenid = r.citizenid, name = r.player_name, total = total }
        values[#values + 1] = total
    end
    return players, values
end

function Analytics.GetWealthList()
    local players, values

    if Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox') then
        local ok, p, v = pcall(getWealth_QBCoreStyle)
        if ok and p then
            players, values = p, v
        end
    elseif Bridge and Bridge.Framework == 'esx' then
        local ok, p, v = pcall(getWealth_ESX)
        if ok and p then
            players, values = p, v
        end
    end

    if not players then
        local ok, p, v = pcall(getWealth_FromProfiles)
        if ok and p then
            players, values = p, v
        else
            players, values = {}, {}
        end
    end

    return players, values
end

function Analytics.GetTopRichest(limit)
    limit = tonumber(limit) or 10
    local players = (Analytics.GetWealthList())
    sortDescPlayers(players)

    local out = {}
    for i = 1, math.min(limit, #players) do
        local p = players[i]
        out[#out + 1] = {
            citizenid = p.citizenid,
            name = p.name,
            firstname = p.firstname,
            lastname = p.lastname,
            total_wealth = p.total or 0,
        }
    end
    return out
end

