CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(playerPed, false)
        
        if not isInVehicle then
            Wait(Config.TireWear.tick.parked_ms)
        else
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == 0 then
                Wait(Config.TireWear.tick.parked_ms)
            else
                local speed = GetEntitySpeed(vehicle) * 3.6
                Telemetry.collect(vehicle)
                
                if Telemetry.shouldPublish(speed, Config.TireWear) then
                    Telemetry.publish(Config.TireWear.net.telemKey, Config.TireWear)
                end
                Wait(Config.TireWear.tick.driving_ms)
            end
        end
    end
end)