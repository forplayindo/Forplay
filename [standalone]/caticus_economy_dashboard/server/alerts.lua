Alerts = Alerts or {}

local function lower(s) return tostring(s or ''):lower() end

function Alerts.Create(alert)
    if not alert or not alert.title then return false end
    Database.InsertAlert(alert)
    return true
end

local function maybeLargeTransaction(tx)
    local cfg = Config.Alerts and Config.Alerts.LargeTransaction
    if not cfg or not cfg.enabled then return end
    if not tx or not tx.amount then return end

    local amount = tonumber(tx.amount) or 0
    if amount < (tonumber(cfg.amount) or 1000000) then return end

    Alerts.Create({
        alert_type = 'LargeTransaction',
        severity = cfg.severity or 'medium',
        player_id = tx.playerTo or tx.playerFrom,
        player_name = nil,
        title = ('Large transaction: Rp %s'):format(amount),
        description = ('A %s of Rp %s was logged (%s/%s). Reason: %s'):format(
            tx.type or 'transaction',
            amount,
            tx.category or 'other',
            tx.moneyType or 'cash',
            tx.reason or 'N/A'
        ),
        data = tx,
    })
end

local function maybeRapidWealthGain(tx)
    local cfg = Config.Alerts and Config.Alerts.RapidWealthGain
    if not cfg or not cfg.enabled then return end
    if not tx or tx.type ~= 'faucet' then return end
    if not tx.playerTo then return end

    local window = tonumber(cfg.timeWindow) or 600
    local threshold = tonumber(cfg.amount) or 500000

    local sum = Database.Scalar([[
        SELECT SUM(amount)
        FROM economy_transactions
        WHERE transaction_type = 'faucet'
          AND player_to = ?
          AND created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND)
    ]], { tx.playerTo, window })

    sum = tonumber(sum) or 0
    if sum < threshold then return end

    Alerts.Create({
        alert_type = 'RapidWealthGain',
        severity = cfg.severity or 'high',
        player_id = tx.playerTo,
        player_name = nil,
        title = ('Rapid wealth gain: Rp %s'):format(sum),
        description = ('Player gained Rp %s in the last %ss (latest: Rp %s).'):format(sum, window, tx.amount or 0),
        data = { citizenid = tx.playerTo, sum = sum, window = window, latest = tx },
    })
end

function Alerts.HandleTransaction(tx)
    if not tx then return end
    tx.type = lower(tx.type)
    maybeLargeTransaction(tx)
    maybeRapidWealthGain(tx)
end

