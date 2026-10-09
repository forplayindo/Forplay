-- Pilih karakter + lokasi spawn dalam satu layar (NUI ringan, tanpa blur / kamera bergerak).
-- Server qbx_core tetap jadi sumber kebenaran: daftar karakter, jumlah slot, login & pembuatan.
local cfg = require 'config'

local defaultSpawn do
    local src = LoadResourceFile('qbx_core', 'config/shared.lua')
    local chunk = src and load(src, '@@qbx_core/config/shared.lua')
    local ok, shared = pcall(chunk or function() end)
    defaultSpawn = ok and type(shared) == 'table' and shared.defaultSpawn or vec4(-540.58, -212.02, 37.65, 208.88)
end

local DEFAULT_PEDS = {
    [0] = {
        model = `mp_m_freemode_01`,
        components = {
            { component_id = 0, drawable = 0, texture = 0 }, { component_id = 1, drawable = 0, texture = 0 },
            { component_id = 2, drawable = 0, texture = 0 }, { component_id = 5, drawable = 0, texture = 0 },
            { component_id = 7, drawable = 0, texture = 0 }, { component_id = 9, drawable = 0, texture = 0 },
            { component_id = 10, drawable = 0, texture = 0 }, { component_id = 11, drawable = 15, texture = 0 },
            { component_id = 8, drawable = 15, texture = 0 }, { component_id = 3, drawable = 15, texture = 0 },
            { component_id = 6, drawable = 34, texture = 0 }, { component_id = 4, drawable = 61, texture = 0 },
        },
    },
    [1] = {
        model = `mp_f_freemode_01`,
        headBlend = { shapeFirst = 31, shapeSecond = 0, shapeThird = 0, skinFirst = 0, skinSecond = 0, skinThird = 0, shapeMix = 0.3, skinMix = 0, thirdMix = 0 },
        hair = { style = 15, color = 0, highlight = 0, texture = 0 },
        components = {
            { component_id = 0, drawable = 0, texture = 0 }, { component_id = 1, drawable = 0, texture = 0 },
            { component_id = 2, drawable = 0, texture = 0 }, { component_id = 5, drawable = 0, texture = 0 },
            { component_id = 7, drawable = 0, texture = 0 }, { component_id = 9, drawable = 0, texture = 0 },
            { component_id = 10, drawable = 0, texture = 0 }, { component_id = 3, drawable = 15, texture = 0 },
            { component_id = 11, drawable = 15, texture = 3 }, { component_id = 8, drawable = 14, texture = 0 },
            { component_id = 4, drawable = 15, texture = 3 }, { component_id = 6, drawable = 35, texture = 0 },
        },
    },
}

local cam
local isOpen, busy = false, false
local previewToken = 0
---@type PlayerEntity[]
local characters = {}
---@type table<string, { id: integer, label: string }[]>
local properties = {}
local houses = {} -- rumah MLO dari f_spawnpoints

---------------------------------------------------------------------------
-- preview karakter
---------------------------------------------------------------------------
local function applyPreview(model, appearance, token)
    local ok = pcall(lib.requestModel, model, cfg.modelTimeout)
    if not ok or token ~= previewToken then return end
    SetPlayerModel(cache.playerId, model)
    local ped = PlayerPedId()
    pcall(function() exports['illenium-appearance']:setPedAppearance(ped, appearance) end)
    SetModelAsNoLongerNeeded(model)
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, cfg.preview.ped.x, cfg.preview.ped.y, cfg.preview.ped.z, false, false, false, false)
    SetEntityHeading(ped, cfg.preview.ped.w)
end

local function previewNew(gender)
    previewToken += 1
    local token = previewToken
    local ped = DEFAULT_PEDS[gender == 1 and 1 or 0]
    applyPreview(ped.model, ped, token)
end

local function previewCharacter(citizenid)
    previewToken += 1
    local token = previewToken
    local ok, skin, model = pcall(lib.callback.await, 'qbx_core:server:getPreviewPedData', false, citizenid)
    if token ~= previewToken then return end
    local appearance = ok and skin and model and json.decode(skin)
    if appearance then
        applyPreview(model, appearance, token)
    else
        local c
        for i = 1, #characters do if characters[i].citizenid == citizenid then c = characters[i] end end
        previewNew(c and c.charinfo.gender or 0)
    end
