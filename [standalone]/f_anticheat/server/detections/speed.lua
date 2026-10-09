if not Config.Speed.enabled then return end

---@type table<integer, { coords: vector3, time: integer, strikes: integer }>
local last = {}

local function checkPlayer(source)
    local ped = GetPlayerPed(source --[[@as string]])
    if ped == 0 or not DoesEntityExist(ped) then
        last[source] = nil
        return
    end

    if GetEntityHealth(ped) <= 0 then
        last[source] = nil
        return
    end

    local coords = GetEntityCoords(ped)
    local now = GetGameTimer()
    local prev = last[source]
    last[source] = { coords = coords, time = now, strikes = prev and prev.strikes or 0 }

    if not prev then return end

    local dt = (now - prev.time) / 1000.0
    if dt <= 0 then return end

    local dx = coords.x - prev.coords.x
    local dy = coords.y - prev.coords.y
    local dz = coords.z - prev.coords.z

    local horizontalSpeed = math.sqrt(dx * dx + dy * dy) / dt
    local verticalSpeed = math.abs(dz) / dt

    local inVehicle = GetVehiclePedIsIn(ped, false) ~= 0
    local violated

    if inVehicle then
        local totalSpeed = math.sqrt(dx * dx + dy * dy + dz * dz) / dt
        violated = totalSpeed > Config.Speed.maxSpeedInVehicleMs
    else
        violated = horizontalSpeed > Config.Speed.maxSpeedOnFootMs
        -- falling/parachuting is mostly vertical movement - give it a much
        -- higher allowance instead of judging it against the on-foot limit
        if violated and verticalSpeed > horizontalSpeed then
            violated = verticalSpeed > Config.Speed.maxSpeedFallingMs
        end
    end

    if violated then
        local entry = last[source]
        entry.strikes = entry.strikes + 1
        if entry.strikes >= Config.Speed.requiredConsecutive then
            Punish.Flag(source, 'speed', Config.Speed.points, ('moved %.1fm in %.2fs (%s)'):format(
                math.sqrt(dx * dx + dy * dy + dz * dz), dt, inVehicle and 'vehicle' or 'on foot'))
            -- player may have disconnected while Punish.Flag was logging (async DB insert),
            -- which clears their entry via the playerDropped handler below
            entry = last[source]
            if entry then entry.strikes = 0 end
        end
    else
        last[source].strikes = 0
    end
end

CreateThread(function()
    while true do
        Wait(Config.Speed.tickMs)
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            local ok, err = pcall(checkPlayer, source)
            if not ok then
                lib.print.error(('f_anticheat speed check failed for %s: %s'):format(source, err))
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
