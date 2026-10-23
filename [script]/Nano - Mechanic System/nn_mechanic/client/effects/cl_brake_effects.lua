local clamp
local getBrakeState
local calculateBrakeForceMultiplier
local vehicleBrakeForceCache = {}
local getBaseBrakeForce
local setVehicleBrakeForce

-- Utility function
function clamp(value, minVal, maxVal)
    if value < minVal then
        return minVal
    elseif maxVal < value then
        return maxVal
    else
        return value
    end
end

-- Get brake state from state bags
function getBrakeState(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        return nil
    end

    local stateBagKey = ("entity:%d"):format(netId)
    local frontBrake = GetStateBagValue(stateBagKey, "ns_brake_front")
    local rearBrake = GetStateBagValue(stateBagKey, "ns_brake_rear")
    local brakeHeat = GetStateBagValue(stateBagKey, "ns_brake_heat")

    if not (frontBrake and rearBrake) or not brakeHeat then
        return nil
    end

    return {
        front = frontBrake / 100.0,
        rear = rearBrake / 100.0,
        heat = brakeHeat
    }
end

-- Calculate brake force multiplier based on pad wear and heat
function calculateBrakeForceMultiplier(vehicle)
    local brakeState = getBrakeState(vehicle)
    if not brakeState then
        return 1.0
    end

    local defaultProfile = Config.BrakeWear.profiles[Config.BrakeWear.defaultProfile]
    if not defaultProfile then
        return 1.0
    end

    local vehicleClass = GetVehicleClass(vehicle)
    local classProfileName = Config.BrakeWear.vehicleClassProfiles[vehicleClass] or "SemiMetallic"
    local activeProfile = Config.BrakeWear.profiles[classProfileName] or defaultProfile

    -- Pad health penalty (wear)
    local minPadHealth = math.min(brakeState.front, brakeState.rear)
    local padHealthPenalty = math.min(
        math.max(0.0, 100.0 - minPadHealth) / activeProfile.penalties.padHealth.denom,
        activeProfile.penalties.padHealth.cap
    )

    -- Heat fade penalty
    local heatFadePenalty = 0.0
    if brakeState.heat > activeProfile.heat.FADE_THRESHOLD then
        local heatFactor = (brakeState.heat - activeProfile.heat.FADE_THRESHOLD) / activeProfile.heat.FADE_RANGE
        heatFactor = clamp(heatFactor, 0.0, 1.0)
        heatFadePenalty = heatFactor * activeProfile.penalties.heatFade.cap
    end

    local totalPenalty = math.max(padHealthPenalty, heatFadePenalty)
    local multiplier = 1.0 - totalPenalty
    
    return clamp(multiplier, 0.0, 1.0)
end

-- Get base brake force from cache or handling
function getBaseBrakeForce(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil
    end

    local stateBagKey = ("entity:%d"):format(netId)
    local baseForceFromStateBag = GetStateBagValue(stateBagKey, "ns_base_brake_force")
    if baseForceFromStateBag and baseForceFromStateBag > 0 then
        return baseForceFromStateBag
    end

    local cachedForce = vehicleBrakeForceCache[netId]
    if cachedForce then
        return cachedForce
    end

    local handlingForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
    if handlingForce and handlingForce > 0 then
        vehicleBrakeForceCache[netId] = handlingForce
        return handlingForce
    end
    
    return nil
end

-- Apply modified brake force to vehicle
function setVehicleBrakeForce(vehicle, multiplier)
    if not vehicle or vehicle == 0 then
        return false
    end

    local baseForce = getBaseBrakeForce(vehicle)
    if not baseForce or baseForce <= 0 then
        return false
    end

    local newBrakeForce = baseForce * multiplier
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce", newBrakeForce)
    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 0.0)
    
    return true
end

-- Clean up cache when vehicle is removed
AddEventHandler("entityRemoved", function(entityNetId)
    if GetEntityType(entityNetId) == 2 then
        local entityId = NetworkGetEntityFromNetworkId(entityNetId)
        if entityId and entityId ~= 0 then
            vehicleBrakeForceCache[entityId] = nil
        end
    end
end)

-- Update brake force when state bag changes
local function onBrakeStateChange(stateBagName)
    local netIdStr = stateBagName:match("entity:(%d+)")
    local netId = tonumber(netIdStr)
    if not netId then
        return
    end

    local vehicleId = NetToVeh(netId)
    if vehicleId ~= 0 and DoesEntityExist(vehicleId) then
        local baseForce = getBaseBrakeForce(vehicleId)
        if baseForce then
            local multiplier = calculateBrakeForceMultiplier(vehicleId)
            setVehicleBrakeForce(vehicleId, multiplier)
        end
    end
end

-- Register state bag change handlers
AddStateBagChangeHandler("ns_brake_front", nil, onBrakeStateChange)
AddStateBagChangeHandler("ns_brake_rear", nil, onBrakeStateChange)
AddStateBagChangeHandler("ns_brake_heat", nil, onBrakeStateChange)