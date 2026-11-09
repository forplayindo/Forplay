-- Keausan & efek kerusakan (client). Hanya berjalan saat pemain jadi PENGEMUDI, satu loop per detik.
--  * Keausan dikumpulkan lalu dikirim ke server tiap `sendEvery` detik / saat turun. Server hanya
--    menerima pengurangan dan membatasinya (server/condition.lua).
--  * Efek handling (rem, grip, suspensi, tenaga) hanya diubah saat tingkat kondisinya berubah.
local cfg = require 'config.shared'
local W = require 'config.wear'

local STATE_KEY = 'f_mech:cond'
local HANDLING = { 'fBrakeForce', 'fTractionCurveMax', 'fTractionCurveMin', 'fSuspensionForce', 'fSuspensionCompDamp', 'fSuspensionReboundDamp', 'fInitialDriveForce' }

local cur, netId                ---@type number?, number?
local acc                       ---@type { p: table<string, number>, tw: table<string, number>, km: number }
local lastSend = 0
local prevBody, prevForward = 1000.0, 0.0
local speedHist = {}
local timers = {}
local airborne, minVz = false, 0.0
local collidedAt = 0
local steerReset = 0
local lastSqueal = 0
local baseHandling = {}         ---@type table<number, table<string, number>>
local appliedSig = {}           ---@type table<number, string>

local function level(v)
    v = tonumber(v) or 100
    for i, min in ipairs(cfg.levels) do
        if v >= min then return i end
    end
    return #cfg.levels + 1
end

local function rand(range) return math.random(range[1] * 10, range[2] * 10) / 10 end

local function resetAcc() acc = { p = {}, tw = {}, km = 0.0 } end
resetAcc()

local function wear(part, amount)
    if amount > 0 then acc.p[part] = (acc.p[part] or 0) + amount end
end

local function wearTyre(key, amount)
    if amount > 0 then acc.tw[key] = (acc.tw[key] or 0) + amount end
end

