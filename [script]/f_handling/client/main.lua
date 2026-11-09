---------------------------------------------------------------------------
-- f_handling (client)
--  * GlobalState['f_handling'] = { ver, cars = { [NAMA] = { n, m = {model}, v = { key = angka meta } } } }
--    -> dipasang global (SetHandling*, untuk spawn berikutnya) + per kendaraan pada
--       mobil yang sedang dikemudikan (SetVehicleHandling*, karena f_mechanicjob wear
--       membuat salinan handling per kendaraan sehingga global tidak sampai ke sana).
--  * Setiap penerapan per kendaraan memicu 'f_handling:applied' (veh, { key = nilai memori })
--    supaya wear f_mechanicjob memperbarui nilai dasarnya.
--  * Panel /handling: geser slider = langsung dicoba di mobil sendiri (hanya client ini),
--    Simpan = server menulis handling.meta + menyiarkan ke semua pemain.
---------------------------------------------------------------------------
local GROUPS = require 'shared.fields'
local STATE_KEY = 'f_handling'
local DEG = math.pi / 180

local FIELD = {}
for _, g in ipairs(GROUPS) do
    for _, f in ipairs(g.fields) do FIELD[f.key] = f end
end

local function u32(h) return h & 0xFFFFFFFF end

local function splitKey(key)
    local tag, axis = key:match('^(.-)%.([xyz])$')
    return tag or key, axis
end

local function mem(def, v)
    if def.conv == 'rad' then return v * DEG end
    return v * (def.conv or 1)
end

---------------------------------------------------------------------------
-- Penerapan
---------------------------------------------------------------------------
---Global (semua kendaraan dengan handling ini di client ini, termasuk spawn berikutnya).
local function applyGlobal(name, values)
    local vec = {}
    for k, v in pairs(values) do
        local def = FIELD[k]
        if def and def.kind ~= 'restart' then
            local tag, axis = splitKey(k)
            if axis then
                vec[tag] = vec[tag] or {}
                vec[tag][axis] = v
            elseif def.int then
                pcall(SetHandlingInt, name, 'CHandlingData', k, math.floor(v + 0.5))
            else
                pcall(SetHandlingFloat, name, 'CHandlingData', k, mem(def, v) + 0.0)
            end
        end
    end
    -- vektor global butuh ketiga sumbu (server selalu mengirim lengkap)
    for tag, a in pairs(vec) do
        if a.x and a.y and a.z then
            pcall(SetHandlingVector, name, 'CHandlingData', tag, vector3(a.x + 0.0, a.y + 0.0, a.z + 0.0))
        end
    end
end

---Per kendaraan (salinan handling milik kendaraan itu).
local function applyVehicle(veh, values)
    if not veh or not DoesEntityExist(veh) then return end
    local floats, vec, topSpeed = {}, {}, false
    for k, v in pairs(values) do
        local def = FIELD[k]
        if def and def.kind ~= 'restart' then
            local tag, axis = splitKey(k)
            if axis then
                vec[tag] = vec[tag] or {}
                vec[tag][axis] = v
            elseif def.int then
                SetVehicleHandlingInt(veh, 'CHandlingData', k, math.floor(v + 0.5))
            else
                local m = mem(def, v) + 0.0
                SetVehicleHandlingFloat(veh, 'CHandlingData', k, m)
                floats[k] = m
                if k == 'fInitialDriveMaxFlatVel' then topSpeed = true end
            end
        end
    end
    for tag, a in pairs(vec) do
        local c = GetVehicleHandlingVector(veh, 'CHandlingData', tag)
        SetVehicleHandlingVector(veh, 'CHandlingData', tag, vector3((a.x or c.x) + 0.0, (a.y or c.y) + 0.0, (a.z or c.z) + 0.0))
    end
    -- batas kecepatan baru baru terbaca game setelah top speed dihitung ulang
    -- (nilai = persen tambahan, 0 = tanpa bonus)
    if topSpeed then ModifyVehicleTopSpeed(veh, 0.0) end
    if next(floats) then TriggerEvent('f_handling:applied', veh, floats) end
end

---------------------------------------------------------------------------
-- Siaran server
---------------------------------------------------------------------------
local live, byModel = {}, {}   -- [NAMA] = { n, m, v } / [hash model] = NAMA
local stateVer = 0
local lastGlobal = {}          -- [NAMA] = { key = angka } yang sudah dipasang global
local appliedVer = {}          -- [veh] = stateVer terakhir yang dipasang per kendaraan

