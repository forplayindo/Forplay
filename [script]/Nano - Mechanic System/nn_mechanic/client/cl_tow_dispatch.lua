local towCalls = {}
local myActiveCallId = nil
local towRouteBlip = nil

State.DispatchOpen = false

local function getStreetAndZoneFromCoord(coords)
    local streetHash, crossStreetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)

    if 0 ~= crossStreetHash then
        local crossStreetName = GetStreetNameFromHashKey(crossStreetHash)
        if crossStreetName and "" ~= crossStreetName then
            streetName = streetName .. " / " .. crossStreetName
        end
    end

    local zoneName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zoneName and "YOURPROPERTY" ~= zoneName and "" ~= zoneName then
        streetName = streetName .. ", " .. zoneName
    end

    return streetName
end

local function getVehicleName(vehicle)
    local exists = DoesEntityExist(vehicle)
    if not exists then
        return "Unknown Vehicle"
    end

    local modelHash = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(modelHash)
    local labelText = GetLabelText(displayName)

    if labelText and "NULL" ~= labelText then
        return labelText
    end

    return displayName
end

local function getVehicleColors(vehicle)
    local exists = DoesEntityExist(vehicle)
    if not exists then
        return "Unknown"
    end

    local color1, color2 = GetVehicleColours(vehicle)
    return GetVehicleColorName(color1, color2)
end

local function SetTowRoute(x, y, z)
    ClearTowRoute()
    towRouteBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(towRouteBlip, 477)
    SetBlipColour(towRouteBlip, 5)
    SetBlipScale(towRouteBlip, 1.1)
    SetBlipRoute(towRouteBlip, true)
    SetBlipRouteColour(towRouteBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Tow Call Location")
    EndTextCommandSetBlipName(towRouteBlip)
end

local function ClearTowRoute()
    if towRouteBlip then
        if DoesBlipExist(towRouteBlip) then
            SetBlipRoute(towRouteBlip, false)
            RemoveBlip(towRouteBlip)
            towRouteBlip = nil
        end
    end
end

local function OpenTowDispatch()
    if State.DispatchOpen then
        return
    end

    local canOpen = bridge.Callback.Trigger("nn_mechanic:canOpenTowDispatch")
    if not canOpen then
        bridge.Notify.SendNotify(t("not_a_mechanic") or "You are not a mechanic.", "error")
        return
    end

    local callsResult = bridge.Callback.Trigger("nn_mechanic:getTowCalls")
    local success = callsResult.success
    if success then
        towCalls = callsResult.calls
        myActiveCallId = callsResult.myActiveCall
        State.DispatchOpen = true
        ToggleTablet(true)
        Wait(300)
        SetNuiFocus(true, true)

        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = true,
                page = "tow_dispatch"
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = callsResult.calls,
                myActiveCall = callsResult.myActiveCall
            }
        })

        CreateThread(function()
            while true do
                if not State.DispatchOpen then
                    break
                end
                UpdateCallDistances()
                Wait(5000)
            end
        end)
    end
end

local function UpdateCallDistances()
    if not State.DispatchOpen then
        return
    end
    if #towCalls == 0 then
        return
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, call in ipairs(towCalls) do
        local callLocation = vector3(call.location.x, call.location.y, call.location.z)
        local distance = #(playerCoords - callLocation)
        call.distance = distance
    end

    SendNUIMessage({
        action = "setTowDispatchData",
        data = {
            calls = towCalls,
            myActiveCall = myActiveCallId
        }
    })
end

local function CloseTowDispatch()
    State.DispatchOpen = false
    ToggleTablet(false)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = nil
        }
    })
end

