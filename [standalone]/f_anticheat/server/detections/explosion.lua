if not Config.Explosion.enabled then return end

---@type table<integer, { windowStart: integer, count: integer }>
local windows = {}

AddEventHandler('explosionEvent', function(sender, ev)
    if sender == 0 then return end

    local now = GetGameTimer()
    local w = windows[sender]
    if not w or (now - w.windowStart) > Config.Explosion.windowMs then
        w = { windowStart = now, count = 0 }
        windows[sender] = w
    end

    w.count = w.count + 1

    if w.count > Config.Explosion.maxExplosions then
        CancelEvent()
        Punish.Flag(sender, 'explosion', Config.Explosion.points, ('triggered %d explosions in %dms'):format(w.count, Config.Explosion.windowMs))
    end
end)

AddEventHandler('playerDropped', function()
    windows[source] = nil
end)
