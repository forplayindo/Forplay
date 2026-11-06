-- Log ke Discord saja, tidak disimpan di database. URL di convar server (tidak pernah ke client):
--   set f_admin_webhook         "https://discord.com/api/webhooks/..."  -- utama / lainnya
--   set f_admin_webhook_ekonomi "https://discord.com/api/webhooks/..."  -- kosong = ikut utama
--   set f_admin_webhook_sanksi  "https://discord.com/api/webhooks/..."
local RESOURCE = GetCurrentResourceName()
local ROLE_LABEL = { owner = 'Owner', admin = 'Admin', support = 'Support' }

-- webhook per channel (Config.LogChannels); kosong = pakai utama
local Hooks = {}
for _, c in ipairs(Config.LogChannels) do Hooks[c.key] = GetConvar(c.convar, '') end

local KindChannel = {}
for _, l in ipairs(Config.Logs) do KindChannel[l.key] = l.ch or 'utama' end

local function hookOf(ch)
    local url = Hooks[ch or 'utama'] or ''
    if url == '' then url = Hooks.utama or '' end
    return url
end

-- jenis log yang aktif: bawaan dari Config.Logs, diubah Owner di halaman Log Discord (data/logs.json)
local LogOn = {}
for _, l in ipairs(Config.Logs) do LogOn[l.key] = l.on end
do
    local ok, saved = pcall(json.decode, LoadResourceFile(RESOURCE, 'data/logs.json') or '')
    if ok and type(saved) == 'table' then
        for k, v in pairs(saved) do
            if LogOn[k] ~= nil then LogOn[k] = v == true end
        end
    end
end

---Status tiap channel untuk halaman Log Discord. own = punya webhook sendiri, hook = ada tujuan (sendiri/utama).
function LogChannels()
    local out = {}
    for _, c in ipairs(Config.LogChannels) do
        out[#out + 1] = { key = c.key, label = c.label, convar = c.convar, own = Hooks[c.key] ~= '', hook = hookOf(c.key) ~= '' }
    end
    return out
end

function LogKinds()
    local out = {}
    for _, l in ipairs(Config.Logs) do out[#out + 1] = { key = l.key, label = l.label, on = LogOn[l.key], ch = KindChannel[l.key] } end
    return out
end

function SetLogKind(key, on)
    if LogOn[key] == nil then return false end
    LogOn[key] = on == true
    SaveResourceFile(RESOURCE, 'data/logs.json', json.encode(LogOn, { indent = true }), -1)
    return true
end

local function send(ch, text)
    local url = hookOf(ch)
    if url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'F-Admin',
        content = text,
        allowed_mentions = { parse = {} },
    }), { ['Content-Type'] = 'application/json' })
end

---@param kind string kunci Config.Logs
---@param text string pesan singkat, mis. "**Sandi** mengangkat Budi menjadi Support"
function DiscordLog(kind, text)
    print(('^3[f_admin]^0 %s'):format(text:gsub('%*%*', '')))
    if LogOn[kind] == false then return end
    send(KindChannel[kind], text)
end

---Log aksi staff: "**Sandi** <text>" + baris kecil role & ID.
---@param src number staff
---@param kind string
---@param text string
---@param target? number pemain tujuan (untuk baris ID)
function Log(src, kind, text, target)
    local id = tostring(src)
    local role = GetRole and GetRole(id)
    local foot = ('%s · ID %s%s · %s'):format(ROLE_LABEL[role] or 'Pemain', id, target and (' → ID ' .. target) or '', os.date('%H:%M'))
    DiscordLog(kind, ('**%s** %s\n-# %s'):format(GetPlayerName(id) or ('ID ' .. id), text, foot))
end

---@param ch string channel yang diuji
function TestWebhook(src, ch)
    if Hooks[ch] == nil or hookOf(ch) == '' then return false end
    local label = ch
    for _, c in ipairs(Config.LogChannels) do if c.key == ch then label = c.label end end
    send(ch, ('🔔 Pesan uji channel **%s** dari panel admin oleh **%s**'):format(label, GetPlayerName(src) or 'Owner'))
    return true
end

-- dipakai script lain (mis. ox_inventory /giveitem): exports.f_admin:Log(source, 'item', 'memberikan ...')
exports('Log', function(src, kind, text, target)
    if type(kind) ~= 'string' or type(text) ~= 'string' then return end
    Log(src, kind, text, target)
end)
