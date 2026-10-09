-- Event triggered when a player is loaded
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    client.onPlayerLoad(true)
end)

-- Event triggered when a player logs out
RegisterNetEvent('esx:onPlayerLogout', function(xPlayer)
    client.onPlayerLoad(false)
end)

-- Event triggered on status update
RegisterNetEvent('esx_status:onTick', function(status)
    for _, v in pairs(status) do
        local value = math.floor(v.percent or 0)
        if v.name == 'hunger' then
            PlayerData.hunger = value
        elseif v.name == 'thirst' then
            PlayerData.thirst = value
        elseif v.name == 'stress' then
            PlayerData.stress = value
        end
    end
end)

-- Event triggered to update stress value
RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    PlayerData.stress = newStress
end)

-- Retrieves the player's data
---@return object PlayerData
function client.GetPlayerData()
    return client.framework.GetPlayerData()
end

-- Retrieves the balance of the specified account
---@param account 'bank'|'cash'|'extra_currency'
---@return integer Balance
function client.GetPlayerBalance(account)
    local xPlayer = client.GetPlayerData()

    local function getItemAmount(itemName)
        for _, item in pairs(xPlayer.inventory or {}) do
            if item.name == itemName then
                return item.amount or item.count or 0
            end
        end
        return 0
    end

    if account == 'cash' then
        account = 'money'
    end

    if account == 'money' and Config.MoneySettings.isMoneyItem then
        return getItemAmount(Config.MoneySettings.itemName)
    elseif account == 'extra_currency' then
        if Config.MoneySettings.extra_currency.type == 'item' then
            return getItemAmount(Config.MoneySettings.extra_currency.name)
        else
            account = Config.MoneySettings.extra_currency.name
        end
    end

    for _, data in pairs(xPlayer.accounts or {}) do
        if account == data.name then
            return data.money
        end
    end

    return 0
end

-- Retrieves the player's job information
---@return table JobInfo
function client.GetPlayerJob()
    local label, grade = nil, nil
    local xPlayer = client.GetPlayerData()
    label = xPlayer.job.label
    grade = xPlayer.job.grade_label or xPlayer.job.grade_name
    return { label = label, grade = grade }
end

-- Checks if the player is logged in
---@return boolean isLoggedIn
function client.IsPlayerLoaded()
    return client.framework.IsPlayerLoaded()
end

-- Character name for the glass HUD player card
---@return string
function client.GetPlayerName()
    local xPlayer = client.GetPlayerData() or {}
    if xPlayer.firstName then
        return ('%s %s'):format(xPlayer.firstName, xPlayer.lastName or '')
    end
    return xPlayer.name or GetPlayerName(PlayerId())
end

-- Gang info for the glass HUD job card.
-- ESX has no gang by default: this reads `xPlayer.gang` if your server adds it,
-- otherwise returns nil (card shows "No Gang"). Edit here for job2/other gang scripts.
---@return table|nil { label, grade }
function client.GetPlayerGang()
    local gang = (client.GetPlayerData() or {}).gang
    if not gang or not gang.label then return nil end
    return { label = gang.label, grade = gang.grade_label or gang.grade_name }
end
