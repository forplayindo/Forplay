-- isi dek tug & bak bison kerja nelayan (prop lokal dari statebag 'fnl'), terlihat semua pemain di dekatnya.
-- tug: f = peti isi (8 dasar lalu menumpuk), w = daftar posisi jaring di laut (jaring isi ikan dipegang pemain)
-- bison: t = peti isi di bak
local sharedConfig = require 'config.shared'
local config = require 'config.client'
local M = sharedConfig.models

NLY = NLY or {}

local rigs = {}     -- vehicle -> { kind, props = { key = { obj, model } } }
local kinds = { [joaat(sharedConfig.boatModel)] = 'tug', [joaat(sharedConfig.truckModel)] = 'bison' }

local function deleteObj(obj)
    if not obj or not DoesEntityExist(obj) then return end
    exports.ox_target:removeLocalEntity(obj)
    DeleteEntity(obj)
end

-- lantai dek tug di titik (x, y): sinar dari atas ke bawah yang hanya mengenai kapal itu, disimpan per slot
-- (dek naik-turun & miring sedikit, nilai config z hanya cadangan kalau sinar tidak kena)
local floorCache = {}

local function snapToDeck(veh, key, off)
    if floorCache[key] then return vec3(off.x, off.y, floorCache[key]) end
    local top = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z + 2.5)
    local bottom = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z - 2.0)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(top.x, top.y, top.z, bottom.x, bottom.y, bottom.z, 2, 0, 7)
    local _, hit, at, _, ent = GetShapeTestResult(ray)
    if hit == 1 and ent == veh then
        local z = GetOffsetFromEntityGivenWorldCoords(veh, at.x, at.y, at.z).z
        floorCache[key] = z
        return vec3(off.x, off.y, z)
    end
    return off
end

local function attached(model, veh, off, heading, key)
    if key then off = snapToDeck(veh, key, off) end
    lib.requestModel(model, 5000)
    local at = GetEntityCoords(veh)
    local obj = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, veh, 0, off.x, off.y, off.z, 0.0, 0.0, heading or 0.0, false, true, false, false, 2, true)
    return obj
end

local function seaNet(pos, veh)
    lib.requestModel(M.netSea, 5000)
    local found, h = GetWaterHeight(pos.x, pos.y, 5.0)
    local obj = CreateObject(M.netSea, pos.x, pos.y, (found and h or 0.0) - 0.05, false, false, false)
    SetModelAsNoLongerNeeded(M.netSea)
    SetEntityHeading(obj, GetEntityHeading(veh))
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return obj
end

-- satu prop per kunci; model berubah (peti kosong -> isi) = dibuat ulang
local function want(veh, rig, key, model, make)
    local p = rig.props[key]
    if p and p.model == model and DoesEntityExist(p.obj) then return end
    if p then deleteObj(p.obj) end
    rig.props[key] = nil
    if not model then return end
    local obj = make()
    rig.props[key] = { obj = obj, model = model }
    if NLY.onProp then NLY.onProp(veh, key, obj, model) end
end

local function apply(veh, rig, s)
    s = s or {}
    if rig.kind == 'tug' then
        local tc = config.tug
        local base = #tc.crates
        local full = s.f or 0
        -- lapis dasar selalu 8 peti (kosong sampai terisi), peti isi ke-9 dst menumpuk di atasnya
        for i = 1, math.max(base, full, rig.top or 0) do
            local slot, layer = (i - 1) % base + 1, (i - 1) // base
            local model = i <= full and M.crateFull or i <= base and M.crateEmpty or nil
            want(veh, rig, 'crate' .. i, model, function()
                local off = snapToDeck(veh, 'crate' .. slot, tc.crates[slot])
                return attached(model, veh, vec3(off.x, off.y, off.z + layer * tc.crateLayer), tc.crateHeading or 0.0)
            end)
        end
        rig.top = math.max(base, full)
        -- jaring di laut (satu per anggota kru yang sedang menebar): posisi berubah = buat ulang
        local nets = s.w or {}
        for i = 1, math.max(#nets, rig.seaCount or 0) do
            local key, pos = 'sea' .. i, nets[i]
            local sea = rig.props[key]
            if sea and (not pos or #(sea.pos - pos) > 0.5) then
                deleteObj(sea.obj)
                rig.props[key] = nil
            end
            if pos and not rig.props[key] then
                rig.props[key] = { obj = seaNet(pos, veh), model = M.netSea, pos = pos }
            end
        end
        rig.seaCount = #nets
    else
        for i, off in ipairs(config.bison.crates) do
            local model = i <= (s.t or 0) and M.crateFull or nil
            want(veh, rig, 'crate' .. i, model, function() return attached(model, veh, off) end)
        end
    end
end

-- prop jaring di laut terdekat ke posisi itu (dipakai klien.main untuk tali & tarikan)
function NLY.seaNetNear(pos)
    for _, rig in pairs(rigs) do
        for key, p in pairs(rig.props) do
            if key:sub(1, 3) == 'sea' and p.pos and #(p.pos.xy - pos.xy) < 1.0 and DoesEntityExist(p.obj) then return p.obj end
        end
    end
end

local function destroy(rig)
    for key, p in pairs(rig.props) do
        deleteObj(p.obj)
        rig.props[key] = nil
    end
end

AddStateBagChangeHandler('fnl', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    local rig = veh ~= 0 and rigs[veh]
    if rig then apply(veh, rig, value) end
end)

-- kendaraan nelayan yang dekat dapat isinya, yang jauh / hilang dibuang, tiap 1 detik
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local kind = kinds[GetEntityModel(veh)]
            if kind and #(GetEntityCoords(veh) - me) < config.propDistance then
                local state = Entity(veh).state.fnl
                if state then
                    seen[veh] = true
                    if not rigs[veh] then
                        rigs[veh] = { kind = kind, props = {} }
                        apply(veh, rigs[veh], state)
                    end
                end
            end
        end
        for veh, rig in pairs(rigs) do
            if not seen[veh] or not DoesEntityExist(veh) then
                destroy(rig)
                rigs[veh] = nil
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, rig in pairs(rigs) do destroy(rig) end
end)
