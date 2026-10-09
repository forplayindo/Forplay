-- Meja administrasi penjara (panel NUI html/prison.*). Data penahanan diambil dari MDT f_phone,
-- polisi tinggal menekan "Masukkan ke Penjara" (server/prison.lua).

local sharedConfig = require 'config.shared'
local deskOpen = false

local function isLeoOnDuty()
    local job = QBX.PlayerData.job
    return job ~= nil and job.type == 'leo' and job.onduty
end

local function closeDesk()
    deskOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'prisonClose' })
end

local function loadDesk()
    local data = lib.callback.await('f_police:server:prisonDesk', false)
    if not data then return end
    if data.error then
        exports.qbx_core:Notify(data.error, 'error')
        return
    end
    return data
end

local function openDesk()
    local data = loadDesk()
    if not data then return end
    deskOpen = true
    SendNUIMessage({ type = 'prisonOpen', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('prisonClose', function(_, cb)
    closeDesk()
    cb(1)
end)

RegisterNUICallback('prisonRefresh', function(_, cb)
    cb(1)
    if not deskOpen then return end
    local data = loadDesk()
    if not data then return closeDesk() end
    SendNUIMessage({ type = 'prisonOpen', data = data })
end)

RegisterNUICallback('prisonServe', function(data, cb)
    if not deskOpen then return cb({ ok = false }) end
    local ok, msg = lib.callback.await('f_police:server:prisonServe', false, data.id)
    cb({ ok = ok == true, msg = msg })
    if ok then
        exports.qbx_core:Notify(msg, 'success')
        closeDesk()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and deskOpen then SetNuiFocus(false, false) end
end)

-- [E] di meja: point aktif hanya saat dekat, loop tombol cuma jalan di dalam radius 1.5 m
for _, coords in ipairs(sharedConfig.locations.prisonDesk or {}) do
    local shown = false
    lib.points.new({
        coords = coords,
        distance = 1.5,
        nearby = function()
            local can = isLeoOnDuty() and not deskOpen
            if can ~= shown then
                shown = can
                if can then lib.showTextUI('[E] Administrasi Penjara') else lib.hideTextUI() end
            end
            if can and IsControlJustReleased(0, 38) then
                shown = false
                lib.hideTextUI()
                openDesk()
            end
        end,
        onExit = function()
            if shown then
                shown = false
                lib.hideTextUI()
            end
        end,
    })
end
