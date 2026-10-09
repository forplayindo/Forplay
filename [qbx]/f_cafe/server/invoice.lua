-- Invoice f_phone. Baris invoice ditulis ke tabel phone_service_invoices (tabel yang sama
-- dengan invoice bisnis f_phone) supaya kita memegang id-nya: bisa dibatalkan saat kadaluarsa
-- dan dicocokkan saat event f_phone:server:services:invoicePaid. Saat dibayar, f_phone sendiri
-- yang memindahkan uang pelanggan ke rekening organisasi (job).
Invoice = {}

local CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789'

local function newId()
    local t = {}
    for i = 1, 16 do
        local n = math.random(1, #CHARS)
        t[i] = CHARS:sub(n, n)
    end
    return 'bill_' .. table.concat(t)
end

function Invoice.Available()
    return GetResourceState('f_phone') == 'started'
end

---@return string|nil invoiceId
function Invoice.Create(src, amount, label, note)
    if not Invoice.Available() then return end
    local cid = Bridge.GetCitizenId(src)
    if not cid then return end

    local okNum, number = pcall(function() return exports['f_phone']:getPhoneNumber(src) end)
    local id = newId()
    local ok = pcall(MySQL.insert.await, [[
        INSERT INTO phone_service_invoices
            (id, job, label, sender_cid, sender_name, sender_number,
             target_cid, target_name, target_number, amount, note, status, created_at)
        VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, 'pending', ?)
    ]], { id, Config.Job, label, Config.Job, Config.Label, cid, Bridge.GetName(src), okNum and number or nil, math.floor(amount), note, os.time() })
    if not ok then return end

    pcall(function()
        exports['f_phone']:notify(src, {
            appId = 'bank', app = 'Bank', title = label,
            body = ('Tagihan baru Rp %d dari %s. Buka Bank > Invoices untuk membayar.'):format(math.floor(amount), Config.Label),
            time = 'now',
        })
    end)
    TriggerClientEvent('f_phone:client:services:invoices', src, {})
    return id
end

--- Membatalkan invoice yang masih pending. true = berhasil dibatalkan (belum dibayar).
function Invoice.Cancel(id, targetCid)
    local affected = MySQL.update.await(
        "UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { id })
    if (tonumber(affected) or 0) > 0 then
        local tsrc = targetCid and Bridge.GetSourceByCitizenId(targetCid)
        if tsrc then TriggerClientEvent('f_phone:client:services:invoices', tsrc, {}) end
        return true
    end
    return false
end

function Invoice.Status(id)
    return MySQL.scalar.await('SELECT status FROM phone_service_invoices WHERE id = ?', { id })
end
