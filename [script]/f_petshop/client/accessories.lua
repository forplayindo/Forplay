-- f_petshop client: memasang aksesoris hewan. Prop dibuat LOKAL di tiap client (tidak tersinkron,
-- jadi ringan) berdasarkan statebag `fpetacc`; kalung warna (komponen ped) diatur oleh pemilik
-- hewan karena komponen ped tersinkron sendiri lewat jaringan.

Accessories = {}

local petsById = {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end

local rendered = {} -- [ped] = { sig = string, objs = number[] }
local suspended = {} -- [ped] = true selama alat /petfit dipakai pada hewan itu
local fitsVer = 0   -- naik tiap GlobalState.fpetFits berubah -> semua aksesoris dipasang ulang

---@param ped number
---@param model string nama model hewan
---@param worn table { [slot] = prop | nomor kalung }
---@return number[] objek yang dibuat
function Accessories.attach(ped, model, worn)
    local objs = {}
    for slot, prop in pairs(worn or {}) do
        if slot ~= 'collar' and type(prop) == 'string' then
            local fit = Acc.fit(model, prop)
            local hash = joaat(prop)
            if fit and IsModelInCdimage(hash) and pcall(lib.requestModel, hash, 5000) and DoesEntityExist(ped) then
                local c = GetEntityCoords(ped)
                local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
                SetModelAsNoLongerNeeded(hash)
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, fit[3]), fit[1].x, fit[1].y, fit[1].z,
                    fit[2].x, fit[2].y, fit[2].z, false, false, false, true, 0, true) -- rotation order 0 = sama seperti posisi dari electus
                objs[#objs + 1] = obj
            end
        end
    end
    return objs
end

function Accessories.detach(objs)
    for _, obj in ipairs(objs or {}) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end

---@param ped number
---@param worn table
function Accessories.applyCollar(ped, worn)
    local c = worn and tonumber(worn.collar)
    if c and GetPedTextureVariation(ped, Config.CollarComponent) ~= c then
        SetPedComponentVariation(ped, Config.CollarComponent, 0, c, 0)
    end
end

-- jumlah warna kalung yang ada di model ini (0 = tidak punya kalung)
function Accessories.collarCount(ped)
    if GetNumberOfPedDrawableVariations(ped, Config.CollarComponent) < 1 then return 0 end
    return math.min(GetNumberOfPedTextureVariations(ped, Config.CollarComponent, 0), #Config.CollarColors)
end

function Accessories.suspend(ped, on)
    suspended[ped] = on or nil
    if on and rendered[ped] then
        Accessories.detach(rendered[ped].objs)
        rendered[ped] = nil
    end
end

local function clear(ped)
    local r = rendered[ped]
    if not r then return end
    Accessories.detach(r.objs)
    rendered[ped] = nil
end

local function refresh(ped)
    if suspended[ped] or not DoesEntityExist(ped) then return end
    local s = Entity(ped).state.fpet
    local worn = s and Entity(ped).state.fpetacc
    local cfg = s and petsById[s.pet]
    if not cfg or not worn then return clear(ped) end

    if NetworkHasControlOfEntity(ped) then Accessories.applyCollar(ped, worn) end

    local sig = ('%d|%s'):format(fitsVer, json.encode(worn))
    local r = rendered[ped]
    if r and r.sig == sig then return end
    if r then Accessories.detach(r.objs) end
    rendered[ped] = { sig = sig, objs = {} }
    rendered[ped].objs = Accessories.attach(ped, cfg.model, worn)
end

-- perubahan langsung (beli / pakai / lepas)
AddStateBagChangeHandler('fpetacc', nil, function(bagName)
    local ent = GetEntityFromStateBagName(bagName)
    if ent == 0 then return end
    SetTimeout(0, function()
        if rendered[ent] then rendered[ent].sig = nil end
        refresh(ent)
    end)
end)

AddStateBagChangeHandler('fpetFits', 'global', function()
    fitsVer += 1
end)

---------------------------------------------------------------------------
-- Tali anjing: gulungan tali di tangan pemilik + tali melengkung ke leher hewan, digambar
-- tiap frame di semua client (tanpa fisika tali, jadi tidak membebani hewan yang tersinkron)
---------------------------------------------------------------------------
local leashes = {} -- [ped hewan] = { holder = ped pemilik, hand = objek gulungan tali }
local LEASH_PROP = `prop_devin_rope_01`

local function clearLeash(ped)
    local l = leashes[ped]
    if not l then return end
    if DoesEntityExist(l.hand) then DeleteEntity(l.hand) end
    leashes[ped] = nil
end

-- dipanggil tiap detik: pasang / lepas gulungan tali sesuai statebag
local function syncLeash(ped, s)
    local player = s and s.leash and not s.dead and GetPlayerFromServerId(s.owner) or -1
    local holder = player ~= -1 and GetPlayerPed(player) or 0
    if holder == 0 or IsPedInAnyVehicle(holder, false) or IsEntityAttached(ped) then return clearLeash(ped) end
    local l = leashes[ped]
    if l and l.holder == holder and DoesEntityExist(l.hand) then return end
    clearLeash(ped)
    if not pcall(lib.requestModel, LEASH_PROP, 5000) then return end
    local c = GetEntityCoords(holder)
    local hand = CreateObject(LEASH_PROP, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(LEASH_PROP)
    SetEntityCollision(hand, false, false)
    AttachEntityToEntity(hand, holder, GetPedBoneIndex(holder, 6286), 0.075, 0.0, 0.0, 0.0, 90.0, 0.0,
        false, false, false, false, 0, true)
    leashes[ped] = { holder = holder, hand = hand }
end

local SEGMENTS = 10

local function cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

-- DrawLine selalu 1 piksel; tali digambar sebagai pita (DrawPoly) yang menghadap kamera
-- supaya punya tebal nyata. Tiap segitiga digambar dua arah karena DrawPoly hanya satu sisi.
local function quad(a1, a2, b1, b2, r, g, b)
    DrawPoly(a1.x, a1.y, a1.z, a2.x, a2.y, a2.z, b1.x, b1.y, b1.z, r, g, b, 255)
    DrawPoly(a2.x, a2.y, a2.z, b2.x, b2.y, b2.z, b1.x, b1.y, b1.z, r, g, b, 255)
    DrawPoly(a1.x, a1.y, a1.z, b1.x, b1.y, b1.z, a2.x, a2.y, a2.z, r, g, b, 255)
    DrawPoly(a2.x, a2.y, a2.z, b1.x, b1.y, b1.z, b2.x, b2.y, b2.z, r, g, b, 255)
end

local drawing = false
local function drawLeashes()
    if drawing then return end
    drawing = true
    CreateThread(function()
        local r, g, b = table.unpack(Config.Leash.color)
        local half = (Config.Leash.width or 0.025) / 2
        local pts, sides = {}, {}
        while next(leashes) do
            local cam = GetFinalRenderedCamCoord()
            for ped, l in pairs(leashes) do
                if DoesEntityExist(ped) and DoesEntityExist(l.hand) then
                    local hand = GetEntityCoords(l.hand)
                    local neck = GetPedBoneCoords(ped, 39317, 0.0, 0.0, -0.15)
                    local dist = #(hand - neck)
                    if dist > 0.05 and dist < 20.0 then
                        -- tali melengkung ke bawah (makin jauh makin kendur, maks 45 cm)
                        local sag = math.min(0.45, 0.12 + dist * 0.04)
                        for i = 0, SEGMENTS do
                            local t = i / SEGMENTS
                            pts[i] = hand + (neck - hand) * t - vec3(0.0, 0.0, 4 * sag * t * (1 - t))
                        end
                        -- arah samping tiap titik = tegak lurus arah tali & arah pandang kamera
                        for i = 0, SEGMENTS do
                            local dir = pts[math.min(i + 1, SEGMENTS)] - pts[math.max(i - 1, 0)]
                            local side = cross(dir, pts[i] - cam)
                            local len = #side
                            sides[i] = len > 0.0001 and side * (half / len) or vec3(0.0, 0.0, half)
                        end
                        for i = 0, SEGMENTS - 1 do
                            local a, c = pts[i], pts[i + 1]
                            quad(a + sides[i], a - sides[i], c + sides[i + 1], c - sides[i + 1], r, g, b)
                        end
                    end
                end
            end
            Wait(0)
        end
        drawing = false
    end)
end

-- hewan yang masuk / keluar jangkauan
CreateThread(function()
    while true do
        local seen = {}
        for _, n in ipairs(lib.getNearbyPeds(GetEntityCoords(cache.ped), 80.0)) do
            local s = Entity(n.ped).state.fpet
            if s then
                seen[n.ped] = true
                if Entity(n.ped).state.fpetacc then refresh(n.ped) end
                syncLeash(n.ped, s)
            end
        end
        for ped in pairs(rendered) do
            if not seen[ped] then clear(ped) end
        end
        for ped in pairs(leashes) do
            if not seen[ped] then clearLeash(ped) end
        end
        if next(leashes) then drawLeashes() end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    for ped in pairs(rendered) do clear(ped) end
    for ped in pairs(leashes) do clearLeash(ped) end
end)
