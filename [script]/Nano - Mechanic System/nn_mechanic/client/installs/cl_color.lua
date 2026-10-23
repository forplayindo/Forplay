local openColorMixingStationFunc, registerNUICallbackRef, colorMixingResultName, colorMixingResultHandler

function openColorMixingStationFunc()
    local hasEmptySprayGun = bridge.Callback.Trigger("nn_mechanic:hasEmptySprayGun")
    if not hasEmptySprayGun then
        bridge.Notify.SendNotify("You need an empty spray gun to mix colors.", "error")
        return
    end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "color-mixing"
        }
    })
    SendNUIMessage({
        action = "setColorMixingData",
        data = {
            title = "Respray Color Mix"
        }
    })
    State.openPage = "color-mixing"
    DisplayRadar(false)
    TriggerScreenblurFadeIn(500)
end
OpenColorMixingStation = openColorMixingStationFunc

local function closeColorMixingStation()
    TriggerScreenblurFadeOut(500)
    SetNuiFocus(false, false)
    DisplayRadar(true)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "color-mixing"
        }
    })
    State.openPage = nil
end

registerNUICallbackRef = RegisterNUICallback
colorMixingResultName = "ColorMixingResult"

function colorMixingResultHandler(data, callback)
    if data and data.success == true and data.mixed then
        TriggerServerEvent("nn_mechanic:finalizeColorMixingSprayGun", {
            success = true,
            rgb = data.mixed,
            hex = data.mixed.hex,
            paintType = data.paintType,
            target = data.target
        })
        closeColorMixingStation()
        callback({success = true})
    else
        bridge.Notify.SendNotify("Color mixing failed.", "error")
        closeColorMixingStation()
        callback({success = false})
    end
end

registerNUICallbackRef(colorMixingResultName, colorMixingResultHandler)