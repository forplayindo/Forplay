Punish = {}

local points = {} ---@type table<integer, integer>

---@param source integer
local function getIdentifiers(source)
    return {
        license = GetPlayerIdentifierByType(source --[[@as string]], 'license2')
            or GetPlayerIdentifierByType(source --[[@as string]], 'license'),
        discord = GetPlayerIdentifierByType(source --[[@as string]], 'discord'),
        ip = GetPlayerIdentifierByType(source --[[@as string]], 'ip'),
    }
end

---@param source integer
---@return boolean
local function isExempt(source)
    return IsPlayerAceAllowed(source --[[@as string]], Config.ExemptAce)
end

---@param source integer
---@param category string
---@param reason string
local function ban(source, category, reason)
    local ids = getIdentifiers(source)
    local name = GetPlayerName(source) or ('id:%s'):format(source)

    Storage.InsertBan({
        name = name,
        license = ids.license,
        discord = ids.discord,
        ip = ids.ip,
        category = category,
        reason = reason,
        bannedBy = 'f_anticheat',
    })

    DropPlayer(source --[[@as string]], ('You have been banned by the anti-cheat.\nReason: %s\nAppeal on our Discord if you believe this is a mistake.'):format(reason))

    lib.print.warn(('f_anticheat: BANNED %s (%s) - category: %s - reason: %s'):format(name, ids.license or 'unknown', category, reason))
    Webhook.Send('🔨 Player banned', ('**%s** (`%s`)\nCategory: `%s`\nReason: %s'):format(name, ids.license or 'unknown', category, reason), 'red')
end

---@param source integer
---@param category string
---@param reason string
local function kick(source, category, reason)
    local name = GetPlayerName(source) or ('id:%s'):format(source)
    DropPlayer(source --[[@as string]], ('Kicked by the anti-cheat.\nReason: %s'):format(reason))
    lib.print.warn(('f_anticheat: KICKED %s - category: %s - reason: %s'):format(name, category, reason))
    Webhook.Send('👢 Player kicked', ('**%s**\nCategory: `%s`\nReason: %s'):format(name, category, reason), 'orange')
end

---@param source integer
---@param category string
---@param reason string
local function warn(source, category, reason)
    local name = GetPlayerName(source) or ('id:%s'):format(source)
    pcall(function()
        exports.qbx_core:Notify(source, ('Aktivitas mencurigakan terdeteksi (%s). Pelanggaran berikutnya akan berujung kick atau ban.'):format(category), 'error', 8000)
    end)
    Webhook.Send('⚠️ Anti-cheat warning', ('**%s**\nCategory: `%s`\nReason: %s'):format(name, category, reason), 'yellow')
end

---Report a violation. Accumulates points per player per session and escalates
---the response (warn -> kick -> ban) once configured thresholds are crossed.
---@param source integer
---@param category string key into Config matching the detector (e.g. 'entityspam', 'speed')
---@param severity integer points to add
---@param reason string human readable description for logs/webhook
function Punish.Flag(source, category, severity, reason)
    if source == 0 then return end
    if isExempt(source) then
        lib.print.info(('f_anticheat: %s exempt (%s), skipped flag: %s'):format(
            GetPlayerName(source) or ('id:%s'):format(source), Config.ExemptAce, reason))
        return
    end

    local total = (points[source] or 0) + severity
    points[source] = total

    local ids = getIdentifiers(source)
    local name = GetPlayerName(source) or ('id:%s'):format(source)

    local action = 'log'
    if Config.Punish.instantBan[category] then
        action = 'ban'
    elseif total >= Config.Punish.banThreshold then
        action = 'ban'
    elseif total >= Config.Punish.kickThreshold then
        action = 'kick'
    elseif total >= Config.Punish.warnThreshold then
        action = 'warn'
    end

    Storage.InsertLog({
        name = name,
        license = ids.license,
        category = category,
        points = severity,
        totalPoints = total,
        reason = reason,
        action = action,
    })

    if action == 'ban' then
        ban(source, category, reason)
        points[source] = nil
    elseif action == 'kick' then
        kick(source, category, reason)
    elseif action == 'warn' then
        warn(source, category, reason)
    else
        Webhook.Send('👀 Anti-cheat flag', ('**%s**\nCategory: `%s` (+%d, total %d)\nReason: %s'):format(name, category, severity, total, reason), 'yellow')
    end
end

AddEventHandler('playerDropped', function()
    points[source] = nil
end)

exports('Flag', Punish.Flag)
exports('GetPoints', function(source) return points[source] or 0 end)
exports('ResetPoints', function(source) points[source] = nil end)
