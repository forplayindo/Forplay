-- f_graffiti server: graffiti gang dari PNG di images/<gang>/.
--
-- Ringan: tanpa loop. Semua graffiti ada di memori (Records) dan hanya ditulis ke database saat ada
-- aksi. Semua aksi client dicek ulang di sini: anggota gang, desain milik gang, slot, jarak, item,
-- dan lama menyemprot / mengelap (mulai -> selesai, tidak bisa dilewati).

local ox = exports.ox_inventory
local RES = GetCurrentResourceName()
local PNG_SIG = '\137PNG\r\n\26\n'

---@type table<string, { key: string, gang: string, label: string, aspect: number }>
local Designs = {}
---@type table<string, string[]> gang -> daftar kunci desain
local ByGang = {}
---@type table<integer, table>
local Records = {}
---@type table<string, integer>
local Count = {}
---@type table<integer, table> src -> semprotan yang sedang berjalan
local Spraying = {}
---@type table<integer, { id: integer, started: integer }>
local Cleaning = {}
local lastCall = {}
local ready = false
-- Graffiti perang (Gang Wars f_crew): hanya di memori, id negatif supaya tidak bentrok dengan database.
---@type table<string, table<string, integer>> wilayah -> gang -> jumlah semprotan selama perang ini
local WarSprayed = {}
local warSeq = 0

