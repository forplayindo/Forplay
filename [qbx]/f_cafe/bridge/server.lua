-- Framework bridge (server): Qbox (qbx_core) atau QBCore (qb-core)
Bridge = {}

local function isUp(res)
    local s = GetResourceState(res)
    return s == 'started' or s == 'starting'
end

local QBCore
if isUp('qbx_core') then
    Bridge.framework = 'qbx'
elseif isUp('qb-core') then
    Bridge.framework = 'qb'
    QBCore = exports['qb-core']:GetCoreObject()
else
    error('[f_cafe] qbx_core / qb-core tidak ditemukan')
end

function Bridge.GetPlayer(src)
    if Bridge.framework == 'qbx' then return exports.qbx_core:GetPlayer(src) end
    return QBCore.Functions.GetPlayer(src)
end

---@return { name: string, grade: integer, onduty: boolean }|nil
function Bridge.GetJob(src)
    local p = Bridge.GetPlayer(src)
    if not p then return end
    local job = p.PlayerData.job
    if not job then return end
    local grade = type(job.grade) == 'table' and job.grade.level or job.grade
    return { name = job.name, grade = tonumber(grade) or 0, onduty = job.onduty == true }
end

function Bridge.GetCitizenId(src)
    local p = Bridge.GetPlayer(src)
    return p and p.PlayerData.citizenid
end

function Bridge.GetName(src)
    local p = Bridge.GetPlayer(src)
    if not p then return ('ID %s'):format(src) end
    local c = p.PlayerData.charinfo or {}
    local name = ('%s %s'):format(c.firstname or '', c.lastname or ''):match('^%s*(.-)%s*$')
    return name ~= '' and name or ('ID %s'):format(src)
end

function Bridge.GetSourceByCitizenId(cid)
    if Bridge.framework == 'qbx' then
        local p = exports.qbx_core:GetPlayerByCitizenId(cid)
        return p and p.PlayerData.source
    end
    local p = QBCore.Functions.GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source
end

function Bridge.SetDuty(src, state)
    local p = Bridge.GetPlayer(src)
    if not p then return false end
    if Bridge.framework == 'qbx' then
        exports.qbx_core:SetJobDuty(src, state)
    else
        p.Functions.SetJobDuty(state)
        TriggerClientEvent('QBCore:Client:SetDuty', src, state)
    end
    return true
end

function Bridge.AddBank(src, amount, reason)
    local p = Bridge.GetPlayer(src)
    if not p then return false end
    return p.Functions.AddMoney('bank', amount, reason) ~= false
end

function Bridge.Notify(src, msg, typ, duration)
    TriggerClientEvent('ox_lib:notify', src, { title = Config.Label, description = msg, type = typ or 'inform', duration = duration })
end
