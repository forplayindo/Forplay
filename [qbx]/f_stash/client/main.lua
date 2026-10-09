local Stashes = {}
local nuiOpen = false
local shownId -- stash yang teks [E]-nya sedang tampil

local function setList(list)
    for i = 1, #list do
        local c = list[i].coords
        list[i].coords = vec3(c.x, c.y, c.z)
    end
    Stashes = list
end

RegisterNetEvent('f_stash:client:sync', function(list)
    setList(list)
end)

local function loadList()
    setList(lib.callback.await('f_stash:getList', false) or {})
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', loadList)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then loadList() end
end)

local function canUse(s)
    if s.gtype == 'public' then return true end
    if s.duty and s.gtype == 'job' then
        local job = QBX.PlayerData.job
        if not job or job.name ~= s.group or not job.onduty then return false end
    end
    return exports.qbx_core:HasGroup({ [s.group] = s.grade })
end

local function hideText()
    if shownId then
        shownId = nil
        lib.hideTextUI()
    end
end

---------------------------------------------------------------------------
-- [E] buka stash
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 750
        local near

        if not nuiOpen and not cache.vehicle and LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(cache.ped)
            local best = Config.Distance
            for i = 1, #Stashes do
                local s = Stashes[i]
                local d = #(pos - s.coords)
                if d < best and canUse(s) then
                    near, best = s, d
                end
            end
        end

        if near then
            sleep = 0
            if shownId ~= near.id then
                shownId = near.id
                lib.showTextUI(('[E] %s'):format(near.label))
            end
            if IsControlJustReleased(0, 38) then
                hideText()
                exports.ox_inventory:openInventory('stash', near.id)
                Wait(500)
            end
        else
            hideText()
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Menu admin (NUI)
---------------------------------------------------------------------------
local function closeNui()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function myPos()
    local c = GetEntityCoords(cache.ped)
    return { x = c.x, y = c.y, z = c.z }
end

RegisterNetEvent('f_stash:client:openAdmin', function()
    if nuiOpen then return end
    local res = lib.callback.await('f_stash:admin:open', false)
    if not res or not res.ok then
        return lib.notify({ type = 'error', description = res and res.msg or 'Gagal membuka menu stash.' })
    end
    nuiOpen = true
    hideText()
    res.pos = myPos()
    SendNUIMessage({ action = 'open', data = res })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb(1)
end)

local function relay(name, ...)
    local res = lib.callback.await('f_stash:admin:' .. name, false, ...) or { ok = false, msg = 'Tidak ada respon server.' }
    res.pos = myPos()
    return res
end

RegisterNUICallback('create', function(d, cb) cb(relay('create', d)) end)
RegisterNUICallback('update', function(d, cb) cb(relay('update', d.id, d)) end)
RegisterNUICallback('move', function(d, cb) cb(relay('move', d.id)) end)
RegisterNUICallback('delete', function(d, cb) cb(relay('delete', d.id)) end)

RegisterNUICallback('teleport', function(d, cb)
    local c = d and d.coords
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
        closeNui()
        SetEntityCoords(cache.ped, c.x + 0.0, c.y + 0.0, c.z - 0.9, false, false, false, false)
    end
    cb(1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hideText()
    if nuiOpen then SetNuiFocus(false, false) end
end)
