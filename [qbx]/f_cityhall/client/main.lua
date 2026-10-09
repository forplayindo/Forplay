local config = require 'config.client'
local sharedConfig = require 'config.shared'
local offices = sharedConfig.offices
local blips, zones = {}, {}
local activeText -- text UI of the zone the player is standing in
local view       -- nil | 'services' | 'staff'
local initialized = false

local function restoreText()
    if activeText and not view then lib.showTextUI(activeText) end
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function openNui(action, data)
    view = action == 'openServices' and 'services' or 'staff'
    lib.hideTextUI()
    SendNUIMessage({ action = action, data = data })
    SetNuiFocus(true, true)
end

local function closeNui()
    if not view then return end
    view = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    restoreText()
end

local function openServices(officeKey)
    local data = lib.callback.await('f_cityhall:getServices', false, officeKey)
    if not data then return end
    data.office = officeKey
    openNui('openServices', data)
end

local function openStaff()
    if view then return end
    local data = lib.callback.await('f_cityhall:getRequests', false)
    if not data then
        return lib.notify({ type = 'error', description = 'Hanya petugas administrasi yang sedang bertugas.' })
    end
    openNui('openStaff', data)
end

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb(1)
end)

RegisterNUICallback('order', function(data, cb)
    local res = lib.callback.await('f_cityhall:placeOrder', false, data.office, data.ids, data.method)
    if res and res.ok then
        if res.paid then
            lib.notify({ type = 'success', description = ('Permohonan #%s dibayar. Silakan tunggu petugas.'):format(res.code) })
        else
            lib.notify({ type = 'info', duration = 8000,
                description = ('Tagihan #%s dikirim ke HP. Bayar lewat Bank dalam %d menit.'):format(res.code, res.timeout) })
        end
        closeNui()
    end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_cityhall:getRequests', false) or false)
end)

local function handled(res)
    if res and res.msg then lib.notify({ description = res.msg, type = res.ok and 'success' or 'error' }) end
    return res or { ok = false }
end

RegisterNUICallback('approve', function(data, cb)
    cb(handled(lib.callback.await('f_cityhall:approve', false, data.id)))
end)

RegisterNUICallback('reject', function(data, cb)
    cb(handled(lib.callback.await('f_cityhall:reject', false, data.id, data.reason)))
end)

RegisterNUICallback('prices', function(_, cb)
    cb(lib.callback.await('f_cityhall:getPrices', false) or false)
end)

RegisterNUICallback('setPrice', function(data, cb)
    cb(handled(lib.callback.await('f_cityhall:setPrice', false, data.key, data.value)))
end)

RegisterNUICallback('tickets', function(_, cb)
    cb(lib.callback.await('f_cityhall:getTickets', false) or false)
end)

RegisterNUICallback('ticketAction', function(data, cb)
    cb(handled(lib.callback.await('f_cityhall:ticketAction', false, data.id, data.action)))
end)

-- nomor telepon untuk ditempel di aplikasi telepon f_phone
RegisterNUICallback('copy', function(data, cb)
    if type(data.text) == 'string' and data.text ~= '' then
        lib.setClipboard(data.text)
        lib.notify({ type = 'success', description = ('Nomor %s disalin.'):format(data.text) })
    end
    cb(1)
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    lib.callback.await('f_cityhall:toggleDuty', false)
    closeNui()
    cb(1)
end)

RegisterNetEvent('f_cityhall:client:refresh', function()
    if view ~= 'staff' then return end
    local data = lib.callback.await('f_cityhall:getRequests', false)
    if not data then return closeNui() end
    SendNUIMessage({ action = 'staffData', data = data })
end)

RegisterNetEvent('f_cityhall:client:openStaff', openStaff)

---------------------------------------------------------------------------
-- Counter (citizens) & desk (staff)
---------------------------------------------------------------------------
local function openEmploymentMenu()
    local jobs = sharedConfig.employment.jobs
    local keys = {}
    for k in pairs(jobs) do keys[#keys + 1] = k end
    table.sort(keys)

    local options = {}
    for _, job in ipairs(keys) do
        options[#options + 1] = {
            title = jobs[job],
            onSelect = function()
                lib.callback.await('f_cityhall:server:applyJob', false, job)
                restoreText()
            end
        }
    end
    lib.registerContext({ id = 'cityhall_employment_menu', title = 'Lowongan Kerja', menu = 'cityhall_counter_menu', onExit = restoreText, options = options })
    lib.showContext('cityhall_employment_menu')
end

local function openCounter(officeKey)
    local office = offices[officeKey]
    if not (office.employment and sharedConfig.employment.enabled) then return openServices(officeKey) end

    lib.registerContext({
        id = 'cityhall_counter_menu',
        title = office.label,
        onExit = restoreText,
        options = {
            { title = 'Layanan Administrasi', description = office.subtitle, icon = 'id-card', onSelect = function() openServices(officeKey) end },
            { title = 'Lowongan Kerja', description = 'Pilih pekerjaan baru', icon = 'briefcase', onSelect = openEmploymentMenu },
        }
    })
    lib.showContext('cityhall_counter_menu')
end

local function openDesk(officeKey)
    local job = QBX.PlayerData.job
    if job.name ~= offices[officeKey].job then return end

    if sharedConfig.rules.dutyToggleJobs[job.name] and not job.onduty then
        lib.registerContext({
            id = 'cityhall_desk_menu',
            title = offices[officeKey].label,
            onExit = restoreText,
            options = {{
                title = 'Mulai Bertugas', icon = 'clipboard-user',
                onSelect = function()
                    lib.callback.await('f_cityhall:toggleDuty', false)
                    restoreText()
                end
            }}
        })
        return lib.showContext('cityhall_desk_menu')
    end
    openStaff()
end

local function addZone(coords, text, canUse, onUse)
    zones[#zones + 1] = lib.zones.box({
        coords = coords,
        size = config.zoneSize,
        debug = config.debugPoly,
        onEnter = function()
            if not canUse() then return end
            activeText = text
            if not view then lib.showTextUI(text) end
        end,
        onExit = function()
            if activeText == text then
                activeText = nil
                lib.hideTextUI()
            end
        end,
        inside = function()
            if activeText == text and not view and IsControlJustPressed(0, 38) and not lib.getOpenContextMenu() then
                lib.hideTextUI()
                onUse()
            end
        end,
    })
end

local function alwaysTrue() return true end

local function init()
    if initialized then return end
    initialized = true

    for key, office in pairs(offices) do
        if office.blip then
            local b = office.blip
            local blip = AddBlipForCoord(office.counter.x, office.counter.y, office.counter.z)
            SetBlipSprite(blip, b.sprite or 1)
            SetBlipDisplay(blip, b.display or 4)
            SetBlipScale(blip, b.scale or 0.7)
            SetBlipColour(blip, b.colour or 0)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(b.label or office.label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        addZone(office.counter, ('[E] %s'):format(office.label), alwaysTrue, function() openCounter(key) end)
        addZone(office.desk, '[E] Meja Petugas', function()
            return QBX.PlayerData.job and QBX.PlayerData.job.name == office.job
        end, function() openDesk(key) end)
    end
end

local function cleanup()
    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then RemoveBlip(blips[i]) end
    end
    for i = 1, #zones do zones[i]:remove() end
    blips, zones = {}, {}
    if activeText then
        activeText = nil
        lib.hideTextUI()
    end
    if view then
        view = nil
        SetNuiFocus(false, false)
    end
    initialized = false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', init)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', cleanup)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    if LocalPlayer.state.isLoggedIn then init() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    cleanup()
end)
