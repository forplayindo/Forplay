local function GetBathAnim()
    return HygieneIsFemale() and Config.Mandi.BathAnimFemale or Config.Mandi.BathAnim
end

local function UndressForBath(ped)
    local clothes = HygieneIsFemale() and Config.BathClothes.female or Config.BathClothes.male

    for i = 0, 7 do
        ClearPedProp(ped, i)
    end

    exports['illenium-appearance']:setPedAppearance(ped, {
        components = clothes,
        props = {},
    })
end

local function StartBathing(showerData)
    if HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping or HygieneState.isSleeping then return end
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        HygieneNotify('Tidak bisa mandi di dalam kendaraan', 'error')
        return
    end

    HygieneState.isBathing = true

    -- matikan dulu animasi lain yang mungkin masih nempel (lalat, kebelet dll) supaya tidak
    -- bentrok sama animasi mandi yang mau dimainkan
    ClearPedTasks(ped)

    -- snap ke koordinat/heading shower dulu sebelum animasi, supaya tidak main "di tempat berdiri"
    if showerData and showerData.coords then
        HygienePositionAt(ped, showerData.coords, showerData.heading)
    end

    local anim = GetBathAnim()

    -- simpan outfit sebelum dilepas, dikembalikan setelah selesai mandi
    local savedAppearance = exports['illenium-appearance']:getPedAppearance(ped)
    FreezeEntityPosition(ped, true)
    UndressForBath(ped)
    FreezeEntityPosition(ped, false)

    RequestAnimDict(anim.dict)
    local animTimeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < animTimeout do Wait(0) end

    local waterActive = false
    if showerData then
        local fx = Config.Mandi.ShowerWaterEffect
        RequestNamedPtfxAsset(fx.dict)
        local timeout = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(fx.dict) and GetGameTimer() < timeout do Wait(0) end
        waterActive = true
        CreateThread(function()
            while waterActive do
                local pos = GetEntityCoords(ped) + fx.offset
                UseParticleFxAssetNextCall(fx.dict)
                StartParticleFxNonLoopedAtCoord(fx.name, pos.x, pos.y, pos.z, 0.0, 180.0, 0.0, 5.0, false, false, false)
                Wait(fx.interval)
            end
        end)
    end

    local finished = lib.progressBar({
        duration = Config.Mandi.BathDuration,
        label = showerData and 'Sedang mandi (shower)...' or 'Sedang mandi...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = anim.dict, clip = anim.clip, flag = 49 },
    })

    waterActive = false
    ClearPedTasks(ped)

    -- kembalikan pakaian semula
    exports['illenium-appearance']:setPedAppearance(ped, savedAppearance)
    HygieneState.isBathing = false
    -- reset optimis di client dulu (jangan nunggu balesan server) - kalau tidak, ada jeda dimana
    -- HygieneState.mandi masih kebaca tinggi dan animasi lalat di mandi.lua nge-trigger lagi
    if finished then
        HygieneState.mandi = 0
    end
    TriggerEvent('hygiene:client:RefreshHud') -- reaktifkan efek/clipset yang di-pause selama mandi

    if finished then
        TriggerServerEvent('hygiene:server:FinishMandi')
    else
        HygieneNotify('Mandi dibatalkan', 'error')
    end
end

-- shower: satu zone ox_target per titik yang didaftarkan manual di Config.ShowerLocations.
-- zoneCoords (opsional) = titik munculnya target/crosshair (misal di depan shower, gampang
-- di-klik), kalau tidak diisi pakai coords yang sama dengan titik mandi final
for i, loc in ipairs(Config.ShowerLocations) do
    exports.ox_target:addSphereZone({
        coords = loc.zoneCoords or loc.coords,
        radius = Config.ShowerZoneRadius,
        options = {
            {
                name = ('hygiene_mandi_shower_%d'):format(i),
                icon = 'fas fa-shower',
                label = 'Mandi',
                canInteract = function()
                    return not HygieneIsBusy()
                end,
                onSelect = function()
                    StartBathing({ coords = loc.coords, heading = loc.heading })
                end,
            }
        }
    })
end

-- mandi di sungai/laut/kolam renang: cukup cek status "di dalam air" tiap 1 detik (bukan tiap
-- frame, tidak perlu radius pencarian), opsi radial muncul/hilang otomatis mengikuti status itu
local waterRadialAdded = false

local function AddWaterRadial()
    if waterRadialAdded then return end
    waterRadialAdded = true
    lib.addRadialItem({
        id = 'hygiene_mandi_air',
        label = 'Mandi',
        icon = 'droplet',
        onSelect = function()
            StartBathing(nil)
        end,
    })
end

local function RemoveWaterRadial()
    if not waterRadialAdded then return end
    waterRadialAdded = false
    lib.removeRadialItem('hygiene_mandi_air')
end

-- f_radialmenu bisa clear wheel-nya sendiri (lihat client/main.lua) - kalau player masih di
-- air pas itu terjadi, daftarkan ulang
RegisterNetEvent('hygiene:client:RegisterRadial', function()
    if waterRadialAdded then
        waterRadialAdded = false
        AddWaterRadial()
    end
end)

CreateThread(function()
    while true do
        if not HygieneState.isBathing then
            local ped = PlayerPedId()
            if IsEntityInWater(ped) and not IsPedInAnyVehicle(ped, false) then
                AddWaterRadial()
            else
                RemoveWaterRadial()
            end
        end
        Wait(1000)
    end
end)

