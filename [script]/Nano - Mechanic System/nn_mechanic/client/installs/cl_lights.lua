--[[
    Vehicle Lighting System for FiveM
    Supports: Neon Lights & Xenon Lights
]]

-- Bridge initialization
local bridge = bridge or exports.community_bridge.Bridge()

-- Animation dictionary and clip
local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local animClip = "machinic_loop_mechandplayer"

-- Helper Functions
local function clampRGB(value)
    local num = tonumber(value) or 0
    num = math.floor(num + 0.5)
    return math.max(0, math.min(255, num))
end

local function parseColor(color)
    if type(color) ~= "table" then
        return { r = 255, g = 255, b = 255 }
    end
    
    local r = color.r or color[1] or 255
    local g = color.g or color[2] or 255
    local b = color.b or color[3] or 255
    
    return {
        r = clampRGB(r),
        g = clampRGB(g),
        b = clampRGB(b)
    }
end

local function getNearbyVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle and DoesEntityExist(vehicle) and vehicle ~= 0 then
        return vehicle
    end
    
    local coords = GetEntityCoords(ped)
    vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 70)
    
    if vehicle and DoesEntityExist(vehicle) and vehicle ~= 0 then
        return vehicle
    end
    
    return nil
end

local function consumeItem(itemName)
    if not bridge.Callback.Trigger("nn_mechanic:hasItem", itemName) then
        bridge.Notify.SendNotify(string.format("Missing item: %s", itemName), "error")
        return false
    end
    
    if not bridge.Callback.Trigger("nn_mechanic:consumeItem", itemName) then
        local msg = t("failed_to_remove_item") or "Failed to remove item."
        bridge.Notify.SendNotify(msg, "error")
        return false
    end
    
    return true
end

local function doInstallAnimation(textKey, displayText, duration)
    duration = duration or 6000
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(30)
    end
    
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, false)
    
    local success = bridge.ProgressBar.Open({
        duration = duration,
        label = t(textKey) or displayText,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = animDict,
            clip = animClip,
            flag = 1
        }
    })
    
    SetPedCanRagdoll(ped, true)
    return success == true
end

-- Core Installation Functions
function StartInstallNeon(rgbColor, callback)
    local vehicle = getNearbyVehicle()
    
    if not vehicle then
        local msg = t("no_vehicle_found") or "No vehicle found"
        bridge.Notify.SendNotify(msg, "error")
        if callback then callback(false) end
        return false
    end
    
    if not consumeItem("mechanic_neon_light") then
        if callback then callback(false) end
        return false
    end
    
    if not doInstallAnimation("installing_neon_lights", "Installing neon lights...", 6500) then
        if callback then callback(false) end
        return false
    end
    
    local color = parseColor(rgbColor)
    
    SetVehicleModKit(vehicle, 0)
    
    if DisableVehicleNeonLights then
        DisableVehicleNeonLights(vehicle, false)
    end
    
    for i = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, i, true)
    end
    
    SetVehicleNeonLightsColour(vehicle, color.r, color.g, color.b)
    
    local props = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", props)
    setVehicleProperties(vehicle, props)
    
    local msg = t("neon_lights_installed") or "Neon lights installed"
    bridge.Notify.SendNotify(msg, "success")
    
    if callback then callback(true) end
    return true
end

function StartInstallXenon(rgbColor, callback)
    local vehicle = getNearbyVehicle()
    
    if not vehicle then
        local msg = t("no_vehicle_found") or "No vehicle found"
        bridge.Notify.SendNotify(msg, "error")
        if callback then callback(false) end
        return false
    end
    
    if not consumeItem("mechanic_xenon_light") then
        if callback then callback(false) end
        return false
    end
    
    if not doInstallAnimation("installing_xenon_lights", "Installing xenon lights...", 6500) then
        if callback then callback(false) end
        return false
    end
    
    local color = parseColor(rgbColor)
    
    SetVehicleModKit(vehicle, 0)
    ToggleVehicleMod(vehicle, 22, true)
    
    if SetVehicleXenonLightsCustomColor then
        SetVehicleXenonLightsCustomColor(vehicle, color.r, color.g, color.b)
    end
    
    local props = getVehicleProperties(vehicle)
    TriggerServerEvent("nn_mechanic:saveVehicleProps", props)
    setVehicleProperties(vehicle, props)
    
    local msg = t("xenon_lights_installed") or "Xenon lights installed"
    bridge.Notify.SendNotify(msg, "success")
    
    if callback then callback(true) end
    return true
end

-- Menu Functions
function OpenNeonInstallMenu(rgbColor)
    OpenLightsInstallMenu("neon", rgbColor)
end

function OpenXenonInstallMenu(rgbColor)
    OpenLightsInstallMenu("xenon", rgbColor)
