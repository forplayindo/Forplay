-- Stress gain + screen effects, ported from f_stress (0Resmon) for Qbox.
-- The value itself is server-authoritative (modules/stress/server.lua); PlayerData.stress is fed by the bridge.

local stress = {}

local cfg = Config.Stress
if not cfg or not cfg.enabled then return stress end

local speedMultiplier = Config.DefaultHudSettings.vehicle_info.kmH and 3.6 or 2.23694
local isNotifSend = false

local whitelistedWeapons = {}
for _, hash in ipairs(cfg.whitelistedWeapons) do
    whitelistedWeapons[hash] = true
end

local function isActive()
    if not client.load then return false end
    local job = (client.GetPlayerData() or {}).job
    return not (job and cfg.excludedJobs[job.name])
end

local function getStress()
    return PlayerData.stress or 0
end

local function sendNotify(title, type)
    if isNotifSend then return end
    isNotifSend = true
    lib.notify({ title = title, duration = 3000, position = 'center-right', type = type })
end

local lastStress
RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    if type(newStress) ~= 'number' then return end
    if lastStress then
        if newStress > lastStress then
            sendNotify(locale('more_stressed'), 'inform')
        elseif newStress < lastStress then
            sendNotify(locale('more_relaxed'), 'success')
        end
    end
    lastStress = newStress
end)

CreateThread(function() -- max 1 notif per menit
    while true do
        Wait(60000)
        isNotifSend = false
    end
end)

-- Stress Gain

CreateThread(function() -- Speeding
    while true do
        Wait(10000)
        local veh = cache.vehicle
        if veh and isActive() and not cfg.ignoredVehicleClasses[GetVehicleClass(veh)] then
            if GetEntitySpeed(veh) * speedMultiplier >= cfg.minimumSpeed then
                TriggerServerEvent('hud:server:GainStress', math.random(cfg.speedGain.min, cfg.speedGain.max))
            end
        end
    end
end)

CreateThread(function() -- Shooting
    local sleep = 1000
    while true do
        Wait(sleep)
        sleep = 1000
        if client.load and cache.weapon and not whitelistedWeapons[cache.weapon] then
            sleep = 5
            local ped = cache.ped
            if IsPedShooting(ped) and math.random() < cfg.shootChance and isActive() then
                TriggerServerEvent('hud:server:GainStress', math.random(cfg.shootGain.min, cfg.shootGain.max))
            end
        end
    end
end)

-- Stress Screen Effects

local function getBlurIntensity(level)
    for _, v in ipairs(cfg.blur) do
        if level >= v.min and level <= v.max then
            return v.intensity
        end
    end
    return 1500
end

local function getEffectInterval(level)
    for _, v in ipairs(cfg.interval) do
        if level >= v.min and level <= v.max then
            return math.random(v.from, v.to)
        end
    end
    return 60000
end

local function blurPulse(intensity)
    TriggerScreenblurFadeIn(1000.0)
    Wait(intensity)
    TriggerScreenblurFadeOut(1000.0)
end

CreateThread(function()
    while true do
        local level = getStress()
        local ped = cache.ped
        if client.load and level >= cfg.minimumStress and not IsEntityDead(ped) then
            local intensity = getBlurIntensity(level)
            if level >= 100 then
                local fallRepeat = math.random(2, 4)
                local ragdollTimeout = fallRepeat * 1750
                blurPulse(intensity)
                if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                    SetPedToRagdollWithFall(ped, ragdollTimeout, ragdollTimeout, 1, GetEntityForwardVector(ped), 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                end
                Wait(1000)
                for _ = 1, fallRepeat do
                    Wait(750)
                    DoScreenFadeOut(200)
                    Wait(1000)
                    DoScreenFadeIn(200)
                    blurPulse(intensity)
                end
            else
                blurPulse(intensity)
            end
        end
        Wait(getEffectInterval(level))
    end
end)

return stress
