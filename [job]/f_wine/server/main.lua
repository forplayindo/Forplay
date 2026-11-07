local config = require 'config.shared'
local kebun = require 'config.kebun'

-- src -> { cid, keranjang = { state = 'bawa'|'tanah', pos, jenis, n, jauhSejak }, pegang = jenis|nil, injak = { pos, mulai } }
local workers = {}
local dipetik = {}     -- cid -> { [spot] = { [idx] = os.time() siap lagi } } (memori, per pemain)
local injakKunci = {}  -- kunci pos injak -> src yang sedang menginjak
local jeda = {}        -- src -> { aksi -> GetGameTimer() }

---------------------------------------------------------------------------
-- helper
---------------------------------------------------------------------------
local function cidOf(src)
    local p = exports.qbx_core:GetPlayer(src)
    return p and p.PlayerData.citizenid
end

local function pedPos(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function dekat(src, c, d)
    return #(pedPos(src) - vec3(c.x, c.y, c.z)) <= d
end

local function spam(src, aksi, ms)
    jeda[src] = jeda[src] or {}
    local now = GetGameTimer()
    if jeda[src][aksi] and now - jeda[src][aksi] < ms then return true end
    jeda[src][aksi] = now
    return false
end

local function itemLabel(name)
    local it = exports.ox_inventory:Items(name)
    return it and it.label or name
end

---------------------------------------------------------------------------
-- statistik harian + tong fermentasi (KVP, tetap ada walau logout / restart)
---------------------------------------------------------------------------
local function statKey(cid) return ('f_wine:stat:%s:%s'):format(cid, os.date('%Y-%m-%d')) end

local function getStat(cid)
    local s = GetResourceKvpString(statKey(cid))
    return s and json.decode(s) or { t = 0, j = 0, w = 0 }
end

local function addStat(cid, k, n)
    local s = getStat(cid)
    s[k] = (s[k] or 0) + n
    SetResourceKvp(statKey(cid), json.encode(s))
end

local function getTong(cid)
    local s = GetResourceKvpString('f_wine:tong:' .. cid)
    local raw = s and json.decode(s) or {}
    local t = {}
    for i = 1, config.tongPerPemain do
        local d = raw[i]
        t[i] = (type(d) == 'table' and d.j) and { j = d.j, n = d.n, r = d.r } or {}
    end
    return t
end

local function setTong(cid, t)
    SetResourceKvp('f_wine:tong:' .. cid, json.encode(t))
end

local function tongView(cid)
    local now, out = os.time(), {}
    for i, d in ipairs(getTong(cid)) do
        if d.j then
            out[i] = { j = d.j, n = d.n, sisa = math.max(0, d.r - now), wine = d.n * config.botolPerJus }
        else
            out[i] = {}
        end
    end
    return out
end

local function jusCount(src)
    local out = {}
    for key, j in pairs(config.jenis) do
        out[key] = exports.ox_inventory:Search(src, 'count', j.jus) or 0
    end
    return out
end

-- tandan yang masih tumbuh milik pemain ini: { 'spot:idx' = detik sisa }
local function dipetikView(cid)
    local now, out = os.time(), {}
    for s, list in pairs(dipetik[cid] or {}) do
        for i, siap in pairs(list) do
            if siap > now then out[s .. ':' .. i] = siap - now end
        end
    end
    return out
end

local function lepasInjak(src)
    local w = workers[src]
    if w and w.injak then
        if injakKunci[w.injak.pos] == src then injakKunci[w.injak.pos] = nil end
        w.injak = nil
    end
    for k, s in pairs(injakKunci) do
        if s == src then injakKunci[k] = nil end
    end
end

---------------------------------------------------------------------------
-- Mandor
---------------------------------------------------------------------------
lib.callback.register('f_wine:server:menu', function(src)
    if not dekat(src, config.lokasi.mandor, config.jarak.mandor + 1.0) then return false end
    local cid = cidOf(src)
    if not cid then return false end
    local w = workers[src]
    return {
        kerja = w ~= nil,
        isi = w and w.keranjang.n or 0,
        stat = getStat(cid),
        tong = tongView(cid),
    }
end)

lib.callback.register('f_wine:server:mulai', function(src)
    if not dekat(src, config.lokasi.mandor, config.jarak.mandor + 1.0) then return { ok = false } end
    if workers[src] then return { ok = false, msg = 'Kamu sudah bekerja.' } end
    local cid = cidOf(src)
    if not cid then return { ok = false } end
    workers[src] = { cid = cid, keranjang = { state = 'bawa', n = 0 } }
    return { ok = true, dipetik = dipetikView(cid) }
end)

lib.callback.register('f_wine:server:selesai', function(src)
    if not workers[src] then return { ok = true } end
    lepasInjak(src)
    workers[src] = nil
    return { ok = true }
end)

---------------------------------------------------------------------------
-- keranjang
---------------------------------------------------------------------------
lib.callback.register('f_wine:server:taruh', function(src, pos)
    local w = workers[src]
    if not w or w.keranjang.state ~= 'bawa' or w.injak then return { ok = false } end
    if type(pos) ~= 'vector3' or #(pedPos(src) - pos) > 2.5 then pos = pedPos(src) end
    w.keranjang.state, w.keranjang.pos, w.keranjang.jauhSejak = 'tanah', pos, nil
    return { ok = true }
end)

lib.callback.register('f_wine:server:angkat', function(src)
    local w = workers[src]
    if not w or w.keranjang.state ~= 'tanah' then return { ok = false } end
    if w.pegang then return { ok = false, msg = 'Masukkan dulu anggur di tanganmu ke keranjang.' } end
    if #(pedPos(src) - w.keranjang.pos) > config.jarak.keranjang + 0.5 then return { ok = false } end
    w.keranjang.state, w.keranjang.pos = 'bawa', nil
    return { ok = true }
end)

---------------------------------------------------------------------------
-- petik -> pegang di tangan -> masukkan ke keranjang
---------------------------------------------------------------------------
lib.callback.register('f_wine:server:petik', function(src, spot, idx)
    local w = workers[src]
    if not w then return { ok = false } end
    local s = kebun[spot]
    local t = s and s.t[idx]
    if not t then return { ok = false } end
    if spam(src, 'petik', 2500) then return { ok = false } end
    if w.pegang then return { ok = false, msg = 'Masukkan dulu anggur di tanganmu ke keranjang.' } end
    if w.keranjang.state ~= 'tanah' then return { ok = false, msg = 'Taruh keranjangmu dulu di dekat pohon.' } end
    if #(w.keranjang.pos - s.c) > config.jarak.keranjangKeTandan then
        return { ok = false, msg = 'Keranjangmu terlalu jauh. Taruh keranjang di dekat pohon ini.' }
    end
    local k = w.keranjang
    if k.n >= config.keranjangMax then return { ok = false, msg = 'Keranjang sudah penuh. Bawa ke pos injak anggur.' } end
    if k.n > 0 and k.jenis ~= s.j then
        return { ok = false, msg = ('Keranjangmu berisi %s. Satu keranjang hanya untuk satu jenis anggur.'):format(config.jenis[k.jenis].anggur) }
    end
    if #(pedPos(src) - t.xyz) > config.jarak.petik + 0.6 then return { ok = false } end

    dipetik[w.cid] = dipetik[w.cid] or {}
    dipetik[w.cid][spot] = dipetik[w.cid][spot] or {}
    local now = os.time()
    if (dipetik[w.cid][spot][idx] or 0) > now then return { ok = false, msg = 'Tandan ini belum tumbuh lagi.' } end
    dipetik[w.cid][spot][idx] = now + config.tumbuhMenit * 60
    w.pegang = s.j
    return { ok = true, jenis = s.j, tumbuh = config.tumbuhMenit * 60 }
end)

lib.callback.register('f_wine:server:masukkan', function(src)
    local w = workers[src]
    if not w or not w.pegang then return { ok = false } end
    if spam(src, 'masukkan', 700) then return { ok = false } end
    local k = w.keranjang
    if k.state ~= 'tanah' or #(pedPos(src) - k.pos) > config.jarak.keranjang + 0.5 then return { ok = false } end
    if k.n >= config.keranjangMax then return { ok = false, msg = 'Keranjang sudah penuh.' } end
    k.jenis = w.pegang
    k.n += 1
    w.pegang = nil
    addStat(w.cid, 't', 1)
    return { ok = true, n = k.n, jenis = k.jenis }
end)

---------------------------------------------------------------------------
-- injak anggur di pos blok -> 1 botol jus
---------------------------------------------------------------------------
lib.callback.register('f_wine:server:mulaiInjak', function(src, pos)
    local w = workers[src]
    local p = config.lokasi.injak[pos]
    if not w or not p or w.injak then return { ok = false } end
    local k = w.keranjang
    if k.state ~= 'bawa' then return { ok = false } end
    if k.n < config.keranjangMax then
        return { ok = false, msg = ('Keranjang belum penuh (%d/%d).'):format(k.n, config.keranjangMax) }
    end
    if not dekat(src, p, config.jarak.injak + 0.5) then return { ok = false } end
    local s = injakKunci[pos]
    if s and s ~= src and workers[s] and workers[s].injak then
        return { ok = false, msg = 'Tong ini sedang dipakai orang lain. Tunggu sebentar.' }
    end
    injakKunci[pos] = src
    w.injak = { pos = pos, mulai = os.time() }
    return { ok = true, jenis = k.jenis }
end)

lib.callback.register('f_wine:server:selesaiInjak', function(src)
    local w = workers[src]
    if not w or not w.injak then return { ok = false } end
    local p = config.lokasi.injak[w.injak.pos]
    if os.time() - w.injak.mulai < config.injakMinDetik or not dekat(src, p, config.jarak.injak + 2.0) then
        lepasInjak(src)
        return { ok = false }
    end
    local j = config.jenis[w.keranjang.jenis]
    if not j or w.keranjang.n < config.keranjangMax then lepasInjak(src) return { ok = false } end
    if not exports.ox_inventory:CanCarryItem(src, j.jus, 1) then
        lepasInjak(src)
        return { ok = false, msg = 'Tasmu penuh. Kosongkan sedikit lalu injak lagi.' }
    end
    exports.ox_inventory:AddItem(src, j.jus, 1)
    w.keranjang.n, w.keranjang.jenis = 0, nil
    lepasInjak(src)
    addStat(w.cid, 'j', 1)
    return { ok = true, label = itemLabel(j.jus) }
end)

RegisterNetEvent('f_wine:server:batalInjak', function()
    lepasInjak(source)
end)

---------------------------------------------------------------------------
-- tong fermentasi (per pemain, 3 tong)
---------------------------------------------------------------------------
local function dekatTong(src)
    for _, c in ipairs(config.lokasi.fermentasi) do
        if dekat(src, c, config.jarak.fermentasi + 1.0) then return true end
    end
    return false
end

lib.callback.register('f_wine:server:tong', function(src)
    if not dekatTong(src) then return false end
    local cid = cidOf(src)
    if not cid then return false end
    return { tong = tongView(cid), jus = jusCount(src) }
end)

lib.callback.register('f_wine:server:tuang', function(src, i, jenis, n)
    if not dekatTong(src) or spam(src, 'tong', 1500) then return { ok = false } end
    local cid = cidOf(src)
    local j = config.jenis[jenis]
    n = math.floor(tonumber(n) or 0)
    if not cid or not j or n < 1 or n > config.jusPerTong then return { ok = false } end
    local t = getTong(cid)
    if not t[i] then return { ok = false } end
    if t[i].j then return { ok = false, msg = 'Tong ini sudah terisi.' } end
    if (exports.ox_inventory:Search(src, 'count', j.jus) or 0) < n then
        return { ok = false, msg = 'Botol jus di tasmu tidak cukup.' }
    end
    if not exports.ox_inventory:RemoveItem(src, j.jus, n) then return { ok = false } end
    t[i] = { j = jenis, n = n, r = os.time() + config.fermentasiMenit * 60 }
    setTong(cid, t)
    return { ok = true, tong = tongView(cid), jus = jusCount(src) }
end)

lib.callback.register('f_wine:server:botolkan', function(src, i)
    if not dekatTong(src) or spam(src, 'tong', 1500) then return { ok = false } end
    local cid = cidOf(src)
    if not cid then return { ok = false } end
    local t = getTong(cid)
    local d = t[i]
    if not d or not d.j then return { ok = false } end
    if d.r > os.time() then return { ok = false, msg = 'Wine di tong ini belum matang.' } end
    local j = config.jenis[d.j]
    local jumlah = d.n * config.botolPerJus
    if not exports.ox_inventory:CanCarryItem(src, j.wine, jumlah) then
        return { ok = false, msg = ('Tasmu tidak muat %d botol %s.'):format(jumlah, j.label) }
    end
    exports.ox_inventory:AddItem(src, j.wine, jumlah)
    t[i] = {}
    setTong(cid, t)
    addStat(cid, 'w', jumlah)
    return { ok = true, jumlah = jumlah, label = j.label, tong = tongView(cid), jus = jusCount(src) }
end)

---------------------------------------------------------------------------
-- keranjang ditinggal jauh terlalu lama -> kembali ke tangan pemain
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, w in pairs(workers) do
            local k = w.keranjang
            if k.state == 'tanah' and k.pos then
                if #(pedPos(src) - k.pos) > 150.0 then
                    k.jauhSejak = k.jauhSejak or now
                    if now - k.jauhSejak >= config.keranjangTinggalMenit * 60 and not w.pegang then
                        k.state, k.pos, k.jauhSejak = 'bawa', nil, nil
                        TriggerClientEvent('f_wine:client:keranjangKembali', src)
                    end
                else
                    k.jauhSejak = nil
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lepasInjak(src)
    workers[src] = nil
    jeda[src] = nil
end)

-- /winepos (admin): salin koordinat + arah hadap untuk kalibrasi config
lib.addCommand('winepos', { help = 'f_wine: salin posisi kamu (vec4) untuk config', restricted = 'group.admin' }, function(src)
    TriggerClientEvent('f_wine:client:pos', src)
end)