local function liveKeyOf(veh)
    return byModel[u32(GetEntityModel(veh))]
end

local function checkVehicle()
    for v in pairs(appliedVer) do
        if not DoesEntityExist(v) then appliedVer[v] = nil end
    end
    local veh = cache.vehicle
    if not veh or cache.seat ~= -1 then return end
    local key = liveKeyOf(veh)
    if not key or appliedVer[veh] == stateVer then return end
    appliedVer[veh] = stateVer
    applyVehicle(veh, live[key].v)
end

local function onState(st)
    st = type(st) == 'table' and st or {}
    stateVer = st.ver or 0
    live, byModel = st.cars or {}, {}
    for key, c in pairs(live) do
        for _, m in ipairs(c.m or {}) do byModel[u32(joaat(m))] = key end
        local last, diff = lastGlobal[key] or {}, {}
        for k, v in pairs(c.v) do
            if last[k] ~= v then diff[k], last[k] = v, v end
        end
        lastGlobal[key] = last
        if next(diff) then
            -- vektor: kirim lengkap kalau salah satu sumbunya berubah
            for k in pairs(diff) do
                local tag, axis = splitKey(k)
                if axis then
                    for _, a in ipairs({ 'x', 'y', 'z' }) do
                        local kk = tag .. '.' .. a
                        if c.v[kk] then diff[kk] = c.v[kk] end
                    end
                end
            end
            applyGlobal(c.n, diff)
        end
    end
    checkVehicle()
end

AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    onState(value)
end)

CreateThread(function()
    onState(GlobalState[STATE_KEY])
end)

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local panelOpen, focused = false, false
local panelCars = {}           -- [NAMA] = data dari server (cur, orig, models, ...)
local panelByModel = {}        -- [hash model] = NAMA (semua addon, bukan hanya yang diubah)
local previewed = {}           -- [NAMA] = { key = true } yang sedang dicoba

local function currentPanelKey()
    local veh = cache.vehicle
    if not veh then return nil, false end
    return panelByModel[u32(GetEntityModel(veh))], cache.seat == -1
end

local function myVehicleFor(key)
    local veh = cache.vehicle
    if veh and cache.seat == -1 and panelByModel[u32(GetEntityModel(veh))] == key then return veh end
end

local function setCars(list)
    panelCars, panelByModel = {}, {}
    for _, c in ipairs(list) do
        panelCars[c.key] = c
        for _, m in ipairs(c.models or {}) do panelByModel[u32(joaat(m))] = c.key end
    end
end

---Kembalikan semua field yang dicoba ke nilai tersimpan.
local function revert(key)
    local p, car = previewed[key], panelCars[key]
    if not p or not car then previewed[key] = nil return end
    local values = {}
    for k in pairs(p) do values[k] = car.cur[k] end
    -- vektor perlu lengkap untuk global
    for k in pairs(p) do
        local tag, axis = splitKey(k)
        if axis then
            for _, a in ipairs({ 'x', 'y', 'z' }) do values[tag .. '.' .. a] = car.cur[tag .. '.' .. a] end
        end
    end
    applyGlobal(car.name, values)
    applyVehicle(myVehicleFor(key), values)
    previewed[key] = nil
end

local function revertAll()
    for key in pairs(previewed) do revert(key) end
end

local function vehicleInfo()
    local key, driver = currentPanelKey()
    return { key = key, driver = driver }
end

local function openPanel()
    local r = lib.callback.await('f_handling:list', false)
    if not r or not r.ok then
        lib.notify({ type = 'error', description = r and r.msg or 'Gagal membuka editor handling.' })
        return
    end
    if #r.cars == 0 then
        lib.notify({ type = 'info', description = 'Belum ada kendaraan addon dengan HANDLING_FILE.' })
        return
    end
    setCars(r.cars)
    panelOpen, focused = true, true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', cars = r.cars, groups = GROUPS, vehicle = vehicleInfo() })
end

local function closePanel()
    revertAll()
    panelOpen, focused = false, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refocus()
    if not panelOpen or focused then return end
    focused = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'focus' })
end

RegisterCommand('handling', function()
    if panelOpen then refocus() else openPanel() end
end, false)

RegisterCommand('handlingfokus', refocus, false)
RegisterKeyMapping('handlingfokus', 'Editor handling: kembali ke panel', 'keyboard', 'INSERT')

