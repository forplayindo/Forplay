function dprint(...)
    print("^2[nn_mechanic]^7 " .. ...)
end

local function isNaN(x)
    return type(x) == "number" and x ~= x
end

-- RapidJSON (SendNUIMessage / NUI callback responses) cannot encode NaN/Inf.
-- Strip them recursively from any payload sourced from the DB before handing
-- it to the UI.
function sanitizeForNui(value, visited)
    local tValue = type(value)

    if tValue == "number" then
        if isNaN(value) or value == math.huge or value == -math.huge then
            return nil
        end
        return value
    end

    if tValue ~= "table" then
        return value
    end

    visited = visited or {}
    if visited[value] then
        return nil
    end
    visited[value] = true

    local out = {}
    for k, v in pairs(value) do
        local newV = sanitizeForNui(v, visited)
        if newV ~= nil then
            out[k] = newV
        end
    end

    visited[value] = nil
    return out
end

function roundCoords(coords)
    return {
        x = math.floor(coords.x * 100 + 0.5) / 100,
        y = math.floor(coords.y * 100 + 0.5) / 100,
        z = math.floor(coords.z * 100 + 0.5) / 100
    }
end

function getClosestPlayer(playerId)
    local closestPlayer = nil
    local closestDistance = nil
    for _, player in pairs(GetPlayers()) do
        if tonumber(player) ~= tonumber(playerId) then
            local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(player)))
            local distance = #(playerCoords - GetEntityCoords(GetPlayerPed(tonumber(playerId))))
            if closestDistance == nil or distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestDistance, closestPlayer
end

local VehicleClass = {
    Compacts = 0,
    Sedans = 1,
    SUVs = 2,
    Coupes = 3,
    Muscle = 4,
    SportsClassics = 5,
    Sports = 6,
    Super = 7,
    Motorcycles = 8,
    OffRoad = 9,
    Industrial = 10,
    Utility = 11,
    Vans = 12,
    Cycles = 13,
    Boats = 14,
    Helicopters = 15,
    Planes = 16,
    Service = 17,
    Emergency = 18,
    Military = 19,
    Commercial = 20,
    Trains = 21,
    OpenWheels = 22,
}

local WheelType = {
    Sport = 0,
    Muscle = 1,
    Lowrider = 2,
    SUV = 3,
    Offroad = 4,
    Tuner = 5,
    Bike = 6,
    HighEnd = 7,
    BennysOriginal = 8,
    BennysBespoke = 9,
    OpenWheel = 10,
    Street = 11,
    Track = 12,
}

function isWheelTypeAllowed(wheelType, vehicle)
    local class = GetVehicleClass(vehicle)
    if class == VehicleClass.Cycles then return false end

    if class == VehicleClass.Motorcycles then
        if wheelType == WheelType.Bike then
            return true
        end
        return false
    end

    if class == VehicleClass.OpenWheels then
        if wheelType == WheelType.OpenWheel then
            return true
        end
        return false
    end
    return true
end


-- DRAG CAM

local angleY = 0.0
local angleZ = 0.0
local cam = nil
local running = false
local gEntity = nil
local gRadius = nil
local gRadiusMax = nil
local gRadiusMin = nil
local scaleform = nil
local scrollIncrements = nil
local isFirstPersonView = false

local function cos(degrees)
    return math.cos(math.rad(degrees))
end

local function sin(degrees)
    return math.sin(math.rad(degrees))
end

local function setCamPosition()
    local entityCoords = GetEntityCoords(gEntity)
    local mouseX = GetDisabledControlNormal(0, 1) * 8.0 -- 8x multiplier to make it more sensitive
    local mouseY = GetDisabledControlNormal(0, 2) * 8.0

    angleZ = angleZ - mouseX -- left / right
    angleY = angleY + mouseY -- up / down
    angleY = bridge.Math.Clamp(angleY, 0.0, 89.0) -- >=90 degrees will flip the camera, < 0 is underground

    local cosAngleZ = cos(angleZ)
    local cosAngleY = cos(angleY)
    local sinAngleZ = sin(angleZ)
    local sinAngleY = sin(angleY)

    local offset = vec3(
        ((cosAngleZ * cosAngleY) + (cosAngleY * cosAngleZ)) / 2 * gRadius,
        ((sinAngleZ * cosAngleY) + (cosAngleY * sinAngleZ)) / 2 * gRadius,
        ((sinAngleY)) * gRadius
    )

    local camPos = vec3(entityCoords.x + offset.x, entityCoords.y + offset.y, entityCoords.z + offset.z)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, entityCoords.x, entityCoords.y, entityCoords.z + 0.5)
end

