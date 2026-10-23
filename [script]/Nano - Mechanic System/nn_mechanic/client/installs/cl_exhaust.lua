local function changeExhaust(referenceNumber, onCompleteCallback)
    if not referenceNumber or referenceNumber == "" then
        local sendNotification = bridge.Notify.SendNotify
        local errorMessage = t("reference_number_required")
        sendNotification(errorMessage, "error")

        if onCompleteCallback then
            onCompleteCallback(false)
        end
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local searchRadius = 5.0
    local modelHash = 0
    local searchFlags = 70
    local closestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, searchRadius, modelHash, searchFlags)

    if not DoesEntityExist(closestVehicle) then
        local sendNotification = bridge.Notify.SendNotify
        local errorMessage = t("no_vehicle_found")
        sendNotification(errorMessage, "error")

        if onCompleteCallback then
            onCompleteCallback(false)
        end
        return
    end

    local exhaustRecipes = InstallRecipes.exhaust({})
    local flowParameters = {
        vehicle = closestVehicle,
        modId = 4,
        expectedRef = referenceNumber,
        onComplete = onCompleteCallback
    }

    local flowStartedSuccessfully = InstallFlow.Start(exhaustRecipes, flowParameters)
    if not flowStartedSuccessfully and onCompleteCallback then
        onCompleteCallback(false)
    end
end

ChangeExhaust = changeExhaust

local debugEnabled = Config.Debug
if debugEnabled then
    local commandName = "change_exhaust"
    local function commandHandler(source, args)
        local referenceNumberArgument = args and args[1] or nil
        ChangeExhaust(referenceNumberArgument)
    end
    RegisterCommand(commandName, commandHandler)
end