end

function OpenLightsInstallMenu(type, rgbColor)
    local menuId = (type == "neon") and "neon_install_menu" or "xenon_install_menu"
    local label = (type == "neon") and t("install_neon_lights") or t("install_xenon_lights")
    local icon = (type == "neon") and "fas fa-lightbulb" or "fas fa-bolt"
    local nuiCallback = (type == "neon") and "installNeonLights" or "installXenonLights"
    
    local items = {{
        label = label,
        icon = icon,
        nuiCallback = nuiCallback,
        callbackData = { rgb = rgbColor }
    }}
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = { menuId = menuId, items = items }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = menuId
    StartMenuControlsThread()
end

function ShowLightsInstallConfirmationMenu(type, rgbColor, callback)
    local menuId = (type == "neon") and "neon_install_confirm_menu" or "xenon_install_confirm_menu"
    local label = (type == "neon") and t("install_neon_lights") or t("install_xenon_lights")
    local icon = (type == "neon") and "fas fa-lightbulb" or "fas fa-bolt"
    local nuiCallback = (type == "neon") and "confirmInstallNeon" or "confirmInstallXenon"
    
    local items = {
        {
            label = label,
            icon = icon,
            nuiCallback = nuiCallback,
            callbackData = { rgb = rgbColor, onComplete = true }
        },
        {
            label = t("cancel"),
            icon = "fas fa-xmark",
            nuiCallback = "cancelLightsInstall",
            callbackData = { onComplete = false }
        }
    }
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setMenuData",
        data = { menuId = menuId, items = items }
    })
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "menu" }
    })
    
    State.openPage = "menu"
    State.currentMenuId = menuId
    State.lightsInstallCallback = callback
    State.lightsInstallData = { lightType = type, rgb = rgbColor }
    StartMenuControlsThread()
end

-- Control Panel Functions
function LightsControl_DisconnectAndPersist()
    local lightsControl = State.lightsControl
    
    if lightsControl and lightsControl.connected and lightsControl.vehicle then
        local vehicle = lightsControl.vehicle
        
        if DoesEntityExist(vehicle) and lightsControl.hasNeon then
            local plate = GetVehicleNumberPlateText(vehicle)
            plate = plate and plate:gsub("%s+", "") or ""
            
            if plate ~= "" then
                local effect = lightsControl.neonEffect or "static"
                TriggerServerEvent("nn_mechanic:setVehicleNeonEffect", plate, effect)
                
                if lightsControl.neonRgb and type(lightsControl.neonRgb) == "table" then
                    local r = math.max(0, math.min(255, tonumber(lightsControl.neonRgb.r) or tonumber(lightsControl.neonRgb[1]) or 0))
                    local g = math.max(0, math.min(255, tonumber(lightsControl.neonRgb.g) or tonumber(lightsControl.neonRgb[2]) or 0))
                    local b = math.max(0, math.min(255, tonumber(lightsControl.neonRgb.b) or tonumber(lightsControl.neonRgb[3]) or 0))
                    local hexColor = string.format("#%02X%02X%02X", r, g, b)
                    TriggerServerEvent("nn_mechanic:setVehicleNeonColor", plate, hexColor)
                end
                
                if lightsControl.neonZones and type(lightsControl.neonZones) == "table" then
                    local zones = {
                        front = lightsControl.neonZones.front == true,
                        back = lightsControl.neonZones.back == true,
                        left = lightsControl.neonZones.left == true,
                        right = lightsControl.neonZones.right == true
                    }
                    TriggerServerEvent("nn_mechanic:setVehicleNeonZones", plate, json.encode(zones))
                end
            end
        end
        
        local props = getVehicleProperties(vehicle)
        TriggerServerEvent("nn_mechanic:saveVehicleProps", props)
        setVehicleProperties(vehicle, props)
    end
    
    if State.lightsControl then
        State.lightsControl.connected = false
        State.lightsControl.vehicle = nil
        State.lightsControl.hasNeon = nil
        State.lightsControl.hasXenon = nil
        State.lightsControl.neonEffect = nil
    end
end

-- Event Registration
RegisterNetEvent("nn_mechanic:useNeonLight", function()
    OpenNeonInstallMenu({ r = 255, g = 0, b = 0 })
end)

RegisterNetEvent("nn_mechanic:useXenonLight", function()
    OpenXenonInstallMenu({ r = 255, g = 255, b = 255 })
end)

RegisterNetEvent("nn_mechanic:openLightsControl", function()
    SetNuiFocus(true, true)
    DisplayRadar(false)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = true, page = "lights-control", action = "setVisible" }
    })
    State.openPage = "lights-control"
end)

