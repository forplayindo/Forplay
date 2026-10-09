if not Config.EntitySpam.enabled then return end

---@type table<integer, { windowStart: integer, objects: integer, vehicles: integer, peds: integer }>
local windows = {}

local ENTITY_TYPE_PED = 1
local ENTITY_TYPE_VEHICLE = 2
local ENTITY_TYPE_OBJECT = 3

---@param source integer
local function getWindow(source)
    local now = GetGameTimer()
    local w = windows[source]
    if not w or (now - w.windowStart) > Config.EntitySpam.windowMs then
        w = { windowStart = now, objects = 0, vehicles = 0, peds = 0 }
        windows[source] = w
    end
    return w
end

AddEventHandler('entityCreating', function(entity)
    local src = source
    if src == 0 or src == '' then return end -- created by the server itself, not a player

    local ok, entityType = pcall(GetEntityType, entity)
    if not ok then return end

    local w = getWindow(src)

    if entityType == ENTITY_TYPE_OBJECT then
        w.objects = w.objects + 1
        if w.objects > Config.EntitySpam.maxObjects then
            CancelEvent()
            Punish.Flag(src, 'entityspam', Config.EntitySpam.points, ('spawned %d objects in %dms'):format(w.objects, Config.EntitySpam.windowMs))
        end
    elseif entityType == ENTITY_TYPE_VEHICLE then
        w.vehicles = w.vehicles + 1
        if w.vehicles > Config.EntitySpam.maxVehicles then
            CancelEvent()
            Punish.Flag(src, 'entityspam', Config.EntitySpam.points, ('spawned %d vehicles in %dms'):format(w.vehicles, Config.EntitySpam.windowMs))
        end
    elseif entityType == ENTITY_TYPE_PED then
        w.peds = w.peds + 1
        if w.peds > Config.EntitySpam.maxPeds then
            CancelEvent()
            Punish.Flag(src, 'entityspam', Config.EntitySpam.points, ('spawned %d peds in %dms'):format(w.peds, Config.EntitySpam.windowMs))
        end
    end
end)

AddEventHandler('playerDropped', function()
    windows[source] = nil
end)
