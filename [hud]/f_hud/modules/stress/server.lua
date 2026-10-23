-- Server-authoritative stress (ported from f_stress). Writing the 'stress' statebag is enough:
-- qbx_core mirrors it into metadata and fires hud:client:UpdateStress for the HUD bar.

local cfg = Config.Stress
if not cfg or not cfg.enabled then return end

local lastGain, lastRelief = {}, {}

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function setStress(src, value)
    local state = Player(src).state
    value = math.floor(math.max(0, math.min(100, value)) + 0.5)
    if state.stress ~= value then
        state:set('stress', value, true)
    end
    return value
end

---@param src number
---@param amount number positive = gain, negative = relief
---@return number|false newStress
local function addStress(src, amount)
    local player = getPlayer(src)
    if not player then return false end
    if amount > 0 and cfg.excludedJobs[player.PlayerData.job.name] then return false end
    local current = Player(src).state.stress or player.PlayerData.metadata.stress or 0
    return setStress(src, current + amount)
end

RegisterNetEvent('hud:server:GainStress', function(amount)
    local src = source
    if type(amount) ~= 'number' or amount ~= amount or amount <= 0 then return end
    local now = GetGameTimer()
    if lastGain[src] and now - lastGain[src] < cfg.gainCooldown then return end
    lastGain[src] = now
    addStress(src, math.min(amount, cfg.maxGainPerEvent))
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    local src = source
    if type(amount) ~= 'number' or amount ~= amount or amount <= 0 then return end
    local now = GetGameTimer()
    if lastRelief[src] and now - lastRelief[src] < cfg.reliefCooldown then return end
    lastRelief[src] = now
    addStress(src, -math.min(amount, 100))
end)

AddEventHandler('playerDropped', function()
    lastGain[source], lastRelief[source] = nil, nil
end)

CreateThread(function() -- berkurang sendiri tiap beberapa menit
    while true do
        Wait(cfg.passiveRelief.every)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local state = Player(src).state
            if state.isLoggedIn and (state.stress or 0) > 0 then
                setStress(src, state.stress - cfg.passiveRelief.amount)
            end
        end
    end
end)

-- Untuk script lain (server): exports.f_hud:AddStress(src, 5) / exports.f_hud:RelieveStress(src, 10)
exports('AddStress', function(src, amount) return addStress(src, math.abs(tonumber(amount) or 0)) end)
exports('RelieveStress', function(src, amount) return addStress(src, -math.abs(tonumber(amount) or 0)) end)
exports('GetStress', function(src) return Player(src).state.stress or 0 end)