local function disablePlayerMovement()
    DisableControlAction(0, 14, true) -- INPUT_SPRINT | LEFT SHIFT
    DisableControlAction(0, 15, true) -- INPUT_SPRINT | LEFT SHIFT
    DisableControlAction(0, 21, true) -- INPUT_SPRINT | LEFT SHIFT
    DisableControlAction(0, 24, true) -- INPUT_ATTACK | LEFT MOUSE BUTTON
    DisableControlAction(0, 25, true) -- INPUT_AIM | RIGHT MOUSE BUTTON
    DisableControlAction(0, 30, true) -- INPUT_MOVE_LR | D
    DisableControlAction(0, 31, true) -- INPUT_MOVE_UD | S
    DisableControlAction(0, 36, true) -- INPUT_DUCK | LEFT CTRL
    DisableControlAction(0, 47, true) -- INPUT_DETONATE | G
    DisableControlAction(0, 58, true) -- INPUT_THROW_GRENADE | G
    DisableControlAction(0, 69, true) -- INPUT_VEH_ATTACK | LEFT MOUSE BUTTON
    DisableControlAction(0, 75, true) -- INPUT_VEH_EXIT | F
    DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT | R
    DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY | Q
    DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE | LEFT MOUSE BUTTON
    DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK | SPACEBAR
    DisableControlAction(0, 257, true) -- INPUT_ATTACK2 | LEFT MOUSE BUTTON
    DisableControlAction(0, 263, true) -- INPUT_MELEE_ATTACK1 | R
    DisableControlAction(0, 264, true) -- INPUT_MELEE_ATTACK2 | Q
    DisableControlAction(0, 81, true)  -- INPUT_VEH_NEXT_RADIO
    DisableControlAction(0, 82, true)  -- INPUT_VEH_PREV_RADIO
    DisableControlAction(0, 85, true)  -- INPUT_VEH_RADIO_WHEEL
end

local function disableCamMovement()
    DisableControlAction(0, 1, true) -- INPUT_LOOK_LR | MOUSE RIGHT
    DisableControlAction(0, 2, true) -- INPUT_LOOK_UD | MOUSE DOWN
    DisableControlAction(0, 3, true) -- INPUT_LOOK_UP_ONLY | (NONE)
    DisableControlAction(0, 4, true) -- INPUT_LOOK_DOWN_ONLY | MOUSE DOWN
    DisableControlAction(0, 5, true) -- INPUT_LOOK_LEFT_ONLY | (NONE)
    DisableControlAction(0, 6, true) -- INPUT_LOOK_RIGHT_ONLY | MOUSE RIGHT
    DisableControlAction(0, 12, true) -- INPUT_WEAPON_WHEEL_UD | MOUSE DOWN
    DisableControlAction(0, 13, true) -- INPUT_WEAPON_WHEEL_LR | MOUSE RIGHT
    DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE_ALTERNATE | ESC
    
end

local function mouseDownListener()
    CreateThread(function()
        while running do
            setCamPosition()

            if IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 24) and State.cameraMovementActive then
                SetMouseCursorSprite(3)
                return
            end

            Wait(0)
        end
    end)
end

local function inputListener()
    setCamPosition() -- Set initial cam position, otherwise cam will remain at player until first left click
    CreateThread(function()
        while running do
            disablePlayerMovement()
            if not isFirstPersonView then
                if State.cameraMovementActive then
                    SetMouseCursorActiveThisFrame()
                end
                disableCamMovement()

                if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) then
                    SetMouseCursorSprite(4)
                    mouseDownListener()
                end
            end

            if IsDisabledControlJustReleased(0, 14) or IsControlJustReleased(0, 14) then
                if gRadius + scrollIncrements <= gRadiusMax then
                    gRadius = gRadius + scrollIncrements
                    setCamPosition()
                end
            elseif IsDisabledControlJustReleased(0, 15) or IsControlJustReleased(0, 15) then
                if gRadius - scrollIncrements >= gRadiusMin then
                    gRadius = gRadius - scrollIncrements
                    setCamPosition()
                end
            end

            if IsDisabledControlJustPressed(0, 22) or IsDisabledControlJustPressed(0, 22) then
                local doors = GetNumberOfVehicleDoors(State.Vehicle)
                for i = 0, doors do
                    if GetVehicleDoorAngleRatio(State.Vehicle, i) > 0 then
                        SetVehicleDoorShut(State.Vehicle, i, false)
                    else
                        SetVehicleDoorOpen(State.Vehicle, i, false, false)
                    end
                end
            end

            -- Left shift
            if IsDisabledControlJustPressed(0, 21) or IsControlJustPressed(0, 21) then
                State.cameraMovementActive = not State.cameraMovementActive
                if State.cameraMovementActive then
                    SetNuiFocus(false, false)
                else
                    SetNuiFocus(true, true)
                end
            end

            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 200) then
                SetNuiFocus(false, false)
                State.openPage = nil
                SendNUIMessage({
                    action = 'setVisibility',
                    data = {
                        visible = false,
                        page = nil
                    }
                })
                TriggerScreenblurFadeOut(500)
                local vehicle = GetVehiclePedIsIn(State.Ped, false)
                if vehicle then
                    setVehicleProperties(vehicle, State.vehicleProps)
                    if State.initialWindowTint ~= nil then
                        SetVehicleWindowTint(vehicle, State.initialWindowTint == -1 and 0 or State.initialWindowTint)
                    end
                    stopDragCam()
                end
            end

            if IsDisabledControlJustPressed(0, 0) or IsDisabledControlJustPressed(0, 0) then
                isFirstPersonView = not isFirstPersonView
                if isFirstPersonView then
                    SetCamViewModeForContext(1, 4)
                    RenderScriptCams(false, true, 0, true, false)
                else
                    RenderScriptCams(true, true, 0, true, false)
                end
            end

            Wait(0)
        end
    end)
