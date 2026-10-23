RegisterNUICallback("createRole", function(data, cb)
    TriggerServerEvent(Events.Role.Create, data)
    cb("ok")
end)

RegisterNUICallback("updateRole", function(data, cb)
    TriggerServerEvent(Events.Role.Update, data)
    cb("ok")
end)

RegisterNUICallback("deleteRole", function(data, cb)
    TriggerServerEvent(Events.Role.Delete, data)
    cb("ok")
end)

RegisterNUICallback("updateEmployee", function(data, cb)
    TriggerServerEvent("nn_mechanic:updateEmployee", {
        shopId = data.shopId,
        employeeId = data.id,
        updates = data
    })
    cb("ok")
end)

RegisterNUICallback("inviteEmployee", function(data, cb)
    TriggerServerEvent("nn_mechanic:hireEmployee", State.shop.id)
    cb("ok")
end)

RegisterNUICallback("fireEmployee", function(data, cb)
    TriggerServerEvent("nn_mechanic:fireEmployee", {
        shopId = data.shopId,
        employeeId = data.employeeId
    })
    cb("ok")
end)

RegisterNUICallback("depositMoney", function(data, cb)
    TriggerServerEvent("nn_mechanic:depositMoney", data)
    cb("ok")
end)

RegisterNUICallback("withdrawMoney", function(data, cb)
    TriggerServerEvent("nn_mechanic:withdrawMoney", data)
    cb("ok")
end)

RegisterNUICallback("payAllSalaries", function(data, cb)
    TriggerServerEvent("nn_mechanic:payAllSalaries", data)
    cb("ok")
end)

RegisterNUICallback("updateShopInformation", function(data, cb)
    TriggerServerEvent("nn_mechanic:updateShopInformation", data)
    cb("ok")
end)

RegisterNUICallback("purchaseVehicleUpgrade", function(data, cb)
    TriggerServerEvent("nn_mechanic:purchaseVehicleUpgrade", data)
    cb("ok")
end)

RegisterNUICallback("toggleVehicleUpgradeMarker", function(data, cb)
    TriggerServerEvent("nn_mechanic:toggleVehicleUpgradeMarker", data)
    cb("ok")
end)

RegisterNUICallback("updatePoint", function(data, cb)
    TriggerServerEvent("nn_mechanic:updatePoint", data)
    cb("ok")
end)

RegisterNUICallback("removePoint", function(data, cb)
    TriggerServerEvent("nn_mechanic:removePoint", data)
    cb("ok")
end)

RegisterNUICallback("nn_mechanic:startVehicleLocationCapture", function(data, cb)
    State.vehicleUpgradeCapture.isCapturing = true
    State.vehicleUpgradeCapture.upgradeId = data.upgradeId
    State.vehicleUpgradeCapture.locationType = data.locationType
    State.vehicleUpgradeCapture.shopId = data.shopId
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "management" }
    })
    TriggerScreenblurFadeOut(500)
    
    bridge.HelpText.ShowHelpText(t("move_to_desired_location_enter_confirm_esc_cancel"))
    
    Citizen.CreateThread(function()
        while State.vehicleUpgradeCapture.isCapturing do
            local coords = roundCoords(GetEntityCoords(State.Ped))
            local heading = GetEntityHeading(State.Ped)
            
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 132, 221, 111, 100, false, true, 2, false, nil, nil, false)
            
            if IsControlJustPressed(0, 18) then
                State.vehicleUpgradeCapture.isCapturing = false
                bridge.HelpText.HideHelpText()
                
                local locationData = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                
                local interactionLocation = nil
                if State.vehicleUpgradeCapture.locationType == "interaction" then
                    interactionLocation = locationData
                end
                
                local vehicleSpawnLocation = nil
                if State.vehicleUpgradeCapture.locationType == "vehicle" then
                    vehicleSpawnLocation = locationData
                end
                
                TriggerServerEvent("nn_mechanic:updateVehicleUpgradeLocations", {
                    shopId = State.vehicleUpgradeCapture.shopId,
                    upgradeId = State.vehicleUpgradeCapture.upgradeId,
                    interactionLocation = interactionLocation,
                    vehicleSpawnLocation = vehicleSpawnLocation
                })
                
                cb(locationData)
                Citizen.Wait(100)
                OpenManagement()
                break
            end
            
            if IsControlJustPressed(0, 322) then
                State.vehicleUpgradeCapture.isCapturing = false
                bridge.HelpText.HideHelpText()
                cb(nil)
                Citizen.Wait(100)
                OpenManagement()
                break
            end
            
            Wait(0)
        end
    end)
