Tracking = Tracking or {}

local queue = {}
local flushing = false

local function lower(s)
    return tostring(s or ''):lower()
end

local function detectMoneyType(mt)
    mt = lower(mt)
    if mt == 'money' then return 'cash' end
    if mt == 'black_money' then return 'dirty' end
    if mt == 'cash' or mt == 'bank' or mt == 'dirty' or mt == 'crypto' then
        return mt
    end
    if mt == '' then return 'cash' end
    return 'cash'
end

local function shouldMapCryptoToDirty()
    return Bridge and (Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbox')
end

local function normalizeMoneyType(mt)
    mt = detectMoneyType(mt)
    if mt == 'crypto' and shouldMapCryptoToDirty() then
        return 'dirty'
    end
    return mt
end

local function matchKeywordGroup(reason, keywordTable)
    local r = lower(reason)
    for group, keywords in pairs(keywordTable or {}) do
        for _, kw in ipairs(keywords) do
            if kw and kw ~= '' and r:find(lower(kw), 1, true) then
                return group, kw
            end
        end
    end
    return nil, nil
end

function Tracking.Categorize(txType, reason)
    if txType == 'transfer' then
        return 'transfer', nil
    end

    if txType == 'faucet' then
        local group = matchKeywordGroup(reason, Config.FaucetKeywords)
        return group or 'other', nil
    end

    if txType == 'sink' then
        local group = matchKeywordGroup(reason, Config.SinkKeywords)
        return group or 'other', nil
    end

    return 'other', nil
end

local function enqueue(row, profileDeltas, alertTx)
    queue[#queue + 1] = { row = row, deltas = profileDeltas, alertTx = alertTx }
end

local function flush()
    if flushing then return end
    if #queue == 0 then return end
    flushing = true

    local batch = queue
    queue = {}

    -- One INSERT for the whole batch, and deltas for the same player summed and
    -- upserted once, instead of a synchronous DB round trip per queued transaction
    -- (that per-item loop is what was stalling the resource on busy flush ticks).
    local rows = {}
    local deltasByCitizenid = {}

    for i = 1, #batch do
        local item = batch[i]
        rows[#rows + 1] = item.row

        if item.deltas then
            for citizenid, delta in pairs(item.deltas) do
                local agg = deltasByCitizenid[citizenid]
                if not agg then
                    agg = { player_name = nil, total_earned = 0, total_spent = 0, total_received = 0, total_sent = 0, peak_wealth = 0 }
                    deltasByCitizenid[citizenid] = agg
                end

                agg.player_name = delta.player_name or agg.player_name
                agg.total_earned = agg.total_earned + (tonumber(delta.total_earned) or 0)
                agg.total_spent = agg.total_spent + (tonumber(delta.total_spent) or 0)
                agg.total_received = agg.total_received + (tonumber(delta.total_received) or 0)
                agg.total_sent = agg.total_sent + (tonumber(delta.total_sent) or 0)
                agg.peak_wealth = math.max(agg.peak_wealth, tonumber(delta.peak_wealth) or 0)
            end
        end
    end

    local ok, err = pcall(function()
        Database.InsertTransactionsBatch(rows)
    end)
    if not ok and Config.Debug then
        print(('[Economy Dashboard] Failed to insert transaction batch: %s'):format(tostring(err)))
    end

    local ok2, err2 = pcall(function()
        Database.UpsertProfileDeltasBatch(deltasByCitizenid)
    end)
    if not ok2 and Config.Debug then
        print(('[Economy Dashboard] Failed to upsert profile batch: %s'):format(tostring(err2)))
    end

    if Alerts and Alerts.HandleTransaction then
        for i = 1, #batch do
            pcall(function()
                Alerts.HandleTransaction(batch[i].alertTx)
            end)
        end
    end

    flushing = false
end

CreateThread(function()
    local interval = tonumber(Config.BatchInsertInterval) or 30
    if interval < 2 then interval = 2 end

    while true do
        Wait(interval * 1000)
        flush()
    end
end)

function Tracking.LogTransaction(tx)
    if not tx then return false end

    local txType = lower(tx.type)
    if txType ~= 'faucet' and txType ~= 'sink' and txType ~= 'transfer' then
        return false
    end

    local amount = tonumber(tx.amount) or 0
    amount = math.floor(math.abs(amount))
    if amount <= 0 then return false end

    local reason = tx.reason and tostring(tx.reason) or nil
    local category = tx.category
    local subcategory = tx.subcategory

    if not category or category == '' then
        category = (Tracking.Categorize(txType, reason))
    end
    if not subcategory or subcategory == '' then
        subcategory = tx.subcategory or reason
    end

    local moneyType = normalizeMoneyType(tx.moneyType)

    local row = {
        transaction_type = txType,
        category = category or 'other',
        subcategory = subcategory,
        amount = amount,
        player_from = tx.playerFrom,
        player_to = tx.playerTo,
        money_type = moneyType,
        balance_after = (type(tx.balanceAfter) == 'number') and math.floor(tx.balanceAfter) or nil,
        reason = reason,
        metadata = tx.metadata,
    }

    local deltas = {}
    local peak = (type(tx.balanceAfter) == 'number') and math.floor(tx.balanceAfter) or 0
    local playerName = tx.playerName

    if txType == 'faucet' and tx.playerTo then
        deltas[tx.playerTo] = {
            player_name = playerName,
            total_earned = amount,
            total_spent = 0,
            total_received = 0,
            total_sent = 0,
            peak_wealth = peak,
        }
    elseif txType == 'sink' and tx.playerFrom then
        deltas[tx.playerFrom] = {
            player_name = playerName,
            total_earned = 0,
            total_spent = amount,
            total_received = 0,
            total_sent = 0,
            peak_wealth = peak,
        }
    elseif txType == 'transfer' then
        if tx.playerFrom then
            deltas[tx.playerFrom] = {
                player_name = playerName,
                total_earned = 0,
                total_spent = 0,
                total_received = 0,
                total_sent = amount,
                peak_wealth = 0,
            }
        end
        if tx.playerTo then
            deltas[tx.playerTo] = {
                player_name = playerName,
                total_earned = 0,
                total_spent = 0,
                total_received = amount,
                total_sent = 0,
                peak_wealth = 0,
            }
        end
    end

    enqueue(row, deltas, {
        type = txType,
        amount = amount,
        moneyType = moneyType,
        playerFrom = tx.playerFrom,
        playerTo = tx.playerTo,
        reason = reason,
        category = category,
        subcategory = subcategory,
    })

    if Config.Debug then
        flush()
    end

    return true
end

function Tracking.Flush()
    flush()
end

exports('LogFaucet', function(identifier, amount, category, reason, moneyType, metadata)
    return Tracking.LogTransaction({
        type = 'faucet',
        amount = amount,
        moneyType = moneyType or 'cash',
        playerFrom = nil,
        playerTo = identifier,
        category = category,
        reason = reason,
        metadata = metadata,
    })
end)

exports('LogSink', function(identifier, amount, category, reason, moneyType, metadata)
    return Tracking.LogTransaction({
        type = 'sink',
        amount = amount,
        moneyType = moneyType or 'cash',
        playerFrom = identifier,
        playerTo = nil,
        category = category,
        reason = reason,
        metadata = metadata,
    })
end)

exports('LogTransfer', function(fromIdentifier, toIdentifier, amount, reason, moneyType, metadata)
    return Tracking.LogTransaction({
        type = 'transfer',
        amount = amount,
        moneyType = moneyType or 'cash',
        playerFrom = fromIdentifier,
        playerTo = toIdentifier,
        category = 'transfer',
        reason = reason,
        metadata = metadata,
    })
end)

