local config = require 'config.shared'

local menuOpen = false
local shown = false

local function hideText()
    if not shown then return end
    shown = false
    lib.hideTextUI()
end

local function openMenu()
    local data = lib.callback.await('f_koperasi:server:getMenu', false)
    if not data then return end
    hideText()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- [E] Koperasi: hanya dicek tiap frame saat pemain dekat (lib.points)
for _, coords in ipairs(config.locations) do
    lib.points.new({
        coords = coords,
        distance = config.distance + 3.0,
        nearby = function(point)
            if menuOpen or cache.vehicle or point.currentDistance > config.distance then
                return hideText()
            end
            if not shown then
                shown = true
                lib.showTextUI('[E] Koperasi')
            end
            if IsControlJustReleased(0, 38) then openMenu() end
        end,
        onExit = hideText,
    })
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_koperasi:server:getMenu', false) or false)
end)

RegisterNUICallback('sell', function(data, cb)
    cb(lib.callback.await('f_koperasi:server:sell', false, data.items) or { ok = false })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hideText()
    if menuOpen then SetNuiFocus(false, false) end
end)
