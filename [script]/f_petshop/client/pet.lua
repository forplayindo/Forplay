-- f_petshop client: hewan yang sedang dipanggil (bisa beberapa sekaligus): spawn, perintah,
-- mati/hidup, plus interaksi yang bisa dilakukan SIAPA PUN pada hewan peliharaan:
-- elus, gendong hewan mati, masukkan/ambil dari kendaraan.
--
-- Status bersama disimpan server di statebag entity `fpet`:
--   { id, owner, name, pet, dead, carrier?, seatVeh?, seat? }
-- carrier = server id yang sedang menggendong, seatVeh/seat = kendaraan (netId) & kursi hewan mati.

---@class FPetRow
---@field id number
---@field pet string
---@field name string
---@field variant number texture warna (lihat Config.Pets[].variants)
---@field hunger number
---@field thirst number
---@field health number
---@field dead boolean

---@class FPet
---@field id number
---@field ped number
---@field cfg table
---@field row FPetRow
---@field mode string 'follow' | 'stay' | 'sit' | 'lay' | 'vehicle' | 'idle'
---@field slot number posisi ikut di belakang pemain
---@field vehicle number? kendaraan tempat hewan (hidup) duduk, ditempel ke bone kursi
---@field seat number? indeks kursi kendaraan
---@field reserve { veh: number, seat: number }? kursi yang sedang dituju (naik otomatis)
---@field auto boolean? naik otomatis bersama pemilik -> ikut turun saat pemilik keluar
---@field fetching boolean? sedang main lempar bola
---@field trickToken table? trik sekali jalan yang sedang berjalan
---@field attackTarget table? token serangan yang sedang berjalan
---@field guard { pos: vector3, radius: number }? sedang menjaga area

Pet = {
    ---@type table<number, FPet>
    list = {},
}

local petsById = {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end

local relGroup
local carry -- { ped, netId, cfg } hewan (milik siapa pun) yang sedang KITA gendong
local CARRY_DICT, CARRY_ANIM = 'anim@heists@box_carry@', 'idle'
-- posisi ikut di belakang pemain per slot supaya tidak bertumpuk
local FOLLOW_OFFSETS = { vec2(0.6, -1.0), vec2(-0.6, -1.0), vec2(0.0, -1.8), vec2(1.2, -1.6), vec2(-1.2, -1.6) }

local function notify(msg, kind) lib.notify({ description = msg, type = kind or 'inform' }) end
local function changed() TriggerEvent('f_petshop:client:changed') end

local function exists(p) return p and p.ped ~= 0 and DoesEntityExist(p.ped) end
local function petState(entity) return Entity(entity).state.fpet end
local function cfgOf(entity)
    local s = petState(entity)
    return s and petsById[s.pet]
end

local function animFor(cfg, action)
    local set = cfg and Config.Anims[cfg.kind]
    return set and set[action]
end

local function playAnim(ped, anim)
    if not anim or not DoesAnimDictExist(anim[1]) then return false end
    lib.requestAnimDict(anim[1])
    TaskPlayAnim(ped, anim[1], anim[2], 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(anim[1])
    return true
end

local function deadAnim(cfg) return animFor(cfg, 'dead') or animFor(cfg, 'lay') or animFor(cfg, 'sit') end
local function deadAnimPlaying(ped, cfg)
    local anim = deadAnim(cfg)
    return anim and IsEntityPlayingAnim(ped, anim[1], anim[2], 3)
end

-- minta kendali entity (hewan bisa sedang dikendalikan client lain, mis. yang terakhir menggendong)
local function ensureControl(ped, timeout)
    if NetworkHasControlOfEntity(ped) then return true end
    local deadline = GetGameTimer() + (timeout or 1000)
    repeat
        NetworkRequestControlOfEntity(ped)
        Wait(50)
    until NetworkHasControlOfEntity(ped) or GetGameTimer() > deadline
    return NetworkHasControlOfEntity(ped)
end

local function follow(p)
    if not exists(p) or p.row.dead then return end
    local o = FOLLOW_OFFSETS[p.slot] or FOLLOW_OFFSETS[1]
    ClearPedTasks(p.ped)
    TaskFollowToOffsetOfEntity(p.ped, cache.ped, o.x, o.y, 0.0, 5.0, -1, 1.5, true)
    p.mode = 'follow'
end

local function setupPed(ped)
    if not relGroup then
        local _, hash = AddRelationshipGroup('FPETSHOP')
        relGroup = hash
        SetRelationshipBetweenGroups(0, relGroup, `PLAYER`)
        SetRelationshipBetweenGroups(0, `PLAYER`, relGroup)
    end
    SetPedRelationshipGroupHash(ped, relGroup)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanBeTargetted(ped, true)
    SetPedKeepTask(ped, true)
end

local function freeSlot()
    local used = {}
    for _, p in pairs(Pet.list) do used[p.slot] = true end
    for i = 1, #FOLLOW_OFFSETS do
        if not used[i] then return i end
    end
    return 1
end

local function ownedByPed(ped)
    for _, p in pairs(Pet.list) do
        if p.ped == ped then return p end
    end
end

function Pet.isCarried(ped) return carry ~= nil and carry.ped == ped end
function Pet.isCarrying() return carry ~= nil end

---------------------------------------------------------------------------
-- Hewan mati:
--  * di tanah  -> benar-benar mati (ragdoll), tergeletak seperti mayat
--  * digendong / di kursi kendaraan -> "lemas": ped dihidupkan diam-diam, kebal, tanpa ragdoll,
--    memutar animasi lemas. Fisika ragdoll glitch kalau ditempel ke pemain / didudukkan.
-- Secara data hewan tetap mati (statebag `dead`) sampai diobati.
---------------------------------------------------------------------------
local function makeLimp(ped)
    if IsPedDeadOrDying(ped, true) then ResurrectPed(ped) end
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    setupPed(ped)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
end

-- kembali mati sungguhan: tubuhnya jatuh sendiri ke tanah
local function dropDead(ped)
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    SetEntityHealth(ped, 0)
end

---------------------------------------------------------------------------
-- Kendaraan: hewan TIDAK dimasukkan dengan SetPedIntoVehicle (posisinya posisi duduk manusia,
-- badan hewan tenggelam ke jok), tapi ditempel ke bone kursi dengan offset Config.VehicleSeat.
---------------------------------------------------------------------------
local SEAT_BONES = {
    [0] = 'seat_pside_f',  -- depan sebelah sopir
    [1] = 'seat_dside_r', [2] = 'seat_pside_r',
    [3] = 'seat_dside_r1', [4] = 'seat_pside_r1',
    [5] = 'seat_dside_r2', [6] = 'seat_pside_r2',
}

local function seatTaken(veh, seat)
    if not IsVehicleSeatFree(veh, seat) then return true end
    for _, p in pairs(Pet.list) do
        if p.vehicle == veh and p.seat == seat then return true end
        if p.reserve and p.reserve.veh == veh and p.reserve.seat == seat then return true end
    end
    -- hewan milik siapa pun (hidup / mati) yang sudah duduk di kursi ini
    local vehNet = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh)
    local seatPos = GetWorldPositionOfEntityBone(veh, GetEntityBoneIndexByName(veh, SEAT_BONES[seat]))
    for _, n in ipairs(lib.getNearbyPeds(GetEntityCoords(veh), 6.0)) do
        local s = petState(n.ped)
        if s then
            if vehNet and s.seatVeh == vehNet and s.seat == seat then return true end
            -- hewan hidup pemain lain: tertempel ke kendaraan ini, dekat titik kursi ini
            if IsEntityAttachedToEntity(n.ped, veh) and #(GetEntityCoords(n.ped) - seatPos) < 0.7 then return true end
        end
    end
    return false
end

-- kursi kosong pertama: depan sebelah sopir (0), lalu belakang (1, 2, ...)
local function freeSeat(veh)
    for s = 0, math.min(GetVehicleMaxNumberOfPassengers(veh) - 1, #SEAT_BONES) do
        if GetEntityBoneIndexByName(veh, SEAT_BONES[s]) ~= -1 and not seatTaken(veh, s) then return s end
    end
end

local function canRide(cfg)
    return cfg and Config.VehicleEnter[cfg.kind] ~= false
end

local function attachToSeat(ped, cfg, veh, seat)
    local o = (cfg and cfg.seat) or (cfg and Config.VehicleSeat[cfg.kind]) or Config.VehicleSeat.default
    local bone = GetEntityBoneIndexByName(veh, SEAT_BONES[seat])
    local rot = o.w or 0.0
    local function attach(rz)
        AttachEntityToEntity(ped, veh, bone, o.x, o.y, o.z, 0.0, 0.0, rz, false, false, false, true, 2, true)
    end
    attach(rot)

    -- arah bone kursi beda-beda antar kendaraan (ada yang menghadap ke belakang):
    -- setelah ditempel, pastikan hewan menghadap ke depan kendaraan, kalau terbalik putar 180
    CreateThread(function()
        Wait(0)
        if not DoesEntityExist(ped) or not DoesEntityExist(veh) or GetEntityAttachedTo(ped) ~= veh then return end
        local diff = (GetEntityHeading(ped) - GetEntityHeading(veh) - rot) % 360.0
        if diff > 90.0 and diff < 270.0 then attach(rot + 180.0) end
    end)
end

local function seatPet(p, veh, seat)
    ClearPedTasksImmediately(p.ped)
    SetEntityCollision(p.ped, false, false)
    p.vehicle, p.seat = veh, seat
    attachToSeat(p.ped, p.cfg, veh, seat)
    playAnim(p.ped, animFor(p.cfg, 'sit') or animFor(p.cfg, 'lay'))
    p.mode = 'vehicle'
end

-- pintu untuk kursi 0-2 (kursi 0 = depan sebelah sopir -> pintu 1)
local function doorOf(veh, seat)
    local door = seat + 1
    if seat <= 2 and GetIsDoorValid(veh, door) then return door end
end

-- hewan HIDUP yang turun dari kendaraan jangan sampai ragdoll ("pingsan") saat mendarat
local function noRagdollFor(ped, ms)
    SetPedCanRagdoll(ped, false)
    SetTimeout(ms, function()
        local s = DoesEntityExist(ped) and petState(ped)
        if s and not s.dead then SetPedCanRagdoll(ped, true) end -- hewan mati (lemas) tetap tanpa ragdoll
    end)
end

local function unseat(p, pos)
    if not p.vehicle then return end
    DetachEntity(p.ped, false, true) -- false = tidak membawa laju kendaraan
    SetEntityCollision(p.ped, true, true)
    p.vehicle, p.seat, p.auto = nil, nil, nil
    if pos then
        local found, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
        SetEntityCoords(p.ped, pos.x, pos.y, found and z or pos.z, false, false, false, false)
    end
end

local function enterVehicle(list)
    local veh = cache.vehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
    if not veh then return notify('Tidak ada kendaraan di dekatmu.', 'error') end

    local placed, skipped = 0, 0
    for _, p in ipairs(list) do
        if not canRide(p.cfg) then
            skipped += 1
            notify(('%s tidak bisa naik kendaraan.'):format(p.row.name), 'error')
        elseif p.vehicle then
            placed += 1
        else
            local seat = freeSeat(veh)
            if not seat then break end
            seatPet(p, veh, seat)
            placed += 1
        end
    end
    if placed + skipped < #list then notify('Kursi kendaraan tidak cukup untuk semua hewan.', 'error') end
end

local function exitVehicle(p)
    if not p.vehicle then return follow(p) end
    local veh = p.vehicle
    local door = DoesEntityExist(veh) and doorOf(veh, p.seat)
    local out
    if door then
        out = GetEntryPositionOfDoor(veh, door) -- turun di samping pintu kursinya
    elseif DoesEntityExist(veh) then
        local o = FOLLOW_OFFSETS[p.slot] or FOLLOW_OFFSETS[1]
        out = GetOffsetFromEntityInWorldCoords(veh, -2.0 + o.x, -1.0 + o.y, 0.0)
    else
        out = GetEntityCoords(p.ped)
    end
    noRagdollFor(p.ped, 2000)
    ClearPedTasksImmediately(p.ped)
    unseat(p, out)
    follow(p)
end

-- Atur posisi duduk di kendaraan langsung di game (Config.Debug): /petseat x y z [rotasi]
if Config.Debug then
    RegisterCommand('petseat', function(_, args)
        local x, y, z, h = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4]) or 0.0
        if not (x and y and z) then return notify('Pakai: /petseat x y z [rotasi]  contoh: /petseat 0 0 0.3') end
        local done = false
        for _, p in pairs(Pet.list) do
            if p.vehicle and exists(p) then
                Config.VehicleSeat[p.cfg.kind] = vec4(x, y, z, h)
                DetachEntity(p.ped, false, false)
                attachToSeat(p.ped, p.cfg, p.vehicle, p.seat)
                print(('[f_petshop] Config.VehicleSeat.%s = vec4(%.2f, %.2f, %.2f, %.1f)'):format(p.cfg.kind, x, y, z, h))
                done = true
            end
        end
        notify(done and 'Posisi dicoba. Angka final ada di F8 untuk disalin ke config.lua.' or 'Tidak ada hewan di kendaraan.')
    end, false)
