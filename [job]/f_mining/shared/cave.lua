-- Geometri gua mengikuti grid aquiver: satu petak = tabung 4.9715 m, maju = +Y dari pintu utara lobby.
-- Dipakai server (cek jarak batu / bak) dan klien (prop lokal). Semua gua A-E memakai geometri yang sama.
local BASE = vec3(-1150.04492, 3303.74951, -110.304749) -- tengah petak (0,0)
local STEP = 4.9715
local FLOOR = -111.7808

-- muka dinding 3x3 (offset tiap potongan dari titik tengah muka, dari aquiver)
local PIECES = {
    { 0, 0, vec3(-1.27282, 0, -0.9018025) },
    { 0, 1, vec3(-1.25808, 0, 0.004444) },
    { 0, 2, vec3(-1.27631915, 0, 0.850906) },
    { 1, 0, vec3(0.0395569541, 0, -0.911404) },
    { 1, 1, vec3(0, 0, 0) },
    { 1, 2, vec3(0.003661, 0, 0.868383) },
    { 2, 0, vec3(1.23617, 0, -0.87126) },
    { 2, 1, vec3(1.28565, 0, -0.09983321) },
    { 2, 2, vec3(1.256, 0, 0.910349) },
}

-- tabung: { x, y, heading, kiri terbuka, kanan terbuka } — heading 0 maju, 90 lorong kiri, -90 lorong kanan
local TUBES = {
    { 0, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0, true, true }, { 0, 3, 0 }, { 0, 4, 0 },
    { -1, 2, 90 }, { -2, 2, 90 }, { -3, 2, 90 }, { -4, 2, 90 },
    { 1, 2, -90 }, { 2, 2, -90 }, { 3, 2, -90 }, { 4, 2, -90 },
}

-- muka batu yang bisa ditambang (ujung tiap lorong): petak + arah hadap
local FACES = {
    { 0, 4, 0 },
    { -4, 2, 90 },
    { 4, 2, -90 },
}

local RAIL_X = 1.3 -- rel & lori digeser ke timur supaya ada jalan di sisi barat

local function offset(origin, heading, off)
    local r = math.rad(heading)
    local c, s = math.cos(r), math.sin(r)
    return vec3(origin.x + off.x * c - off.y * s, origin.y + off.x * s + off.y * c, origin.z + off.z)
end

local function cellPos(x, y)
    return vec3(BASE.x + x * STEP, BASE.y + y * STEP, BASE.z)
end

local function tubeModel(left, right)
    -- penamaan model aquiver terbalik: kiri terbuka = *_open_right
    if left and right then return 'avp_prop_mining_tube_02_open_both' end
    if left then return 'avp_prop_mining_tube_02_open_right' end
    if right then return 'avp_prop_mining_tube_02_open_left' end
    return 'avp_prop_mining_tube_02_closed'
end

-- 9 potongan muka dinding; depth -1.6 = muka utuh (tahap 0), 0.0 = muka cadangan di belakangnya
local function face(cell, heading, depth)
    local origin = offset(cell, heading, vec3(0, depth, 0))
    local list = {}
    for i = 1, #PIECES do
        local p = PIECES[i]
        list[i] = { cx = p[1], cy = p[2], pos = offset(origin, heading, p[3]), heading = heading }
    end
    return list
end

local cave = {
    floor = FLOOR,
    center = vec3(BASE.x, BASE.y + 2 * STEP, FLOOR),
    tubes = {},
    lamps = {},
    rocks = {},       -- bisa ditambang
    rockById = {},
    backing = {},     -- muka cadangan statis di belakang batu (supaya lubang tidak tembus)
}

for i = 1, #TUBES do
    local t = TUBES[i]
    local pos = cellPos(t[1], t[2])
    cave.tubes[i] = { model = tubeModel(t[4], t[5]), pos = pos, heading = t[3] }
    cave.lamps[i] = { pos = offset(pos, t[3], vec3(0, -2.5, 0.97)), heading = t[3] }
end

for f = 1, #FACES do
    local def = FACES[f]
    local cell = cellPos(def[1], def[2])
    for _, piece in ipairs(face(cell, def[3], -1.6)) do
        piece.id = ('%d_%d_%d'):format(f, piece.cx, piece.cy)
        cave.rocks[#cave.rocks + 1] = piece
        cave.rockById[piece.id] = piece
    end
    for _, piece in ipairs(face(cell, def[3], 0.0)) do
        cave.backing[#cave.backing + 1] = piece
    end
end

-- pintu gua di ujung utara lobby: sisi lobby menghadap selatan, sisi gua menghadap utara
local gateCell = cellPos(0, 0)
cave.gateLobby = face(gateCell, 0, -1.6)
cave.gateCave = face(gateCell, 180, -1.6)
cave.gateCaveTarget = vec3(gateCell.x, gateCell.y + 1.2, FLOOR + 1.0)

-- rel + lori (bak setor) di lorong utama
local c0, c1 = cellPos(0, 0), cellPos(0, 1)
cave.rails = {
    { pos = vec3(c0.x + RAIL_X, c0.y, FLOOR), heading = 0 },
    { pos = vec3(c1.x + RAIL_X, c1.y, FLOOR), heading = 0 },
}
cave.cartPark = vec3(c1.x + RAIL_X, c1.y + 1.0, FLOOR)
cave.cartOut = vec3(c1.x + RAIL_X, gateCell.y + 2.4, FLOOR) -- lori "masuk" ke pintu menuju lobby
cave.arrival = vec4(c1.x - 1.2, c1.y - 1.0, FLOOR, 0.0)

cave.rockModel = function(cx, cy, stage)
    return ('avp_prop_mining_wall_%d_%d_%d'):format(cx, cy, stage)
end

return cave