end

local function instructionalButton(controlId, text)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, controlId, true))
    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()
end

local function showInstructionalButtons()
    CreateThread(function()
        scaleform = RequestScaleformMovie('instructional_buttons')
        while not HasScaleformMovieLoaded(scaleform) do
            Wait(0)
        end
        BeginScaleformMovieMethod(scaleform, 'CLEAR_ALL')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(1)
        instructionalButton(14, 'Zoom Out')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(2)
        instructionalButton(15, 'Zoom In')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(3)
        instructionalButton(22, 'Toggle Doors')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
        ScaleformMovieMethodAddParamInt(4)
        instructionalButton(0, 'Change View')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'SET_BACKGROUND_COLOUR')
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(80)
        EndScaleformMovieMethod()

        while running do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end
    end)
end

---@param entity integer
function startDragCam(entity)
    running = true
    gEntity = entity
    gRadius = 5.0
    gRadiusMin = 2.5
    gRadiusMax = 10.0
    scrollIncrements = 0.5
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, true, 0, true, false)
    -- showInstructionalButtons()
    inputListener()
end

function stopDragCam()
    running = false
    RenderScriptCams(false, true, 0, true, false)
    DestroyCam(cam, true)
    SetCamViewModeForContext(1, 1)
    SetScaleformMovieAsNoLongerNeeded(scaleform)
end

local gameBuild = GetGameBuildNumber()