end)

RegisterNUICallback("nn_mechanic:startPointLocationCapture", function(data, cb)
    State.pointCapture.isCapturing = true
    State.pointCapture.pointId = data.pointId
    State.pointCapture.pointName = data.pointName
    State.pointCapture.pointType = data.pointType
    State.pointCapture.shopId = data.shopId
    State.pointCapture.captureMode = data.captureMode or "interaction"
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = "management" }
    })
    TriggerScreenblurFadeOut(500)
    
    local r, g, b = 132, 221, 111
    if State.pointCapture.captureMode == "spawn" then
        r, g, b = 245, 158, 11
    end
    
    bridge.HelpText.ShowHelpText(t("move_to_desired_location_enter_confirm_esc_cancel"))
    
    Citizen.CreateThread(function()
        while State.pointCapture.isCapturing do
            local coords = roundCoords(GetEntityCoords(State.Ped))
            local heading = GetEntityHeading(State.Ped)
            
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, r, g, b, 100, false, true, 2, false, nil, nil, false)
            
            if IsControlJustPressed(0, 18) then
                State.pointCapture.isCapturing = false
                bridge.HelpText.HideHelpText()
                
                local locationData = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                
                if State.pointCapture.captureMode == "spawn" then
                    TriggerServerEvent("nn_mechanic:updatePoint", {
                        shopId = State.pointCapture.shopId,
                        pointId = State.pointCapture.pointId,
                        updates = { spawnCoords = locationData }
                    })
                else
                    if data.isMoveOperation then
                        TriggerServerEvent("nn_mechanic:updatePoint", {
                            shopId = State.pointCapture.shopId,
                            pointId = State.pointCapture.pointId,
                            updates = { coords = locationData }
                        })
                    else
                        TriggerServerEvent("nn_mechanic:addPoint", {
                            shopId = State.pointCapture.shopId,
                            name = State.pointCapture.pointName,
                            type = State.pointCapture.pointType,
                            coords = locationData,
                            enabled = true
                        })
                    end
                end
                
                cb(locationData)
                Citizen.Wait(100)
                OpenManagement()
                break
            end
            
            if IsControlJustPressed(0, 322) then
                State.pointCapture.isCapturing = false
                bridge.HelpText.HideHelpText()
                cb(nil)
                Citizen.Wait(100)
                OpenManagement()
                break
            end
            
            Wait(0)
        end
    end)
end)

local DynoSetup = {
    isSetup = false,
    shopId = nil,
    pointId = nil,
    step = 1,
    tvStand = nil,
    platform = nil
}

local function CancelDynoSetup()
    DynoSetup.isSetup = false
    DynoSetup.shopId = nil
    DynoSetup.pointId = nil
    DynoSetup.step = 1
    DynoSetup.tvStand = nil
    DynoSetup.platform = nil
    bridge.HelpText.HideHelpText()
end

local function CompleteDynoSetup()
    if DynoSetup.tvStand and DynoSetup.platform then
        TriggerServerEvent("nn_mechanic:updatePoint", {
            shopId = DynoSetup.shopId,
            pointId = DynoSetup.pointId,
            updates = {
                dyno = {
                    tvStand = DynoSetup.tvStand,
                    platform = DynoSetup.platform,
                    configured = true
                }
            }
        })
        bridge.Notify.SendNotify(t("dyno_configured"), "success")
    end
    CancelDynoSetup()
    Wait(100)
    OpenManagement()
