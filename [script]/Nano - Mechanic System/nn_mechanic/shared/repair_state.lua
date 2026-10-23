function CreateRepairState()
    return {
        lift = {
            isAttached = false,
            liftIndex = nil,
            vehicleNetId = nil,
            height = nil,
            isMoving = false,
            position = 'down'
        },
        hood = {
            isOpen = false,
            openedBy = nil
        },
        oilChange = {
            inProgress = false,
            requiredOilType = nil,
            instructionStates = {},
            bucketPlaced = false,
            oilBoltOpen = false,
            oilDraining = false,
            particleActive = false
        },
        wheelInstall = {
            inProgress = false,
            wheelIndex = nil,
            boneName = nil,
            alignmentInProgress = false,
            tireData = nil
        },
        brakes = {
            inProgress = false,
            axis = nil, -- 'front' or 'rear'
            requiredPadType = nil,
            instructionStates = {},
            wheelsRemoved = false,
            padsInstalled = false,
            wheelsReinstalled = false,
            removedWheelSides = {},    -- { left = bool, right = bool }
            reinstalledWheelSides = {}, -- { left = bool, right = bool }
            frontWheelOffsets = nil,   -- { wheel_lf = x, wheel_rf = x }
            rearWheelOffsets = nil,    -- { wheel_lr = x, wheel_rr = x }
            frontWheelBonePositions = nil,  -- { wheel_lf = {x,y,z}, wheel_rf = {x,y,z} }
            rearWheelBonePositions = nil    -- { wheel_lr = {x,y,z}, wheel_rr = {x,y,z} }
        },
        repairs = {
            exhaust = { inProgress = false, step = nil },
            engine = { inProgress = false, step = nil }
        },
        menus = {
            oilBoltMenu = false,
            refillOilMenu = false,
            serviceMenu = false,
            instructionsVisible = false,
            brakePadMenu = false
        }
    }
end

function MergeRepairState(currentState, updates)
    if not currentState then
        currentState = CreateRepairState()
    end
    
    if not updates then
        return currentState
    end
    
    for section, sectionUpdates in pairs(updates) do
        if type(sectionUpdates) == "table" then
            if not currentState[section] then
                currentState[section] = {}
            end
            
            if section == "repairs" then
                if not currentState.repairs then
                    currentState.repairs = {}
                end
                for repairType, repairData in pairs(sectionUpdates) do
                    if not currentState.repairs[repairType] then
                        currentState.repairs[repairType] = {}
                    end
                    for key, value in pairs(repairData) do
                        currentState.repairs[repairType][key] = value
                    end
                end
            else
                for key, value in pairs(sectionUpdates) do
                    -- Handle simple tables that should be merged key by key
                    if key == "instructionStates" or key == "removedWheelSides" or key == "reinstalledWheelSides" then
                        if type(value) == "table" then
                            if not currentState[section][key] then
                                currentState[section][key] = {}
                            end
                            for k, v in pairs(value) do
                                currentState[section][key][k] = v
                            end
                        else
                            currentState[section][key] = value
                        end
                    -- Handle tables that should be replaced entirely (bone positions, offsets)
                    elseif key == "frontWheelBonePositions" or key == "rearWheelBonePositions" or key == "frontWheelOffsets" or key == "rearWheelOffsets" then
                        currentState[section][key] = value
                    elseif type(value) ~= "table" then
                        currentState[section][key] = value
                    elseif type(currentState[section][key]) == "table" then
                        currentState[section][key] = MergeRepairState(currentState[section][key], value)
                    else
                        currentState[section][key] = value
                    end
                end
            end
        else
            currentState[section] = sectionUpdates
        end
    end
    
    return currentState
end

function DebugRepairState(ctx)
    if not ctx or not ctx.repairState then
        print("No repair state")
        return
    end
    
    if json then
        print(json.encode(ctx.repairState, {indent = true}))
    else
        print("Repair State:")
        print("  Lift: attached=" .. tostring(ctx.repairState.lift.isAttached) .. 
              ", index=" .. tostring(ctx.repairState.lift.liftIndex) .. 
              ", moving=" .. tostring(ctx.repairState.lift.isMoving) .. 
              ", position=" .. tostring(ctx.repairState.lift.position))
        print("  Hood: open=" .. tostring(ctx.repairState.hood.isOpen))
        print("  Oil Change: inProgress=" .. tostring(ctx.repairState.oilChange.inProgress))
        print("  Wheel Install: inProgress=" .. tostring(ctx.repairState.wheelInstall.inProgress))
    end
end