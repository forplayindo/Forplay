if not Config.Health.enabled then return end

-- Log-only: too many legitimate systems (armor, downed/laststand state, medical
-- revives, PVP toggle, damage multiplier configs) can look identical to
-- invincibility from the server's point of view, so this never auto-punishes.
-- It exists so staff can spot a pattern (same player, over and over) in the
-- webhook and investigate manually.

---@type table<integer, { hits: integer, windowStart: integer }>
local noDamage = {}

AddEventHandler('weaponDamageEvent', function(sender, data)
    pcall(function()
        local targetPed = data.hitGlobalIds and data.hitGlobalIds[1]
        if not targetPed then return end

        local targetSource = NetworkGetEntityOwner(NetworkGetEntityFromNetworkId(targetPed))
        if not targetSource or targetSource == 0 or targetSource == sender then return end

        local health = GetEntityHealth(GetPlayerPed(targetSource --[[@as string]]))
        local now = GetGameTimer()
        local w = noDamage[targetSource]
        if not w or (now - w.windowStart) > 15000 then
            w = { windowStart = now, hits = 0 }
            noDamage[targetSource] = w
        end

        -- damage was registered but the target's health didn't move and they're
        -- not simply full-health-with-armor soaking it - worth a look, not a verdict
        if data.overrideDefaultDamage == false and health and health >= 200 then
            w.hits = w.hits + 1
            if w.hits == 5 then
                Webhook.Send('🕵️ Possible invincibility',
                    ('**%s** has taken %d hits in the last 15s without any health loss. Log-only, please verify manually.')
                    :format(GetPlayerName(targetSource) or targetSource, w.hits), 'yellow')
            end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    noDamage[source] = nil
end)
