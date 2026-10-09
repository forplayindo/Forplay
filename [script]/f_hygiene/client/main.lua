-- State & helper bersama, dipakai antar file client (via global, bukan local)
HygieneState = HygieneState or {
    mandi = 0,
    kencing = 0,
    poop = 0,
    isBathing = false,
    isPeeing = false,
    isPooping = false,
    isSleeping = false,
    hudVisible = true,
}

function HygieneNotify(msg, type, duration)
    exports.qbx_core:Notify(msg, type or 'inform', duration or 5000)
end

-- pakai native langsung (bukan cache.ped) supaya tidak error saat thread ini jalan
-- pertama kali di awal resource start, sebelum cache ox_lib sempat "pemanasan"
function HygieneCoords()
    return GetEntityCoords(PlayerPedId())
end

-- cek dari MODEL PED YANG SEDANG DIPAKAI (bukan charinfo.gender data karakter) - supaya tetap
-- akurat kalau ped-nya diganti manual buat testing (misal lewat pedmenu), tidak cuma dari gender
-- yang diset waktu bikin karakter
local femaleModelHash = GetHashKey('mp_f_freemode_01')

function HygieneIsFemale()
    return GetEntityModel(cache.ped) == femaleModelHash
end

-- lepas celana sementara (cuma komponen legs, bukan full-undress kayak mandi) - dipakai bareng
-- oleh poop dan kencing duduk (wanita di toilet)
function HygieneUndressLegs(ped)
    local legs = HygieneIsFemale() and Config.Poop.PoopClothes.female or Config.Poop.PoopClothes.male
    exports['illenium-appearance']:setPedAppearance(ped, {
        components = { legs },
        props = {},
    })
end

-- snap player ke koordinat/heading tetap (dari Config.ToiletLocations dkk) sebelum animasi
-- dimainkan, supaya tidak jalan "di tempat player berdiri" tapi benar-benar pas di titik yang
-- sudah didaftarkan
function HygienePositionAt(ped, coords, heading)
    if not coords then return end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
end

-- hitung koordinat dunia dari satu titik acuan (coords+heading) + offset lokal (x=kanan,
-- y=depan, z=atas relatif ke heading acuan). Dipakai buat menurunkan posisi duduk poop dari
-- titik kencing yang sama (tinggal dibalik headingnya) tanpa perlu cari titik terpisah lagi
function HygieneOffsetCoords(baseCoords, headingDeg, offset)
    offset = offset or vector3(0.0, 0.0, 0.0)
    local rad = math.rad(headingDeg)
    local sin, cos = math.sin(rad), math.cos(rad)
    return vector3(
        baseCoords.x + (offset.x * cos - offset.y * sin),
        baseCoords.y + (offset.x * sin + offset.y * cos),
        baseCoords.z + offset.z
    )
end

-- true kalau player sedang melakukan aksi "penuh" (tidur/mandi/kencing/poop/last-stand/mati) -
-- dipakai sebagai syarat mutlak sebelum animasi reaksi apapun (batuk/muntah/tepuk lalat) boleh
-- jalan, supaya tidak bentrok dengan animasi aksi yang sedang berlangsung
function HygieneIsBusy()
    if HygieneState.isSleeping or HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping then
        return true
    end
    local ok, dead = pcall(function() return exports.f_medical:IsDead() or exports.f_medical:IsLaststand() end)
    return ok and dead or false
end

-- kunci tunggal supaya animasi reaksi (batuk/muntah/tepuk lalat) tidak pernah numpuk lebih dari
-- 1 di waktu yang sama. Kalau lagi dipakai atau player lagi busy, skip giliran ini saja
-- (bukan antri), coba lagi di siklus berikutnya.
HygieneAnimLock = false

function HygieneTryPlayReaction(durationMs, fn)
    if HygieneAnimLock or HygieneIsBusy() then return false end
    HygieneAnimLock = true
    fn()
    CreateThread(function()
        Wait(durationMs or 3500)
        HygieneAnimLock = false
    end)
    return true
end

-- hitung jumlah player lain dalam radius tertentu (dipakai untuk cek "ada orang di sekitar")
function HygieneNearbyPlayers(coords, maxDist)
    local count = 0
    local myPed = cache.ped
    for _, id in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(id)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local dist = #(coords - GetEntityCoords(targetPed))
            if dist <= maxDist then
                count = count + 1
            end
        end
    end
    return count
end

RegisterNetEvent('hygiene:client:SyncHud', function(data)
    HygieneState.mandi = data.mandi
    HygieneState.kencing = data.kencing
    HygieneState.poop = data.poop
    TriggerEvent('hygiene:client:RefreshHud')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    TriggerServerEvent('hygiene:server:RequestSync')
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('hygiene:server:RequestSync')
end)

