-- Deathscreen client. Tidak ada loop per-frame: UI (termasuk countdown) jalan di NUI, tombol lewat
-- key mapping, dan status dibaca dari state bag f_medical. Kontrol gerak sudah dikunci oleh
-- f_medical (hanya mouse look yang aktif), jadi player cuma bisa memutar kamera.

local L = Config.Locale

local DEATH_BAG  = 'f_medical:deathState'
local BLEED_BAG  = 'f_medical:bleedLevel'
local INJURY_BAG = 'f_medical:injuries:'
local ALIVE, DEAD = 1, 3

local BODY_PARTS = {
    'HEAD', 'NECK', 'SPINE', 'UPPER_BODY', 'LOWER_BODY',
    'LARM', 'LHAND', 'LFINGER', 'LLEG', 'LFOOT',
    'RARM', 'RHAND', 'RFINGER', 'RLEG', 'RFOOT',
}

local playerState = LocalPlayer.state
local isOpen = false
local respawning = false
local busy = {}
---@type table?
local deathInfo
---@type vector3?
local downCoords

-------------------------------------------------------------------------------
-- Senjata & penyebab kematian
-------------------------------------------------------------------------------

---hash bisa datang signed atau unsigned tergantung sumbernya, samakan ke unsigned
local function norm(hash)
    hash = math.tointeger(tonumber(hash) or 0) or 0
    if hash < 0 then hash = hash + 4294967296 end
    return hash
end

local WEAPONS = {}
for hash, data in pairs(exports.qbx_core:GetWeapons() or {}) do
    WEAPONS[norm(hash)] = data
end

local function h(name) return norm(joaat(name)) end

local SPECIAL = {
    [h('WEAPON_RUN_OVER_BY_CAR')]     = 'vehicle',
    [h('WEAPON_RAMMED_BY_CAR')]       = 'vehicle',
    [h('WEAPON_HELI_CRASH')]          = 'vehicle',
    [h('VEHICLE_WEAPON_ROTORS')]      = 'vehicle',
    [h('WEAPON_FALL')]                = 'fall',
    [h('WEAPON_DROWNING')]            = 'drowned',
    [h('WEAPON_DROWNING_IN_VEHICLE')] = 'drowned',
    [h('WEAPON_EXPLOSION')]           = 'explosion',
    [h('WEAPON_FIRE')]                = 'fire',
    [h('WEAPON_MOLOTOV')]             = 'fire',
    [h('WEAPON_PETROLCAN')]           = 'fire',
    [h('WEAPON_BLEEDING')]            = 'bleeding',
    [h('WEAPON_ANIMAL')]              = 'animal',
    [h('WEAPON_COUGAR')]              = 'animal',
    [h('WEAPON_ELECTRIC_FENCE')]      = 'electric',
    [h('WEAPON_STUNGUN')]             = 'electric',
    [h('WEAPON_BARBED_WIRE')]         = 'stabbed',
    [h('WEAPON_EXHAUSTION')]          = 'unknown',
    [h('WEAPON_UNARMED')]             = 'melee',
}

local BLADES = {
    [h('WEAPON_KNIFE')] = true, [h('WEAPON_DAGGER')] = true, [h('WEAPON_MACHETE')] = true,
    [h('WEAPON_SWITCHBLADE')] = true, [h('WEAPON_BOTTLE')] = true, [h('WEAPON_BATTLEAXE')] = true,
    [h('WEAPON_HATCHET')] = true, [h('WEAPON_STONE_HATCHET')] = true,
}

-- GetWeaponDamageType: 2 melee, 3 bullet, 5 explosive, 6 fire, 8 fall, 10 electric, 13 gas
local DAMAGE_TYPE = { [2] = 'melee', [3] = 'shot', [4] = 'shot', [5] = 'explosion', [6] = 'fire', [8] = 'fall', [10] = 'electric', [13] = 'gas' }

local function causeOf(hash, raw)
    if hash == 0 then return 'unknown' end
    if SPECIAL[hash] then return SPECIAL[hash] end
    if BLADES[hash] then return 'stabbed' end
    return DAMAGE_TYPE[GetWeaponDamageType(raw)] or 'unknown'
end

-- pingsan maksimal sekian ms setelah tick lapar/haus qbx_core dianggap karena lapar/haus
local STARVE_WINDOW = 3000
local STARVE_CAUSE = { hunger = 'starved', thirst = 'dehydrated', both = 'starvedDehydrated' }

