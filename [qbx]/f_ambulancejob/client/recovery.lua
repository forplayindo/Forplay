-- Masa pemulihan kaki & Crutch (client). Sisa waktu dari server lewat state bag
-- 'f_ambulancejob:recovery'. Selama pemulihan Crutch wajib: tanpa Crutch jalan pincang parah dan
-- bisa jatuh kalau memaksa lari. Dengan Crutch: jalan pakai tongkat, tidak bisa lari / lompat /
-- memegang senjata. Menyetir tetap boleh (prop disembunyikan selama di kendaraan).
local cfg = require 'config.treatment'
local crutchCfg = cfg.crutch
local STATE = 'f_ambulancejob:recovery'

local equipped = false
local prop        ---@type number?
local propPos, propRot = crutchCfg.pos, crutchCfg.rot
-- gaya jalan yang dipasang script ini. Reset hanya kalau kita yang memasang, supaya pincang dari
-- luka f_medical tidak ikut terhapus.
local currentClip ---@type string?
local touchedClip = false
local forceClip = false ---@type boolean pasang ulang di update berikutnya (setelah kendaraan / ragdoll)

local function inRecovery()
    return (LocalPlayer.state[STATE] or 0) > 0
end

local function applyClipset(name)
    if name == currentClip and not forceClip then return end
    forceClip = false
    if name then
        lib.requestAnimSet(name, 5000)
        SetPedMovementClipset(cache.ped, name, 0.25)
        touchedClip = true
    elseif touchedClip then
        ResetPedMovementClipset(cache.ped, 0.25)
        touchedClip = false
    end
    currentClip = name
end

local function deleteProp()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

local function attachProp()
    deleteProp()
    local model = joaat(crutchCfg.model)
    if not IsModelInCdimage(model) then
        lib.print.warn(('model Crutch %s tidak ditemukan'):format(crutchCfg.model))
        return
    end
    lib.requestModel(model, 5000)
    local coords = GetEntityCoords(cache.ped)
    prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, crutchCfg.bone),
        propPos.x, propPos.y, propPos.z, propRot.x, propRot.y, propRot.z, true, true, false, true, 1, true)
end

local function updateMovement()
    if equipped then
        applyClipset(crutchCfg.clipset)
    elseif inRecovery() then
        applyClipset(crutchCfg.limpClipset)
    else
        applyClipset(nil)
    end
end

local function setEquipped(value, silent)
    if equipped == value then return end
    equipped = value
    if value then
        TriggerEvent('ox_inventory:disarm', cache.playerId, true)
        if not cache.vehicle then attachProp() end
        if not silent then exports.qbx_core:Notify('Kruk dipegang', 'inform') end
    else
        deleteProp()
        if not silent then exports.qbx_core:Notify('Kruk dilepas', 'inform') end
    end
    forceClip = true
    updateMovement()
end

exports('useCrutch', function()
    if exports.f_medical:IsDead() or exports.f_medical:IsLaststand() then return end
    if cache.vehicle then return exports.qbx_core:Notify('Tidak bisa di dalam kendaraan', 'error') end
    setEquipped(not equipped)
end)

-- efek per frame selama memegang Crutch atau masa pemulihan
CreateThread(function()
    local nextFallRoll = 0
    while true do
        local recovering = inRecovery()
        if equipped or recovering then
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- lompat
            if equipped then
                DisableControlAction(0, 24, true)  -- serang
                DisableControlAction(0, 25, true)  -- bidik
                DisableControlAction(0, 37, true)  -- roda senjata
                DisableControlAction(0, 44, true)  -- cover
                DisableControlAction(0, 140, true) -- pukul
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            elseif recovering and not cache.vehicle and IsDisabledControlPressed(0, 21)
                and GetEntitySpeed(cache.ped) > 1.0 and GetGameTimer() >= nextFallRoll then
                -- memaksa lari tanpa Crutch: bisa jatuh
                nextFallRoll = GetGameTimer() + 1000
                if math.random(100) <= cfg.recovery.fallChance and not IsPedRagdoll(cache.ped) then
                    SetPedToRagdoll(cache.ped, 2000, 2500, 0, false, false, false)
                    exports.qbx_core:Notify('Kakimu belum kuat, pakai Crutch', 'error')
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- pengawasan keadaan: kendaraan, jatuh / tergeletak, item dibuang, clipset tertimpa script lain
CreateThread(function()
    local wasInVehicle = false
    while true do
        Wait(500)
        if equipped then
            local inVehicle = cache.vehicle ~= false and cache.vehicle ~= nil
            if inVehicle and not wasInVehicle then
                deleteProp()
            elseif not inVehicle and wasInVehicle then
                attachProp()
                forceClip = true
            end
            wasInVehicle = inVehicle

            if exports.f_medical:IsDead() or exports.f_medical:IsLaststand() or IsPedRagdoll(cache.ped) then
                setEquipped(false, true)
                exports.qbx_core:Notify('Crutch terlepas dari tangan', 'error')
            elseif exports.ox_inventory:Search('count', cfg.items.crutch) < 1 then
                setEquipped(false, true)
            elseif not inVehicle and prop and not DoesEntityExist(prop) then
                attachProp()
            end
        end
        if not cache.vehicle then updateMovement() end
    end
end)

AddStateBagChangeHandler(STATE, ('player:%s'):format(cache.serverId), function(_, _, value)
    if not value then forceClip = true end
    SetTimeout(0, updateMovement)
end)

RegisterNetEvent('f_ambulancejob:client:recoveryStarted', function(left)
    if GetInvokingResource() then return end
    exports.qbx_core:Notify(('Kakimu dibidai. Masa pemulihan %d menit, wajib pakai Kruk.'):format(math.ceil((left or 0) / 60)), 'inform', 8000)
end)

RegisterNetEvent('f_ambulancejob:client:recoveryEnded', function()
    if GetInvokingResource() then return end
    exports.qbx_core:Notify('Kakimu sudah pulih. Crutch boleh disimpan.', 'success', 8000)
    forceClip = true
    updateMovement()
end)

RegisterNetEvent('f_ambulancejob:client:crutchGiven', function()
    if GetInvokingResource() then return end
    exports.qbx_core:Notify('Kamu menerima Crutch. Pakai dari inventory.', 'success')
end)

-- admin: setel posisi prop live (/crutchpos x y z rx ry rz), salin hasilnya ke config/treatment.lua
RegisterNetEvent('f_ambulancejob:client:crutchPos', function(pos, rot)
    if GetInvokingResource() then return end
    propPos, propRot = pos, rot
    if not equipped then setEquipped(true, true) else attachProp() end
    print(('crutch pos = vec3(%.3f, %.3f, %.3f), rot = vec3(%.1f, %.1f, %.1f)'):format(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    deleteProp()
    if touchedClip then ResetPedMovementClipset(cache.ped, 0.0) end
end)
