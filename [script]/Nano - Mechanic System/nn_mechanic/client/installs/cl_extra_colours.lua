-- Initialize bridge
if not bridge then
    bridge = exports.community_bridge.Bridge()
end

-- Animation constants
local ANIM_DICT = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local ANIM_CLIP = "machinic_loop_mechandplayer"

-- Clamp RGB value to valid range (0-255)
function ClampRGBValue(value)
    local num = tonumber(value) or 0
    local clamped = math.floor(num + 0.5)
    
    if clamped < 0 then
        return 0
    elseif clamped > 255 then
        return 255
    end
    
    return clamped
end

-- Get nearest or current vehicle
function GetTargetVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        return vehicle
    end
    
    local pedCoords = GetEntityCoords(ped)
    local closestVehicle = GetClosestVehicle(pedCoords.x, pedCoords.y, pedCoords.z, 6.0, 0, 70)
    
    if closestVehicle and closestVehicle ~= 0 and DoesEntityExist(closestVehicle) then
        return closestVehicle
    end
    
    return nil
end

-- Install extra colours on vehicle
function StartInstallExtraColours(coloursData, callback)
    -- Validate input data
    if type(coloursData) ~= "table" then
        bridge.Notify.SendNotify(t("invalid_extra_colours_data") or "Invalid extra colours data", "error")
        if callback then callback(false) end
        return false
    end
    
    -- Find target vehicle
    local vehicle = GetTargetVehicle()
    if not vehicle then
        bridge.Notify.SendNotify(t("no_vehicle_found") or "No vehicle found", "error")
        if callback then callback(false) end
        return false
    end
    
    -- Load animation dictionary
    RequestAnimDict(ANIM_DICT)
    while not HasAnimDictLoaded(ANIM_DICT) do
        Wait(30)
    end
    
    -- Start installation progress
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = 7000,
        label = t("installing_extra_colours") or "Applying extra colours...",
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = ANIM_DICT,
            clip = ANIM_CLIP,
            flag = 1
        }
    })
    
    SetPedCanRagdoll(ped, true)
    
    if not success then
        if callback then callback(false) end
        return false
    end
    
    -- Apply the modifications
    SetVehicleModKit(vehicle, 0)
    
    -- Get current extra colours as fallbacks
    local currentPearlescent, currentWheelColor = GetVehicleExtraColours(vehicle)
    
    -- Apply pearlescent and wheel colours
    local newPearlescent = tonumber(coloursData.pearlescentColorIndex)
    local newWheelColor = tonumber(coloursData.wheelColorIndex)
    
    if newPearlescent ~= nil or newWheelColor ~= nil then
        SetVehicleExtraColours(
            vehicle,
            newPearlescent or currentPearlescent or 0,
            newWheelColor or currentWheelColor or 0
        )
    end
    
    -- Apply tyre smoke colour
    if coloursData.tyreSmokeRgb then
        local smokeRgb = coloursData.tyreSmokeRgb
        ToggleVehicleMod(vehicle, 20, true)
        SetVehicleTyreSmokeColor(
            vehicle,
            ClampRGBValue(smokeRgb.r),
            ClampRGBValue(smokeRgb.g),
            ClampRGBValue(smokeRgb.b)
        )
    end
    
    -- Save vehicle properties
    local vehicleProps = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", vehicleProps)
    setVehicleProperties(vehicle, vehicleProps)
    
    -- Notify success
    bridge.Notify.SendNotify(t("extra_colours_installed") or "Extra colours applied", "success")
    
    if callback then callback(true) end
    return true
end