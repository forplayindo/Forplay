local open      = false
local ready     = false
local settings  = {}
local staff     = false
local pendingOpen = nil -- tombol chat ditekan sebelum init datang: false = default, 'ooc' = tab OOC

--============================================================
--  SETTINGS (saved per player on this machine)
--============================================================

local function loadSettings()
    local raw = GetResourceKvpString('f_chat:settings')
    settings = raw and json.decode(raw) or {}
    for key, value in pairs(Config.DefaultTheme) do
        if settings[key] == nil then settings[key] = value end
    end
end

local function saveSettings()
    SetResourceKvp('f_chat:settings', json.encode(settings))
end

--============================================================
--  NUI
--============================================================

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setOpen(state, channelId)
    open = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
    send('focus', { open = state, channel = channelId })
end

RegisterNetEvent('f_chat:init', function(payload)
    ready = true
    staff = payload.staff
    loadSettings()
    payload.settings = settings
    send('init', payload)
    send('suggestion', { name = '/clearchat', help = 'Bersihkan tab yang sedang dibuka (hanya di layar kamu)' })
    if pendingOpen ~= nil and not open and not IsPauseMenuActive() then
        setOpen(true, pendingOpen or nil)
    end
    pendingOpen = nil
end)

RegisterNetEvent('f_chat:channels', function(channels, isStaff)
    staff = isStaff
    send('channels', { channels = channels, staff = isStaff })
end)

RegisterNetEvent('f_chat:message', function(payload)
    send('message', payload)
    if settings.sound ~= false and payload.mention then
        PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    end
end)

RegisterNetEvent('f_chat:notice', function(text, kind)
    send('message', {
        id = -1, channel = 'system', tag = 'SYSTEM', color = kind == 'error' and '#D9534F'
            or kind == 'warn' and '#E0A458' or '#6FBF8B',
        notice = true, -- tampil di tab yang sedang dibuka
        icon = 'info', name = 'Reminder', text = text, time = GetClockHours() and
            ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) or '', system = true,
    })
end)

RegisterNetEvent('f_chat:delete', function(id) send('delete', { id = id }) end)
RegisterNetEvent('f_chat:edit', function(id, text) send('edit', { id = id, text = text }) end)
RegisterNetEvent('f_chat:react', function(id, emoji, from) send('react', { id = id, emoji = emoji, from = from }) end)
RegisterNetEvent('f_chat:typing', function(serverId, name, state)
    send('typing', { id = serverId, name = name, state = state })
end)

--============================================================
--  NUI CALLBACKS
--============================================================

RegisterNUICallback('send', function(data, cb)
    if data.text and data.text ~= '' then
        if data.text:sub(1, 1) == '/' then
            ExecuteCommand(data.text:sub(2))
        else
            TriggerServerEvent('f_chat:send', data.channel, data.text)
        end
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb('ok')
end)

RegisterNUICallback('typing', function(data, cb)
    TriggerServerEvent('f_chat:typing', data.channel, data.state)
    cb('ok')
end)

RegisterNUICallback('react', function(data, cb)
    TriggerServerEvent('f_chat:react', data.id, data.emoji)
    cb('ok')
end)

RegisterNUICallback('moderate', function(data, cb)
    TriggerServerEvent('f_chat:moderate', data.action, data.id, data.value)
    cb('ok')
end)

RegisterNUICallback('settings', function(data, cb)
    for key, value in pairs(data or {}) do settings[key] = value end
    saveSettings()
    cb('ok')
end)

--============================================================
--  KEYS
--============================================================

-- isDead di-set server oleh f_medical (true saat last stand / mati)
local function isDead()
    return LocalPlayer.state.isDead == true
end

-- belum siap: ingat tombolnya, minta init sekarang juga, buka begitu init datang
local function requestOpen(channelId)
    if open or IsPauseMenuActive() or isDead() then return end
    if ready then return setOpen(true, channelId) end
    pendingOpen = channelId or false
    TriggerServerEvent('f_chat:requestInit')
end

RegisterCommand('+nxchat', function() requestOpen() end, false)
RegisterCommand('-nxchat', function() end, false)
RegisterKeyMapping('+nxchat', 'Buka chat', 'keyboard', 'T')
-- tidak ada tombol OOC: OOC cukup lewat /ooc (Z dipakai radial)

-- chat yang sedang terbuka ditutup begitu player tergeletak
AddStateBagChangeHandler('isDead', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value and open then setOpen(false) end
end)

