Bridge = { name = 'standalone' }

local function resourceUp(res)
    return GetResourceState(res) == 'started' or GetResourceState(res) == 'starting'
end

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if resourceUp('qbx_core') then return 'qbx' end
    if resourceUp('qb-core') then return 'qb' end
    if resourceUp('es_extended') then return 'esx' end
    return 'standalone'
end

CreateThread(function()
    Bridge.name = detect()
    if Bridge.name == 'qb' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        Bridge.qb = ok and core or nil
    elseif Bridge.name == 'esx' then
        local ok, esx = pcall(function() return exports['es_extended']:getSharedObject() end)
        Bridge.esx = ok and esx or nil
    end
    print(('[f_chat] framework bridge: %s'):format(Bridge.name))
end)

--- Returns { name, label, grade, gradeName } or nil
function Bridge.GetJob(src)
    if Bridge.name == 'qbx' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player and player.PlayerData and player.PlayerData.job then
            local job = player.PlayerData.job
            return {
                name      = job.name,
                label     = job.label,
                grade     = (job.grade and job.grade.level) or 0,
                gradeName = (job.grade and job.grade.name) or '',
                onDuty    = job.onduty,
            }
        end
    elseif Bridge.name == 'qb' and Bridge.qb then
        local player = Bridge.qb.Functions.GetPlayer(src)
        if player then
            local job = player.PlayerData.job
            return {
                name      = job.name,
                label     = job.label,
                grade     = (job.grade and job.grade.level) or 0,
                gradeName = (job.grade and job.grade.name) or '',
                onDuty    = job.onduty,
            }
        end
    elseif Bridge.name == 'esx' and Bridge.esx then
        local player = Bridge.esx.GetPlayerFromId(src)
        if player then
            local job = player.getJob()
            return { name = job.name, label = job.label, grade = job.grade, gradeName = job.grade_name }
        end
    end
    return nil
end

--- Character name, falling back to the Steam/RockstarΩ name
function Bridge.GetName(src)
    if Bridge.name == 'qbx' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player and player.PlayerData and player.PlayerData.charinfo then
            local c = player.PlayerData.charinfo
            return ('%s %s'):format(c.firstname or '', c.lastname or ''):gsub('^%s+', '')
        end
    elseif Bridge.name == 'qb' and Bridge.qb then
        local player = Bridge.qb.Functions.GetPlayer(src)
        if player and player.PlayerData.charinfo then
            local c = player.PlayerData.charinfo
            return ('%s %s'):format(c.firstname or '', c.lastname or '')
        end
    elseif Bridge.name == 'esx' and Bridge.esx then
        local player = Bridge.esx.GetPlayerFromId(src)
        if player and player.getName then return player.getName() end
    end
    return GetPlayerName(src) or ('Pemain %s'):format(src)
end

function Bridge.IsStaff(src)
    if IsPlayerAceAllowed(src, Config.StaffAce) then return true end
    for _, group in ipairs(Config.StaffGroups) do
        if IsPlayerAceAllowed(src, ('group.%s'):format(group)) then return true end
        if Bridge.name == 'qbx' then
            local ok, res = pcall(function() return exports.qbx_core:HasPermission(src, group) end)
            if ok and res then return true end
        elseif Bridge.name == 'qb' and Bridge.qb then
            local ok, res = pcall(function() return Bridge.qb.Functions.HasPermission(src, group) end)
            if ok and res then return true end
        end
    end
    return false
end
