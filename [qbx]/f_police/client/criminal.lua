-- ox_target untuk warga / gang: bidik pemain atau kendaraan. Semua aksi dicek ulang di server.
-- canInteract hanya membaca statebag + native murah, jadi ringan walau dievaluasi tiap frame
-- selama pemain menahan ALT ke sebuah entity.

local config = require 'config.criminal'
local text = config.text
local trunkSpots = config.trunk.classes

---@type integer|false kendaraan yang bagasinya sedang ditempati pemain ini (sebagai korban)
InTrunk = false
local carrying = false

AddEventHandler('qb-kidnapping:client:SetKidnapping', function(state)
    carrying = state == true
end)

-- kena taser: dipasang client sendiri (seperti canSteal) supaya polisi bisa memborgol tanpa angkat tangan
CreateThread(function()
    local stunned = false
    while true do
        Wait(250)
        local now = IsPedBeingStunned(cache.ped, 0) or (stunned and IsPedRagdoll(cache.ped))
        if now ~= stunned then
            stunned = now
            LocalPlayer.state:set('stunned', now, true)
        end
    end
end)

-- Helper ------------------------------------------------------------------------------------

---@param ped integer
---@return integer?
local function serverIdOf(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return end
    return GetPlayerServerId(idx)
end

---@param ped integer
---@return table? state, integer? serverId
local function stateOf(ped)
    local id = serverIdOf(ped)
    if not id then return end
    return Player(id).state, id
end

local function isLeoOnDuty()
    local job = QBX.PlayerData.job
    return job ~= nil and job.type == 'leo' and job.onduty
end

---Pemain ini bebas bertindak: tidak diborgol, tidak diseret, tidak di mobil/bagasi/sandera.
local function selfFree()
    return not QBX.PlayerData.metadata.ishandcuffed and not IsEscorted and not cache.vehicle
        and not InTrunk and not IsHostage and not HoldingHostage and not LocalPlayer.state.isDead
end

local function isDown(ped, state)
    return state.isDead == true or IsPedDeadOrDying(ped, true)
end

---Target bisa diseret / digendong / dimasukkan ke kendaraan: diborgol atau pingsan.
local function isRestrained(ped, state)
    return state.cuffed == true or isDown(ped, state)
end

local function gangAllowed(gangOnly)
    return not gangOnly or LocalPlayer.state.crewTag == 'gang'
end

---Pemain lain yang sedang digendong / diseret pemain ini.
---@return integer? serverId
local function carriedPlayer()
    for _, p in ipairs(lib.getNearbyPlayers(GetEntityCoords(cache.ped), 3.0, false)) do
        if GetEntityAttachedTo(p.ped) == cache.ped then
            local id = GetPlayerServerId(p.id)
            local state = Player(id).state
            if isRestrained(p.ped, state) then return id end
        end
    end
end

---Penumpang yang diborgol / pingsan di dalam kendaraan.
---@return integer? serverId
local function restrainedOccupant(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then
            local state, id = stateOf(ped)
            if state and isRestrained(ped, state) then return id end
        end
    end
end

---Helper bersama untuk ox_target polisi (client/police.lua).
FTarget = {
    serverIdOf = serverIdOf,
    stateOf = stateOf,
    isLeoOnDuty = isLeoOnDuty,
    selfFree = selfFree,
    isDown = isDown,
    isRestrained = isRestrained,
}

-- Rampok ------------------------------------------------------------------------------------

local function robPlayer(ped)
    local id = serverIdOf(ped)
    if not id then return end

    if not lib.progressCircle({
        duration = config.rob.duration,
        position = 'bottom',
        label = text.robbing,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'random@shop_robbery', clip = 'robbery_action_b', flag = 16 },
    }) then return end

    -- korban harus masih menyerah dan dekat; ox_inventory menutup sendiri kalau korban menurunkan tangan
    if Player(id).state.canSteal and #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) < 2.0 then
        exports.ox_inventory:openInventory('player', id)
    end
end

-- Ikat / buka borgol ------------------------------------------------------------------------

local cuffs = config.cuffs
local UNLOCK_ANIM = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 }

---Target bisa diikat: belum diborgol, dan sudah menyerah (angkat tangan) atau pingsan.
local function canTie(ped)
    if not selfFree() then return false end
    local state = stateOf(ped)
    return state ~= nil and not state.cuffed and not state.hostage
        and (state.canSteal == true or state.stunned == true or isDown(ped, state))
end

