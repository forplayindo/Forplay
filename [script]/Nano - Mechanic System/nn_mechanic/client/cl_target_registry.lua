local targetBridge = bridge
if not targetBridge then
    local communityBridge = exports.community_bridge
    targetBridge = communityBridge.Bridge(communityBridge)
end
bridge = targetBridge

if not bridge or type(bridge.Target) ~= "table" then
    return
end

if rawget(bridge.Target, "__nnTargetRegistryInstalled") then
    return
end
bridge.Target.__nnTargetRegistryInstalled = true

local targetResourceName = nil
if type(bridge.Target.GetResourceName) == "function" then
    local name = bridge.Target.GetResourceName()
    if name then
        targetResourceName = name
    end
end

local registryState = {
    zones = {},
    entities = {},
    models = {},
    globalPlayers = {},
    globalVehicles = {}
}

local originalTargetFunctions = {
    AddBoxZone = bridge.Target.AddBoxZone,
    AddSphereZone = bridge.Target.AddSphereZone,
    AddLocalEntity = bridge.Target.AddLocalEntity,
    AddModel = bridge.Target.AddModel,
    AddGlobalPlayer = bridge.Target.AddGlobalPlayer,
    AddGlobalVehicle = bridge.Target.AddGlobalVehicle,
    RemoveZone = bridge.Target.RemoveZone,
    RemoveLocalEntity = bridge.Target.RemoveLocalEntity,
    RemoveModel = bridge.Target.RemoveModel,
    RemoveGlobalPlayer = bridge.Target.RemoveGlobalPlayer,
    RemoveGlobalVehicle = bridge.Target.RemoveGlobalVehicle
}

