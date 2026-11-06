-- panel Alur Kerja: muncul otomatis di beberapa kerja pertama, bisa dibuka kapan saja (F7 / /panduan)
local config = require 'config'

local active            -- job yang sedang dikerjakan (lewat export Start)
local step              -- langkah sekarang dari job (lewat export SetStep)
local open = false

local function citizenId()
    return QBX.PlayerData and QBX.PlayerData.citizenid or 'x'
end

-- disimpan per karakter di komputer pemain
local function kvp(job, what)
    return ('panduan:%s:%s:%s'):format(citizenId(), job, what)
end

local function muted(job)
    return GetResourceKvpInt(kvp(job, 'mute')) == 1
end

local function payload(job, extra)
    local list = {}
    for _, key in ipairs(config.order) do
        local j = config.jobs[key]
        list[#list + 1] = { key = key, name = j.name, icon = j.icon, steps = j.steps, rules = j.rules, muted = muted(key) }
    end
    local data = { jobs = list, job = job, active = active, step = job == active and step or nil, browse = active == nil }
    for k, v in pairs(extra or {}) do data[k] = v end
    return data
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function show(job, extra)
    job = config.jobs[job] and job or active or config.order[1]
    -- the running job answers with SetStep for the "Sekarang" marker
    if job == active then TriggerEvent('f_panduan:client:requestStep', job) end
    open = true
    SendNUIMessage({ action = 'open', data = payload(job, extra) })
    SetNuiFocus(true, true)
end

---------------------------------------------------------------------------
-- exports untuk job
---------------------------------------------------------------------------
exports('Start', function(job)
    if not config.jobs[job] then return end
    active, step = job, nil
    local count = GetResourceKvpInt(kvp(job, 'count')) + 1
    SetResourceKvpInt(kvp(job, 'count'), count)
    if muted(job) or count > config.autoTimes then return end
    SetTimeout(config.autoDelay, function()
        if active == job and not open then show(job, { last = count == config.autoTimes }) end
    end)
end)

exports('SetStep', function(job, n)
    if job ~= active then return end
    step = n
    if open then SendNUIMessage({ action = 'step', job = job, step = n }) end
end)

exports('Stop', function(job)
    if job ~= active then return end
    active, step = nil, nil
    close()
end)

exports('Open', function(job) show(job) end)

---------------------------------------------------------------------------
-- tombol & perintah
---------------------------------------------------------------------------
RegisterCommand('panduan', function(_, args)
    if open then return close() end
    show(args[1] and args[1]:lower() or nil)
end, false)
RegisterKeyMapping('panduan', 'Buka Alur Kerja (panduan job)', 'keyboard', config.key)
TriggerEvent('chat:addSuggestion', '/panduan', 'Buka panel alur kerja', {
    { name = 'job', help = 'kayu / tambang / nelayan / sampah / kurir (kosongkan = job yang sedang dikerjakan)' },
})

RegisterNUICallback('close', function(data, cb)
    if data and config.jobs[data.job] then
        SetResourceKvpInt(kvp(data.job, 'mute'), data.mute and 1 or 0)
    end
    close()
    cb(1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
