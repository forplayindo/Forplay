---Lowest z of the zone. The zone spans from here up to `ZoneMinZ(zone) + zone.height`.
---@param zone GarageZone
---@return number
function ZoneMinZ(zone)
    return zone.z - 2.0
end

---Checks if coords are inside the zone, or within `margin` meters of its edge.
---@param zone GarageZone
---@param coords vector3
---@param margin number
---@return boolean
function IsInsideZone(zone, coords, margin)
    local minZ = ZoneMinZ(zone)
    if coords.z < minZ - margin or coords.z > minZ + zone.height + margin then return false end

    local points = zone.points
    local x, y = coords.x, coords.y
    local inside = false
    local j = #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then
            inside = not inside
        end
        j = i
    end
    if inside or margin <= 0 then return inside end

    -- tolerance for server-side position lagging behind the client
    j = #points
    for i = 1, #points do
        local a, b = points[j], points[i]
        local dx, dy = b.x - a.x, b.y - a.y
        local lenSq = dx * dx + dy * dy
        local t = lenSq > 0 and math.max(0, math.min(1, ((x - a.x) * dx + (y - a.y) * dy) / lenSq)) or 0
        local px, py = a.x + t * dx - x, a.y + t * dy - y
        if px * px + py * py <= margin * margin then return true end
        j = i
    end
    return false
end
