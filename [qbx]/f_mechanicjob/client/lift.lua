-- Lift bengkel (client). Status dari GlobalState['f_mech:lift:<i>'] (server/lift.lua).
--  * Semua client: platform map disembunyikan & diganti objek lokal yang ikut naik / turun.
--  * Mekanik yang menekan panel: menggerakkan kendaraan (dia pemegang fisikanya selama animasi).
local cfg = require 'config.shared'
local clientCfg = require 'config.client'
local LIFT = cfg.lift

local platforms = {} ---@type table<integer, { obj: number, base: vector3 }>
local animToken = {}  ---@type table<integer, integer>

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function liftState(i) return GlobalState['f_mech:lift:' .. i] or { up = false } end

local function ease(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end

---Menggerakkan platform (dan kendaraan kalau `veh` diberikan) ke posisi naik / turun.
local function animate(i, up, veh)
    animToken[i] = (animToken[i] or 0) + 1
    local token = animToken[i]
    local p = platforms[i]
    local lift = LIFT.lifts[i]

    local fromP = p and GetEntityCoords(p.obj).z
    local toP = p and (p.base.z + (up and LIFT.height or 0.0))
    local vehFrom, vehTo
    if veh then
        vehFrom = GetEntityCoords(veh).z
        vehTo = vehFrom + (up and LIFT.height or -LIFT.height)
        FreezeEntityPosition(veh, true)
    end

    CreateThread(function()
        local start = GetGameTimer()
        while animToken[i] == token do
            local t = math.min(1.0, (GetGameTimer() - start) / LIFT.duration)
            local k = ease(t)
            if p and DoesEntityExist(p.obj) then
                SetEntityCoordsNoOffset(p.obj, p.base.x, p.base.y, fromP + (toP - fromP) * k, false, false, false)
            end
            if veh and DoesEntityExist(veh) and NetworkHasControlOfEntity(veh) then
                local pos = GetEntityCoords(veh)
                SetEntityCoordsNoOffset(veh, pos.x, pos.y, vehFrom + (vehTo - vehFrom) * k, false, false, false)
            end
            if t >= 1.0 then break end
            Wait(0)
        end
    end)
    return lift
end

local function takeControl(veh)
    NetworkRequestControlOfEntity(veh)
    local timeout = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do Wait(50) end
    return NetworkHasControlOfEntity(veh)
end

AddStateBagChangeHandler(nil, 'global', function(_, key, value)
    local i = tonumber(key:match('^f_mech:lift:(%d+)$'))
    if not i or type(value) ~= 'table' or not LIFT.lifts[i] then return end
    local veh
    if value.by == cache.serverId and value.net then
        local v = NetworkGetEntityFromNetworkId(value.net)
        if v ~= 0 and takeControl(v) then veh = v end
    end
    animate(i, value.up == true, veh)
end)

local function toggle(i)
    local res = lib.callback.await('f_mechanicjob:server:liftToggle', false, i)
    if not res or res.error then return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error') end
    exports.qbx_core:Notify(res.up and 'Lift naik' or 'Lift turun', 'inform')
end

for i, lift in ipairs(LIFT.lifts) do
    exports.ox_target:addSphereZone({
        coords = lift.panel,
        radius = 0.8,
        debug = clientCfg.debugZones,
        options = {
            {
                name = 'f_mechanicjob:liftUp:' .. i,
                icon = 'fa-solid fa-arrow-up',
                label = 'Naikkan Lift',
                distance = 2.0,
                canInteract = function() return isMechanic() and not liftState(i).up end,
                onSelect = function() toggle(i) end,
            },
            {
                name = 'f_mechanicjob:liftDown:' .. i,
                icon = 'fa-solid fa-arrow-down',
                label = 'Turunkan Lift',
                distance = 2.0,
                canInteract = function() return isMechanic() and liftState(i).up end,
                onSelect = function() toggle(i) end,
            },
        },
    })
end

-- platform map diganti objek lokal yang bisa digerakkan
CreateThread(function()
    if not LIFT.animatePlatform then return end
    local hash = joaat(LIFT.model)
    if not IsModelInCdimage(hash) then return end
    lib.requestModel(hash, 15000)
    for i, lift in ipairs(LIFT.lifts) do
        local c = lift.coords
        CreateModelHide(c.x, c.y, c.z, 1.0, hash, true)
        local obj = CreateObjectNoOffset(hash, c.x, c.y, c.z, false, false, false)
        SetEntityHeading(obj, c.w)
        FreezeEntityPosition(obj, true)
        platforms[i] = { obj = obj, base = c.xyz }
        if liftState(i).up then SetEntityCoordsNoOffset(obj, c.x, c.y, c.z + LIFT.height, false, false, false) end
    end
    SetModelAsNoLongerNeeded(hash)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    local hash = joaat(LIFT.model)
    for _, lift in ipairs(LIFT.lifts) do
        RemoveModelHide(lift.coords.x, lift.coords.y, lift.coords.z, 1.0, hash, false)
    end
    for _, p in pairs(platforms) do
        if DoesEntityExist(p.obj) then DeleteEntity(p.obj) end
    end
end)