local function notify(src, msg, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Graffiti', description = msg, type = kind or 'inform' })
end

local function log(src, msg)
    print(('^3[f_graffiti]^0 %s: %s'):format(src and src > 0 and GetPlayerName(src) or 'console', msg))
    lib.logger(src or 0, 'f_graffiti', msg)
end

local function throttle(src, ms)
    local now = GetGameTimer()
    if (lastCall[src] or 0) > now then return true end
    lastCall[src] = now + (ms or 300)
    return false
end

---Nama internal gang (crew_<id>) kalau pemain anggota crew bertipe 'gang'.
local function gangOf(src)
    local okGang, isGang = pcall(function() return exports.f_crew:IsGang(src) end)
    if not okGang or not isGang then return nil end
    local player = exports.qbx_core:GetPlayer(src)
    local gang = player and player.PlayerData.gang
    if not gang or not gang.name or gang.name == 'none' then return nil end
    return gang.name, gang.label or gang.name, player
end

local function charName(player)
    local c = player and player.PlayerData.charinfo
    return c and ('%s %s'):format(c.firstname or '', c.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '') or '?'
end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

---------------------------------------------------------------------------
-- Desain (PNG): dicek sekali saat start, ukuran dibaca dari header PNG
---------------------------------------------------------------------------

local function pngSize(path)
    local data = LoadResourceFile(RES, path)
    if not data or #data < 24 or data:sub(1, 8) ~= PNG_SIG then return nil end
    local w, h = string.unpack('>I4>I4', data, 17)
    if w < 1 or h < 1 then return nil end
    return w, h
end

local function loadDesigns()
    Designs, ByGang = {}, {}
    for gang, list in pairs(Config.Designs or {}) do
        if type(gang) == 'string' and gang:match('^[%w_%-]+$') and type(list) == 'table' then
            for _, d in ipairs(list) do
                local file = type(d) == 'table' and d.file
                if type(file) == 'string' and file:match('^[%w_%-%.]+%.png$') then
                    local key = gang .. '/' .. file
                    local w, h = pngSize('images/' .. key)
                    if not w then
                        print(('^1[f_graffiti] images/%s tidak ada atau bukan PNG, dilewati^0'):format(key))
                    else
                        if w > 1024 or h > 1024 then
                            print(('^3[f_graffiti] images/%s %dx%d, sebaiknya maks 1024 (disarankan 512)^0'):format(key, w, h))
                        end
                        Designs[key] = { key = key, gang = gang, label = tostring(d.label or file), aspect = h / w }
                        ByGang[gang] = ByGang[gang] or {}
                        ByGang[gang][#ByGang[gang] + 1] = key
                    end
                else
                    print(('^1[f_graffiti] nama file desain %s tidak valid (huruf/angka/_-. dan .png)^0'):format(tostring(file)))
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

local function v3(t) return vec3(t.x, t.y, t.z) end

---Data yang dikirim ke semua client (tanpa citizenid / nama).
local function public(rec)
    return { id = rec.id, gang = rec.gang, d = rec.design, p = rec.p, n = rec.n, r = rec.r, rot = rec.rot, w = rec.w }
end

local function addRecord(rec)
    Records[rec.id] = rec
    if not rec.war then Count[rec.gang] = (Count[rec.gang] or 0) + 1 end
end

local function dropRecord(id)
    local rec = Records[id]
    if not rec then return nil end
    Records[id] = nil
    if not rec.war then Count[rec.gang] = math.max(0, (Count[rec.gang] or 1) - 1) end
    for src, c in pairs(Cleaning) do
        if c.id == id then Cleaning[src] = nil end
    end
    return rec
end

local function removeRecord(id, by, reason)
    local rec = dropRecord(id)
    if not rec then return false end
    if not rec.war then MySQL.update('DELETE FROM f_graffiti WHERE id = ?', { id }) end
    TriggerClientEvent('f_graffiti:client:remove', -1, id)
    log(by, ('hapus graffiti #%d milik %s (%s)'):format(id, rec.gang, reason))
    return true
end

local function removeGang(gang, reason)
    local n = 0
    for id, rec in pairs(Records) do
        if rec.gang == gang then
            dropRecord(id)
            TriggerClientEvent('f_graffiti:client:remove', -1, id)
            n = n + 1
        end
    end
    MySQL.update('DELETE FROM f_graffiti WHERE gang = ?', { gang })
    if n > 0 then log(nil, ('%d graffiti %s dihapus (%s)'):format(n, gang, reason)) end
end

---------------------------------------------------------------------------
-- Graffiti perang (f_crew Gang Wars)
---------------------------------------------------------------------------

---Wilayah perang (id, nama) kalau titik p ada di wilayah yang sedang diperebutkan gang pemain.
local function warZone(src, p)
    if GetResourceState('f_crew') ~= 'started' then return nil end
    local okCall, id, label = pcall(function() return exports.f_crew:GetWarGraffitiZone(src, p.x, p.y) end)
    if okCall and type(id) == 'string' then return id, label end
end

local function warParticipant(zone, src)
    if GetResourceState('f_crew') ~= 'started' then return nil end
    local okCall, gang = pcall(function() return exports.f_crew:GetWarParticipant(zone, src) end)
    return okCall and gang or nil
end

local function warPoints(zone, gang, sign)
    if GetResourceState('f_crew') ~= 'started' then return false end
    local okCall, done = pcall(function() return exports.f_crew:AddWarGraffitiPoints(zone, gang, sign) end)
    return okCall and done == true
end

local function warCount(zone, gang)
    return WarSprayed[zone] and WarSprayed[zone][gang] or 0
end

---Hapus graffiti perang satu wilayah (zone) atau semuanya (zone = nil).
local function removeWar(zone, reason)
    local n = 0
    for id, rec in pairs(Records) do
        if rec.war and (not zone or rec.war == zone) then
            dropRecord(id)
            TriggerClientEvent('f_graffiti:client:remove', -1, id)
            n = n + 1
        end
    end
    if zone then WarSprayed[zone] = nil else WarSprayed = {} end
    if n > 0 then log(nil, ('%d graffiti perang%s dihapus (%s)'):format(n, zone and (' ' .. zone) or '', reason)) end
end

AddEventHandler('f_crew:server:warEnded', function(zone)
    if type(zone) == 'string' then removeWar(zone, 'perang selesai') end
end)

-- data perang f_crew hanya di memori: kalau f_crew berhenti, graffiti perangnya ikut hilang
AddEventHandler('onResourceStop', function(res)
    if res == 'f_crew' then removeWar(nil, 'f_crew berhenti') end
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS f_graffiti (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        gang VARCHAR(60) NOT NULL,
        design VARCHAR(160) NOT NULL,
        data TEXT NOT NULL,
        citizenid VARCHAR(60) NOT NULL,
        name VARCHAR(100) NOT NULL,
        created INT UNSIGNED NOT NULL,
        PRIMARY KEY (id),
        KEY gang (gang)
    )]])

    -- gang yang sudah bubar saat server mati
    local hasCrew = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'crew_gangs']])
    if hasCrew and hasCrew > 0 then
        local okDel, n = pcall(MySQL.update.await, 'DELETE FROM f_graffiti WHERE gang NOT IN (SELECT name FROM crew_gangs)')
        if okDel and n and n > 0 then print(('[f_graffiti] %d graffiti dari gang yang sudah bubar dihapus'):format(n)) end
    end

    loadDesigns()
    for _, row in ipairs(MySQL.query.await('SELECT * FROM f_graffiti') or {}) do
        local d = json.decode(row.data)
        if d and d.p and d.n and d.r then
            addRecord({
                id = row.id, gang = row.gang, design = row.design,
                p = d.p, n = d.n, r = d.r, rot = d.rot or 0.0, w = d.w or Config.Size.default,
                citizenid = row.citizenid, name = row.name, created = row.created,
            })
        end
    end
    ready = true
    TriggerClientEvent('f_graffiti:client:reload', -1)
