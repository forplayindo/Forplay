-- Preview 3D lokal (non-network): hanya ada di layar pemain ini, tidak membebani server.
-- Kamera tidak pakai loop per-frame; posisinya dihitung ulang hanya saat ada input putar/zoom.
Preview = {}

local P = Config.Preview
local cam, veh
local token = 0
local heading = P.coords.w
local zoom = 1.0
local pitch = P.camHeight
local baseDist = 6.0
local center = P.coords.xyz

local function updateCam()
    if not cam then return end
    local dist = baseDist * zoom
    local a = math.rad(P.coords.w + P.camAngle)
    local pos = vec3(center.x - math.sin(a) * dist, center.y + math.cos(a) * dist, center.z + pitch)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, center.x, center.y, center.z + 0.15)
end

local function deleteVeh()
    if veh and DoesEntityExist(veh) then DeleteEntity(veh) end
    veh = nil
end

function Preview.start()
    if cam then return end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 45.0)
    updateCam()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 400, true, true)
end

function Preview.stop(instant)
    token += 1
    deleteVeh()
    if cam then
        RenderScriptCams(false, not instant, instant and 0 or 400, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

---Ganti kendaraan yang dipamerkan. Mengembalikan statistik performa (atau nil kalau model gagal dimuat / sudah diganti lagi).
function Preview.show(model)
    token += 1
    local my = token
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    if not pcall(lib.requestModel, hash, 15000) then return nil end
    if my ~= token or not cam then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    deleteVeh()
    local c = P.coords
    veh = CreateVehicle(hash, c.x, c.y, c.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'DEALER')
    SetEntityCollision(veh, false, false)

    local min, max = GetModelDimensions(hash)
    local size = max - min
    baseDist = math.max(size.x, size.y, size.z * 1.6) * 1.15 + 2.2
    center = GetEntityCoords(veh) + vec3(0.0, 0.0, (min.z + max.z) * 0.5)
    updateCam()

    local SM = Config.StatMax
    local speed = GetVehicleModelEstimatedMaxSpeed(hash) * 3.6
    local accel = GetVehicleModelAcceleration(hash)
    local brake = GetVehicleModelMaxBraking(hash)
    local traction = GetVehicleModelMaxTraction(hash)
    local pct = function(v, m) return math.floor(math.min(1.0, math.max(0.0, v / m)) * 100 + 0.5) end
    return {
        speed = math.floor(speed + 0.5),
        speedPct = pct(speed, SM.speed),
        accelPct = pct(accel, SM.accel),
        brakePct = pct(brake, SM.brake),
        tractionPct = pct(traction, SM.traction),
        seats = GetVehicleModelNumberOfSeats(hash),
    }
end

function Preview.rotate(dx, dy)
    heading = (heading + (tonumber(dx) or 0) * 0.35) % 360.0
    if veh and DoesEntityExist(veh) then SetEntityHeading(veh, heading) end
    pitch = math.min(3.0, math.max(-0.2, pitch + (tonumber(dy) or 0) * 0.01))
    updateCam()
end

function Preview.zoom(delta)
    zoom = math.min(P.zoomMax, math.max(P.zoomMin, zoom + (tonumber(delta) or 0) * 0.08))
    updateCam()
end

---------------------------------------------------------------------------
-- Mobil pajangan showroom: dibuat saat pemain dekat, dihapus saat jauh
---------------------------------------------------------------------------
local display = {}

local function spawnDisplay()
    for i, d in ipairs(Config.Display) do
        if not display[i] then
            local hash = joaat(d.model)
            if IsModelInCdimage(hash) and pcall(lib.requestModel, hash, 10000) then
                local v = CreateVehicle(hash, d.coords.x, d.coords.y, d.coords.z, d.coords.w, false, false)
                SetModelAsNoLongerNeeded(hash)
                SetVehicleOnGroundProperly(v)
                FreezeEntityPosition(v, true)
                SetEntityInvincible(v, true)
                SetVehicleDoorsLocked(v, 2)
                SetVehicleDirtLevel(v, 0.0)
                SetVehicleNumberPlateText(v, 'PDM')
                display[i] = v
            end
        end
    end
end

local function clearDisplay()
    for i, v in pairs(display) do
        if DoesEntityExist(v) then DeleteEntity(v) end
        display[i] = nil
    end
end

function Preview.hideDisplay(hide)
    for _, v in pairs(display) do
        if DoesEntityExist(v) then
            SetEntityVisible(v, not hide, false)
            SetEntityCollision(v, not hide, true)
        end
    end
end

if #Config.Display > 0 then
    lib.points.new({
        coords = P.coords.xyz,
        distance = 70.0,
        onEnter = spawnDisplay,
        onExit = clearDisplay,
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    Preview.stop(true)
    clearDisplay()
end)
