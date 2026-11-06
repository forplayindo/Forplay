--[[
 ______     __         ______     ______     __   __     ______     _____        ______     __  __        __  __     ______     __   __   __     __   __    
/\  ___\   /\ \       /\  ___\   /\  __ \   /\ "-.\ \   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \/ /    /\  ___\   /\ \ / /  /\ \   /\ "-.\ \   
\ \ \____  \ \ \____  \ \  __\   \ \  __ \  \ \ \-.  \  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  _"-.  \ \  __\   \ \ \'/   \ \ \  \ \ \-.  \  
 \ \_____\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_\\"\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_____\  \ \__|    \ \_\  \ \_\\"\_\ 
  \/_____/   \/_____/   \/_____/   \/_/\/_/   \/_/ \/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_____/   \/_/      \/_/   \/_/ \/_/ 
 ______   __     __  __     ______     _____        ______     __  __        __  __     ______     ______     __     __    __        __  __     ______     ______     ______     ______     ______     ______    
/\  ___\ /\ \   /\_\_\_\   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \_\ \   /\  __ \   /\___  \   /\ \   /\ "-./  \      /\ \_\ \   /\  ___\   /\  == \   /\  == \   /\  ___\   /\  == \   /\  __ \   
\ \  __\ \ \ \  \/_/\_\/_  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  __ \  \ \  __ \  \/_/  /__  \ \ \  \ \ \-./\ \     \ \  __ \  \ \  __\   \ \  __<   \ \  __<   \ \  __\   \ \  __<   \ \  __ \  
 \ \_\    \ \_\   /\_\/\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_\ \_\   /\_____\  \ \_\  \ \_\ \ \_\     \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\ 
  \/_/     \/_/   \/_/\/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_/\/_/   \/_____/   \/_/   \/_/  \/_/      \/_/\/_/   \/_____/   \/_/ /_/   \/_/ /_/   \/_____/   \/_/ /_/   \/_/\/_/ 
                                                                                                                                                                    
]]

-- Every return is backed by one item removed here, never by a client grant event.
local sessions, lastReward, sequence = {}, {}, 0
local sessionDuration = 90000 -- Two runs of up to 30s, plus asset loading and animations.

local function activePet(src, owner, name, distance)
    for _, entry in pairs(EP.activePets or {}) do
        if entry.owner == owner and entry.pet.name == name and DoesEntityExist(entry.entity)
            and not entry.pet.dead and EP.near(src, GetEntityCoords(entry.entity), distance)
            and GetPlayerRoutingBucket(src) == GetEntityRoutingBucket(entry.entity) then return entry end
    end
end

local function returnBall(src, session)
    if EP.identifier(src) ~= session.owner then return false end
    if not EP.addItem(src, session.item, 1) then return false end
    sessions[session.owner] = nil
    return true
end

EP.registerCallback('electus_pets:startFetch', function(src, name)
    return EP.withPetLock(src, function(owner)
        local previous = sessions[owner]
        if previous then
            if not previous.finished and GetGameTimer() - previous.started < sessionDuration then return { error = 'fetchBusy' } end
            previous.finished = true
            previous.source = src
            return returnBall(src, previous) and { recovered = true } or { error = 'fetchInventoryFull' }
        end
        if type(name) ~= 'string' then return { error = 'fetchUnavailable' } end
        local entry = activePet(src, owner, name, 10.0)
        if not entry then return { error = 'fetchTooFar' } end
        if not (Config.PetAnims and Config.PetAnims[entry.pet.model] or {}).pickUp then
            return { error = 'fetchUnsupported' }
        end
        local item = (Config.Fetch or {}).item or 'WEAPON_BALL'
        if not EP.removeItem(src, item, 1) then return { error = 'fetchNeedBall' } end
        sequence = sequence + 1
        local session = { owner = owner, source = src, name = name, item = item, token = sequence, started = GetGameTimer() }
        sessions[owner] = session
        SetTimeout(sessionDuration, function()
            if sessions[owner] ~= session then return end
            session.finished = true
            returnBall(src, session)
        end)
        return { token = session.token }
    end)
end)

EP.registerCallback('electus_pets:finishFetch', function(src, token, completed)
    return EP.withPetLock(src, function(owner)
        local session = sessions[owner]
        if not session or session.owner ~= owner or session.token ~= token then return false end
        if not session.finished then
            session.finished = true
            session.completed = completed == true and GetGameTimer() - session.started >= 4000
                and activePet(src, owner, session.name, 6.0) ~= nil
            if session.completed and (not lastReward[owner] or GetGameTimer() - lastReward[owner] >= 30000) then
                lastReward[owner] = GetGameTimer()
                local ok, err = pcall(EP.awardXP, src, session.name, (Config.RewardsXP or {}).fetchedBall or 0)
                if not ok then print(('electus_pets: fetch XP failed: %s'):format(err)) end
            end
        end
        local returned = not session.completed or Config.AddBallAfterFetch ~= false
        if returned then
            if not returnBall(src, session) then return { error = 'fetchInventoryFull' } end
        else
            sessions[owner] = nil
        end
        return { completed = session.completed, returned = returned }
    end)
end)

local function cleanup(src)
    for _, session in pairs(sessions) do
        if session.source == src then
            session.finished = true
            -- Keep failed refunds under the character so they can recover on return.
            returnBall(src, session)
        end
    end
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) cleanup(tonumber(src) or source) end)
AddEventHandler('esx:playerLogout', function(src) cleanup(tonumber(src) or source) end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, session in pairs(sessions) do returnBall(session.source, session) end
end)
