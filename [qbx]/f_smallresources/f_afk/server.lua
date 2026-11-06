local config = lib.load('f_afk.config')

local loggedInPlayers = {}
local previousPos = {}
local time = {}
local inZone = {}
local exemptCache = {}
local timeMinutes = {
    [900] = 'minutes',
    [600] = 'minutes',
    [300] = 'minutes',
    [150] = 'minutes',
    [60] = 'minutes',
    [30] = 'seconds',
    [20] = 'seconds',
    [10] = 'seconds'
}

local EXEMPT_REFRESH = 30000 -- staff bisa ditambah/dicabut dari panel saat jalan

local function isExempt(source)
    local cached = exemptCache[source]
    local now = GetGameTimer()
    if cached and now < cached.expires then return cached.value end

    local value = false
    local ok, staff = pcall(function() return exports.f_admin:IsStaff(source) end)
    if ok and staff then
        value = true
    else
        for i = 1, #config.ignoreAces do
            if IsPlayerAceAllowed(tostring(source), config.ignoreAces[i]) then
                value = true
                break
            end
        end
    end

    exemptCache[source] = { value = value, expires = now + EXEMPT_REFRESH }
    return value
end

local function pointInPolygon(x, y, points)
    local inside = false
    local j = #points
    for i = 1, #points do
        local pi, pj = points[i], points[j]
        if (pi.y > y) ~= (pj.y > y) and x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x then
            inside = not inside
        end
        j = i
    end
    return inside
end

---@return string? nama zona AFK tempat pemain berdiri
local function getAfkZone(coords)
    for i = 1, #config.zones do
        local zone = config.zones[i]
        if #zone.points >= 3
            and (not zone.minZ or coords.z >= zone.minZ)
            and (not zone.maxZ or coords.z <= zone.maxZ)
            and pointInPolygon(coords.x, coords.y, zone.points) then
            return zone.name or 'Zona AFK'
        end
    end
end

local function resetPlayer(source)
    loggedInPlayers[source] = nil
    previousPos[source] = nil
    time[source] = nil
    inZone[source] = nil
    exemptCache[source] = nil
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    loggedInPlayers[source] = true
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    resetPlayer(source)
end)

AddEventHandler('QBCore:Server:OnPermissionUpdate', function(source)
    exemptCache[source] = nil
end)

AddEventHandler('playerDropped', function()
    resetPlayer(source)
end)

---@TODO determine if lib.cron is better for this
CreateThread(function()
    for _, v in pairs(GetPlayers()) do
        v = tonumber(v)
        loggedInPlayers[v] = Player(v).state.isLoggedIn or nil
    end
    while true do
        Wait(1000)
        for _, v in pairs(GetPlayers()) do
            -- Events make source a number, GetPlayers() returns it as a string
            v = tonumber(v) --[[@as number]]

            if loggedInPlayers[v] then
                local playerPed = GetPlayerPed(v)
                local currentPos = GetEntityCoords(playerPed)
                if not time[v] then
                    time[v] = config.timeUntilAFKKick
                end

                -- Zona & staff hanya dicek saat pemain diam, jadi pemain yang bergerak tidak menambah beban
                if previousPos[v] and currentPos == previousPos[v] and not isExempt(v) then
                    local zone = getAfkZone(currentPos)
                    if zone then
                        if not inZone[v] then
                            inZone[v] = true
                            exports.qbx_core:Notify(v, 'Kamu di ' .. zone .. ', aman dari kick AFK.', 'success', 7000)
                        end
                        time[v] = config.timeUntilAFKKick
                    elseif time[v] > 0 then
                        inZone[v] = nil
                        local _type = timeMinutes[time[v]]
                        if _type == 'minutes' then
                            exports.qbx_core:Notify(v, 'Kamu AFK dan akan dikeluarkan dalam ' .. math.ceil(time[v] / 60) .. ' menit!', 'error', 10000)
                        elseif _type == 'seconds' then
                            exports.qbx_core:Notify(v, 'Kamu AFK dan akan dikeluarkan dalam ' .. time[v] .. ' detik!', 'error', 10000)
                        end
                        time[v] -= 1
                    else
                        DropPlayer(v --[[@as string]], 'Kamu dikeluarkan karena AFK terlalu lama')
                    end
                else
                    time[v] = config.timeUntilAFKKick
                    inZone[v] = nil
                end

                previousPos[v] = currentPos
            end
        end
    end
end)
