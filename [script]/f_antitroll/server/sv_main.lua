print([[^1
     _   _  _ _____ ___   _____ ___  ___  _    _
    /_\ | \| |_   _|_ _| |_   _| _ \/ _ \| |  | |
   / _ \| .` | | |  | |    | | |   / (_) | |__| |__
  /_/ \_\_|\_| |_| |___|   |_| |_|_\\___/|____|____|
          ^8by ZerX (github.com/ZerXGIT)^0
^0---------------------[^2Tests^0]---------------------]])


testPrint("Oxmysql is installed.", "Oxmysql is not installed!", tests.checkForOxmysql())
testPrint(Config.Framework .. " is installed.", Config.Framework .. "is not installed!", tests.checkForFramework())
testPrint("Config found.", "Config not found!", tests.checkForConfig())
print([[^0---------------------[^2Tests^0]---------------------]])

if tests.checkForOxmysql() and tests.checkForFramework() and tests.checkForConfig() then
    cPrint("All tests passed!", "info")
else
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
        local id = args[1]
        local target = id or source
        print(target)
        -- check if source exists on the server
        if not GetPlayerName(target) then
            cPrint("Player not found!", "error")
            return
        end

        if not target then
            cPrint("Player not found!", "error")
            return
        end

        ToggleTrollProtection(target)
        cPrint("Troll protection toggled for " .. target .. " for " .. Config.HowLong .. " min!", "info")
    end, getCommandRang())
end
function ToggleTrollProtection(target, toogleOverride, timeOverride)
    TriggerClientEvent("bk_antitroll:toggle", target, timeOverride)
end

RegisterNetEvent("bk_antitroll:updateTime", function(time)
    local identifier = GetPlayerIdentifier(source)

    time = tonumber(time)
    if not time or time < 0 then return end

    if not doesUserExist(identifier) then
        -- First sync after join: accept up to the configured protection length only.
        insert(identifier, math.min(time, Config.HowLong))
        return
    end

    local current = getTimeLeft(identifier)

    -- The client ticks this down by ~1 per minute. Never allow it to jump back up
    -- (extend protection) or skip straight down past a single tick (bypass it early).
    if time > current or (current - time) > 1 then return end

    update(identifier, time)
end)

RegisterNetEvent("bk_antitroll:onjoin", function()
    local source = source
    local identifier = GetPlayerIdentifier(source)
    local isNew = isNewPlayer(identifier)
    onJoin(source, identifier, isNew)
end)

function onJoin(source, identifier, isNew)
    if isNew then
        ToggleTrollProtection(source, true, Config.HowLong)
        return
    end

    local time = getTimeLeft(identifier)

    if time > 0 then
        TriggerClientEvent("bk_antitroll:toggle", source, true, time)
        return
    end

    updateOrInsert(identifier, time)
end
