-- OBD Tablet System for Mechanic Job
-- Handles vehicle diagnostics, fault detection, and repair procedures

local bridge = exports.community_bridge.Bridge()

-- Module state
local state = {
    vehicle = nil,
    vehicleNetId = nil,
    repairHistory = nil
}

-- Helper: Get band configuration for a given health value
local function getBandForHealth(health, bandType)
    local repairConfig = Data.RepairConfig
    if not repairConfig or not repairConfig.Bands then
        return nil
    end
    
    local bands = repairConfig.Bands[bandType]
    if not bands then
        return nil
    end
    
    for _, band in ipairs(bands) do
        if health >= band.min and health <= band.max then
            return band
        end
    end
    
    return bands[#bands]
end

-- Helper: Get diagnosis faults for a given health band
local function getDiagnosisFaults(bandId, componentType)
    local repairConfig = Data.RepairConfig
    if not repairConfig or not repairConfig.Diagnosis then
        return {}
    end
    
    local diagnosis = repairConfig.Diagnosis[componentType]
    if not diagnosis then
        return {}
    end
    
    local faults = diagnosis[bandId]
    if not faults then
        return {}
    end
    
    -- Get random diagnosis lines configuration
    local diagLines = Data.RepairConfig.DiagnosisLines
    if not diagLines then
        diagLines = { min = 1, max = 3 }
    end
    
    -- Determine number of faults to show
    local numFaults = math.random(diagLines.min, math.min(diagLines.max, #faults))
    
    -- Shuffle faults
    local shuffledFaults = {}
    for i, fault in ipairs(faults) do
        shuffledFaults[i] = fault
    end
    
    for i = #shuffledFaults, 2, -1 do
        local j = math.random(i)
        shuffledFaults[i], shuffledFaults[j] = shuffledFaults[j], shuffledFaults[i]
    end
    
    -- Return only the selected number of faults
    local result = {}
    for i = 1, numFaults do
        result[i] = shuffledFaults[i]
    end
    
    return result
end

-- Helper: Get repair procedures for a given component and band
local function getRepairProcedures(bandId, componentType)
    local procedures = Data.RepairConfig and Data.RepairConfig.Procedures
    if not procedures then
        return {}
    end
    
    local availableProcedures = {}
    
    for procId, procedure in pairs(procedures) do
        if procedure.targets == componentType then
            local allowedBands = procedure.allowedBands or {}
            
            for _, allowedBand in ipairs(allowedBands) do
                if allowedBand == bandId then
                    table.insert(availableProcedures, {
                        id = procedure.id or procId,
                        label = procedure.label,
                        description = procedure.description,
                        requirements = procedure.requirements or {},
                        items = procedure.items or {},
                        stepCount = procedure.steps and #procedure.steps or 0
                    })
                    break
                end
            end
        end
    end
    
    return availableProcedures
end

-- Helper: Build repair diagnostics data
local function buildRepairDiagnostics(engineHealth, bodyHealth)
    local engineBand = getBandForHealth(engineHealth, "Engine")
    local bodyBand = getBandForHealth(bodyHealth, "Body")
    
    local engineFaults = {}
    local engineProcedures = {}
    local bodyFaults = {}
    local bodyProcedures = {}
    
    if engineBand then
        engineFaults = getDiagnosisFaults(engineBand.id, "Engine")
        engineProcedures = getRepairProcedures(engineBand.id, "engine")
    end
    
    if bodyBand then
        bodyFaults = getDiagnosisFaults(bodyBand.id, "Body")
        bodyProcedures = getRepairProcedures(bodyBand.id, "body")
    end
    
    local requirementLabels = (Data.RepairConfig and Data.RepairConfig.RequirementLabels) or {}
    
    return {
        engine = {
            health = engineHealth,
            bandId = engineBand and engineBand.id or "unknown",
            bandLabel = engineBand and engineBand.label or "Unknown",
            faults = engineFaults,
            procedures = engineProcedures
        },
        body = {
            health = bodyHealth,
            bandId = bodyBand and bodyBand.id or "unknown",
            bandLabel = bodyBand and bodyBand.label or "Unknown",
            faults = bodyFaults,
            procedures = bodyProcedures
        },
        requirementLabels = requirementLabels
    }
end

-- Refresh OBD data from vehicle state bags
function RefreshOBDData()
    if not state.vehicle or not DoesEntityExist(state.vehicle) then
        return
    end
    
    local netId = NetworkGetNetworkIdFromEntity(state.vehicle)
    local stateBagKey = string.format("entity:%d", netId)
    local vehicleClass = GetVehicleClass(state.vehicle)
    local wheelIndices = GetWheelIndicesForClass(vehicleClass)
    
    -- Tire pressure data
    local tirePressures = {}
    local totalPressure = 0.0
    local wheelCount = #wheelIndices
    
    for idx, wheelIndex in ipairs(wheelIndices) do
        local pressure = GetStateBagValue(stateBagKey, string.format("ns_psi%d", wheelIndex))
        tirePressures[idx] = (pressure and pressure / 10.0) or 32.0
        totalPressure = totalPressure + tirePressures[idx]
    end
    
    local avgPressure = totalPressure / wheelCount
    
    -- Brake data
    local brakeFront = GetStateBagValue(stateBagKey, "ns_brake_front")
    local brakeRear = GetStateBagValue(stateBagKey, "ns_brake_rear")
    local brakeHeat = GetStateBagValue(stateBagKey, "ns_brake_heat")
    
    local brakeFrontHealth = brakeFront and brakeFront / 100.0 or 100.0
    local brakeRearHealth = brakeRear and brakeRear / 100.0 or 100.0
    local brakeTemperature = brakeHeat or 0.0
    local avgBrakeHealth = (brakeFrontHealth + brakeRearHealth) / 2.0
    
    -- Oil data
    local oilQuality = GetStateBagValue(stateBagKey, "ns_oil_quality")
    local oilQualityPercent = oilQuality and oilQuality / 100.0 or 100.0
    local oilLastChangeKm = 0.0
    
    -- Vehicle health
    local engineHealth = GetVehicleEngineHealth(state.vehicle)
    local bodyHealth = GetVehicleBodyHealth(state.vehicle)
    
    -- Vehicle information
    local vehicleInfo = {
        model = GetEntityModel(state.vehicle),
        displayName = GetDisplayNameFromVehicleModel(GetEntityModel(state.vehicle)),
        plate = GetVehicleNumberPlateText(state.vehicle),
        vin = GenerateVehicleVin(GetEntityModel(state.vehicle), GetVehicleNumberPlateText(state.vehicle)),
        engineHealth = engineHealth / 10.0,
        bodyHealth = bodyHealth / 10.0,
        tankHealth = GetVehiclePetrolTankHealth(state.vehicle) / 10.0,
        fuelLevel = GetVehicleFuelLevel(state.vehicle),
        oilLevel = oilQualityPercent,
        tires = {
            pressure = tirePressures,
            averagePressure = avgPressure
        },
        brakes = {
            front = brakeFrontHealth,
            rear = brakeRearHealth,
            heat = brakeTemperature,
            averageHealth = avgBrakeHealth
        },
        oil = {
            quality = oilQualityPercent,
            lastChangeKm = oilLastChangeKm
        },
        repair = buildRepairDiagnostics(engineHealth, bodyHealth),
        repairHistory = state.repairHistory or {}
    }
    
    SendNUIMessage({
        action = "setVehicleData",
        data = vehicleInfo
    })
end

-- Fetch repair history for the current vehicle
local function fetchRepairHistory()
    if not state.vehicle or not DoesEntityExist(state.vehicle) then
        return
    end
    
    local plate = GetVehicleNumberPlateText(state.vehicle)
    local vin = GenerateVehicleVin(GetEntityModel(state.vehicle), plate)
    
    local history = bridge.Callback.Trigger("nn_mechanic:getRepairHistory", plate, vin, 20)
    state.repairHistory = history or {}
    
    RefreshOBDData()
end

-- Register NUI callbacks and events
RegisterNetEvent("nn_mechanic:openOBDTablet", function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    
    if not DoesEntityExist(vehicle) then
        bridge.Notify.SendNotify(t("not_in_vehicle"), "error")
        return
    end
    
    state.vehicle = vehicle
    state.vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    state.repairHistory = {}
    
    RefreshOBDData()
    
    -- Start refresh loop
    Citizen.CreateThread(function()
        while state.vehicle do
            RefreshOBDData()
            Citizen.Wait(1000)
        end
    end)
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "diagnostic",
            action = "setVisible"
        }
    })
    
    SetNuiFocus(true, true)
    TriggerScreenblurFadeIn(500)
    DisplayRadar(false)
    
    State.openPage = "diagnostic"
end)

-- NUI: Start repair procedure
RegisterNUICallback("obd:startRepair", function(data, cb)
    if not data.procedureId then
        cb({ success = false, error = "No procedure specified" })
        return
    end
    
    if not state.vehicle or not DoesEntityExist(state.vehicle) then
        cb({ success = false, error = "No vehicle" })
        return
    end
    
    local success, errorMsg = StartObdRepair(state.vehicle, data.procedureId)
    cb({ success = success, error = errorMsg })
end)

-- NUI: Close OBD tablet
RegisterNUICallback("obd:close", function(_, cb)
    SetNuiFocus(false, false)
    TriggerScreenblurFadeOut(500)
    DisplayRadar(true)
    
    State.openPage = nil
    state.vehicle = nil
    state.vehicleNetId = nil
    
    cb({ success = true })
end)

-- Export: Get current OBD vehicle
function GetOBDVehicle()
    return state.vehicle
end