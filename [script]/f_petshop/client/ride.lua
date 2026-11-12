-- f_petshop client: tunggang kuda (Config.Ride). SIAPA PUN boleh naik kuda peliharaan siapa pun:
-- orang pertama = pengendali (rider), orang kedua = bonceng di belakang (passenger).
-- Server mencatat siapa yang naik di statebag `fpet.rider` / `fpet.passenger`.
--
-- GTA V tidak punya sistem tunggang: pemain DITEMPEL ke badan kuda + animasi duduk mengangkang,
-- pengendali mengambil kendali jaringan kuda dan menggerakkannya dengan tugas jalan lurus
-- (TaskGoStraightToCoord) ke titik di depan sesuai arah yang dibelokkan pemain.

Ride = {}

local petsById = {}
for _, p in ipairs(Config.Pets) do petsById[p.id] = p end

local R = Config.Ride
local riding -- { horse, netId, role = 'rider' | 'passenger', cfg, offset }
local seatAnim -- animasi duduk yang dipakai (dipilih sekali dari R.anims)

local function notify(msg, kind) lib.notify({ description = msg, type = kind or 'inform' }) end
local function petState(entity) return Entity(entity).state.fpet end

local function rideCfg(entity)
    local s = petState(entity)
    local cfg = s and petsById[s.pet]
    return cfg and R.kinds[cfg.kind] and cfg or nil, s
end

-- animasi pertama dari daftar yang benar-benar ada di game
local function pickAnim()
    if seatAnim then return seatAnim end
    for _, a in ipairs(R.anims) do
        if DoesAnimDictExist(a[1]) and pcall(lib.requestAnimDict, a[1], 3000) and GetAnimDuration(a[1], a[2]) > 0 then
            seatAnim = a
            return a
        end
    end
end

local function playSeatAnim()
    local a = pickAnim()
    if not a then return end
    lib.requestAnimDict(a[1])
    TaskPlayAnim(cache.ped, a[1], a[2], 8.0, -8.0, -1, 1, 0.0, false, false, false)
end

local function seatOffset(cfg, role)
    local s = R.seat[cfg.id] or R.seat.default
    return (s[role] or R.seat.default[role])
end

local function attach(horse, offset)
    AttachEntityToEntity(cache.ped, horse, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0,
        false, false, false, false, 2, true)
end

function Ride.active() return riding ~= nil end
function Ride.isOn(horse) return riding ~= nil and riding.horse == horse end

local CONTROLS_RIDER = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 140, 141, 142, 143, 257, 263 }
local CONTROLS_PASSENGER = { 21, 22, 23, 24, 25, 36, 37, 44, 140, 141, 142, 143, 257, 263 }

---@param fall boolean? true = terjatuh (ragdoll), bukan turun biasa
function Ride.dismount(fall)
    if not riding then return end
    local r = riding
    riding = nil
    lib.hideTextUI()

    local horse = r.horse
    local exists = DoesEntityExist(horse)
    DetachEntity(cache.ped, true, false)
    if seatAnim then StopAnimTask(cache.ped, seatAnim[1], seatAnim[2], 2.0) end
    ClearPedTasks(cache.ped)

    -- turun di sisi kiri kuda
    local pos = exists and GetOffsetFromEntityInWorldCoords(horse, -1.2, r.role == 'passenger' and -0.5 or 0.0, 0.0)
        or GetEntityCoords(cache.ped)
    local found, z = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    SetEntityCoords(cache.ped, pos.x, pos.y, found and z or pos.z, false, false, false, false)
    if fall then SetPedToRagdoll(cache.ped, 2500, 2500, 0, false, false, false) end

    -- pengendali turun: kuda berhenti di tempat (pemiliknya bisa menyuruh "Ikuti" lagi)
    if r.role == 'rider' and exists and NetworkHasControlOfEntity(horse) and not IsPedDeadOrDying(horse, true) then
        SetPedMoveRateOverride(horse, 1.0)
        ClearPedTasks(horse)
        TaskStandStill(horse, -1)
    end
    TriggerServerEvent('f_petshop:server:dismount')