---@param vehicle number
---@return VehicleProperties?
function getVehicleProperties(vehicle)
    if DoesEntityExist(vehicle) then
        ---@type number | number[], number | number[]
        local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
        local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
        local paintType1 = GetVehicleModColor_1(vehicle)
        local paintType2 = GetVehicleModColor_2(vehicle)

        if GetIsVehiclePrimaryColourCustom(vehicle) then
            colorPrimary = { GetVehicleCustomPrimaryColour(vehicle) }
        end

        if GetIsVehicleSecondaryColourCustom(vehicle) then
            colorSecondary = { GetVehicleCustomSecondaryColour(vehicle) }
        end

        local extras = {}

        for i = 1, 15 do
            if DoesExtraExist(vehicle, i) then
                extras[i] = IsVehicleExtraTurnedOn(vehicle, i) and 0 or 1
            end
        end

        local damage = {
            windows = {},
            doors = {},
            tyres = {},
        }

        local windows = 0

        for i = 0, 7 do
            RollUpWindow(vehicle, i)

            if not IsVehicleWindowIntact(vehicle, i) then
                windows += 1
                damage.windows[windows] = i
            end
        end

        local doors = 0

        for i = 0, 5 do
            if IsVehicleDoorDamaged(vehicle, i) then
                doors += 1
                damage.doors[doors] = i
            end
        end

        for i = 0, 7 do
            if IsVehicleTyreBurst(vehicle, i, false) then
                damage.tyres[i] = IsVehicleTyreBurst(vehicle, i, true) and 2 or 1
            end
        end

        local neons = {}

        for i = 0, 3 do
            neons[i + 1] = IsVehicleNeonLightEnabled(vehicle, i)
        end

        local xenonCustomColor = nil
        if GetVehicleXenonLightsCustomColor then
            -- Cfx returns: hasCustom, r, g, b
            local hasCustom, r, g, b = GetVehicleXenonLightsCustomColor(vehicle)
            if hasCustom then
                xenonCustomColor = { r or 255, g or 255, b or 255 }
            end
        end

        return {
            model = GetEntityModel(vehicle),
            plate = GetVehicleNumberPlateText(vehicle),
            plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
            bodyHealth = math.floor(GetVehicleBodyHealth(vehicle) + 0.5),
            engineHealth = math.floor(GetVehicleEngineHealth(vehicle) + 0.5),
            tankHealth = math.floor(GetVehiclePetrolTankHealth(vehicle) + 0.5),
            fuelLevel = math.floor(GetVehicleFuelLevel(vehicle) + 0.5),
            oilLevel = math.floor(GetVehicleOilLevel(vehicle) + 0.5),
            dirtLevel = math.floor(GetVehicleDirtLevel(vehicle) + 0.5),
            paintType1 = paintType1,
            paintType2 = paintType2,
            color1 = colorPrimary,
            color2 = colorSecondary,
            pearlescentColor = pearlescentColor,
            interiorColor = GetVehicleInteriorColor(vehicle),
            dashboardColor = GetVehicleDashboardColour(vehicle),
            wheelColor = wheelColor,
            wheelWidth = GetVehicleWheelWidth(vehicle),
            wheelSize = GetVehicleWheelSize(vehicle),
            wheels = GetVehicleWheelType(vehicle),
            windowTint = GetVehicleWindowTint(vehicle),
            xenonColor = GetVehicleXenonLightsColor(vehicle),
            xenonCustomColor = xenonCustomColor,
            neonEnabled = neons,
            neonColor = { GetVehicleNeonLightsColour(vehicle) },
            extras = extras,
            tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
            modSpoilers = GetVehicleMod(vehicle, 0),
            modFrontBumper = GetVehicleMod(vehicle, 1),
            modRearBumper = GetVehicleMod(vehicle, 2),
            modSideSkirt = GetVehicleMod(vehicle, 3),
            modExhaust = GetVehicleMod(vehicle, 4),
            modFrame = GetVehicleMod(vehicle, 5),
            modGrille = GetVehicleMod(vehicle, 6),
            modHood = GetVehicleMod(vehicle, 7),
            modFender = GetVehicleMod(vehicle, 8),
            modRightFender = GetVehicleMod(vehicle, 9),
            modRoof = GetVehicleMod(vehicle, 10),
            modEngine = GetVehicleMod(vehicle, 11),
            modBrakes = GetVehicleMod(vehicle, 12),
            modTransmission = GetVehicleMod(vehicle, 13),
            modHorns = GetVehicleMod(vehicle, 14),
            modSuspension = GetVehicleMod(vehicle, 15),
            modArmor = GetVehicleMod(vehicle, 16),
            modNitrous = GetVehicleMod(vehicle, 17),
            modTurbo = IsToggleModOn(vehicle, 18),
            modSubwoofer = GetVehicleMod(vehicle, 19),
            modSmokeEnabled = IsToggleModOn(vehicle, 20),
            modHydraulics = IsToggleModOn(vehicle, 21),
            modXenon = IsToggleModOn(vehicle, 22),
            modFrontWheels = GetVehicleMod(vehicle, 23),
            modBackWheels = GetVehicleMod(vehicle, 24),
            modCustomTiresF = GetVehicleModVariation(vehicle, 23),
            modCustomTiresR = GetVehicleModVariation(vehicle, 24),
            modPlateHolder = GetVehicleMod(vehicle, 25),
            modVanityPlate = GetVehicleMod(vehicle, 26),
            modTrimA = GetVehicleMod(vehicle, 27),
            modOrnaments = GetVehicleMod(vehicle, 28),
            modDashboard = GetVehicleMod(vehicle, 29),
            modDial = GetVehicleMod(vehicle, 30),
            modDoorSpeaker = GetVehicleMod(vehicle, 31),
            modSeats = GetVehicleMod(vehicle, 32),
            modSteeringWheel = GetVehicleMod(vehicle, 33),
            modShifterLeavers = GetVehicleMod(vehicle, 34),
            modAPlate = GetVehicleMod(vehicle, 35),
            modSpeakers = GetVehicleMod(vehicle, 36),
            modTrunk = GetVehicleMod(vehicle, 37),
            modHydrolic = GetVehicleMod(vehicle, 38),
            modEngineBlock = GetVehicleMod(vehicle, 39),
            modAirFilter = GetVehicleMod(vehicle, 40),
            modStruts = GetVehicleMod(vehicle, 41),
            modArchCover = GetVehicleMod(vehicle, 42),
            modAerials = GetVehicleMod(vehicle, 43),
            modTrimB = GetVehicleMod(vehicle, 44),
            modTank = GetVehicleMod(vehicle, 45),
            modWindows = GetVehicleMod(vehicle, 46),
            modDoorR = GetVehicleMod(vehicle, 47),
            modLivery = GetVehicleMod(vehicle, 48),
            modRoofLivery = GetVehicleRoofLivery(vehicle),
            modLightbar = GetVehicleMod(vehicle, 49),
            livery = GetVehicleLivery(vehicle),
            windows = damage.windows,
            doors = damage.doors,
            tyres = damage.tyres,
            bulletProofTyres = GetVehicleTyresCanBurst(vehicle),
            driftTyres = gameBuild >= 2372 and GetDriftTyresEnabled(vehicle),
            -- no setters?
            -- leftHeadlight = GetIsLeftVehicleHeadlightDamaged(vehicle),
            -- rightHeadlight = GetIsRightVehicleHeadlightDamaged(vehicle),
            -- frontBumper = IsVehicleBumperBrokenOff(vehicle, true),
            -- rearBumper = IsVehicleBumperBrokenOff(vehicle, false),
        }
    end