end

---------------------------------------------------------------------------
-- Naik/turun kendaraan OTOMATIS: hewan yang sedang mengikuti jalan ke pintu dan naik saat
-- pemiliknya masuk kendaraan, lalu ikut turun saat pemiliknya keluar.
-- Anjing besar ('scene') melompat masuk/keluar dengan animasi asli GTA yang ditempel ke kursi.
---------------------------------------------------------------------------
local IN_VEH_DICT = 'creatures@rottweiler@in_vehicle@std_car'

-- animasi naik/turun: diputar di titik kursi; animasinya dibuat dari sisi kanan,
-- jadi kursi belakang kiri (1) diputar 180 derajat
local function seatScene(veh, seat, ped, clip)
    lib.requestAnimDict(IN_VEH_DICT)
    local scene = NetworkCreateSynchronisedScene(0.0, 0.0, 0.0, 0.0, 0.0, seat == 1 and 180.0 or 0.0, 2, false, false, 1.0, 0.0, 1.0)
    NetworkAttachSynchronisedSceneToEntity(scene, veh, GetEntityBoneIndexByName(veh, SEAT_BONES[seat]))
    NetworkAddPedToSynchronisedScene(ped, scene, IN_VEH_DICT, clip, 1.5, -4.0, 0, 0, 1000.0, 0)
    NetworkStartSynchronisedScene(scene)
    return math.floor(GetAnimDuration(IN_VEH_DICT, clip) * 1000)
end