-- kategori yang punya "murder weapon" beneran (bukan jatuh, tenggelam, dll)
local HAS_WEAPON = { shot = true, melee = true, stabbed = true, explosion = true, fire = true, electric = true }

local function streetLabel(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    if street == '' then street = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) end
    return street
end

---Rekam info kematian sekali per kejadian (dipanggil saat pertama tergeletak)
local function captureDeath(attacker, weapon)
    if deathInfo then return end
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    downCoords = coords

    local raw = tonumber(weapon) or GetPedCauseOfDeath(ped)
    local hash = norm(raw)
    local cause = causeOf(hash, raw)
    local hasAttacker = attacker and attacker ~= 0 and DoesEntityExist(attacker) and attacker ~= ped

    -- lapar/haus mengurangi darah lewat SetEntityHealth (qbx_core loops.lua) yang tidak mencatat
    -- penyebab, jadi GetPedCauseOfDeath masih berisi kerusakan lama (mis. jatuh). Pakai penanda qbx_core.
    local starve = playerState.f_starveAt
    if not hasAttacker and type(starve) == 'table' and GetGameTimer() - (starve.t or 0) < STARVE_WINDOW then
        cause = STARVE_CAUSE[starve.kind] or 'starved'
        hash = 0
    end

    local weaponLabel, weaponImage
    local wdata = WEAPONS[hash]
    if wdata and HAS_WEAPON[cause] and hash ~= h('WEAPON_UNARMED') then
        weaponLabel = (wdata.label or wdata.name or ''):upper()
        weaponImage = wdata.name and ('nui://ox_inventory/web/images/%s.png'):format(wdata.name:upper()) or nil
    elseif hash == h('WEAPON_UNARMED') then
        weaponLabel = 'FISTS'
    end

    local distance
    if hasAttacker then
        distance = ('%.1f m'):format(#(GetEntityCoords(attacker) - coords))
    end

    deathInfo = {
        cause    = cause,
        causeLabel = L.causes[cause] or L.causes.unknown,
        weapon   = weaponLabel,
        image    = weaponImage,
        distance = distance,
        time     = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        location = streetLabel(coords),
    }
end

AddEventHandler('f_medical:client:onPlayerLaststand', captureDeath)
AddEventHandler('f_medical:client:onPlayerDied', captureDeath)

-------------------------------------------------------------------------------
-- NUI
-------------------------------------------------------------------------------

local function collectInjuries()
    local out = {}
    for i = 1, #BODY_PARTS do
        local key = BODY_PARTS[i]
        local injury = playerState[INJURY_BAG .. key]
        if injury and injury.severity then out[key] = injury.severity end
    end
    return out
end

local keybinds = {}

local function keyLabels()
    return {
        dispatch = keybinds.dispatch and keybinds.dispatch:getCurrentKey() or Config.Keys.dispatch,
        sync     = keybinds.sync and keybinds.sync:getCurrentKey() or Config.Keys.sync,
    }
end

local function setKeysEnabled(enabled)
    for _, kb in pairs(keybinds) do kb:disable(not enabled) end
end

-- HUD f_hud disembunyikan selama layar kematian tampil (supaya tidak bertumpuk)
local function setHud(visible)
    if GetResourceState('f_hud') ~= 'started' then return end
    pcall(function() exports.f_hud:ToggleVisible(visible) end)
end

-- f_hud memunculkan HUD lagi setiap pause menu ditutup -> sembunyikan ulang selama layar masih terbuka
local function guardHud()
    CreateThread(function()
        local paused = false
        while isOpen do
            local now = IsPauseMenuActive()
            if paused and not now then
                Wait(250) -- tunggu f_hud selesai memunculkan HUD, baru disembunyikan lagi
                if isOpen then setHud(false) end
            end
            paused = now
            Wait(500)
        end
    end)
end

local function closeScreen()
    deathInfo = nil
    downCoords = nil
    if not isOpen then return end
    isOpen = false
    setKeysEnabled(false)
    SendNUIMessage({ action = 'close' })
    setHud(true)
end

local opening = false

-- sudah dipindah ke kasur rumah sakit: layar tidak dibuka lagi sampai benar-benar bangun
local inHospital = false
---@type fun(walkAway: boolean)
local cleanupDoctor

local function openScreen(state)
    if inHospital then return end
    if isOpen then
        SendNUIMessage({ action = 'phase', data = state == DEAD and 'dead' or 'down' })
        return
    end
    if opening then return end
    opening = true

    -- f_medical mengirim event onPlayerLaststand (berisi attacker & senjata) SETELAH state bag
    -- berubah, jadi beri waktu sebentar sebelum memakai fallback
    Wait(300)
    if not deathInfo then captureDeath(nil, nil) end -- mis. relog dalam keadaan tergeletak

    local srv = lib.callback.await('f_deathscreen:server:getState', false)
    opening = false
    if not srv or not srv.downed or srv.inBed or inHospital then return end
    -- status bisa berubah selama menunggu server
    local now = playerState[DEATH_BAG]
    if not now or now == ALIVE then
        deathInfo = nil
        return
    end

    isOpen = true
    setKeysEnabled(true)
    setHud(false)
    guardHud()
    SendNUIMessage({
        action = 'open',
        data = {
            phase     = now == DEAD and 'dead' or 'down',
            remaining = srv.remaining,
            total     = Config.BleedoutTime,
            ems       = srv.ems,
            ai        = srv.ai,
            emsTreating = srv.emsTreating,
            info      = deathInfo,
            injuries  = collectInjuries(),
            bleed     = playerState[BLEED_BAG] or 0,
            keys      = keyLabels(),
            locale    = { ui = L.ui, body = L.body, severity = L.severity, bleed = L.bleed },
        },
    })
end

local function onDeathState(value)
    if not LocalPlayer.state.isLoggedIn then return end
    if value and value ~= ALIVE then
        CreateThread(function() openScreen(value) end)
    else
        inHospital = false
        if cleanupDoctor then cleanupDoctor(true) end
        closeScreen()
    end
end

AddStateBagChangeHandler(DEATH_BAG, ('player:%s'):format(cache.serverId), function(_, _, value)
    onDeathState(value)
end)

-- update diagram luka & pendarahan secara live selama layar terbuka (event-driven, bukan loop)
for i = 1, #BODY_PARTS do
    AddStateBagChangeHandler(INJURY_BAG .. BODY_PARTS[i], ('player:%s'):format(cache.serverId), function()
        if not isOpen then return end
        SetTimeout(0, function() SendNUIMessage({ action = 'injuries', data = collectInjuries() }) end)
    end)
end

AddStateBagChangeHandler(BLEED_BAG, ('player:%s'):format(cache.serverId), function(_, _, value)
    if isOpen then SendNUIMessage({ action = 'bleed', data = value or 0 }) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- f_medical memulihkan status mati dari metadata ~1 detik setelah load
    SetTimeout(2500, function() onDeathState(playerState[DEATH_BAG]) end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    inHospital = false
    if cleanupDoctor then cleanupDoctor(false) end
    closeScreen()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    SetTimeout(1000, function() onDeathState(playerState[DEATH_BAG]) end)
end)

-------------------------------------------------------------------------------
-- Dispatch (E)
-------------------------------------------------------------------------------

local function doDispatch()
    if not isOpen or respawning or busy.dispatch then return end
    busy.dispatch = true
    SendNUIMessage({ action = 'press', data = 'dispatch' })
    local res = lib.callback.await('f_deathscreen:server:dispatch', false, streetLabel(GetEntityCoords(cache.ped)))
    SendNUIMessage({ action = 'dispatch', data = res or { ok = false } })
    busy.dispatch = false
end

-------------------------------------------------------------------------------
-- Sync (H): perbaiki posisi/animasi/visibilitas tanpa menghidupkan karakter
-------------------------------------------------------------------------------

local function fixPed()
    local ped = cache.ped
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    if cache.vehicle then return end

    local c = GetEntityCoords(ped)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        Wait(50)
    end

    -- cari tanah di bawah; kalau tidak ketemu (karakter sudah di bawah map) cari dari atas
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if not found then found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 100.0, false) end

    if found then
        if math.abs(c.z - groundZ) > 1.5 then
            SetEntityCoordsNoOffset(ped, c.x, c.y, groundZ + 0.5, false, false, false)
        end
    elseif downCoords then
        SetEntityCoordsNoOffset(ped, downCoords.x, downCoords.y, downCoords.z, false, false, false)
    end

    -- animasi tergeletak otomatis dipasang ulang oleh loop f_medical / f_ambulancejob
    ClearPedTasksImmediately(ped)
end

local function doSync()
    if not isOpen or respawning or busy.sync then return end
    busy.sync = true
    SendNUIMessage({ action = 'press', data = 'sync' })

    local res = lib.callback.await('f_deathscreen:server:sync', false)
    local state = playerState[DEATH_BAG]

    if res and res.ok then
        fixPed()
        -- replikasi ulang status mati supaya player lain melihat kondisi yang sama
        if state and state ~= ALIVE then playerState:set(DEATH_BAG, state, true) end
        res.injuries = collectInjuries()
        res.bleed = playerState[BLEED_BAG] or 0
    elseif res and res.reason == 'notdown' and state and state ~= ALIVE then
        -- server mengira kita sudah bangun padahal belum: kirim ulang statusnya
        playerState:set(DEATH_BAG, state, true)
        fixPed()
        res = { ok = true, cooldown = Config.SyncCooldown }
    end

    SendNUIMessage({ action = 'sync', data = res or { ok = false } })
    busy.sync = false
end

keybinds.dispatch = lib.addKeybind({
    name = 'f_deathscreen_dispatch',
    description = 'Deathscreen: call EMS / AI doctor',
    defaultMapper = 'keyboard',
    defaultKey = Config.Keys.dispatch,
    disabled = true,
    onPressed = function() CreateThread(doDispatch) end,
})

keybinds.sync = lib.addKeybind({
    name = 'f_deathscreen_sync',
    description = 'Deathscreen: sync character',
    defaultMapper = 'keyboard',
    defaultKey = Config.Keys.sync,
    disabled = true,
    onPressed = function() CreateThread(doSync) end,
})

-------------------------------------------------------------------------------
-- Dibawa ke kasur rumah sakit (hanya atas perintah server)
-------------------------------------------------------------------------------
-- Server memanggil f_ambulancejob CheckIn setelah kita siap: player dimasukkan ke kasur,
-- dirawat, lalu tekan E untuk bangun (biaya dipotong saat itu oleh f_ambulancejob).

RegisterNetEvent('f_deathscreen:client:respawn', function(hospitalLabel)
    if GetInvokingResource() or respawning then return end
    local state = playerState[DEATH_BAG]
    if not state or state == ALIVE then return end
    respawning = true

    SendNUIMessage({ action = 'transport', data = hospitalLabel })
    if cleanupDoctor then cleanupDoctor(false) end
    Wait(1500)

    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(50) end

    if QBX.PlayerData.metadata and QBX.PlayerData.metadata.ishandcuffed then
        TriggerEvent('police:client:GetCuffed', -1)
    end
    TriggerEvent('police:client:DeEscort')
    if cache.vehicle then ClearPedTasksImmediately(cache.ped) end

    -- last stand memutar animasi menggeliat tiap frame (akan terlihat aneh di kasur);
    -- jadikan "mati" dulu supaya f_ambulancejob memakai animasi berbaring di kasur
    if playerState[DEATH_BAG] ~= DEAD then
        exports.f_medical:KillPlayer()
    end

    inHospital = true
    closeScreen()
    TriggerServerEvent('f_deathscreen:server:readyForBed')
    respawning = false
    -- layar dibuka lagi (fade in) oleh f_ambulancejob setelah player berbaring di kasur
end)

RegisterNetEvent('f_deathscreen:client:bedsFull', function()
    if GetInvokingResource() then return end
    inHospital = false
    DoScreenFadeIn(500)
    exports.qbx_core:Notify(L.ui.bedsFull, 'error')
    onDeathState(playerState[DEATH_BAG])
end)

-- EMS membuka panel Cek Pasien / menjalankan tindakan: countdown dijeda di server
RegisterNetEvent('f_deathscreen:client:emsTreating', function(active, remaining)
    if GetInvokingResource() then return end
    if isOpen then SendNUIMessage({ action = 'ems', data = { active = active, remaining = remaining } }) end
end)

-------------------------------------------------------------------------------
-- Dokter AI (dipanggil server setelah pembayaran berhasil)
-------------------------------------------------------------------------------

local AI = Config.AiDoctor
local CPR_DICT, CPR_ANIM = 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest'
local doctor = { ped = nil, blip = nil, active = false }

cleanupDoctor = function(walkAway)
    doctor.active = false
    if doctor.blip then RemoveBlip(doctor.blip) end
    doctor.blip = nil

    local ped = doctor.ped
    doctor.ped = nil
    if not ped or not DoesEntityExist(ped) then return end

    if walkAway then
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetTimeout(10000, function()
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end)
    else
        DeleteEntity(ped)
    end
end

local function doctorSpawnPoint()
    local me = GetEntityCoords(cache.ped)
    local angle = math.random() * math.pi * 2
    local x = me.x + math.cos(angle) * AI.SpawnDistance
    local y = me.y + math.sin(angle) * AI.SpawnDistance
    local found, safe = GetSafeCoordForPed(x, y, me.z, true, 16)
    if found then return safe end
    -- tidak ada titik aman (mis. di dalam interior): muncul dekat player
    return GetOffsetFromEntityInWorldCoords(cache.ped, 2.0, 2.0, 0.0)
end

RegisterNetEvent('f_deathscreen:client:aiDoctor', function(reviveTime)
    if GetInvokingResource() or doctor.active then return end
    doctor.active = true
    SendNUIMessage({ action = 'status', data = 'aiComingSub' })

    local model = joaat(AI.Model)
    local loaded = pcall(lib.requestModel, model, 10000)
    if not loaded or not doctor.active then
        -- model gagal dimuat: server tetap merevive lewat timeout
        doctor.active = false
        return
    end

    local pos = doctorSpawnPoint()
    local ped = CreatePed(4, model, pos.x, pos.y, pos.z, 0.0, true, false)
    SetModelAsNoLongerNeeded(model)
    doctor.ped = ped

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedCanRagdoll(ped, false)

    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 61)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    doctor.blip = blip

    TaskGoToEntity(ped, cache.ped, -1, 1.2, 2.0, 1073741824, 0)

    local arriveBy = GetGameTimer() + AI.ArriveTimeout * 1000
    while doctor.active and DoesEntityExist(ped) do
        if #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) <= 1.8 then break end
        if GetGameTimer() > arriveBy then
            -- nyangkut di jalan: pindahkan ke samping player
            local p = GetOffsetFromEntityInWorldCoords(cache.ped, 1.0, 0.0, 0.0)
            SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
            break
        end
        Wait(250)
    end
    if not doctor.active or not DoesEntityExist(ped) then return end

    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, cache.ped, 1000)
    Wait(1000)
    lib.requestAnimDict(CPR_DICT, 5000)
    TaskPlayAnim(ped, CPR_DICT, CPR_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(CPR_DICT)
    SendNUIMessage({ action = 'status', data = 'aiTreating' })

    local doneAt = GetGameTimer() + (reviveTime or AI.ReviveTime) * 1000
    while doctor.active and GetGameTimer() < doneAt do Wait(250) end
    if not doctor.active then return end

    -- server yang memutuskan & menghidupkan (mengecek lama CPR)
    TriggerServerEvent('f_deathscreen:server:aiDoctorDone')
end)

