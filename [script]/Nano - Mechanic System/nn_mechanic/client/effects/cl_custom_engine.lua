local function applyEngineCustomization(vehicle, customData)
    if not (vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)) then
        return
    end

    local handlingConfig = customData and customData.handling

    if not handlingConfig or not handlingConfig.values or type(handlingConfig.values) ~= "table" then
        return
    end

    local mode = handlingConfig.mode or "set"
    local values = handlingConfig.values

    local enginePowerState = nil
    if EnsureEnginePowerState then
        enginePowerState = EnsureEnginePowerState(vehicle)
    end

    for property, value in pairs(values) do
        if type(value) == "number" and type(property) == "string" then
            local effectiveValue = value

            if mode == "difference" then
                local stockValue = 0.0
                if property == "fInitialDriveForce" then
                    if enginePowerState and enginePowerState.stock then
                        stockValue = enginePowerState.stock
                    else
                        stockValue = GetVehicleHandlingFloat(vehicle, "CHandlingData", property) or 0.0
                    end
                elseif property == "fDriveInertia" then
                    if enginePowerState and enginePowerState.stockInertia then
                        stockValue = enginePowerState.stockInertia
                    else
                        stockValue = GetVehicleHandlingFloat(vehicle, "CHandlingData", property) or 0.0
                    end
                else
                    stockValue = GetVehicleHandlingFloat(vehicle, "CHandlingData", property) or 0.0
                end
                effectiveValue = stockValue + value
            end

            if property == "fInitialDriveForce" then
                if SetCustomEnginePower then
                    SetCustomEnginePower(vehicle, effectiveValue)
                else
                    SetVehicleHandlingFloat(vehicle, "CHandlingData", property, effectiveValue)
                end
            elseif property == "fDriveInertia" then
                if SetCustomEngineInertia then
                    SetCustomEngineInertia(vehicle, effectiveValue)
                else
                    SetVehicleHandlingFloat(vehicle, "CHandlingData", property, effectiveValue)
                end
            else
                SetVehicleHandlingFloat(vehicle, "CHandlingData", property, effectiveValue)
            end
        end
    end

    ModifyVehicleTopSpeed(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 0.0)
end

local function onEngineStateBagChange(stateBagName, propertyName, newValue)
    local vehicleEntity = GetEntityFromStateBagName(stateBagName)

    if not (vehicleEntity and vehicleEntity ~= 0 and DoesEntityExist(vehicleEntity)) then
        return
    end

    if GetEntityType(vehicleEntity) ~= 2 then
        return
    end

    if newValue then
        if type(newValue) == "string" then
            local engineConfig = nil
            if Config and Config.EngineSwap and Config.EngineSwap.engines then
                engineConfig = Config.EngineSwap.engines[newValue]
            end

            if not engineConfig then
                return
            end

            while not HasCollisionLoadedAroundEntity(vehicleEntity) do
                if not DoesEntityExist(vehicleEntity) then
                    return
                end
                Wait(100)
            end

            applyEngineCustomization(vehicleEntity, engineConfig)

            if engineConfig.audio and engineConfig.audio.preset and type(engineConfig.audio.preset) == "string" then
                ForceUseAudioGameObject(vehicleEntity, engineConfig.audio.preset)
            end
        end
    else
        if ClearCustomEnginePower then
            ClearCustomEnginePower(vehicleEntity)
        end
        if ClearCustomEngineInertia then
            ClearCustomEngineInertia(vehicleEntity)
        end
    end
end

AddStateBagChangeHandler("nn_custom_engine", nil, onEngineStateBagChange)