local function autoBoard(p, veh)
    local seat = freeSeat(veh)
    if not seat then return notify(('Tidak ada kursi untuk %s.'):format(p.row.name), 'error') end
    p.reserve = { veh = veh, seat = seat }
    p.mode = 'boarding'

    local door = doorOf(veh, seat)
    local entry = door and GetEntryPositionOfDoor(veh, door) or GetOffsetFromEntityInWorldCoords(veh, 0.0, -3.0, 0.0)
    ClearPedTasks(p.ped)
    TaskGoToCoordAnyMeans(p.ped, entry.x, entry.y, entry.z, 3.0, 0, false, 786603, 0.0)

    local deadline = GetGameTimer() + (Config.BoardTimeout or 8000)
    while p.reserve and exists(p) and DoesEntityExist(veh) and cache.vehicle == veh do
        if #(GetEntityCoords(p.ped) - entry) < 1.6 or GetGameTimer() > deadline or GetEntitySpeed(veh) > 2.0 then break end
        Wait(100)
    end

    if not p.reserve or not exists(p) or p.row.dead or not DoesEntityExist(veh) then p.reserve = nil return end
    if cache.vehicle ~= veh then -- pemilik keburu turun lagi
        p.reserve = nil
        return follow(p)
    end

    local close = #(GetEntityCoords(p.ped) - entry) < 2.0 and GetEntitySpeed(veh) < 1.0
    if door and close and Config.VehicleEnter[p.cfg.kind] == 'scene' then
        SetVehicleDoorOpen(veh, door, false, false)
        SetEntityCollision(p.ped, false, true)
        Wait(seatScene(veh, seat, p.ped, 'get_in'))
    end

    p.reserve = nil
    if not exists(p) or p.row.dead or not DoesEntityExist(veh) then return end
    seatPet(p, veh, seat)
    p.auto = true
    if door then SetVehicleDoorShut(veh, door, false) end
    changed()
end

local function autoExit(p)
    local veh, seat = p.vehicle, p.seat
    p.auto = nil
    local door = veh and DoesEntityExist(veh) and doorOf(veh, seat)
    if not door or Config.VehicleEnter[p.cfg.kind] ~= 'scene' or GetEntitySpeed(veh) > 1.0 then
        return exitVehicle(p)
    end

    -- lepas dari kursi dulu supaya pemantau tidak memutar ulang animasi duduk
    p.vehicle, p.seat, p.mode = nil, nil, 'boarding'
    noRagdollFor(p.ped, 5000)
    SetVehicleDoorOpen(veh, door, false, false)
    DetachEntity(p.ped, false, true)
    SetEntityCollision(p.ped, true, true)
    Wait(seatScene(veh, seat, p.ped, 'get_out'))
    if not exists(p) then return end
    ClearPedTasks(p.ped)
    if DoesEntityExist(veh) then SetVehicleDoorShut(veh, door, false) end
    if not p.row.dead then follow(p) end
    changed()
end

