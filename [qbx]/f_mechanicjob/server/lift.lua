-- Lift bengkel. Status tiap lift ada di GlobalState['f_mech:lift:<i>'] = { up, net, by, at } supaya
-- semua client bisa menganimasikan platform. Perbaikan berat hanya boleh kalau kendaraan ada di
-- atas lift yang sedang naik (Lift.Holds).
local cfg = require 'config.shared'
local LIFTS = cfg.lift.lifts

Lift = {}

local function key(i) return 'f_mech:lift:' .. i end
local function get(i) return GlobalState[key(i)] or { up = false } end

for i = 1, #LIFTS do GlobalState[key(i)] = { up = false } end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function flatDist(a, b) return #(vec2(a.x, a.y) - vec2(b.x, b.y)) end

---Kendaraan yang berdiri di atas platform lift i (kosong = nil).
local function vehicleOn(i)
    local c = LIFTS[i].coords
    local best, bestDist
    for _, veh in ipairs(GetAllVehicles()) do
        local pos = GetEntityCoords(veh)
        local d = flatDist(pos, c)
        if d <= cfg.lift.radius and math.abs(pos.z - c.z) < 2.5 and (not bestDist or d < bestDist) then
            best, bestDist = veh, d
        end
    end
    return best
end

---Apakah kendaraan ini sedang di atas lift yang naik.
---@param veh number
function Lift.Holds(veh)
    local net = NetworkGetNetworkIdFromEntity(veh)
    for i = 1, #LIFTS do
        local s = get(i)
        if s.up and s.net == net and flatDist(GetEntityCoords(veh), LIFTS[i].coords) <= cfg.lift.radius + 0.5 then
            return true
        end
    end
    return false
end

lib.callback.register('f_mechanicjob:server:liftToggle', function(src, i)
    i = tonumber(i)
    local lift = i and LIFTS[i]
    if not lift then return { error = 'Lift tidak ditemukan' } end
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    local here = GetEntityCoords(GetPlayerPed(src))
    if #(here - lift.panel) > 4.0 and #(here - lift.coords.xyz) > 6.0 then return { error = 'Kamu terlalu jauh dari lift' } end

    local s = get(i)
    if (os.time() - (s.at or 0)) * 1000 < cfg.lift.duration then return { error = 'Lift masih bergerak' } end

    if s.up then
        local veh = s.net and NetworkGetEntityFromNetworkId(s.net) or 0
        GlobalState[key(i)] = { up = false, net = s.net, by = src, at = os.time() }
        if veh ~= 0 and DoesEntityExist(veh) then
            SetTimeout(cfg.lift.duration + 300, function()
                if DoesEntityExist(veh) and not get(i).up then FreezeEntityPosition(veh, false) end
            end)
        end
        return { up = false, net = s.net }
    end

    local veh = vehicleOn(i)
    if not veh then return { error = 'Tidak ada kendaraan di atas lift' } end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return { error = 'Pengemudi harus turun dulu' } end
    if not Condition.Kind(veh) then return { error = 'Kendaraan ini tidak bisa dinaikkan' } end
    for j = 1, #LIFTS do
        if j ~= i and get(j).up and get(j).net == NetworkGetNetworkIdFromEntity(veh) then return { error = 'Kendaraan sudah di lift lain' } end
    end

    FreezeEntityPosition(veh, true)
    local net = NetworkGetNetworkIdFromEntity(veh)
    GlobalState[key(i)] = { up = true, net = net, by = src, at = os.time() }
    return { up = true, net = net }
end)

-- kendaraan di lift hilang (dihapus / disimpan ke garasi): lift otomatis turun
AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) ~= 2 then return end
    local net = NetworkGetNetworkIdFromEntity(entity)
    for i = 1, #LIFTS do
        local s = get(i)
        if s.up and s.net == net then GlobalState[key(i)] = { up = false, at = os.time() } end
    end
end)
