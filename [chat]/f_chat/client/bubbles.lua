local bubbles = {}   -- [serverId] = { { text, color, tag, until } }

local function wrap(text, perLine)
    local lines, line = {}, ''
    for word in text:gmatch('%S+') do
        if #line + #word + 1 > perLine then
            lines[#lines + 1] = line
            line = word
        else
            line = line == '' and word or (line .. ' ' .. word)
        end
    end
    if line ~= '' then lines[#lines + 1] = line end
    return lines
end

local function hexToRgb(hex)
    hex = (hex or '#E6EAF2'):gsub('#', '')
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

RegisterNetEvent('f_chat:bubble', function(serverId, text, color, tag)
    if not Config.Bubbles.enabled then return end
    bubbles[serverId] = bubbles[serverId] or {}
    table.insert(bubbles[serverId], {
        text  = text,
        color = color,
        tag   = tag,
        dies  = GetGameTimer() + (Config.Bubbles.duration * 1000),
    })
    while #bubbles[serverId] > Config.Bubbles.maxStack do
        table.remove(bubbles[serverId], 1)
    end
end)

local function draw3d(x, y, z, text, r, g, b, scale)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

CreateThread(function()
    while true do
        local wait = 500
        local anyone = false
        for _ in pairs(bubbles) do anyone = true break end

        if anyone and Config.Bubbles.enabled then
            wait = 0
            local myCoords = GetEntityCoords(PlayerPedId())
            local now = GetGameTimer()

            for serverId, stack in pairs(bubbles) do
                for i = #stack, 1, -1 do
                    if stack[i].dies < now then table.remove(stack, i) end
                end
                if #stack == 0 then
                    bubbles[serverId] = nil
                else
                    local playerIdx = GetPlayerFromServerId(serverId)
                    local ped = playerIdx ~= -1 and GetPlayerPed(playerIdx) or nil
                    if ped and ped ~= 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        if #(coords - myCoords) <= Config.Bubbles.distance then
                            local offset = 0.0
                            for i = #stack, 1, -1 do
                                local bubble = stack[i]
                                local r, g, b = hexToRgb(bubble.color)
                                local lines = wrap(bubble.text, 34)
                                for j = #lines, 1, -1 do
                                    draw3d(coords.x, coords.y, coords.z + 1.05 + offset,
                                        lines[j], r, g, b, Config.Bubbles.scale)
                                    offset = offset + 0.13
                                end
                                offset = offset + 0.06
                            end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)