-- Debug Commands
if Config.Debug then
    RegisterCommand("installneon", function()
        OpenNeonInstallMenu({ r = 255, g = 0, b = 0 })
    end)
    
    RegisterCommand("installxenon", function()
        OpenXenonInstallMenu({ r = 255, g = 255, b = 255 })
    end)
end

-- NUI Callbacks
RegisterNUICallback("confirmInstallNeon", function(data, cb)
    if State.openPage == "menu" and State.currentMenuId == "neon_install_confirm_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    local installData = State.lightsInstallData
    local callback = State.lightsInstallCallback
    State.lightsInstallCallback = nil
    State.lightsInstallData = nil
    
    if installData and installData.lightType == "neon" and installData.rgb then
        local success = StartInstallNeon(installData.rgb, callback)
        cb({ success = success == true })
    else
        if callback then callback(false) end
        cb({ success = false })
    end
end)

RegisterNUICallback("confirmInstallXenon", function(data, cb)
    if State.openPage == "menu" and State.currentMenuId == "xenon_install_confirm_menu" then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    local installData = State.lightsInstallData
    local callback = State.lightsInstallCallback
    State.lightsInstallCallback = nil
    State.lightsInstallData = nil
    
    if installData and installData.lightType == "xenon" and installData.rgb then
        local success = StartInstallXenon(installData.rgb, callback)
        cb({ success = success == true })
    else
        if callback then callback(false) end
        cb({ success = false })
    end
end)

RegisterNUICallback("cancelLightsInstall", function(data, cb)
    if State.openPage == "menu" and (State.currentMenuId == "neon_install_confirm_menu" or State.currentMenuId == "xenon_install_confirm_menu") then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    local callback = State.lightsInstallCallback
    State.lightsInstallCallback = nil
    State.lightsInstallData = nil
    
    if callback then callback(false) end
    cb({ success = true })
end)

RegisterNUICallback("installNeonLights", function(data, cb)
    if State.openPage == "menu" and (State.currentMenuId == "neon_install_menu" or State.currentMenuId == "lights_install_menu") then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    local rgb = data and data.rgb
    local success = StartInstallNeon(rgb)
    cb({ success = success == true })
end)

RegisterNUICallback("installXenonLights", function(data, cb)
    if State.openPage == "menu" and (State.currentMenuId == "xenon_install_menu" or State.currentMenuId == "lights_install_menu") then
        SendNUIMessage({
            action = "setVisibility",
            data = { visible = false, page = "menu" }
        })
        State.openPage = nil
        State.currentMenuId = nil
    end
    
    local rgb = data and data.rgb
    local success = StartInstallXenon(rgb)
    cb({ success = success == true })
end)

-- Lights Control Panel NUI Callbacks
RegisterNUICallback("lightsControlConnect", function(data, cb)
    local vehicle = getNearbyVehicle()
    
    if not vehicle then
        SendNUIMessage({
            action = "lightsControlConnectResult",
            data = { success = false, error = "no_vehicle_found" }
        })
        cb({ success = false })
        return
    end
    
    local hasNeon = IsAnyNeonLightEnabled(vehicle)
    local hasXenon = IsToggleModOn(vehicle, 22)
    
    if not hasNeon and not hasXenon then
        SendNUIMessage({
            action = "lightsControlConnectResult",
            data = { success = false, error = "no_lights_installed" }
        })
        cb({ success = false })
        return
    end
    
    State.lightsControl = State.lightsControl or {}
    State.lightsControl.connected = true
    State.lightsControl.vehicle = vehicle
    State.lightsControl.hasNeon = hasNeon
    State.lightsControl.hasXenon = hasXenon
    
    if hasNeon then
        State.lightsControl.neonRgb = GetNeonLightsColor(vehicle)
    end
    
    local neonEffect = "static"
    if hasNeon and bridge and bridge.Callback and bridge.Callback.Trigger then
        local plate = GetVehicleNumberPlateText(vehicle)
        plate = plate and plate:gsub("%s+", "") or ""
        if plate ~= "" then
            local effect = bridge.Callback.Trigger("nn_mechanic:getVehicleNeonEffect", plate)
            if type(effect) == "string" and effect ~= "" then
                neonEffect = effect
            end
        end
    end
    State.lightsControl.neonEffect = neonEffect
    
    local neonZones = nil
    if hasNeon and bridge and bridge.Callback and bridge.Callback.Trigger then
        local plate = GetVehicleNumberPlateText(vehicle)
        plate = plate and plate:gsub("%s+", "") or ""
        if plate ~= "" then
            local zonesJson = bridge.Callback.Trigger("nn_mechanic:getVehicleNeonZones", plate)
            neonZones = ParseNeonZones(zonesJson)
        end
    end
    State.lightsControl.neonZones = neonZones or (hasNeon and GetNeonZonesState(vehicle) or nil)
    
    SendNUIMessage({
        action = "lightsControlConnectResult",
        data = {
            success = true,
            hasNeon = hasNeon,
            hasXenon = hasXenon,
            neonRgb = hasNeon and GetNeonLightsColor(vehicle) or nil,
            xenonRgb = hasXenon and GetXenonLightsColor(vehicle) or nil,
            neonSides = hasNeon and (neonZones or GetNeonZonesState(vehicle)) or nil,
            neonEffect = hasNeon and neonEffect or nil
        }
    })
    
    cb({ success = true })
end)

