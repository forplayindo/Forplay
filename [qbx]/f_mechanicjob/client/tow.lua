-- Derek (client): ox_target di bak flatbed untuk job tow & mekanik on-duty, plus job Derek
-- (ambil flatbed ber-deposit, misi NPC /npc, slip gaji). Validasi ada di server/tow.lua.
local cfg = require 'config.shared'
local tow = require 'config.tow'

local FLATBED = {}
for _, model in ipairs(tow.flatbeds) do FLATBED[joaat(model)] = true end

local mission = { on = false } ---@type { on: boolean, spot: integer?, net: integer?, blip: integer?, dropBlip: integer?, zone: table?, carrying: boolean? }
local jobBlips = {}

local function canTow()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.onduty and (job.name == tow.job or job.type == cfg.jobType)
end

local function isTowJob()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.name == tow.job
end

local function getTowed(flatbed)
    local netId = Entity(flatbed).state.f_towed
    if not netId or not NetworkDoesEntityExistWithNetworkId(netId) then return end
    return NetToVeh(netId)
end

local function requestControl(entity)
    local timeout = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function behind(flatbed, extra)
    local min = GetModelDimensions(GetEntityModel(flatbed))
    return GetOffsetFromEntityInWorldCoords(flatbed, 0.0, min.y - extra, 0.0)
end

local function notifyResult(res)
    if not res then return exports.qbx_core:Notify('Gagal', 'error') end
    if res.error then return exports.qbx_core:Notify(res.error, 'error') end
    if res.message then exports.qbx_core:Notify(res.message, 'success') end
end

local function routeBlip(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipColour(blip, 3)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 3)
    return blip
end

local function removeBlip(key)
    if mission[key] and DoesBlipExist(mission[key]) then RemoveBlip(mission[key]) end
    mission[key] = nil
end

-- Misi NPC ----------------------------------------------------------------------------------

local function clearSpot()
    removeBlip('blip')
    if mission.zone then mission.zone:remove() end
    mission.zone = nil
end

local function stopMission()
    clearSpot()
    removeBlip('dropBlip')
    mission = { on = false }
end

local function setSpot(idx)
    clearSpot()
    removeBlip('dropBlip')
    mission.spot, mission.net, mission.carrying = idx, nil, false
    local spot = tow.spots[idx]
    mission.blip = routeBlip(spot.coords)
    mission.zone = lib.zones.sphere({
        coords = spot.coords,
        radius = 50.0,
        onEnter = function()
            if mission.net and NetworkDoesEntityExistWithNetworkId(mission.net) then return end
            local netId = lib.callback.await('f_mechanicjob:tow:spawnNpc', false)
            if not netId then return end
            mission.net = netId
            local veh = lib.waitFor(function()
                if NetworkDoesEntityExistWithNetworkId(netId) then return NetToVeh(netId) end
            end, nil, 5000)
            if veh then SetVehicleFuelLevel(veh, 0.0) end
        end,
    })
end

local function drawDropoff()
    CreateThread(function()
        local p = tow.dropoff
        while mission.carrying do
            DrawMarker(2, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, false, false, false)
            Wait(0)
        end
    end)
end

RegisterNetEvent('jobs:client:ToggleNpc', function()
    if not isTowJob() then return end
    if mission.carrying then return exports.qbx_core:Notify('Selesaikan dulu kendaraan yang sedang diderek', 'error') end
    local spot, err = lib.callback.await('f_mechanicjob:tow:toggleNpc', false)
    if err then return exports.qbx_core:Notify(err, 'error') end
    if spot then
        mission.on = true
        setSpot(spot)
        exports.qbx_core:Notify('Misi NPC aktif, jemput kendaraan di lokasi', 'inform')
    else
        stopMission()
        exports.qbx_core:Notify('Misi NPC dimatikan', 'inform')
    end
end)

-- Naik / turunkan kendaraan di bak ----------------------------------------------------------

local function towProgress(label)
    local ok = lib.progressBar({
        duration = 5000,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    })
    StopAnimTask(cache.ped, 'mini@repair', 'fixing_a_ped', 1.0)
    if not ok then exports.qbx_core:Notify('Dibatalkan', 'error') end
    return ok
end

local function loadVehicle(flatbed)
    if getTowed(flatbed) then return end

    local target = lib.getClosestVehicle(behind(flatbed, 3.0), 4.0, true)
    if not target or target == flatbed or FLATBED[GetEntityModel(target)] then
        return exports.qbx_core:Notify('Tidak ada kendaraan di belakang bak flatbed', 'error')
    end
    if not IsVehicleSeatFree(target, -1) or GetVehicleNumberOfPassengers(target) > 0 then
        return exports.qbx_core:Notify('Kendaraan masih ada orangnya', 'error')
    end
    local targetNet = VehToNet(target)
    if mission.on and isTowJob() and targetNet ~= mission.net then
        return exports.qbx_core:Notify('Ini bukan kendaraan misi', 'error')
    end

    if not towProgress('Menaikkan kendaraan...') then return end

    if not DoesEntityExist(target) or not requestControl(target)
        or not lib.callback.await('f_mechanicjob:tow:set', false, VehToNet(flatbed), targetNet) then
        return exports.qbx_core:Notify('Gagal menaikkan kendaraan', 'error')
    end

    local a = tow.attach
    AttachEntityToEntity(target, flatbed, GetEntityBoneIndexByName(flatbed, 'bodyshell'), a.x, a.y, a.z, 0.0, 0.0, 0.0, true, true, false, true, 0, true)
    FreezeEntityPosition(target, true)

    if mission.on and targetNet == mission.net then
        clearSpot()
        mission.carrying = true
        mission.dropBlip = mission.dropBlip or routeBlip(tow.dropoff)
        drawDropoff()
        exports.qbx_core:Notify('Bawa kendaraan ke depo derek', 'inform', 5000)
    end
    exports.qbx_core:Notify('Kendaraan sudah di atas bak', 'success')
