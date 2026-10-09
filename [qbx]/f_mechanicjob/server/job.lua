-- Fitur job dasar: kendaraan kerja (ambil / kembalikan). Gudang bengkel dikelola f_stash.
local cfg = require 'config.shared'

local JOB_VEHICLES = {}
for _, v in ipairs(cfg.jobVehicles) do JOB_VEHICLES[v.model] = true end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function near(src, point, dist)
    return #(GetEntityCoords(GetPlayerPed(src)) - point) <= dist
end

lib.callback.register('f_mechanicjob:server:spawnJobVehicle', function(src, model)
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if type(model) ~= 'string' or not JOB_VEHICLES[model] then return { error = 'Kendaraan tidak tersedia' } end
    if not near(src, cfg.locations.garage, 5.0) then return { error = 'Kamu harus berada di garasi bengkel' } end

    local spawn = cfg.locations.garageSpawn
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - spawn.xyz) < 3.0 then return { error = 'Tempat keluar kendaraan masih terhalang' } end
    end

    local netId, veh = qbx.spawnVehicle({ model = joaat(model), spawnSource = spawn, warp = GetPlayerPed(src) })
    if not netId then return { error = 'Kendaraan gagal dimunculkan' } end
    local plate = ('MECH%04d'):format(math.random(0, 9999))
    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('f_mech:jobVehicle', true, true)
    TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate)
    return { net = netId }
end)

lib.callback.register('f_mechanicjob:server:returnJobVehicle', function(src, netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) then return { error = 'Kendaraan tidak ditemukan' } end
    if not Entity(veh).state['f_mech:jobVehicle'] then return { error = 'Ini bukan kendaraan kerja bengkel' } end
    if not isMechanic(src) then return { error = 'Hanya mekanik yang sedang bertugas' } end
    if not near(src, cfg.locations.garage, 15.0) or #(GetEntityCoords(veh) - cfg.locations.garage) > 20.0 then
        return { error = 'Bawa kendaraan ke garasi bengkel' }
    end
    DeleteEntity(veh)
    return { ok = true }
end)