lib.onCache('vehicle', function(veh)
    for _, p in pairs(Pet.list) do
        if exists(p) and not p.row.dead and not Pet.isCarried(p.ped) then
            if veh and p.mode == 'follow' and not p.vehicle and canRide(p.cfg) then
                CreateThread(function()
                    Wait(0) -- cache.vehicle baru terisi setelah event ini selesai
                    if ensureControl(p.ped, 500) then autoBoard(p, veh) end
                end)
            elseif not veh and p.auto and p.vehicle then
                CreateThread(function()
                    if ensureControl(p.ped, 500) then autoExit(p) end
                end)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Spawn / despawn (hewan milik sendiri)
---------------------------------------------------------------------------
local function remove(id)
    local p = Pet.list[id]
    if not p then return end
    if carry and carry.ped == p.ped then Pet.putDown() end
    if exists(p) then DeleteEntity(p.ped) end
    Pet.list[id] = nil
    changed()
end

-- baru dipanggil: bangun dulu (animasi keluar dari tidur/duduk), baru mengikuti
local function wakeUp(p)
    local anim = animFor(p.cfg, 'wake')
    if not anim or not DoesAnimDictExist(anim[1]) then return follow(p) end
    lib.requestAnimDict(anim[1])
    TaskPlayAnim(p.ped, anim[1], anim[2], 8.0, -4.0, -1, 0, 0.0, false, false, false)
    local ms = math.floor(GetAnimDuration(anim[1], anim[2]) * 1000)
    RemoveAnimDict(anim[1])
    p.mode = 'idle'
    SetTimeout(math.max(ms - 150, 300), function()
        -- belum diberi perintah lain selama bangun -> mulai mengikuti
        if exists(p) and not p.row.dead and p.mode == 'idle' and not p.vehicle then
            follow(p)
            changed()
        end
    end)
end

---@param inFront boolean? true = muncul di depan pemain menghadap ke arahnya (setelah membeli)
function Pet.summon(id, inFront)
    if Pet.list[id] then return false end
    local res = lib.callback.await('f_petshop:summon', false, id)
    if not res or not res.ok then
        if res and res.msg then notify(res.msg, 'error') end
        return false
    end

    local cfg = petsById[res.row.pet]
    local model = joaat(cfg.model)
    if not IsModelInCdimage(model) then
        notify('Model hewan tidak ditemukan di server.', 'error')
        lib.callback.await('f_petshop:dismiss', false, id)
        return false
    end

    ---@type FPet
    local p = { id = id, ped = 0, cfg = cfg, row = res.row, mode = 'idle', slot = freeSlot() }
    Pet.list[id] = p

    -- hewan mati muncul di tempat terakhir ia ditinggal (harus didatangi & digendong)
    local o = FOLLOW_OFFSETS[p.slot]
    local spawn = res.spawnAt and vec3(res.spawnAt.x, res.spawnAt.y, res.spawnAt.z)
        or GetOffsetFromEntityInWorldCoords(cache.ped, inFront and 0.0 or o.x, inFront and 1.5 or o.y, 0.0)

    local function create()
        if not lib.requestModel(model, 10000) or Pet.list[id] ~= p then return end
        local found, z = GetGroundZFor_3dCoord(spawn.x, spawn.y, spawn.z + 1.0, false)
        local heading = GetEntityHeading(cache.ped) + (inFront and 180.0 or 0.0)
        local ped = CreatePed(28, model, spawn.x, spawn.y, found and z or spawn.z - 1.0, heading % 360.0, true, true)
        SetModelAsNoLongerNeeded(model)
        if cfg.variants then SetPedComponentVariation(ped, cfg.variants.comp, 0, p.row.variant or 0, 0) end
        setupPed(ped)
        p.ped = ped
        TriggerServerEvent('f_petshop:server:spawned', id, NetworkGetNetworkIdFromEntity(ped))

        if p.row.dead then
            dropDead(ped)
        else
            notify(('%s datang!'):format(p.row.name), 'success')
            wakeUp(p)
        end
        changed()
    end

    if p.row.dead then
        notify(('%s masih mati. Bawa ke %s dan minta petugas EMS menyembuhkannya.'):format(p.row.name, Config.Vet.label), 'error')
    end

    if res.spawnAt and #(GetEntityCoords(cache.ped) - spawn) > 120.0 then
        -- terlalu jauh untuk di-spawn sekarang: tandai lokasinya, spawn saat pemain mendekat
        SetNewWaypoint(spawn.x, spawn.y)
        notify(('Lokasi %s ditandai di peta.'):format(p.row.name))
        CreateThread(function()
            while Pet.list[id] == p and p.ped == 0 do
                if #(GetEntityCoords(cache.ped) - spawn) <= 100.0 then return create() end
                Wait(1000)
            end
        end)
    else
        create()
    end
    changed()
    return true
end

function Pet.summonAll()
    local pets = lib.callback.await('f_petshop:getMyPets', false) or {}
    for _, r in ipairs(pets) do
        if not Pet.list[r.id] then
            Pet.summon(r.id)
            Wait(350) -- jeda anti-spam server untuk panggil
        end
    end
end

---@param id number? kosong = pulangkan semua
function Pet.dismiss(id)
    if id and not Pet.list[id] then return end
    if not id and not next(Pet.list) then return end
    lib.callback.await('f_petshop:dismiss', false, id)
end

RegisterNetEvent('f_petshop:client:despawned', function(id)
    remove(id)
end)

RegisterNetEvent('f_petshop:client:status', function(data)
    local p = Pet.list[data.id]
    if not p then return end
    local revived = p.row.dead and not data.dead
    p.row.hunger, p.row.thirst, p.row.health, p.row.dead = data.hunger, data.thirst, data.health, data.dead
    if revived and exists(p) then
        -- hewan dihidupkan (bisa saat dikendalikan client lain): ambil kendali lalu ikut lagi
        CreateThread(function()
            Wait(500)
            if not exists(p) or not ensureControl(p.ped, 2000) then return end
            -- kalau client lain belum sempat menghidupkannya, hidupkan sendiri
            if IsPedDeadOrDying(p.ped, true) or IsEntityAttached(p.ped) then
                if IsEntityAttached(p.ped) then DetachEntity(p.ped, true, false) end
                SetEntityCollision(p.ped, true, true)
                local c = GetEntityCoords(p.ped)
                ResurrectPed(p.ped)
                ClearPedTasksImmediately(p.ped)
                SetEntityCoords(p.ped, c.x, c.y, c.z, false, false, false, false)
                SetEntityHealth(p.ped, GetEntityMaxHealth(p.ped))
            end
            setupPed(p.ped)
            SetEntityInvincible(p.ped, false)
            SetPedCanRagdoll(p.ped, true)
            follow(p)
            changed()
        end)
    end
    changed()
end)

RegisterNetEvent('f_petshop:client:kill', function(id)
    local p = Pet.list[id]
    if not exists(p) then return end
    p.row.dead = true
    if p.vehicle then unseat(p) end
    SetEntityHealth(p.ped, 0)
end)

-- dikirim server ke client yang MENGENDALIKAN entity (bisa bukan pemiliknya)
RegisterNetEvent('f_petshop:client:reviveEntity', function(netId)
    if not NetworkDoesNetworkIdExist(netId) then return end
    local ped = NetworkGetEntityFromNetworkId(netId)
    if ped == 0 or not DoesEntityExist(ped) then return end
    if carry and carry.ped == ped then Pet.release() end
    if IsEntityAttached(ped) then DetachEntity(ped, true, false) end
    local own = ownedByPed(ped)
    -- tandai hidup SEKARANG, jangan tunggu status dari server: kalau tidak, pemantau di bawah
    -- masih mengira hewannya mati lalu mematikannya lagi
    if own then own.vehicle, own.seat, own.row.dead = nil, nil, false end
    local coords = GetEntityCoords(ped)
    SetEntityCollision(ped, true, true)
    if IsPedDeadOrDying(ped, true) then ResurrectPed(ped) end
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    setupPed(ped)
end)

-- hewan yang kita gendong dihidupkan / dipulangkan: lepas dari gendongan
RegisterNetEvent('f_petshop:client:forceDrop', function(netId)
    if carry and carry.netId == netId then Pet.release() end
end)

---------------------------------------------------------------------------
-- Perintah (target = id hewan, atau 'all' untuk semua yang hidup)
---------------------------------------------------------------------------
local function targets(target)
    local out = {}
    if target == 'all' then
        for _, p in pairs(Pet.list) do
            if exists(p) and not p.row.dead then out[#out + 1] = p end
        end
        table.sort(out, function(a, b) return a.slot < b.slot end)
    else
        local p = Pet.list[tonumber(target)]
        if exists(p) and not p.row.dead then out[1] = p end
    end
    return out
end

---@param cmd string
---@param target number|'all'
---@param radius number? luas area jaga (meter) dari panel
function Pet.command(cmd, target, radius)
    target = target or 'all'
    if cmd == 'dismiss' then return Pet.dismiss(target ~= 'all' and tonumber(target) or nil) end
    if cmd == 'summonAll' then return Pet.summonAll() end
    if cmd == 'carry' then
        if carry then return Pet.putDown() end
        local p = Pet.list[tonumber(target)]
        if exists(p) then Pet.pickUp(p.ped) end
        return
    end

    if cmd == 'leash' then
        local p = Pet.list[tonumber(target)]
        if not exists(p) or p.row.dead then return end
        local s = petState(p.ped)
        lib.callback.await('f_petshop:leash', false, p.id, not (s and s.leash))
        Wait(200) -- tunggu statebag baru sampai sebelum panel diperbarui
        return changed()
    end

    -- serang / jaga area: satu hewan, panel ditutup dulu untuk memilih target / luas area
    if cmd == 'attack' or cmd == 'guard' then
        local p = Pet.list[tonumber(target)]
        if not exists(p) or p.row.dead then return end
        if cmd == 'guard' then
            if p.guard then return Pet.stopGuard(p) end
            return Pet.placeGuard(p, radius)
        end
        CreateThread(function() Pet.pickTarget(p) end)
        return
    end

    local list = targets(target)
    if #list == 0 then return notify('Tidak ada hewan hidup yang bisa diperintah.', 'error') end

    for _, p in ipairs(list) do
        ensureControl(p.ped, 500)
        -- perintah baru membatalkan trik / lempar bola / serangan / jaga area
        p.fetching, p.trickToken, p.attackTarget, p.guard = nil, nil, nil, nil
    end

    if cmd == 'enter' then
        enterVehicle(list)
    else
        for _, p in ipairs(list) do
            if cmd == 'follow' then
                if p.mode == 'vehicle' then exitVehicle(p) else follow(p) end
            elseif cmd == 'exit' then
                exitVehicle(p)
            elseif cmd == 'stay' then
                ClearPedTasks(p.ped)
                TaskStandStill(p.ped, -1)
                p.mode = 'stay'
            elseif cmd == 'sit' or cmd == 'lay' then
                ClearPedTasks(p.ped)
                if not playAnim(p.ped, animFor(p.cfg, cmd)) then
                    TaskStandStill(p.ped, -1)
                    notify(('%s tidak bisa melakukan itu, jadi diam saja.'):format(p.row.name))
                end
                p.mode = cmd
            end
        end
    end
    changed()
end

---------------------------------------------------------------------------
-- Gendong hewan mati (SIAPA PUN boleh, misalnya membantu membawa ke rumah sakit)
---------------------------------------------------------------------------
-- lepas gendongan tanpa menaruh/mematikan (dipakai saat hewan dihidupkan / dihapus)
function Pet.release()
    if not carry then return end
    local c = carry
    carry = nil
    lib.hideTextUI()
    StopAnimTask(cache.ped, CARRY_DICT, CARRY_ANIM, 2.0)
    RemoveAnimDict(CARRY_DICT)
    if DoesEntityExist(c.ped) and IsEntityAttached(c.ped) then DetachEntity(c.ped, true, false) end
    changed()
end

function Pet.pickUp(ped)
    local s = petState(ped)
    local cfg = s and petsById[s.pet]
    if not cfg or not s.dead then return notify('Hanya hewan yang mati yang bisa digendong.', 'error') end
    if cfg.carry == false then return notify(('%s terlalu besar untuk digendong.'):format(cfg.label), 'error') end
    if carry or cache.vehicle then return end
    if s.carrier then return notify('Hewan itu sedang digendong orang lain.', 'error') end
    local seated = s.seatVeh ~= nil
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > (seated and 4.0 or 3.0) then
        return notify('Dekati hewannya dulu.', 'error')
    end

    local netId = NetworkGetNetworkIdFromEntity(ped)
    if not lib.callback.await('f_petshop:carry', false, netId) then
        return notify('Hewan itu tidak bisa digendong sekarang.', 'error')
    end
    if not ensureControl(ped, 1500) then
        TriggerServerEvent('f_petshop:server:drop', netId)
        return notify('Gagal mengangkat hewan, coba lagi.', 'error')
    end

    if IsEntityAttached(ped) then
        -- keluarkan dari kendaraan dulu
        DetachEntity(ped, true, false)
        local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.6, 0.0)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    end
    local own = ownedByPed(ped)
    if own then own.vehicle, own.seat, own.mode = nil, nil, 'idle' end

    makeLimp(ped) -- dari mayat ragdoll / kursi kendaraan -> pose lemas yang bisa ditempel
    local c = cfg.carry or Config.Carry[cfg.kind] or Config.Carry.dog_big
    SetEntityCollision(ped, false, false)
    lib.requestAnimDict(CARRY_DICT)
    TaskPlayAnim(cache.ped, CARRY_DICT, CARRY_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
    -- ditempel ke root pemain (sumbu = sumbu badan pemain: x kanan, y depan, z atas)
    AttachEntityToEntity(ped, cache.ped, GetPedBoneIndex(cache.ped, 0),
        c.offset.x, c.offset.y, c.offset.z, c.rot.x, c.rot.y, c.rot.z, false, false, false, true, 2, true)
    playAnim(ped, deadAnim(cfg))
    local me = { ped = ped, netId = netId, cfg = cfg }
    carry = me
    changed()

    CreateThread(function()
        local tick, text, veh = 0, nil, nil
        while carry == me do
            tick += 1
            -- cek kendaraan di dekat & perbarui teks tiap ~0,5 detik (bukan tiap frame)
            if tick % 30 == 1 then
                veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3.5, false)
                if veh and not freeSeat(veh) then veh = nil end
                local want = veh and '[E] Masukkan ke kendaraan  \n[G] Turunkan' or '[G] Turunkan'
                local open, current = lib.isTextUIOpen()
                if want ~= text or not open or current ~= want then
                    lib.showTextUI(want, { icon = 'hand' })
                    text = want
                end
            end
            DisableControlAction(0, 21, true)  -- lari
            DisableControlAction(0, 22, true)  -- lompat
            DisableControlAction(0, 23, true)  -- masuk kendaraan
            DisableControlAction(0, 24, true)  -- serang
            DisableControlAction(0, 25, true)  -- bidik
            DisableControlAction(0, 47, true)  -- G (dipakai untuk menurunkan)
            if IsDisabledControlJustPressed(0, 47) then Pet.putDown() break end
            if veh and IsControlJustPressed(0, 38) then Pet.loadIntoVehicle(veh) break end
            if not IsEntityPlayingAnim(cache.ped, CARRY_DICT, CARRY_ANIM, 3) then
                TaskPlayAnim(cache.ped, CARRY_DICT, CARRY_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            if not DoesEntityExist(ped) then Pet.release() break end
            if not deadAnimPlaying(ped, cfg) then playAnim(ped, deadAnim(cfg)) end
            if IsPedRagdoll(cache.ped) or IsEntityDead(cache.ped) then Pet.putDown() break end
            Wait(0)
        end
    end)
end

function Pet.putDown()
    if not carry then return end
    local c = carry
    Pet.release()
    if DoesEntityExist(c.ped) then
        SetEntityCollision(c.ped, true, true)
        -- lepas setinggi pinggang di depan pemain, lalu mati sungguhan -> jatuh sendiri ke tanah
        local pos = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 0.8, 0.0)
        SetEntityCoords(c.ped, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(c.ped, GetEntityHeading(cache.ped) + 90.0)
        dropDead(c.ped)
    end
    TriggerServerEvent('f_petshop:server:drop', c.netId)
end

-- hewan mati yang sedang digendong dimasukkan ke kursi kosong kendaraan (depan dulu, lalu belakang)
function Pet.loadIntoVehicle(veh)
    if not carry or not DoesEntityExist(veh) then return end
    local seat = freeSeat(veh)
    if not seat then return notify('Kendaraan penuh.', 'error') end
    local c = carry
    Pet.release()
    if not DoesEntityExist(c.ped) then return end
    SetEntityCollision(c.ped, false, false)
    attachToSeat(c.ped, c.cfg, veh, seat)
    playAnim(c.ped, deadAnim(c.cfg))
    TriggerServerEvent('f_petshop:server:drop', c.netId, NetworkGetNetworkIdFromEntity(veh), seat)
    notify('Hewan dimasukkan ke kendaraan. Ambil lagi lewat target kendaraan → Ambil Hewan.')
end

-- hewan mati (milik siapa pun) yang ditaruh di kendaraan ini
local function deadPetIn(veh)
    if not NetworkGetEntityIsNetworked(veh) then return end
    local vehNet = NetworkGetNetworkIdFromEntity(veh)
    for _, n in ipairs(lib.getNearbyPeds(GetEntityCoords(veh), 6.0)) do
        local s = petState(n.ped)
        if s and s.dead and s.seatVeh == vehNet and not s.carrier then return n.ped end
    end
end

---------------------------------------------------------------------------
-- Pemantau hewan milik sendiri: mati, tertinggal jauh, dll (hanya jalan saat ada hewan)
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        if next(Pet.list) then
            local myPos = GetEntityCoords(cache.ped)
            for id, p in pairs(Pet.list) do
                if exists(p) then
                    local s = petState(p.ped)
                    local busy = s and (s.carrier or s.seatVeh) -- sedang digendong / di kursi (oleh siapa pun)
                    local deadNow = IsPedDeadOrDying(p.ped, true)

                    if p.vehicle and not DoesEntityExist(p.vehicle) then
                        unseat(p) -- kendaraannya hilang: lepas di tempat
                        if p.row.dead then dropDead(p.ped) else follow(p) end
                    elseif s and s.seatVeh and not s.carrier and NetworkHasControlOfEntity(p.ped)
                        and not NetworkDoesNetworkIdExist(s.seatVeh) then
                        -- kendaraan tempat hewan mati ditaruh sudah hilang: jatuhkan di tempat
                        DetachEntity(p.ped, true, false)
                        SetEntityCollision(p.ped, true, true)
                        dropDead(p.ped)
                        TriggerServerEvent('f_petshop:server:drop', NetworkGetNetworkIdFromEntity(p.ped))
                    elseif not p.row.dead and deadNow then
                        if p.vehicle then unseat(p) end -- mati di kursi: jatuh dari kendaraan
                        p.row.dead = true
                        p.mode = 'idle'
                        TriggerServerEvent('f_petshop:server:died', id)
                        changed()
                    elseif p.row.dead and s and s.dead and not busy and not deadNow and not Pet.isCarried(p.ped)
                        and NetworkHasControlOfEntity(p.ped) then
                        dropDead(p.ped) -- harusnya tergeletak mati (baru di-spawn / diganggu game)
                    elseif p.vehicle and not p.row.dead then
                        local sit = animFor(p.cfg, 'sit') or animFor(p.cfg, 'lay')
                        if sit and not IsEntityPlayingAnim(p.ped, sit[1], sit[2], 3) then playAnim(p.ped, sit) end
                    elseif p.mode == 'follow' and not p.row.dead and not cache.vehicle then
                        local dist = #(myPos - GetEntityCoords(p.ped))
                        if dist > 60.0 then
                            local o = FOLLOW_OFFSETS[p.slot] or FOLLOW_OFFSETS[1]
                            local pos = GetOffsetFromEntityInWorldCoords(cache.ped, o.x, o.y - 1.0, 0.0)
                            SetEntityCoords(p.ped, pos.x, pos.y, pos.z, false, false, false, false)
                            follow(p)
                        elseif dist > 8.0 and GetEntitySpeed(p.ped) < 0.3 then -- tugas ikut terhenti
                            follow(p)
                        end
                    end
                elseif p.ped ~= 0 then
                    -- entity hilang (dihapus game/admin): anggap dipulangkan
                    CreateThread(function() Pet.dismiss(id) end)
                end
            end
            Wait(500)
        else
            Wait(2000)
        end
    end
end)

---------------------------------------------------------------------------
-- Trik, lempar bola, dielus (hewan milik sendiri)
---------------------------------------------------------------------------
-- kembali ke perintah sebelumnya setelah trik sekali jalan / dielus
local function resume(p, mode)
    if not exists(p) or p.row.dead or p.vehicle then return end
    if mode == 'follow' or mode == 'idle' then
        follow(p)
    elseif (mode == 'sit' or mode == 'lay') and playAnim(p.ped, animFor(p.cfg, mode)) then
        p.mode = mode
    else
        TaskStandStill(p.ped, -1)
        p.mode = 'stay'
    end
    changed()
end

local function trickOf(cfg, trickId)
    for _, t in ipairs(Config.Tricks[cfg.kind] or {}) do
        if t.id == trickId then return t end
    end
end

---@return { id: string, label: string, icon: string }[]
function Pet.tricksFor(cfg)
    local out = {}
    for _, t in ipairs(Config.Tricks[cfg.kind] or {}) do out[#out + 1] = { id = t.id, label = t.label, icon = t.icon } end
    if Config.Fetch.kinds[cfg.kind] then out[#out + 1] = { id = 'fetch', label = 'Lempar Bola', icon = '🎾' } end
    return out
end

local function fetch(p)
    local f = Config.Fetch
    local set = f.kinds[p.cfg.kind]
    if not set then return end
    if cache.vehicle then return notify('Turun dari kendaraan dulu.', 'error') end
    if exports.ox_inventory:Search('count', f.item) < 1 then
        return notify('Kamu butuh Bola Tenis (beli di Toko Hewan → Perlengkapan).', 'error')
    end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(p.ped)) > 15.0 then
        return notify(('%s terlalu jauh.'):format(p.row.name), 'error')
    end

    p.fetching, p.mode = true, 'fetch'
    changed()
    local ball
    local ok = pcall(function()
        local model = joaat(f.prop)
        lib.requestModel(model, 5000)
        lib.requestAnimDict('weapons@projectile@', 3000)
        local c = GetEntityCoords(cache.ped)
        ball = CreateObject(model, c.x, c.y, c.z + 1.0, true, true, false)
        SetModelAsNoLongerNeeded(model)
        AttachEntityToEntity(ball, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, 0.0, 0.0, 0.0, 0.0,
            false, false, false, false, 2, true)
        ClearPedTasks(p.ped)
        TaskStandStill(p.ped, 2500)
        TaskPlayAnim(cache.ped, 'weapons@projectile@', 'throw_m_fb_stand', 3.0, -3.0, 1200, 48, 0.0, false, false, false)
        Wait(550)

        -- lempar ke arah kamera
        DetachEntity(ball, true, true)
        local rot = GetGameplayCamRot(2)
        local rx, rz = math.rad(rot.x), math.rad(rot.z)
        local dir = vec3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
        SetEntityVelocity(ball, dir.x * 14.0, dir.y * 14.0, math.max(dir.z * 14.0, 0.0) + 4.0)
        Wait(400)
        local settle = GetGameTimer() + 4000
        while GetGameTimer() < settle and GetEntitySpeed(ball) > 0.5 do Wait(100) end

        local deadline = GetGameTimer() + f.timeout
        local function check()
            if not p.fetching or not exists(p) or p.row.dead or GetGameTimer() > deadline then error('batal') end
        end

        -- kejar bola
        TaskGoToEntity(p.ped, ball, -1, 1.0, 3.0, 1073741824.0, 0)
        while #(GetEntityCoords(p.ped) - GetEntityCoords(ball)) > 1.2 do check() Wait(100) end

        -- gigit bola
        if set.pickup and DoesAnimDictExist(set.pickup[1]) then
            lib.requestAnimDict(set.pickup[1])
            TaskPlayAnim(p.ped, set.pickup[1], set.pickup[2], 4.0, -4.0, 1200, 0, 0.0, false, false, false)
            Wait(700)
        end
        local mouth = GetPedBoneIndex(p.ped, 17188)
        if mouth == -1 then mouth = GetPedBoneIndex(p.ped, 31086) end
        AttachEntityToEntity(ball, p.ped, mouth, 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)

        -- bawa pulang
        TaskGoToEntity(p.ped, cache.ped, -1, 1.4, 2.5, 1073741824.0, 0)
        while #(GetEntityCoords(p.ped) - GetEntityCoords(cache.ped)) > 1.8 do check() Wait(100) end
    end)

    if ball and DoesEntityExist(ball) then DeleteEntity(ball) end
    StopAnimTask(cache.ped, 'weapons@projectile@', 'throw_m_fb_stand', 2.0)
    local cancelled = not p.fetching -- diberi perintah lain saat mengejar bola
    p.fetching = nil
    if cancelled then return end
    if ok then notify(('%s membawa bolanya kembali!'):format(p.row.name), 'success') end
    if exists(p) and not p.row.dead then follow(p) end
    changed()
end

---@param id number id hewan
---@param trickId string id di Config.Tricks, atau 'fetch'
function Pet.trick(id, trickId)
    local p = Pet.list[tonumber(id)]
    if not exists(p) or p.row.dead or p.vehicle or p.fetching then return end
    ensureControl(p.ped, 500)
    if trickId == 'fetch' then return CreateThread(function() fetch(p) end) end

    local t = trickOf(p.cfg, trickId)
    if not t or not DoesAnimDictExist(t.anim[1]) then return end
    local before = p.mode == 'trick' and 'stay' or p.mode
    ClearPedTasks(p.ped)
    lib.requestAnimDict(t.anim[1])
    TaskPlayAnim(p.ped, t.anim[1], t.anim[2], 8.0, -8.0, -1, t.loop and 1 or 0, 0.0, false, false, false)
    local ms = math.floor(GetAnimDuration(t.anim[1], t.anim[2]) * 1000)
    RemoveAnimDict(t.anim[1])
    if t.bark and PlayAnimalVocalization then PlayAnimalVocalization(p.ped, 3, 'BARK') end
    p.mode = 'trick'

    if not t.loop then
        local token = {}
        p.trickToken = token
        SetTimeout(math.max(ms, 500), function()
            if p.trickToken == token and p.mode == 'trick' then resume(p, before) end
        end)
    end
    changed()
end

-- ada yang mengelus hewan kita (atau kita sendiri): berhenti, hadapkan ke pengelus, animasi dielus
RegisterNetEvent('f_petshop:client:petted', function(netId, petter, duration)
    if not NetworkDoesNetworkIdExist(netId) then return end
    local p = ownedByPed(NetworkGetEntityFromNetworkId(netId))
    if not exists(p) or p.row.dead or p.vehicle or p.fetching or Pet.isCarried(p.ped) then return end
    local player = GetPlayerFromServerId(petter)
    local petterPed = player ~= -1 and GetPlayerPed(player) or 0
    if petterPed == 0 then return end

    ensureControl(p.ped, 500)
    local set = Config.Petting[p.cfg.kind] or Config.Petting.default
    local before = p.mode
    ClearPedTasks(p.ped)
    local a, b = GetEntityCoords(p.ped), GetEntityCoords(petterPed)
    SetEntityHeading(p.ped, GetHeadingFromVector_2d(b.x - a.x, b.y - a.y))
    if set.pet and DoesAnimDictExist(set.pet[1]) then
        lib.requestAnimDict(set.pet[1])
        TaskPlayAnim(p.ped, set.pet[1], set.pet[2], 8.0, -8.0, duration, 1, 0.0, false, false, false)
        RemoveAnimDict(set.pet[1])
    else
        TaskStandStill(p.ped, duration)
    end
    p.mode = 'petted'
    SetTimeout(duration + 200, function()
        if p.mode == 'petted' then resume(p, before) end
    end)
end)

---------------------------------------------------------------------------
-- Serang & jaga area (hewan dengan `attack = true` di Config.Pets). Serangan ke PEMAIN selalu
-- minta izin server dulu (daftar teman, jarak, job) dan tercatat di console server.
---------------------------------------------------------------------------
function Pet.canFight(cfg)
    return Config.Attack.enabled and cfg ~= nil and cfg.attack == true
end

local guardChecked = {} -- [server id] = waktu terakhir pemain itu dicek / diserang saat jaga area

local function validTarget(p, ped)
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or ped == cache.ped or ped == p.ped then return false end
    if petState(ped) then return false end -- hewan peliharaan (milik siapa pun)
    if IsPedAPlayer(ped) then return Config.Attack.players end
    return Config.Attack.npcs and not IsPedInAnyVehicle(ped, false)
end

-- selesai menyerang: kembali ke tempat jaga, atau mengikuti pemilik
local function backToPost(p)
    if not exists(p) or p.row.dead then return end
    if p.guard then
        local g = p.guard.pos
        TaskGoStraightToCoord(p.ped, g.x, g.y, g.z, 2.0, 15000, 0.0, 0.5)
        p.mode = 'guard'
    else
        follow(p)
    end
    changed()
end

-- Grup relasi khusus saat menyerang. Grup FPETSHOP berstatus "companion" dengan PLAYER, dan AI GTA
-- menolak TaskCombatPed ke target yang dianggap teman (hewan lalu kabur / lari ke arah lain).
-- Selama menyerang hewan pindah ke grup ini yang membenci grup target, lalu dikembalikan.
local atkGroup, atkHated
local function makeHostile(p, target)
    if not atkGroup then
        local _, hash = AddRelationshipGroup('FPETSHOP_ATK')
        atkGroup = hash
    end
    local tg = GetPedRelationshipGroupHash(target)
    if atkHated and atkHated ~= tg then
        ClearRelationshipBetweenGroups(5, atkGroup, atkHated) -- jangan terus membenci grup target lama (mis. PLAYER)
    end
    atkHated = tg
    SetRelationshipBetweenGroups(5, atkGroup, tg)
    SetPedRelationshipGroupHash(p.ped, atkGroup)
end

local function restoreGroup(p)
    if exists(p) and relGroup then SetPedRelationshipGroupHash(p.ped, relGroup) end
end

local function fightAttributes(ped)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 5, true)    -- berani melawan target bersenjata walau tak bersenjata
    SetPedCombatAttributes(ped, 46, true)   -- selalu bertarung
    SetPedCombatAttributes(ped, 17, false)  -- jangan selalu kabur
    SetPedCombatAttributes(ped, 58, true)   -- jangan kabur dari pertarungan
    SetPedCombatAbility(ped, 2)             -- profesional
    SetPedCombatMovement(ped, 3)            -- menyerbu (offensive)
    SetPedCombatRange(ped, 0)               -- jarak dekat
end

local function attack(p, ped)
    if not validTarget(p, ped) then return false end
    if IsPedAPlayer(ped) then
        local sid = GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped))
        if not lib.callback.await('f_petshop:canAttack', false, p.id, sid) then return false end
    end
    if not ensureControl(p.ped, 1000) then return false end

    local token = {}
    p.fetching, p.trickToken, p.attackTarget = nil, nil, token
    if not p.guard then p.mode = 'attack' end
    ClearPedTasks(p.ped)
    fightAttributes(p.ped)
    makeHostile(p, ped)
    TaskCombatPed(p.ped, ped, 0, 16)
    changed()

    CreateThread(function()
        local deadline = GetGameTimer() + Config.Attack.maxTime * 1000
        local nextRetask = GetGameTimer() + 1000
        while p.attackTarget == token and exists(p) and not p.row.dead do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) or GetGameTimer() > deadline
                or #(GetEntityCoords(p.ped) - GetEntityCoords(ped)) > Config.Attack.range
                or (Config.Attack.stopWhenDown and IsPedRagdoll(ped))
                or (p.guard and #(GetEntityCoords(ped) - p.guard.pos) > p.guard.radius * 2.0) then
                break
            end
            -- tugas serang terputus (dibatalkan AI / kehilangan kontrol jaringan): ulangi
            if GetGameTimer() > nextRetask then
                nextRetask = GetGameTimer() + 1000
                if GetScriptTaskStatus(p.ped, `SCRIPT_TASK_COMBAT`) == 7 and NetworkHasControlOfEntity(p.ped) then
                    fightAttributes(p.ped)
                    TaskCombatPed(p.ped, ped, 0, 16)
                end
            end
            Wait(250)
        end
        if p.attackTarget ~= token then
            -- dibatalkan perintah lain; kembalikan grup kecuali sudah ada serangan baru
            if not p.attackTarget then restoreGroup(p) end
            return
        end
        p.attackTarget = nil
        restoreGroup(p)
        if exists(p) then ClearPedTasks(p.ped) end
        backToPost(p)
    end)
    return true