-------------------------------------------------------------------------------
-- Blip untuk EMS
-------------------------------------------------------------------------------

---@type table<integer, { blip: integer, radius: integer?, token: integer }>
local emsBlips = {}
local blipToken = 0

local function removeEmsBlip(patient)
    local b = emsBlips[patient]
    if not b then return end
    RemoveBlip(b.blip)
    if b.radius then RemoveBlip(b.radius) end
    emsBlips[patient] = nil
end

RegisterNetEvent('f_deathscreen:client:emsBlip', function(patient, coords)
    if GetInvokingResource() then return end
    removeEmsBlip(patient)

    local cfg = Config.Blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.color)
    SetBlipScale(blip, cfg.scale)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L.blipName)
    EndTextCommandSetBlipName(blip)

    local radius
    if (cfg.radius or 0) > 0 then
        radius = AddBlipForRadius(coords.x, coords.y, coords.z, cfg.radius)
        SetBlipColour(radius, cfg.color)
        SetBlipAlpha(radius, 110)
    end

    blipToken += 1
    local token = blipToken
    emsBlips[patient] = { blip = blip, radius = radius, token = token }
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)

    SetTimeout(cfg.duration * 1000, function()
        if emsBlips[patient] and emsBlips[patient].token == token then removeEmsBlip(patient) end
    end)
end)

RegisterNetEvent('f_deathscreen:client:removeBlip', function(patient)
    if GetInvokingResource() then return end
    removeEmsBlip(patient)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for patient in pairs(emsBlips) do removeEmsBlip(patient) end
    cleanupDoctor(false)
    if isOpen then setHud(true) end
end)
