-- Rekening organisasi (society). f_banking -> qb-banking -> qb-management
Society = {}

local function isUp(res) return GetResourceState(res) == 'started' end

function Society.Add(amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if isUp('f_banking') then
        local ok = exports['f_banking']:addAccountMoney(Config.Job, amount)
        if ok then
            pcall(exports['f_banking'].handleTransaction, exports['f_banking'], Config.Job, Config.Label, amount, reason or 'Penjualan', 'Customer', Config.Label, 'deposit')
        end
        return ok == true
    elseif isUp('qb-banking') then
        return exports['qb-banking']:AddMoney(Config.Job, amount, reason) ~= false
    elseif isUp('qb-management') then
        exports['qb-management']:AddMoney(Config.Job, amount)
        return true
    end
    print('^1[f_cafe] Tidak ada resource banking untuk rekening organisasi^0')
    return false
end

function Society.Remove(amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if isUp('f_banking') then
        local ok = exports['f_banking']:removeAccountMoney(Config.Job, amount)
        if ok then
            pcall(exports['f_banking'].handleTransaction, exports['f_banking'], Config.Job, Config.Label, amount, reason or 'Pembelian', Config.Label, 'Supplier', 'withdraw')
        end
        return ok == true
    elseif isUp('qb-banking') then
        return exports['qb-banking']:RemoveMoney(Config.Job, amount, reason) == true
    elseif isUp('qb-management') then
        return exports['qb-management']:RemoveMoney(Config.Job, amount) == true
    end
    return false
end

function Society.Balance()
    if isUp('f_banking') then return exports['f_banking']:getAccountMoney(Config.Job) or 0 end
    if isUp('qb-banking') then return exports['qb-banking']:GetAccountBalance(Config.Job) or 0 end
    if isUp('qb-management') then return exports['qb-management']:GetAccount(Config.Job) or 0 end
    return 0
end