--============================================================
--  STARTUP
--============================================================

CreateThread(function()
    loadSettings()
    while not NetworkIsSessionStarted() do Wait(250) end
    -- kirim ulang sampai init datang; satu permintaan bisa telat/hilang saat server sibuk
    while not ready do
        TriggerServerEvent('f_chat:requestInit')
        Wait(2000)
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if NetworkIsSessionStarted() then
        Wait(400)
        TriggerServerEvent('f_chat:requestInit')
    end
end)

-- Re-evaluate channel access when the job changes (and once the character is loaded,
-- since init may land on the character-select screen before there's a job)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('f_chat:refresh') end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() TriggerServerEvent('f_chat:refresh') end)
RegisterNetEvent('qbx_core:client:onJobUpdate', function() TriggerServerEvent('f_chat:refresh') end)
RegisterNetEvent('esx:setJob', function() TriggerServerEvent('f_chat:refresh') end)

--============================================================
--  LEGACY chat:* API — keeps every other resource working
--============================================================

local function stripColours(text)
    return (text:gsub('%^%d', ''))
end

local function legacyMessage(message)
    -- payload format asli f_chat (mis. dari exports.f_chat / script sendiri)
    if type(message) == 'table' and message.channel and message.text and not message.args then
        send('message', message)
        return
    end

    local text, name, colour = '', 'System', nil

    if type(message) == 'string' then
        text = message
    elseif type(message) == 'table' then
        if message.args then
            if #message.args > 1 then
                name = tostring(message.args[1])
                text = table.concat(message.args, ' ', 2)
            else
                text = tostring(message.args[1] or '')
            end
        end
        if message.templateId and message.multiline then
            text = tostring(message.args and message.args[1] or text)
        end
        if message.color then
            colour = ('#%02X%02X%02X'):format(message.color[1] or 224, message.color[2] or 164, message.color[3] or 88)
        end
    end

    send('message', {
        id = -1,
        channel = 'system',
        tag = 'INFO',
        color = colour or '#8D97AB',
        icon = 'info',
        name = stripColours(name),
        text = stripColours(text),
        time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        system = true,
    })
end

RegisterNetEvent('chat:addMessage', legacyMessage)

RegisterNetEvent('chat:clear', function() send('clear', {}) end)

-- /clearchat: bersihkan tab yang sedang dibuka, di layar sendiri saja
RegisterCommand('clearchat', function() send('clear', { current = true }) end, false)

local function addSuggestion(name, help, params)
    send('suggestion', { name = name, help = help, params = params })
end

RegisterNetEvent('chat:addSuggestion', addSuggestion)

RegisterNetEvent('chat:addSuggestions', function(list)
    if not list then return end
    -- ox_lib's lib.addCommand sends a proper array for its first batch, but a
    -- single suggestion table (not wrapped in an array) for every command
    -- registered afterwards — handle both shapes.
    if list.name then
        send('suggestion', { name = list.name, help = list.help, params = list.params })
        return
    end
    for _, item in ipairs(list) do
        send('suggestion', { name = item.name, help = item.help, params = item.params })
    end
end)

local function removeSuggestion(name)
    send('removeSuggestion', { name = name })
end

RegisterNetEvent('chat:removeSuggestion', removeSuggestion)

-- Old okokChat style events, harmlessly mapped
RegisterNetEvent('okokChat:sendServerMessage', function(title, text, colour)
    send('message', {
        id = -1, channel = 'system', tag = (title or 'INFO'):upper(), color = colour or '#8D97AB',
        icon = 'info', name = title or 'BOT', text = text or '', system = true,
        time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
    })
end)

--============================================================
--  EXPORTS
--  Resource ini `provide 'chat'`, tapi FiveM TIDAK otomatis mengalihkan
--  exports.chat:xxx ke resource yang provide. Akibatnya qbx_core error:
--    "No such export addMessage in resource chat"
--  Karena itu setiap export juga didaftarkan atas nama 'chat'.
--============================================================

local function exportAs(name, fn)
    exports(name, fn)                                            -- exports.f_chat:name
    AddEventHandler(('__cfx_export_chat_%s'):format(name),       -- exports.chat:name
        function(setCB) setCB(fn) end)
end

exportAs('isOpen',           function() return open end)
exportAs('addMessage',       legacyMessage)
exportAs('addSuggestion',    addSuggestion)
exportAs('removeSuggestion', removeSuggestion)
exportAs('clear',            function() send('clear', {}) end)
