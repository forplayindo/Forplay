local isDashboardOpen = false
local dashboardUpdateThread = nil

function GetVehicleDashboardData(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
        local entityBag = string.format("entity:%d", vehicleNetId)
        
        local engineHealth = math.max(0, math.min(100, GetVehicleEngineHealth(vehicle) / 10.0))
        local fuelLevel = math.max(0, math.min(100, GetVehicleFuelLevel(vehicle)))
        
        local vehicleClass = GetVehicleClass(vehicle)
        local wheelIndices = GetWheelIndicesForClass(vehicleClass)
        
        local totalTireHealth = 0.0
        for _, wheelIndex in ipairs(wheelIndices) do
            local tireHealth = GetStateBagValue(entityBag, string.format("ns_tr%d", wheelIndex))
            if tireHealth then
                tireHealth = tireHealth / 100.0
            else
                tireHealth = 100.0
            end
            totalTireHealth = totalTireHealth + tireHealth
        end
        
        local averageTireHealth = math.max(0, math.min(100, totalTireHealth / #wheelIndices))
        
        local brakeFront = GetStateBagValue(entityBag, "ns_brake_front")
        local brakeRear = GetStateBagValue(entityBag, "ns_brake_rear")
        
        if brakeFront then
            brakeFront = brakeFront / 100.0
        else
            brakeFront = 100.0
        end
        
        if brakeRear then
            brakeRear = brakeRear / 100.0
        else
            brakeRear = 100.0
        end
        
        local averageBrakeHealth = math.max(0, math.min(100, (brakeFront + brakeRear) / 2.0))
        
        local oilQuality = GetStateBagValue(entityBag, "ns_oil_quality")
        if oilQuality then
            oilQuality = math.max(0, math.min(100, oilQuality / 100.0))
        else
            oilQuality = 100.0
        end
        
        return {
            engineHealth = engineHealth,
            engineOil = oilQuality,
            tireHealth = averageTireHealth,
            brakePadHealth = averageBrakeHealth,
            fuel = fuelLevel
        }
    end
    return nil
end

function OpenDashboard()
    if isDashboardOpen then
        return
    end
    
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then
        bridge.Notify.SendNotify(t("not_in_vehicle"), "error")
        return
    end
    
    isDashboardOpen = true
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "vehicle-dashboard"
        }
    })
    
    local dashboardData = GetVehicleDashboardData(vehicle)
    if dashboardData then
        SendNUIMessage({
            action = "vehicleDashboardUpdate",
            data = dashboardData
        })
    end
    
    dashboardUpdateThread = Citizen.CreateThread(function()
        while true do
            if not isDashboardOpen then
                break
            end
            
            local ped = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(ped, false)
            
            if not currentVehicle or currentVehicle == 0 then
                CloseDashboard()
                return
            end
            
            local updatedData = GetVehicleDashboardData(currentVehicle)
            if updatedData then
                SendNUIMessage({
                    action = "vehicleDashboardUpdate",
                    data = updatedData
                })
            end
            
            Wait(1000)
        end
    end)
end

function CloseDashboard()
    if not isDashboardOpen then
        return
    end
    
    isDashboardOpen = false
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = nil
        }
    })
end

RegisterNUICallback("closeDashboard", function(data, cb)
    CloseDashboard()
    cb("ok")
end)

RegisterCommand("dashboard", function()
    if isDashboardOpen then
        CloseDashboard()
    else
        OpenDashboard()
    end
end, false)

RegisterKeyMapping("dashboard", "Toggle Vehicle Dashboard", "keyboard", Config.Dashboard.Key)