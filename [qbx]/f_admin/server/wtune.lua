---------------------------------------------------------------------------
-- Halaman Senjata: damage badan / armor / kepala & recoil per senjata.
-- Khusus Owner & Admin. Disimpan di data/weapons.json (hanya senjata yang
-- diubah) lalu disiarkan lewat GlobalState['f_admin:wtune'] supaya langsung
-- berlaku di semua client tanpa restart (client/wtune.lua).
---------------------------------------------------------------------------
local RESOURCE = GetCurrentResourceName()
local STATE_KEY = 'f_admin:wtune'
local FILE = 'data/weapons.json'

local WEAPONS = require 'shared.weapons'

-- batas nilai yang boleh disimpan
local LIMIT = { b = { 1, 1000 }, a = { 0, 1000 }, h = { 0, 1000 }, r = { 0, 2.5 } }

local function s32(h)
    h = h & 0xFFFFFFFF
    return h >= 0x80000000 and h - 0x100000000 or h
end

local function round1(n) return math.floor(n * 10 + 0.5) / 10 end

-- recoil bawaan = f_recoils/config.lua (satu sumber), [hash] = nilai
local function recoilDefaults()
    local code = LoadResourceFile('f_smallresources', 'f_recoils/config.lua')
    local fn = code and load(code, '@f_recoils/config.lua', 't', {})
    local ok, tbl = pcall(fn or error)
    return ok and type(tbl) == 'table' and tbl or {}
end

local Def, ByName = {}, {}
do
    local rec = recoilDefaults()
    for _, w in ipairs(WEAPONS) do
        local d = {
            name = w.name, label = w.label, cat = w.cat, pellets = w.pellets, hs = w.hs,
            b = w.dmg, a = w.dmg, h = round1(w.dmg * w.hs), r = rec[s32(joaat(w.name))] or 0.0,
        }
        Def[#Def + 1] = d
        ByName[w.name] = d
    end
end

local Saved = {}
do
    local ok, data = pcall(json.decode, LoadResourceFile(RESOURCE, FILE) or '')
    if ok and type(data) == 'table' then
        for name, v in pairs(data) do
            if ByName[name] and type(v) == 'table' then Saved[name] = v end
        end
    end
end

local function publish()
    local out = {}
    for name, v in pairs(Saved) do out[name] = { b = v.b, a = v.a, h = v.h, r = v.r } end
    GlobalState[STATE_KEY] = out
end
publish()

local function canTune(src)
    local role = GetRole(src)
    return role == 'owner' or role == 'admin'
end

local function rowOf(d)
    local s = Saved[d.name]
    return {
        n = d.name, l = d.label, c = d.cat, p = d.pellets, hs = d.hs,
        d = { b = d.b, a = d.a, h = d.h, r = d.r },
        s = s and { b = s.b, a = s.a, h = s.h, r = s.r } or nil,
        by = s and s.by, at = s.at,
    }
end

Handle('wtune', false, function(src)
    if not canTune(src) then return { ok = false, msg = 'Khusus Admin & Owner.' } end
    local list = {}
    for _, d in ipairs(Def) do list[#list + 1] = rowOf(d) end
    return { ok = true, list = list }
end)

local FIELD_LABEL = { b = 'darah badan', a = 'armor', h = 'kepala', r = 'recoil' }

Handle('wtune_save', false, function(src, d)
    if not canTune(src) then return { ok = false, msg = 'Khusus Admin & Owner.' } end
    local def = ByName[d.name]
    if not def then return { ok = false, msg = 'Senjata tidak dikenal.' } end

    local old = Saved[def.name] or def
    local new, changed, custom = {}, {}, false
    for k, lim in pairs(LIMIT) do
        local v = tonumber(d[k])
        if not v or v ~= v then return { ok = false, msg = 'Angka tidak valid.' } end
        v = round1(math.max(lim[1], math.min(lim[2], v)))
        new[k] = v
        if v ~= def[k] then custom = true end
        if v ~= old[k] then changed[#changed + 1] = ('%s %s → %s'):format(FIELD_LABEL[k], old[k], v) end
    end
    if #changed == 0 then return { ok = false, msg = 'Tidak ada perubahan.' } end

    if custom then
        new.by = ('%s (%s)'):format(GetPlayerName(src) or ('ID ' .. src), RoleLabel[GetRole(src)] or 'Staff')
        new.at = os.date('%d/%m/%Y %H:%M')
        Saved[def.name] = new
    else
        Saved[def.name] = nil -- semua kembali bawaan
    end
    SaveResourceFile(RESOURCE, FILE, json.encode(Saved, { indent = true }), -1)
    publish()

    table.sort(changed)
    Log(src, 'wtune', ('mengubah **%s** (%s): %s'):format(def.label, def.name, table.concat(changed, ', ')))
    return { ok = true, msg = ('%s tersimpan dan langsung berlaku untuk semua pemain.'):format(def.label), row = rowOf(def) }
end)