---Nilai bawaan GTA kendaraan dalam persen (dipakai server karena nilai di server sering tidak
---ter-update). Juga dipakai client/panel.lua untuk callback f_mechanicjob:client:nativeSnap.
---@param veh number
function MechNativeSnapshot(veh)
    local burst = {}
    for idx = 0, 7 do
        if IsVehicleTyreBurst(veh, idx, false) then burst[#burst + 1] = idx end
    end
    local function pct(v) return math.floor(math.max(0, math.min(1000, v)) + 0.5) / 10 end
    return { e = pct(GetVehicleEngineHealth(veh)), b = MechBodyCondition(veh), t = pct(GetVehiclePetrolTankHealth(veh)), burst = burst }
end

-- Body health GTA hanya turun sedikit walau bodi penyok parah, dan kaca pecah tidak mengubahnya.
-- Kondisi Body = nilai terendah dari body health dan kerusakan yang terlihat (penyok, kaca, pintu,
-- bumper, lampu). Hanya dihitung saat panel dibuka / laporan keausan, bukan tiap frame.
local WINDOW_BONES = { [0] = 'window_lf', 'window_rf', 'window_lr', 'window_rr', 'window_lm', 'window_rm', 'windscreen', 'windscreen_r' }
local DOOR_BONES = { [0] = 'door_dside_f', 'door_pside_f', 'door_dside_r', 'door_pside_r', 'bonnet', 'boot' }

---@param veh number
---@return number persen 0-100
function MechBodyCondition(veh)
    local health = math.max(0, math.min(1000, GetVehicleBodyHealth(veh))) / 10
    local penalty = 0.0

    -- penyok: deformasi di 9 titik sekeliling kendaraan (meter)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local points = {
        vec3(0.0, max.y * 0.9, 0.0), vec3(0.0, min.y * 0.9, 0.0),
        vec3(min.x * 0.9, 0.0, 0.0), vec3(max.x * 0.9, 0.0, 0.0),
        vec3(min.x * 0.8, max.y * 0.8, 0.0), vec3(max.x * 0.8, max.y * 0.8, 0.0),
        vec3(min.x * 0.8, min.y * 0.8, 0.0), vec3(max.x * 0.8, min.y * 0.8, 0.0),
        vec3(0.0, 0.0, max.z * 0.8),
    }
    local dent = 0.0
    for i = 1, #points do dent += #GetVehicleDeformationAtPos(veh, points[i].x, points[i].y, points[i].z) end
    penalty += math.min(45.0, dent * 40.0)

    -- kaca pecah (hanya kaca yang memang ada di model)
    for idx, bone in pairs(WINDOW_BONES) do
        if GetEntityBoneIndexByName(veh, bone) ~= -1 and not IsVehicleWindowIntact(veh, idx) then
            penalty += (idx >= 6) and 8.0 or 5.0
        end
    end
    -- pintu / kap / bagasi lepas
    for idx, bone in pairs(DOOR_BONES) do
        if GetEntityBoneIndexByName(veh, bone) ~= -1 and IsVehicleDoorDamaged(veh, idx) then penalty += 6.0 end
    end
    -- bumper lepas / menggantung
    for _, front in ipairs({ true, false }) do
        if IsVehicleBumperBrokenOff(veh, front) then penalty += 6.0
        elseif IsVehicleBumperBouncing(veh, front) then penalty += 3.0 end
    end
    -- lampu depan pecah
    if GetIsLeftVehicleHeadlightDamaged(veh) then penalty += 3.0 end
    if GetIsRightVehicleHeadlightDamaged(veh) then penalty += 3.0 end

    local visual = math.max(0.0, 100.0 - penalty)
    return math.floor(math.min(health, visual) * 10 + 0.5) / 10
end

local lastNativeSig    ---@type string?

local function send()
    if not netId then return end
    local n = cur and DoesEntityExist(cur) and MechNativeSnapshot(cur) or nil
    local sig = n and ('%s|%s|%s|%s'):format(n.e, n.b, n.t, table.concat(n.burst, ',')) or nil
    local empty = acc.km <= 0 and next(acc.p) == nil and next(acc.tw) == nil
    if not empty or sig ~= lastNativeSig then
        local function round(t)
            for k, v in pairs(t) do t[k] = math.floor(v * 1000 + 0.5) / 1000 end
            return t
        end
        TriggerServerEvent('f_mechanicjob:server:wear', netId, { p = round(acc.p), tw = round(acc.tw), km = acc.km, n = n })
        lastNativeSig = sig
    end
    resetAcc()
    lastSend = GetGameTimer()
end

local function tyreDefs(veh)
    return cfg.tyres[IsThisModelABike(GetEntityModel(veh)) and 'bike' or 'car']
end

---------------------------------------------------------------------------
-- Efek
---------------------------------------------------------------------------
local function applyHandling(veh, c)
    local brakeLvl = math.max(level(c.brakes), level(c.brakefluid))
    local tyreSum, tyreN = 0, 0
    for _, w in pairs(c.tw or {}) do tyreSum += w tyreN += 1 end
    local tyreLvl = level(tyreN > 0 and tyreSum / tyreN or 100)
    local rain = GetRainLevel() > W.rainLevel
    local suspLvl = level(c.suspension)
    local powerLvls = ('%d%d%d'):format(level(c.sparkplugs), level(c.airfilter), level(c.oil))

    local sig = table.concat({ brakeLvl, tyreLvl, rain and 1 or 0, suspLvl, powerLvls }, ',')
    if appliedSig[veh] == sig then return end
    appliedSig[veh] = sig

    local base = baseHandling[veh]
    if not base then
        base = {}
        for _, field in ipairs(HANDLING) do base[field] = GetVehicleHandlingFloat(veh, 'CHandlingData', field) end
        baseHandling[veh] = base
    end

    local traction = W.traction[tyreLvl]
    if rain then traction = 1 - (1 - traction) * W.rainPenalty end
    traction = math.max(0.3, traction)
    local power = W.power[level(c.sparkplugs)] * W.power[level(c.airfilter)] * W.power[level(c.oil)]
    local susp = W.suspension[suspLvl]

    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce', base.fBrakeForce * W.brakeForce[brakeLvl])
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMax', base.fTractionCurveMax * traction)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fTractionCurveMin', base.fTractionCurveMin * traction)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionForce', base.fSuspensionForce * susp)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionCompDamp', base.fSuspensionCompDamp * susp)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fSuspensionReboundDamp', base.fSuspensionReboundDamp * susp)
    SetVehicleHandlingFloat(veh, 'CHandlingData', 'fInitialDriveForce', base.fInitialDriveForce * power)
