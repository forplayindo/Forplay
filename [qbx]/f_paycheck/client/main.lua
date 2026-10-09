local config = require 'config'
local blips, points = {}, {}
local open = false

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function closeNui()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openNui(label)
    if open then return end
    local data = lib.callback.await('f_paycheck:get', false)
    if not data then
        return lib.notify({ type = 'error', description = 'Kamu terlalu jauh dari petugas.' })
    end
    data.label = label
    open = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb(1)
end)

RegisterNUICallback('withdraw', function(data, cb)
    local res = lib.callback.await('f_paycheck:withdraw', false, data.method) or { ok = false, msg = 'Server tidak merespons.' }
    if res.ok then
        closeNui()
        lib.notify({ type = 'success', title = 'Paycheck Dicairkan', description = 'Rincian dikirim ke Email kamu.', icon = 'envelope' })
    end
    cb(res)
end)

---------------------------------------------------------------------------
-- NPC (spawn hanya saat dekat)
---------------------------------------------------------------------------
local function spawnPed(point)
    local loc = point.loc
    lib.requestModel(loc.model)
    local c = loc.coords
    local ped = CreatePed(4, loc.model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(loc.model)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if loc.scenario then TaskStartScenarioInPlace(ped, loc.scenario, 0, true) end
    exports.ox_target:addLocalEntity(ped, {{
        name = 'f_paycheck', icon = 'fas fa-money-check-dollar', label = 'Ambil Paycheck',
        distance = 2.5,
        onSelect = function() openNui(loc.label) end,
    }})
    point.ped = ped
end

local function removePed(point)
    if point.ped and DoesEntityExist(point.ped) then
        exports.ox_target:removeLocalEntity(point.ped, 'f_paycheck')
        DeleteEntity(point.ped)
    end
    point.ped = nil
end

CreateThread(function()
    for i = 1, #config.locations do
        local loc = config.locations[i]
        local c = loc.coords
        if loc.blip then
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, loc.blip.sprite or 500)
            SetBlipColour(blip, loc.blip.colour or 2)
            SetBlipScale(blip, loc.blip.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(loc.label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
        points[#points + 1] = lib.points.new({
            coords = c.xyz, distance = 40.0, loc = loc,
            onEnter = spawnPed, onExit = removePed,
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    closeNui()
    for i = 1, #points do removePed(points[i]); points[i]:remove() end
    for i = 1, #blips do RemoveBlip(blips[i]) end
end)