-- f_radialmenu memanggil lib.clearRadialItems() lalu membangun ulang wheel-nya sendiri
-- setiap kali player loaded / mati / revive, sehingga item radial resource lain (termasuk
-- punya kita) ikut kehapus. Kita daftarkan ulang item kita setiap event itu terjadi (dengan
-- jeda supaya berjalan setelah proses clear milik f_radialmenu selesai).
local function ReRegisterHygieneRadial()
    Wait(1500)
    TriggerEvent('hygiene:client:RegisterRadial')
end

CreateThread(function()
    Wait(2500)
    TriggerEvent('hygiene:client:RegisterRadial')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', ReRegisterHygieneRadial)

RegisterNetEvent('radialmenu:client:deadradial', function(isDead)
    if not isDead then
        ReRegisterHygieneRadial()
    end
end)

-- begitu player di-revive (last-stand/dead selesai), langsung reaktifkan animasi/efek yang
-- di-pause tadi (kalau HUD masih mengharuskan), tidak perlu nunggu siklus cek berikutnya
RegisterNetEvent('f_medical:client:playerRevived', function()
    TriggerEvent('hygiene:client:RefreshHud')
end)

-- reminder notifikasi (edge-triggered)
local last = { mandi = 0, kencing = 0, poop = 0 }

RegisterNetEvent('hygiene:client:RefreshHud', function()
    if HygieneState.mandi >= Config.Mandi.ReminderPercent and last.mandi < Config.Mandi.ReminderPercent then
        HygieneNotify('Badan kamu sudah mulai kotor, segera pergi mandi!', 'error', 6000)
    end
    if HygieneState.kencing >= Config.Kencing.ReminderPercent and last.kencing < Config.Kencing.ReminderPercent then
        HygieneNotify('Kamu mulai ingin buang air kecil', 'inform', 6000)
    end
    if HygieneState.poop >= Config.Poop.ReminderPercent and last.poop < Config.Poop.ReminderPercent then
        HygieneNotify('Kamu mulai ingin buang air besar', 'inform', 6000)
    end

    last.mandi, last.kencing, last.poop = HygieneState.mandi, HygieneState.kencing, HygieneState.poop
end)

-- animasi "kebelet" (nempel di atas jalan normal, loop) begitu kencing/poop nyampe 100%
local desperateAnimActive = false

RegisterNetEvent('hygiene:client:RefreshHud', function()
    local desperate = HygieneState.kencing >= 100 or HygieneState.poop >= 100
    if desperate and not desperateAnimActive then
        desperateAnimActive = true
        CreateThread(function()
            local dict, clip = Config.Desperate.AnimDict, Config.Desperate.AnimClip
            RequestAnimDict(dict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end

            -- dimainkan sebentar tiap Config.Desperate.Interval (bukan loop terus), gantian sama
            -- reaksi lain lewat HygieneTryPlayReaction. Kalau giliran ini ke-skip (busy/lock),
            -- coba lagi 1 detik kemudian, bukan nunggu satu interval penuh
            local D = Config.Desperate
            while desperateAnimActive do
                if not HasAnimDictLoaded(dict) then RequestAnimDict(dict) end
                local played = HasAnimDictLoaded(dict) and HygieneTryPlayReaction(D.Duration, function()
                    local ped = PlayerPedId()
                    TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, 49, 0, false, false, false)
                    -- flag loop (1) bisa mengabaikan parameter durasi, jadi dihentikan manual
                    SetTimeout(D.Duration, function()
                        if IsEntityPlayingAnim(ped, dict, clip, 3) then
                            StopAnimTask(ped, dict, clip, 2.0)
                        end
                    end)
                end)
                local waitUntil = GetGameTimer() + (played and D.Interval or 1000)
                while desperateAnimActive and GetGameTimer() < waitUntil do Wait(1000) end
            end

            RemoveAnimDict(dict)
            ClearPedSecondaryTask(PlayerPedId())
        end)
    elseif not desperate and desperateAnimActive then
        desperateAnimActive = false
    end
end)

-- animasi loop yang sudah terpasang di ped tidak ikut berhenti waktu resource di-stop/restart,
-- jadi sisa animasi kebelet dari sesi sebelumnya dibersihkan saat start & stop
local function StopDesperateAnim()
    local ped = PlayerPedId()
    local D = Config.Desperate
    if IsEntityPlayingAnim(ped, D.AnimDict, D.AnimClip, 3) then
        StopAnimTask(ped, D.AnimDict, D.AnimClip, 2.0)
    end
end

StopDesperateAnim()

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then StopDesperateAnim() end
end)
