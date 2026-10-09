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

-- efek lalat saat HUD mandi mencapai 100%
local fliesActive = false

RegisterNetEvent('hygiene:client:RefreshHud', function()
    if HygieneState.mandi >= Config.Mandi.FliesPercent and not fliesActive then
        fliesActive = true
        CreateThread(function()
            local ped = PlayerPedId()
            local dict, anim = Config.Mandi.FliesAnim.dict, Config.Mandi.FliesAnim.anim
            RequestAnimDict(dict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end

            local fx = Config.Mandi.FliesEffect
            RequestNamedPtfxAsset(fx.dict)
            local fxTimeout = GetGameTimer() + 2000
            while not HasNamedPtfxAssetLoaded(fx.dict) and GetGameTimer() < fxTimeout do Wait(0) end

            local fxHandle = nil
            if HasNamedPtfxAssetLoaded(fx.dict) then
                UseParticleFxAssetNextCall(fx.dict)
                fxHandle = StartParticleFxLoopedOnEntity(fx.name, ped, fx.offset.x, fx.offset.y, fx.offset.z, 0.0, 0.0, 0.0, fx.scale, false, false, false)
            end

            -- particle lalat tetap nempel terus selama fliesActive (di atas), tapi gerakan
            -- menepuk lalatnya cuma sekali tiap Config.Mandi.FliesInterval biar tidak terlalu sering, dan gantian
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
            if fxHandle then
                StopParticleFxLooped(fxHandle, false)
            end
        end)
    elseif HygieneState.mandi < Config.Mandi.FliesPercent and fliesActive then
        fliesActive = false
    end
end)
