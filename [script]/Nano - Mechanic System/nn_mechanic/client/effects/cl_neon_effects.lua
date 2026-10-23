local vehicleNeonCache = {}
local previewTimer = 0
local previewThreadId = 0
local breatheTable = {}

-- Generate RGB color sequence for rainbow effect
local rgbColors = {}
local colorIndex = 1

-- Red to Yellow
for r = 0, 254 do
    rgbColors[colorIndex] = {255, r, 0}
    colorIndex = colorIndex + 1
end

-- Yellow to Green
for g = 254, 0, -1 do
    rgbColors[colorIndex] = {g, 255, 0}
    colorIndex = colorIndex + 1
end

-- Green to Cyan
for b = 0, 254 do
    rgbColors[colorIndex] = {0, 255, b}
    colorIndex = colorIndex + 1
end

-- Cyan to Blue
for g = 254, 0, -1 do
    rgbColors[colorIndex] = {0, g, 255}
    colorIndex = colorIndex + 1
end

-- Blue to Magenta
for r = 0, 254 do
    rgbColors[colorIndex] = {r, 0, 255}
    colorIndex = colorIndex + 1
end

-- Magenta to Red
for b = 254, 1, -1 do
    rgbColors[colorIndex] = {255, 0, b}
    colorIndex = colorIndex + 1
end

-- Generate breathe effect intensity values
for i = 1, 120 do
    local t = (i - 1) / 120.0
    if t <= 0.5 then
        -- Ease-in-out using cosine
        local value = 0.5 + 0.5 * math.cos(t * 2.0 * math.pi)
        breatheTable[i] = value
    else
        -- Power curve for fade
        local value = math.pow((t - 0.5) / 0.5, 0.6)
        breatheTable[i] = value
    end
end

-- Preview state
function NeonPreviewIsActive()
    return previewTimer ~= 0
end

-- Apply neon light states
function ApplyNeonLights(vehicle, zones)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    
    DisableVehicleNeonLights(vehicle, false)
    SetVehicleNeonLightEnabled(vehicle, 0, zones.left)
    SetVehicleNeonLightEnabled(vehicle, 1, zones.right)
    SetVehicleNeonLightEnabled(vehicle, 2, zones.front)
    SetVehicleNeonLightEnabled(vehicle, 3, zones.back)
end

-- Apply neon lights with optional color
function ApplyNeonWithColor(vehicle, zones, color)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    
    zones = type(zones) == "table" and zones or {}
    
    local left = zones.left ~= nil and (zones.left == true or zones.left) or false
    local right = zones.right ~= nil and (zones.right == true or zones.right) or false
    local front = zones.front ~= nil and (zones.front == true or zones.front) or false
    local back = zones.back ~= nil and (zones.back == true or zones.back) or false
    
    DisableVehicleNeonLights(vehicle, false)
    
    SetVehicleNeonLightEnabled(vehicle, 0, left)
    SetVehicleNeonLightEnabled(vehicle, 1, right)
    SetVehicleNeonLightEnabled(vehicle, 2, front)
    SetVehicleNeonLightEnabled(vehicle, 3, back)
    
    if color then
        SetVehicleNeonLightsColour(vehicle, color[1], color[2], color[3])
    end
end

-- Parse and validate RGB color
function ParseRGBColor(color)
    if type(color) ~= "table" then
        return {255, 255, 255}
    end
    
    local r = tonumber(color.r) or tonumber(color[1]) or 255
    local g = tonumber(color.g) or tonumber(color[2]) or 255
    local b = tonumber(color.b) or tonumber(color[3]) or 255
    
    r = math.min(255, math.max(0, r))
    g = math.min(255, math.max(0, g))
    b = math.min(255, math.max(0, b))
    
    return {math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)}
end

