-- isi bak truk kru (prop lokal) + muatan bawaan dimatikan, hanya untuk truk kerja (statebag 'flj')
-- 1:1: batang utuh = prop trunk, potongan = prop piece; solo Biff / kru flatbed (config.client truck.solo / truck.crew)
local config, sharedConfig = FLJ.config, FLJ.shared
local tc = config.truck
local per = sharedConfig.piecesPerTrunk

local rigs = {}         -- vehicle -> { kind, props = {}, trunks }
local kinds = {}        -- model hash -> 'solo' | 'crew'
for kind, t in pairs(sharedConfig.trucks) do kinds[joaat(t.model)] = kind end

local slotCache = {}

-- slot tumpukan: kiri-kanan per lapis (di tengah), lapis ke atas; lapis yang duduk di celah lebih rendah (susun sarang lebah)
local function bedSlots(kind)
    if slotCache[kind] then return slotCache[kind] end
    local b = tc[kind].bed
    local a = FLJ.modelAxis(FLJ.models[tc[kind].grid])
    local w = (b.yaw % 180.0 ~= 0.0 and a.len or a.width) * b.squeeze
    local h = a.height * b.squeeze
    local slots, z, prev = {}, b.origin.z, nil
    for _, n in ipairs(b.layers) do
        if prev then z += (prev - n) % 2 == 1 and h * 0.87 or h end
        for i = 0, n - 1 do
            slots[#slots + 1] = vec3(b.origin.x + (i - (n - 1) / 2) * w, b.origin.y, z)
        end
        prev = n
    end
    slotCache[kind] = slots
    return slots
end
FLJ.bedSlots = bedSlots     -- /kayutes [L]

-- slot tumpukan papan: berbaris ke belakang, jarak = sisi prop yang searah truk setelah diputar
function FLJ.plankSlots(kind)
    local p = tc[kind].planks
    local a = FLJ.modelAxis(tc.plankModel)
    local step = p.yaw % 180.0 ~= 0.0 and a.width or a.len
    local slots = {}
    for i = 0, p.count - 1 do
        slots[i + 1] = vec3(p.origin.x, p.origin.y - i * step, p.origin.z)
    end
    return slots, a.yaw + p.yaw
end

local function hideLoad(veh, kind)
    for _, id in ipairs(tc[kind].extrasOff) do
        if DoesExtraExist(veh, id) and IsVehicleExtraTurnedOn(veh, id) then SetVehicleExtra(veh, id, true) end
    end
end

local function destroyRig(rig)
    for _, o in ipairs(rig.props) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    rig.props = {}
end

-- papan hasil sawmill (tampilan saja): tumpukan sesuai config truk
local function showPlanks(veh, rig)
    destroyRig(rig)
    rig.planks = true
    local m = tc.plankModel
    local slots, rot = FLJ.plankSlots(rig.kind)
    lib.requestModel(m, 5000)
    local at = GetEntityCoords(veh)
    for i, s in ipairs(slots) do
        local o = CreateObject(m, at.x, at.y, at.z, false, false, false)
        SetEntityCollision(o, false, false)
        AttachEntityToEntity(o, veh, 0, s.x, s.y, s.z, 0.0, 0.0, rot, false, true, false, false, 2, true)
        rig.props[i] = o
    end
    SetModelAsNoLongerNeeded(m)
end

-- slot bawah = batang utuh, di atasnya potongan; susunan berubah -> bangun ulang
local function setBed(veh, rig, state)
    if state and state.planks then
        if not rig.planks then showPlanks(veh, rig) end
        return
    end
    if rig.planks then
        destroyRig(rig)
        rig.planks = nil
    end
    local bed, trunks = state and state.bed or 0, state and state.trunks or 0
    local list = bedSlots(rig.kind)
    local pieceProps = math.ceil(math.max(bed - trunks * per, 0) / tc[rig.kind].unit)
    if trunks ~= rig.trunks then destroyRig(rig) end
    rig.trunks = trunks
    local count = math.min(trunks + pieceProps, #list)
    local at = GetEntityCoords(veh)
    for i = #rig.props + 1, count do
        local model = i <= trunks and FLJ.models.trunk or FLJ.models.piece
        lib.requestModel(model, 5000)
        local o = CreateObject(model, at.x, at.y, at.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        SetEntityCollision(o, false, false)
        local s = list[i]
        local yaw = FLJ.modelAxis(model).yaw + tc[rig.kind].bed.yaw
        AttachEntityToEntity(o, veh, 0, s.x, s.y, s.z, 0.0, 0.0, yaw, false, true, false, false, 2, true)
        rig.props[i] = o
    end
    for i = #rig.props, count + 1, -1 do
        if DoesEntityExist(rig.props[i]) then DeleteEntity(rig.props[i]) end
        rig.props[i] = nil
    end
end

AddStateBagChangeHandler('flj', nil, function(bagName, _, value)
    local veh = GetEntityFromStateBagName(bagName)
    local rig = veh ~= 0 and rigs[veh]
    if rig then setBed(veh, rig, value) end
end)

-- truk kru yang dekat dapat isi bak, yang jauh / hilang dibuang, tiap 2 detik
CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        local seen = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            local kind = kinds[GetEntityModel(veh)]
            if kind and #(GetEntityCoords(veh) - me) < config.truckDistance then
                local state = Entity(veh).state.flj
                if state then
                    seen[veh] = true
                    hideLoad(veh, kind)
                    if not rigs[veh] then
                        rigs[veh] = { kind = kind, props = {} }
                        setBed(veh, rigs[veh], state)
                    end
                end
            end
        end
        for veh, rig in pairs(rigs) do
            if not seen[veh] or not DoesEntityExist(veh) then
                destroyRig(rig)
                rigs[veh] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, rig in pairs(rigs) do destroyRig(rig) end
end)