end

local function helpText(role)
    if role == 'rider' then
        return '[W] Maju  [A/D] Belok  \n[Shift] Lari kencang  [S] Berhenti  \n[F] Turun'
    end
    return '[F] Turun'
end

-- satu loop untuk pengendali & pembonceng; hanya pengendali yang menggerakkan kuda
local function rideLoop(r)
    local horse, rider = r.horse, r.role == 'rider'
    local heading = GetEntityHeading(horse)
    local lastTask, lastMode = 0, nil
    local lastHealth = GetEntityHealth(cache.ped)
    local tick = 0
    local controls = rider and CONTROLS_RIDER or CONTROLS_PASSENGER
    local rate = (r.cfg.rideRate or 1.0) * R.gallopRate

    while riding == r do
        tick += 1
        for i = 1, #controls do DisableControlAction(0, controls[i], true) end

        -- turun / terjatuh
        local s = DoesEntityExist(horse) and petState(horse)
        if not s or s.dead or IsPedDeadOrDying(horse, true) then Ride.dismount(true) break end
        if IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true) then Ride.dismount(false) break end
        -- statebag baru bisa telat sampai sesaat setelah naik: cek posisi kita di statebag setelah 2 detik
        if (GetGameTimer() > r.since + 2000 and s[r.role] ~= cache.serverId)
            or not IsEntityAttachedToEntity(cache.ped, horse) then
            Ride.dismount(false)
            break
        end
        local hp = GetEntityHealth(cache.ped)
        if lastHealth - hp >= R.fallDamage then Ride.dismount(true) break end
        lastHealth = hp
        if IsDisabledControlJustPressed(0, 23) then Ride.dismount(false) break end

        if tick % 30 == 1 then
            if seatAnim and not IsEntityPlayingAnim(cache.ped, seatAnim[1], seatAnim[2], 3) then playSeatAnim() end
            local text = helpText(r.role)
            local open, current = lib.isTextUIOpen()
            if not open or current ~= text then lib.showTextUI(text, { icon = 'horse' }) end
        end

        if rider then
            if not NetworkHasControlOfEntity(horse) then NetworkRequestControlOfEntity(horse) end
            local now = GetGameTimer()
            local dt = GetFrameTime()
            local turn = (IsDisabledControlPressed(0, 34) and 1 or 0) - (IsDisabledControlPressed(0, 35) and 1 or 0)
            local forward = IsDisabledControlPressed(0, 32) and not IsDisabledControlPressed(0, 33)
            local mode = forward and (IsDisabledControlPressed(0, 21) and 'gallop' or 'walk') or 'stop'
            local turnRate = mode == 'gallop' and R.turnRate * 0.75 or R.turnRate

            if turn ~= 0 then
                heading = (heading + turn * turnRate * dt) % 360.0
            elseif mode == 'stop' then
                heading = GetEntityHeading(horse) -- ikuti arah sebenarnya saat diam
            end

            if mode == 'stop' then
                if lastMode ~= 'stop' then
                    SetPedMoveRateOverride(horse, 1.0)
                    TaskStandStill(horse, -1)
                end
                if turn ~= 0 then SetEntityHeading(horse, heading) end -- berputar di tempat
            else
                if mode ~= lastMode or now - lastTask > 150 then
                    local rad = math.rad(heading)
                    local c = GetEntityCoords(horse)
                    TaskGoStraightToCoord(horse, c.x - math.sin(rad) * 15.0, c.y + math.cos(rad) * 15.0, c.z,
                        R.speed[mode], -1, heading, 0.0)
                    lastTask = now
                end
                SetPedMoveRateOverride(horse, mode == 'gallop' and rate or 1.0)
            end
            lastMode = mode
        end
        Wait(0)
    end
end

