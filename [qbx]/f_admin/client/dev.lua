---------------------------------------------------------------------------
-- Alat developer: salin koordinat, tampilan koordinat & info kendaraan, entity view
-- (freeaim laser + daftar objek/kendaraan/ped terdekat). Semua loop mati kalau tidak dipakai.
---------------------------------------------------------------------------
local dev = { coords = false, vehinfo = false, freeaim = false, objects = false, vehicles = false, peds = false, dist = 20 }
local ENTITY_TYPES = { [1] = 'Ped', [2] = 'Vehicle', [3] = 'Object' }
local POOLS = { objects = 'CObject', vehicles = 'CVehicle', peds = 'CPed' }
local VEH_CLASS = { [0] = 'Compacts', 'Sedans', 'SUVs', 'Coupes', 'Muscle', 'Sports Classics', 'Sports', 'Super', 'Motorcycles', 'Off-road', 'Industrial', 'Utility', 'Vans', 'Cycles', 'Boats', 'Helicopters', 'Planes', 'Service', 'Emergency', 'Military', 'Commercial', 'Trains', 'Open Wheel' }

local function round(v, d) return qbx.math.round(v, d or 2) end

local function text2d(x, y, text, scale)
    SetTextScale(0.0, scale or 0.35)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    for i = 1, #text, 99 do AddTextComponentSubstringPlayerName(text:sub(i, i + 98)) end
    EndTextCommandDisplayText(x, y)
end

local function text3d(c, text)
    SetTextScale(0.0, 0.28)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetDrawOrigin(c.x, c.y, c.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

---------------------------------------------------------------- salin koordinat
local function coordText(kind)
    local c, h = GetEntityCoords(cache.ped), round(GetEntityHeading(cache.ped))
    local x, y, z = round(c.x), round(c.y), round(c.z - 1.0)
    if kind == 'vec2' then return ('vec2(%s, %s)'):format(x, y) end
    if kind == 'vec3' then return ('vec3(%s, %s, %s)'):format(x, y, z) end
    if kind == 'vec4' then return ('vec4(%s, %s, %s, %s)'):format(x, y, z, h) end
    return tostring(h)
end

local function copy(kind)
    lib.setClipboard(coordText(kind))
    Notify(kind == 'heading' and 'Heading disalin' or (kind .. ' disalin ke clipboard'), 'success')
end

RegisterNetEvent('f_admin:client:copy', copy)

---------------------------------------------------------------- tampilan
local function coordsLoop()
    while dev.coords do
        local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
        text2d(0.40, 0.015, ('~o~vec4~w~(%s, %s, %s, %s)'):format(round(c.x), round(c.y), round(c.z), round(h)), 0.45)
        Wait(0)
    end
end

local function vehLoop()
    while dev.vehinfo do
        local v = cache.vehicle
        if v then
            local hash = GetEntityModel(v)
            text2d(0.015, 0.62, ('~o~Gear~w~ %s  ~o~RPM~w~ %s  ~o~Suhu~w~ %s  ~o~Oli~w~ %s'):format(GetVehicleCurrentGear(v), round(GetVehicleCurrentRpm(v), 3), round(GetVehicleEngineTemperature(v), 1), round(GetVehicleOilLevel(v), 2)))
            text2d(0.015, 0.645, ('~o~Mesin~w~ %s  ~o~Body~w~ %s  ~o~Kotor~w~ %s  ~o~Kelas~w~ %s'):format(round(GetVehicleEngineHealth(v), 0), round(GetVehicleBodyHealth(v), 0), round(GetVehicleDirtLevel(v), 1), VEH_CLASS[GetVehicleClass(v)] or '?'))
            text2d(0.015, 0.67, ('~o~Maks~w~ %s km/j  ~o~Net~w~ %s  ~o~Hash~w~ %s  ~o~Nama~w~ %s'):format(round(GetVehicleEstimatedMaxSpeed(v) * 3.6, 0), VehToNet(v), hash, GetLabelText(GetDisplayNameFromVehicleModel(hash))))
            Wait(0)
        else
            Wait(800)
        end
    end
end

---------------------------------------------------------------- entity view
local function modelName(ent, model)
    if IsModelAVehicle(model) then return GetDisplayNameFromVehicleModel(model):lower() end
    local n = GetEntityArchetypeName(ent)
    return (n and n ~= '') and n or 'unknown'
end

local function info(ent)
    local model = GetEntityModel(ent)
    local net = NetworkGetEntityIsNetworked(ent)
    local c, r = GetEntityCoords(ent), GetEntityRotation(ent, 2)
    return {
        type = ENTITY_TYPES[GetEntityType(ent)] or '?', name = modelName(ent, model), model = model,
        coords = ('vec4(%s, %s, %s, %s)'):format(round(c.x), round(c.y), round(c.z), round(GetEntityHeading(ent))),
        rot = ('vec3(%s, %s, %s)'):format(round(r.x), round(r.y), round(r.z)),
        net = net and NetworkGetNetworkIdFromEntity(ent) or nil,
        owner = net and GetPlayerServerId(NetworkGetEntityOwner(ent)) or nil,
        plate = GetEntityType(ent) == 2 and GetVehicleNumberPlateText(ent) or nil,
    }
end

local function deleteEntity(ent)
    if IsEntityAPed(ent) and IsPedAPlayer(ent) then return Notify('Tidak bisa menghapus pemain.', 'error') end
    if NetworkGetEntityIsNetworked(ent) and GetEntityType(ent) == 2 then
        local r = lib.callback.await('f_admin:veh_delete', false, { net = NetworkGetNetworkIdFromEntity(ent) })
        return Notify(r and r.msg or 'Gagal', r and r.ok and 'success' or 'error')
    end
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
    Notify('Entity dihapus (lokal)', 'success')
end

local function freeaimLoop()
    while dev.freeaim do
        local hit, ent, endC = lib.raycast.fromCamera(511, 4, 1000.0)
        local has = hit and ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) ~= 0
        if hit then
            local o = GetEntityCoords(cache.ped)
            local r, g = has and 0 or 255, has and 255 or 0
            DrawLine(o.x, o.y, o.z, endC.x, endC.y, endC.z, r, g, 0, 255)
            DrawMarker(28, endC.x, endC.y, endC.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.05, r, g, 0, 200, false, false, 2, false, nil, nil, false)
        end
        if has then
            local i = info(ent)
            local lines = {
                ('~o~%s~w~ %s  ~o~Hash~w~ %s'):format(i.type, i.name, i.model),
                ('~o~Coords~w~ %s'):format(i.coords),
                ('~o~Rotasi~w~ %s'):format(i.rot),
                ('~o~Net~w~ %s  ~o~Owner~w~ %s%s'):format(i.net or 'lokal', i.owner or '-', i.plate and ('  ~o~Plat~w~ ' .. i.plate) or ''),
                '~y~[E]~w~ salin info  ~y~[G]~w~ hapus',
            }
            for n, l in ipairs(lines) do text2d(0.015, 0.30 + n * 0.022, l) end
            if IsDisabledControlJustPressed(0, 38) then
                lib.setClipboard(('-- %s: %s\nmodel = `%s` -- hash: %s\ncoords = %s\nrotation = %s'):format(i.type, i.name, i.name, i.model, i.coords, i.rot))
                Notify('Info entity disalin', 'success')
            elseif IsDisabledControlJustPressed(0, 47) then
                deleteEntity(ent)
            end
        end
        Wait(0)
    end
