-- Tameng balistik, lihat server/shield.lua. Prop dibuat LOKAL di setiap client untuk pemain dekat yang
-- statebag `shield`-nya aktif: tidak bisa di-spawn sembarangan lewat executor, dan peluru penembak
-- tertahan di sisi penembak (yang menghitung damage).
-- Tameng ditempel ke lengan atas kiri tanpa animasi apa pun, jadi tidak melawan animasi bidik GTA:
-- pistol dipegang normal, tameng tetap di sisi kiri depan badan dan ikut berputar saat membidik.

local shield = require 'config.shared'.shield
local PISTOL_GROUP = `GROUP_PISTOL`

---@type table<number, {object: integer, ped: integer}>
local props = {}

---@param object integer
---@param ped integer
local function attach(object, ped)
    local o, r = shield.offset, shield.rotation
    DetachEntity(object, false, false)
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, shield.bone), o.x, o.y, o.z, r.x, r.y, r.z,
                         false, false, true, true, 0, true)
end

---@param ped integer
---@return integer object
local function createProp(ped)
    lib.requestModel(shield.model)
    local coords = GetEntityCoords(ped)
    local object = CreateObject(shield.model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(shield.model)
    attach(object, ped)
    return object
end

---@param serverId number
local function removeProp(serverId)
    local prop = props[serverId]
    if not prop then return end
    if DoesEntityExist(prop.object) then DeleteEntity(prop.object) end
    props[serverId] = nil
end

-- gambar / hapus prop tameng untuk semua pemain dekat (termasuk diri sendiri)
CreateThread(function()
    while true do
        local myCoords = GetEntityCoords(cache.ped)
        local seen = {}

        for _, playerId in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(playerId)
            if Player(serverId).state.shield then
                local ped = GetPlayerPed(playerId)
                if #(GetEntityCoords(ped) - myCoords) < shield.drawDistance then
                    seen[serverId] = true
                    local prop = props[serverId]
                    if prop and (prop.ped ~= ped or not DoesEntityExist(prop.object)) then
                        removeProp(serverId)
                        prop = nil
                    end
                    if not prop then
                        props[serverId] = {object = createProp(ped), ped = ped}
                    end
                end
            end
        end

        for serverId in pairs(props) do
            if not seen[serverId] then removeProp(serverId) end
        end

        Wait(500)
    end
end)

-- Pemegang tameng ---------------------------------------------------------------------------

local holding = false

local function shouldDrop()
    local ped = cache.ped
    return cache.vehicle or IsPedDeadOrDying(ped, true) or IsPedSwimming(ped)
        or LocalPlayer.state.cuffed or QBX.PlayerData.metadata.ishandcuffed
end

local function holdShield()
    CreateThread(function()
        local nextCheck, dropSent = 0, false

        while holding do
            if not shield.sprint then
                DisableControlAction(0, 21, true) -- lari
            end
            DisableControlAction(0, 22, true)  -- lompat
            DisableControlAction(0, 44, true)  -- cover
            DisableControlAction(0, 140, true) -- pukul
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local now = GetGameTimer()
            if now > nextCheck then
                nextCheck = now + 250

                if shouldDrop() then
                    if not dropSent then
                        dropSent = true
                        TriggerServerEvent('f_police:server:shieldOff')
                    end
                else
                    local weapon = cache.weapon
                    if weapon and GetWeapontypeGroup(weapon) ~= PISTOL_GROUP then
                        TriggerEvent('ox_inventory:disarm', true)
                        exports.qbx_core:Notify(shield.text.pistolOnly, 'error')
                    end
                end
            end

            Wait(0)
        end
    end)
end

AddStateBagChangeHandler('shield', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value and not holding then
        holding = true
        holdShield()
    elseif not value then
        holding = false
    end
end)

-- /tamengpos ox oy oz rx ry rz : setel posisi tameng langsung (hanya terlihat di layar sendiri),
-- lalu salin angka dari F8 ke config/shared.lua. Tanpa angka = tampilkan nilai sekarang.
-- Matikan dengan shield.debug = false.
if shield.debug then
    RegisterCommand('tamengpos', function(_, args)
        local n = {}
        for i = 1, 6 do n[i] = tonumber(args[i]) end
        if n[6] then
            shield.offset = vec3(n[1], n[2], n[3])
            shield.rotation = vec3(n[4], n[5], n[6])
            local prop = props[cache.serverId]
            if prop and DoesEntityExist(prop.object) then attach(prop.object, prop.ped) end
        end

        local o, r = shield.offset, shield.rotation
        print(('[tameng] offset = vec3(%.2f, %.2f, %.2f), rotation = vec3(%.1f, %.1f, %.1f)')
            :format(o.x, o.y, o.z, r.x, r.y, r.z))
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for serverId in pairs(props) do
        removeProp(serverId)
    end
end)
