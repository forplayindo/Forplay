-- f_dealer server: semua harga, uang, plat, kunci, dan status donasi diputuskan di sini.
-- Daftar toko di-cache di memori (dibaca DB sekali saat start, diperbarui saat admin mengubah).
Dealer = {
    shop = {},        -- [model] = { model, label, brand, category, price, donation }
    list = {},        -- array siap kirim ke NUI
    busy = {},        -- [src] = true saat aksi berjalan
    testing = {},     -- [src] = data test drive (diisi server/testdrive.lua)
}

local DONATION = Config.DonationCategory
local CATEGORY = {}
for i, c in ipairs(Config.Categories) do CATEGORY[c.key] = i end
Dealer.CATEGORY = CATEGORY

---------------------------------------------------------------------------
-- Util
---------------------------------------------------------------------------
function Dealer.rupiah(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
    return 'Rp ' .. out:gsub('^%.', '')
end

-- Katalog qbx_core diambil SEKALI (export lintas resource menyalin seluruh tabel tiap panggilan)
local VEHICLES
function Dealer.vehicles()
    if not VEHICLES then VEHICLES = exports.qbx_core:GetVehiclesByName() or {} end
    return VEHICLES
end

function Dealer.catalog(model)
    return Dealer.vehicles()[model]
end

function Dealer.labelOf(model)
    local v = Dealer.catalog(model)
    if not v then return model end
    local label = ('%s %s'):format(v.brand or '', v.name or model):gsub('^%s+', '')
    return label
end

function Dealer.notify(src, text, kind, duration)
    exports.qbx_core:Notify(src, text, kind or 'inform', duration)
end

function Dealer.log(src, text)
    pcall(function() exports.f_admin:Log(src, 'vehicle', '[Dealer] ' .. text) end)
end

function Dealer.isAdmin(src)
    local ok, role = pcall(function() return exports.f_admin:GetRole(src) end)
    if ok then return role == 'owner' or role == 'admin' end
    return IsPlayerAceAllowed(tostring(src), 'admin')
end

---Email f_phone (bisa ke pemain offline lewat citizenid). Tanpa akun Mail jatuh ke notifikasi kalau online.
function Dealer.mail(citizenid, subject, lines)
    local body = table.concat(lines, '\n')
    local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(citizenid) end)
    if okA and type(addresses) == 'table' and #addresses > 0 then
        local to = {}
        for i = 1, #addresses do to[i] = addresses[i].email end
        local okS, res = pcall(function()
            return exports['f_phone']:sendMail({ to = to, subject = subject, body = body, from = { name = Config.MailFrom, email = '' } })
        end)
        if okS and res and (res.delivered or 0) > 0 then return true end
    end
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenid)
    if player then
        Dealer.notify(player.PlayerData.source, subject, 'inform', 10000)
    end
    return false
end

local function nearDealer(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - Config.Ped.coords.xyz) <= Config.ServerRadius
end
Dealer.nearDealer = nearDealer

local function freeSpawn()
    local vehicles = GetAllVehicles()
    for _, spot in ipairs(Config.Spawns) do
        local free = true
        for i = 1, #vehicles do
            if #(GetEntityCoords(vehicles[i]) - spot.xyz) < 3.0 then
                free = false
                break
            end
        end
        if free then return spot end
    end
end

