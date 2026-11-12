-- Banner + hasil test dimatikan biar console bersih; yang gagal tetap di-print.
local okOxmysql, okFramework, okConfig = tests.checkForOxmysql(), tests.checkForFramework(), tests.checkForConfig()

if not (okOxmysql and okFramework and okConfig) then
    testPrint("Oxmysql is installed.", "Oxmysql is not installed!", okOxmysql)
    testPrint(Config.Framework .. " is installed.", Config.Framework .. "is not installed!", okFramework)
    testPrint("Config found.", "Config not found!", okConfig)
    cPrint("^1One or more tests failed!^0", "error")
    return
end

createTableIfNotExist()

if Config.Framework == "ESX" then
    if FrameworkObject.RegisterCommand then
        FrameworkObject.RegisterCommand(getCommandString(), getCommandRang(), function(xPlayer, args, showError)
                local id = args.id
                local target = id

                if not target then
                    cPrint("Player not found!", "error")
                    return
                end

                ToggleTrollProtection(target)
                cPrint("Troll protection toggled for " .. target.name .. " for " .. Config.HowLong .. " min!", "info")
            end, true,
            { help = "Toggle Troll Protection", arguments = { { name = "id", help = "Player ID", type = "player" } } })
    else
        RegisterCommand(getCommandString(), function(source, args, rawCommand)
            if IsPlayerAceAllowed(source, getCommandRang()) then
                local id = args.id
                local target = id

                if not target then
                    cPrint("Player not found!", "error")
                    return
                end

                ToggleTrollProtection(target)
                cPrint("Troll protection toggled for " .. target.name .. " for " .. Config.HowLong .. " min!", "info")
            else
                cPrint("You don't have permission to use this command!", "error")
            end
        end, true)
    end
elseif Config.Framework == "QBCore" then
    FrameworkObject.Commands.Add(getCommandString(), "Toggle Troll Protection", {}, false, function(source, args)
        local target = tonumber(args[1]) or source
        if not target or not GetPlayerName(target) then
            cPrint("Player not found!", "error")
            return
        end

        local on = ToggleTrollProtection(target)
        cPrint(("Troll protection %s for %s"):format(on and ("ON " .. Config.HowLong .. " min") or "OFF", target), "info")
    end, getCommandRang())
end

-- Server-authoritative: server yang menghitung sisa waktu (os.time), client cuma tampilan.
-- Disimpan ke DB tiap Config.TimeToSave menit, saat logout/keluar, dan saat resource stop.
local active = {} -- [src] = { id = identifier, base = menit saat mulai, started = os.time() }

local function minutesLeft(e)
    return math.max(0, e.base - math.floor((os.time() - e.started) / 60))
end

local function saveEntry(e)
    update(e.id, minutesLeft(e))
end

local function startFor(src, identifier, minutes)
    active[src] = { id = identifier, base = minutes, started = os.time() }
    updateOrInsert(identifier, minutes)
    TriggerClientEvent("bk_antitroll:toggle", src, true, minutes)
end

local function stopFor(src)
    local e = active[src]
    if not e then return end
    active[src] = nil
    update(e.id, 0)
    TriggerClientEvent("bk_antitroll:toggle", src, false, 0)
end

local function pauseFor(src)
    local e = active[src]
    if not e then return end
    active[src] = nil
    saveEntry(e)
end

function ToggleTrollProtection(target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false end
    if active[target] then
        stopFor(target)
        return false
    end
    local identifier = GetPlayerIdentifier(target)
    if not identifier then return false end
    startFor(target, identifier, Config.HowLong)
    return true
end

RegisterNetEvent("bk_antitroll:onjoin", function()
    local src = source
    local e = active[src]
    if e then
        -- ganti karakter / event dobel: kirim ulang sisa waktu, jangan reset
        TriggerClientEvent("bk_antitroll:toggle", src, true, minutesLeft(e))
        return
    end

    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local time = isNewPlayer(identifier) and Config.HowLong or getTimeLeft(identifier)
    if time > 0 then
        startFor(src, identifier, time)
    end
end)

AddEventHandler("playerDropped", function()
    pauseFor(source)
end)

AddEventHandler("QBCore:Server:OnPlayerUnload", function(src)
    pauseFor(src)
end)

AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(active) do saveEntry(e) end
end)

CreateThread(function()
    local tick = 0
    while true do
        Wait(60000)
        tick = tick + 1
        local doSave = tick % math.max(1, Config.TimeToSave) == 0
        for src, e in pairs(active) do
            if not GetPlayerName(src) then
                active[src] = nil
                saveEntry(e)
            elseif minutesLeft(e) <= 0 then
                stopFor(src)
            elseif doSave then
                saveEntry(e)
            end
        end
    end
end)