end

local function DynoSetupStep2()
    DynoSetup.step = 2
    bridge.HelpText.ShowHelpText(t("dyno_place_platform"))
    Citizen.CreateThread(function()
        while DynoSetup.isSetup and DynoSetup.step == 2 do
            local coords = roundCoords(GetEntityCoords(State.Ped))
            local heading = GetEntityHeading(State.Ped)
            
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 2.0, 0.5, 239, 68, 68, 100, false, true, 2, false, nil, nil, false)
            
            local forwardVec = GetEntityForwardVector(State.Ped)
            local targetPos = vector3(coords.x, coords.y, coords.z) + (forwardVec * 2.5)
            
            DrawMarker(2, targetPos.x, targetPos.y, coords.z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 239, 68, 68, 200, false, true, 2, false, nil, nil, false)
            
            if IsControlJustPressed(0, 18) then
                bridge.HelpText.HideHelpText()
                DynoSetup.platform = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                bridge.Notify.SendNotify(t("dyno_platform_placed"), "success")
                CompleteDynoSetup()
                break
            end
            
            if IsControlJustPressed(0, 322) then
                bridge.Notify.SendNotify(t("placement_cancelled"), "error")
                CancelDynoSetup()
                Wait(100)
                OpenManagement()
                break
            end
            
            Wait(0)
        end
    end)
end

local function DynoSetupStep1()
    DynoSetup.step = 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "management" } })
    TriggerScreenblurFadeOut(500)
    
    bridge.HelpText.ShowHelpText(t("dyno_place_tv_stand"))
    
    local coords, heading = bridge.Placeable.PlaceObject("prop_cs_tv_stand", 15.0, true)
    
    if coords and heading then
        DynoSetup.tvStand = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
        bridge.Notify.SendNotify(t("dyno_tv_stand_placed"), "success")
        DynoSetupStep2()
    else
        bridge.Notify.SendNotify(t("placement_cancelled"), "error")
        CancelDynoSetup()
        Wait(100)
        OpenManagement()
    end
end

RegisterNUICallback("nn_mechanic:startDynoSetup", function(data, cb)
    if DynoSetup.isSetup then
        cb({ success = false })
        return
    end
    
    DynoSetup.isSetup = true
    DynoSetup.shopId = data.shopId
    DynoSetup.pointId = data.pointId
    
    DynoSetupStep1()
    cb({ success = true })
end)

local LiftSetup = {
    isSetup = false,
    shopId = nil,
    pointId = nil,
    style = nil,
    step = 1,
    bodyCoords = nil,
    previewBody = nil,
    previewArms = nil
}

local LiftStyles = {
    [1] = { body = "nano_lift_body_1", arms = "nano_lift_arms_1" },
    [2] = { body = "nano_lift_body_2", arms = "nano_lift_arms_2" }
}

local function CancelLiftSetup()
    if LiftSetup.previewBody and DoesEntityExist(LiftSetup.previewBody) then
        DeleteEntity(LiftSetup.previewBody)
    end
    if LiftSetup.previewArms and DoesEntityExist(LiftSetup.previewArms) then
        DeleteEntity(LiftSetup.previewArms)
    end
    
    LiftSetup.isSetup = false
    LiftSetup.shopId = nil
    LiftSetup.pointId = nil
    LiftSetup.style = nil
    LiftSetup.step = 1
    LiftSetup.bodyCoords = nil
    LiftSetup.previewBody = nil
    LiftSetup.previewArms = nil
    
    bridge.HelpText.HideHelpText()
end