---Pemain ini berdiri di belakang target, di sisi tangan yang diborgol.
local function isBehind(ped)
    local tPos, myPos = GetEntityCoords(ped), GetEntityCoords(cache.ped)
    if #(tPos - myPos) > cuffs.maxDistance then return false end
    local dx, dy = myPos.x - tPos.x, myPos.y - tPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.05 then return false end
    local fwd = GetEntityForwardVector(ped)
    return (fwd.x * dx + fwd.y * dy) / len <= cuffs.behindDot
end

---@param kind 'zip'|'cuff'
local function canUnlockHere(ped, kind)
    if not selfFree() then return false end
    local state = stateOf(ped)
    if not state or not state.cuffed or state.hostage then return false end
    local cuffKind = state.cuffType == 'zip' and 'zip' or 'cuff'
    return cuffKind == kind and isBehind(ped)
end

local cutterProp
local function getCutterProp()
    if cutterProp == nil then
        local p = cuffs.cutter.prop
        local model = p and joaat(p.model)
        cutterProp = model and IsModelInCdimage(model)
            and { model = model, bone = p.bone, pos = p.pos, rot = p.rot } or false
    end
    return cutterProp or nil
end

---@param method 'hand'|'key'|'lockpick'|'cutter'
local function unlock(ped, method)
    local id = serverIdOf(ped)
    if not id then return end
    TriggerServerEvent('f_police:server:unlockStart', id, method)

    local ok
    if method == 'lockpick' then
        lib.playAnim(cache.ped, UNLOCK_ANIM.dict, UNLOCK_ANIM.clip, 8.0, -8.0, -1, UNLOCK_ANIM.flag)
        ok = lib.skillCheck(cuffs.lockpick.difficulty, cuffs.lockpick.keys)
        StopAnimTask(cache.ped, UNLOCK_ANIM.dict, UNLOCK_ANIM.clip, 1.0)
    else
        ok = lib.progressCircle({
            duration = cuffs[method].duration,
            position = 'bottom',
            label = method == 'cutter' and text.cutting or text.unlocking,
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = UNLOCK_ANIM,
            prop = method == 'cutter' and getCutterProp() or nil,
        })
    end

    TriggerServerEvent('f_police:server:unlockFinish', ok == true)
end

-- ox_target: pemain -------------------------------------------------------------------------

