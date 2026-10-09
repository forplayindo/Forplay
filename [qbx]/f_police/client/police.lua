-- ox_target khusus polisi on-duty. Borgol, buka borgol (kunci), seret, masukkan ke mobil, dan
-- keluarkan penumpang/bagasi ada di client/criminal.lua karena dipakai bersama.

local config = require 'config.criminal'
local text = config.text
-- helper dari client/criminal.lua, dibaca saat dipakai supaya urutan load file tidak berpengaruh
local T = setmetatable({}, { __index = function(_, key) return FTarget[key] end })

local function canAct()
    return T.isLeoOnDuty() and T.selfFree()
end

-- Administrasi (tilang) - panel NUI html/admin.* --------------------------------------------------

---@type { id: integer?, vehicle: integer? }?
local admin

local function closeAdmin()
    if not admin then return end
    admin = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'adminClose' })
end

local function seizeVehicle(vehicle, reasonIndex)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    local body = math.ceil(GetVehicleBodyHealth(vehicle))
    local engine = math.ceil(GetVehicleEngineHealth(vehicle))
    local fuel = GetVehicleFuelLevel(vehicle)
    if not lib.progressCircle({
        duration = 5000,
        position = 'bottom',
        label = text.seizing,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'missheistdockssetup1clipboard@base', clip = 'base', flag = 49 },
        prop = {
            { model = `prop_notepad_01`, bone = 18905, pos = vec3(0.1, 0.02, 0.05), rot = vec3(10.0, 0.0, 0.0) },
            { model = `prop_pencil_01`, bone = 58866, pos = vec3(0.11, -0.02, 0.001), rot = vec3(-120.0, 0.0, 0.0) },
        },
    }) then return end
    TriggerServerEvent('f_police:server:seizeVehicle', VehToNet(vehicle), reasonIndex, body, engine, fuel)
end

---Kendaraan kosong (tanpa pengemudi) yang tersinkron ke server.
local function seizable(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
        and GetPedInVehicleSeat(vehicle, -1) == 0 and NetworkGetEntityIsNetworked(vehicle)
end

---Satu panel untuk semua administrasi. Yang dibidik dipakai langsung; sisi lainnya diambil dari yang
---terdekat (pemain 3 m untuk tilang, kendaraan kosong 6 m untuk sita).
local function openAdmin(entity)
    if admin then return end
    local myCoords = GetEntityCoords(cache.ped)
    local id, vehicle
    if IsPedAPlayer(entity) then
        id = T.serverIdOf(entity)
        local closest = lib.getClosestVehicle(myCoords, 6.0, false)
        vehicle = seizable(closest) and closest or nil
    else
        vehicle = seizable(entity) and entity or nil
        local player = lib.getClosestPlayer(myCoords, 3.0, false)
        id = player and GetPlayerServerId(player) or nil
    end

    local data = lib.callback.await('f_police:server:adminData', false, id)
    if not data then return end
    if vehicle then
        local label = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
        data.vehicle = { plate = qbx.getVehiclePlate(vehicle), label = label ~= 'NULL' and label or '' }
    end

    admin = { id = data.target and id or nil, vehicle = vehicle }
    SendNUIMessage({ type = 'adminOpen', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('adminClose', function(_, cb)
    closeAdmin()
    cb(1)
end)

RegisterNUICallback('adminSubmit', function(data, cb)
    local ctx = admin
    if not ctx then return cb({ ok = false }) end

    local res
    if data.action == 'fine' and ctx.id then
        res = lib.callback.await('f_police:server:issueFine', false, ctx.id, data.indexes)
    elseif (data.action == 'sim' or data.action == 'stnk') and ctx.id then
        res = lib.callback.await('f_police:server:holdDocument', false, ctx.id, data.action, data.slot, data.note)
    elseif data.action == 'revoke' and ctx.id then
        res = lib.callback.await('f_police:server:revokeLicense', false, ctx.id, data.kind, data.note)
    elseif data.action == 'seize' and ctx.vehicle then
        cb({ ok = true })
        closeAdmin()
        return seizeVehicle(ctx.vehicle, tonumber(data.reason))
    end

    res = res or { ok = false, msg = 'Aksi tidak valid.' }
    if res.ok then
        exports.qbx_core:Notify(res.msg, 'success')
        closeAdmin()
    end
    cb(res)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and admin then SetNuiFocus(false, false) end
end)

-- Pemain ------------------------------------------------------------------------------------

exports.ox_target:addGlobalPlayer({
    {
        name = 'f_police:admin',
        icon = 'fa-solid fa-clipboard-list',
        label = text.admin,
        distance = 2.0,
        canInteract = function(entity)
            if not canAct() then return false end
            local state = T.stateOf(entity)
            return state ~= nil and not state.hostage
        end,
        onSelect = function(data) openAdmin(data.entity) end,
    },
    {
        name = 'f_police:search',
        icon = 'fa-solid fa-magnifying-glass',
        label = text.search,
        distance = 1.5,
        canInteract = function(entity)
            if not canAct() then return false end
            local state = T.stateOf(entity)
            return state ~= nil and not state.hostage and (state.canSteal == true or T.isDown(entity, state))
        end,
        onSelect = function(data)
            local id = T.serverIdOf(data.entity)
            if id then exports.ox_inventory:openInventory('player', id) end
        end,
    },
    {
        name = 'f_police:dna',
        icon = 'fa-solid fa-dna',
        label = text.takeDna,
        distance = 1.5,
        items = 'empty_evidence_bag',
        canInteract = function(entity)
            if not canAct() then return false end
            local state = T.stateOf(entity)
            return state ~= nil and not state.hostage and T.isRestrained(entity, state)
        end,
        onSelect = function(data)
            local id = T.serverIdOf(data.entity)
            if not id then return end
            if lib.progressCircle({
                duration = 3000,
                position = 'bottom',
                label = text.takeDna,
                canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = { dict = 'amb@prop_human_parking_meter@male@idle_a', clip = 'idle_a', flag = 49 },
            }) then
                TriggerServerEvent('f_police:server:takeDna', id)
            end
        end,
    },
    {
        name = 'f_police:anklet',
        icon = 'fa-solid fa-satellite-dish',
        label = text.anklet,
        distance = 1.5,
        canInteract = function(entity)
            if not canAct() then return false end
            local state = T.stateOf(entity)
            return state ~= nil and state.cuffed == true and not state.hostage
        end,
        onSelect = function(data)
            local id = T.serverIdOf(data.entity)
            if id then TriggerServerEvent('police:server:SetTracker', id) end
        end,
    },
})

-- Kendaraan ---------------------------------------------------------------------------------

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_police:adminVehicle',
        icon = 'fa-solid fa-clipboard-list',
        label = text.admin,
        distance = 2.5,
        canInteract = canAct,
        onSelect = function(data) openAdmin(data.entity) end,
    },
    {
        name = 'f_police:checkPlate',
        icon = 'fa-solid fa-id-card',
        label = text.checkPlate,
        distance = 3.0,
        canInteract = function(entity)
            return canAct() and NetworkGetEntityIsNetworked(entity)
        end,
        onSelect = function(data)
            local info = lib.callback.await('f_police:server:plateInfo', false, VehToNet(data.entity))
            if not info then return end
            local lines = {
                info.owner and text.plateOwner:format(info.owner) or text.plateUnregistered,
                info.flagged and text.plateFlagged:format(info.reason ~= '' and info.reason or '-') or text.plateClean,
            }
            lib.alertDialog({
                header = text.plateTitle:format(info.plate),
                content = table.concat(lines, '  \n'),
                centered = true,
            })
        end,
    },
})
