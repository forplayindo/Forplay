-- Organization (society) accounts in f_banking, plus invoices through f_phone.
Society = {}
Invoice = {}

local function isUp(res) return GetResourceState(res) == 'started' end

function Society.Add(job, amount, reason, from)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if not isUp('f_banking') then return false end
    local ok, added = pcall(function() return exports['f_banking']:addAccountMoney(job, amount) end)
    if not ok or not added then
        lib.print.error(('Failed to deposit Rp %s into society account "%s"'):format(amount, job))
        return false
    end
    pcall(function()
        exports['f_banking']:handleTransaction(job, 'Layanan Publik', amount, reason, from or 'Warga', job, 'deposit')
    end)
    return true
end

function Society.Remove(job, amount, reason, to)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if not isUp('f_banking') then return false end
    local ok, removed = pcall(function() return exports['f_banking']:removeAccountMoney(job, amount) end)
    if not ok or not removed then return false end
    pcall(function()
        exports['f_banking']:handleTransaction(job, 'Refund Layanan', amount, reason, job, to or 'Warga', 'withdraw')
    end)
    return true
end

local CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789'

local function newInvoiceId()
    local t = {}
    for i = 1, 16 do
        local n = math.random(1, #CHARS)
        t[i] = CHARS:sub(n, n)
    end
    return 'bill_' .. table.concat(t)
end

function Invoice.Available()
    return isUp('f_phone')
end

---Writes a pending invoice into f_phone's business invoice table; when the citizen pays it,
---f_phone itself moves the money into the office job's organization account.
---@return string? invoiceId
function Invoice.Create(src, office, cid, name, amount, label, note)
    if not Invoice.Available() then return end

    local okNum, number = pcall(function() return exports['f_phone']:getPhoneNumber(src) end)
    local id = newInvoiceId()
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, 'pending', ?)
    ]], { id, office.job, label, office.job, office.label, cid, name, okNum and number or nil, math.floor(amount), note, os.time() })
    if not ok then return end

    pcall(function()
        exports['f_phone']:notify(src, {
            appId = 'bank', app = 'Bank', title = label,
            body = ('Tagihan Rp %d dari %s. Buka Bank > Invoices untuk membayar.'):format(math.floor(amount), office.label),
            time = 'now',
        })
    end)
    TriggerClientEvent('f_phone:client:services:invoices', src, {})
    return id
end

---@return boolean cancelled true when it was still pending (not paid)
function Invoice.Cancel(id, targetSrc)
    local affected = MySQL.update.await(
        "UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { id })
    if targetSrc then TriggerClientEvent('f_phone:client:services:invoices', targetSrc, {}) end
    return (tonumber(affected) or 0) > 0
end

function Invoice.Status(id)
    return MySQL.scalar.await('SELECT status FROM phone_service_invoices WHERE id = ?', { id })
end
