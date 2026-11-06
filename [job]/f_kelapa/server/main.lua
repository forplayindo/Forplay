local config = require 'config.shared'
local pohonList = require 'config.pohon'

local pohon = {}      -- index -> { coords, atas, buah, tumbuhAt, climber }
local jatuh = {}      -- id (string) -> { x, y, z, t = pohon, n = titik buah, exp }
local climbing = {}   -- source -> index pohon
local cooldown = {}   -- source -> GetGameTimer() terakhir petik / pungut
local nextId = 0

for i, p in ipairs(pohonList) do
    pohon[i] = { coords = p.coords, atas = p.atas, buah = p.buah, sisa = config.buahPerPohon }
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function pedCoords(src)
    return GetEntityCoords(GetPlayerPed(src))
end

local function dist2D(a, b)
    return #(vec2(a.x, a.y) - vec2(b.x, b.y))
end

-- state yang dilihat semua client: sisa kelapa per pohon + kelapa di tanah
local function syncPohon()
    local sisa = {}
    for i, p in ipairs(pohon) do sisa[i] = p.sisa end
    GlobalState.kelapaPohon = sisa
end

local function syncJatuh()
    local out = {}
    for id, d in pairs(jatuh) do out[id] = { x = d.x, y = d.y, z = d.z, t = d.t, n = d.n } end
    GlobalState.kelapaJatuh = out
end

local function spam(src, ms)
    local now = GetGameTimer()
    if cooldown[src] and now - cooldown[src] < ms then return true end
    cooldown[src] = now
    return false
end

local function lepas(src)
    local i = climbing[src]
    if i and pohon[i] and pohon[i].climber == src then pohon[i].climber = nil end
    climbing[src] = nil
end

---------------------------------------------------------------------------
-- panjat / petik / turun
---------------------------------------------------------------------------
lib.callback.register('f_kelapa:server:panjat', function(src, i)
    local p = pohon[i]
    if not p then return { ok = false } end
    if climbing[src] then return { ok = false, msg = 'Kamu sedang memanjat pohon lain.' } end
    if p.climber then
        -- pemanjat lama yang sudah pergi (mati, teleport, crash) tidak mengunci pohon
        if GetPlayerPed(p.climber) ~= 0 and dist2D(pedCoords(p.climber), p.coords) < 4.0 then
            return { ok = false, msg = 'Pohon ini sedang dipanjat orang lain.' }
        end
        lepas(p.climber)
    end
    if p.sisa <= 0 then return { ok = false, msg = 'Pohon ini belum berbuah lagi.' } end
    if dist2D(pedCoords(src), p.coords) > config.jarakPanjat then return { ok = false } end
    p.climber = src
    climbing[src] = i
    return { ok = true }
end)

lib.callback.register('f_kelapa:server:petik', function(src)
    local i = climbing[src]
    local p = i and pohon[i]
    if not p or p.climber ~= src then return { ok = false } end
    if spam(src, 700) then return { ok = false } end
    if #(pedCoords(src) - p.atas) > config.jarakAtas then return { ok = false } end
    if p.sisa <= 0 then return { ok = false, msg = 'Kelapanya sudah habis.' } end

    local n = p.sisa
    p.sisa -= 1
    if p.sisa == 0 then p.tumbuhAt = os.time() + config.tumbuhMenit * 60 end

    -- titik jatuh dipilih server; client hanya menempelkan prop ke tanah
    local a = math.random() * math.pi * 2
    local r = config.jatuhRadius[1] + math.random() * (config.jatuhRadius[2] - config.jatuhRadius[1])
    nextId += 1
    local id = 'k' .. nextId
    jatuh[id] = {
        x = p.coords.x + math.cos(a) * r, y = p.coords.y + math.sin(a) * r, z = p.coords.z + 0.15,
        t = i, n = n, exp = os.time() + config.jatuhMenit * 60,
    }
    syncPohon()
    syncJatuh()
    return { ok = true, sisa = p.sisa }
end)

RegisterNetEvent('f_kelapa:server:turun', function()
    lepas(source)
end)

---------------------------------------------------------------------------
-- pungut kelapa di tanah
---------------------------------------------------------------------------
lib.callback.register('f_kelapa:server:pungut', function(src, id)
    local d = jatuh[id]
    if not d then return { ok = false, msg = 'Kelapa ini sudah diambil orang lain.' } end
    if spam(src, 2500) then return { ok = false } end
    if climbing[src] then return { ok = false } end
    if dist2D(pedCoords(src), d) > config.jarakPungut then return { ok = false } end
    if not exports.ox_inventory:CanCarryItem(src, config.item, 1) then
        return { ok = false, msg = 'Tasmu penuh.' }
    end
    jatuh[id] = nil
    syncJatuh()
    exports.ox_inventory:AddItem(src, config.item, 1)
    return { ok = true }
end)

---------------------------------------------------------------------------
-- tumbuh lagi + kelapa kadaluarsa
---------------------------------------------------------------------------
CreateThread(function()
    syncPohon()
    syncJatuh()
    while true do
        Wait(30000)
        local now = os.time()
        local ubahPohon, ubahJatuh = false, false
        for _, p in ipairs(pohon) do
            if p.tumbuhAt and now >= p.tumbuhAt then
                p.sisa, p.tumbuhAt, ubahPohon = config.buahPerPohon, nil, true
            end
        end
        for id, d in pairs(jatuh) do
            if now >= d.exp then jatuh[id], ubahJatuh = nil, true end
        end
        if ubahPohon then syncPohon() end
        if ubahJatuh then syncJatuh() end
    end
end)

AddEventHandler('playerDropped', function()
    lepas(source)
    cooldown[source] = nil
end)
