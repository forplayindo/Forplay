local messageId   = 0
local recent      = {}   -- [id] = { src, channel, name, text, time }
local lastSent    = {}   -- [src] = os.clock()
local lastChannel = {}   -- [src] = { [channelId] = os.clock() }
local mutes       = {}   -- [license] = expiry (os.time)
local tags        = {}   -- [license] = { label, color }
local suggestions = {}

local function channelById(id)
    for _, c in ipairs(Config.Channels) do
        if c.id == id then return c end
    end
end

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return ('src:%s'):format(src)
end

--============================================================
--  PERMISSIONS
--============================================================

function CanUseChannel(src, channel)
    local p = channel.permission or { type = 'open' }
    if p.type == 'open' then return true end
    if p.type == 'staff' then return Bridge.IsStaff(src) end
    if p.type == 'ace' then return IsPlayerAceAllowed(src, p.ace or Config.StaffAce) end
    if p.type == 'job' or p.type == 'grade' then
        if Bridge.IsStaff(src) and p.staffBypass ~= false then return true end
        local job = Bridge.GetJob(src)
        if not job then return false end
        for _, name in ipairs(p.jobs or {}) do
            if job.name == name then
                if p.type == 'grade' then return (job.grade or 0) >= (p.minGrade or 0) end
                return true
            end
        end
    end
    return false
end

local function visibleChannels(src)
    local list = {}
    for _, c in ipairs(Config.Channels) do
        if not c.commandOnly and CanUseChannel(src, c) then
            list[#list + 1] = {
                id = c.id, label = c.label, tag = c.tag, command = c.command,
                tab = c.tab or 'global',
                color = c.color, icon = c.icon, radius = c.radius,
                italic = c.italic, default = c.default,
            }
        end
    end
    return list
end

--============================================================
--  HELPERS
--============================================================

local function isMuted(src)
    local key = license(src)
    if mutes[key] and mutes[key] > os.time() then
        return true, math.ceil((mutes[key] - os.time()) / 60)
    end
    mutes[key] = nil
    return false
end

