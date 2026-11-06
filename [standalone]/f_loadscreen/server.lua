local RES = GetCurrentResourceName()

-- ====================================================================
-- Konten: data/news.json + data/tips.json (dibaca ulang tiap 10 detik)
-- exports SetNews/SetTips menang atas file
-- ====================================================================
local pushed = { news = nil, tips = nil }
local cache = { news = {}, tips = {}, at = -1 }

local function stripColors(s)
    return (tostring(s or ''):gsub('%^%d', ''):gsub('~[%a]~', ''))
end

local function readJson(path)
    local raw = LoadResourceFile(RES, path)
    if not raw or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if not ok then
        print(('^3[f_loadscreen] %s bukan JSON valid^7'):format(path))
        return nil
    end
    return data
end

local function normNews(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    if list.news then list = list.news end
    for _, n in ipairs(list) do
        if type(n) == 'table' and (n.title or n.body) then
            local body = n.body
            if type(body) == 'string' then
                local lines = {}
                for line in body:gmatch('[^\r\n]+') do lines[#lines + 1] = line end
                body = lines
            elseif type(body) ~= 'table' then
                body = {}
            end
            out[#out + 1] = {
                title = n.title and tostring(n.title) or nil,
                date = n.date and tostring(n.date) or nil,
                tag = n.tag and tostring(n.tag) or nil,
                body = body,
            }
            if #out >= 12 then break end
        end
    end
    return out
end

local function normTips(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    if list.tips then list = list.tips end
    for _, t in ipairs(list) do
        if type(t) == 'string' and t ~= '' then
            out[#out + 1] = t
            if #out >= 30 then break end
        end
    end
    return out
end

local function getContent(force)
    local now = GetGameTimer()
    if force or cache.at < 0 or now - cache.at > 10000 then
        cache.news = normNews(readJson('data/news.json'))
        cache.tips = normTips(readJson('data/tips.json'))
        cache.at = now
    end
    return pushed.news or cache.news, pushed.tips or cache.tips
end

exports('SetNews', function(list) pushed.news = list and normNews(list) or nil end)
exports('SetTips', function(list) pushed.tips = list and normTips(list) or nil end)

local function serverName()
    return stripColors(GetConvar('sv_projectName', ''))
end

-- ====================================================================
-- Handover: data ini sudah ada di frame pertama loadscreen
-- (window.nuiHandoverData), sebelum client script sempat jalan
-- ====================================================================
AddEventHandler('playerConnecting', function(name, _, deferrals)
    local news, tips = getContent()
    deferrals.handover({
        name = stripColors(name),
        players = GetNumPlayerIndices(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        serverName = serverName(),
        news = news,
        tips = tips,
    })
end)

-- ====================================================================
-- Statistik live (dibatasi 1x per detik per pemain)
-- ====================================================================
local lastAsk = {}

RegisterNetEvent('f_loadscreen:stats', function()
    local src = source
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < 1000 then return end
    lastAsk[src] = now
    TriggerClientEvent('f_loadscreen:stats', src, {
        players = GetNumPlayerIndices(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        ping = GetPlayerPing(src),
        serverName = serverName(),
    })
end)

RegisterNetEvent('f_loadscreen:content', function()
    local src = source
    local news, tips = getContent()
    TriggerClientEvent('f_loadscreen:content', src, news, tips)
end)

AddEventHandler('playerDropped', function()
    lastAsk[source] = nil
end)

-- ====================================================================
-- Gerbang peraturan
--   setr fls:rulesGate 1        aktifkan
--   setr fls:rulesVersion 1     naikkan = semua ditanya lagi
--   setr fls:rulesMode version  'version' sekali per versi, 'always' tiap join
-- ====================================================================
local ACCEPT_FILE = 'data/rules_accepted.json'
local accepted = readJson(ACCEPT_FILE) or {}

local function saveAccepted()
    SaveResourceFile(RES, ACCEPT_FILE, json.encode(accepted), -1)
end

local function gateVersion()
    return GetConvarInt('fls:rulesVersion', 1)
end

local function license(src)
    return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'license2')
end

local function needsGate(src)
    if GetConvarInt('fls:rulesGate', 0) ~= 1 then return false end
    if GetConvar('fls:rulesMode', 'version') == 'always' then return true end
    local id = license(src)
    if not id then return true end
    return accepted[id] ~= gateVersion()
end

RegisterNetEvent('f_loadscreen:gateCheck', function()
    local src = source
    if needsGate(src) then
        TriggerClientEvent('f_loadscreen:gate', src, gateVersion())
    else
        TriggerClientEvent('f_loadscreen:gateOff', src)
    end
end)

RegisterNetEvent('f_loadscreen:gateAccept', function(version)
    local src = source
    if tonumber(version) ~= gateVersion() then
        TriggerClientEvent('f_loadscreen:gate', src, gateVersion())
        return
    end
    local id = license(src)
    if id and GetConvar('fls:rulesMode', 'version') ~= 'always' then
        accepted[id] = gateVersion()
        saveAccepted()
    end
    TriggerClientEvent('f_loadscreen:gateAccepted', src)
end)

RegisterNetEvent('f_loadscreen:gateDecline', function(msg)
    local src = source
    DropPlayer(src, type(msg) == 'string' and msg:sub(1, 200) or 'Peraturan server tidak disetujui.')
end)

-- ====================================================================
-- Perintah console / admin
-- ====================================================================
RegisterCommand('fls_reload', function(src)
    local news, tips = getContent(true)
    local msg = ('[f_loadscreen] berita: %d, tips: %d'):format(#news, #tips)
    if src == 0 then print(msg) else TriggerClientEvent('chat:addMessage', src, { args = { msg } }) end
end, true)

-- fls_rules_reset all | <server id> | me | license:xxxx
RegisterCommand('fls_rules_reset', function(src, args)
    local target = args[1]
    if not target then print('pakai: fls_rules_reset all | <id> | me | license:xxx') return end
    if target == 'all' then
        accepted = {}
    else
        local id
        if target == 'me' then
            id = src ~= 0 and license(src) or nil
        elseif tonumber(target) then
            id = license(tonumber(target))
        else
            id = target
        end
        if not id then print('[f_loadscreen] identifier tidak ditemukan') return end
        accepted[id] = nil
    end
    saveAccepted()
    print(('[f_loadscreen] reset peraturan: %s'):format(target))
end, true)