end

---@param vehicle number
---@param props VehicleProperties
---@param fixVehicle? boolean Fix the vehicle after props have been set. Usually required when adding extras.
---@return boolean isEntityOwner True if the entity is networked and the client is the current entity owner.
function setVehicleProperties(vehicle, props, fixVehicle)
    if not DoesEntityExist(vehicle) then
        error(("Unable to set vehicle properties for '%s' (entity does not exist)"):format(vehicle))
    end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)

    SetVehicleModKit(vehicle, 0)
    -- SetVehicleAutoRepairDisabled(vehicle, true)

    if props.extras then
        for id, disable in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(id) --[[@as number]], disable == 1)
        end
    end

    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end

    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end

    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end

    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end

    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end

    if props.oilLevel then
        SetVehicleOilLevel(vehicle, props.oilLevel + 0.0)
    end

    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
    end

    if props.color1 then
        if type(props.color1) == 'number' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 --[[@as number]], colorSecondary --[[@as number]])
        else
            if props.paintType1 then SetVehicleModColor_1(vehicle, props.paintType1, 0, props.pearlescentColor or 0) end

            SetVehicleCustomPrimaryColour(vehicle, props.color1[1], props.color1[2], props.color1[3])
        end
    end

    if props.color2 then
        if type(props.color2) == 'number' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleColours(vehicle, props.color1 or colorPrimary --[[@as number]], props.color2 --[[@as number]])
        else
            if props.paintType2 then SetVehicleModColor_2(vehicle, props.paintType2, 0) end

            SetVehicleCustomSecondaryColour(vehicle, props.color2[1], props.color2[2], props.color2[3])
        end
    end

    if props.pearlescentColor or props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor or wheelColor)
    end

    if props.interiorColor then
        SetVehicleInteriorColor(vehicle, props.interiorColor)
    end

    if props.dashboardColor then
        SetVehicleDashboardColor(vehicle, props.dashboardColor)
    end

    if props.wheels then
        SetVehicleWheelType(vehicle, props.wheels)
    end

    if props.wheelSize then
        SetVehicleWheelSize(vehicle, props.wheelSize)
    end

    if props.wheelWidth then
        SetVehicleWheelWidth(vehicle, props.wheelWidth)
    end

    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end

    if props.neonEnabled then
        for i = 1, #props.neonEnabled do
            SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i])
        end
    end

    if props.windows then
        for i = 1, #props.windows do
            RemoveVehicleWindow(vehicle, props.windows[i])
        end
    end

    if props.doors then
        for i = 1, #props.doors do
            SetVehicleDoorBroken(vehicle, props.doors[i], true)
        end
    end

    if props.tyres then
        for tyre, state in pairs(props.tyres) do
            SetVehicleTyreBurst(vehicle, tonumber(tyre) --[[@as number]], state == 2, 1000.0)
        end
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.modSmokeEnabled ~= nil then
        ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled)
    end

    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if props.modSpoilers then
        SetVehicleMod(vehicle, 0, props.modSpoilers, false)
    end

    if props.modFrontBumper then
        SetVehicleMod(vehicle, 1, props.modFrontBumper, false)
    end

    if props.modRearBumper then
        SetVehicleMod(vehicle, 2, props.modRearBumper, false)
    end

    if props.modSideSkirt then
        SetVehicleMod(vehicle, 3, props.modSideSkirt, false)
    end

    if props.modExhaust then
        SetVehicleMod(vehicle, 4, props.modExhaust, false)
    end

    if props.modFrame then
        SetVehicleMod(vehicle, 5, props.modFrame, false)
    end

    if props.modGrille then
        SetVehicleMod(vehicle, 6, props.modGrille, false)
    end

    if props.modHood then
        SetVehicleMod(vehicle, 7, props.modHood, false)
    end

    if props.modFender then
        SetVehicleMod(vehicle, 8, props.modFender, false)
    end

    if props.modRightFender then
        SetVehicleMod(vehicle, 9, props.modRightFender, false)
    end

    if props.modRoof then
        SetVehicleMod(vehicle, 10, props.modRoof, false)
    end

    if props.modEngine then
        SetVehicleMod(vehicle, 11, props.modEngine, false)
    end

    if props.modBrakes then
        SetVehicleMod(vehicle, 12, props.modBrakes, false)
    end

    if props.modTransmission then
        SetVehicleMod(vehicle, 13, props.modTransmission, false)
    end

    if props.modHorns then
        SetVehicleMod(vehicle, 14, props.modHorns, false)
    end

    if props.modSuspension then
        SetVehicleMod(vehicle, 15, props.modSuspension, false)
    end

    if props.modArmor then
        SetVehicleMod(vehicle, 16, props.modArmor, false)
    end

    if props.modNitrous then
        SetVehicleMod(vehicle, 17, props.modNitrous, false)
    end

    if props.modTurbo ~= nil then
        ToggleVehicleMod(vehicle, 18, props.modTurbo)
    end

    if props.modSubwoofer ~= nil then
        ToggleVehicleMod(vehicle, 19, props.modSubwoofer)
    end

    if props.modHydraulics ~= nil then
        ToggleVehicleMod(vehicle, 21, props.modHydraulics)
    end

    if props.modXenon ~= nil then
        ToggleVehicleMod(vehicle, 22, props.modXenon)
    end

    if props.xenonColor then
        SetVehicleXenonLightsColor(vehicle, props.xenonColor)
    end

    if props.xenonCustomColor then
        if SetVehicleXenonLightsCustomColor then
            SetVehicleXenonLightsCustomColor(vehicle, props.xenonCustomColor[1] or 255, props.xenonCustomColor[2] or 255, props.xenonCustomColor[3] or 255)
        end
    else
        if ClearVehicleXenonLightsCustomColor then
            ClearVehicleXenonLightsCustomColor(vehicle)
        end
    end

    if props.modFrontWheels then
        SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF)
    end

    if props.modBackWheels then
        SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR)
    end

    if props.modPlateHolder then
        SetVehicleMod(vehicle, 25, props.modPlateHolder, false)
    end

    if props.modVanityPlate then
        SetVehicleMod(vehicle, 26, props.modVanityPlate, false)
    end

    if props.modTrimA then
        SetVehicleMod(vehicle, 27, props.modTrimA, false)
    end

    if props.modOrnaments then
        SetVehicleMod(vehicle, 28, props.modOrnaments, false)
    end

    if props.modDashboard then
        SetVehicleMod(vehicle, 29, props.modDashboard, false)
    end

    if props.modDial then
        SetVehicleMod(vehicle, 30, props.modDial, false)
    end

    if props.modDoorSpeaker then
        SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false)
    end

    if props.modSeats then
        SetVehicleMod(vehicle, 32, props.modSeats, false)
    end

    if props.modSteeringWheel then
        SetVehicleMod(vehicle, 33, props.modSteeringWheel, false)
    end

    if props.modShifterLeavers then
        SetVehicleMod(vehicle, 34, props.modShifterLeavers, false)
    end

    if props.modAPlate then
        SetVehicleMod(vehicle, 35, props.modAPlate, false)
    end

    if props.modSpeakers then
        SetVehicleMod(vehicle, 36, props.modSpeakers, false)
    end

    if props.modTrunk then
        SetVehicleMod(vehicle, 37, props.modTrunk, false)
    end

    if props.modHydrolic then
        SetVehicleMod(vehicle, 38, props.modHydrolic, false)
    end

    if props.modEngineBlock then
        SetVehicleMod(vehicle, 39, props.modEngineBlock, false)
    end

    if props.modAirFilter then
        SetVehicleMod(vehicle, 40, props.modAirFilter, false)
    end

    if props.modStruts then
        SetVehicleMod(vehicle, 41, props.modStruts, false)
    end

    if props.modArchCover then
        SetVehicleMod(vehicle, 42, props.modArchCover, false)
    end

    if props.modAerials then
        SetVehicleMod(vehicle, 43, props.modAerials, false)
    end

    if props.modTrimB then
        SetVehicleMod(vehicle, 44, props.modTrimB, false)
    end

    if props.modTank then
        SetVehicleMod(vehicle, 45, props.modTank, false)
    end

    if props.modWindows then
        SetVehicleMod(vehicle, 46, props.modWindows, false)
    end

    if props.modDoorR then
        SetVehicleMod(vehicle, 47, props.modDoorR, false)
    end

    if props.modLivery then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
    end

    if props.modRoofLivery then
        SetVehicleRoofLivery(vehicle, props.modRoofLivery)
    end

    if props.modLightbar then
        SetVehicleMod(vehicle, 49, props.modLightbar, false)
    end

    if props.livery then
        SetVehicleLivery(vehicle, props.livery)
    end

    if props.bulletProofTyres ~= nil then
        SetVehicleTyresCanBurst(vehicle, props.bulletProofTyres)
    end

    if gameBuild >= 2372 and props.driftTyres then
        SetDriftTyresEnabled(vehicle, true)
    end

    if fixVehicle then
        SetVehicleFixed(vehicle)
    end

    return not NetworkGetEntityIsNetworked(vehicle) or NetworkGetEntityOwner(vehicle) == PlayerId()