local function CompleteLiftSetup()
    if LiftSetup.bodyCoords then
        local liftName = string.format("shop_%s_lift_%s", LiftSetup.shopId, LiftSetup.pointId)
        if DeleteCarLift then DeleteCarLift(liftName) end
        
        TriggerServerEvent("nn_mechanic:updatePoint", {
            shopId = LiftSetup.shopId,
            pointId = LiftSetup.pointId,
            updates = {
                spawnCoords = LiftSetup.bodyCoords,
                lift = {
                    style = LiftSetup.style,
                    configured = true
                }
            }
        })
        
        bridge.Notify.SendNotify(t("lift_setup_complete"), "success")
        
        Citizen.CreateThread(function()
            Wait(500)
            if BuildRuntimeLifts then BuildRuntimeLifts() end
            if SetupLiftZones then SetupLiftZones() end
        end)
    end
    
    CancelLiftSetup()
    Wait(100)
    OpenManagement()
end

local function LiftSetupStep2()
    LiftSetup.step = 2
    bridge.HelpText.ShowHelpText(t("lift_set_interaction"))
    
    Citizen.CreateThread(function()
        while LiftSetup.isSetup and LiftSetup.step == 2 do
            local coords = roundCoords(GetEntityCoords(State.Ped))
            local heading = GetEntityHeading(State.Ped)
            
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 6, 182, 212, 100, false, true, 2, false, nil, nil, false)
            
            if IsControlJustPressed(0, 18) then
                bridge.HelpText.HideHelpText()
                TriggerServerEvent("nn_mechanic:updatePoint", {
                    shopId = LiftSetup.shopId,
                    pointId = LiftSetup.pointId,
                    updates = {
                        coords = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                    }
                })
                bridge.Notify.SendNotify(t("lift_interaction_set"), "success")
                CompleteLiftSetup()
                break
            elseif IsControlJustPressed(0, 177) then -- [BACKSPACE] cancellation logic
                bridge.HelpText.HideHelpText()
                bridge.Notify.SendNotify(t("placement_cancelled"), "error")
                CancelLiftSetup()
                Wait(100)
                OpenManagement()
                break
            end
            
            if IsControlJustPressed(0, 322) then
                bridge.Notify.SendNotify(t("placement_cancelled"), "error")
                CancelLiftSetup()
                Wait(100)
                OpenManagement()
                break
            end
            
            Wait(0)
        end
    end)
end

local function PreviewLift(coords, heading, styleIndex)
    local style = Config.NanoLiftStyles and Config.NanoLiftStyles[styleIndex]
    if not style then return nil, nil end
    
    local bodyModel = GetHashKey(style.body)
    RequestModel(bodyModel)
    while not HasModelLoaded(bodyModel) do Wait(10) end
    
    local bodyEntity = CreateObject(bodyModel, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(bodyEntity, heading)
    FreezeEntityPosition(bodyEntity, true)
    SetEntityAsMissionEntity(bodyEntity, true, true)
    SetModelAsNoLongerNeeded(bodyModel)
    
    local armsEntity = nil
    if style.arms then
        local armsModel = GetHashKey(style.arms)
        RequestModel(armsModel)
        while not HasModelLoaded(armsModel) do Wait(10) end
        
        local offset = style.armsOffset or vector3(0.0, 0.0, 0.0)
        local rot = style.armsRotation or vector3(0.0, 0.0, 0.0)
        
        local radHeading = math.rad(heading)
        local dx = (offset.x * math.cos(radHeading)) - (offset.y * math.sin(radHeading))
        local dy = (offset.x * math.sin(radHeading)) + (offset.y * math.cos(radHeading))
        
        armsEntity = CreateObject(armsModel, coords.x + dx, coords.y + dy, coords.z + offset.z, false, false, false)
        SetEntityHeading(armsEntity, heading + rot.z)
        FreezeEntityPosition(armsEntity, true)
        SetEntityAsMissionEntity(armsEntity, true, true)
        SetModelAsNoLongerNeeded(armsModel)
    end
    
    return bodyEntity, armsEntity
end

local function LiftSetupStep1()
    LiftSetup.step = 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "management" } })
    TriggerScreenblurFadeOut(500)
    
    bridge.HelpText.ShowHelpText(t("lift_place_body"))
    
    local bodyProp = LiftStyles[LiftSetup.style] and LiftStyles[LiftSetup.style].body or "nano_lift_body_1"
    
    local coords, heading = bridge.Placeable.PlaceObject(bodyProp, 15.0, true)
    if coords and heading then
        LiftSetup.bodyCoords = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
        bridge.Notify.SendNotify(t("lift_body_placed"), "success")
        
        LiftSetup.previewBody, LiftSetup.previewArms = PreviewLift(coords, heading, LiftSetup.style)
        LiftSetupStep2()
    else
        bridge.Notify.SendNotify(t("placement_cancelled"), "error")
        CancelLiftSetup()
        Wait(100)
        OpenManagement()
    end
