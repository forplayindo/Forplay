-- Tameng balistik. Server yang menentukan siapa memegang tameng (statebag `shield`); setiap client
-- menggambar prop tameng sendiri (lokal) untuk pemain di dekatnya, lihat client/shield.lua.

local shield = require 'config.shared'.shield

---@type table<number, true>
local holders = {}

---@param src number
---@param on boolean
local function setShield(src, on)
    holders[src] = on or nil
    Player(src).state:set('shield', on or nil, true)
end

---@param src number
---@return boolean
local function hasItem(src)
    return (exports.ox_inventory:GetItemCount(src, shield.item) or 0) > 0
end

exports.qbx_core:CreateUseableItem(shield.item, function(source)
    if holders[source] then return setShield(source, false) end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not hasItem(source) then return end

    local metadata = player.PlayerData.metadata
    local state = Player(source).state
    if metadata.isdead or metadata.inlaststand or metadata.ishandcuffed or state.cuffed or state.hostage then return end

    if GetVehiclePedIsIn(GetPlayerPed(source), false) ~= 0 then
        return exports.qbx_core:Notify(source, shield.text.inVehicle, 'error')
    end

    setShield(source, true)
end)

-- client hanya boleh MELEPAS tameng (mati, diborgol, masuk kendaraan, berenang)
RegisterNetEvent('f_police:server:shieldOff', function()
    if holders[source] then setShield(source, false) end
end)

-- lepas kalau item pindah (dibuang, diberikan, disita), pemain naik kendaraan, atau logout
CreateThread(function()
    while true do
        Wait(3000)
        for src in pairs(holders) do
            local ped = GetPlayerPed(src)
            if ped == 0 or not hasItem(src) or GetVehiclePedIsIn(ped, false) ~= 0 then
                setShield(src, false)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    holders[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for src in pairs(holders) do
        Player(src).state:set('shield', nil, true)
    end
end)