end

-- f_handling mengubah handling kendaraan ini: perbarui nilai dasar field yang diubah saja
-- (field lain masih berisi dasar x pengali aus, jangan dibaca ulang), lalu pasang ulang efek aus.
AddEventHandler('f_handling:applied', function(veh, values)
    local base = baseHandling[veh]
    if base then
        for field, v in pairs(values) do
            if base[field] then base[field] = v end
        end
    end
    appliedSig[veh] = nil
end)

local function stutter(veh, ms)
    CreateThread(function()
        SetVehicleEngineOn(veh, false, true, true)
        Wait(ms)
        if DoesEntityExist(veh) and cache.vehicle == veh then SetVehicleEngineOn(veh, true, true, true) end
    end)
end

local function randomEffects(veh, c, speed)
    local running = GetIsVehicleEngineRunning(veh)
    local now = GetGameTimer()

    if steerReset > 0 and now >= steerReset then
        SetVehicleSteerBias(veh, 0.0)
        steerReset = 0
    end
    if not running then return end

    if speed > 3.0 then
        if math.random() < W.misfire[level(c.sparkplugs)] then stutter(veh, 400)
        elseif math.random() < W.clutchSlip[level(c.clutch)] then stutter(veh, 250) end

        if steerReset == 0 and math.random() < W.steerWobble[level(c.axle)] then
            SetVehicleSteerBias(veh, (math.random() < 0.5 and -1 or 1) * 0.15)
            steerReset = now + 1500
        end
        -- rem Parah: mobil menarik ke samping saat ngerem keras
        if level(c.brakes) == 4 and speed > 15.0 and IsControlPressed(0, 72) and steerReset == 0 then
            SetVehicleSteerBias(veh, (math.random() < 0.5 and -1 or 1) * W.brakePull)
            steerReset = now + 1000
        end

        -- rem Rusak / Parah berdecit saat dipakai (server meneruskan ke pemain sekitar)
        if level(c.brakes) >= W.squeal.level and speed > W.squeal.minSpeed and IsControlPressed(0, 72)
            and now - lastSqueal > W.squeal.interval then
            lastSqueal = now
            TriggerServerEvent('f_mechanicjob:server:squeal', netId)
        end

        local fuelExtra = W.extraFuel[level(c.airfilter)]
        if fuelExtra > 0 then SetVehicleFuelLevel(veh, math.max(0.0, GetVehicleFuelLevel(veh) - fuelExtra)) end

        if speed > W.selfBurst.minSpeed then
            for _, t in ipairs(tyreDefs(veh)) do
                if (c.tw[t.key] or 100) < W.selfBurst.below and not IsVehicleTyreBurst(veh, t.index, false)
                    and math.random() < W.selfBurst.chance then
                    SetVehicleTyreBurst(veh, t.index, false, 1000.0)
                end
            end
        end
    end

    -- oli / coolant habis: mesin overheat & rusak perlahan
    local heat = W.overheatEngine[math.max(level(c.oil), level(c.coolant))]
    if heat > 0 then
        local eh = GetVehicleEngineHealth(veh)
        if eh > 0 then SetVehicleEngineHealth(veh, math.max(0.0, eh - heat * W.tick / 1000)) end
    end