---------------------------------------------------------------------------
-- Database + cache
---------------------------------------------------------------------------
function Dealer.rebuild()
    local list = {}
    for _, v in pairs(Dealer.shop) do list[#list + 1] = v end
    table.sort(list, function(a, b)
        local ca, cb = CATEGORY[a.category] or 99, CATEGORY[b.category] or 99
        if ca ~= cb then return ca < cb end
        if a.price ~= b.price then return a.price < b.price end
        return a.label < b.label
    end)
    Dealer.list = list
end

function Dealer.setShopEntry(model, category, price)
    local c = Dealer.catalog(model)
    if not c then return nil end
    local entry = {
        model = model,
        label = Dealer.labelOf(model),
        brand = c.brand or '',
        category = category,
        price = category == DONATION and 0 or price,
        donation = category == DONATION,
    }
    Dealer.shop[model] = entry
    return entry
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dealer_vehicles (
        model VARCHAR(60) NOT NULL PRIMARY KEY,
        category VARCHAR(30) NOT NULL,
        price BIGINT UNSIGNED NOT NULL DEFAULT 0,
        added_by VARCHAR(100) NULL,
        added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_dealer_requests (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        name VARCHAR(100) NOT NULL,
        model VARCHAR(60) NOT NULL,
        ticket VARCHAR(40) NOT NULL,
        status ENUM('pending','approved','rejected','claimed') NOT NULL DEFAULT 'pending',
        reason VARCHAR(255) NULL,
        decided_by VARCHAR(100) NULL,
        plate VARCHAR(10) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        decided_at TIMESTAMP NULL,
        claimed_at TIMESTAMP NULL,
        KEY idx_citizen (citizenid),
        KEY idx_status (status),
        KEY idx_ticket (ticket)
    )]])

    local rows = MySQL.query.await('SELECT model, category, price FROM f_dealer_vehicles') or {}
    local missing = 0
    for _, r in ipairs(rows) do
        if CATEGORY[r.category] and Dealer.setShopEntry(r.model, r.category, tonumber(r.price) or 0) then
            -- ok
        else
            missing += 1
        end
    end
    Dealer.rebuild()
    if missing > 0 then
        print(('^3[f_dealer] %d kendaraan di DB dilewati (model tidak ada di qbx_core atau kategori tidak dikenal)^7'):format(missing))
    end
end)

---------------------------------------------------------------------------
-- Serah kendaraan: catat di DB, spawn di garasi dealer, pemain duduk di kursi sopir, kunci fisik
---------------------------------------------------------------------------
---@return boolean ok, string? plate, boolean? spawned
local function deliver(src, citizenid, model, spot)
    local plate = exports.f_vehicles:GeneratePlate()
    local vehicleId, err = exports.f_vehicles:CreatePlayerVehicle({
        model = model,
        citizenid = citizenid,
        props = { plate = plate, fuelLevel = 100.0 },
    })
    if not vehicleId then
        print(('^1[f_dealer] gagal membuat kendaraan %s untuk %s: %s^7'):format(model, citizenid, json.encode(err)))
        return false
    end

    local _, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = spot,
        warp = GetPlayerPed(src),
        bucket = GetPlayerRoutingBucket(src),
        props = { plate = plate },
    })
    if not veh or veh == 0 then
        MySQL.update.await('UPDATE player_vehicles SET state = 1, garage = ? WHERE id = ?', { Config.FallbackGarage, vehicleId })
        print(('^3[f_dealer] %s (id %s) gagal di-spawn, dimasukkan ke garasi %s^7'):format(plate, vehicleId, Config.FallbackGarage))
        return true, plate, false
    end

    Entity(veh).state:set('vehicleid', vehicleId, true)
    Entity(veh).state:set('fuel', 100.0, true)
    exports.f_vehicles:EnsureAppearance(veh, vehicleId)
    exports.f_vehiclekeys:GiveKeys(src, veh)
    return true, plate, true
end

local function deliveredText(label, plate, spawned)
    if spawned then
        return ('%s (%s) siap di garasi dealer, kuncinya ada di tasmu'):format(label, plate)
    end
    return ('%s (%s) sudah tercatat, ambil di garasi %s'):format(label, plate, Config.FallbackGarage)
end

