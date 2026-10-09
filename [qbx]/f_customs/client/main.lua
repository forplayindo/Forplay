-- f_customs (client): zona kustom + NUI pilih modifikasi + preview + kamera.
-- Ringan: tidak ada loop. Zona pakai lib.zones, tombol E pakai keybind yang hanya aktif di dalam zona,
-- kamera digerakkan oleh event mouse dari NUI. Preview hanya lokal; saat menu ditutup kendaraan
-- dikembalikan. Harga & pemasangan diputuskan server (f_mechanicjob).
local cfg = require 'config.shared'
local clientCfg = require 'config.client'
local MODS = require 'config.mods'

local zoneId = nil ---@type integer?
local open, admin = false, false
local vehicle = 0
local orig = {} ---@type table properti awal kendaraan
local touched = {} ---@type table<string, boolean> properti yang sudah dipreview
local cam, yaw, pitch, dist, minDist, maxDist = nil, -40.0, 12.0, 6.0, 3.0, 10.0

---------------------------------------------------------------------------
-- Zona
---------------------------------------------------------------------------
local function canUse()
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return false end
    local class = GetVehicleClass(veh)
    if cfg.deniedClasses[class] then return false end
    local z = zoneId and cfg.zones[zoneId]
    return not (z and z.deniedClasses and z.deniedClasses[class])
end

local function refreshText()
    if zoneId and not open and canUse() then
        lib.showTextUI('[E] Bengkel Kustom', { icon = 'fa-solid fa-spray-can', position = 'left-center' })
    else
        local isOpen, text = lib.isTextUIOpen()
        if isOpen and text == '[E] Bengkel Kustom' then lib.hideTextUI() end
    end
end

local openMenu -- forward

local keybind = lib.addKeybind({
    name = 'f_customs_open',
    description = 'Buka menu bengkel kustom',
    defaultKey = 'E',
    disabled = true,
    onPressed = function()
        if zoneId and not open and canUse() then openMenu(false) end
    end,
})

for i, z in ipairs(cfg.zones) do
    lib.zones.poly({
        points = z.points,
        thickness = cfg.thickness,
        onEnter = function()
            zoneId = i
            keybind:disable(false)
            refreshText()
        end,
        onExit = function()
            if zoneId == i then zoneId = nil end
            keybind:disable(true)
            refreshText()
        end,
    })

    if z.blip then
        local cx, cy, cz = 0.0, 0.0, 0.0
        for _, p in ipairs(z.points) do cx, cy, cz = cx + p.x, cy + p.y, cz + p.z end
        local n = #z.points
        local blip = AddBlipForCoord(cx / n, cy / n, cz / n)
        SetBlipSprite(blip, z.blip.sprite or 72)
        SetBlipColour(blip, z.blip.color or 3)
        SetBlipScale(blip, z.blip.scale or 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(z.blip.label or 'Bengkel Kustom')
        EndTextCommandSetBlipName(blip)
    end
end

lib.onCache('vehicle', function() SetTimeout(0, refreshText) end)
lib.onCache('seat', function() SetTimeout(0, refreshText) end)

---------------------------------------------------------------------------
-- Kamera (orbit, digerakkan mouse dari NUI)
---------------------------------------------------------------------------
local function camApply()
    if not cam or not DoesEntityExist(vehicle) then return end
    local r, p = math.rad(yaw), math.rad(pitch)
    local pos = GetOffsetFromEntityInWorldCoords(vehicle, math.sin(r) * math.cos(p) * dist, math.cos(r) * math.cos(p) * dist, math.sin(p) * dist + 0.4)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    local c = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, 0.25)
    PointCamAtCoord(cam, c.x, c.y, c.z)
end

local function startCam()
    local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
    local size = #(mx - mn)
    minDist, maxDist = size * 0.45, size * 1.4
    dist, yaw, pitch = size * 0.9, -40.0, 12.0
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 50.0)
    camApply()
    RenderScriptCams(true, true, 400, true, false)
end

local function stopCam()
    if not cam then return end
    RenderScriptCams(false, true, 400, true, false)
    DestroyCam(cam, false)
    cam = nil
end

local PRESETS = {
    free = { -40.0, 12.0, 0.9 }, front = { 0.0, 8.0, 0.8 }, side = { 90.0, 6.0, 0.85 },
    rear = { 180.0, 8.0, 0.8 }, wheel = { 60.0, 2.0, 0.5 }, engine = { 0.0, 38.0, 0.7 },
}

