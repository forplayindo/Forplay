local ped
local menuOpen = false     -- 'shop' | 'admin' | false
local shown = false
local testing             -- { model, endsAt }
local lastModel

local function hideText()
    if not shown then return end
    shown = false
    lib.hideTextUI()
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------
local function closeMenu(instant)
    if not menuOpen then return end
    local wasShop = menuOpen == 'shop'
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if wasShop then
        Preview.stop(instant)
        Preview.hideDisplay(false)
        DisplayRadar(true)
    end
end

local function openMenu(focusModel)
    if menuOpen or testing then return end
    local data = lib.callback.await('f_dealer:open', false)
    if not data then return end
    hideText()
    menuOpen = 'shop'
    data.focus = focusModel or lastModel
    Preview.hideDisplay(true)
    Preview.start()
    DisplayRadar(false)
    SendNUIMessage({ action = 'open', mode = 'shop', data = data })
    SetNuiFocus(true, true)
end

RegisterNetEvent('f_dealer:openAdmin', function()
    if menuOpen or testing then return end
    menuOpen = 'admin'
    SendNUIMessage({ action = 'open', mode = 'admin' })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('preview', function(d, cb)
    if menuOpen ~= 'shop' or type(d.model) ~= 'string' then return cb(false) end
    lastModel = d.model
    cb(Preview.show(d.model) or false)
end)

RegisterNUICallback('rotate', function(d, cb)
    if menuOpen == 'shop' then Preview.rotate(d.dx, d.dy) end
    cb(1)
end)

RegisterNUICallback('zoom', function(d, cb)
    if menuOpen == 'shop' then Preview.zoom(d.delta) end
    cb(1)
end)

local function afterDelivery(ok, msg, cb)
    cb({ ok = ok, msg = msg })
    if ok then
        closeMenu(true)
        exports.qbx_core:Notify(msg, 'success', 8000)
    end
end

RegisterNUICallback('buy', function(d, cb)
    local ok, msg = lib.callback.await('f_dealer:buy', false, d.model, d.method)
    afterDelivery(ok, msg, cb)
end)

RegisterNUICallback('claim', function(d, cb)
    local ok, msg = lib.callback.await('f_dealer:claim', false, d.model)
    afterDelivery(ok, msg, cb)
end)

RegisterNUICallback('request', function(d, cb)
    local ok, msg = lib.callback.await('f_dealer:request', false, d.model, d.ticket)
    cb({ ok = ok, msg = msg })
end)

---------------------------------------------------------------------------
-- Test drive
---------------------------------------------------------------------------
RegisterNUICallback('testdrive', function(d, cb)
    cb(1)
    if menuOpen ~= 'shop' or testing or type(d.model) ~= 'string' then return end
    lastModel = d.model
    DoScreenFadeOut(300)
    Wait(350)
    closeMenu(true)
    local ok, msg = lib.callback.await('f_dealer:testStart', false, d.model)
    if not ok then
        DoScreenFadeIn(300)
        exports.qbx_core:Notify(msg or 'Test drive gagal', 'error')
        openMenu(d.model)
    end
end)

RegisterNetEvent('f_dealer:testStarted', function(model, seconds)
    testing = { model = model, endsAt = GetGameTimer() + seconds * 1000 }
    SendNUIMessage({ action = 'timer', seconds = seconds })
    CreateThread(function()
        -- tunggu sampai duduk di kendaraan (maks 5 detik) sebelum layar dibuka
        local t = GetGameTimer() + 5000
        while testing and not cache.vehicle and GetGameTimer() < t do Wait(100) end
        DoScreenFadeIn(500)

        local outSince
        local grace = Config.TestDrive.exitGrace * 1000
        while testing do
            Wait(500)
            if not testing then break end
            local out = not cache.vehicle or IsEntityDead(cache.ped)
            if out then
                outSince = outSince or GetGameTimer()
                if GetGameTimer() - outSince >= grace or IsEntityDead(cache.ped) then
                    TriggerServerEvent('f_dealer:testEnd')
                    break
                end
            else
                outSince = nil
            end
        end
    end)
end)

RegisterNetEvent('f_dealer:testFinished', function(model, reason)
    if not testing then return end
    testing = nil
    SendNUIMessage({ action = 'timer', seconds = 0 })
    DoScreenFadeOut(300)
    local back = Config.Ped.coords.xyz
    local t = GetGameTimer() + 4000
    while #(GetEntityCoords(cache.ped) - back) > 15.0 and GetGameTimer() < t do Wait(100) end
    Wait(400)
    if reason ~= 'stop' and not IsEntityDead(cache.ped) then openMenu(model) end
    DoScreenFadeIn(400)
    if reason == 'time' then exports.qbx_core:Notify('Waktu test drive habis', 'inform') end
end)

---------------------------------------------------------------------------
-- Admin (data diambil lewat NUI, semua dicek ulang di server)
---------------------------------------------------------------------------
RegisterNUICallback('admin:data', function(d, cb)
    cb(lib.callback.await('f_dealer:admin:data', false, d.catalog == true) or false)
end)

RegisterNUICallback('admin:save', function(d, cb)
    local ok, msg, list = lib.callback.await('f_dealer:admin:save', false, d.model, d.category, d.price)
    cb({ ok = ok, msg = msg, vehicles = list })
end)

RegisterNUICallback('admin:remove', function(d, cb)
    local ok, msg, list = lib.callback.await('f_dealer:admin:remove', false, d.model)
    cb({ ok = ok, msg = msg, vehicles = list })
end)

RegisterNUICallback('admin:decide', function(d, cb)
    local ok, msg, rows = lib.callback.await('f_dealer:admin:decide', false, d.id, d.approve == true, d.reason)
    cb({ ok = ok, msg = msg, requests = rows })
end)

---------------------------------------------------------------------------
-- NPC + [E] (dicek tiap frame hanya saat pemain dekat)
---------------------------------------------------------------------------
local function spawnPed()
    if ped then return end
    local cfg = Config.Ped
    local model = joaat(cfg.model)
    if not pcall(lib.requestModel, model, 10000) then return end
    ped = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w, false, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end
end

local function removePed()
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    ped = nil
end

lib.points.new({
    coords = Config.Ped.coords.xyz,
    distance = 40.0,
    onEnter = spawnPed,
    onExit = removePed,
})

lib.points.new({
    coords = Config.Ped.coords.xyz,
    distance = Config.Ped.distance + 1.0,
    onExit = hideText,
    nearby = function(point)
        if point.currentDistance > Config.Ped.distance or menuOpen or testing or cache.vehicle then
            return hideText()
        end
        if not shown then
            shown = true
            lib.showTextUI('[E] Beli Kendaraan')
        end
        if IsControlJustReleased(0, 38) then openMenu() end
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    hideText()
    if menuOpen then
        SetNuiFocus(false, false)
        DisplayRadar(true)
    end
    removePed()
    if testing then DoScreenFadeIn(0) end
end)
