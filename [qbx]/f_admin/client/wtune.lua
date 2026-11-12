---------------------------------------------------------------------------
-- Penerapan halaman Senjata di setiap client (server/wtune.lua menyiarkan
-- GlobalState['f_admin:wtune'] = { [weapon_xxx] = { b, a, h, r } }).
--
--  b  darah badan per peluru : SetWeaponDamageModifier di sisi penembak
--     (damage dihitung client penembak, jadi semua client memasang modifier).
--  a  armor per peluru       : dikoreksi di sisi korban setelah GTA memotong armor.
--  h  kepala per peluru      : selama ada senjata dengan nilai kepala diubah,
--     critical hit GTA dimatikan dan damage kepala dipasang di sisi korban.
--     Kalau tidak ada yang diubah, headshot tetap murni bawaan GTA.
--  r  recoil                 : diteruskan ke f_recoils lewat LocalPlayer.state.f_recoil.
--
-- "Coba di Saya" (preview) hanya di client staff ini, hilang saat panel ditutup.
---------------------------------------------------------------------------
local STATE_KEY = 'f_admin:wtune'
local HEAD_BONE = 31086 -- SKEL_Head
local DEAD_HP = 100     -- darah pemain 100..200, <= 100 = jatuh
local SET_ENTITY_HEALTH = 0x6B76DC1F3AE6E6A3

local function s32(h)
    h = h & 0xFFFFFFFF
    return h >= 0x80000000 and h - 0x100000000 or h
end

local Def = {} -- [hash] = { name, dmg, head, pellets }
for _, w in ipairs(require 'shared.weapons') do
    Def[s32(joaat(w.name))] = { name = w.name, dmg = w.dmg, head = math.floor(w.dmg * w.hs * 10 + 0.5) / 10, pellets = w.pellets }
end

local tune, preview = {}, {} -- [hash] = { b, a, h, r }
local lastMod = {}           -- [hash] = modifier yang terakhir dipasang
local critsOff = false       -- true = critical hit dimatikan oleh script ini
local armorFix = false       -- ada senjata dengan armor berbeda dari darah badan

local function eff(hash) return preview[hash] or tune[hash] end

local function setCrits(off)
    if off == critsOff then return end
    critsOff = off
    -- hanya mengembalikan crit yang kita matikan sendiri (f_ignore bisa mematikannya juga)
    SetPedSuffersCriticalHits(cache.ped, not off)
end

local function apply()
    local recoil, headCtl, armor = {}, false, false
    for hash, w in pairs(Def) do
        local v = eff(hash)
        local mod = 1.0
        if v then
            -- selalu dari angka bawaan tabel: GetWeaponDamage bisa ikut membaca pengali yang
            -- sudah terpasang, sehingga hasilnya bolak-balik setiap kali apply() dipanggil
            if v.b ~= w.dmg then mod = v.b / w.dmg end
            recoil[tostring(hash)] = v.r -- kunci teks: aman lewat state bag
            if v.h ~= w.head then headCtl = true end
            if v.a ~= v.b then armor = true end
        end
        if mod ~= (lastMod[hash] or 1.0) then
            SetWeaponDamageModifier(hash, mod)
            lastMod[hash] = mod
        end
    end
    armorFix = armor
    setCrits(headCtl)
    LocalPlayer.state:set('f_recoil', next(recoil) and recoil or nil, false)
    TriggerEvent('f_admin:recoil', recoil) -- f_recoils menyimpan salinannya sendiri
end

local function loadTune(data)
    tune = {}
    for name, v in pairs(type(data) == 'table' and data or {}) do
        tune[s32(joaat(name))] = v
    end
    apply()
end

loadTune(GlobalState[STATE_KEY])
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value) loadTune(value) end)

lib.onCache('ped', function(ped)
    if critsOff then SetPedSuffersCriticalHits(ped, false) end
end)

-- pasang ulang pengali saat senjata dikeluarkan, jaga-jaga kalau game mereset modifier
lib.onCache('weapon', function(weapon)
    if not weapon then return end
    local mod = lastMod[s32(weapon)]
    if mod and mod ~= 1.0 then SetWeaponDamageModifier(weapon, mod) end
end)

