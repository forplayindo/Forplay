-- Admin dealer (Owner/Admin f_admin): atur kendaraan di toko + putuskan permintaan donasi.
local DONATION = Config.DonationCategory
local catalogCache

local function catalogList()
    if catalogCache then return catalogCache end
    local out = {}
    for model, v in pairs(Dealer.vehicles()) do
        local label = Dealer.labelOf(model)
        out[#out + 1] = {
            model = model,
            label = label,
            category = v.category or '',
            price = math.floor(tonumber(v.price) or 0),
            key = (label .. ' ' .. model):lower(),
        }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    catalogCache = out
    return out
end

-- Cari di katalog (server-side, maks 40 hasil) supaya NUI tidak perlu menerima ~900 kendaraan sekaligus
local SEARCH_MAX = 40
lib.callback.register('f_dealer:admin:search', function(source, q)
    if not Dealer.isAdmin(source) then return end
    q = type(q) == 'string' and q:lower():gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 40) or ''
    local out = {}
    for _, c in ipairs(catalogList()) do
        if q == '' or c.key:find(q, 1, true) then
            out[#out + 1] = { model = c.model, label = c.label, category = c.category, price = c.price, inShop = Dealer.shop[c.model] ~= nil }
            if #out >= SEARCH_MAX then break end
        end
    end
    return out
end)