exports.ox_target:addGlobalPlayer({
    {
        name = 'f_police:rob',
        icon = 'fa-solid fa-mask',
        label = text.rob,
        distance = 1.5,
        canInteract = function(entity)
            if not selfFree() or isLeoOnDuty() or not gangAllowed(config.rob.gangOnly) then return false end
            local state = stateOf(entity)
            return state ~= nil and state.canSteal == true and not state.hostage
        end,
        onSelect = function(data) robPlayer(data.entity) end,
    },
    {
        -- satu tombol: server memakai handcuffs dulu, zipties kalau handcuffs tidak ada
        name = 'f_police:cuff',
        icon = 'fa-solid fa-handcuffs',
        label = text.cuff,
        distance = 1.5,
        items = { cuffs.handcuffItem, cuffs.zipItem },
        anyItem = true,
        canInteract = function(entity) return canTie(entity) end,
        onSelect = function(data) CuffTarget(serverIdOf(data.entity), not isLeoOnDuty()) end,
    },
    {
        name = 'f_police:uncuffHand',
        icon = 'fa-solid fa-hands',
        label = text.uncuffHand,
        distance = cuffs.maxDistance,
        canInteract = function(entity) return canUnlockHere(entity, 'zip') end,
        onSelect = function(data) unlock(data.entity, 'hand') end,
    },
    {
        name = 'f_police:uncuffKey',
        icon = 'fa-solid fa-key',
        label = text.uncuffKey,
        distance = cuffs.maxDistance,
        canInteract = function(entity) return isLeoOnDuty() and canUnlockHere(entity, 'cuff') end,
        onSelect = function(data) unlock(data.entity, 'key') end,
    },
    {
        name = 'f_police:uncuffLockpick',
        icon = 'fa-solid fa-unlock',
        label = text.uncuffLockpick,
        distance = cuffs.maxDistance,
        items = cuffs.lockpick.item,
        canInteract = function(entity) return not isLeoOnDuty() and canUnlockHere(entity, 'cuff') end,
        onSelect = function(data) unlock(data.entity, 'lockpick') end,
    },
    {
        name = 'f_police:uncuffCutter',
        icon = 'fa-solid fa-scissors',
        label = text.uncuffCutter,
        distance = cuffs.maxDistance,
        items = cuffs.cutter.item,
        canInteract = function(entity) return not isLeoOnDuty() and canUnlockHere(entity, 'cuff') end,
        onSelect = function(data) unlock(data.entity, 'cutter') end,
    },
    {
        name = 'f_police:escort',
        icon = 'fa-solid fa-people-pulling',
        label = text.escort,
        distance = 1.5,
        canInteract = function(entity)
            if not selfFree() or carrying then return false end
            local state = stateOf(entity)
            return state ~= nil and not state.hostage and isRestrained(entity, state)
        end,
        onSelect = function(data)
            TriggerServerEvent('police:server:EscortPlayer', serverIdOf(data.entity))
        end,
    },
    {
        name = 'f_police:carry',
        icon = 'fa-solid fa-people-carry-box',
        label = text.carry,
        distance = 1.5,
        canInteract = function(entity)
            if not selfFree() or IsPedInAnyVehicle(entity, false) then return false end
            local state = stateOf(entity)
            return state ~= nil and not state.hostage and isRestrained(entity, state)
        end,
        onSelect = function(data)
            TriggerServerEvent('police:server:KidnapPlayer', serverIdOf(data.entity))
        end,
    },
    {
        name = 'f_police:putInVehicle',
        icon = 'fa-solid fa-car-side',
        label = text.putInVehicle,
        distance = 2.0,
        canInteract = function(entity)
            if not selfFree() or IsPedInAnyVehicle(entity, false) then return false end
            local state = stateOf(entity)
            if not state or state.hostage or not isRestrained(entity, state) then return false end
            return lib.getClosestVehicle(GetEntityCoords(entity), 5.0, false) ~= nil
        end,
        onSelect = function(data)
            TriggerServerEvent('police:server:PutPlayerInVehicle', serverIdOf(data.entity))
            if carrying then TriggerEvent('police:client:GetKidnappedDragger') end
        end,
    },
    {
        name = 'f_police:hostage',
        icon = 'fa-solid fa-gun',
        label = text.hostage,
        distance = config.hostage.maxDistance,
        canInteract = function(entity)
            if not selfFree() or carrying or isLeoOnDuty() or not gangAllowed(config.hostage.gangOnly) then return false end
            if not IsHostageWeapon(cache.weapon) or IsPedInAnyVehicle(entity, false) then return false end
            local state = stateOf(entity)
            return state ~= nil and state.canSteal == true and not state.hostage and not isDown(entity, state)
        end,
        onSelect = function(data)
            TriggerServerEvent('f_police:server:takeHostage', serverIdOf(data.entity))
        end,
    },
})

-- ox_target: kendaraan ----------------------------------------------------------------------

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_police:takeOut',
        icon = 'fa-solid fa-person-walking-arrow-right',
        label = text.takeOut,
        distance = 2.5,
        canInteract = function(entity)
            return selfFree() and restrainedOccupant(entity) ~= nil
        end,
        onSelect = function(data)
            local id = restrainedOccupant(data.entity)
            if id then TriggerServerEvent('police:server:SetPlayerOutVehicle', id) end
        end,
    },
    {
        name = 'f_police:putInTrunk',
        icon = 'fa-solid fa-box-open',
        label = text.putInTrunk,
        distance = 2.5,
        canInteract = function(entity)
            if not selfFree() or Entity(entity).state.trunkVictim then return false end
            if not trunkSpots[GetVehicleClass(entity)] or not NetworkGetEntityIsNetworked(entity) then return false end
            return carriedPlayer() ~= nil
        end,
        onSelect = function(data)
            local id = carriedPlayer()
            if id then TriggerServerEvent('f_police:server:putInTrunk', VehToNet(data.entity), id) end
        end,
    },
    {
        name = 'f_police:takeOutTrunk',
        icon = 'fa-solid fa-box-open',
        label = text.takeOutTrunk,
        distance = 2.5,
        canInteract = function(entity)
            local victim = Entity(entity).state.trunkVictim
            return selfFree() and victim ~= nil and victim ~= cache.serverId
        end,
        onSelect = function(data)
            TriggerServerEvent('f_police:server:takeOutTrunk', VehToNet(data.entity))
        end,
    },
})

-- Korban di bagasi --------------------------------------------------------------------------

local TRUNK_DICT, TRUNK_CLIP = 'fin_ext_p1-7', 'cs_devin_dual-7'

---@param vehicle? integer
local function leaveTrunk(vehicle)
    InTrunk = false
    DetachEntity(cache.ped, true, true)
    ClearPedTasks(cache.ped)

    if vehicle and DoesEntityExist(vehicle) then
        local min = GetModelDimensions(GetEntityModel(vehicle))
        local pos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, min.y - 0.7, 0.0)
        SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, false, false, false, false)
        SetVehicleDoorOpen(vehicle, 5, false, false)
        SetTimeout(1500, function()
            if DoesEntityExist(vehicle) then SetVehicleDoorShut(vehicle, 5, false) end
        end)
    end
