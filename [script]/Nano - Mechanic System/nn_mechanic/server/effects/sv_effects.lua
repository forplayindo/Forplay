local vehicleTireCache = {}

function GetTireData(netId)
    if not vehicleTireCache[netId] then
        vehicleTireCache[netId] = {
            psi = {},
            tr = {}
        }
    end
    return vehicleTireCache[netId]
end

function UpdateTireState(netId, stateBagName, value)
    local tireData = GetTireData(netId)
    
    local psiMatch = stateBagName:match("ns_psi(%d+)")
    local trMatch = stateBagName:match("ns_tr(%d+)")
    
    if psiMatch then
        local wheelIndex = tonumber(psiMatch)
        tireData.psi[wheelIndex] = value
    elseif trMatch then
        local wheelIndex = tonumber(trMatch)
        tireData.tr[wheelIndex] = value
    end
end

local tractionBaselineCache = {}

function GetBaselineTraction(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return nil
    end
    
    local stateBagKey = ("entity:%d"):format(netId)
    local baseMin = GetStateBagValue(stateBagKey, "ns_base_traction_min")
    local baseMax = GetStateBagValue(stateBagKey, "ns_base_traction_max")
    
    if baseMin and baseMax then
        tractionBaselineCache[netId] = {min = baseMin, max = baseMax}
        return tractionBaselineCache[netId]
    end
    
    if tractionBaselineCache[netId] then
        return tractionBaselineCache[netId]
    end
    
    local handlingMin = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin")
    local handlingMax = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    
    if handlingMin and handlingMin > 0 and handlingMax and handlingMax > 0 then
        tractionBaselineCache[netId] = {min = handlingMin, max = handlingMax}
        return tractionBaselineCache[netId]
    end
    
    return nil
end

-- Capture vehicle baseline handling data
function CaptureBaseline(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        return
    end
    
    local baseline = {
        tractionMin = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin"),
        tractionMax = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax"),
        brakeForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce"),
        enginePower = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce"),
        driveInertia = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia")
    }
    
    TriggerServerEvent("nn_mechanic:capturedBaseline", netId, baseline)
end

-- Register baseline capture event
RegisterNetEvent("nn_mechanic:captureBaseline")
AddEventHandler("nn_mechanic:captureBaseline", function(netId)
    local vehicle = NetToVeh(netId)
    if vehicle == 0 then
        SetTimeout(100, function()
            vehicle = NetToVeh(netId)
            if vehicle ~= 0 then
                CaptureBaseline(vehicle)
            end
        end)
        return
    end
    CaptureBaseline(vehicle)
end)

-- Apply traction multiplier to vehicle
function ApplyTractionMultiplier(vehicle, multiplier)
    local baseline = GetBaselineTraction(vehicle)
    if not baseline then
        return false
    end
    
    local config = Config.TireWear.handling.traction
    local clampedMultiplier = clamp(multiplier, config.curveMin.minScale, config.curveMin.maxScale)
    
    local newMin = baseline.min * clampedMultiplier
    local newMax = baseline.max * clampedMultiplier
    
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMin", newMin)
    SetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax", newMax)
    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 0.0)
    
    return true
end

-- Calculate tire wear multiplier based on pressure and tread
function CalculateTireMultiplier(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local stateBagKey = ("entity:%d"):format(netId)
    local vehicleClass = GetVehicleClass(vehicle)
    
    local wheelIndices = GetWheelIndicesForClass(vehicleClass)
    local tireData = GetTireData(netId)
    
    local pressures = {}
    local treads = {}
    
    for _, wheelIndex in ipairs(wheelIndices) do
        -- Get pressure
        local pressure = tireData.psi[wheelIndex]
        if not pressure then
            pressure = GetStateBagValue(stateBagKey, ("ns_psi%d"):format(wheelIndex))
        end
        pressures[wheelIndex] = (pressure and pressure / 10.0) or Config.TireWear.defaults.pressure
        
        -- Get tread
        local tread = tireData.tr[wheelIndex]
        if not tread then
            tread = GetStateBagValue(stateBagKey, ("ns_tr%d"):format(wheelIndex))
        end
        treads[wheelIndex] = (tread and tread / 100.0) or Config.TireWear.defaults.tread
    end
    
    -- Get active profile
    local defaultProfile = Config.TireWear.profiles[Config.TireWear.defaultProfile]
    local penalties = defaultProfile.penalties
    
    -- Calculate penalty for a single tire
    local function CalculatePenalty(pressure, tread)
        local pressurePenalty = math.max(0.0, (defaultProfile.pressure.POPT - pressure) / penalties.pressure.denom)
        pressurePenalty = math.min(pressurePenalty, penalties.pressure.cap)
        
        local treadPenalty = math.max(0.0, (100.0 - tread) / penalties.tread.denom)
        treadPenalty = math.min(treadPenalty, penalties.tread.cap)
        
        return 1.0 - math.max(pressurePenalty, treadPenalty)
    end
    
    -- Find worst tire multiplier
    local worstMultiplier = math.huge
    for _, wheelIndex in ipairs(wheelIndices) do
        local multiplier = CalculatePenalty(pressures[wheelIndex], treads[wheelIndex])
        worstMultiplier = math.min(worstMultiplier, multiplier)
    end
    
    if worstMultiplier == math.huge then
        worstMultiplier = 1.0
    end
    
    return worstMultiplier, pressures, treads
end

-- Burst a specific tire
function BurstTire(stateBagName, wheelIndex)
    local netId = tonumber(stateBagName:match("entity:(%d+)"))
    if not netId then
        return
    end
    
    local vehicle = NetToVeh(netId)
    if vehicle == 0 then
        return
    end
    
    SetVehicleTyreBurst(vehicle, wheelIndex, true, 1000.0)
end

-- Register burst handlers for all wheels
local wheelIndices = {0, 1, 2, 3, 4}
for _, wheelIndex in ipairs(wheelIndices) do
    AddStateBagChangeHandler(("ns_burst%d"):format(wheelIndex), nil, function(stateBagName, _, value)
        if value == 1 then
            BurstTire(stateBagName, wheelIndex)
        end
    end)
end

function HandleTireStateUpdate(stateBagName, key, value)
    local netId = tonumber(stateBagName:match("entity:(%d+)"))
    if not netId then
        return
    end
    
    UpdateTireState(netId, key, value)
    
    local vehicle = NetToVeh(netId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        local multiplier = CalculateTireMultiplier(vehicle)
        ApplyTractionMultiplier(vehicle, multiplier)
    end
end

local wheelIndices = {0, 1, 2, 3, 4}
for _, wheelIndex in ipairs(wheelIndices) do
    AddStateBagChangeHandler(("ns_psi%d"):format(wheelIndex), nil, HandleTireStateUpdate)
    AddStateBagChangeHandler(("ns_tr%d"):format(wheelIndex), nil, HandleTireStateUpdate)
end