-- server/minigames/sv_tool_matching.lua
-- Server-side tool matching minigame

local toolSets = {
    easy = {
        tools = {"wrench", "screwdriver", "pliers", "hammer"},
        timeMs = 3500,
        rounds = 3
    },
    medium = {
        tools = {"wrench", "screwdriver", "pliers", "hammer", "socket", "ratchet"},
        timeMs = 2500,
        rounds = 5
    },
    hard = {
        tools = {"wrench", "screwdriver", "pliers", "hammer", "socket", "ratchet", "torque", "multimeter"},
        timeMs = 1800,
        rounds = 7
    }
}

local toolNames = {
    wrench = "Wrench",
    screwdriver = "Screwdriver",
    pliers = "Pliers",
    hammer = "Hammer",
    socket = "Socket",
    ratchet = "Ratchet",
    torque = "Torque Wrench",
    multimeter = "Multimeter"
}

local activeMinigames = {}

function StartToolMatchingMinigame(difficulty, callback)
    local src = source
    local config = toolSets[difficulty] or toolSets.medium
    
    local minigameId = #activeMinigames + 1
    local currentRound = 1
    local roundData = {}
    
    -- Generate rounds
    for round = 1, config.rounds do
        local requiredTool = config.tools[math.random(1, #config.tools)]
        local options = {}
        
        -- Add required tool
        options[1] = requiredTool
        
        -- Add random other tools
        local availableTools = {}
        for _, tool in ipairs(config.tools) do
            if tool ~= requiredTool then
                availableTools[#availableTools + 1] = tool
            end
        end
        
        for i = 2, 4 do
            if #availableTools > 0 then
                local idx = math.random(1, #availableTools)
                options[i] = availableTools[idx]
                table.remove(availableTools, idx)
            else
                options[i] = requiredTool
            end
        end
        
        -- Shuffle options
        for i = #options, 2, -1 do
            local j = math.random(1, i)
            options[i], options[j] = options[j], options[i]
        end
        
        roundData[round] = {
            requiredTool = requiredTool,
            options = options
        }
    end
    
    activeMinigames[minigameId] = {
        id = minigameId,
        playerSrc = src,
        difficulty = difficulty,
        config = config,
        currentRound = currentRound,
        rounds = roundData,
        scores = {},
        startedAt = os.time(),
        completed = false
    }
    
    if callback then 
        callback(true, minigameId, {
            round = currentRound,
            totalRounds = config.rounds,
            timeMs = config.timeMs,
            options = roundData[currentRound].options
        })
    end
    
    return minigameId
end

function SubmitToolChoice(minigameId, toolChoice, callback)
    local minigame = activeMinigames[minigameId]
    if not minigame then
        if callback then callback(false, "Minigame not found") end
        return false
    end
    
    if minigame.completed then
        if callback then callback(false, "Minigame already completed") end
        return false
    end
    
    local currentRoundData = minigame.rounds[minigame.currentRound]
    local isCorrect = (toolChoice == currentRoundData.requiredTool)
    
    -- Record score for this round
    minigame.scores[minigame.currentRound] = isCorrect
    
    if isCorrect then
        -- Move to next round or complete
        if minigame.currentRound >= minigame.config.rounds then
            -- All rounds completed successfully
            minigame.completed = true
            minigame.completedAt = os.time()
            minigame.success = true
            
            if callback then 
                callback(true, {
                    completed = true,
                    success = true,
                    score = #minigame.scores
                })
            end
            return true
        else
            -- Move to next round
            minigame.currentRound = minigame.currentRound + 1
            local nextRoundData = minigame.rounds[minigame.currentRound]
            
            if callback then
                callback(true, {
                    completed = false,
                    success = true,
                    nextRound = minigame.currentRound,
                    totalRounds = minigame.config.rounds,
                    timeMs = minigame.config.timeMs,
                    options = nextRoundData.options
                })
            end
            return true
        end
    else
        -- Wrong choice - minigame failed
        minigame.completed = true
        minigame.completedAt = os.time()
        minigame.success = false
        
        if callback then
            callback(true, {
                completed = true,
                success = false,
                score = #minigame.scores
            })
        end
        return true
    end
end

function GetToolMatchingMinigame(minigameId)
    return activeMinigames[minigameId]
end

-- Cleanup old minigames
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(600000) -- 10 minutes
        local cutoff = os.time() - 1800 -- 30 minutes
        for id, minigame in pairs(activeMinigames) do
            if minigame.completedAt and minigame.completedAt < cutoff then
                activeMinigames[id] = nil
            elseif not minigame.completed and minigame.startedAt < cutoff then
                activeMinigames[id] = nil
            end
        end
    end
end)

-- Register callbacks
lib.callback.register("nn_mechanic:startToolMatching", function(source, difficulty)
    local p1, p2, p3
    StartToolMatchingMinigame(difficulty, function(r1, r2, r3)
        p1, p2, p3 = r1, r2, r3
    end)
    return p1, p2, p3
end)

lib.callback.register("nn_mechanic:submitToolChoice", function(source, minigameId, toolChoice)
    local p1, p2
    SubmitToolChoice(minigameId, toolChoice, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)