RegisterNUICallback("lightsControlSetColor", function(data, cb)
    local lightsControl = State.lightsControl
    
    if not lightsControl or not lightsControl.connected or not lightsControl.vehicle or not DoesEntityExist(lightsControl.vehicle) then
        cb({ success = false })
        return
    end
    
    local mode = data and data.mode
    local color = parseColor(data and data.rgb)
    
    if mode == "neon" then
        if not lightsControl.hasNeon then
            cb({ success = false })
            return
        end
        
        lightsControl.neonRgb = color
        
        if data and type(data.effect) == "string" and data.effect ~= "" then
            lightsControl.neonEffect = data.effect
        end
        
        if data and type(data.sides) == "table" then
            lightsControl.neonZones = {
                front = data.sides.front == true,
                back = data.sides.back == true,
                left = data.sides.left == true,
                right = data.sides.right == true
            }
        end
        
        local zones = lightsControl.neonZones or {}
        local left = zones.left == true
        local right = zones.right == true
        local front = zones.front == true
        local back = zones.back == true
        
        if DisableVehicleNeonLights then
            DisableVehicleNeonLights(lightsControl.vehicle, false)
        end
        
        SetVehicleNeonLightEnabled(lightsControl.vehicle, 0, left)
        SetVehicleNeonLightEnabled(lightsControl.vehicle, 1, right)
        SetVehicleNeonLightEnabled(lightsControl.vehicle, 2, front)
        SetVehicleNeonLightEnabled(lightsControl.vehicle, 3, back)
        SetVehicleNeonLightsColour(lightsControl.vehicle, color.r, color.g, color.b)
        
        cb({ success = true })
        return
    end
    
    if mode == "xenon" then
        if not lightsControl.hasXenon then
            cb({ success = false })
            return
        end
        
        SetVehicleModKit(lightsControl.vehicle, 0)
        ToggleVehicleMod(lightsControl.vehicle, 22, true)
        
        if SetVehicleXenonLightsCustomColor then
            SetVehicleXenonLightsCustomColor(lightsControl.vehicle, color.r, color.g, color.b)
        end
        
        cb({ success = true })
        return
    end
    
    cb({ success = false })
end)

RegisterNUICallback("lightsControlDisconnect", function(data, cb)
    if data and type(data.neonEffect) == "string" and data.neonEffect ~= "" then
        State.lightsControl = State.lightsControl or {}
        State.lightsControl.neonEffect = data.neonEffect
    end
    
    LightsControl_DisconnectAndPersist()
    
    SendNUIMessage({
        action = "lightsControlDisconnected",
        data = {}
    })
    
    cb({ success = true })
end)

function IsAnyNeonLightEnabled(vehicle)
    for i = 0, 3 do
        if IsVehicleNeonLightEnabled(vehicle, i) then
            return true
        end
    end
    return false
end

function GetNeonLightsColor(vehicle)
    if GetVehicleNeonLightsColour then
        local r, g, b = GetVehicleNeonLightsColour(vehicle)
        return parseColor({ r = r, g = g, b = b })
    end
    return { r = 255, g = 255, b = 255 }
end

function GetNeonZonesState(vehicle)
    return {
        left = IsVehicleNeonLightEnabled(vehicle, 0),
        right = IsVehicleNeonLightEnabled(vehicle, 1),
        front = IsVehicleNeonLightEnabled(vehicle, 2),
        back = IsVehicleNeonLightEnabled(vehicle, 3)
    }
end

function ParseNeonZones(jsonString)
    if type(jsonString) ~= "string" or jsonString == "" then
        return nil
    end
    
    local data = json.decode(jsonString)
    return {
        front = data.front == true,
        back = data.back == true,
        left = data.left == true,
        right = data.right == true
    }
end

function GetXenonLightsColor(vehicle)
    if GetVehicleXenonLightsCustomColor then
        local r, g, b = GetVehicleXenonLightsCustomColor(vehicle)
        return parseColor({ r = r, g = g, b = b })
    end
    return { r = 255, g = 255, b = 255 }
end