-- Simulate neon effect with preview timeout
function SimulateNeonEffect(effectType, vehicle, color, zones)
    previewThreadId = previewThreadId + 1
    local myThreadId = previewThreadId
    previewTimer = GetGameTimer() + 10000
    
    local targetVehicle = vehicle or GetVehiclePedIsIn(PlayerPedId(), false)
    if not targetVehicle or targetVehicle == 0 or not DoesEntityExist(targetVehicle) then
        return
    end
    
    effectType = (type(effectType) == "string" and effectType) or "static"
    local parsedColor = ParseRGBColor(color)
    
    if effectType == "off" then
        SetVehicleNeonLightEnabled(targetVehicle, 0, false)
        SetVehicleNeonLightEnabled(targetVehicle, 1, false)
        SetVehicleNeonLightEnabled(targetVehicle, 2, false)
        SetVehicleNeonLightEnabled(targetVehicle, 3, false)
        
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while myThreadId == previewThreadId and GetGameTimer() - startTime < 10000 do
                Wait(150)
            end
            if myThreadId == previewThreadId then
                previewTimer = 0
            end
        end)
        return
    end
    
    if effectType == "static" then
        ApplyNeonWithColor(targetVehicle, zones, parsedColor)
        
        Citizen.CreateThread(function()
            local startTime = GetGameTimer()
            while myThreadId == previewThreadId and GetGameTimer() - startTime < 10000 do
                Wait(150)
            end
            if myThreadId == previewThreadId then
                previewTimer = 0
            end
        end)
        return
    end
    
    -- Dynamic effects (rgb, breathe)
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local config = Config.NeonEffects
        local interval = config.interval
        local rgbSpeed = tonumber(config.rgbSpeed) or 2
        local pulseSpeed = tonumber(config.pulseSpeed) or 2
        
        rgbSpeed = math.min(50, math.max(1, rgbSpeed))
        pulseSpeed = math.min(50, math.max(1, pulseSpeed))
        
        local rgbIndex = 1
        local breatheIndex = 1
        
        while myThreadId == previewThreadId and GetGameTimer() - startTime < 10000 and DoesEntityExist(targetVehicle) do
            if effectType == "rgb" then
                local colorRGB = rgbColors[rgbIndex]
                ApplyNeonWithColor(targetVehicle, zones, colorRGB)
                rgbIndex = (rgbIndex - 1 + rgbSpeed) % #rgbColors + 1
            elseif effectType == "breathe" then
                breatheIndex = breatheIndex + pulseSpeed
                if breatheIndex > #breatheTable then
                    breatheIndex = 1
                end
                
                local intensity = breatheTable[breatheIndex]
                local breatheColor = {
                    math.floor(parsedColor[1] * intensity),
                    math.floor(parsedColor[2] * intensity),
                    math.floor(parsedColor[3] * intensity)
                }
                ApplyNeonWithColor(targetVehicle, zones, breatheColor)
            else
                ApplyNeonWithColor(targetVehicle, zones, parsedColor)
            end
            
            Wait(interval)
        end
        
        if myThreadId == previewThreadId and DoesEntityExist(targetVehicle) then
            ApplyNeonWithColor(targetVehicle, zones, parsedColor)
            previewTimer = 0
        end
    end)
end

-- Convert hex color to RGB table
function HexToRGB(hex)
    if type(hex) ~= "string" then
        return nil
    end
    
    local r, g, b = hex:upper():match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then
        return nil
    end
    
    return {
        tonumber(r, 16) or 255,
        tonumber(g, 16) or 255,
        tonumber(b, 16) or 255
    }
end

-- Update neon effect from server
RegisterNetEvent("nn_mechanic:updateNeonEffect")
AddEventHandler("nn_mechanic:updateNeonEffect", function(licensePlate, effect)
    if type(licensePlate) ~= "string" or licensePlate == "" then
        return
    end
    
    local normalizedPlate = licensePlate:gsub("%s+", "")
    local cache = vehicleNeonCache[normalizedPlate]
    
    if not cache then
        vehicleNeonCache[normalizedPlate] = {
            effect = effect,
            lastFetchedAt = GetGameTimer()
        }
        return
    end
    
    cache.effect = effect
    cache.lastFetchedAt = GetGameTimer()
end)

