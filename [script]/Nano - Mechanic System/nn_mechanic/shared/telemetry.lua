Telemetry = {}

-- Telemetry accumulator
local acc = { d_m = 0, kph10 = 0, hb = 0, off = 0, brake_sec = 0, handbrake_sec = 0, decel_kph = 0 }
local last = { pos = nil, kph = 0, ts = 0, brake_pressed = false, handbrake_pressed = false }

-- Get current timestamp
local function now()
    return GetGameTimer()
end

-- Calculate publish interval based on speed
function Telemetry.publishInterval(kph, config)
    config = config or (Config and Config.TireWear)
    if not config or not config.publish then
        return 1200 -- Default fallback
    end
    return (kph >= 10.0) and config.publish.driving_ms or config.publish.slow_ms
end

-- Collect telemetry data for current frame
-- Returns: telemetry data table or nil if not in vehicle
function Telemetry.collect(veh)
    if not veh or veh == 0 then
        return nil
    end

    local pos = GetEntityCoords(veh)
    local kph = GetEntitySpeed(veh) * 3.6
    local off = not IsPointOnRoad(pos.x, pos.y, pos.z, veh)
    local vehClass = GetVehicleClass(veh) -- Client-side only, will be sent with telemetry
    
    -- Get vehicle handling properties (client-side only)
    local mass = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fMass')
    local brakeForce = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeForce')
    local brakeBiasFront = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fBrakeBiasFront')

    -- Distance integration
    local d = 0.0
    if last.pos then
        d = #(pos - last.pos)
    end
    acc.d_m = acc.d_m + d
    acc.kph10 = math.floor(kph * 10 + 0.5)

    -- Hard brake detection
    local brakePressed = IsControlPressed(0, 72) -- Brake control
    local config = Config and Config.TireWear
    local hardBrakeDrop = (config and config.publish and config.publish.hard_brake_drop_kph) or 25
    if brakePressed and kph < (last.kph or kph) - hardBrakeDrop then
        local maxHb = (config and config.limits and config.limits.max_hb) or 5
        acc.hb = math.min(acc.hb + 1, maxHb)
    end

    -- Off-road flag
    acc.off = off and 1 or 0

    -- Brake usage tracking (accumulate seconds)
    local tickMs = (config and config.tick and config.tick.driving_ms) or 1000
    local tickSeconds = tickMs / 1000.0
    if brakePressed then
        acc.brake_sec = acc.brake_sec + tickSeconds
    end

    -- Handbrake usage tracking
    local handbrakePressed = IsControlPressed(0, 76) -- Handbrake control
    if handbrakePressed then
        acc.handbrake_sec = acc.handbrake_sec + tickSeconds
    end

    -- Deceleration rate (kph per second)
    if last.kph and last.ts then
        local timeDelta = (now() - last.ts) / 1000.0 -- Convert to seconds
        if timeDelta > 0 then
            local speedDelta = last.kph - kph
            if speedDelta > 0 then -- Only positive deceleration
                acc.decel_kph = speedDelta / timeDelta
            end
        end
    end

    -- Update last values
    last.pos = pos
    last.kph = kph
    last.brake_pressed = brakePressed
    last.handbrake_pressed = handbrakePressed
    last.veh_class = vehClass -- Store vehicle class
    last.mass = mass -- Store vehicle mass
    last.brake_force = brakeForce -- Store brake force
    last.brake_bias_front = brakeBiasFront -- Store brake bias

    return {
        d_m = acc.d_m,
        kph10 = acc.kph10,
        hb = acc.hb,
        off = acc.off,
        brake_sec = acc.brake_sec,
        handbrake_sec = acc.handbrake_sec,
        decel_kph = acc.decel_kph,
        veh_class = vehClass,
        mass = mass,
        brake_force = brakeForce,
        brake_bias_front = brakeBiasFront
    }
end

-- Check if telemetry should be published
function Telemetry.shouldPublish(kph, config)
    config = config or (Config and Config.TireWear)
    local ts = now()
    local timeSinceLastPublish = ts - (last.ts or 0)
    local interval = Telemetry.publishInterval(kph, config)
    local minDist = (config and config.publish and config.publish.min_dist_m) or 150
    
    return (timeSinceLastPublish >= interval) or (acc.d_m >= minDist)
end

-- Publish telemetry to state bag
function Telemetry.publish(stateBagKey, config)
    config = config or (Config and Config.TireWear)
    if not stateBagKey then
        stateBagKey = (config and config.net and config.net.telemKey) or "ns_telem"
    end

    local limits = (config and config.limits) or {}
    local telemData = {
        d_m = math.min(acc.d_m, limits.max_dm or 2000),
        kph10 = math.min(acc.kph10, (limits.max_kph or 300) * 10),
        hb = acc.hb,
        off = acc.off,
        brake_sec = acc.brake_sec,
        handbrake_sec = acc.handbrake_sec,
        decel_kph = acc.decel_kph,
        veh_class = last.veh_class, -- Include vehicle class in published data
        mass = last.mass, -- Include vehicle mass
        brake_force = last.brake_force, -- Include brake force
        brake_bias_front = last.brake_bias_front -- Include brake bias
    }

    LocalPlayer.state:set(stateBagKey, telemData, true)

    -- Reset accumulator (keep off flag)
    acc = { d_m = 0, kph10 = 0, hb = 0, off = acc.off, brake_sec = 0, handbrake_sec = 0, decel_kph = 0 }
    last.ts = now()

    return telemData
end

-- Reset telemetry state (useful for cleanup)
function Telemetry.reset()
    acc = { d_m = 0, kph10 = 0, hb = 0, off = 0, brake_sec = 0, handbrake_sec = 0, decel_kph = 0 }
    last = { 
        pos = nil, 
        kph = 0, 
        ts = 0, 
        brake_pressed = false, 
        handbrake_pressed = false, 
        veh_class = nil,
        mass = nil,
        brake_force = nil,
        brake_bias_front = nil
    }
end

-- Get current accumulator state (for debugging)
function Telemetry.getAccumulator()
    return acc
end