local function adminName(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        local ci = player.PlayerData.charinfo
        return ('%s (%s %s)'):format(GetPlayerName(src), ci.firstname or '', ci.lastname or '')
    end
    return GetPlayerName(src) or ('id ' .. src)
end

local function requestRows()
    local rows = MySQL.query.await([[
        (SELECT id, citizenid, name, model, ticket, status, reason, decided_by, plate,
                UNIX_TIMESTAMP(created_at) AS created, UNIX_TIMESTAMP(decided_at) AS decided
         FROM f_dealer_requests WHERE status = 'pending')
        UNION ALL
        (SELECT id, citizenid, name, model, ticket, status, reason, decided_by, plate,
                UNIX_TIMESTAMP(created_at) AS created, UNIX_TIMESTAMP(decided_at) AS decided
         FROM f_dealer_requests WHERE status <> 'pending' ORDER BY id DESC LIMIT 100)
    ]]) or {}
    for _, r in ipairs(rows) do r.label = Dealer.labelOf(r.model) end
    table.sort(rows, function(a, b)
        if (a.status == 'pending') ~= (b.status == 'pending') then return a.status == 'pending' end
        return a.id > b.id
    end)
    return rows
end

lib.callback.register('f_dealer:admin:data', function(source)
    if not Dealer.isAdmin(source) then return end
    return {
        vehicles = Dealer.list,
        requests = requestRows(),
        categories = Config.Categories,
    }
end)

lib.callback.register('f_dealer:admin:save', function(source, model, category, price)
    if not Dealer.isAdmin(source) then return false, 'Tidak punya akses' end
    if type(model) ~= 'string' or not Dealer.catalog(model) then return false, 'Model tidak ada di qbx_core shared/vehicles.lua' end
    if type(category) ~= 'string' or not Dealer.CATEGORY[category] then return false, 'Kategori tidak valid' end
    price = math.floor(tonumber(price) or -1)
    if category ~= DONATION and (price < 1 or price > 99999999999) then return false, 'Harga tidak valid' end
    if category == DONATION then price = 0 end

    local isNew = Dealer.shop[model] == nil
    MySQL.query.await([[INSERT INTO f_dealer_vehicles (model, category, price, added_by) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE category = VALUES(category), price = VALUES(price)]], { model, category, price, adminName(source) })
    local entry = Dealer.setShopEntry(model, category, price)
    Dealer.rebuild()

    Dealer.log(source, ('%s %s %s → %s %s'):format(adminName(source), isNew and 'menambah' or 'mengubah', entry.label, category,
        category == DONATION and '(donasi)' or Dealer.rupiah(price)))
    return true, isNew and 'Kendaraan ditambahkan ke dealer' or 'Kendaraan diperbarui', Dealer.list
end)

lib.callback.register('f_dealer:admin:remove', function(source, model)
    if not Dealer.isAdmin(source) then return false, 'Tidak punya akses' end
    local v = type(model) == 'string' and Dealer.shop[model]
    if not v then return false, 'Kendaraan tidak ada di dealer' end
    MySQL.update.await('DELETE FROM f_dealer_vehicles WHERE model = ?', { model })
    Dealer.shop[model] = nil
    Dealer.rebuild()
    Dealer.log(source, ('%s menghapus %s dari dealer'):format(adminName(source), v.label))
    return true, 'Kendaraan dihapus dari dealer', Dealer.list
end)

---------------------------------------------------------------------------
-- Putuskan permintaan donasi → email f_phone ke pemain
---------------------------------------------------------------------------
local function approveMail(row, label)
    return {
        ('Halo %s,'):format(row.name),
        '',
        'Permintaan kendaraan donasi kamu sudah DISETUJUI.',
        '',
        ('Kendaraan    : %s'):format(label),
        ('Nomor tiket  : %s'):format(row.ticket),
        '',
        'Cara mengambil kendaraan:',
        ('1. Datang ke dealer %s.'):format(Config.Title),
        '2. Dekati NPC dealer lalu tekan [E] Beli Kendaraan.',
        '3. Buka kategori "Mobil Donasi" dan pilih ' .. label .. '.',
        '4. Tekan tombol "Ambil Kendaraan".',
        '5. Kendaraan langsung siap di garasi dealer, kamu duduk di kursi sopir dan kuncinya masuk ke tasmu.',
        '',
        'Terima kasih atas dukunganmu!',
    }
end

local function rejectMail(row, label, reason)
    return {
        ('Halo %s,'):format(row.name),
        '',
        'Mohon maaf, permintaan kendaraan donasi kamu DITOLAK.',
        '',
        ('Kendaraan    : %s'):format(label),
        ('Nomor tiket  : %s'):format(row.ticket),
        ('Alasan       : %s'):format(reason),
        '',
        'Kalau ada pertanyaan, balas lewat tiket Discord kamu. Kamu bisa mengajukan ulang di dealer dengan nomor tiket yang benar.',
    }
end

lib.callback.register('f_dealer:admin:decide', function(source, id, approve, reason)
    if not Dealer.isAdmin(source) then return false, 'Tidak punya akses' end
    id = math.floor(tonumber(id) or 0)
    approve = approve == true
    if not approve then
        reason = type(reason) == 'string' and reason:gsub('^%s+', ''):gsub('%s+$', '') or ''
        if #reason < 3 then return false, 'Tulis alasan penolakan (minimal 3 huruf)' end
        reason = reason:sub(1, 250)
    end

    local row = MySQL.single.await('SELECT id, citizenid, name, model, ticket, status FROM f_dealer_requests WHERE id = ?', { id })
    if not row then return false, 'Permintaan tidak ditemukan' end
    -- setujui: hanya yang menunggu. tolak/batalkan: yang menunggu atau sudah disetujui tapi belum diambil
    local allowed = approve and "status = 'pending'" or "status IN ('pending','approved')"
    local changed = MySQL.update.await(('UPDATE f_dealer_requests SET status = ?, reason = NULLIF(?, \'\'), decided_by = ?, decided_at = NOW() WHERE id = ? AND %s'):format(allowed),
        { approve and 'approved' or 'rejected', approve and '' or reason, adminName(source), id })
    if changed ~= 1 then return false, 'Status permintaan sudah berubah, muat ulang daftar' end

    local label = Dealer.labelOf(row.model)
    if approve then
        Dealer.mail(row.citizenid, 'Kendaraan Donasi Disetujui', approveMail(row, label))
    else
        Dealer.mail(row.citizenid, 'Kendaraan Donasi Ditolak', rejectMail(row, label, reason))
    end

    Dealer.log(source, ('%s %s permintaan #%d %s (%s, tiket %s)%s'):format(adminName(source), approve and 'MENYETUJUI' or 'MENOLAK',
        id, label, row.name, row.ticket, approve and '' or (' alasan: ' .. reason)))
    return true, approve and 'Disetujui, email terkirim ke pemain' or 'Ditolak, email terkirim ke pemain', requestRows()
end)

-- Panel admin tanpa harus ke dealer
lib.addCommand('dealeradmin', { help = 'Kelola kendaraan dealer & permintaan donasi' }, function(source)
    if not Dealer.isAdmin(source) then
        Dealer.notify(source, 'Tidak punya akses', 'error')
        return
    end
    TriggerClientEvent('f_dealer:openAdmin', source)
end)