local function RequestTow(reasonOverride)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if 0 == vehicle then
        local playerCoords = GetEntityCoords(playerPed)
        vehicle = GetClosestVehicle(playerCoords, 5.0, 0, 70)
    end

    if 0 == vehicle then
        local notifyMessage = t("no_vehicle_for_tow") or "No vehicle found nearby to tow."
        bridge.Notify.SendNotify(notifyMessage, "error")
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local streetName = getStreetAndZoneFromCoord(vehicleCoords)
    local vehicleName = getVehicleName(vehicle)
    local vehiclePlate = GetVehicleNumberPlateText(vehicle)
    local vehicleColor = getVehicleColors(vehicle)

    local locationData = {
        x = vehicleCoords.x,
        y = vehicleCoords.y,
        z = vehicleCoords.z,
        streetName = streetName
    }

    local reason = reasonOverride or "Vehicle breakdown"

    local callDetails = {
        vehicleName = vehicleName,
        vehiclePlate = vehiclePlate,
        vehicleColor = vehicleColor,
        location = locationData,
        reason = reason,
        phone = "N/A"
    }

    local createCallResult = bridge.Callback.Trigger("nn_mechanic:createTowCall", callDetails)
    local success = createCallResult.success
    if success then
        local notifyMessage = t("tow_call_placed") or "Tow truck has been called. Please wait for a mechanic."
        bridge.Notify.SendNotify(notifyMessage, "success")
    else
        local notifyMessage = createCallResult.error or "Failed to call tow"
        bridge.Notify.SendNotify(notifyMessage, "error")
    end
end

exports("RequestTow", RequestTow)
exports("OpenTowDispatch", OpenTowDispatch)

RegisterNUICallback("closeTowDispatch", function(eventData, callback)
    CloseTowDispatch()
    callback({})
end)

RegisterNUICallback("takeDispatchCall", function(eventData, callback)
    if myActiveCallId then
        local notifyMessage = t("already_on_call") or "You already have an active call."
        bridge.Notify.SendNotify(notifyMessage, "error")
        callback({
            success = false
        })
        return
    end

    local takeCallResult = bridge.Callback.Trigger("nn_mechanic:takeTowCall", eventData.callId)
    local success = takeCallResult.success
    if success then
        myActiveCallId = eventData.callId
        for _, call in ipairs(towCalls) do
            if call.id == eventData.callId then
                SetTowRoute(call.location.x, call.location.y, call.location.z)
                call.status = "accepted"
                break
            end
        end

        SendNUIMessage({
            action = "setMyActiveCall",
            data = {
                callId = eventData.callId
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = myActiveCallId
            }
        })

        local notifyMessage = t("tow_call_taken") or "Call taken! Route set on GPS."
        bridge.Notify.SendNotify(notifyMessage, "success")
    else
        local notifyMessage = takeCallResult.error or "Failed to take call"
        bridge.Notify.SendNotify(notifyMessage, "error")
    end
    callback(takeCallResult)
end)

RegisterNUICallback("cancelDispatchCall", function(eventData, callback)
    if not myActiveCallId then
        callback({
            success = false
        })
        return
    end

    local releaseCallResult = bridge.Callback.Trigger("nn_mechanic:releaseTowCall", eventData.callId)
    local success = releaseCallResult.success
    if success then
        for _, call in ipairs(towCalls) do
            if call.id == eventData.callId then
                call.status = "pending"
                call.acceptedBy = nil
                call.acceptedByName = nil
                break
            end
        end
        myActiveCallId = nil
        ClearTowRoute()

        SendNUIMessage({
            action = "setMyActiveCall",
            data = {
                callId = nil
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = nil
            }
        })

        local notifyMessage = t("tow_call_released") or "Call released. Other mechanics can now take it."
        bridge.Notify.SendNotify(notifyMessage, "info")
    else
        local notifyMessage = releaseCallResult.error or "Failed to release call"
        bridge.Notify.SendNotify(notifyMessage, "error")
    end
    callback(releaseCallResult)
end)

RegisterNUICallback("completeTowCall", function(eventData, callback)
    if not myActiveCallId then
        callback({
            success = false
        })
        return
    end

    local completeCallResult = bridge.Callback.Trigger("nn_mechanic:completeTowCall", eventData.callId)
    local success = completeCallResult.success
    if success then
        for i = #towCalls, 1, -1 do
            local callIdToRemove = towCalls[i].id
            if callIdToRemove == eventData.callId then
                table.remove(towCalls, i)
                break
            end
        end
        myActiveCallId = nil
        ClearTowRoute()

        SendNUIMessage({
            action = "setMyActiveCall",
            data = {
                callId = nil
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = nil
            }
        })

        local earnedPrice = completeCallResult.price or 0
        local notifyMessage = string.format(t("tow_job_completed") or "Job completed! You earned $%d.", earnedPrice)
        bridge.Notify.SendNotify(notifyMessage, "success")
    else
        local notifyMessage = completeCallResult.error or "Failed to complete call"
        bridge.Notify.SendNotify(notifyMessage, "error")
    end
    callback(completeCallResult)
end)