end

RegisterNetEvent('f_police:client:enterTrunk', function(netId)
    if GetInvokingResource() then return end
    local ok, vehicle = pcall(lib.waitFor, function()
        local veh = NetToVeh(netId)
        if veh ~= 0 then return veh end
    end, nil, 3000)
    if not ok or not vehicle then return TriggerServerEvent('f_police:server:trunkGone') end

    local offset = trunkSpots[GetVehicleClass(vehicle)] or vec3(0.0, -1.5, 0.0)

    IsEscorted = false
    TriggerEvent('hospital:client:isEscorted', false)
    DetachEntity(cache.ped, true, false)
    ClearPedTasksImmediately(cache.ped)

    SetVehicleDoorOpen(vehicle, 5, false, false)
    AttachEntityToEntity(cache.ped, vehicle, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 40.0, true, true, true, true, 1, true)
    lib.playAnim(cache.ped, TRUNK_DICT, TRUNK_CLIP, 8.0, 8.0, -1, 1, 999.0)
    InTrunk = vehicle
    SetTimeout(800, function()
        if DoesEntityExist(vehicle) then SetVehicleDoorShut(vehicle, 5, false) end
    end)

    CreateThread(function()
        while InTrunk == vehicle do
            Wait(500)
            if not DoesEntityExist(vehicle) or not IsEntityAttachedToEntity(cache.ped, vehicle) then
                leaveTrunk()
                TriggerServerEvent('f_police:server:trunkGone')
                break
            end
            if not IsEntityPlayingAnim(cache.ped, TRUNK_DICT, TRUNK_CLIP, 3) and not LocalPlayer.state.isDead then
                lib.playAnim(cache.ped, TRUNK_DICT, TRUNK_CLIP, 8.0, 8.0, -1, 1, 999.0)
            end
        end
    end)
end)

RegisterNetEvent('f_police:client:exitTrunk', function()
    if GetInvokingResource() or not InTrunk then return end
    leaveTrunk(InTrunk --[[@as integer]])
end)

-- DEBUG sementara: cek kenapa opsi buka borgol tidak muncul (hapus setelah selesai tes)
RegisterCommand('cekborgol', function()
    local p = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
    if not p then return print('[cekborgol] tidak ada pemain dalam 3 m') end
    local ped = GetPlayerPed(p)
    local state, id = stateOf(ped)
    local tPos, myPos = GetEntityCoords(ped), GetEntityCoords(cache.ped)
    local dx, dy = myPos.x - tPos.x, myPos.y - tPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    local fwd = GetEntityForwardVector(ped)
    local job = QBX.PlayerData.job
    local lines = {
        ('target id: %s'):format(id),
        ('saya polisi on duty: %s (job %s, type %s, onduty %s)'):format(isLeoOnDuty(), job and job.name, job and job.type, job and job.onduty),
        ('saya bebas: %s (borgol %s, escorted %s, mobil %s, bagasi %s, sandera %s/%s, mati %s)'):format(selfFree(),
            QBX.PlayerData.metadata.ishandcuffed, IsEscorted, cache.vehicle, InTrunk, IsHostage, HoldingHostage, LocalPlayer.state.isDead),
        ('target cuffed: %s, cuffType: %s, hostage: %s'):format(state and state.cuffed, state and state.cuffType, state and state.hostage),
        ('jarak: %.2f (maks %.2f)'):format(#(tPos - myPos), cuffs.maxDistance),
        ('belakang: %.2f (harus <= %.2f) -> %s'):format(len > 0.05 and (fwd.x * dx + fwd.y * dy) / len or 0, cuffs.behindDot, isBehind(ped)),
        ('opsi zip: %s, opsi kunci: %s'):format(canUnlockHere(ped, 'zip'), isLeoOnDuty() and canUnlockHere(ped, 'cuff')),
    }
    for _, l in ipairs(lines) do print('[cekborgol] ' .. l) end
    lib.notify({ title = 'cekborgol', description = 'Hasil ada di F8', type = 'inform' })
end, false)

-- pelaku: lepas animasi gendong setelah korban masuk bagasi
RegisterNetEvent('f_police:client:trunkLoaded', function()
    if GetInvokingResource() then return end
    if carrying then TriggerEvent('police:client:GetKidnappedDragger') end
end)