-- Monitor vehicle entry and fetch neon effects
Citizen.CreateThread(function()
    while true do
        if not Config.NeonEffects.enabled then
            break
        end
        
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        
        if DoesEntityExist(vehicle) then
            local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
            
            -- Check if any neon lights are enabled
            local hasNeon = false
            for i = 0, 3 do
                if IsVehicleNeonLightEnabled(vehicle, i) then
                    hasNeon = true
                    break
                end
            end
            
            if hasNeon and plate ~= "" and not vehicleNeonCache[plate] then
                local effect = bridge.Callback.Trigger("nn_mechanic:getVehicleNeonEffect", plate) or "static"
                local colorStr = bridge.Callback.Trigger("nn_mechanic:getVehicleNeonColor", plate)
                local color = HexToRGB(colorStr) or {255, 255, 255}
                local zonesJson = bridge.Callback.Trigger("nn_mechanic:getVehicleNeonLights", plate) or "{}"
                local zones = json.decode(zonesJson) or {}
                
                TriggerServerEvent("nn_mechanic:takeControlNeonEffect", plate)
                
                vehicleNeonCache[plate] = {
                    effect = effect,
                    vehicle = vehicle,
                    baseRgb = color,
                    zones = zones,
                    rgbIndex = 1,
                    breatheIndex = 1,
                    staticAppliedKey = nil
                }
            end
        end
        
        Wait(2000)
    end
end)

-- Release neon effect control
RegisterNetEvent("nn_mechanic:releaseControlNeonEffect")
AddEventHandler("nn_mechanic:releaseControlNeonEffect", function(licensePlate)
    vehicleNeonCache[licensePlate] = nil
end)

-- Main neon effect thread
Citizen.CreateThread(function()
    while true do
        local interval = tonumber(Config.NeonEffects.interval) or 80
        
        if Config.NeonEffects.enabled then
            if previewTimer ~= 0 and GetGameTimer() < previewTimer then
                Wait(interval)
            else
                local rgbSpeed = tonumber(Config.NeonEffects.rgbSpeed) or 2
                rgbSpeed = math.min(50, math.max(1, rgbSpeed))
                
                for plate, data in pairs(vehicleNeonCache) do
                    local vehicle = data.vehicle
                    
                    if not DoesEntityExist(vehicle) then
                        vehicleNeonCache[plate] = nil
                    else
                        local effectType = data.effect
                        local zones = data.zones
                        
                        if effectType == "rgb" then
                            local rgbIndex = data.rgbIndex or 1
                            local colorRGB = rgbColors[rgbIndex]
                            
                            ApplyNeonLights(vehicle, zones)
                            SetVehicleNeonLightsColour(vehicle, colorRGB[1], colorRGB[2], colorRGB[3])
                            
                            data.rgbIndex = (rgbIndex - 1 + rgbSpeed) % #rgbColors + 1
                            
                        elseif effectType == "static" then
                            local baseColor = data.baseRgb or {255, 255, 255}
                            ApplyNeonLights(vehicle, zones)
                            SetVehicleNeonLightsColour(vehicle, baseColor[1], baseColor[2], baseColor[3])
                            
                        elseif effectType == "breathe" then
                            ApplyNeonLights(vehicle, zones)
                            
                            local baseColor = data.baseRgb or {255, 255, 255}
                            local pulseSpeed = tonumber(Config.NeonEffects.pulseSpeed) or 2
                            pulseSpeed = math.min(50, math.max(1, pulseSpeed))
                            
                            local breatheIndex = (data.breatheIndex or 1) + pulseSpeed
                            if breatheIndex > #breatheTable then
                                breatheIndex = 1
                            end
                            data.breatheIndex = breatheIndex
                            
                            local intensity = breatheTable[breatheIndex]
                            local breatheColor = {
                                math.floor(baseColor[1] * intensity),
                                math.floor(baseColor[2] * intensity),
                                math.floor(baseColor[3] * intensity)
                            }
                            SetVehicleNeonLightsColour(vehicle, breatheColor[1], breatheColor[2], breatheColor[3])
                            
                        elseif effectType == "off" then
                            ApplyNeonLights(vehicle, zones)
                            for i = 0, 3 do
                                SetVehicleNeonLightEnabled(vehicle, i, false)
                            end
                        end
                    end
                end
                
                Wait(interval)
            end
        end
    end
end)