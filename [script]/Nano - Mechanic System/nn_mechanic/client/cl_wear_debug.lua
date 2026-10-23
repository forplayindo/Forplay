local isDebugActive = false

RegisterNetEvent("nn_mechanic:wearDebugToggled", function(state)
    isDebugActive = state
    if state then
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = true,
                page = "wear-debug"
            }
        })
    else
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = false,
                page = nil
            }
        })
    end
end)

RegisterNetEvent("nn_mechanic:wearDebugTick", function(before, after, telemetry)
    if not isDebugActive then return end
    
    SendNUIMessage({
        action = "wearDebugTick",
        data = {
            before = before,
            after = after,
            telemetry = telemetry,
            timestamp = GetGameTimer()
        }
    })
end)

RegisterNUICallback("closeWearDebug", function(data, cb)
    isDebugActive = false
    TriggerServerEvent("nn_mechanic:toggleWearDebug")
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = nil
        }
    })
    cb("ok")
end)

if Config.Debug then
    RegisterCommand("weardebug", function()
        TriggerServerEvent("nn_mechanic:toggleWearDebug")
    end, false)
end