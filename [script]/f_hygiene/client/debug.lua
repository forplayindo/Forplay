-- ALAT BANTU DEV: buat ambil coords/heading presisi (toilet/shower/posisi duduk poop) tanpa
-- tebak-tebak manual. Ini tool development, bukan fitur pemain - boleh dihapus/di-restrict lagi
-- kalau sudah tidak dipakai.
--
-- /hygiene_place      = mode umum: ambil coords/heading APA ADANYA di posisi kamu berdiri
--                        sekarang (buat ToiletLocations/ShowerLocations).
--                        Enter -> print "{ coords = ..., heading = ... },"
-- /hygiene_place_poop = mode khusus posisi DUDUK POOP: langsung teleport + mainkan animasi
--                        duduknya (Config.Poop.ToiletAnim) di posisi yang DIHITUNG dari
--                        ToiletLocations[1] + Config.Poop.SeatOffset sekarang, biar kamu bisa
--                        lihat pose duduk beneran sambil geser (termasuk tinggi/Z).
--                        Enter -> print offset lokal (x,y,z) siap-paste ke
--                        Config.Poop.SeatOffset.offset (dan info kalau kamu ikut mengubah heading)
-- (dua-duanya diketik di chat, bukan tombol - biar tidak bentrok sama keybind lain)
--
-- kontrol geser (dua-duanya): Panah=X/Y, PageUp/PageDown=tinggi, Numpad ./*=rotasi heading,
-- Enter=simpan, Backspace=batal
local toolActive = false
local toolMode = 'raw' -- 'raw' | 'poop'
local toolCoords = nil
local toolHeading = nil
local toolBaseCoords = nil
local toolBaseHeading = nil
local toolGroundZ = nil
local toolStep = 0.02
local toolRotStep = 2.0

RegisterCommand('hygiene_place', function()
    if toolActive then return end
    toolActive = true
    toolMode = 'raw'
    local ped = cache.ped
    toolCoords = GetEntityCoords(ped)
    toolHeading = GetEntityHeading(ped)
    FreezeEntityPosition(ped, true)
    HygieneNotify('Mode atur posisi (umum) aktif. Panah=geser X/Y, PageUp/PageDown=tinggi, Numpad ./*=rotasi, Enter=simpan, Backspace=batal', 'inform', 8000)
end, false)

RegisterCommand('hygiene_place_poop', function()
    if toolActive then return end
    local loc = Config.ToiletLocations[1]
    if not loc then
        HygieneNotify('Config.ToiletLocations masih kosong, isi dulu titik toiletnya', 'error')
        return
    end

    toolActive = true
    toolMode = 'poop'
    local seat = Config.Poop.SeatOffset
    toolBaseCoords = loc.coords
    toolBaseHeading = (loc.heading + (seat.headingFlip or 0.0)) % 360.0
    toolHeading = toolBaseHeading

    local ped = cache.ped
    local xy = HygieneOffsetCoords(toolBaseCoords, toolBaseHeading, seat.offset)
    -- formula yang sama kayak client/poop.lua: Z ground player saat ini + SeatOffset.offset.z
    toolGroundZ = GetEntityCoords(ped).z
    local seatZ = toolGroundZ + (seat.offset and seat.offset.z or -0.5)
    toolCoords = vector3(xy.x, xy.y, seatZ)

    ClearPedTasks(ped)
    local anim = Config.Poop.ToiletAnim
    SetEntityCoords(ped, toolCoords.x, toolCoords.y, toolCoords.z, false, false, false, false)
    SetEntityHeading(ped, toolHeading)
    FreezeEntityPosition(ped, true)
    RequestAnimDict(anim.dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < timeout do Wait(0) end
    if HasAnimDictLoaded(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    HygieneNotify('Mode atur posisi DUDUK POOP aktif (lihat pose beneran). Panah=geser X/Y, PageUp/PageDown=tinggi, Numpad ./*=rotasi, Enter=simpan, Backspace=batal', 'inform', 8000)
end, false)

local function Nudge(dx, dy, dz, dh)
    if not toolActive then return end
    toolCoords = toolCoords + vector3(dx, dy, dz)
    toolHeading = (toolHeading + dh) % 360.0
    local ped = cache.ped
    SetEntityCoords(ped, toolCoords.x, toolCoords.y, toolCoords.z, false, false, false, false)
    SetEntityHeading(ped, toolHeading)
end

RegisterCommand('hygiene_place_fwd',   function() Nudge(0, toolStep, 0, 0) end, false)
RegisterCommand('hygiene_place_back',  function() Nudge(0, -toolStep, 0, 0) end, false)
RegisterCommand('hygiene_place_left',  function() Nudge(-toolStep, 0, 0, 0) end, false)
RegisterCommand('hygiene_place_right', function() Nudge(toolStep, 0, 0, 0) end, false)
RegisterCommand('hygiene_place_up',    function() Nudge(0, 0, toolStep, 0) end, false)
RegisterCommand('hygiene_place_down',  function() Nudge(0, 0, -toolStep, 0) end, false)
RegisterCommand('hygiene_place_rotl',  function() Nudge(0, 0, 0, -toolRotStep) end, false)
RegisterCommand('hygiene_place_rotr',  function() Nudge(0, 0, 0, toolRotStep) end, false)

RegisterKeyMapping('hygiene_place_fwd',   'Hygiene: geser +Y', 'keyboard', 'UP')
RegisterKeyMapping('hygiene_place_back',  'Hygiene: geser -Y', 'keyboard', 'DOWN')
RegisterKeyMapping('hygiene_place_left',  'Hygiene: geser -X', 'keyboard', 'LEFT')
RegisterKeyMapping('hygiene_place_right', 'Hygiene: geser +X', 'keyboard', 'RIGHT')
RegisterKeyMapping('hygiene_place_up',    'Hygiene: geser +Z (naik)', 'keyboard', 'PAGEUP')
RegisterKeyMapping('hygiene_place_down',  'Hygiene: geser -Z (turun)', 'keyboard', 'PAGEDOWN')
RegisterKeyMapping('hygiene_place_rotl',  'Hygiene: rotasi heading kiri', 'keyboard', 'DECIMAL')
RegisterKeyMapping('hygiene_place_rotr',  'Hygiene: rotasi heading kanan', 'keyboard', 'MULTIPLY')

RegisterCommand('hygiene_place_save', function()
    if not toolActive then return end
    toolActive = false
    local ped = cache.ped
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)

    if toolMode == 'poop' then
        -- balikkan world coords final ke offset lokal (x=kanan, y=depan) relatif ke
        -- toolBaseHeading - kebalikan dari HygieneOffsetCoords. z dihitung terpisah, relatif ke
        -- toolGroundZ (Z player waktu tool ini mulai), bukan ke toolBaseCoords.z
        local dx = toolCoords.x - toolBaseCoords.x
        local dy = toolCoords.y - toolBaseCoords.y
        local rad = math.rad(toolBaseHeading)
        local sin, cos = math.sin(rad), math.cos(rad)
        local offX = dx * cos + dy * sin
        local offY = -dx * sin + dy * cos
        local offZ = toolCoords.z - toolGroundZ
        local headingDelta = (toolHeading - toolBaseHeading) % 360.0

        print(('[f_hygiene] SeatOffset.offset = vector3(%.2f, %.2f, %.2f),'):format(offX, offY, offZ))
        if headingDelta > 0.5 and headingDelta < 359.5 then
            print(('[f_hygiene] kamu juga rotasi heading %.2f derajat - tambahkan itu ke Config.Poop.SeatOffset.headingFlip'):format(headingDelta))
        end
    else
        print(('[f_hygiene] hasil posisi: { coords = vector3(%.2f, %.2f, %.2f), heading = %.2f },'):format(
            toolCoords.x, toolCoords.y, toolCoords.z, toolHeading))
    end

    HygieneNotify('Posisi disimpan, cek F8 console buat copy hasilnya', 'success', 6000)
end, false)
RegisterKeyMapping('hygiene_place_save', 'Hygiene: simpan & print posisi', 'keyboard', 'RETURN')

RegisterCommand('hygiene_place_cancel', function()
    if not toolActive then return end
    toolActive = false
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    HygieneNotify('Dibatalkan', 'error', 3000)
end, false)
RegisterKeyMapping('hygiene_place_cancel', 'Hygiene: batal atur posisi', 'keyboard', 'BACK')