end

-- arahkan kamera ke target lalu tekan E
function Pet.pickTarget(p)
    if not Pet.canFight(p.cfg) then return end
    if cache.vehicle then return notify('Turun dari kendaraan dulu.', 'error') end
    TriggerEvent('f_petshop:client:closeUi')
    lib.showTextUI(('[E] Suruh %s menyerang  \n[Backspace] Batal'):format(p.row.name), { icon = 'crosshairs' })
    local chosen
    while exists(p) and not p.row.dead do
        local hit, ent = lib.raycast.cam(511, 4, Config.Attack.range)
        local ped = hit and ent and ent ~= 0 and IsEntityAPed(ent) and validTarget(p, ent) and ent or nil
        if ped then
            local c = GetEntityCoords(ped)
            DrawMarker(2, c.x, c.y, c.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 69, 58, 200,
                true, true, 2, false, nil, nil, false)
        end
        DisableControlAction(0, 38, true)
        if ped and IsDisabledControlJustPressed(0, 38) then chosen = ped break end
        if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then break end
        Wait(0)
    end
    lib.hideTextUI()
    if chosen and not attack(p, chosen) then
        notify('Target itu tidak bisa diserang (teman, terlalu jauh, atau tidak diizinkan).', 'error')
    end
end

-- luas area diisi angka di panel (meter); hewan menjaga di tempatnya sekarang
function Pet.placeGuard(p, radius)
    if not Pet.canFight(p.cfg) or p.vehicle or not exists(p) or p.row.dead then return end
    local r = Config.Attack.guardRadius
    radius = math.floor(tonumber(radius) or r.default)
    radius = math.max(r.min, math.min(r.max, radius))

    ensureControl(p.ped, 500)
    local token = { pos = GetEntityCoords(p.ped), radius = radius }
    p.fetching, p.trickToken, p.attackTarget, p.guard = nil, nil, nil, token
    p.mode = 'guard'
    ClearPedTasks(p.ped)
    SetBlockingOfNonTemporaryEvents(p.ped, true)
    SetPedFleeAttributes(p.ped, 0, false)
    SetPedCombatAttributes(p.ped, 17, false)
    SetPedCombatAttributes(p.ped, 58, true)
    TaskStandStill(p.ped, -1)
    notify(('%s menjaga area (%d m). Teman di Daftar Teman tidak diserang.'):format(p.row.name, radius), 'success')
    changed()

    -- tampilkan lingkaran area 5 detik sebagai tanda
    CreateThread(function()
        local untilT = GetGameTimer() + 5000
        local c = token.pos
        while GetGameTimer() < untilT and p.guard == token do
            DrawMarker(1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2.0, radius * 2.0, 0.6,
                243, 179, 84, 90, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)

    -- hanya PEMAIN yang masuk area yang diserang (NPC lewat tidak diganggu)
    CreateThread(function()
        while p.guard == token and exists(p) and not p.row.dead do
            -- tidak sedang menyerang: tetap di pos (kalau bergeser / kabur, kembali lalu diam)
            if not p.attackTarget and NetworkHasControlOfEntity(p.ped) then
                local dist = #(GetEntityCoords(p.ped) - token.pos)
                if dist > 2.0 then
                    if GetScriptTaskStatus(p.ped, `SCRIPT_TASK_GO_STRAIGHT_TO_COORD`) == 7 then
                        TaskGoStraightToCoord(p.ped, token.pos.x, token.pos.y, token.pos.z, 2.0, 15000, 0.0, 0.5)
                    end
                elseif GetScriptTaskStatus(p.ped, `SCRIPT_TASK_STAND_STILL`) == 7 then
                    TaskStandStill(p.ped, -1)
                end
            end
            if not p.attackTarget then
                for _, pl in ipairs(lib.getNearbyPlayers(token.pos, token.radius, false)) do
                    local sid = GetPlayerServerId(pl.id)
                    local last = guardChecked[sid]
                    if (not last or GetGameTimer() - last > Config.Attack.guardCooldown * 1000)
                        and not IsPedDeadOrDying(pl.ped, true) and not IsPedInAnyVehicle(pl.ped, false) then
                        guardChecked[sid] = GetGameTimer()
                        if attack(p, pl.ped) then break end
                    end
                end
            end
            Wait(500)
        end
    end)
end

function Pet.stopGuard(p)
    p.guard, p.attackTarget = nil, nil
    if exists(p) and not p.row.dead then follow(p) end
    changed()
end

---------------------------------------------------------------------------
-- ox_target pada hewan peliharaan (statebag fpet)
---------------------------------------------------------------------------
local function mine(entity)
    local s = petState(entity)
    if not s or s.owner ~= cache.serverId then return end
    local p = Pet.list[s.id]
    return p and p.ped == entity and p or nil
end

-- makan & minum: hanya pemilik
local feedOptions = {}
local consumables = {}
for _, f in ipairs(Config.Food) do consumables[#consumables + 1] = f end
for _, d in ipairs(Config.Drinks) do consumables[#consumables + 1] = d end
for _, food in ipairs(consumables) do
    feedOptions[#feedOptions + 1] = {
        name = 'fpet_feed_' .. food.item,
        icon = food.thirst and 'fa-solid fa-droplet' or 'fa-solid fa-bone',
        label = ('Beri %s'):format(food.label),
        distance = 2.5,
        canInteract = function(entity)
            local p = mine(entity)
            return p and not p.row.dead and exports.ox_inventory:Search('count', food.item) > 0
        end,
        onSelect = function(data)
            lib.requestAnimDict('pickup_object')
            TaskPlayAnim(cache.ped, 'pickup_object', 'putdown_low', 8.0, -8.0, 1200, 0, 0.0, false, false, false)
            lib.callback.await('f_petshop:feed', false, food.item, NetworkGetNetworkIdFromEntity(data.entity))
        end,
    }
end
exports.ox_target:addGlobalPed(feedOptions)

-- elus: siapa pun, hewan hidup
local petting = false

local function stroke(entity)
    local s = petState(entity)
    local cfg = s and petsById[s.pet]
    if not cfg then return end
    local set = Config.Petting[cfg.kind] or Config.Petting.default
    petting = true

    -- pemilik hewan (yang mengendalikan ped-nya) menghentikan hewan & menghadapkannya ke kita,
    -- jadi semua pemain melihat animasi yang sama
    TriggerServerEvent('f_petshop:server:petting', NetworkGetNetworkIdFromEntity(entity))
    Wait(350)

    -- pemain berdiri di depan hewan, menghadap ke arahnya
    local pos = GetOffsetFromEntityInWorldCoords(entity, set.offset.x, set.offset.y, 0.0)
    SetEntityCoordsNoOffset(cache.ped, pos.x, pos.y, GetEntityCoords(cache.ped).z, false, false, false)
    SetEntityHeading(cache.ped, (GetEntityHeading(entity) + 180.0) % 360.0)

    lib.progressCircle({
        duration = Config.Petting.duration,
        label = ('Mengelus %s...'):format(s.name or cfg.label),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, combat = true, car = true },
        anim = DoesAnimDictExist(set.player[1]) and { dict = set.player[1], clip = set.player[2], flag = 1 } or nil,
    })
    ClearPedTasks(cache.ped)
    petting = false
end

exports.ox_target:addGlobalPed({
    {
        -- menu hewan langsung dari hewannya (hanya pemilik), hewan itu yang terpilih
        name = 'fpet_menu',
        icon = 'fa-solid fa-paw',
        label = 'Menu Hewan',
        distance = 2.5,
        canInteract = function(entity)
            local p = mine(entity)
            return p ~= nil and not carry
        end,
        onSelect = function(data)
            local p = mine(data.entity)
            if p then TriggerEvent('f_petshop:client:openMenu', p.id) end
        end,
    },
    {
        name = 'fpet_pet',
        icon = 'fa-solid fa-hand-holding-heart',
        label = 'Elus',
        distance = 2.0,
        canInteract = function(entity)
            local s = petState(entity)
            return s and not s.dead and not petting and not carry and not cache.vehicle
                and not IsEntityAttached(entity)
        end,
        onSelect = function(data) stroke(data.entity) end,
    },
    {
        name = 'fpet_carry',
        icon = 'fa-solid fa-hands',
        label = 'Gendong',
        distance = 2.5,
        canInteract = function(entity)
            local s = petState(entity)
            local cfg = s and petsById[s.pet]
            return cfg and s.dead and cfg.carry ~= false and not s.carrier and not s.seatVeh
                and not carry and not cache.vehicle
        end,
        onSelect = function(data) Pet.pickUp(data.entity) end,
    },
    {
        name = 'fpet_ems_revive',
        icon = 'fa-solid fa-heart-pulse',
        label = 'Sembuhkan Hewan',
        distance = 2.5,
        canInteract = function(entity)
            local s = petState(entity)
            if not s or not s.dead or s.carrier or carry then return false end
            local job = QBX and QBX.PlayerData and QBX.PlayerData.job
            if not (job and Config.Vet.emsJobs[job.name] and job.onduty) then return false end
            -- tas & area dicek lagi di server; di sini hanya supaya opsi tidak muncul sia-sia
            if exports.ox_inventory:Search('count', Config.Vet.bag) < 1 then return false end
            return not Config.Vet.requireArea or #(GetEntityCoords(cache.ped) - Config.Vet.coords) <= Config.Vet.radius
        end,
        onSelect = function(data)
            local netId = NetworkGetNetworkIdFromEntity(data.entity)
            if lib.progressCircle({
                duration = Config.Vet.duration or 8000,
                label = 'Menyembuhkan hewan...',
                position = 'bottom',
                canCancel = true,
                disable = { move = true, combat = true, car = true },
                anim = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
            }) then
                lib.callback.await('f_petshop:emsRevive', false, netId)
            end
        end,
    },
})

-- ambil hewan mati dari kendaraan: siapa pun
exports.ox_target:addGlobalVehicle({
    {
        name = 'fpet_take_from_vehicle',
        icon = 'fa-solid fa-paw',
        label = 'Ambil Hewan (Gendong)',
        distance = 3.0,
        canInteract = function(entity)
            return not carry and not cache.vehicle and deadPetIn(entity) ~= nil
        end,
        onSelect = function(data)
            local ped = deadPetIn(data.entity)
            if ped then Pet.pickUp(ped) end
        end,
    },
})

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    if carry then
        StopAnimTask(cache.ped, CARRY_DICT, CARRY_ANIM, 2.0)
        lib.hideTextUI()
    end
    for _, p in pairs(Pet.list) do
        if exists(p) then DeleteEntity(p.ped) end
    end
    exports.ox_target:removeGlobalVehicle('fpet_take_from_vehicle')
    exports.ox_target:removeGlobalPed({ 'fpet_menu', 'fpet_carry', 'fpet_ems_revive', 'fpet_pet' })
    for _, o in ipairs(feedOptions) do exports.ox_target:removeGlobalPed(o.name) end
end)