end

function GetVehicleColorName(primaryId, secondaryId)
    local colors = {
        -- Chrome
        [120] = { name = "Chrome", finish = "Chrome" },

        -- Classic / Metallic
        [0] = { name = "Black", finish = "Metallic" },
        [147] = { name = "Carbon Black", finish = "Metallic" },
        [1] = { name = "Graphite", finish = "Metallic" },
        [11] = { name = "Anhracite Black", finish = "Metallic" },
        [2] = { name = "Black Steel", finish = "Metallic" },
        [3] = { name = "Dark Steel", finish = "Metallic" },
        [4] = { name = "Silver", finish = "Metallic" },
        [5] = { name = "Bluish Silver", finish = "Metallic" },
        [6] = { name = "Rolled Steel", finish = "Metallic" },
        [7] = { name = "Shadow Silver", finish = "Metallic" },
        [8] = { name = "Stone Silver", finish = "Metallic" },
        [9] = { name = "Midnight Silver", finish = "Metallic" },
        [10] = { name = "Cast Iron Silver", finish = "Metallic" },
        [27] = { name = "Red", finish = "Metallic" },
        [28] = { name = "Torino Red", finish = "Metallic" },
        [29] = { name = "Formula Red", finish = "Metallic" },
        [150] = { name = "Lava Red", finish = "Metallic" },
        [30] = { name = "Blaze Red", finish = "Metallic" },
        [31] = { name = "Grace Red", finish = "Metallic" },
        [32] = { name = "Garnet Red", finish = "Metallic" },
        [33] = { name = "Sunset Red", finish = "Metallic" },
        [34] = { name = "Cabernet Red", finish = "Metallic" },
        [143] = { name = "Wine Red", finish = "Metallic" },
        [35] = { name = "Candy Red", finish = "Metallic" },
        [135] = { name = "Hot Pink", finish = "Metallic" },
        [137] = { name = "Pfsiter Pink", finish = "Metallic" },
        [136] = { name = "Salmon Pink", finish = "Metallic" },
        [36] = { name = "Sunrise Orange", finish = "Metallic" },
        [38] = { name = "Orange", finish = "Metallic" },
        [138] = { name = "Bright Orange", finish = "Metallic" },
        [99] = { name = "Gold", finish = "Metallic" },
        [90] = { name = "Bronze", finish = "Metallic" },
        [88] = { name = "Yellow", finish = "Metallic" },
        [89] = { name = "Race Yellow", finish = "Metallic" },
        [91] = { name = "Dew Yellow", finish = "Metallic" },
        [49] = { name = "Dark Green", finish = "Metallic" },
        [50] = { name = "Racing Green", finish = "Metallic" },
        [51] = { name = "Sea Green", finish = "Metallic" },
        [52] = { name = "Olive Green", finish = "Metallic" },
        [53] = { name = "Bright Green", finish = "Metallic" },
        [54] = { name = "Gasoline Green", finish = "Metallic" },
        [92] = { name = "Lime Green", finish = "Metallic" },
        [141] = { name = "Midnight Blue", finish = "Metallic" },
        [61] = { name = "Galaxy Blue", finish = "Metallic" },
        [62] = { name = "Dark Blue", finish = "Metallic" },
        [63] = { name = "Saxon Blue", finish = "Metallic" },
        [64] = { name = "Blue", finish = "Metallic" },
        [65] = { name = "Mariner Blue", finish = "Metallic" },
        [66] = { name = "Harbor Blue", finish = "Metallic" },
        [67] = { name = "Diamond Blue", finish = "Metallic" },
        [68] = { name = "Surf Blue", finish = "Metallic" },
        [69] = { name = "Nautical Blue", finish = "Metallic" },
        [73] = { name = "Racing Blue", finish = "Metallic" },
        [70] = { name = "Ultra Blue", finish = "Metallic" },
        [74] = { name = "Light Blue", finish = "Metallic" },
        [71] = { name = "Schafter Purple", finish = "Metallic" },
        [72] = { name = "Spinnaker Purple", finish = "Metallic" },
        [142] = { name = "Midnight Purple", finish = "Metallic" },
        [145] = { name = "Bright Purple", finish = "Metallic" },
        [111] = { name = "Ice White", finish = "Metallic" },
        [112] = { name = "Frost White", finish = "Metallic" },

        -- Matte
        [12] = { name = "Black", finish = "Matte" },
        [13] = { name = "Gray", finish = "Matte" },
        [14] = { name = "Light Gray", finish = "Matte" },
        [131] = { name = "Ice White", finish = "Matte" },
        [83] = { name = "Blue", finish = "Matte" },
        [82] = { name = "Dark Blue", finish = "Matte" },
        [84] = { name = "Midnight Blue", finish = "Matte" },
        [149] = { name = "Midnight Purple", finish = "Matte" },
        [148] = { name = "Schafter Purple", finish = "Matte" },
        [39] = { name = "Red", finish = "Matte" },
        [40] = { name = "Dark Red", finish = "Matte" },
        [41] = { name = "Orange", finish = "Matte" },
        [42] = { name = "Yellow", finish = "Matte" },
        [55] = { name = "Lime Green", finish = "Matte" },
        [128] = { name = "Green", finish = "Matte" },
        [151] = { name = "Forest Green", finish = "Matte" },
        [155] = { name = "Foliage Green", finish = "Matte" },
        [152] = { name = "Olive Darb", finish = "Matte" },
        [153] = { name = "Dark Earth", finish = "Matte" },
        [154] = { name = "Desert Tan", finish = "Matte" },

        -- Metals
        [117] = { name = "Brushed Steel", finish = "Metal" },
        [118] = { name = "Brushed Black Steel", finish = "Metal" },
        [119] = { name = "Brushed Aluminum", finish = "Metal" },
        [158] = { name = "Pure Gold", finish = "Metal" },
        [159] = { name = "Brushed Gold", finish = "Metal" }
    }

    local primary = colors[primaryId]
    local secondary = colors[secondaryId]

    if not primary and not secondary then
        return "Unknown Colors"
    end

    if primary and not secondary then
        return string.format("%s %s", primary.finish, primary.name)
    elseif not primary and secondary then
        return string.format("%s %s", secondary.finish, secondary.name)
    elseif primaryId == secondaryId then
        return string.format("%s %s", primary.finish, primary.name)
    else
        return string.format("%s %s with %s accents", primary.finish, primary.name, secondary.name)
    end
