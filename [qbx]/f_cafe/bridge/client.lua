-- Framework bridge (client): Qbox (qbx_core) atau QBCore (qb-core)
Bridge = {}

local QBCore
if GetResourceState('qbx_core') == 'started' then
    Bridge.framework = 'qbx'
else
    Bridge.framework = 'qb'
    QBCore = exports['qb-core']:GetCoreObject()
end

local function playerData()
    if Bridge.framework == 'qbx' then return exports.qbx_core:GetPlayerData() or {} end
    return QBCore.Functions.GetPlayerData() or {}
end

-- Job di-cache: canInteract ox_target dipanggil tiap frame saat ALT ditahan, jadi jangan
-- mengambil seluruh PlayerData lewat export setiap kali. Cache diperbarui lewat event saja.
local jobCache

local function refreshJob(job)
    job = job or playerData().job
    if not job then jobCache = nil return end
    local grade = type(job.grade) == 'table' and job.grade.level or job.grade
    jobCache = { name = job.name, grade = tonumber(grade) or 0, onduty = job.onduty == true }
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() refreshJob() end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() jobCache = nil end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) refreshJob(job) end)
RegisterNetEvent('QBCore:Client:SetDuty', function(state)
    if jobCache then jobCache.onduty = state == true else refreshJob() end
end)
CreateThread(function() refreshJob() end)

---@return { name: string, grade: integer, onduty: boolean }|nil
function Bridge.GetJob()
    return jobCache
end

function Bridge.IsEmployee(minGrade)
    local job = Bridge.GetJob()
    return job and job.name == Config.Job and job.grade >= (minGrade or 0) or false
end

function Bridge.IsOnDuty(minGrade)
    local job = Bridge.GetJob()
    return job and job.name == Config.Job and job.onduty and job.grade >= (minGrade or 0) or false
end

function Bridge.IsMale()
    return GetEntityModel(cache.ped) == `mp_m_freemode_01`
end