function Ride.mount(horse)
    if riding then return end
    if cache.vehicle or Pet.isCarrying() or IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped) then return end
    local cfg, s = rideCfg(horse)
    if not cfg then return notify('Hewan itu tidak bisa ditunggangi.', 'error') end
    if s.dead then return notify('Kuda itu mati.', 'error') end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) > R.distance then
        return notify('Dekati kudanya dulu.', 'error')
    end
    if not pickAnim() then return notify('Animasi tunggang tidak ditemukan.', 'error') end

    local netId = NetworkGetNetworkIdFromEntity(horse)
    local res = lib.callback.await('f_petshop:mount', false, netId)
    if not res or not res.role then
        return notify(res and res.msg or 'Tidak bisa naik sekarang.', 'error')
    end

    if res.role == 'rider' then
        local deadline = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(horse) and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(horse)
            Wait(50)
        end
        if not NetworkHasControlOfEntity(horse) then
            TriggerServerEvent('f_petshop:server:dismount')
            return notify('Gagal naik, coba lagi.', 'error')
        end
        SetBlockingOfNonTemporaryEvents(horse, true)
        SetPedFleeAttributes(horse, 0, false)
        SetPedKeepTask(horse, true)
        ClearPedTasks(horse)
        TaskStandStill(horse, -1)
    end

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    ClearPedTasksImmediately(cache.ped)
    local offset = seatOffset(cfg, res.role)
    attach(horse, offset)
    playSeatAnim()

    local r = { horse = horse, netId = netId, role = res.role, cfg = cfg, offset = offset, since = GetGameTimer() }
    riding = r
    TriggerEvent('f_petshop:client:changed')
    CreateThread(function() rideLoop(r) end)
end

function Ride.toggle(horse)
    if Ride.isOn(horse) then return Ride.dismount(false) end
    Ride.mount(horse)
end

-- server menurunkan paksa (kuda dipulangkan / mati)
RegisterNetEvent('f_petshop:client:forceDismount', function(netId)
    if riding and riding.netId == netId then Ride.dismount(false) end
end)

---------------------------------------------------------------------------
-- ox_target: Tunggangi (pengendali) / Bonceng (di belakang)
---------------------------------------------------------------------------
local function canMount(entity, role)
    if riding or cache.vehicle or Pet.isCarrying() then return false end
    local cfg, s = rideCfg(entity)
    if not cfg or s.dead then return false end
    if role == 'rider' then return s.rider == nil end
    return s.rider ~= nil and s.passenger == nil
end

exports.ox_target:addGlobalPed({
    {
        name = 'fpet_ride',
        icon = 'fa-solid fa-horse',
        label = 'Tunggangi',
        distance = R.distance,
        canInteract = function(entity) return canMount(entity, 'rider') end,
        onSelect = function(data) Ride.mount(data.entity) end,
    },
    {
        name = 'fpet_ride_back',
        icon = 'fa-solid fa-horse',
        label = 'Bonceng',
        distance = R.distance,
        canInteract = function(entity) return canMount(entity, 'passenger') end,
        onSelect = function(data) Ride.mount(data.entity) end,
    },
})

-- Setel posisi duduk langsung di game (Config.Debug): /kudapos x y z
if Config.Debug then
    RegisterCommand('kudapos', function(_, args)
        local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
        if not riding then return notify('Naik kuda dulu, lalu /kudapos x y z') end
        if not (x and y and z) then
            local o = riding.offset
            return notify(('Posisi sekarang: %.2f %.2f %.2f'):format(o.x, o.y, o.z))
        end
        riding.offset = vec3(x, y, z)
        DetachEntity(cache.ped, false, false)
        attach(riding.horse, riding.offset)
        playSeatAnim()
        print(('[f_petshop] Config.Ride.seat.%s.%s = vec3(%.2f, %.2f, %.2f)'):format(riding.cfg.id, riding.role, x, y, z))
        notify('Posisi dicoba. Angka final ada di F8 untuk disalin ke config.lua.')
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    if riding then
        DetachEntity(cache.ped, true, false)
        ClearPedTasks(cache.ped)
        lib.hideTextUI()
    end
    exports.ox_target:removeGlobalPed({ 'fpet_ride', 'fpet_ride_back' })
end)
