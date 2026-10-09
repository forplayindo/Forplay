-- Fitur job dasar (client): blip, duty, gudang, kendaraan kerja.
local cfg = require 'config.shared'
local clientCfg = require 'config.client'
local loc = cfg.locations

local function isMechanicJob()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType
end

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

-- blip bengkel dipindah ke f_blips

exports.ox_target:addSphereZone({
    coords = loc.duty,
    radius = 1.0,
    debug = clientCfg.debugZones,
    options = {
        {
            name = 'f_mechanicjob:duty',
            icon = 'fa-solid fa-clipboard-user',
            label = 'Mulai / Selesai Bertugas',
            distance = 2.0,
            canInteract = isMechanicJob,
            serverEvent = 'QBCore:ToggleDuty',
        },
    },
})

-- Gudang bengkel sekarang dikelola f_stash (/stash).

local garageOptions = {}
for _, v in ipairs(cfg.jobVehicles) do
    garageOptions[#garageOptions + 1] = {
        name = 'f_mechanicjob:veh:' .. v.model,
        icon = 'fa-solid fa-truck-pickup',
        label = 'Ambil ' .. v.label,
        distance = 2.5,
        canInteract = isMechanic,
        onSelect = function()
            local res = lib.callback.await('f_mechanicjob:server:spawnJobVehicle', false, v.model)
            if not res or res.error then exports.qbx_core:Notify(res and res.error or 'Gagal', 'error') end
        end,
    }
end
exports.ox_target:addSphereZone({ coords = loc.garage, radius = 1.2, debug = clientCfg.debugZones, options = garageOptions })

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_mechanicjob:returnVehicle',
        icon = 'fa-solid fa-square-parking',
        label = 'Kembalikan Kendaraan Kerja',
        distance = 3.0,
        canInteract = function(entity)
            return isMechanic() and Entity(entity).state['f_mech:jobVehicle'] == true
                and #(GetEntityCoords(entity) - loc.garage) < 20.0
        end,
        onSelect = function(data)
            local res = lib.callback.await('f_mechanicjob:server:returnJobVehicle', false, NetworkGetNetworkIdFromEntity(data.entity))
            if not res or res.error then exports.qbx_core:Notify(res and res.error or 'Gagal', 'error') end
        end,
    },
})
