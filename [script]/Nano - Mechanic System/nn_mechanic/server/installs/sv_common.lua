-- server/install/sv_common.lua
InstallServer = {}
local bridge = exports.community_bridge.Bridge()
local installs = {}

function InstallServer.StartInstall(shopId, pointId, vehicleNetId, modId, modIndex, callback)
    local src = source
    local player = bridge.Framework.GetPlayer(src)
    
    if not player then
        if callback then callback(false, "Player not found") end
        return false
    end
    
    -- Check if player has permission to install parts
    local hasPerm = bridge.Callback.Trigger("nn_mechanic:checkEmployeePermission", src, shopId, "tablet")
    if not hasPerm then
        if callback then callback(false, "No permission") end
        return false
    end
    
    -- Store installation in progress
    local installId = #installs + 1
    installs[installId] = {
        id = installId,
        shopId = shopId,
        pointId = pointId,
        vehicleNetId = vehicleNetId,
        modId = modId,
        modIndex = modIndex,
        playerSrc = src,
        playerId = player.identifier,
        startedAt = os.time(),
        status = "in_progress"
    }
    
    if callback then callback(true, installId) end
    return true
end

function InstallServer.CompleteInstall(installId, success, callback)
    local install = installs[installId]
    if not install then
        if callback then callback(false, "Install not found") end
        return false
    end
    
    install.status = success and "completed" or "failed"
    install.completedAt = os.time()
    
    -- Log the installation
    TriggerEvent("nn_mechanic:logInstall", install)
    
    if callback then callback(true) end
    return true
end

function InstallServer.GetInstall(installId)
    return installs[installId]
end

function InstallServer.CleanupOldInstalls()
    local cutoff = os.time() - (60 * 60) -- 1 hour
    for id, install in pairs(installs) do
        if install.completedAt and install.completedAt < cutoff then
            installs[id] = nil
        elseif not install.completedAt and install.startedAt < cutoff then
            installs[id] = nil
        end
    end
end

-- Clean up every hour
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600000)
        InstallServer.CleanupOldInstalls()
    end
end)

-- Register callbacks
lib.callback.register("nn_mechanic:startInstall", function(source, shopId, pointId, vehicleNetId, modId, modIndex)
    local p1, p2
    InstallServer.StartInstall(shopId, pointId, vehicleNetId, modId, modIndex, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)

lib.callback.register("nn_mechanic:completeInstall", function(source, installId, success)
    local p1, p2
    InstallServer.CompleteInstall(installId, success, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)