---------------------------------------------------------------------------
-- Data untuk NUI
---------------------------------------------------------------------------
local function modOptions(id, isLevel)
    local n = GetNumVehicleMods(vehicle, id)
    if n <= 0 then return end
    local opts = { { v = -1, l = 'Standar' } }
    for i = 0, n - 1 do
        local l
        if isLevel then
            l = ('Level %d'):format(i + 1)
        else
            local label = GetModTextLabel(vehicle, id, i)
            l = label and label ~= '' and GetLabelText(label) or nil
            if not l or l == 'NULL' then l = ('Varian %d'):format(i + 1) end
        end
        opts[#opts + 1] = { v = i, l = l }
    end
    return opts
end

local function wheelTypes()
    local class = GetVehicleClass(vehicle)
    local list = {}
    for _, w in ipairs(clientCfg.wheels) do
        local ok
        if class == 8 then ok = w.id == 6
        elseif class == 22 then ok = w.id == 10
        else ok = w.id ~= 6 and w.id ~= 10 end
        if ok then list[#list + 1] = { id = w.id, label = w.label } end
    end
    return list
end

local function buildCatalog()
    local cat = { perf = {}, body = {}, interior = {}, misc = {} }
    for _, m in ipairs(MODS) do
        local opts = modOptions(m.id, m.level)
        if opts then cat[m.cat][#cat[m.cat] + 1] = { key = m.key, label = m.label, icon = m.icon, level = m.level, opts = opts } end
    end
    if GetVehicleClass(vehicle) ~= 13 then
        cat.perf[#cat.perf + 1] = { key = 'modTurbo', label = 'Turbo', icon = '🌀', toggle = true }
    end

    -- klakson
    local hornN = GetNumVehicleMods(vehicle, 14)
    if hornN > 0 then
        local opts, names = { { v = -1, l = 'Standar' } }, {}
        for _, h in ipairs(clientCfg.modLabels[14] or {}) do names[h.id] = h.label end
        for i = 0, hornN - 1 do opts[#opts + 1] = { v = i, l = names[i] or ('Klakson %d'):format(i + 1) } end
        cat.misc[#cat.misc + 1] = { key = 'modHorns', label = 'Klakson', icon = '📯', opts = opts }
    end

    -- livery (cara baru mod 48, atau cara lama SetVehicleLivery)
    local liv = modOptions(48, false)
    if liv then
        cat.body[#cat.body + 1] = { key = 'modLivery', label = 'Livery', icon = '🖌️', opts = liv }
    else
        local count = GetVehicleLiveryCount(vehicle)
        if count and count > 1 then
            local opts = {}
            for i = 0, count - 1 do opts[#opts + 1] = { v = i, l = ('Livery %d'):format(i + 1) } end
            cat.body[#cat.body + 1] = { key = 'livery', label = 'Livery', icon = '🖌️', opts = opts }
        end
    end

    local extras = {}
    for i = 1, 15 do
        if DoesExtraExist(vehicle, i) then extras[#extras + 1] = i end
    end

    return {
        mods = cat,
        extras = extras,
        paints = clientCfg.paints,
        wheelTypes = wheelTypes(),
        bike = GetVehicleClass(vehicle) == 8,
        xenons = clientCfg.xenon,
        tints = clientCfg.windowTints,
        plates = clientCfg.plateIndexes,
        neonColors = clientCfg.neonColors,
        smokes = clientCfg.tyreSmoke,
    }
end

---Properti awal untuk NUI (extras dengan kunci string supaya aman dikirim sebagai JSON).
local function origForNui()
    local o = table.clone(orig)
    local ex = {}
    for id, v in pairs(orig.extras or {}) do ex[tostring(id)] = v end
    o.extras = ex
    return o
end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------
---ox_lib memasang ban custom bersama velg, jadi lengkapi pasangannya dari kondisi sekarang.
local function complete(props)
    if props.modFrontWheels ~= nil and props.modCustomTiresF == nil then props.modCustomTiresF = GetVehicleModVariation(vehicle, 23) end
    if props.modCustomTiresF ~= nil and props.modFrontWheels == nil then props.modFrontWheels = GetVehicleMod(vehicle, 23) end
    if props.modBackWheels ~= nil and props.modCustomTiresR == nil then props.modCustomTiresR = GetVehicleModVariation(vehicle, 24) end
    if props.modCustomTiresR ~= nil and props.modBackWheels == nil then props.modBackWheels = GetVehicleMod(vehicle, 24) end
    return props
end

local function revertAll()
    if not DoesEntityExist(vehicle) or not next(touched) then return end
    local r = {}
    for k in pairs(touched) do r[k] = orig[k] end
    if touched.extras then r.extras = orig.extras or {} end
    if r.modFrontWheels ~= nil or r.modCustomTiresF ~= nil then
        r.modFrontWheels, r.modCustomTiresF = orig.modFrontWheels, orig.modCustomTiresF
    end
    if r.modBackWheels ~= nil or r.modCustomTiresR ~= nil then
        r.modBackWheels, r.modCustomTiresR = orig.modBackWheels, orig.modCustomTiresR
    end
    if touched.wheels then r.wheels = orig.wheels end
    lib.setVehicleProperties(vehicle, r)
    touched = {}
end

---------------------------------------------------------------------------
-- Buka / tutup
---------------------------------------------------------------------------
local function closeMenu(keep)
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if DoesEntityExist(vehicle) then
        if not keep then revertAll() end
        SetVehicleDoorShut(vehicle, 4, false)
        FreezeEntityPosition(vehicle, false)
    end
    stopCam()
    touched = {}
    refreshText()
end

openMenu = function(asAdmin)
    if open then return end
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then
        return exports.qbx_core:Notify('Kamu harus mengemudikan kendaraan', 'error')
    end
    local info = lib.callback.await('f_customs:server:info', false, NetworkGetNetworkIdFromEntity(veh), asAdmin)
    if not info or info.error then
        return exports.qbx_core:Notify(info and info.error or 'Bengkel kustom tidak tersedia', 'error')
    end

    vehicle, admin, open, touched = veh, asAdmin == true, true, {}
    SetVehicleModKit(vehicle, 0)
    orig = lib.getVehicleProperties(vehicle) or {}
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    FreezeEntityPosition(vehicle, true)
    lib.hideTextUI()
    startCam()

    local model = GetEntityModel(vehicle)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if name == 'NULL' then name = GetDisplayNameFromVehicleModel(model) end
    SendNUIMessage({
        action = 'open',
        info = info,
        catalog = buildCatalog(),
        orig = origForNui(),
        vehicle = { name = name, plate = qbx.string.trim(GetVehicleNumberPlateText(vehicle)) },
    })
    SetNuiFocus(true, true)
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeMenu(false)
end)

RegisterNUICallback('preview', function(data, cb)
    cb(1)
    if not open or type(data) ~= 'table' or type(data.props) ~= 'table' or not DoesEntityExist(vehicle) then return end
    local props = data.props
    for k in pairs(props) do touched[k] = true end
    if props.extras then
        local ex = {}
        for id, v in pairs(props.extras) do ex[tonumber(id)] = v end
        props.extras = ex
    end
    lib.setVehicleProperties(vehicle, complete(props))
end)

RegisterNUICallback('wheelList', function(data, cb)
    if not open or type(data) ~= 'table' then return cb({}) end
    local wtype = tonumber(data.type) or 0
    local curType, curMod, curVar = GetVehicleWheelType(vehicle), GetVehicleMod(vehicle, 23), GetVehicleModVariation(vehicle, 23)
    SetVehicleWheelType(vehicle, wtype)
    local opts = { { v = -1, l = 'Standar' } }
    for i = 0, GetNumVehicleMods(vehicle, 23) - 1 do
        local label = GetModTextLabel(vehicle, 23, i)
        local l = label and label ~= '' and GetLabelText(label) or nil
        if not l or l == 'NULL' then l = ('Velg %d'):format(i + 1) end
        opts[#opts + 1] = { v = i, l = l }
    end
    SetVehicleWheelType(vehicle, curType)
    SetVehicleMod(vehicle, 23, curMod, curVar)
    cb(opts)
end)

RegisterNUICallback('cam', function(data, cb)
    cb(1)
    if not open or type(data) ~= 'table' then return end
    if data.preset and PRESETS[data.preset] then
        local p = PRESETS[data.preset]
        local size = maxDist / 1.4
        yaw, pitch, dist = p[1], p[2], math.max(minDist, math.min(maxDist, size * p[3]))
        if data.preset == 'engine' then SetVehicleDoorOpen(vehicle, 4, false, false) else SetVehicleDoorShut(vehicle, 4, false) end
    else
        yaw = (yaw - (tonumber(data.dx) or 0) * 0.35) % 360
        pitch = math.max(-5.0, math.min(75.0, pitch + (tonumber(data.dy) or 0) * 0.25))
        if data.zoom then dist = math.max(minDist, math.min(maxDist, dist + (tonumber(data.zoom) or 0) * 0.4)) end
    end
    camApply()
end)

RegisterNUICallback('submit', function(data, cb)
    if not open then return cb({ error = 'Menu tidak terbuka' }) end
    data = type(data) == 'table' and data or {}
    local res = lib.callback.await('f_customs:server:submit', false, NetworkGetNetworkIdFromEntity(vehicle), data.lines, data.dry == true, admin)
    if res and res.applied then
        -- server sudah memasang & menyimpan; preview jangan dikembalikan
        touched = {}
        orig = lib.getVehicleProperties(vehicle) or orig
    end
    cb(res or { error = 'Gagal' })
end)

RegisterNUICallback('done', function(data, cb)
    cb(1)
    closeMenu(type(data) == 'table' and data.keep == true)
end)

---Dipakai f_adminmenu: kustom gratis tanpa zona (server memeriksa izin admin).
exports('OpenMenu', function()
    if open or not cache.vehicle then return false end
    openMenu(true)
    return true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not open then return end
    SetNuiFocus(false, false)
    revertAll()
    if DoesEntityExist(vehicle) then FreezeEntityPosition(vehicle, false) end
    stopCam()
end)
