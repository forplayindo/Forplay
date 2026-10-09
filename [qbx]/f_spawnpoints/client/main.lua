local nuiOpen = false

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

RegisterNetEvent('f_spawnpoints:client:openAdmin', function()
    if nuiOpen then return end
    local res = lib.callback.await('f_spawnpoints:admin:open', false)
    if not res or not res.ok then
        return lib.notify({ type = 'error', description = res and res.msg or 'Gagal membuka menu.' })
    end
    nuiOpen = true
    res.pos = myPos()
    SendNUIMessage({ action = 'open', data = res })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb(1)
end)

local function relay(name, ...)
    local res = lib.callback.await('f_spawnpoints:admin:' .. name, false, ...) or { ok = false, msg = 'Tidak ada respon server.' }
    res.pos = myPos()
    return res
end

RegisterNUICallback('create', function(d, cb) cb(relay('create', d)) end)
RegisterNUICallback('rename', function(d, cb) cb(relay('rename', d.id, d)) end)
RegisterNUICallback('move', function(d, cb) cb(relay('move', d.id)) end)
RegisterNUICallback('give', function(d, cb) cb(relay('give', d.id, d.target)) end)
RegisterNUICallback('revoke', function(d, cb) cb(relay('revoke', d.id)) end)
RegisterNUICallback('delete', function(d, cb) cb(relay('delete', d.id)) end)

RegisterNUICallback('teleport', function(d, cb)
    local c = d and d.coords
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
        closeNui()
        SetEntityCoords(cache.ped, c.x + 0.0, c.y + 0.0, c.z - 0.9, false, false, false, false)
        SetEntityHeading(cache.ped, (tonumber(c.w) or 0.0) + 0.0)
    end
    cb(1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if nuiOpen then SetNuiFocus(false, false) end
end)
