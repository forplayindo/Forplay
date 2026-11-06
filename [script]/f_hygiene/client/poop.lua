-- poop di prop toilet lewat ox_target (duduk), atau sembarang tempat lewat menu radial (jongkok
-- pakai animasi emote "shit" rpemotes, kotoran keluar otomatis)
local function LoadAnim(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function TryPoopAnywhere()
    if HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping or HygieneState.isSleeping then return end
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        HygieneNotify('Tidak bisa dilakukan di dalam kendaraan', 'error')
        return
    end
    if HygieneNearbyPlayers(HygieneCoords(), Config.Poop.SafeDistance) > 0 then
        HygieneNotify('Ada orang di sekitar, cari tempat yang lebih sepi', 'error')
        return
    end

    HygieneState.isPooping = true
    ClearPedTasks(ped)

    -- celana dilepas sementara, sama seperti poop di toilet
    local savedAppearance = exports['illenium-appearance']:getPedAppearance(ped)
    HygieneUndressLegs(ped)

    local anim, propCfg, fx = Config.Poop.AnywhereAnim, Config.Poop.AnywhereProp, Config.Poop.AnywhereEffect
    if LoadAnim(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- tisu di tangan (networked supaya player lain ikut lihat)
    local prop
    local model = joaat(propCfg.model)
    if lib.requestModel(model, 2000) then
        local c = GetEntityCoords(ped)
        prop = CreateObject(model, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, propCfg.bone), propCfg.pos.x, propCfg.pos.y, propCfg.pos.z,
            propCfg.rot.x, propCfg.rot.y, propCfg.rot.z, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
    end

    -- kotoran keluar sendiri setelah jongkok sebentar (rpemotes: harus tahan G)
    local fxHandle, active = nil, true
    CreateThread(function()
        Wait(fx.delay or 0)
        if not active then return end
        RequestNamedPtfxAsset(fx.dict)
        local timeout = GetGameTimer() + 1500
        while not HasNamedPtfxAssetLoaded(fx.dict) and GetGameTimer() < timeout do Wait(0) end
        if not active or not HasNamedPtfxAssetLoaded(fx.dict) then return end
        UseParticleFxAssetNextCall(fx.dict)
        fxHandle = StartNetworkedParticleFxLoopedOnEntityBone(fx.name, ped, fx.offset.x, fx.offset.y, fx.offset.z,
            fx.rot.x, fx.rot.y, fx.rot.z, GetPedBoneIndex(ped, fx.bone), fx.scale or 1.0, false, false, false)
    end)

    local finished = lib.progressBar({
        duration = Config.Poop.PoopDuration,
        label = 'Sedang buang air besar...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    active = false
    if fxHandle then StopParticleFxLooped(fxHandle, false) end
    RemoveNamedPtfxAsset(fx.dict)
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    ClearPedTasks(ped)
    RemoveAnimDict(anim.dict)

    -- kembalikan celana semula
    exports['illenium-appearance']:setPedAppearance(ped, savedAppearance)

    HygieneState.isPooping = false
    if finished then
        HygieneState.poop = 0
    end
    TriggerEvent('hygiene:client:RefreshHud')

    if finished then
        TriggerServerEvent('hygiene:server:FinishPoop')
    else
        HygieneNotify('Dibatalkan', 'error')
    end
end

local function RegisterPoopRadial()
    lib.addRadialItem({
        id = 'hygiene_poop',
        label = 'Buang Air Besar',
        icon = 'poo',
        onSelect = TryPoopAnywhere,
    })
end
RegisterNetEvent('hygiene:client:RegisterRadial', RegisterPoopRadial)
RegisterPoopRadial()

local function TryPoop(propData)
    if HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping or HygieneState.isSleeping then return end
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        HygieneNotify('Tidak bisa dilakukan di dalam kendaraan', 'error')
        return
    end

    HygieneState.isPooping = true

    -- matikan dulu animasi lain yang mungkin masih nempel (lalat, kebelet dll) supaya tidak
    -- bentrok/numpuk sama animasi duduk yang mau dimainkan
    ClearPedTasks(ped)

    -- simpan outfit sebelum celana dilepas, dikembalikan setelah selesai/dibatalkan
    local savedAppearance = exports['illenium-appearance']:getPedAppearance(ped)
    HygieneUndressLegs(ped)

    local anim = Config.Poop.ToiletAnim
    local x, y, heading
    if propData and propData.coords then
        x, y = propData.coords.x, propData.coords.y
        heading = propData.heading or GetEntityHeading(ped)
    else
        local c = GetEntityCoords(ped)
        x, y = c.x, c.y
        heading = GetEntityHeading(ped)
    end

    -- posisi Z = Z player saat ini (pasti ground yang valid) + Config.Poop.SeatOffset.offset.z
    local seat = Config.Poop.SeatOffset
    local seatZ = GetEntityCoords(ped).z + (seat.offset and seat.offset.z or -0.5)

    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end

    SetEntityCoords(ped, x, y, seatZ, false, false, false, false)
    SetEntityHeading(ped, heading)
    -- animasi mentah (bukan scenario) tidak otomatis dikunci fisikanya seperti
    -- TaskStartScenarioAtPosition - freeze manual dulu, kalau tidak ped bisa "didorong balik" ke
    -- ground asli sama collision dan animasinya kelihatan salah lagi
    FreezeEntityPosition(ped, true)
    if HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    local finished = lib.progressBar({
        duration = Config.Poop.PoopDuration,
        label = 'Sedang buang air besar...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    -- kembalikan celana semula
    exports['illenium-appearance']:setPedAppearance(ped, savedAppearance)

    HygieneState.isPooping = false
    -- reset optimis di client dulu (jangan nunggu balesan server) - kalau tidak, ada jeda ~1
    -- detik dimana HygieneState.poop masih kebaca 100% dan animasi "kebelet" di main.lua
    -- nge-trigger lagi begitu isPooping balik false
    if finished then
        HygieneState.poop = 0
    end
    TriggerEvent('hygiene:client:RefreshHud') -- reaktifkan efek/clipset yang di-pause selama poop

    if finished then
        TriggerServerEvent('hygiene:server:FinishPoop')
    else
        HygieneNotify('Dibatalkan', 'error')
    end
end

-- toilet: satu zone ox_target per titik yang didaftarkan manual di Config.ToiletLocations.
-- zoneCoords (opsional) = titik munculnya target/crosshair (misal di depan toilet, gampang
-- di-klik), kalau tidak diisi pakai coords yang sama dengan titik duduk final
for i, loc in ipairs(Config.ToiletLocations) do
    exports.ox_target:addSphereZone({
        coords = loc.zoneCoords or loc.coords,
        radius = Config.ToiletZoneRadius,
        options = {
            {
                name = ('hygiene_poop_toilet_%d'):format(i),
                icon = 'fas fa-toilet',
                label = 'Buang Air Besar',
                canInteract = function()
                    return not HygieneIsBusy()
                end,
                onSelect = function()
                    -- posisi duduk dihitung dari titik kencing yang sama (loc.coords/heading),
                    -- dibalik 180 derajat (membelakangi toilet) + offset kecil - lihat
                    -- Config.Poop.SeatOffset
                    local seat = Config.Poop.SeatOffset
                    local poopHeading = (loc.heading + (seat.headingFlip or 180.0)) % 360.0
                    local poopCoords = HygieneOffsetCoords(loc.coords, poopHeading, seat.offset)
                    TryPoop({ coords = poopCoords, heading = poopHeading })
                end,
            }
        }
    })
end