end)

lib.callback.register('f_graffiti:getAll', function()
    while not ready do Wait(100) end
    local designs, list = {}, {}
    for key, d in pairs(Designs) do designs[key] = d.aspect end
    for _, rec in pairs(Records) do list[#list + 1] = public(rec) end
    for _, s in pairs(Spraying) do list[#list + 1] = s.temp end
    return { designs = designs, records = list }
end)

---------------------------------------------------------------------------
-- Item berisi beberapa pemakaian (pylox / cleaningkit): sisa di metadata.uses
---------------------------------------------------------------------------

local function usesOf(slot, max)
    return slot.metadata and tonumber(slot.metadata.uses) or max
end

---Slot yang dipakai duluan: yang sudah terpakai sebagian, baru yang masih baru.
local function chargeSlot(src, item, max)
    local slots = ox:GetSlotsWithItem(src, item)
    if not slots or #slots == 0 then return nil end
    local best
    for _, s in ipairs(slots) do
        if not best or usesOf(s, max) < usesOf(best, max) then best = s end
    end
    return best
end

local function chargesLeft(src, item, max)
    local slot = chargeSlot(src, item, max)
    return slot and usesOf(slot, max) or 0
end

local function useCharge(src, item, max, text)
    local slot = chargeSlot(src, item, max)
    if not slot then return false end
    local left = usesOf(slot, max) - 1
    if left <= 0 then
        return ox:RemoveItem(src, item, 1, nil, slot.slot) and true or false
    end

    local meta = {}
    for k, v in pairs(slot.metadata or {}) do meta[k] = v end
    meta.uses = left
    meta.description = text:format(left, max)

    if slot.count == 1 then
        ox:SetMetadata(src, slot.slot, meta)
        return true
    end
    -- satu tumpukan: pisahkan 1 item dengan sisa pemakaiannya sendiri
    if not ox:RemoveItem(src, item, 1, nil, slot.slot) then return false end
    if not ox:AddItem(src, item, 1, meta) then
        ox:AddItem(src, item, 1, slot.metadata)
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Menu (item pylox)
---------------------------------------------------------------------------

local function menuData(src, gang, label)
    local designs, list = {}, {}
    for _, key in ipairs(ByGang[gang] or {}) do
        local d = Designs[key]
        designs[#designs + 1] = { key = key, label = d.label, aspect = d.aspect }
    end
    for _, rec in pairs(Records) do
        if rec.gang == gang and not rec.war then
            local d = Designs[rec.design]
            list[#list + 1] = {
                id = rec.id, design = rec.design, label = d and d.label or 'Desain tidak ada', missing = not d,
                by = rec.name, created = rec.created, p = rec.p,
            }
        end
    end
    table.sort(list, function(a, b) return a.created > b.created end)
    return {
        ok = true, gang = label, designs = designs, list = list, max = Config.MaxPerGang,
        sprayLeft = chargesLeft(src, Config.SprayItem, Config.SprayUses), sprayUses = Config.SprayUses,
    }
end

lib.callback.register('f_graffiti:menu', function(src)
    if not ready then return { ok = false, msg = 'Graffiti belum siap, coba lagi sebentar.' } end
    local gang, label = gangOf(src)
    if not gang then return { ok = false, msg = 'Hanya anggota gang yang bisa memakai pylox.' } end
    return menuData(src, gang, label)
end)

lib.callback.register('f_graffiti:remove', function(src, id)
    if throttle(src, 500) then return { ok = false, msg = 'Pelan-pelan.' } end
    local gang, label = gangOf(src)
    if not gang then return { ok = false, msg = 'Hanya anggota gang.' } end
    local rec = Records[tonumber(id) or -1]
    if not rec or rec.gang ~= gang or rec.war then
        local res = menuData(src, gang, label)
        res.ok, res.msg = false, 'Graffiti tidak ditemukan.'
        return res
    end
    removeRecord(rec.id, src, 'dihapus anggota lewat menu')
    local res = menuData(src, gang, label)
    res.msg = 'Graffiti dihapus.'
    return res
end)

---------------------------------------------------------------------------
-- Menyemprot: mulai -> selesai (server menghitung waktunya)
---------------------------------------------------------------------------

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if lo and v < lo then return nil end
    if hi and v > hi then return nil end
    return v
end

local function vec(t, lo, hi)
    if type(t) ~= 'table' then return nil end
    local x, y, z = num(t.x, lo, hi), num(t.y, lo, hi), num(t.z, lo, hi)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z }
end

local function cancelSpray(src)
    local s = Spraying[src]
    if not s then return end
    Spraying[src] = nil
    TriggerClientEvent('f_graffiti:client:remove', -1, s.temp.id)
end

lib.callback.register('f_graffiti:sprayBegin', function(src, data)
    if not ready or throttle(src, 500) or type(data) ~= 'table' then return false, 'Coba lagi.' end
    if Spraying[src] or Cleaning[src] then return false, 'Sedang sibuk.' end

    local gang = gangOf(src)
    if not gang then return false, 'Hanya anggota gang yang bisa menyemprot.' end
    local design = Designs[data.d]
    if not design or design.gang ~= gang then return false, 'Desain tidak tersedia untuk gangmu.' end
    if chargesLeft(src, Config.SprayItem, Config.SprayUses) <= 0 then return false, 'Kamu tidak punya pylox.' end

    local p = vec(data.p, -20000, 20000)
    local n, r = vec(data.n, -1.01, 1.01), vec(data.r, -1.01, 1.01)
    local w = num(data.w, Config.Size.min - 0.001, Config.Size.max + 0.001)
    local rot = num(data.rot, -360, 360)
    if not (p and n and r and w and rot) then return false, 'Data tidak valid.' end
    local nv, rv = v3(n), v3(r)
    if math.abs(#nv - 1.0) > 0.02 or math.abs(#rv - 1.0) > 0.02 or math.abs(nv.x * rv.x + nv.y * rv.y + nv.z * rv.z) > 0.03 then
        return false, 'Data tidak valid.'
    end

    local pos = pedPos(src)
    if not pos or #(pos - v3(p)) > Config.PlaceDistance + 1.5 then return false, 'Terlalu jauh dari tembok.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Turun dari kendaraan dulu.' end

    -- di wilayah perang gangmu = graffiti perang (slot sendiri), selain itu graffiti biasa
    local war, warLabel = warZone(src, p)
    if war then
        if warCount(war, gang) >= Config.WarMaxPerGang then
            return false, ('Gangmu sudah %d kali menyemprot di perang %s.'):format(Config.WarMaxPerGang, warLabel or war)
        end
    elseif (Count[gang] or 0) >= Config.MaxPerGang then
        return false, ('Graffiti gangmu sudah %d. Bersihkan atau hapus salah satu dulu.'):format(Config.MaxPerGang)
    end

    local temp = { id = 'p' .. src, gang = gang, d = design.key, p = p, n = n, r = r, rot = rot, w = w, spraying = true }
    Spraying[src] = { gang = gang, design = design.key, p = p, n = n, r = r, rot = rot, w = w, started = GetGameTimer(), temp = temp, war = war }
    TriggerClientEvent('f_graffiti:client:add', -1, temp)
    return true
end)

lib.callback.register('f_graffiti:sprayFinish', function(src)
    local s = Spraying[src]
    if not s then return false, 'Tidak sedang menyemprot.' end
    Spraying[src] = nil
    TriggerClientEvent('f_graffiti:client:remove', -1, s.temp.id)

    if GetGameTimer() - s.started < Config.SprayTime - 750 then return false, 'Terlalu cepat.' end
    local gang, _, player = gangOf(src)
    if gang ~= s.gang then return false, 'Kamu bukan anggota gang ini lagi.' end
    if s.war then
        if warZone(src, s.p) ~= s.war then return false, 'Perang di wilayah ini sudah selesai.' end
        if warCount(s.war, gang) >= Config.WarMaxPerGang then return false, 'Jatah graffiti perang gangmu sudah habis.' end
    elseif (Count[gang] or 0) >= Config.MaxPerGang then
        return false, 'Slot graffiti gangmu sudah penuh.'
    end
    local pos = pedPos(src)
    if not pos or #(pos - v3(s.p)) > Config.PlaceDistance + 2.0 then return false, 'Kamu menjauh dari tembok.' end
    if not useCharge(src, Config.SprayItem, Config.SprayUses, 'Sisa semprotan: %dx dari %d.') then
        return false, 'Kamu tidak punya pylox.'
    end

    local now = os.time()
    local name = charName(player)

    if s.war then
        -- graffiti perang: memori saja, hilang saat perang selesai
        warSeq = warSeq - 1
        local rec = {
            id = warSeq, gang = gang, design = s.design, p = s.p, n = s.n, r = s.r, rot = s.rot, w = s.w,
            citizenid = player.PlayerData.citizenid, name = name, created = now, war = s.war,
        }
        addRecord(rec)
        WarSprayed[s.war] = WarSprayed[s.war] or {}
        WarSprayed[s.war][gang] = warCount(s.war, gang) + 1
        TriggerClientEvent('f_graffiti:client:add', -1, public(rec))
        local scored = warPoints(s.war, gang, 1)
        log(src, ('semprot graffiti perang %s (%s) di wilayah %s%s'):format(s.design, gang, s.war, scored and '' or ' (poin tidak masuk)'))
        return true, ('Graffiti perang terpasang%s (%d/%d).'):format(scored and ', poin gangmu bertambah' or '',
            WarSprayed[s.war][gang], Config.WarMaxPerGang)
    end
    local data = { p = s.p, n = s.n, r = s.r, rot = s.rot, w = s.w }
    local id = MySQL.insert.await('INSERT INTO f_graffiti (gang, design, data, citizenid, name, created) VALUES (?, ?, ?, ?, ?, ?)',
        { gang, s.design, json.encode(data), player.PlayerData.citizenid, name, now })
    if not id then return false, 'Gagal menyimpan graffiti.' end

    local rec = {
        id = id, gang = gang, design = s.design, p = s.p, n = s.n, r = s.r, rot = s.rot, w = s.w,
        citizenid = player.PlayerData.citizenid, name = name, created = now,
    }
    addRecord(rec)
    TriggerClientEvent('f_graffiti:client:add', -1, public(rec))
    log(src, ('semprot graffiti #%d %s (%s) di %.1f, %.1f, %.1f'):format(id, s.design, gang, s.p.x, s.p.y, s.p.z))
    return true, ('Graffiti terpasang (%d/%d).'):format(Count[gang], Config.MaxPerGang)
end)

RegisterNetEvent('f_graffiti:server:sprayCancel', function()
    cancelSpray(source)
end)

---------------------------------------------------------------------------
-- Membersihkan (siapa saja yang membawa alat pembersih)
---------------------------------------------------------------------------

local function stopClean(src)
    local c = Cleaning[src]
    if not c then return end
    Cleaning[src] = nil
    if Records[c.id] then TriggerClientEvent('f_graffiti:client:cleaning', -1, c.id, false) end
end

lib.callback.register('f_graffiti:cleanBegin', function(src, id)
    if not ready or throttle(src, 500) then return false, 'Coba lagi.' end
    if Spraying[src] or Cleaning[src] then return false, 'Sedang sibuk.' end
    local rec = Records[tonumber(id) or -1]
    if not rec then return false, 'Graffiti sudah tidak ada.' end
    for _, c in pairs(Cleaning) do
        if c.id == rec.id then return false, 'Graffiti ini sedang dibersihkan orang lain.' end
    end
    if chargesLeft(src, Config.CleanItem, Config.CleanUses) <= 0 then return false, 'Kamu butuh Alat Pembersih.' end
    local pos = pedPos(src)
    if not pos or #(pos - v3(rec.p)) > Config.CleanDistance + 1.0 then return false, 'Terlalu jauh.' end

    Cleaning[src] = { id = rec.id, started = GetGameTimer() }
    TriggerClientEvent('f_graffiti:client:cleaning', -1, rec.id, true)
    return true
end)

lib.callback.register('f_graffiti:cleanFinish', function(src)
    local c = Cleaning[src]
    if not c then return false, 'Tidak sedang membersihkan.' end
    Cleaning[src] = nil

    local rec = Records[c.id]
    if not rec then return false, 'Graffiti sudah tidak ada.' end
    local function fail(msg)
        TriggerClientEvent('f_graffiti:client:cleaning', -1, rec.id, false)
        return false, msg
    end
    if GetGameTimer() - c.started < Config.CleanTime - 750 then return fail('Terlalu cepat.') end
    local pos = pedPos(src)
    if not pos or #(pos - v3(rec.p)) > Config.CleanDistance + 1.5 then return fail('Kamu menjauh dari graffiti.') end
    if not useCharge(src, Config.CleanItem, Config.CleanUses, 'Sisa membersihkan graffiti: %dx dari %d.') then
        return fail('Kamu butuh Alat Pembersih.')
    end

    -- graffiti perang dibersihkan peserta perang itu (musuh / gangnya sendiri): poin pemiliknya berkurang.
    -- Pembersih netral (polisi / warga / gang lain) tidak mengubah poin.
    local penalty = rec.war and warParticipant(rec.war, src) and warPoints(rec.war, rec.gang, -1)
    removeRecord(rec.id, src, penalty and 'dibersihkan peserta perang, poin pemilik -1' or 'dibersihkan')
    return true, penalty and 'Graffiti perang dibersihkan, poin gang pemiliknya berkurang.' or 'Graffiti dibersihkan.'
end)

RegisterNetEvent('f_graffiti:server:cleanCancel', function()
    stopClean(source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    cancelSpray(src)
    stopClean(src)
    lastCall[src] = nil
end)

---------------------------------------------------------------------------
-- Gang bubar (f_crew) & admin
---------------------------------------------------------------------------

AddEventHandler('f_crew:server:gangDisbanded', function(gang)
    if type(gang) == 'string' then removeGang(gang, 'gang bubar') end
end)

lib.addCommand(Config.AdminCommand, {
    help = ('Hapus graffiti dalam radius %d m, atau "semua" untuk seluruh map'):format(Config.AdminRadius),
    params = { { name = 'semua', type = 'string', help = 'ketik semua untuk hapus seluruh map', optional = true } },
    restricted = 'group.admin',
}, function(src, args)
    local n = 0
    if args.semua == 'semua' then
        for id in pairs(Records) do
            dropRecord(id)
            TriggerClientEvent('f_graffiti:client:remove', -1, id)
            n = n + 1
        end
        MySQL.update.await('DELETE FROM f_graffiti')
    else
        local pos = src > 0 and pedPos(src)
        if not pos then return end
        for id, rec in pairs(Records) do
            if #(pos - v3(rec.p)) <= Config.AdminRadius then
                removeRecord(id, src, 'admin')
                n = n + 1
            end
        end
    end
    log(src, ('admin menghapus %d graffiti%s'):format(n, args.semua == 'semua' and ' (semua)' or ''))
    if src > 0 then notify(src, ('%d graffiti dihapus.'):format(n), 'success') end
end)