end

---------------------------------------------------------------------------
-- Keausan
---------------------------------------------------------------------------
local function timer(name, active, dt, seconds)
    if not active then timers[name] = 0 return false end
    timers[name] = (timers[name] or 0) + dt
    if timers[name] >= seconds then timers[name] = 0 return true end
    return false
end

local function tick(veh, c)
    local dt = W.tick / 1000
    local now = GetGameTimer()
    local speed = GetEntitySpeed(veh)
    local kmh = speed * 3.6
    local km = speed * dt / 1000
    acc.km += km

    local class = GetVehicleClass(veh)
    local pos = GetEntityCoords(veh)
    local offroad = speed > W.offroad.minSpeed and not IsPointOnRoad(pos.x, pos.y, pos.z, veh)
    local braking = IsControlPressed(0, 72)
    local gas = IsControlPressed(0, 71)
    local ch = W.chain

    -- jarak tempuh
    if km > 0 then
        local engine = GetVehicleEngineHealth(veh) / 10
        for part, life in pairs(W.life) do
            if part ~= 'tyre' then
                local mult = 1.0
                if part == 'oil' and engine < ch.oilWhenEngineBelow then mult = ch.oilMult end
                if part == 'coolant' and c.radiator < ch.coolantWhenRadiatorBelow then mult = ch.coolantMult end
                if part == 'sparkplugs' and c.airfilter < ch.sparkWhenFilterBelow then mult = ch.sparkMult end
                if part == 'clutch' and c.transfluid < ch.clutchWhenTransBelow then mult = ch.clutchMult end
                if part == 'brakes' and c.brakefluid < ch.brakesWhenFluidBelow then mult = ch.brakesMult end
                if part == 'airfilter' and offroad then mult = W.offroad.airfilterMult end
                wear(part, km / life * 100 * mult)
            end
        end
        if offroad and class ~= W.offroadClass then wear('suspension', km * W.offroad.suspensionPerKm) end

        local tyreWear = km / W.life.tyre * 100 * (offroad and W.offroad.tyreMult or 1.0)
        for key in pairs(c.tw) do wearTyre(key, tyreWear) end
    end

    -- burnout / drift
    if IsVehicleInBurnout(veh) then
        for _, t in ipairs(tyreDefs(veh)) do
            if t.key:sub(1, 1) == 'R' then wearTyre(t.key, W.burnout.tyrePerSec * dt) end
        end
        wear('transfluid', W.burnout.transfluidPerSec * dt)
        wear('clutch', W.burnout.clutchPerSec * dt)
    end
    local lateral = math.abs(GetEntitySpeedVector(veh, true).x)
    if lateral > W.drift.lateral and speed > W.drift.minSpeed then
        for key in pairs(c.tw) do wearTyre(key, W.drift.tyrePerSec * dt) end
    end

    -- start gas penuh dari diam
    if speed < 3.0 and GetControlNormal(0, 71) > 0.95 and GetVehicleCurrentRpm(veh) > 0.9 then
        wear('clutch', W.launch.clutchPerSec * dt)
    end

    -- rem mendadak dari kecepatan tinggi (bukan tabrakan)
    speedHist[#speedHist + 1] = kmh
    if #speedHist > W.hardBrake.window + 1 then table.remove(speedHist, 1) end
    local peak = 0
    for i = 1, #speedHist do peak = math.max(peak, speedHist[i]) end
    if peak >= W.hardBrake.fromKmh and kmh <= W.hardBrake.toKmh and braking and now - collidedAt > 3000 then
        wear('brakes', rand(W.hardBrake.brakes))
        wear('brakefluid', W.hardBrake.brakefluid)
        speedHist = {}
    end

    if timer('brakeGas', braking and gas and speed > 1.0, dt, W.brakeAndGas.seconds) then
        wear('brakes', W.brakeAndGas.brakes)
        wear('clutch', W.brakeAndGas.clutch)
    end
    if timer('downhill', braking and speed > 3.0 and GetEntityPitch(veh) < W.downhill.pitch, dt, W.downhill.seconds) then
        wear('brakes', rand(W.downhill.brakes))
    end
    if timer('rpm', GetVehicleCurrentRpm(veh) > W.highRpm.rpm, dt, W.highRpm.seconds) then
        wear('oil', W.highRpm.oil)
        wear('sparkplugs', W.highRpm.sparkplugs)
    end

    -- mendarat keras setelah lompat
    if IsEntityInAir(veh) then
        airborne = true
        minVz = math.min(minVz, GetEntityVelocity(veh).z)
    elseif airborne then
        if minVz <= W.landing.velocity then
            local scale = math.min(2.0, minVz / W.landing.velocity)
            wear('suspension', rand(W.landing.suspension) * scale)
            wear('axle', rand(W.landing.axle) * scale)
        end
        airborne, minVz = false, 0.0
    end

    -- tabrakan (body turun). Arah dari gerak sebelum benturan: maju = depan.
    local body = GetVehicleBodyHealth(veh)
    local drop = prevBody - body
    if drop >= W.collision.minDrop then
        local sev = drop / 10
        local col = W.collision
        if prevForward >= 0 then
            wear('radiator', sev * col.radiator)
            wear('brakes', sev * col.brakes)
        end
        wear('suspension', sev * col.suspension)
        wear('axle', sev * col.axle)
        collidedAt = now
    end
    prevBody = body
    prevForward = GetEntitySpeedVector(veh, true).y
end

-- decit rem dari kendaraan di sekitar (dikirim server): volume menurun sesuai jarak
RegisterNetEvent('f_mechanicjob:client:squeal', function(vehNet, severe)
    local veh = NetworkGetEntityFromNetworkId(vehNet)
    if veh == 0 or not DoesEntityExist(veh) then return end
    local dist = #(GetEntityCoords(cache.ped) - GetEntityCoords(veh))
    if dist > W.squeal.distance then return end
    local volume = W.squeal.volume * (1 - dist / W.squeal.distance) ^ 2
    SendNUIMessage({ action = 'squeal', volume = volume, severe = severe == true })
end)

---------------------------------------------------------------------------
-- Loop
---------------------------------------------------------------------------
local function onEnter(veh)
    cur = veh
    netId = NetworkGetNetworkIdFromEntity(veh)
    resetAcc()
    lastSend = GetGameTimer()
    prevBody = GetVehicleBodyHealth(veh)
    prevForward = 0.0
    speedHist, timers = {}, {}
    airborne, minVz = false, 0.0
    appliedSig[veh] = nil
    lastNativeSig = nil
    if type(Entity(veh).state[STATE_KEY]) ~= 'table' then
        TriggerServerEvent('f_mechanicjob:server:initCond', netId)
    end
end

local function onLeave()
    if cur and DoesEntityExist(cur) and steerReset > 0 then SetVehicleSteerBias(cur, 0.0) end
    steerReset = 0
    send()
    cur, netId = nil, nil
end

CreateThread(function()
    while true do
        local veh = cache.vehicle
        if veh and cache.seat == -1 and not W.ignoredClasses[GetVehicleClass(veh)] and NetworkGetEntityIsNetworked(veh) then
            if veh ~= cur then
                if cur then onLeave() end
                onEnter(veh)
            end
            local c = Entity(veh).state[STATE_KEY]
            if type(c) == 'table' and type(c.tw) == 'table' then
                tick(veh, c)
                applyHandling(veh, c)
                randomEffects(veh, c, GetEntitySpeed(veh))
            end
            if GetGameTimer() - lastSend >= W.sendEvery * 1000 then send() end
            Wait(W.tick)
        else
            if cur then onLeave() end
            Wait(1000)
        end

        for v in pairs(baseHandling) do
            if not DoesEntityExist(v) then baseHandling[v] = nil appliedSig[v] = nil end
        end
    end
end)