end

local function unloadVehicle(flatbed)
    local towed = getTowed(flatbed)
    if not towed then return end

    if not towProgress('Menurunkan kendaraan...') then return end

    if not DoesEntityExist(towed) or not requestControl(towed)
        or not lib.callback.await('f_mechanicjob:tow:set', false, VehToNet(flatbed), false) then
        return exports.qbx_core:Notify('Gagal menurunkan kendaraan', 'error')
    end

    local drop = behind(flatbed, tow.dropBehind)
    DetachEntity(towed, true, true)
    FreezeEntityPosition(towed, false)
    SetEntityCoords(towed, drop.x, drop.y, drop.z, false, false, false, false)
    SetEntityHeading(towed, GetEntityHeading(flatbed))
    SetVehicleOnGroundProperly(towed)
    exports.qbx_core:Notify('Kendaraan sudah diturunkan', 'success')

    local towedNet = VehToNet(towed)
    if mission.on and towedNet == mission.net then
        mission.carrying = false
        local spot = lib.callback.await('f_mechanicjob:tow:deliver', false, towedNet)
        if spot then
            setSpot(spot)
            exports.qbx_core:Notify('Kendaraan terantar. Kendaraan baru bisa dijemput', 'success')
        end
    end
end

exports.ox_target:addModel(tow.flatbeds, {
    {
        name = 'f_mechanicjob:tow:load',
        icon = 'fa-solid fa-truck-ramp-box',
        label = 'Naikkan Kendaraan',
        offset = vec3(0.5, 0.0, 0.5),
        offsetSize = 2.0,
        distance = 2.5,
        canInteract = function(entity)
            return not cache.vehicle and canTow() and not getTowed(entity)
        end,
        onSelect = function(data) loadVehicle(data.entity) end,
    },
    {
        name = 'f_mechanicjob:tow:unload',
        icon = 'fa-solid fa-truck-ramp-box',
        label = 'Turunkan Kendaraan',
        offset = vec3(0.5, 0.0, 0.5),
        offsetSize = 2.0,
        distance = 2.5,
        canInteract = function(entity)
            return not cache.vehicle and canTow() and getTowed(entity) ~= nil
        end,
        onSelect = function(data) unloadVehicle(data.entity) end,
    },
    {
        name = 'f_mechanicjob:tow:returnTruck',
        icon = 'fa-solid fa-square-parking',
        label = 'Kembalikan Flatbed Derek',
        distance = 3.0,
        canInteract = function(entity)
            return isTowJob() and Entity(entity).state['f_mech:towTruck'] == QBX.PlayerData.citizenid
                and #(GetEntityCoords(entity) - tow.truck.coords.xyz) < 20.0
        end,
        onSelect = function(data)
            notifyResult(lib.callback.await('f_mechanicjob:tow:returnTruck', false, VehToNet(data.entity)))
        end,
    },
})

-- Job Derek: markas & tempat ambil flatbed ---------------------------------------------------

exports.ox_target:addSphereZone({
    coords = tow.depot.coords,
    radius = 1.5,
    options = {
        {
            name = 'f_mechanicjob:tow:payslip',
            icon = 'fa-solid fa-file-invoice-dollar',
            label = 'Ambil Slip Gaji Derek',
            distance = 2.5,
            canInteract = isTowJob,
            onSelect = function()
                local res = lib.callback.await('f_mechanicjob:tow:payslip', false)
                if res and not res.error then stopMission() end
                notifyResult(res)
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = tow.truck.coords.xyz,
    radius = 1.5,
    options = {
        {
            name = 'f_mechanicjob:tow:takeTruck',
            icon = 'fa-solid fa-truck-pickup',
            label = ('Ambil Flatbed (deposit Rp %s)'):format(lib.math.groupdigits(tow.truck.deposit, '.')),
            distance = 2.5,
            canInteract = function() return isTowJob() and not cache.vehicle end,
            onSelect = function()
                notifyResult(lib.callback.await('f_mechanicjob:tow:takeTruck', false))
            end,
        },
    },
})

local function addBlip(coords, sprite, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.6)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, 15)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    jobBlips[#jobBlips + 1] = blip
end

-- blip markas & flatbed hanya untuk job Derek
local function refreshJob()
    for _, blip in ipairs(jobBlips) do RemoveBlip(blip) end
    jobBlips = {}
    if not isTowJob() then
        if mission.on then stopMission() end
        return
    end
    addBlip(tow.depot.coords, 477, tow.depot.label)
    addBlip(tow.truck.coords, 326, tow.truck.label)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() SetTimeout(500, refreshJob) end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() SetTimeout(500, refreshJob) end)
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    stopMission()
    for _, blip in ipairs(jobBlips) do RemoveBlip(blip) end
    jobBlips = {}
end)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then refreshJob() end
end)