---------------------------------------------------------------------------
-- Status permintaan donasi milik karakter ini, per model
---------------------------------------------------------------------------
local function requestStatus(citizenid)
    local rows = MySQL.query.await([[SELECT model, status, reason FROM f_dealer_requests
        WHERE citizenid = ? AND status IN ('pending','approved','rejected') ORDER BY id]], { citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local cur = out[r.model]
        -- yang masih aktif (menunggu / disetujui) selalu menang dari penolakan lama
        if not cur or r.status ~= 'rejected' or cur.status == 'rejected' then
            out[r.model] = { status = r.status, reason = r.reason }
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Callback NUI
---------------------------------------------------------------------------
lib.callback.register('f_dealer:open', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local requests = requestStatus(player.PlayerData.citizenid)

    -- kendaraan donasi yang sudah disetujui tetap bisa diambil walau admin sudah menghapusnya dari toko
    local list = Dealer.list
    local extra
    for model, r in pairs(requests) do
        if r.status == 'approved' and not Dealer.shop[model] and Dealer.catalog(model) then
            extra = extra or {}
            extra[#extra + 1] = { model = model, label = Dealer.labelOf(model), brand = Dealer.catalog(model).brand or '', category = DONATION, price = 0, donation = true }
        end
    end
    if extra then
        list = {}
        for i = 1, #Dealer.list do list[i] = Dealer.list[i] end
        for i = 1, #extra do list[#list + 1] = extra[i] end
    end

    return {
        title = Config.Title,
        categories = Config.Categories,
        vehicles = list,
        requests = requests,
        money = { cash = player.PlayerData.money.cash or 0, bank = player.PlayerData.money.bank or 0 },
        admin = Dealer.isAdmin(source),
        testSeconds = Config.TestDrive.seconds,
    }
end)

local function guard(src, fn, ...)
    if Dealer.busy[src] then return false, 'Tunggu sebentar...' end
    Dealer.busy[src] = true
    local ok, a, b = pcall(fn, src, ...)
    Dealer.busy[src] = nil
    if not ok then
        print(('^1[f_dealer] error: %s^7'):format(a))
        return false, 'Terjadi kesalahan, hubungi admin'
    end
    return a, b
end
Dealer.guard = guard

local function commonCheck(src)
    if Dealer.testing[src] then return 'Selesaikan test drive dulu' end
    if not nearDealer(src) then return 'Kamu terlalu jauh dari dealer' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return 'Turun dari kendaraan dulu' end
end

local function buy(src, model, method)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Data pemain tidak ditemukan' end
    local bad = commonCheck(src)
    if bad then return false, bad end

    local v = type(model) == 'string' and Dealer.shop[model]
    if not v then return false, 'Kendaraan tidak dijual' end
    if v.donation then return false, 'Kendaraan donasi tidak bisa dibeli langsung' end
    if method ~= 'cash' and method ~= 'bank' then return false, 'Metode pembayaran tidak valid' end
    if v.price <= 0 then return false, 'Harga belum diatur admin' end

    if (player.Functions.GetMoney(method) or 0) < v.price then
        return false, method == 'cash' and 'Uang tunai tidak cukup' or 'Saldo bank tidak cukup'
    end
    local spot = freeSpawn()
    if not spot then return false, 'Garasi dealer penuh, coba lagi sebentar' end

    if not player.Functions.RemoveMoney(method, v.price, 'dealer-beli-' .. model) then
        return false, 'Pembayaran gagal'
    end

    local ok, plate, spawned = deliver(src, player.PlayerData.citizenid, model, spot)
    if not ok then
        player.Functions.AddMoney(method, v.price, 'dealer-refund-' .. model)
        return false, 'Kendaraan gagal dibuat, uang dikembalikan'
    end

    Dealer.log(src, ('%s membeli %s (%s) %s via %s'):format(GetPlayerName(src), v.label, plate, Dealer.rupiah(v.price), method))
    return true, deliveredText(v.label, plate, spawned)
end

lib.callback.register('f_dealer:buy', function(source, model, method)
    return guard(source, buy, model, method)
end)

---------------------------------------------------------------------------
-- Donasi: ajukan dengan nomor tiket Discord, lalu ambil setelah disetujui
---------------------------------------------------------------------------
local ticketLock = {}

local function normalizeTicket(ticket)
    if type(ticket) ~= 'string' then return end
    ticket = ticket:gsub('^%s+', ''):gsub('%s+$', '')
    if #ticket < 1 or #ticket > Config.Donation.ticketMax then return end
    if not ticket:find(Config.Donation.ticketPattern) then return end
    return ticket
end

local function notifyAdmins(text)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if Dealer.isAdmin(src) then Dealer.notify(src, text, 'inform', 8000) end
    end
end

local function request(src, model, rawTicket)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Data pemain tidak ditemukan' end
    local bad = commonCheck(src)
    if bad then return false, bad end

    local v = type(model) == 'string' and Dealer.shop[model]
    if not v or not v.donation then return false, 'Kendaraan ini bukan kendaraan donasi' end
    local ticket = normalizeTicket(rawTicket)
    if not ticket then return false, 'Nomor tiket tidak valid (huruf, angka, - # _ maks 32)' end

    local cid = player.PlayerData.citizenid
    local active = MySQL.query.await([[SELECT model, status FROM f_dealer_requests
        WHERE citizenid = ? AND status IN ('pending','approved')]], { cid }) or {}
    local pending = 0
    for _, r in ipairs(active) do
        if r.model == model then
            return false, r.status == 'approved' and 'Permintaan sudah disetujui, tinggal ambil kendaraannya' or 'Permintaan kendaraan ini masih menunggu admin'
        end
        if r.status == 'pending' then pending += 1 end
    end
    if pending >= Config.Donation.maxPending then
        return false, ('Maksimal %d permintaan menunggu sekaligus'):format(Config.Donation.maxPending)
    end

    local key = ticket:lower()
    if ticketLock[key] then return false, 'Tunggu sebentar...' end
    ticketLock[key] = true
    local used = MySQL.scalar.await([[SELECT 1 FROM f_dealer_requests
        WHERE LOWER(ticket) = ? AND status <> 'rejected' LIMIT 1]], { key })
    if used then
        ticketLock[key] = nil
        return false, 'Nomor tiket ini sudah dipakai (1 tiket = 1 kendaraan)'
    end
    local ci = player.PlayerData.charinfo
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''):gsub('^%s+', '')
    MySQL.insert.await('INSERT INTO f_dealer_requests (citizenid, name, model, ticket) VALUES (?, ?, ?, ?)', { cid, name, model, ticket })
    ticketLock[key] = nil

    Dealer.log(src, ('%s (%s) mengajukan donasi %s, tiket %s'):format(name, cid, v.label, ticket))
    notifyAdmins(('Permintaan kendaraan donasi baru: %s (tiket %s)'):format(v.label, ticket))
    return true, 'Permintaan terkirim. Tunggu email dari dealer setelah admin mengecek tiketmu.'
end

lib.callback.register('f_dealer:request', function(source, model, ticket)
    return guard(source, request, model, ticket)
end)

local function claim(src, model)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Data pemain tidak ditemukan' end
    local bad = commonCheck(src)
    if bad then return false, bad end
    if type(model) ~= 'string' or not Dealer.catalog(model) then return false, 'Kendaraan tidak ditemukan' end

    local cid = player.PlayerData.citizenid
    local id = MySQL.scalar.await([[SELECT id FROM f_dealer_requests
        WHERE citizenid = ? AND model = ? AND status = 'approved' ORDER BY id LIMIT 1]], { cid, model })
    if not id then return false, 'Belum ada persetujuan untuk kendaraan ini' end

    local spot = freeSpawn()
    if not spot then return false, 'Garasi dealer penuh, coba lagi sebentar' end

    -- kunci baris dulu: hanya satu klaim yang bisa mengubah approved → claimed
    if MySQL.update.await("UPDATE f_dealer_requests SET status = 'claimed', claimed_at = NOW() WHERE id = ? AND status = 'approved'", { id }) ~= 1 then
        return false, 'Kendaraan ini sudah diambil'
    end

    local ok, plate, spawned = deliver(src, cid, model, spot)
    if not ok then
        MySQL.update.await("UPDATE f_dealer_requests SET status = 'approved', claimed_at = NULL WHERE id = ?", { id })
        return false, 'Kendaraan gagal dibuat, coba lagi'
    end
    MySQL.update.await('UPDATE f_dealer_requests SET plate = ? WHERE id = ?', { plate, id })

    local label = Dealer.labelOf(model)
    Dealer.log(src, ('%s (%s) mengambil kendaraan donasi %s (%s), permintaan #%s'):format(GetPlayerName(src), cid, label, plate, id))
    return true, deliveredText(label, plate, spawned)
end

lib.callback.register('f_dealer:claim', function(source, model)
    return guard(source, claim, model)
end)

AddEventHandler('playerDropped', function()
    Dealer.busy[source] = nil
end)
