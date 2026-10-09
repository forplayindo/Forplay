local function GetPeeAnim()
    return HygieneIsFemale() and Config.Kencing.PeeAnimFemale or Config.Kencing.PeeAnim
end

-- propData.sitting = true kalau wanita kencing di toilet - duduk kayak poop (bukan berdiri),
-- pakai animasi & trik posisi Z yang sama persis dengan client/poop.lua.
-- Kalau tidak sitting DAN tidak ada propData (kencing sembarangan) DAN wanita -> jongkok
-- (PeeAnimFemale), tidak disamain kayak pria berdiri, dan tidak keluar efek air.
local function TryPee(propData)
    if HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping or HygieneState.isSleeping then return end
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        HygieneNotify('Tidak bisa dilakukan di dalam kendaraan', 'error')
        return
    end

    if not propData then
        if HygieneNearbyPlayers(HygieneCoords(), Config.Kencing.SafeDistance) > 0 then
            HygieneNotify('Ada orang di sekitar, cari tempat yang lebih sepi', 'error')
            return
        end
    end

    HygieneState.isPeeing = true

    -- matikan dulu animasi lain yang mungkin masih nempel (lalat, kebelet dll) supaya tidak
    -- bentrok/numpuk sama animasi kencing yang mau dimainkan
    ClearPedTasks(ped)

    local sitting = propData and propData.sitting
    local squatting = not sitting and not propData and HygieneIsFemale()
    local anim = sitting and Config.Poop.ToiletAnim or GetPeeAnim()
    local frozen = false
    local savedAppearance = nil

    if sitting then
        -- duduk: sama persis polanya dengan client/poop.lua (posisi Z = Z player + SeatOffset.z,
        -- freeze manual karena TaskPlayAnim mentah tidak lock fisika kayak scenario, celana
        -- dilepas sementara juga)
        savedAppearance = exports['illenium-appearance']:getPedAppearance(ped) --[[@as table]]
        HygieneUndressLegs(ped)

        local seat = Config.Poop.SeatOffset
        local seatZ = GetEntityCoords(ped).z + (seat.offset and seat.offset.z or -0.5)
        RequestAnimDict(anim.dict)
        local timeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end
        SetEntityCoords(ped, propData.coords.x, propData.coords.y, seatZ, false, false, false, false)
        SetEntityHeading(ped, propData.heading)
        FreezeEntityPosition(ped, true)
        frozen = true
        if HasAnimDictLoaded(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    elseif propData and propData.coords then
        -- berdiri (pria di toilet, atau siapapun di toilet dgn versi lama): snap ke koordinat/
        -- heading toilet dulu sebelum animasi, supaya tidak main "di tempat berdiri"
        HygienePositionAt(ped, propData.coords, propData.heading)
    end
    -- kalau squatting (wanita kencing sembarangan): tidak perlu reposisi apapun, cukup jongkok
    -- di tempat dia berdiri sekarang - animasinya dimainkan lewat progressBar di bawah

    -- efek air kencing: tidak buat versi duduk (sitting) atau jongkok wanita (squatting)
    local fxHandle = nil
    if not sitting and not squatting then
        local fx = propData and Config.Kencing.PeeEffectToilet or Config.Kencing.PeeEffect
        RequestNamedPtfxAsset(fx.dict)
        local fxTimeout = GetGameTimer() + 1500
        while not HasNamedPtfxAssetLoaded(fx.dict) and GetGameTimer() < fxTimeout do Wait(0) end
        if HasNamedPtfxAssetLoaded(fx.dict) then
            UseParticleFxAssetNextCall(fx.dict)
            local rot = fx.rot or vector3(0.0, 0.0, 0.0)
            fxHandle = StartParticleFxLoopedOnEntity(fx.name, ped, fx.offset.x, fx.offset.y, fx.offset.z, rot.x, rot.y, rot.z, 1.0, false, false, false)
        end
    end

    local finished = lib.progressBar({
        duration = Config.Kencing.PeeDuration,
        label = 'Sedang kencing...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        -- kalau duduk, animasinya sudah dimainkan manual di atas - progressBar cuma buat UI/durasi.
        -- squatting (wanita jongkok sembarangan) tetap lewat sini sama seperti versi berdiri
        anim = sitting and nil or { dict = anim.dict, clip = anim.clip, flag = 49 },
    })

    if fxHandle then
        StopParticleFxLooped(fxHandle, false)
    end

    if frozen then
        FreezeEntityPosition(ped, false)
    end
    ClearPedTasks(ped)

    -- kembalikan celana semula (kalau tadi dilepas)
    if savedAppearance then
        exports['illenium-appearance']:setPedAppearance(ped, savedAppearance)
    end

    HygieneState.isPeeing = false
    -- reset optimis di client dulu (jangan nunggu balesan server) - kalau tidak, ada jeda ~1
    -- detik dimana HygieneState.kencing masih kebaca 100% dan animasi "kebelet" di main.lua
    -- nge-trigger lagi begitu isPeeing balik false
    if finished then
        HygieneState.kencing = 0
    end
    TriggerEvent('hygiene:client:RefreshHud') -- reaktifkan efek/clipset yang di-pause selama kencing

    if finished then
        TriggerServerEvent('hygiene:server:FinishKencing')
    else
        HygieneNotify('Dibatalkan', 'error')
    end
end

local function RegisterKencingRadial()
    lib.addRadialItem({
        id = 'hygiene_kencing',
        label = 'Kencing',
        icon = 'droplet',
        onSelect = function()
            TryPee(nil)
        end,
    })
end
RegisterNetEvent('hygiene:client:RegisterRadial', RegisterKencingRadial)
RegisterKencingRadial()

-- toilet: satu zone ox_target per titik yang didaftarkan manual di Config.ToiletLocations.
-- zoneCoords (opsional) = titik munculnya target/crosshair (misal di depan toilet, gampang
-- di-klik), kalau tidak diisi pakai coords yang sama dengan titik duduk final
for i, loc in ipairs(Config.ToiletLocations) do
    exports.ox_target:addSphereZone({
        coords = loc.zoneCoords or loc.coords,
        radius = Config.ToiletZoneRadius,
        options = {
            {
                name = ('hygiene_kencing_toilet_%d'):format(i),
                icon = 'fas fa-toilet',
                label = 'Kencing',
                canInteract = function()
                    return not HygieneIsBusy()
                end,
                onSelect = function()
                    if HygieneIsFemale() then
                        -- wanita kencing di toilet: duduk, posisi dihitung sama persis kayak
                        -- poop (lihat client/poop.lua & Config.Poop.SeatOffset)
                        local seat = Config.Poop.SeatOffset
                        local sitHeading = (loc.heading + (seat.headingFlip or 180.0)) % 360.0
                        local sitCoords = HygieneOffsetCoords(loc.coords, sitHeading, seat.offset)
                        TryPee({ coords = sitCoords, heading = sitHeading, sitting = true })
                    else
                        local heading = (loc.heading + (Config.Kencing.HeadingFlip or 0.0)) % 360.0
                        TryPee({ coords = loc.coords, heading = heading })
                    end
                end,
            }
        }
    })
end