end

function GenerateVehicleVin(model, plate)
    local seed = 0
    local combinedString = tostring(model or "") .. tostring(plate or "")
    
    for i = 1, #combinedString do
        seed = seed + string.byte(combinedString, i) * (i * 31)
    end
    
    local vinChars = "0123456789ABCDEFGHJKLMNPRSTUVWXYZ"
    local vin = ""
    
    local a = 1664525
    local c = 1013904223
    local m = 2^32
    local currentSeed = seed
    
    for i = 1, 17 do
        currentSeed = (a * currentSeed + c) % m
        local charIndex = (currentSeed % #vinChars) + 1
        vin = vin .. string.sub(vinChars, charIndex, charIndex)
    end
    
    return vin
end

local bridge = exports['community_bridge']:Bridge()
function IsVehicleOwned(src, plate)
    local frameworkVehInfo = bridge.Framework.IsVehicleOwnedByPlayer(src, plate)
    local isOwned = frameworkVehInfo and frameworkVehInfo.vehicle
    return isOwned
end

-- Copied from qb_mechanic
RegisterNetEvent('nn_mechanic:saveVehicleProps', function(vehicleProps)
    local src = source
    if IsVehicleOwned(src, vehicleProps.plate) then
        if GetResourceState('qbx_core') == 'started' or GetResourceState('qb-core') == 'started' then
            MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
        elseif GetResourceState('es_extended') == 'started' then
            MySQL.update.await('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
        end
    end
end)

function clamp(x, a, b)
    if x < a then
        return a
    elseif x > b then
        return b
    else
        return x
    end
end

function DisableControls()
    Citizen.CreateThread(function()
        while State.disableControls do
            DisableAllControlActions(0)
            Wait(1)
        end
    end)
end