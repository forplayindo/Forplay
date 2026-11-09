---------------------------------------------------------------------------
-- f_handling (server)
--  * Mencari semua kendaraan addon dari resource yang punya data_file HANDLING_FILE
--    (model -> handlingId dari VEHICLE_METADATA_FILE). Kendaraan vanilla tidak ikut.
--  * Simpan = tulis angka yang diubah langsung ke handling.meta di folder kendaraannya
--    (hanya angka di <Item> yang cocok, sisa file tidak disentuh, backup .bak sekali
--    per sesi), lalu disiarkan lewat GlobalState supaya semua client langsung
--    memakainya tanpa restart. Setelah restart server, file sudah berisi nilai baru
--    sehingga siaran sesi lama dibuang.
---------------------------------------------------------------------------
local RESOURCE = GetCurrentResourceName()
local STATE_KEY = 'f_handling'
local KVP_KEY = 'f_handling:session'
local GROUPS = require 'shared.fields'

local FIELD, ORDER = {}, {}
for _, g in ipairs(GROUPS) do
    for _, f in ipairs(g.fields) do
        FIELD[f.key] = f
        ORDER[#ORDER + 1] = f.key
    end
end

local Cars = {}       -- [NAMA_UPPER] = { name, res, path, models = {}, file = { [key] = angka } }
local Live = {}       -- [NAMA_UPPER] = { n = name, m = models, v = { [key] = angka } } nilai yang disiarkan
local Orig = {}       -- [NAMA_UPPER] = { [key] = angka saat server boot } (untuk "bawaan")
local Meta = {}       -- [NAMA_UPPER] = { by, at }
local backedUp = {}   -- ['res:path'] = true
local scanned, dirty = false, true
local ver = 0

-- waktu boot server (detik). GetGameTimer di server = ms sejak proses jalan.
local BOOT = os.time() - math.floor(GetGameTimer() / 1000)

---------------------------------------------------------------------------
-- Angka
---------------------------------------------------------------------------
local function fmtNum(v, int)
    if int then return tostring(math.floor(v + 0.5)) end
    local s = ('%.4f'):format(v)
    s = s:gsub('0+$', '')
    s = s:gsub('%.$', '.0')
    if s == '-0.0' then s = '0.0' end
    return s
end

local function snap(v, step)
    return tonumber(fmtNum(math.floor(v / step + 0.5) * step))
end

---------------------------------------------------------------------------
-- Baca / tulis handling.meta
---------------------------------------------------------------------------
local function splitKey(key)
    local tag, axis = key:match('^(.-)%.([xyz])$')
    return tag or key, axis
end

---Rentang teks satu kendaraan: dari <handlingName> sampai sebelum <SubHandlingData>
---atau <handlingName> berikutnya. Field utama selalu ada di rentang ini.
---@return integer? start, integer? stop  stop = indeks pertama SESUDAH rentang
local function itemRange(text, name)
    local up, pos = name:upper(), 1
    while true do
        local s, e, hn = text:find('<handlingName>%s*([^<]-)%s*</handlingName>', pos)
        if not s then return end
        if hn:upper() == up then
            local stop = #text + 1
            local a = text:find('<SubHandlingData', e, true)
            if a and a < stop then stop = a end
            local b = text:find('<handlingName>', e, true)
            if b and b < stop then stop = b end
            return s, stop
        end
        pos = e + 1
    end
end

local function readField(region, key)
    local tag, axis = splitKey(key)
    if axis then
        local t = region:match('<' .. tag .. '%s[^>]*>')
        return t and tonumber(t:match('%s' .. axis .. '%s*=%s*"([^"]*)"'))
    end
    return tonumber(region:match('<' .. tag .. '%s+value%s*=%s*"([^"]*)"'))
end

local function parseRegion(region)
    local out = {}
    for _, k in ipairs(ORDER) do out[k] = readField(region, k) end
    return out
end

local function insertLine(region, line)
    local _, e = region:find('</handlingName>', 1, true)
    local indent = region:match('\n([ \t]*)<', e) or '    '
    return region:sub(1, e) .. '\n' .. indent .. line .. region:sub(e + 1)
end

local function writeField(region, key, value)
    local def = FIELD[key]
    local tag, axis = splitKey(key)
    local num = fmtNum(value, def.int)
    if axis then
        local s, e = region:find('<' .. tag .. '%s[^>]*>')
        if not s then
            return writeField(insertLine(region, ('<%s x="0.0" y="0.0" z="0.0"/>'):format(tag)), key, value)
        end
        local t = region:sub(s, e)
        local nt, n = t:gsub('(%s' .. axis .. '%s*=%s*")[^"]*(")', '%1' .. num .. '%2', 1)
        if n == 0 then nt = t:gsub('<' .. tag, '<' .. tag .. ' ' .. axis .. '="' .. num .. '"', 1) end
        return region:sub(1, s - 1) .. nt .. region:sub(e + 1)
    end
    local nr, n = region:gsub('(<' .. tag .. '%s+value%s*=%s*")[^"]*(")', '%1' .. num .. '%2', 1)
    if n > 0 then return nr end
    return insertLine(region, ('<%s value="%s"/>'):format(tag, num))
end

---------------------------------------------------------------------------
-- Scan resource kendaraan addon
---------------------------------------------------------------------------
local function metaPaths(res, kind)
    local out = {}
    for i = 0, GetNumResourceMetadata(res, 'data_file') - 1 do
        if GetResourceMetadata(res, 'data_file', i) == kind then
            local raw = GetResourceMetadata(res, 'data_file_extra', i)
            local ok, v = pcall(json.decode, raw or '')
            local p = ok and (type(v) == 'table' and v[1] or v) or raw
            if type(p) == 'string' and p ~= '' then
                p = p:gsub('\\', '/'):gsub('^%./', '')
                if p:find('*', 1, true) then
                    print(('^3[f_handling] %s: path wildcard "%s" dilewati, tulis path lengkap di fxmanifest^0'):format(res, p))
                else
                    out[#out + 1] = p
                end
            end
        end
    end
    return out
end

local function scan()
    local models, found, texts = {}, {}, {}
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        local st = res and GetResourceState(res)
        if res and res ~= RESOURCE and (st == 'started' or st == 'starting') then
            for _, p in ipairs(metaPaths(res, 'VEHICLE_METADATA_FILE')) do
                local txt = LoadResourceFile(res, p)
                if txt then
                    for pos, model in txt:gmatch('()<modelName>%s*([^<]-)%s*</modelName>') do
                        local hid = txt:match('<handlingId>%s*([^<]-)%s*</handlingId>', pos)
                        if hid then
                            local list = models[hid:upper()] or {}
                            list[#list + 1] = model:lower()
                            models[hid:upper()] = list
                        end
                    end
                end
            end
            for _, p in ipairs(metaPaths(res, 'HANDLING_FILE')) do
                local txt = LoadResourceFile(res, p)
                if txt then
                    texts[res .. ':' .. p] = txt
                    for hn in txt:gmatch('<handlingName>%s*([^<]-)%s*</handlingName>') do
                        found[hn:upper()] = { name = hn, res = res, path = p }
                    end
                else
                    print(('^3[f_handling] %s: file %s tidak bisa dibaca^0'):format(res, p))
                end
            end
        end
    end

    Cars = {}
    for key, f in pairs(found) do
        local txt = texts[f.res .. ':' .. f.path]
        local s, stop = itemRange(txt, f.name)
        if s then
            Cars[key] = { name = f.name, res = f.res, path = f.path, models = models[key] or {}, file = parseRegion(txt:sub(s, stop - 1)) }
        end
    end
    for key, l in pairs(Live) do
        if Cars[key] then l.m = Cars[key].models end
    end
    scanned, dirty = true, false
end

local function ensureScan()
    if dirty or not scanned then scan() end
end

-- resource kendaraan baru di-start -> scan ulang saat panel dibuka berikutnya
AddEventHandler('onResourceStart', function(res)
    if res ~= RESOURCE and GetNumResourceMetadata(res, 'data_file') > 0 then dirty = true end
end)

---------------------------------------------------------------------------
-- Sesi (bertahan saat f_handling di-restart, dibuang saat server boot ulang)
---------------------------------------------------------------------------
local function saveSession()
    SetResourceKvp(KVP_KEY, json.encode({ boot = BOOT, live = Live, orig = Orig, meta = Meta }))
end

do
    local ok, d = pcall(json.decode, GetResourceKvpString(KVP_KEY) or '')
    if ok and type(d) == 'table' and math.abs((d.boot or 0) - BOOT) < 300 then
        Live, Orig, Meta = d.live or {}, d.orig or {}, d.meta or {}
    else
        DeleteResourceKvp(KVP_KEY)
    end
end

local function publish()
    local cars = {}
    for key, l in pairs(Live) do
        if next(l.v) then cars[key] = { n = l.n, m = l.m, v = l.v } end
    end
    ver += 1
    GlobalState[STATE_KEY] = { ver = ver, cars = cars }
end
publish()

---------------------------------------------------------------------------
-- Izin: Owner / Admin f_admin (cadangan: ACE f_handling.edit)
---------------------------------------------------------------------------
local function canEdit(src)
    if GetResourceState('f_admin') == 'started' then
        local role = exports.f_admin:GetRole(src)
        if role == 'owner' or role == 'admin' then return true end
    end
    return IsPlayerAceAllowed(tostring(src), 'f_handling.edit')
end

local DENIED = { ok = false, msg = 'Khusus Owner & Admin.' }

local function rowOf(key)
    local c = Cars[key]
    local orig = {}
    for k, v in pairs(c.file) do orig[k] = v end
    for k, v in pairs(Orig[key] or {}) do orig[k] = v end
    local m = Meta[key]
    return {
        key = key, name = c.name, res = c.res, path = c.path, models = c.models,
        cur = c.file, orig = orig, by = m and m.by, at = m and m.at,
    }
end

lib.callback.register('f_handling:list', function(src)
    if not canEdit(src) then return DENIED end
    ensureScan()
    local list = {}
    for key in pairs(Cars) do list[#list + 1] = rowOf(key) end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return { ok = true, cars = list }
end)

lib.callback.register('f_handling:save', function(src, key, values)
    if not canEdit(src) then return DENIED end
    if type(key) ~= 'string' or type(values) ~= 'table' then return { ok = false, msg = 'Data tidak valid.' } end
    ensureScan()
    key = key:upper()
    local car = Cars[key]
    if not car then return { ok = false, msg = 'Kendaraan tidak dikenal.' } end

    local text = LoadResourceFile(car.res, car.path)
    if not text then return { ok = false, msg = ('File %s/%s tidak bisa dibaca.'):format(car.res, car.path) } end
    local s, stop = itemRange(text, car.name)
    if not s then return { ok = false, msg = ('%s tidak ditemukan di %s.'):format(car.name, car.path) } end

    local region = text:sub(s, stop - 1)
    local cur = parseRegion(region)
    local changed, count = {}, 0
    for k, v in pairs(values) do
        local def = FIELD[k]
        v = tonumber(v)
        if def and v and v == v then
            v = snap(math.max(def.min, math.min(def.max, v)), def.step)
            if not cur[k] or math.abs(cur[k] - v) > 1e-6 then
                changed[k] = v
                count += 1
            end
        end
    end
    if count == 0 then return { ok = false, msg = 'Tidak ada perubahan.' } end

    local fk = car.res .. ':' .. car.path
    if not backedUp[fk] then
        SaveResourceFile(car.res, car.path .. '.bak', text, -1)
        backedUp[fk] = true
    end
    for k, v in pairs(changed) do region = writeField(region, k, v) end
    if not SaveResourceFile(car.res, car.path, text:sub(1, s - 1) .. region .. text:sub(stop), -1) then
        return { ok = false, msg = 'Gagal menulis handling.meta (cek izin folder).' }
    end

    car.file = parseRegion(region)
    Orig[key] = Orig[key] or {}
    Live[key] = Live[key] or { n = car.name, m = car.models, v = {} }
    local log = {}
    for _, k in ipairs(ORDER) do
        local v = changed[k]
        if v then
            if Orig[key][k] == nil then Orig[key][k] = cur[k] or 0 end
            Live[key].v[k] = v
            -- vektor: siarkan ketiga sumbu (SetHandlingVector butuh lengkap)
            local tag, axis = splitKey(k)
            if axis then
                for _, a in ipairs({ 'x', 'y', 'z' }) do
                    local kk = tag .. '.' .. a
                    if Orig[key][kk] == nil then Orig[key][kk] = cur[kk] or 0 end
                    Live[key].v[kk] = car.file[kk] or 0
                end
            end
            log[#log + 1] = ('%s %s → %s'):format(FIELD[k].label, cur[k] and fmtNum(cur[k], FIELD[k].int) or '-', fmtNum(v, FIELD[k].int))
        end
    end
    Meta[key] = { by = GetPlayerName(src) or ('ID ' .. src), at = os.date('%d/%m/%Y %H:%M') }
    saveSession()
    publish()

    if GetResourceState('f_admin') == 'started' then
        pcall(exports.f_admin.Log, exports.f_admin, src, 'handling', ('mengubah handling **%s** (%s/%s): %s'):format(car.name, car.res, car.path, table.concat(log, ', ')))
    end
    print(('[f_handling] %s mengubah %s: %s'):format(GetPlayerName(src), car.name, table.concat(log, ', ')))

    return { ok = true, msg = ('%d nilai %s tersimpan ke handling.meta dan langsung dipakai semua pemain.'):format(count, car.name), car = rowOf(key) }
end)

lib.callback.register('f_handling:file', function(src, key)
    if not canEdit(src) then return DENIED end
    local car = type(key) == 'string' and Cars[key:upper()]
    if not car then return { ok = false, msg = 'Kendaraan tidak dikenal.' } end
    local text = LoadResourceFile(car.res, car.path)
    if not text then return { ok = false, msg = 'File tidak bisa dibaca.' } end
    return { ok = true, path = car.res .. '/' .. car.path, text = text }
end)

CreateThread(function()
    Wait(2000)
    ensureScan()
end)
