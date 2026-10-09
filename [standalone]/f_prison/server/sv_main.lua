local config            = lib.load('configs.server')
local prisonBreakcfg    = lib.load('configs.prisonbreak')
local db                = require 'server.modules.db'
local utils             = require 'server.modules.utils'
local ox_inventory      = exports.ox_inventory
local globalState       = GlobalState
local confiscated       = {}

local function savePlayerJailTime(src)
    local state = Player(src).state
    local jailTime = JailSentence[src] or 0 -- server value, not the client-writable statebag
    local cid = getCharID(src) or state and state.xtprison_identifier
    if not cid then return lib.print.debug('player core identifier not found, not saving jailtime') end
    MySQL.insert.await(db.UPDATE_JAILTIME, { cid, jailTime })

    if confiscated[cid] then
        ox_inventory:ReturnInventory(src)
        confiscated[cid] = nil
    end
end

local function loadPlayerJailTime(src)
    local cid = getCharID(src)
    local getJailTime = MySQL.scalar.await(db.LOAD_JAILTIME, { cid })
    local setTime = setJailTime(src, getJailTime or 0)
    return setTime and getJailTime or 0
end

-- Get Jail Time --
lib.callback.register('xt-prison:server:initJailTime', function(source)
    return loadPlayerJailTime(source)
end)

-- Save Jail Time --
RegisterNetEvent('xt-prison:server:saveJailTime', function()
    local src = source
    savePlayerJailTime(src)
end)

-- Remove Player Job --
lib.callback.register('xt-prison:server:removeJob', function(source)
    if not charHasJob(source, config.UnemployedJobName) then
        if setCharJob(source, config.UnemployedJobName) then
            lib.notify(source, {
                title = locale('notify.lost_job'),
                icon = 'fas fa-ban',
                type = 'error'
            })
            return true
        end
    else
        return true
    end

    return false
end)

-- foreplay: makanan/minuman tidak disita. Dibaca sekali dari ox_inventory/data/items.lua (di server
-- ox_inventory membuang `client`, jadi status hunger/thirst tidak bisa dibaca lewat export).
local keepItems = {}
for name in pairs(config.KeepOnEntry or {}) do keepItems[name] = true end
if config.KeepFoodAndDrink then
    local raw = LoadResourceFile('ox_inventory', 'data/items.lua')
    local chunk = raw and load(raw, '@ox_inventory/data/items.lua', 't', setmetatable({}, { __index = _G }))
    local ok, items = false, nil
    if chunk then ok, items = pcall(chunk) end
    if ok and type(items) == 'table' then
        for name, item in pairs(items) do
            local status = type(item) == 'table' and type(item.client) == 'table' and item.client.status
            if type(status) == 'table' and ((tonumber(status.hunger) or 0) > 0 or (tonumber(status.thirst) or 0) > 0) then
                keepItems[name] = true
            end
        end
    else
        lib.print.warn('Tidak bisa membaca ox_inventory/data/items.lua; makanan/minuman ikut disita kecuali di KeepOnEntry')
    end
end

---@return boolean
local function hasConfiscated(cid)
    local raw = MySQL.scalar.await(db.GET_ITEMS, { cid })
    local items = raw and json.decode(raw)
    return type(items) == 'table' and next(items) ~= nil
end

