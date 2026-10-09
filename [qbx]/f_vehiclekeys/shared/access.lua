local sharedConfig = require 'config.shared'

---Unique value stored in a physical key's metadata. ox_inventory matches metadata by value,
---so a single unique string is used instead of separate vehicleid/version fields.
---@param vehicleId integer
---@param version integer
---@return string
function KeyId(vehicleId, version)
    return ('vk:%s:%s'):format(vehicleId, version)
end

---@param job? {name: string, onduty: boolean}
---@param jobs string[]
---@param requireOnDuty? boolean
---@return boolean
function HasAllowedJob(job, jobs, requireOnDuty)
    if not job then return false end
    for i = 1, #jobs do
        if jobs[i] == job.name then
            return not requireOnDuty or job.onduty == true
        end
    end
    return false
end

---Whether a job has shared access to a vehicle model/class.
---@param job? {name: string, onduty: boolean}
---@param model integer
---@param class integer
---@return boolean shared, string? reason 'off_duty' when listed but the player is off duty
function IsJobSharedVehicle(job, model, class)
    if not job then return false end
    local profile = sharedConfig.sharedKeys[job.name]
    if not profile then return false end

    local listed = (profile.classes and profile.classes[class]) or (profile.vehicles and profile.vehicles[model])
    if not listed then return false end
    if profile.requireOnDuty and not job.onduty then return false, 'off_duty' end
    return true
end

local DIFFICULTY_ORDER = { 'easy', 'medium', 'hard', 'expert' }

---@param class integer
---@param tier integer security tier 1-3
---@param advanced? boolean advanced lockpick makes it one step easier
---@return string? difficulty nil when the class cannot be stolen
function GetTheftDifficulty(class, tier, advanced)
    local base = sharedConfig.theft.classDifficulty[class]
    if base == false then return end
    base = base or 'medium'

    local index = 2
    for i = 1, #DIFFICULTY_ORDER do
        if DIFFICULTY_ORDER[i] == base then
            index = i
            break
        end
    end

    index = index + ((tier or 1) - 1) - (advanced and 1 or 0)
    return DIFFICULTY_ORDER[math.max(1, math.min(#DIFFICULTY_ORDER, index))]
end

---@param difficulty string
---@param tier integer
---@return boolean
function NeedsJammer(difficulty, tier)
    return difficulty == 'expert' or tier >= 3 or (tier >= 2 and difficulty == 'hard')
end
