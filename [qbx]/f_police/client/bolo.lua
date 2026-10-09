-- Blip kendaraan BOLO di peta polisi (data dari server/bolo.lua tiap 30 detik).

---@type table<string, integer> plat -> blip
local blips = {}

local function removeAll()
    for plate, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[plate] = nil
    end
end

RegisterNetEvent('f_police:client:boloBlips', function(list)
    local seen = {}
    for _, v in ipairs(list or {}) do
        seen[v.plate] = true
        local blip = blips[v.plate]
        if blip and DoesBlipExist(blip) then
            SetBlipCoords(blip, v.x, v.y, v.z)
        else
            blip = AddBlipForCoord(v.x, v.y, v.z)
            SetBlipSprite(blip, 225)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.9)
            SetBlipAsShortRange(blip, false)
            SetBlipFlashes(blip, true)
            SetBlipFlashTimer(blip, 5000)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('BOLO · %s'):format(v.plate))
            EndTextCommandSetBlipName(blip)
            blips[v.plate] = blip
        end
    end
    for plate, blip in pairs(blips) do
        if not seen[plate] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            blips[plate] = nil
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', removeAll)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then removeAll() end
end)
