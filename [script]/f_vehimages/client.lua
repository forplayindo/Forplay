-- Vehicle photo session (admin only, started by /fotokendaraan on the server).
-- The car is spawned locally in the sky in front of a scaled-up green screen, photographed with
-- screencapture, keyed to a transparent webp by the NUI page, then sent to the server to be saved.
local config = require 'config'

local pending = {} ---@type table<integer, promise> NUI processing jobs by id
local saved = {}   ---@type table<string, promise> server save acks by model
local jobId = 0

---Resolves a promise only once (callbacks and timeouts may both try).
---@param p table promise
local function settle(p, value)
    if p and not p.settled then
        p.settled = true
        p:resolve(value)
    end
end

---Settles the promise with `value` after `ms` unless something settled it first.
local function timeout(p, ms, value)
    SetTimeout(ms, function() settle(p, value) end)
end

RegisterNUICallback('processed', function(data, cb)
    cb(1)
    local p = pending[data.id]
    pending[data.id] = nil
    settle(p, data)
end)

RegisterNetEvent('f_vehimages:saved', function(model, ok)
    local p = saved[model]
    saved[model] = nil
    settle(p, ok == true)
end)

---Places the green screens behind the vehicle (two, back to back, so the green side always faces
---the camera), scaled up to fill the whole frame.
---@param screens number[]
---@param vehPos vector3
---@param camPos vector3
local function placeGreenScreen(screens, vehPos, camPos)
    local flat = vector3(vehPos.x - camPos.x, vehPos.y - camPos.y, 0.0)
    local dir = flat / #flat
    local pos = vehPos + dir * config.greenScreen.distance
    local s = config.greenScreen.scale
    for i = 1, #screens do
        local screen = screens[i]
        SetEntityCoordsNoOffset(screen, pos.x, pos.y, pos.z - 6.0, false, false, false)
        SetEntityHeading(screen, GetHeadingFromVector_2d(dir.x, dir.y) + (i - 1) * 180.0)
        local forward, right, up = GetEntityMatrix(screen)
        SetEntityMatrix(screen, forward.x * s, forward.y * s, forward.z * s, right.x * s, right.y * s, right.z * s,
            up.x * s, up.y * s, up.z * s, pos.x, pos.y, pos.z - 6.0)
    end
end

---Takes one photo and returns the transparent webp data URI, or nil.
---@return string?
local function shoot()
    local shot = promise.new()
    exports.screencapture:requestScreenshot({ encoding = 'png' }, function(data) settle(shot, data) end)
    timeout(shot, 15000, false)
    local image = Citizen.Await(shot)
    if type(image) ~= 'string' then return nil end

    jobId += 1
    local p = promise.new()
    pending[jobId] = p
    timeout(p, 15000, { ok = false, error = 'timeout' })
    SendNUIMessage({
        action = 'process', id = jobId, image = image,
        width = config.output.width, height = config.output.height, quality = config.output.quality,
    })
    local res = Citizen.Await(p)
    if not res.ok then
        lib.notify({ type = 'error', description = ('Proses foto gagal: %s'):format(res.error or '?') })
        return nil
    end
    return res.data
end

RegisterNetEvent('f_vehimages:start', function(models)
    local studio = config.studio
    local ped = cache.ped
    local returnCoords = GetEntityCoords(ped)
    local running = true

    CreateThread(function()
        while running do
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)

    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, studio.x + 15.0, studio.y + 15.0, studio.z, false, false, false, false)
    NetworkOverrideClockTime(13, 0, 0)
    SetWeatherTypeNowPersist('EXTRASUNNY')

    local screenHash = joaat(config.greenScreen.model)
    lib.requestModel(screenHash, 15000)
    local screens = {}
    for i = 1, 2 do
        screens[i] = CreateObject(screenHash, studio.x, studio.y, studio.z, false, false, false)
        FreezeEntityPosition(screens[i], true)
    end
    SetModelAsNoLongerNeeded(screenHash)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 40.0)
    RenderScriptCams(true, false, 0, true, true)

    local done = 0
    for i = 1, #models do
        local model = models[i]
        local hash = joaat(model)
        if IsModelInCdimage(hash) and IsModelAVehicle(hash) and pcall(lib.requestModel, hash, 15000) then
            local veh = CreateVehicle(hash, studio.x, studio.y, studio.z, studio.w, false, false)
            SetModelAsNoLongerNeeded(hash)
            FreezeEntityPosition(veh, true)
            SetVehicleDirtLevel(veh, 0.0)
            SetVehicleLights(veh, 2)

            -- 3/4 depan, moncong ke kiri layar (sama dengan gambar docs.fivem.net)
            local min, max = GetModelDimensions(hash)
            local size = #(max - min)
            local camPos = GetOffsetFromEntityInWorldCoords(veh, -size * 0.55, size * 0.8, size * 0.15)
            SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
            PointCamAtEntity(cam, veh, 0.0, 0.0, 0.0, true)
            placeGreenScreen(screens, GetEntityCoords(veh), camPos)

            Wait(1500)
            local data = shoot()
            if data then
                local ack = promise.new()
                saved[model] = ack
                timeout(ack, 30000, false)
                TriggerLatentServerEvent('f_vehimages:save', 200000, model, data)
                if Citizen.Await(ack) then done += 1 end
            end
            DeleteEntity(veh)
        else
            lib.notify({ type = 'error', description = ('Model %s tidak ditemukan'):format(model) })
        end
    end

    for i = 1, #screens do DeleteEntity(screens[i]) end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    NetworkClearClockTimeOverride()
    ClearWeatherTypePersist()
    SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    running = false

    lib.notify({ type = 'info', description = ('%d/%d foto kendaraan tersimpan'):format(done, #models) })
    TriggerServerEvent('f_vehimages:done')
end)
