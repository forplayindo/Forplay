-- server/minigames/sv_pressure_minigame.lua
-- Server-side pressure minigame for fluid refills

local activePressureMinigames = {}

function StartPressureMinigame(targetPressure, timeLimit, callback)
    local src = source
    
    local minigameId = #activePressureMinigames + 1
    local currentPressure = 0
    local isActive = true
    local startTime = os.time()
    
    activePressureMinigames[minigameId] = {
        id = minigameId,
        playerSrc = src,
        targetPressure = targetPressure,
        currentPressure = currentPressure,
        timeLimit = timeLimit,
        startTime = startTime,
        isActive = true,
        completed = false
    }
    
    if callback then
        callback(true, minigameId, {
            currentPressure = currentPressure,
            targetPressure = targetPressure,
            timeRemaining = timeLimit
        })
    end
    
    return minigameId
end

function UpdatePressure(minigameId, pressureDelta, callback)
    local minigame = activePressureMinigames[minigameId]
    if not minigame then
        if callback then callback(false, "Minigame not found") end
        return false
    end
    
    if not minigame.isActive or minigame.completed then
        if callback then callback(false, "Minigame not active") end
        return false
    end
    
    minigame.currentPressure = math.max(0, math.min(100, minigame.currentPressure + pressureDelta))
    
    -- Check for completion
    local elapsed = os.time() - minigame.startTime
    local timeRemaining = math.max(0, minigame.timeLimit - elapsed)
    
    local isComplete = false
    local success = false
    
    if minigame.currentPressure >= minigame.targetPressure then
        isComplete = true
        success = true
        minigame.completed = true
        minigame.completedAt = os.time()
        minigame.success = true
    elseif timeRemaining <= 0 then
        isComplete = true
        success = false
        minigame.completed = true
        minigame.completedAt = os.time()
        minigame.success = false
    end
    
    if callback then
        callback(true, {
            currentPressure = minigame.currentPressure,
            targetPressure = minigame.targetPressure,
            timeRemaining = timeRemaining,
            isComplete = isComplete,
            success = success
        })
    end
    
    return true
end

function CancelPressureMinigame(minigameId, callback)
    local minigame = activePressureMinigames[minigameId]
    if not minigame then
        if callback then callback(false, "Minigame not found") end
        return false
    end
    
    minigame.isActive = false
    minigame.completed = true
    minigame.completedAt = os.time()
    minigame.success = false
    
    if callback then callback(true) end
    return true
end

function GetPressureMinigame(minigameId)
    return activePressureMinigames[minigameId]
end

-- Cleanup old minigames
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(600000) -- 10 minutes
        local cutoff = os.time() - 300 -- 5 minutes
        for id, minigame in pairs(activePressureMinigames) do
            if minigame.completedAt and minigame.completedAt < cutoff then
                activePressureMinigames[id] = nil
            elseif not minigame.completed and minigame.startTime < cutoff then
                activePressureMinigames[id] = nil
            end
        end
    end
end)

-- Register callbacks
lib.callback.register("nn_mechanic:startPressureMinigame", function(source, targetPressure, timeLimit)
    local p1, p2, p3
    StartPressureMinigame(targetPressure, timeLimit, function(r1, r2, r3)
        p1, p2, p3 = r1, r2, r3
    end)
    return p1, p2, p3
end)

lib.callback.register("nn_mechanic:updatePressure", function(source, minigameId, pressureDelta)
    local p1, p2
    UpdatePressure(minigameId, pressureDelta, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)

lib.callback.register("nn_mechanic:cancelPressureMinigame", function(source, minigameId)
    local p1, p2
    CancelPressureMinigame(minigameId, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)