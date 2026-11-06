local config = require 'config.server'
local clientConfig = require 'config.client'

-- status kerja per pemain, dicatat server supaya hadiah tidak bisa dipanggil sembarangan
local workers = {}

local MAX_DUTY_DIST = 5.0      -- jarak maksimal ke meja duty
local MAX_PICKUP_DIST = 4.0    -- jarak maksimal ke rak paket
local MAX_DROP_DIST = 4.0      -- jarak maksimal ke titik serah
local MIN_PICKUP_GAP = 3000    -- ms minimal antar ambil paket
local MIN_DELIVERY_TIME = 4000 -- ms minimal dari ambil paket sampai hadiah

local function distTo(src, coords)
    local pos = GetEntityCoords(GetPlayerPed(src))
    return #(pos - vector3(coords.x, coords.y, coords.z))
end

local function flag(src, reason)
    lib.print.warn(('[f_recyclejob] %s (%s) ditolak: %s'):format(GetPlayerName(src), src, reason))
end

RegisterNetEvent('f_recyclejob:server:setDuty', function(state)
    local src = source

    if not state then
        workers[src] = nil
        return
    end

    if distTo(src, clientConfig.dutyLocation) > MAX_DUTY_DIST then
        return flag(src, 'mulai kerja jauh dari meja duty')
    end

    workers[src] = { carrying = false, pickedAt = 0 }
end)

RegisterNetEvent('f_recyclejob:server:pickup', function()
    local src = source
    local worker = workers[src]
    if not worker then return flag(src, 'ambil paket tanpa duty') end

    local now = GetGameTimer()
    if now - worker.pickedAt < MIN_PICKUP_GAP then
        return flag(src, 'ambil paket terlalu cepat')
    end

    local near = false
    for _, loc in pairs(clientConfig.pickupLocations) do
        if distTo(src, loc) <= MAX_PICKUP_DIST then
            near = true
            break
        end
    end
    if not near then return flag(src, 'ambil paket jauh dari rak') end

    worker.carrying = true
    worker.pickedAt = now
end)

RegisterNetEvent('qbx_recycle:server:getItem', function()
    local src = source
    local worker = workers[src]
    if not worker then return flag(src, 'minta hadiah tanpa duty') end
    if not worker.carrying then return flag(src, 'minta hadiah tanpa membawa paket') end
    if GetGameTimer() - worker.pickedAt < MIN_DELIVERY_TIME then
        return flag(src, 'minta hadiah terlalu cepat')
    end
    if distTo(src, clientConfig.dropLocation) > MAX_DROP_DIST then
        return flag(src, 'minta hadiah jauh dari titik serah')
    end

    worker.carrying = false

    for _ = 1, math.random(1, config.maxItemsReceived), 1 do
        local randItem = config.itemTable[math.random(1, #config.itemTable)]
        local amount = math.random(config.minItemReceivedQty, config.maxItemReceivedQty)
        if exports.ox_inventory:CanCarryItem(src, randItem, amount) then
            exports.ox_inventory:AddItem(src, randItem, amount)
            Wait(500)
        else
            exports.qbx_core:Notify(src, locale('error.overweight_check'), 'error')
        end
    end

    local chance = math.random(1, 100)
    if chance < 7 and exports.ox_inventory:Items(config.chanceItem) then
        if exports.ox_inventory:CanCarryItem(src, config.chanceItem, 1) then
            exports.ox_inventory:AddItem(src, config.chanceItem, 1)
        else
            exports.qbx_core:Notify(src, locale('error.overweight_check'), 'error')
        end
    end

    local luck = math.random(1, 10)
    local odd = math.random(1, 10)
    if luck == odd then
        local random = math.random(1, 3)
        if exports.ox_inventory:CanCarryItem(src, config.luckyItem, random) then
            exports.ox_inventory:AddItem(src, config.luckyItem, random)
        else
            exports.qbx_core:Notify(src, locale('error.overweight_check'), 'error')
        end
    end
end)

AddEventHandler('playerDropped', function()
    workers[source] = nil
end)
