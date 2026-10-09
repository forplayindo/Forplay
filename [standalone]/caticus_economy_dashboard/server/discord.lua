Discord = Discord or {}

local function isEnabled()
    return Config.Discord and Config.Discord.enabled
end

local function getWebhook(kind)
    if not Config.Discord then return nil end
    if kind == 'alert' then return Config.Discord.alertWebhook end
    if kind == 'daily' then return Config.Discord.dailyReportWebhook end
    if kind == 'weekly' then return Config.Discord.weeklyReportWebhook end
    if kind == 'admin' then return Config.Discord.adminLogWebhook end
    return nil
end

function Discord.Send(kind, title, description, color)
    if not isEnabled() then return false end
    local webhook = getWebhook(kind)
    if not webhook or webhook == '' then return false end

    local payload = {
        username = Config.Discord.botName or 'Economy Dashboard',
        avatar_url = (Config.Discord.botAvatar ~= '' and Config.Discord.botAvatar) or nil,
        embeds = {
            {
                title = title or 'Economy Dashboard',
                description = description or '',
                color = color or 31487,
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            }
        }
    }

    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
    return true
end

function Discord.Test(kind)
    return Discord.Send(kind, 'Webhook Test', 'Economy Dashboard webhook is working.', 0x00d4ff)
end