-- animasi tepuk lalat saat HUD mandi >= FliesPercent (lalat + suara + reaksi sekitar di thread sync di bawah)
local fliesActive = false

RegisterNetEvent('hygiene:client:RefreshHud', function()
    if HygieneState.mandi >= Config.Mandi.FliesPercent and not fliesActive then
        fliesActive = true
        CreateThread(function()
            local dict, anim = Config.Mandi.FliesAnim.dict, Config.Mandi.FliesAnim.anim
            RequestAnimDict(dict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end

            -- gerakan tepuk cuma sekali tiap Config.Mandi.FliesInterval biar tidak terlalu sering, dan gantian
            -- sama animasi reaksi lain (batuk/muntah) lewat HygieneTryPlayReaction
            while fliesActive do
                HygieneTryPlayReaction(3500, function()
                    local p = PlayerPedId()
                    if HasAnimDictLoaded(dict) then
                        TaskPlayAnim(p, dict, anim, 8.0, -8.0, -1, 48, 0, false, false, false)
                    end
                end)
                Wait(Config.Mandi.FliesInterval)
            end

            RemoveAnimDict(dict)
            ClearPedSecondaryTask(PlayerPedId())
        end)
    elseif HygieneState.mandi < Config.Mandi.FliesPercent and fliesActive then
        fliesActive = false
    end
end)

-- lalat (particle) buat SEMUA player kotor di sekitar, termasuk diri sendiri. Sumbernya statebag
-- hygieneFlies yang di-set server. Suara nyamuk + reaksi kibas player sekitar dipicu saat ped kotor
-- itu MULAI main animasi tepuk lalat (animasinya sudah sync bawaan GTA), jadi tanpa event network
local fliesFx = {} -- [serverId] = { ped = ped, handle = handle }
local fliesSwatting = {} -- [serverId] = true selama ped itu sedang main animasi tepuk
local lastReaction = 0

local function StopFliesFx(sid)
    local cur = fliesFx[sid]
    if cur then
        StopParticleFxLooped(cur.handle, false)
        fliesFx[sid] = nil
    end
end

local function StartFliesFx(ped)
    local fx = Config.Mandi.FliesEffect
    if not HasNamedPtfxAssetLoaded(fx.dict) then
        RequestNamedPtfxAsset(fx.dict)
        local timeout = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded(fx.dict) and GetGameTimer() < timeout do Wait(0) end
        if not HasNamedPtfxAssetLoaded(fx.dict) then return nil end
    end
    UseParticleFxAssetNextCall(fx.dict)
    return StartParticleFxLoopedOnEntity(fx.name, ped, fx.offset.x, fx.offset.y, fx.offset.z, 0.0, 0.0, 0.0, fx.scale, false, false, false)
end

local function TryFliesReaction()
    local R = Config.Mandi.FliesReaction
    if LocalPlayer.state.hygieneFlies or cache.vehicle then return end
    if GetGameTimer() - lastReaction < R.Cooldown then return end
    CreateThread(function()
        RequestAnimDict(R.Anim.dict)
        local timeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(R.Anim.dict) and GetGameTimer() < timeout do Wait(0) end
        if not HasAnimDictLoaded(R.Anim.dict) then return end
        local played = HygieneTryPlayReaction(R.Duration, function()
            TaskPlayAnim(cache.ped, R.Anim.dict, R.Anim.anim, 8.0, -8.0, -1, 48, 0, false, false, false)
        end)
        if played then lastReaction = GetGameTimer() end
        RemoveAnimDict(R.Anim.dict)
    end)
end

CreateThread(function()
    local S = Config.Mandi.FliesSync
    local swatDict, swatAnim = Config.Mandi.FliesAnim.dict, Config.Mandi.FliesAnim.anim
    while true do
        local myPed = cache.ped
        local myCoords = GetEntityCoords(myPed)
        local seen, soundDist, react = {}, nil, false

        for _, id in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(id)
            if Player(sid).state.hygieneFlies then
                local ped = GetPlayerPed(id)
                local dist = #(myCoords - GetEntityCoords(ped))
                if dist <= S.Distance then
                    seen[sid] = true
                    local cur = fliesFx[sid]
                    if not cur or cur.ped ~= ped or not DoesParticleFxLoopedExist(cur.handle) then
                        StopFliesFx(sid)
                        local handle = StartFliesFx(ped)
                        if handle then fliesFx[sid] = { ped = ped, handle = handle } end
                    end

                    -- baru mulai tepuk lalat -> bunyi nyamuk (+ reaksi kalau ped orang lain & dekat)
                    local swatting = IsEntityPlayingAnim(ped, swatDict, swatAnim, 3)
                    if swatting and not fliesSwatting[sid] then
                        if not soundDist or dist < soundDist then soundDist = dist end
                        if ped ~= myPed and dist <= Config.Mandi.FliesReaction.Distance then react = true end
                    end
                    fliesSwatting[sid] = swatting or nil
                end
            end
        end

        for sid in pairs(fliesFx) do
            if not seen[sid] then StopFliesFx(sid) end
        end
        for sid in pairs(fliesSwatting) do
            if not seen[sid] then fliesSwatting[sid] = nil end
        end

        if soundDist then
            local volume = math.floor(S.Volume * (1.0 - soundDist / S.Distance) * 100 + 0.5) / 100
            if volume > 0 then SendNUIMessage({ action = 'flies', volume = volume }) end
        end
        if react then TryFliesReaction() end

        Wait(S.Tick)
    end
end)