local function extractLabelsFromTable(data)
    local labelsList = {}
    if type(data) ~= "table" then
        return labelsList
    end

    for _, entry in pairs(data) do
        if type(entry) == "table" and type(entry.label) == "string" then
            labelsList[#labelsList + 1] = entry.label
        end
    end
    return labelsList
end

if originalTargetFunctions.AddBoxZone then
    local originalAddBoxZone = originalTargetFunctions.AddBoxZone
    bridge.Target.AddBoxZone = function(name, ...)
        local zoneId = originalAddBoxZone(name, ...)
        if name ~= nil then
            registryState.zones[name] = { id = zoneId }
        end
        return zoneId
    end
end

if originalTargetFunctions.AddSphereZone then
    local originalAddSphereZone = originalTargetFunctions.AddSphereZone
    bridge.Target.AddSphereZone = function(name, ...)
        local zoneId = originalAddSphereZone(name, ...)
        if name ~= nil then
            registryState.zones[name] = { id = zoneId }
        end
        return zoneId
    end
end

if originalTargetFunctions.AddLocalEntity then
    local originalAddLocalEntity = originalTargetFunctions.AddLocalEntity
    bridge.Target.AddLocalEntity = function(entityId, ...)
        if entityId ~= nil then
            registryState.entities[entityId] = true
        end
        return originalAddLocalEntity(entityId, ...)
    end
end

if originalTargetFunctions.AddModel then
    local originalAddModel = originalTargetFunctions.AddModel
    bridge.Target.AddModel = function(modelName, modelEntries, ...)
        if modelName ~= nil then
            local currentModels = registryState.models[modelName]
            if not currentModels then
                currentModels = {}
            end
            local labelsToAdd = extractLabelsFromTable(modelEntries)
            for _, label in ipairs(labelsToAdd) do
                currentModels[label] = true
            end
            registryState.models[modelName] = currentModels
        end
        return originalAddModel(modelName, modelEntries, ...)
    end
end

if originalTargetFunctions.AddGlobalPlayer then
    local originalAddGlobalPlayer = originalTargetFunctions.AddGlobalPlayer
    bridge.Target.AddGlobalPlayer = function(playerList, ...)
        local labelsToAdd = extractLabelsFromTable(playerList)
        for _, label in ipairs(labelsToAdd) do
            registryState.globalPlayers[label] = true
        end
        return originalAddGlobalPlayer(playerList, ...)
    end
end

if originalTargetFunctions.AddGlobalVehicle then
    local originalAddGlobalVehicle = originalTargetFunctions.AddGlobalVehicle
    bridge.Target.AddGlobalVehicle = function(vehicleList, ...)
        local labelsToAdd = extractLabelsFromTable(vehicleList)
        for _, label in ipairs(labelsToAdd) do
            registryState.globalVehicles[label] = true
        end
        return originalAddGlobalVehicle(vehicleList, ...)
    end
end

if originalTargetFunctions.RemoveZone then
    local originalRemoveZone = originalTargetFunctions.RemoveZone
    bridge.Target.RemoveZone = function(name, ...)
        if name ~= nil then
            registryState.zones[name] = nil
        end
        return originalRemoveZone(name, ...)
    end
end

if originalTargetFunctions.RemoveLocalEntity then
    local originalRemoveLocalEntity = originalTargetFunctions.RemoveLocalEntity
    bridge.Target.RemoveLocalEntity = function(entityId, ...)
        if entityId ~= nil then
            registryState.entities[entityId] = nil
        end
        return originalRemoveLocalEntity(entityId, ...)
    end
end

if originalTargetFunctions.RemoveModel then
    local originalRemoveModel = originalTargetFunctions.RemoveModel
    bridge.Target.RemoveModel = function(modelName, modelLabelsToRemove, ...)
        if modelName ~= nil then
            local currentModels = registryState.models[modelName]
            if currentModels then
                if type(modelLabelsToRemove) == "table" then
                    for _, label in ipairs(modelLabelsToRemove) do
                        currentModels[label] = nil
                    end
                    if next(currentModels) == nil then
                        registryState.models[modelName] = nil
                    end
                else
                    registryState.models[modelName] = nil
                end
            end
        end
        return originalRemoveModel(modelName, modelLabelsToRemove, ...)
    end
end

if originalTargetFunctions.RemoveGlobalPlayer then
    local originalRemoveGlobalPlayer = originalTargetFunctions.RemoveGlobalPlayer
    bridge.Target.RemoveGlobalPlayer = function(playerList, ...)
        if type(playerList) == "table" then
            for _, playerId in ipairs(playerList) do
                registryState.globalPlayers[playerId] = nil
            end
        end
        return originalRemoveGlobalPlayer(playerList, ...)
    end
end

if originalTargetFunctions.RemoveGlobalVehicle then
    local originalRemoveGlobalVehicle = originalTargetFunctions.RemoveGlobalVehicle
    bridge.Target.RemoveGlobalVehicle = function(vehicleList, ...)
        if type(vehicleList) == "table" then
            for _, vehicleId in ipairs(vehicleList) do
                registryState.globalVehicles[vehicleId] = nil
            end
        end
        return originalRemoveGlobalVehicle(vehicleList, ...)
    end
end

local function removeZoneWrapper(zoneName, zoneData)
    if targetResourceName == "ox_target" then
        local ok, oxTarget = pcall(function() return exports.ox_target end)
        if ok and oxTarget then
            local removeId = zoneName
            if type(zoneData) == "table" and zoneData.id then
                removeId = zoneData.id
            end
            pcall(function()
                oxTarget:removeZone(removeId, true)
            end)
            pcall(originalTargetFunctions.RemoveZone, zoneName)
            return
        end
    end

    if targetResourceName == "qb-target" then
        local ok, qbTarget = pcall(function() return exports["qb-target"] end)
        if ok and qbTarget then
            pcall(function()
                qbTarget:RemoveZone(zoneName)
            end)
            pcall(originalTargetFunctions.RemoveZone, zoneName)
            return
        end
    end

    if targetResourceName == "sleepless_interact" then
        local ok, sleeplessInteract = pcall(function() return exports.sleepless_interact end)
        if ok and sleeplessInteract then
            if type(zoneData) == "table" and zoneData.id ~= nil then
                pcall(function()
                    sleeplessInteract:removeCoords(zoneData.id)
                end)
                pcall(originalTargetFunctions.RemoveZone, zoneName)
                return
            end
        end
    end

    pcall(originalTargetFunctions.RemoveZone, zoneName)
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for name, data in pairs(registryState.zones) do
        removeZoneWrapper(name, data)
    end
    registryState.zones = {}

    if originalTargetFunctions.RemoveLocalEntity then
        for entityId, _ in pairs(registryState.entities) do
            if DoesEntityExist(entityId) then
                pcall(originalTargetFunctions.RemoveLocalEntity, entityId)
            end
        end
    end
    registryState.entities = {}

    if originalTargetFunctions.RemoveModel then
        for modelName, labels in pairs(registryState.models) do
            local labelsToRemove = {}
            for label, _ in pairs(labels) do
                labelsToRemove[#labelsToRemove + 1] = label
            end
            if #labelsToRemove > 0 then
                pcall(originalTargetFunctions.RemoveModel, modelName, labelsToRemove)
            end
        end
    end
    registryState.models = {}

    if originalTargetFunctions.RemoveGlobalPlayer then
        local playersToRemove = {}
        for playerId, _ in pairs(registryState.globalPlayers) do
            playersToRemove[#playersToRemove + 1] = playerId
        end
        if #playersToRemove > 0 then
            pcall(originalTargetFunctions.RemoveGlobalPlayer, playersToRemove)
        end
    end
    registryState.globalPlayers = {}

    if originalTargetFunctions.RemoveGlobalVehicle then
        local vehiclesToRemove = {}
        for vehicleId, _ in pairs(registryState.globalVehicles) do
            vehiclesToRemove[#vehiclesToRemove + 1] = vehicleId
        end
        if #vehiclesToRemove > 0 then
            pcall(originalTargetFunctions.RemoveGlobalVehicle, vehiclesToRemove)
        end
    end
    registryState.globalVehicles = {}
end)