---------------------------------------------------------------------------
-- Koreksi di sisi korban
---------------------------------------------------------------------------
local snap = { hp = 0, ar = 0 } -- darah & armor sebelum kena tembak

local function takeSnap()
    snap.hp = GetEntityHealth(cache.ped)
    snap.ar = GetPedArmour(cache.ped)
end

-- snapshot ringan, hanya rapat saat ada koreksi yang aktif
CreateThread(function()
    while true do
        takeSnap()
        Wait((critsOff or armorFix) and 300 or 2000)
    end
end)

local function setHealth(ped, hp, attacker, weapon)
    if hp <= DEAD_HP then
        -- instigator + senjata supaya pembunuh tetap tercatat (f_medical, f_crew)
        Citizen.InvokeNative(SET_ENTITY_HEALTH, ped, 0, attacker, weapon)
    else
        SetEntityHealth(ped, math.floor(hp))
    end
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = cache.ped
    if args[1] ~= ped then return end

    local hp, ar = GetEntityHealth(ped), GetPedArmour(ped)
    local beforeHp, beforeAr = snap.hp, snap.ar
    snap.hp, snap.ar = hp, ar

    if not (critsOff or armorFix) then return end
    local attacker, weapon = args[2], args[7]
    if args[4] == 1 or IsEntityDead(ped) then return end
    if not attacker or attacker == 0 or attacker == ped or not IsEntityAPed(attacker) or not IsPedAPlayer(attacker) then return end

    local hash = s32(weapon)
    local w = Def[hash]
    if not w then return end
    if hp > beforeHp or ar > beforeAr then return end -- snapshot basi (baru diobati / pakai armor)

    local v = eff(hash)
    local B = v and v.b or w.dmg
    local lost = (beforeHp - hp) + (beforeAr - ar)
    if lost <= 0 or B <= 0 then return end
    local n = math.max(1, math.min(w.pellets, math.floor(lost / B + 0.5))) -- peluru/pelet yang kena

    local _, bone = GetPedLastDamageBone(ped)
    local newHp, newAr
    if bone == HEAD_BONE then
        if not critsOff then return end
        -- kepala: langsung ke darah, armor tidak berkurang
        newHp, newAr = beforeHp - (v and v.h or w.head) * n, beforeAr
    else
        if not v or v.a == v.b or beforeAr <= 0 then return end
        -- badan selama armor masih ada: hanya armor yang berkurang
        newHp, newAr = beforeHp, math.max(0, beforeAr - v.a * n)
    end

    newAr = math.floor(newAr)
    if newAr ~= ar then SetPedArmour(ped, newAr) end
    if newHp ~= hp then setHealth(ped, newHp, attacker, weapon) end
    takeSnap()
end)

---------------------------------------------------------------------------
-- "Coba di Saya" dari NUI
---------------------------------------------------------------------------
local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return lo end
    return math.floor(math.max(lo, math.min(hi, v)) * 10 + 0.5) / 10
end

ACT.wtune_try = function(d)
    local hash = type(d.name) == 'string' and s32(joaat(d.name))
    if not hash or not Def[hash] then return { ok = false, msg = 'Senjata tidak dikenal.' } end
    preview[hash] = { b = num(d.b, 1, 1000), a = num(d.a, 0, 1000), h = num(d.h, 0, 1000), r = num(d.r, 0, 2.5) }
    apply()
    return { ok = true }
end

ACT.wtune_clear = function(d)
    if type(d.name) == 'string' then preview[s32(joaat(d.name))] = nil else preview = {} end
    apply()
    return { ok = true }
end

function ClearWeaponPreview()
    if next(preview) then
        preview = {}
        apply()
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for hash, mod in pairs(lastMod) do
        if mod ~= 1.0 then SetWeaponDamageModifier(hash, 1.0) end
    end
    if critsOff then SetPedSuffersCriticalHits(cache.ped, true) end
    LocalPlayer.state:set('f_recoil', nil, false)
    TriggerEvent('f_admin:recoil', {})
end)
