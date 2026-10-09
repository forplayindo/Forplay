---------------------------------------------------------------------------
-- Blip di peta: dibuat sekali saat resource start, tanpa thread.
---------------------------------------------------------------------------
local function createBlip(b)
    local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.color)
    SetBlipScale(blip, b.scale + 0.0)
    SetBlipDisplay(blip, 4)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

for _, b in ipairs(Blips or {}) do
    if b.active then createBlip(b) end
end

---------------------------------------------------------------------------
-- Menu admin (NUI)
---------------------------------------------------------------------------
local nuiOpen = false
local previewBlip

local function clearPreview()
    if previewBlip then
        RemoveBlip(previewBlip)
        previewBlip = nil
    end
end

local function closeNui()
    if not nuiOpen then return end
    nuiOpen = false
    clearPreview()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function myPos()
    local c = GetEntityCoords(cache.ped)
    return { x = c.x, y = c.y, z = c.z }
end

RegisterNetEvent('f_blips:client:openAdmin', function()
    if nuiOpen then return end
    local res = lib.callback.await('f_blips:admin:open', false)
    if not res or not res.ok then
        return lib.notify({ type = 'error', description = res and res.msg or 'Gagal membuka menu blips.' })
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

RegisterNUICallback('pos', function(_, cb)
    cb(myPos())
end)

-- Blip uji di minimap admin selama form terbuka, supaya ikon/warna/ukuran asli terlihat.
RegisterNUICallback('preview', function(d, cb)
    clearPreview()
    local c = d and d.coords
    local sprite, color, scale = tonumber(d and d.sprite), tonumber(d and d.color), tonumber(d and d.scale)
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and sprite and color and scale then
        previewBlip = createBlip({
            coords = { x = c.x + 0.0, y = c.y + 0.0, z = (tonumber(c.z) or 0) + 0.0 },
            sprite = math.floor(sprite), color = math.floor(color), scale = scale,
            label = (type(d.label) == 'string' and d.label ~= '') and d.label or 'Pratinjau',
        })
        SetBlipAsShortRange(previewBlip, false)
        SetBlipFlashes(previewBlip, true)
    end
    cb(1)
end)

RegisterNUICallback('clearPreview', function(_, cb)
    clearPreview()
    cb(1)
end)

local function relay(name, ...)
    local res = lib.callback.await('f_blips:admin:' .. name, false, ...) or { ok = false, msg = 'Tidak ada respon server.' }
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
    if nuiOpen then SetNuiFocus(false, false) end
end)
