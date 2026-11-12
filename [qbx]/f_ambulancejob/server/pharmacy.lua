-- Apotek (server). Warga hanya MEMESAN di meja apotek:
--  * stok gudang langsung dikunci (Stock.Take), tagihan 'apotek' masuk Kasir (Billing, channel kasir)
--  * belum dibayar dalam orderTimeout menit -> batal otomatis, stok kembali ke gudang
--  * 1 pesanan aktif per karakter; batas obat per pesanan beda saat ada / tidak ada EMS bertugas
--  * membeli saat tidak ada EMS -> jeda noEmsCooldown menit, hilang kalau ada EMS bertugas emsResetAfter menit

local cfg = require 'config.pharmacy'

local MENU = {}
for _, m in ipairs(cfg.items) do MENU[m.item] = m end
local throttles = {}
local emsOnSince = nil       -- os.time() saat jumlah EMS bertugas naik dari 0

local function throttle(src, key, ms)
    local id, now = src .. key, GetGameTimer()
    if throttles[id] and now - throttles[id] < ms then return false end
    throttles[id] = now
    return true
end

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function nearCounter(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, c in ipairs(cfg.counters) do
        if #(pos - c.coords) <= 4.0 then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Pengaturan batas (KVP, diubah petugas di Kasir > Pengaturan)
---------------------------------------------------------------------------
Pharmacy = {}

function Pharmacy.Limits()
    local w = GetResourceKvpInt('pharmacy_limit_ems')
    local wo = GetResourceKvpInt('pharmacy_limit_noems')
    return (w and w > 0) and w or cfg.limitWithEms, (wo and wo > 0) and wo or cfg.limitWithoutEms
end

---@return string? error
function Pharmacy.SetLimits(withEms, withoutEms)
    withEms, withoutEms = math.floor(tonumber(withEms) or 0), math.floor(tonumber(withoutEms) or 0)
    if withEms < 1 or withEms > cfg.maxLimit or withoutEms < 1 or withoutEms > cfg.maxLimit then
        return ('Batas harus 1 - %d obat'):format(cfg.maxLimit)
    end
    SetResourceKvpInt('pharmacy_limit_ems', withEms)
    SetResourceKvpInt('pharmacy_limit_noems', withoutEms)
end

---Sisa jeda (detik) setelah membeli tanpa EMS bertugas.
local function cooldownLeft(cid)
    local at = GetResourceKvpInt('pharmacy_noems_' .. cid) or 0
    if at <= 0 then return 0 end
    if emsOnSince and emsOnSince > at and os.time() - emsOnSince >= cfg.emsResetAfter * 60 then
        DeleteResourceKvp('pharmacy_noems_' .. cid)
        return 0
    end
    local left = at + cfg.noEmsCooldown * 60 - os.time()
    if left <= 0 then DeleteResourceKvp('pharmacy_noems_' .. cid) return 0 end
    return left
end

---Pembeli wajib membawa KTP / KTP Sementara miliknya yang masih berlaku (f_idcard). Kasir tidak dicek.
---@return string? message alasan ditolak
local function identityError(src)
    local ok, valid, message = pcall(function() return exports.f_idcard:CheckIdentity(src) end)
    if ok and not valid then return message or 'Anda tidak membawa KTP' end
end

local function activeOrder(cid)
    return Billing.Query("citizenid = ? AND kind = 'apotek' AND status = 'unpaid' LIMIT 1", { cid })[1]
end

---------------------------------------------------------------------------
-- Menu & pesan
---------------------------------------------------------------------------
local function menuData(cid)
    local ems = Billing.EmsOnDuty()
    local withEms, withoutEms = Pharmacy.Limits()
    local items = {}
    for i, m in ipairs(cfg.items) do
        items[i] = { item = m.item, label = m.label, emoji = m.emoji, desc = m.desc, price = Prices.Get('item:' .. m.item), stock = Stock.Get(m.item) }
    end
    local active = activeOrder(cid)
    return {
        label = cfg.label,
        items = items,
        ems = ems,
        limit = ems > 0 and withEms or withoutEms,
        cooldown = cooldownLeft(cid),
        timeout = cfg.orderTimeout,
        active = active and { id = active.id, total = active.total, created = active.created_at } or nil,
    }
end

lib.callback.register('f_ambulancejob:server:pharmacyMenu', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan.' } end
    local idErr = identityError(src)
    if idErr then return { error = idErr } end
    return menuData(player.PlayerData.citizenid)
end)

---@param cart table<string, integer> item -> jumlah
lib.callback.register('f_ambulancejob:server:pharmacyOrder', function(src, cart)
    if not throttle(src, 'order', 3000) then return { error = 'Tunggu sebentar.' } end
    if not nearCounter(src) then return { error = 'Kamu harus berada di meja apotek.' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { error = 'Data pemain tidak ditemukan.' } end
    local idErr = identityError(src)
    if idErr then return { error = idErr } end
    local cid = player.PlayerData.citizenid

    if activeOrder(cid) then return { error = 'Kamu masih punya pesanan yang belum dibayar. Bayar dulu di kasir.' } end
    local wait = cooldownLeft(cid)
    if wait > 0 then return { error = ('Kamu baru saja membeli obat. Bisa memesan lagi dalam %d menit.'):format(math.ceil(wait / 60)) } end
    if type(cart) ~= 'table' then return { error = 'Keranjang tidak valid.' } end

    local ems = Billing.EmsOnDuty()
    local withEms, withoutEms = Pharmacy.Limits()
    local limit = ems > 0 and withEms or withoutEms

    local lines, need, total, count = {}, {}, 0, 0
    for item, raw in pairs(cart) do
        local m, qty = MENU[item], tonumber(raw)
        if not m or not qty or qty ~= math.floor(qty) or qty < 0 then return { error = 'Keranjang tidak valid.' } end
        if qty > 0 then
            local price = Prices.Get('item:' .. item)
            lines[#lines + 1] = { item = item, label = m.label, qty = qty, price = price }
            need[item] = qty
            total += price * qty
            count += qty
        end
    end
    if count <= 0 then return { error = 'Keranjang masih kosong.' } end
    if count > limit then return { error = ('Maksimal %d obat per pesanan.'):format(limit) } end

    -- kunci stok gudang sekarang (kembali ke gudang kalau batal / kadaluarsa)
    local ok, missing = Stock.Take(need)
    if not ok then return { error = ('Stok %s sedang habis.'):format(Stock.Label(missing)) } end

    local id = Billing.Create({
        cid = cid, name = charName(player), items = lines, total = total, kind = 'apotek', channel = 'kasir',
        by = cid, byName = charName(player), deliver = 'pending',
    })
    if ems <= 0 then SetResourceKvpInt('pharmacy_noems_' .. cid, os.time()) end

    local data = menuData(cid)
    data.ordered = { id = id, total = total }
    return data
end)

---------------------------------------------------------------------------
-- Batal otomatis + pantau EMS bertugas (untuk jeda tanpa EMS)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        if Billing.EmsOnDuty() > 0 then
            emsOnSince = emsOnSince or os.time()
        else
            emsOnSince = nil
        end
        local limit = os.time() - cfg.orderTimeout * 60
        for _, bill in ipairs(Billing.Query("kind = 'apotek' AND status = 'unpaid' AND created_at <= ?", { limit })) do
            if not Billing.Cancel(bill, 'Otomatis (30 menit)') then
                local src = Billing.SourceOf(bill.citizenid)
                if src then exports.qbx_core:Notify(src, ('Pesanan apotek #%d dibatalkan karena tidak dibayar.'):format(bill.id), 'error', 7000) end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Peralihan dari apotek lama (tabel ems_pharmacy_orders): pesanan yang masih berjalan dibereskan
---------------------------------------------------------------------------
CreateThread(function()
    local exists = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ems_pharmacy_orders'
    ]])
    if (tonumber(exists) or 0) == 0 then return end
    for _, r in ipairs(MySQL.query.await("SELECT * FROM ems_pharmacy_orders WHERE status IN ('unpaid', 'paid')") or {}) do
        if r.status == 'paid' then
            pcall(function() exports['f_banking']:removeAccountMoney(cfg.job, r.total) end)
            exports.qbx_core:AddMoney(r.citizenid, 'bank', r.total, 'pharmacy-refund')
        elseif r.invoice_id then
            MySQL.update.await("UPDATE phone_service_invoices SET status = 'cancelled' WHERE id = ? AND status = 'pending'", { r.invoice_id })
        end
        MySQL.update.await("UPDATE ems_pharmacy_orders SET status = ?, updated_at = ? WHERE code = ?",
            { r.status == 'paid' and 'refunded' or 'cancelled', os.time(), r.code })
    end
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for k in pairs(throttles) do
        if k:sub(1, #src) == src then throttles[k] = nil end
    end
end)