-- Remove Items on Entry --
RegisterNetEvent('xt-prison:server:removeItems', function()
    local src = source
    local cid = getCharID(src)
    if not cid then return end
    if confiscated[cid] then return end
    if not JailSentence[src] then return end -- hanya tahanan yang benar-benar dipenjara server

    -- sudah ada sitaan tersimpan (login ulang saat masih dipenjara): jangan sita dua kali
    if hasConfiscated(cid) then
        confiscated[cid] = true
        return
    end

    local playerItems = ox_inventory:GetInventoryItems(src)
    local taken = {}
    for _, item in pairs(playerItems or {}) do
        if not keepItems[item.name] then taken[#taken + 1] = item end
    end
    if #taken == 0 then
        confiscated[cid] = true
        return
    end

    -- simpan dulu, baru hapus dari inventory (kalau DB gagal, item tidak hilang)
    local success = MySQL.insert.await(db.CONFISCATE_ITEMS, { cid, json.encode(taken) })
    if not success then return end

    for i = 1, #taken do
        local item = taken[i]
        ox_inventory:RemoveItem(src, item.name, item.count, nil, item.slot)
    end
    confiscated[cid] = true

    lib.notify(src, {
        title = locale('notify.confiscated'),
        icon = 'fas fa-trash',
        type = 'error'
    })
end)

-- Return Items on Exit --
-- foreplay: sumber kebenaran = tabel xt_prison_items, bukan flag di memori. Dulu flag `confiscated`
-- hilang saat logout setelah masa hukuman habis / restart resource, jadi item tidak pernah kembali.
local function returnItems(src)
    local cid = getCharID(src)
    if not cid then return end

    if (JailSentence[src] or 0) > 0 then
        utils.banPlayer(src, cid)
        return
    end

    if not confiscated[cid] and not hasConfiscated(cid) then return end

    local prisonInventory = ox_inventory:GetInventoryItems(src) -- items picked up while jailed
    local rawConfiscated = MySQL.scalar.await(db.GET_ITEMS, { cid })
    local confiscatedItems = rawConfiscated and json.decode(rawConfiscated) or {}

    ox_inventory:ClearInventory(src) -- wipe prison inventory; re-add allowed items

    local failedItems = {}

    if confiscatedItems and next(confiscatedItems) then
        for _, info in pairs(confiscatedItems) do
            local success, response = ox_inventory:AddItem(src, info.name, info.count, info.metadata)
            if not success then
                failedItems[#failedItems + 1] = info
            end
        end
    end

    if #failedItems > 0 then
        MySQL.query.await(db.UPDATE_CONFISCATED_ITEMS, { json.encode(failedItems), cid })

        lib.notify(src, {
            title = locale('notify.return_partial_failure'),
            icon = 'fas fa-triangle-exclamation',
            type = 'error'
        })
    else
        MySQL.query.await(db.CLEAR_CONFISCATED_ITEMS, { cid })

        lib.notify(src, {
            title = locale('notify.returned_items'),
            icon = 'fas fa-hand-holding-heart',
            type = 'success'
        })
    end

    confiscated[cid] = nil

    for _, info in pairs(prisonInventory) do -- Return allowed prison items (+ makanan/minuman)
        if config.AllowedToKeepItems[info.name] or keepItems[info.name] then
            ox_inventory:AddItem(src, info.name, info.count, info.metadata)
        end
    end
end

RegisterNetEvent('xt-prison:server:returnItems', function()
    returnItems(source)
end)

-- foreplay: login dengan masa hukuman 0 tapi masih ada sitaan (logout sebelum checkout / restart
-- resource / item lama yang tertahan) -> client dikeluarkan dari penjara dan item dikembalikan.
lib.callback.register('xt-prison:server:hasConfiscated', function(source)
    local cid = getCharID(source)
    return cid ~= nil and (JailSentence[source] or 0) <= 0 and hasConfiscated(cid)
end)

-- Client confirms the sentence it is entering prison with. The server already set it (MDT booking
-- through exports.JailPlayer, or the saved time on login); a client can never choose its own time.
lib.callback.register('xt-prison:server:setJailStatus', function(source, setTime)
    return (JailSentence[source] or 0) == tonumber(setTime)
end)

-- Check if Player is a Lifer --
lib.callback.register('xt-prison:server:liferCheck', function(source)
    return utils.liferCheck(source)
end)

-- Receive Canteen Meal --
lib.callback.register('xt-prison:server:receiveCanteenMeal', function(source)
    local food = config.CanteenMeal.food
    local drink = config.CanteenMeal.drink
    if ox_inventory:AddItem(source, food.item, food.count) and ox_inventory:AddItem(source, drink.item, drink.count) then
        return true
    end
    return false
end)

-- Checks Time Left --
local lastTimeCheck = {}

local function initTimeCheck(source)
    lastTimeCheck[source] = lib.timer(5000, function()
        lastTimeCheck[source] = nil
    end, true)
end

lib.callback.register('xt-prison:server:checkJailTime', function(source)
    if lastTimeCheck[source] then
        lib.notify(source, {
            title = locale('notify.wait_before_check'),
            icon = 'fas fa-hourglass-half',
            type = 'error'
        })
        return
    end

    initTimeCheck(source) -- init timer

    return utils.checkJailTime(source)
end)

-- Constantly Update Cop Count --
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if prisonBreakcfg.MinimumPolice == 0 then
        globalState.copCount = 0
        return
    end

    SetInterval(function()
        local players = GetPlayers()
        local count = 0

        for _, src in pairs(players) do
            src = src and tonumber(src) or false
            local player = src and getPlayer(src) or false
            if player then
                if charHasJob(src, config.policeJobs) then
                    count += 1
                end
            end
        end

        if globalState.copCount ~= count then
            globalState.copCount = count
        end
    end, 120000)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    savePlayerJailTime(src)
    JailSentence[src] = nil
end)