RegisterNetEvent("nn_mechanic:newTowCall", function(data)
    table.insert(towCalls, 1, data.call)
    if State.DispatchOpen then
        SendNUIMessage({
            action = "updateTowCall",
            data = {
                call = data.call
            }
        })
        PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", false)
    end
    local notifyMessage = t("new_tow_call") or "New tow call received!"
    bridge.Notify.SendNotify(notifyMessage, "info")
end)

RegisterNetEvent("nn_mechanic:updateTowCall", function(data)
    for _, call in ipairs(towCalls) do
        if call.id == data.call.id then
            call = data.call
            break
        end
    end
    if State.DispatchOpen then
        SendNUIMessage({
            action = "updateTowCall",
            data = {
                call = data.call
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = myActiveCallId
            }
        })
    end
end)

RegisterNetEvent("nn_mechanic:removeTowCall", function(data)
    for i = #towCalls, 1, -1 do
        local callIdToRemove = towCalls[i].id
        if callIdToRemove == data.callId then
            table.remove(towCalls, i)
            break
        end
    end
    if myActiveCallId == data.callId then
        myActiveCallId = nil
        ClearTowRoute()
        SendNUIMessage({
            action = "setMyActiveCall",
            data = {
                callId = nil
            }
        })
    end
    if State.DispatchOpen then
        SendNUIMessage({
            action = "removeTowCall",
            data = {
                callId = data.callId
            }
        })
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = myActiveCallId
            }
        })
    end
end)

RegisterNetEvent("nn_mechanic:towCallTaken", function(data)
    for _, call in ipairs(towCalls) do
        if call.id == data.callId then
            call.status = "accepted"
            call.acceptedBy = data.acceptedBy
            call.acceptedByName = data.acceptedByName
            break
        end
    end
    if State.DispatchOpen then
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = myActiveCallId
            }
        })
    end
end)

RegisterNetEvent("nn_mechanic:towCallReleased", function(data)
    for _, call in ipairs(towCalls) do
        if call.id == data.callId then
            call.status = "pending"
            call.acceptedBy = nil
            call.acceptedByName = nil
            break
        end
    end
    if State.DispatchOpen then
        SendNUIMessage({
            action = "setTowDispatchData",
            data = {
                calls = towCalls,
                myActiveCall = myActiveCallId
            }
        })
    end
    local notifyMessage = t("tow_call_available") or "A tow call is now available!"
    bridge.Notify.SendNotify(notifyMessage, "info")
end)

RegisterNetEvent("nn_mechanic:towCallAccepted", function(data)
    local notifyMessage = string.format(t("tow_mechanic_coming") or "Mechanic %s is on the way!", data.mechanicName)
    bridge.Notify.SendNotify(notifyMessage, "success")
end)

RegisterNetEvent("nn_mechanic:towCallCompleted", function(data)
    local notifyMessage = string.format(t("tow_service_complete") or "Tow service completed. Charged: $%d", data.price)
    bridge.Notify.SendNotify(notifyMessage, "info")
end)

RegisterNetEvent("nn_mechanic:towCallExpired", function()
    local notifyMessage = t("tow_call_expired") or "Your tow call has expired. No mechanics available."
    bridge.Notify.SendNotify(notifyMessage, "error")
end)

RegisterNetEvent("nn_mechanic:towCallCancelled", function(data)
    local notifyMessage = t("tow_call_cancelled") or "The tow call was cancelled."
    bridge.Notify.SendNotify(notifyMessage, "error")
end)

RegisterCommand(Config.TowDispatch.MechanicCommand, function()
    OpenTowDispatch()
end, false)

RegisterCommand(Config.TowDispatch.PlayerCommand, function(source, args)
    local reason = table.concat(args, " ")
    if "" == reason then
        reason = "Vehicle breakdown"
    end
    RequestTow(reason)
end, false)