end

---------------------------------------------------------------------------
-- kamera & layar
---------------------------------------------------------------------------
local function startCam()
    if cam then return end
    local c = cfg.preview.cam
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, -6.0, 0.0, c.w, cfg.preview.fov, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function stopCam()
    if not cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    cam = nil
end

local function fadeOut(ms)
    DoScreenFadeOut(ms)
    while not IsScreenFadedOut() do Wait(0) end
end

local function closeUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function streetOf(coords)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if street == '' then return zone end
    return ('%s, %s'):format(street, zone)
end

local function nuiCharacters()
    local list = {}
    for i, c in ipairs(characters) do
        local ci, job, gang, money = c.charinfo or {}, c.job or {}, c.gang or {}, c.money or {}
        local locs = { { key = 'last', label = 'Lokasi Terakhir', area = streetOf(c.position), icon = 'pin' } }
        for n, s in ipairs(cfg.spawns) do
            locs[#locs + 1] = { key = 'spawn:' .. n, label = s.label, area = streetOf(s.coords), icon = 'city' }
        end
        for _, p in ipairs(properties[c.citizenid] or {}) do
            locs[#locs + 1] = { key = 'prop:' .. p.id, label = p.label, area = 'Rumah milikmu', icon = 'home' }
        end
        for _, h in ipairs(houses[c.citizenid] or {}) do
            locs[#locs + 1] = { key = 'house:' .. h.id, label = h.label, area = 'Rumah milikmu', icon = 'home' }
        end
        list[i] = {
            citizenid = c.citizenid,
            first = ci.firstname, last = ci.lastname,
            gender = ci.gender,
            birthdate = ci.birthdate,
            nationality = ci.nationality,
            phone = ci.phone,
            job = job.label, grade = job.grade and job.grade.name,
            gang = gang.name ~= 'none' and gang.label or nil,
            bank = money.bank or 0, cash = money.cash or 0,
            locations = locs,
        }
    end
    return list
end

---------------------------------------------------------------------------
-- buka layar pilih karakter
---------------------------------------------------------------------------
local function open()
    if isOpen then return end
    busy = false

    local chars, amount = lib.callback.await('qbx_core:server:getCharacters')
    characters = chars or {}
    properties = lib.callback.await('f_multichar:server:properties') or {}
    houses = lib.callback.await('f_multichar:server:houses') or {}

    DisplayRadar(false)
    SetFollowPedCamViewMode(2)
    if not IsScreenFadedOut() then fadeOut(500) end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, cfg.preview.ped.x, cfg.preview.ped.y, cfg.preview.ped.z, false, false, false, false)
    SetEntityHeading(ped, cfg.preview.ped.w)

    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end

    -- tunggu area bandara termuat (bukan jeda tetap)
    RequestCollisionAtCoord(cfg.preview.ped.x, cfg.preview.ped.y, cfg.preview.ped.z)
    local timeout = GetGameTimer() + 4000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end

    if characters[1] then previewCharacter(characters[1].citizenid) else previewNew(0) end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    startCam()

    isOpen = true
    SendNUIMessage({
        action = 'open',
        characters = nuiCharacters(),
        slots = math.max(amount or 1, #characters),
        birthdate = cfg.birthdate,
    })
    SetNuiFocus(true, true)
    DoScreenFadeIn(600)

    CreateThread(function()
        -- karakter sempat mati saat memilih: SetEntityInvincible kurang andal, jadi diulang
        while NetworkIsInTutorialSession() do
            SetEntityInvincible(PlayerPedId(), true)
            Wait(250)
        end
        SetEntityInvincible(PlayerPedId(), false)
    end)
end

---------------------------------------------------------------------------
-- spawn
---------------------------------------------------------------------------
local function waitCollision(ped, ms)
    local c = GetEntityCoords(ped)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local timeout = GetGameTimer() + ms
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do Wait(0) end
end

local function spawnExisting(coords, propertyId)
    stopCam()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)

    if not propertyId then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, coords.w or 0.0)
        waitCollision(ped, 5000)
    end

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    if propertyId then
        TriggerServerEvent('f_properties:server:enterProperty', { id = propertyId, isSpawn = true })
    end
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
    DoScreenFadeIn(800)
end

local function spawnNew()
    stopCam()
    local ped = PlayerPedId()
    SetEntityCoords(ped, defaultSpawn.x, defaultSpawn.y, defaultSpawn.z, false, false, false, false)
    SetEntityHeading(ped, defaultSpawn.w)
    SetEntityVisible(ped, true, false)
    waitCollision(ped, 5000)
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
    DoScreenFadeIn(250)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
    TriggerEvent('qb-weathersync:client:EnableSync')
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
RegisterNUICallback('select', function(data, cb)
    cb(1)
    if busy then return end
    local c = characters[tonumber(data.index) or 0]
    if c then
        previewCharacter(c.citizenid)
    else
        previewNew(tonumber(data.gender) or 0)
    end
end)

RegisterNUICallback('gender', function(data, cb)
    cb(1)
    if busy then return end
    previewNew(tonumber(data.gender) == 1 and 1 or 0)
end)

RegisterNUICallback('play', function(data, cb)
    if busy then return cb({ error = 'Tunggu sebentar...' }) end
    local c = characters[tonumber(data.index) or 0]
    if not c then return cb({ error = 'Karakter tidak ditemukan' }) end

    -- lokasi diambil dari data di client ini sendiri, bukan koordinat dari NUI
    local key = tostring(data.location or 'last')
    local coords, propertyId
    if key == 'last' then
        coords = c.position
    elseif key:find('^spawn:') then
        local s = cfg.spawns[tonumber(key:sub(7)) or 0]
        coords = s and s.coords
    elseif key:find('^house:') then
        local id = tonumber(key:sub(7))
        for _, h in ipairs(houses[c.citizenid] or {}) do
            if h.id == id then coords = h.coords end
        end
    elseif key:find('^prop:') then
        local id = tonumber(key:sub(6))
        for _, p in ipairs(properties[c.citizenid] or {}) do
            if p.id == id then propertyId = id end
        end
    end
    if not coords and not propertyId then return cb({ error = 'Lokasi tidak valid' }) end

    busy = true
    previewToken += 1
    fadeOut(300)
    local ok, loaded = pcall(lib.callback.await, 'qbx_core:server:loadCharacter', false, c.citizenid)
    if not ok or not loaded then
        busy = false
        DoScreenFadeIn(250)
        return cb({ error = 'Gagal masuk ke karakter ini, coba lagi.' })
    end

    cb({ ok = true })
    closeUI()
    spawnExisting(coords, propertyId)
    busy = false
end)

RegisterNUICallback('create', function(data, cb)
    if busy then return cb({ error = 'Tunggu sebentar...' }) end
    if type(data) ~= 'table' then return cb({ error = 'Data tidak valid' }) end

    busy = true
    local newData = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = tostring(data.firstname or ''),
        lastname = tostring(data.lastname or ''),
        nationality = 'Indonesia', -- server juga memaksa Indonesia
        gender = tonumber(data.gender) == 1 and 1 or 0,
        birthdate = tostring(data.birthdate or ''),
    })
    if not newData then
        busy = false
        return cb({ error = 'Nama atau tanggal lahir tidak valid, atau slot karakter sudah penuh.' })
    end

    cb({ ok = true })
    previewToken += 1
    closeUI()
    fadeOut(300)
    spawnNew()
    busy = false
end)

---------------------------------------------------------------------------
-- start / logout
---------------------------------------------------------------------------
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if GetInvokingResource() then return end -- hanya dari server
    open()
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    if LocalPlayer.state.isLoggedIn then return end -- resource di-restart saat sedang bermain
    Wait(250)
    open()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not isOpen then return end
    closeUI()
    stopCam()
end)
