-- Kolom INT berhenti di Rp 2.147.483.647; kolom uang diubah ke BIGINT supaya saldo/transaksi
-- miliaran tidak gagal tersimpan. Aman dijalankan berkali-kali: kolom yang sudah BIGINT dilewati,
-- tabel yang belum ada (resource belum pernah jalan) juga dilewati.

local MONEY_COLUMNS = {
    { 'bank_accounts_new', 'amount' },
    { 'bank_loans', 'total_amount' },
    { 'bank_loans', 'remaining_amount' },
    { 'bank_transactions', 'amount' },
    { 'cafe_orders', 'total' },
    { 'cafe_promos', 'price' },
    { 'cityhall_requests', 'price' },
    { 'crew_bank_log', 'amount' },
    { 'economy_price_history', 'price' },
    { 'ems_bills', 'total' },
    { 'ems_pharmacy_orders', 'total' },
    { 'ems_prices', 'price' },
    { 'mechanic_bills', 'total' },
    { 'mechanic_prices', 'price' },
    { 'mechanic_shop_orders', 'total' },
    { 'occasion_vehicles', 'price' },
    { 'phone_mdt_arrests', 'fine' },
    { 'phone_mdt_court_cases', 'sentence_fine' },
    { 'phone_mdt_penal_overrides', 'fine' },
    { 'phone_mdt_report_charges', 'fine' },
    { 'phone_mdt_warrants', 'bond' },
    { 'phone_service_invoices', 'amount' },
    { 'player_vehicles', 'depotprice' },
    { 'police_tickets', 'price' },
    { 'properties', 'price' },
    { 'vehicle_financing', 'balance' },
    { 'vehicle_financing', 'paymentamount' },
    { 'yphone_banking_transactions', 'amount' },
}

local function buildDefinition(col)
    local def = 'BIGINT'
    if col.COLUMN_TYPE:find('unsigned', 1, true) then def = def .. ' UNSIGNED' end

    local nullable = col.IS_NULLABLE == 'YES'
    def = def .. (nullable and ' NULL' or ' NOT NULL')

    local default = col.COLUMN_DEFAULT
    if default ~= nil and default ~= 'NULL' then
        local n = tonumber((tostring(default):gsub("'", '')))
        if n then def = def .. (' DEFAULT %d'):format(math.floor(n)) end
    elseif nullable then
        def = def .. ' DEFAULT NULL'
    end
    return def
end

local function migrate()
    local wanted, where = {}, {}
    for i = 1, #MONEY_COLUMNS do
        local t, c = MONEY_COLUMNS[i][1], MONEY_COLUMNS[i][2]
        wanted[t .. '.' .. c] = true
        where[#where + 1] = t
    end

    local rows = MySQL.query.await([[
        SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND DATA_TYPE <> 'bigint' AND TABLE_NAME IN (?)
    ]], { where }) or {}

    local changed = 0
    for i = 1, #rows do
        local col = rows[i]
        if wanted[col.TABLE_NAME .. '.' .. col.COLUMN_NAME] then
            local sql = ('ALTER TABLE `%s` MODIFY `%s` %s'):format(col.TABLE_NAME, col.COLUMN_NAME, buildDefinition(col))
            local ok, err = pcall(MySQL.query.await, sql)
            if ok then
                changed = changed + 1
                print(('^2[f_dbmigrate]^7 %s.%s: %s -> BIGINT'):format(col.TABLE_NAME, col.COLUMN_NAME, col.COLUMN_TYPE))
            else
                print(('^1[f_dbmigrate]^7 gagal ubah %s.%s: %s'):format(col.TABLE_NAME, col.COLUMN_NAME, tostring(err)))
            end
        end
    end
    return changed
end

CreateThread(function()
    migrate()
    -- Ulangi sekali setelah semua resource selesai start, untuk tabel yang baru dibuat script lain.
    Wait(60000)
    migrate()
end)
