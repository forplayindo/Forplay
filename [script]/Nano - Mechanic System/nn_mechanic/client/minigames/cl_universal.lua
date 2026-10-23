-- ============================================
-- Minigame System
-- Includes: Key Press Timing, Tool Matching, Cable Routing
-- ============================================

-- Bridge setup
local bridge = exports.community_bridge.Bridge()

-- ============================================
-- Key Press Timing Minigame
-- ============================================

local keyPressTimingResult = nil
local keyPressTimingActive = false

function StartKeyPressMinigame(config)
    config = config or {}
    
    local rounds = config.rounds or 3
    local difficulty = config.difficulty or "medium"
    local timeLimit = config.timeLimit or 30
    
    keyPressTimingResult = nil
    keyPressTimingActive = true
    
    -- Send configuration to UI
    SendNUIMessage({
        action = "setKeyPressTimingData",
        data = {
            rounds = rounds,
            difficulty = difficulty,
            timeLimit = timeLimit
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "key-press-timing"
        }
    })
    
    State.openPage = "key-press-timing"
    SetNuiFocus(true, true)
    
    -- Wait for minigame to complete
    while keyPressTimingActive do
        Citizen.Wait(0)
    end
    
    State.openPage = nil
    return keyPressTimingResult == true
end

RegisterNUICallback("keyPressTimingResult", function(data, cb)
    if not data then
        keyPressTimingResult = false
        keyPressTimingActive = false
        cb({ success = false })
        return
    end
    
    keyPressTimingResult = data.success == true
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "key-press-timing"
        }
    })
    
    SetNuiFocus(false, false)
    keyPressTimingActive = false
    cb({ success = true })
end)

-- ============================================
-- Tool Matching Minigame
-- ============================================

local toolMatchingResult = nil
local toolMatchingActive = false

function StartToolMatchingMinigame(config)
    config = config or {}
    
    local toolConfig = Config.ToolMatching or {}
    local difficulties = toolConfig.difficulties or {}
    
    local difficulty = config.difficulty or toolConfig.defaultDifficulty or "medium"
    local difficultySettings = difficulties[difficulty] or difficulties[toolConfig.defaultDifficulty] or {}
    
    local rounds = config.rounds or difficultySettings.rounds or 5
    local timeMs = config.timeMs or difficultySettings.timeMs
    local toolCount = config.toolCount or difficultySettings.toolCount
    local taskType = config.taskType or "Tool Selection"
    
    toolMatchingResult = nil
    toolMatchingActive = true
    
    SendNUIMessage({
        action = "setToolMatchingData",
        data = {
            rounds = rounds,
            difficulty = difficulty,
            timeMs = timeMs,
            toolCount = toolCount,
            taskType = taskType
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "tool-matching"
        }
    })
    
    State.openPage = "tool-matching"
    SetNuiFocus(true, true)
    
    while toolMatchingActive do
        Citizen.Wait(0)
    end
    
    State.openPage = nil
    return toolMatchingResult == true
end

-- Debug command
if Config.Debug then
    RegisterCommand("toolmatching", function()
        local result = StartToolMatchingMinigame()
        print(result)
    end)
end

RegisterNUICallback("ToolMatchingResult", function(data, cb)
    if not data then
        toolMatchingResult = false
        toolMatchingActive = false
        cb({ success = false })
        return
    end
    
    toolMatchingResult = data.success == true
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "tool-matching"
        }
    })
    
    SetNuiFocus(false, false)
    toolMatchingActive = false
    cb({ success = true })
end)

-- ============================================
-- Cable Routing Minigame
-- ============================================

local cableRoutingResult = nil
local cableRoutingActive = false

function StartCableRoutingMinigame(config)
    config = config or {}
    
    local difficulty = config.difficulty or "medium"
    local taskType = config.taskType or "Wire Routing"
    local timeLimit = config.timeLimit or 30
    
    cableRoutingResult = nil
    cableRoutingActive = true
    
    SendNUIMessage({
        action = "setCableRoutingData",
        data = {
            difficulty = difficulty,
            taskType = taskType,
            timeLimit = timeLimit
        }
    })
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = true,
            page = "cable-routing"
        }
    })
    
    State.openPage = "cable-routing"
    SetNuiFocus(true, true)
    
    while cableRoutingActive do
        Citizen.Wait(0)
    end
    
    State.openPage = nil
    return cableRoutingResult == true
end

-- Debug command
if Config.Debug then
    RegisterCommand("cablerouting", function()
        local result = StartCableRoutingMinigame()
        print(result)
    end)
end

RegisterNUICallback("CableRoutingResult", function(data, cb)
    if not data then
        cableRoutingResult = false
        cableRoutingActive = false
        cb({ success = false })
        return
    end
    
    cableRoutingResult = data.success == true
    
    SendNUIMessage({
        action = "setVisibility",
        data = {
            visible = false,
            page = "cable-routing"
        }
    })
    
    SetNuiFocus(false, false)
    cableRoutingActive = false
    cb({ success = true })
end)