-- ganti / masuk kendaraan: pasang nilai siaran, lalu kabari panel
local function onVehicleChange()
    SetTimeout(400, function()
        checkVehicle()
        if panelOpen then SendNUIMessage({ action = 'vehicle', vehicle = vehicleInfo() }) end
    end)
end
lib.onCache('vehicle', onVehicleChange)
lib.onCache('seat', onVehicleChange)

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb(1)
end)

RegisterNUICallback('drive', function(_, cb)
    focused = false
    SetNuiFocus(false, false)
    cb(1)
end)

---data = { key, values = { field = angka } }  -> dicoba di client ini saja
RegisterNUICallback('preview', function(data, cb)
    local car = panelCars[data.key]
    if not car or type(data.values) ~= 'table' then return cb({ applied = false }) end
    local values, p = {}, previewed[data.key] or {}
    for k, v in pairs(data.values) do
        local def, n = FIELD[k], tonumber(v)
        if def and n then
            values[k] = math.max(def.min, math.min(def.max, n))
            p[k] = true
        end
    end
    -- vektor global butuh ketiga sumbu: lengkapi dari nilai tersimpan / data panel
    for k in pairs(values) do
        local tag, axis = splitKey(k)
        if axis then
            for _, a in ipairs({ 'x', 'y', 'z' }) do
                local kk = tag .. '.' .. a
                if values[kk] == nil then values[kk] = tonumber(data.values[kk]) or car.cur[kk] end
            end
        end
    end
    previewed[data.key] = p
    applyGlobal(car.name, values)
    local veh = myVehicleFor(data.key)
    applyVehicle(veh, values)
    cb({ applied = veh ~= nil })
end)

RegisterNUICallback('revert', function(data, cb)
    if data.key then revert(data.key) end
    cb(1)
end)

RegisterNUICallback('save', function(data, cb)
    local r = lib.callback.await('f_handling:save', false, data.key, data.values)
    if r and r.ok and r.car then
        panelCars[r.car.key] = r.car
        previewed[r.car.key] = nil -- nilai baru datang lewat siaran server
    end
    cb(r or { ok = false, msg = 'Tidak ada respons server.' })
end)

RegisterNUICallback('file', function(data, cb)
    cb(lib.callback.await('f_handling:file', false, data.key) or { ok = false, msg = 'Tidak ada respons server.' })
end)

RegisterNUICallback('spawn', function(data, cb)
    local car = panelCars[data.key]
    local model = car and car.models and car.models[1]
    if not model then return cb({ ok = false, msg = 'Model kendaraan ini tidak ditemukan di vehicles.meta.' }) end
    ExecuteCommand('car ' .. model)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and panelOpen then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------------
-- /handlingcek : bandingkan nilai file dengan nilai memori mobil yang dikendarai
-- untuk memastikan konversi satuan (conv di shared/fields.lua) benar.
---------------------------------------------------------------------------
RegisterCommand('handlingcek', function()
    local r = lib.callback.await('f_handling:list', false)
    if not r or not r.ok then return lib.notify({ type = 'error', description = r and r.msg or 'Ditolak.' }) end
    setCars(r.cars)
    local veh = cache.vehicle
    local key = veh and panelByModel[u32(GetEntityModel(veh))]
    if not key then return lib.notify({ type = 'error', description = 'Naik kendaraan addon dulu.' }) end
    local car = panelCars[key]
    print(('^5[f_handling] cek %s (%s) — file vs memori^0'):format(car.name, car.path))
    print('^3Catatan: rem/grip/suspensi/tenaga bisa beda karena efek aus f_mechanicjob.^0')
    for _, g in ipairs(GROUPS) do
        for _, def in ipairs(g.fields) do
            local k = def.key
            local fileV = car.cur[k]
            if def.kind ~= 'restart' and not def.int and not k:find('.', 1, true) and fileV then
                local got = GetVehicleHandlingFloat(veh, 'CHandlingData', k)
                local want = mem(def, fileV)
                local ok = math.abs(got - want) <= math.max(0.0005, math.abs(want) * 0.02)
                local ratio = fileV ~= 0 and got / fileV or 0
                print(('%s%-34s file %-10s memori %-12.5f harapan %-12.5f rasio %.5f^0'):format(
                    ok and '^2' or '^1', k, tostring(fileV), got, want, ratio))
            end
        end
    end
    lib.notify({ type = 'info', description = 'Hasil cek ada di konsol F8.' })
end, false)