local function clean(text)
    text = text:gsub('%^%d', ''):gsub('~[a-z]~', '')
    for _, word in ipairs(Config.Moderation.blockedWords or {}) do
        text = text:gsub('()(' .. word:gsub('%W', '%%%0') .. ')()', function(_, m)
            return ('*'):rep(#m)
        end)
    end
    if #text > Config.MaxLength then text = text:sub(1, Config.MaxLength) end
    return text
end

local function receivers(src, channel)
    local out = {}
    local players = GetPlayers()

    if channel.staffOnlyView then
        out[#out + 1] = src
        for _, id in ipairs(players) do
            local pid = tonumber(id)
            if pid ~= src and Bridge.IsStaff(pid) then out[#out + 1] = pid end
        end
        return out
    end

    if not channel.radius then
        for _, id in ipairs(players) do
            local pid = tonumber(id)
            if CanUseChannel(pid, channel) then out[#out + 1] = pid end
        end
        return out
    end

    local origin = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(players) do
        local pid = tonumber(id)
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            if #(GetEntityCoords(ped) - origin) <= channel.radius then
                out[#out + 1] = pid
            end
        end
    end
    return out
end

local function webhook(url, channel, name, text, extra)
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'f_chat',
        embeds = { {
            title       = ('[%s] %s'):format(channel.tag, name),
            description = text,
            color       = tonumber(((channel.color or '#E0A458'):gsub('#', '')), 16),
            footer      = { text = extra or os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

--============================================================
--  SENDING
--============================================================

--- Broadcast a message object built by the server.
function SendMessage(src, channelId, text, opts)
    opts = opts or {}
    local channel = channelById(channelId)
    if not channel then return end

    if src and src > 0 then
        -- player yang tergeletak / mati tidak bisa chat (dicek server supaya tidak bisa diakali
        -- lewat F8 atau trigger event langsung)
        if Player(src).state.isDead then
            TriggerClientEvent('f_chat:notice', src, 'Kamu tidak bisa chat saat tidak sadarkan diri.', 'error')
            return
        end

        if not CanUseChannel(src, channel) then
            TriggerClientEvent('f_chat:notice', src, 'Kamu tidak punya akses ke channel itu.', 'error')
            return
        end

        local muted, minutes = isMuted(src)
        if muted then
            TriggerClientEvent('f_chat:notice', src, ('Kamu masih di-mute %s menit lagi.'):format(minutes), 'error')
            return
        end

        local now = os.clock()
        if Config.SlowMode > 0 and lastSent[src] and now - lastSent[src] < Config.SlowMode then
            TriggerClientEvent('f_chat:notice', src, 'Pelan-pelan, tunggu sebentar.', 'warn')
            return
        end
        lastSent[src] = now

        if channel.cooldown then
            lastChannel[src] = lastChannel[src] or {}
            local last = lastChannel[src][channel.id]
            if last and now - last < channel.cooldown then
                TriggerClientEvent('f_chat:notice', src,
                    ('%s sedang cooldown %s detik.'):format(channel.label, math.ceil(channel.cooldown - (now - last))), 'warn')
                return
            end
            lastChannel[src][channel.id] = now
        end
    end

    text = clean(text)
    if text == '' then return end

    if channel.roll then
        text = ('%s — %s'):format(text, math.random(100) > 50 and 'succeeded' or 'failed')
    end

    messageId = messageId + 1
    local name = opts.name or (src and src > 0 and Bridge.GetName(src)) or 'System'
    local tag  = not opts.anonymous and src and tags[license(src)] or nil

    local payload = {
        id        = messageId,
        channel   = channel.id,
        tab       = channel.tab or 'global',
        tag       = opts.tag or channel.tag,
        color     = opts.color or channel.color,
        icon      = channel.icon,
        italic    = channel.italic,
        name      = opts.anonymous and '' or name, -- anonymous: chat cuma menampilkan tag; log/webhook tetap nama asli
        serverId  = src,
        text      = text,
        time      = os.date('%H:%M'),
        badge     = tag,
        system    = opts.system,
        bubble    = channel.bubble and Config.Bubbles.enabled or false,
    }

    recent[messageId] = { src = src, channel = channel.id, name = name, text = text, time = os.time() }

    local targets = opts.targets or receivers(src, channel)
    for _, pid in ipairs(targets) do
        TriggerClientEvent('f_chat:message', pid, payload)
    end

    if payload.bubble and src and src > 0 then
        TriggerClientEvent('f_chat:bubble', -1, src, text, channel.color, channel.tag)
    end

    webhook(channel.webhook, channel, ('%s (%s)'):format(name, src or 0), text)
end

exports('SendMessage', SendMessage)

--============================================================
--  COMMANDS FROM CONFIG
--============================================================

CreateThread(function()
    for _, channel in ipairs(Config.Channels) do
        if channel.command then
            local names = { channel.command }
            for _, alias in ipairs(channel.aliases or {}) do names[#names + 1] = alias end

            for _, cmd in ipairs(names) do
                RegisterCommand(cmd, function(src, args, raw)
                    if src == 0 then
                        print(('[f_chat] %s is a player command.'):format(cmd))
                        return
                    end
                    local text = raw:sub(#cmd + 2)
                    if text:gsub('%s', '') == '' then
                        TriggerClientEvent('f_chat:notice', src, ('Usage: /%s [message]'):format(cmd), 'warn')
                        return
                    end
                    SendMessage(src, channel.id, text)
                end, false)
            end

            suggestions[#suggestions + 1] = {
                name = ('/%s'):format(channel.command),
                help = channel.label,
                params = { { name = 'message', help = 'Apa yang ingin kamu katakan' } },
            }
        end
    end
end)

--============================================================
--  /announce — pengumuman atas nama instansi (Config.Announce.jobs).
--  Di chat hanya tampil nama instansi, tanpa nama pemain.
--============================================================

RegisterCommand('announce', function(src, args, raw)
    if src == 0 then
        print('[f_chat] announce is a player command.')
        return
    end
    local job = Bridge.GetJob(src)
    local org = job and Config.Announce.jobs[job.name]
    if not org then
        TriggerClientEvent('f_chat:notice', src, 'Pekerjaanmu tidak bisa membuat pengumuman.', 'error')
        return
    end
    if not Bridge.IsStaff(src) then
        if Config.Announce.onDuty and not job.onDuty then
            TriggerClientEvent('f_chat:notice', src, 'Kamu harus on duty untuk membuat pengumuman.', 'error')
            return
        end
        if (job.grade or 0) < (org.minGrade or 0) then
            TriggerClientEvent('f_chat:notice', src, 'Jabatanmu belum cukup untuk membuat pengumuman.', 'error')
            return
        end
    end
    local text = raw:sub(#'announce' + 2)
    if text:gsub('%s', '') == '' then
        TriggerClientEvent('f_chat:notice', src, 'Usage: /announce [message]', 'warn')
        return
    end
    SendMessage(src, 'announce', text, { tag = org.name, color = org.color, anonymous = true })
end, false)

suggestions[#suggestions + 1] = {
    name = '/announce',
    help = 'Pengumuman ke semua warga atas nama instansimu (on duty)',
    params = { { name = 'message', help = 'Isi pengumuman' } },
}

--- /announceadmin: seperti /announce, tapi untuk staf tanpa perlu job — selalu tampil
--- dengan nama & warna Config.Announce.admin.
RegisterCommand('announceadmin', function(src, args, raw)
    if src == 0 then
        print('[f_chat] announceadmin is a player command.')
        return
    end
    if not Bridge.IsStaff(src) then
        TriggerClientEvent('f_chat:notice', src, 'Kamu tidak punya akses ke perintah itu.', 'error')
        return
    end
    local text = raw:sub(#'announceadmin' + 2)
    if text:gsub('%s', '') == '' then
        TriggerClientEvent('f_chat:notice', src, 'Usage: /announceadmin [message]', 'warn')
        return
    end
    local admin = Config.Announce.admin
    SendMessage(src, 'announce', text, { tag = admin.name, color = admin.color, anonymous = true })
end, false)

suggestions[#suggestions + 1] = {
    name = '/announceadmin',
    help = 'Pengumuman sebagai Admin (khusus staf)',
    params = { { name = 'message', help = 'Isi pengumuman' } },
}

--============================================================
--  CLIENT ENTRY POINTS
--============================================================

RegisterNetEvent('f_chat:send', function(channelId, text)
    local src = source
    if type(text) ~= 'string' or text:gsub('%s', '') == '' then return end
    local channel = channelById(channelId)
    if channel and channel.commandOnly then return end -- mis. announce: hanya lewat /announce
    SendMessage(src, channelId, text)
end)

RegisterNetEvent('f_chat:requestInit', function()
    local src = source
    TriggerClientEvent('f_chat:init', src, {
        channels    = visibleChannels(src),
        themes      = Config.Themes,
        fonts       = Config.Fonts,
        defaults    = Config.DefaultTheme,
        staff       = Bridge.IsStaff(src),
        maxLength   = Config.MaxLength,
        fadeAfter   = Config.FadeAfter,
        announceFadeAfter = Config.AnnounceFadeAfter,
        suggestions = suggestions,
        serverId    = src,
    })
end)

-- Refresh the channel list after a job change
RegisterNetEvent('f_chat:refresh', function()
    local src = source
    TriggerClientEvent('f_chat:channels', src, visibleChannels(src), Bridge.IsStaff(src))
end)

RegisterNetEvent('f_chat:typing', function(channelId, state)
    local src = source
    local channel = channelById(channelId)
    if not channel or not CanUseChannel(src, channel) then return end
    for _, pid in ipairs(receivers(src, channel)) do
        if pid ~= src then
            TriggerClientEvent('f_chat:typing', pid, src, Bridge.GetName(src), state and true or false)
        end
    end
end)

RegisterNetEvent('f_chat:react', function(id, emoji)
    local src = source
    if not recent[id] then return end
    TriggerClientEvent('f_chat:react', -1, id, emoji, src)
end)

--============================================================
--  MODERATION
--============================================================

RegisterNetEvent('f_chat:moderate', function(action, id, value)
    local src = source
    if not Bridge.IsStaff(src) then return end
    local msg = recent[id]
    if not msg then return end

    if action == 'delete' and Config.Moderation.allowDelete then
        TriggerClientEvent('f_chat:delete', -1, id)
        recent[id] = nil
    elseif action == 'edit' and Config.Moderation.allowEdit then
        local text = clean(tostring(value or ''))
        if text == '' then return end
        msg.text = text
        TriggerClientEvent('f_chat:edit', -1, id, text)
    elseif action == 'mute' and Config.Moderation.allowMute and msg.src then
        local minutes = tonumber(value) or Config.Moderation.defaultMute
        mutes[license(msg.src)] = os.time() + (minutes * 60)
        TriggerClientEvent('f_chat:notice', msg.src, ('Kamu di-mute selama %s menit.'):format(minutes), 'error')
        TriggerClientEvent('f_chat:notice', src, ('%s di-mute selama %s menit.'):format(msg.name, minutes), 'ok')
    end

    webhook(Config.Moderation.logWebhook,
        { tag = 'MOD', color = '#D9534F' },
        Bridge.GetName(src),
        ('%s on message #%s by %s: %s'):format(action, id, msg.name, msg.text))
end)

RegisterCommand('mute', function(src, args)
    if src ~= 0 and not Bridge.IsStaff(src) then return end
    local target = tonumber(args[1])
    local minutes = tonumber(args[2]) or Config.Moderation.defaultMute
    if not target or not GetPlayerName(target) then return end
    mutes[license(target)] = os.time() + (minutes * 60)
    TriggerClientEvent('f_chat:notice', target, ('Kamu di-mute selama %s menit.'):format(minutes), 'error')
end, true)

RegisterCommand('unmute', function(src, args)
    if src ~= 0 and not Bridge.IsStaff(src) then return end
    local target = tonumber(args[1])
    if not target then return end
    mutes[license(target)] = nil
    TriggerClientEvent('f_chat:notice', target, 'Kamu bisa bicara lagi.', 'ok')
end, true)

--============================================================
--  PLAYER TAGS
--============================================================

if Config.Tags.enabled then
    RegisterCommand('tag', function(src, args)
        if src ~= 0 and not Bridge.IsStaff(src) then return end
        local target = tonumber(args[1])
        if not target or not GetPlayerName(target) then return end
        local label = args[2]
        if not label or label == 'clear' then
            tags[license(target)] = nil
            return
        end
        local color = args[3]
        if not color then
            for _, preset in ipairs(Config.Tags.presets) do
                if preset.id == label:lower() then
                    label, color = preset.label, preset.color
                    break
                end
            end
        end
        tags[license(target)] = { label = label:upper(), color = color or '#E0A458' }
        TriggerClientEvent('f_chat:notice', target, ('Kamu sekarang memakai badge %s.'):format(label:upper()), 'ok')
    end, true)
end

--============================================================
--  AUTOMATIC MESSAGES
--============================================================

if Config.AutoMessages.enabled then
    for _, auto in ipairs(Config.AutoMessages.messages) do
        CreateThread(function()
            while true do
                Wait(auto.interval * 60000)
                local targets = {}
                for _, id in ipairs(GetPlayers()) do
                    local pid = tonumber(id)
                    if auto.audience ~= 'staff' or Bridge.IsStaff(pid) then targets[#targets + 1] = pid end
                end
                for _, pid in ipairs(targets) do
                    TriggerClientEvent('f_chat:message', pid, {
                        id      = -1,
                        channel = 'system',
                        tag     = (auto.title or 'INFO'):upper(),
                        color   = auto.color or '#6FBF8B',
                        icon    = auto.icon or 'info',
                        name    = auto.title or 'BOT',
                        text    = auto.text,
                        time    = os.date('%H:%M'),
                        system  = true,
                    })
                end
            end
        end)
    end
end

--============================================================
--  LEGACY chat:* COMPATIBILITY
--============================================================

RegisterNetEvent('_chat:messageEntered', function(name, color, message)
    local src = source
    if not message or message == '' then return end
    TriggerEvent('chatMessage', src, name, message)
    if not WasEventCanceled() then
        local fallback = channelById('ooc') or Config.Channels[1]
        SendMessage(src, fallback.id, message)
    end
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
    suggestions[#suggestions + 1] = { name = name, help = help, params = params }
    TriggerClientEvent('chat:addSuggestion', -1, name, help, params)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastSent[src], lastChannel[src] = nil, nil
end)

-- Housekeeping: drop message records older than an hour
CreateThread(function()
    while true do
        Wait(600000)
        local cutoff = os.time() - 3600
        for id, msg in pairs(recent) do
            if msg.time < cutoff then recent[id] = nil end
        end
    end
end)

--============================================================
--  exports.chat:xxx (server) — alias supaya script yang masih memanggil
--  resource 'chat' tidak error "No such export ... in resource chat".
--  Signature sama dengan resource chat bawaan: addMessage(target, message)
--============================================================

local function exportAs(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_chat_%s'):format(name), function(setCB) setCB(fn) end)
end

exportAs('addMessage', function(target, message)
    if target == nil or message == nil then return end
    TriggerClientEvent('chat:addMessage', target, message)
end)

exportAs('addSuggestion', function(target, name, help, params)
    if target == nil then return end
    TriggerClientEvent('chat:addSuggestion', target, name, help, params)
end)

exportAs('removeSuggestion', function(target, name)
    if target == nil then return end
    TriggerClientEvent('chat:removeSuggestion', target, name)
end)
