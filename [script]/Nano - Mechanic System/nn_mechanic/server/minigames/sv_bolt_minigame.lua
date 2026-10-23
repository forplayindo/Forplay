-- server/minigames/sv_bolt_minigame.lua
-- Server-side bolt minigame handling

local boltMinigames = {}

function StartBoltMinigameServer(vehicleNetId, boneName, boltCount, callback)
    local src = source
    
    -- Generate bolt positions
    local bolts = {}
    for i = 1, boltCount do
        bolts[i] = {
            id = i,
            position = {
                x = math.random(-15, 15) / 10,
                y = math.random(-15, 15) / 10,
                z = 0
            },
            rotation = math.random(0, 360),
            torque = math.random(80, 120),
            isLoosened = false
        }
    end
    
    local minigameId = #boltMinigames + 1
    boltMinigames[minigameId] = {
        id = minigameId,
        vehicleNetId = vehicleNetId,
        boneName = boneName,
        bolts = bolts,
        playerSrc = src,
        startedAt = os.time(),
        completed = false
    }
    
    if callback then callback(true, minigameId, bolts) end
    return minigameId
end

function UpdateBoltState(minigameId, boltId, isLoosened, callback)
    local minigame = boltMinigames[minigameId]
    if not minigame then
        if callback then callback(false, "Minigame not found") end
        return false
    end
    
    if minigame.completed then
        if callback then callback(false, "Minigame already completed") end
        return false
    end
    
    local bolt = minigame.bolts[boltId]
    if not bolt then
        if callback then callback(false, "Bolt not found") end
        return false
    end
    
    bolt.isLoosened = isLoosened
    
    -- Check if all bolts are loosened
    local allLoosened = true
    for _, b in ipairs(minigame.bolts) do
        if not b.isLoosened then
            allLoosened = false
            break
        end
    end
    
    if allLoosened then
        minigame.completed = true
        minigame.completedAt = os.time()
    end
    
    if callback then callback(true, allLoosened) end
    return true
end

function CompleteBoltMinigame(minigameId, success, callback)
    local minigame = boltMinigames[minigameId]
    if not minigame then
        if callback then callback(false, "Minigame not found") end
        return false
    end
    
    minigame.completed = true
    minigame.completedAt = os.time()
    minigame.success = success
    
    if callback then callback(true) end
    return true
end

function GetBoltMinigame(minigameId)
    return boltMinigames[minigameId]
end

-- Cleanup old minigames
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(600000) -- 10 minutes
        local cutoff = os.time() - 1800 -- 30 minutes
        for id, minigame in pairs(boltMinigames) do
            if minigame.completedAt and minigame.completedAt < cutoff then
                boltMinigames[id] = nil
            elseif not minigame.completed and minigame.startedAt < cutoff then
                boltMinigames[id] = nil
            end
        end
    end
end)

-- Register callbacks
lib.callback.register("nn_mechanic:startBoltMinigame", function(source, vehicleNetId, boneName, boltCount)
    local p1, p2, p3
    StartBoltMinigameServer(vehicleNetId, boneName, boltCount, function(r1, r2, r3)
        p1, p2, p3 = r1, r2, r3
    end)
    return p1, p2, p3
end)

lib.callback.register("nn_mechanic:updateBoltState", function(source, minigameId, boltId, isLoosened)
    local p1, p2
    UpdateBoltState(minigameId, boltId, isLoosened, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)

lib.callback.register("nn_mechanic:completeBoltMinigame", function(source, minigameId, success)
    local p1, p2
    CompleteBoltMinigame(minigameId, success, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)