end

local poolRunning = false
local function poolsLoop()
    if poolRunning then return end
    poolRunning = true
    local cached, nextRefresh = {}, 0
    while dev.objects or dev.vehicles or dev.peds do
        if GetGameTimer() > nextRefresh then -- daftar disegarkan tiap 500 ms supaya ringan
            nextRefresh = GetGameTimer() + 500
            cached = {}
            local cam = GetFinalRenderedCamCoord()
            for key, pool in pairs(POOLS) do
                if dev[key] then
                    for _, e in ipairs(GetGamePool(pool)) do
                        if e ~= cache.ped and #(GetEntityCoords(e) - cam) <= dev.dist then cached[#cached + 1] = e end
                    end
                end
            end
        end
        for i = 1, #cached do
            local e = cached[i]
            if DoesEntityExist(e) then
                local c, m = GetEntityCoords(e), GetEntityModel(e)
                text3d(vec3(c.x, c.y, c.z + 1.0), ('~o~%s~w~ %s~n~~o~Hash~w~ %s ~o~Net~w~ %s'):format(ENTITY_TYPES[GetEntityType(e)] or '?', modelName(e, m), m,
                    NetworkGetEntityIsNetworked(e) and NetworkGetNetworkIdFromEntity(e) or 'lokal'))
            end
        end
        Wait(0)
    end
    poolRunning = false
end

local LOOP = { coords = coordsLoop, vehinfo = vehLoop, freeaim = freeaimLoop, objects = poolsLoop, vehicles = poolsLoop, peds = poolsLoop }

---------------------------------------------------------------- dari panel
local function devAllowed()
    if lib.callback.await('f_admin:self', false, 'dev', true) then return true end
    Notify('Tidak punya izin alat developer.', 'error')
end

ACT.dev = function()
    local c = GetEntityCoords(cache.ped)
    return { ok = true, dev = dev, pos = { x = round(c.x), y = round(c.y), z = round(c.z - 1.0), h = round(GetEntityHeading(cache.ped)) } }
end

ACT.copy = function(d)
    if not devAllowed() then return { ok = false } end
    copy(d.kind)
    return { ok = true }
end

ACT.devtoggle = function(d)
    if dev[d.k] == nil or d.k == 'dist' then return { ok = false } end
    if not dev[d.k] and not devAllowed() then return { ok = false } end
    dev[d.k] = not dev[d.k]
    if dev[d.k] then CreateThread(LOOP[d.k]) end
    return { ok = true, dev = dev }
end

ACT.devdist = function(d)
    dev.dist = math.max(5, math.min(100, math.floor(tonumber(d.m) or 20)))
    return { ok = true, dev = dev }
end