end

RegisterNUICallback("nn_mechanic:startLiftSetup", function(data, cb)
    if LiftSetup.isSetup then
        cb({ success = false })
        return
    end
    
    LiftSetup.isSetup = true
    LiftSetup.shopId = data.shopId
    LiftSetup.pointId = data.pointId
    LiftSetup.style = data.style or 1
    
    LiftSetupStep1()
    cb({ success = true })
end)

RegisterNUICallback("nn_mechanic:startLiftBodyPlacement", function(data, cb)
    if LiftSetup.isSetup then
        cb({ success = false })
        return
    end
    
    local pointData = nil
    if State.shop and State.shop.points then
        pointData = State.shop.points[data.pointId]
    end
    
    LiftSetup.isSetup = true
    LiftSetup.shopId = data.shopId
    LiftSetup.pointId = data.pointId
    LiftSetup.style = (pointData and pointData.lift and pointData.lift.style) or 1
    
    local liftName = string.format("shop_%s_lift_%s", data.shopId, data.pointId)
    if DeleteCarLift then DeleteCarLift(liftName) end
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "management" } })
    TriggerScreenblurFadeOut(500)
    
    bridge.HelpText.ShowHelpText(t("lift_place_body"))
    
    local bodyProp = LiftStyles[LiftSetup.style] and LiftStyles[LiftSetup.style].body or "nano_lift_body_1"
    
    local coords, heading = bridge.Placeable.PlaceObject(bodyProp, 15.0, true)
    if coords and heading then
        TriggerServerEvent("nn_mechanic:updatePoint", {
            shopId = LiftSetup.shopId,
            pointId = LiftSetup.pointId,
            updates = {
                spawnCoords = { x = coords.x, y = coords.y, z = coords.z, heading = heading },
                lift = { style = LiftSetup.style, configured = true }
            }
        })
        bridge.Notify.SendNotify(t("lift_body_placed"), "success")
        
        Citizen.CreateThread(function()
            Wait(500)
            if BuildRuntimeLifts then BuildRuntimeLifts() end
            if SetupLiftZones then SetupLiftZones() end
        end)
    else
        bridge.Notify.SendNotify(t("placement_cancelled"), "error")
    end
    
    CancelLiftSetup()
    Wait(100)
    OpenManagement()
    
    cb({ success = true })
end)

