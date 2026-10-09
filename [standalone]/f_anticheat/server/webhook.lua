Webhook = {}

local colors = {
    red = 15158332,
    orange = 15105570,
    yellow = 16776960,
    green = 3066993,
}

---@param title string
---@param description string
---@param color 'red'|'orange'|'yellow'|'green'
function Webhook.Send(title, description, color)
    if not Config.Webhook or Config.Webhook == '' then return end

    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'f_anticheat',
        embeds = { {
            title = title,
            description = description,
            color = colors[color] or colors.orange,
        } }
    }), { ['Content-Type'] = 'application/json' })
end