RegisterNUICallback("nn_mechanic:startLiftInteractionPlacement", function(data, cb)
    if LiftSetup.isSetup then
        cb({ success = false })
        return
    end
    
    LiftSetup.isSetup = true
    LiftSetup.shopId = data.shopId
    LiftSetup.pointId = data.pointId
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "management" } })
    TriggerScreenblurFadeOut(500)
    
    bridge.HelpText.ShowHelpText(t("lift_set_interaction"))
    
    Citizen.CreateThread(function()
        while LiftSetup.isSetup do
            local coords = roundCoords(GetEntityCoords(State.Ped))
            local heading = GetEntityHeading(State.Ped)
            
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 6, 182, 212, 100, false, true, 2, false, nil, nil, false)
            
            if IsControlJustPressed(0, 18) then
                bridge.HelpText.HideHelpText()
                TriggerServerEvent("nn_mechanic:updatePoint", {
                    shopId = LiftSetup.shopId,
                    pointId = LiftSetup.pointId,
                    updates = {
                        coords = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
                    }
                })
                bridge.Notify.SendNotify(t("lift_interaction_set"), "success")
                
                Citizen.CreateThread(function()
                    Wait(500)
                    if BuildRuntimeLifts then BuildRuntimeLifts() end
                    if SetupLiftZones then SetupLiftZones() end
                end)
                
                CancelLiftSetup()
                Wait(100)
                OpenManagement()
                break
            elseif IsControlJustPressed(0, 177) then -- BACKSPACE
                bridge.HelpText.HideHelpText()
                bridge.Notify.SendNotify(t("placement_cancelled"), "error")
                CancelLiftSetup()
                Wait(100)
                OpenManagement()
                break
            end
            
            Wait(0)
        end
    end)
    
    cb({ success = true })
end)

local ColorMixingSetup = {
    isPlacing = false,
    defaultProp = "prop_paints_bench01"
}

local function CancelColorMixingPlacement()
    ColorMixingSetup.isPlacing = false
    bridge.HelpText.HideHelpText()
end

local function RefreshColorMixingStations()
    if SetupColorMixingStations then
        if CleanupColorMixingStations then CleanupColorMixingStations() end
        SetupColorMixingStations()
    end
end

RegisterNUICallback("nn_mechanic:startColorMixingTablePlacement", function(data, cb)
    if ColorMixingSetup.isPlacing then
        cb({ success = false })
        return
    end
    
    ColorMixingSetup.isPlacing = true
    local mode = data.mode or "add"
    local shopId = data.shopId
    local pointId = data.pointId
    local pointName = data.pointName
    local prop = data.prop and data.prop ~= "" and data.prop or ColorMixingSetup.defaultProp
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibility", data = { visible = false, page = "management" } })
    TriggerScreenblurFadeOut(500)
    
    local helpText = t("color_mixing_place_table") or "Place the color mixing table - [E] confirm / [BACKSPACE] cancel"
    bridge.HelpText.ShowHelpText(helpText)
    
    local existingEntity = nil
    if mode == "replace" and State.colorMixingStations and State.colorMixingStations[pointId] then
        existingEntity = State.colorMixingStations[pointId]
        if DoesEntityExist(existingEntity) then
            SetEntityVisible(existingEntity, false, false)
        end
    end
    
    local coords, heading = bridge.Placeable.PlaceObject(prop, 8.0, true)
    
    if existingEntity and DoesEntityExist(existingEntity) then
        SetEntityVisible(existingEntity, true, false)
    end
    
    if not coords or not heading then
        local msg = t("placement_cancelled") or "error"
        bridge.Notify.SendNotify(msg, "error")
        CancelColorMixingPlacement()
        Wait(100)
        OpenManagement()
        cb({ success = false })
        return
    end
    
    local locationData = { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    
    if mode == "replace" and pointId then
        TriggerServerEvent("nn_mechanic:updatePoint", {
            shopId = shopId,
            pointId = pointId,
            updates = { coords = locationData, prop = prop }
        })
        local msg = t("color_mixing_table_moved") or "Color mixing table moved."
        bridge.Notify.SendNotify(msg, "success")
    else
        local name = data.pointName and data.pointName ~= "" and data.pointName or (t("color_mixing_point") or "Color Mixing Table")
        TriggerServerEvent("nn_mechanic:addPoint", {
            shopId = shopId,
            name = name,
            type = "color_mixing",
            coords = locationData,
            enabled = true,
            prop = prop
        })
        local msg = t("color_mixing_table_placed") or "Color mixing table placed."
        bridge.Notify.SendNotify(msg, "success")
    end
    
    CancelColorMixingPlacement()
    Citizen.SetTimeout(800, function()
        RefreshColorMixingStations()
    end)
    
    Wait(100)
    OpenManagement()
    cb({ success = true })
end)