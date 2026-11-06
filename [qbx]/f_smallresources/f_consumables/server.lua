local config = require 'f_consumables.config'

---Sets a status through player metadata. SetMetaData writes the metadata before the statebag,
---which is what qbx_core's statebag guard treats as a server-side (trusted) change.
---@param source number
---@param key 'hunger' | 'thirst' | 'stress'
---@param amount number
local function setStatus(source, key, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    player.Functions.SetMetaData(key, lib.math.clamp(amount, 0, 100))
end

---Increments a status from its authoritative metadata value.
---@param source number
---@param key 'hunger' | 'thirst' | 'stress'
---@param amount number
local function addStatus(source, key, amount)
    -- stress lives in the statebag (f_hud stress module), metadata can lag behind it
    if key == 'stress' and GetResourceState('f_hud') == 'started' then
        local ok = pcall(function()
            if amount < 0 then exports.f_hud:RelieveStress(source, -amount) else exports.f_hud:AddStress(source, amount) end
        end)
        if ok then return end
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    setStatus(source, key, (player.PlayerData.metadata[key] or 0) + amount)
end

---Set player's hunger state to 'amount'
---@param source number
---@param amount number inverted, lower == more hungry
local function setHunger(source, amount) setStatus(source, 'hunger', amount) end

---Increment player's hunger state by 'amount'
---@param source number
---@param amount number inverted, lower == more hungry
local function addHunger(source, amount) addStatus(source, 'hunger', amount) end

---Set player's thirst state to 'amount'
---@param source number
---@param amount number inverted, lower == more thirsty
local function setThirst(source, amount) setStatus(source, 'thirst', amount) end

---Increment player's thirst state by 'amount'
---@param source number
---@param amount number inverted, lower == more thirsty
local function addThirst(source, amount) addStatus(source, 'thirst', amount) end

---------------------------------------------------------------------------
-- Status for ox_inventory items (client.status in ox_inventory/data/items.lua).
-- ox_inventory drops item client data on the server and its qbx bridge used to add the status
-- from the client. The status is now applied here, after the server confirms the item was used.
---------------------------------------------------------------------------
local STATUS_KEYS = { hunger = true, thirst = true, stress = true }
local itemStatus = {}
local statusHandler

---Reads client.status of every item from ox_inventory's item file.
---@return table<string, table<string, number>>
local function loadItemStatus()
    local file = LoadResourceFile('ox_inventory', 'data/items.lua')
    if not file then return {} end

    local chunk, err = load(file, '@@ox_inventory/data/items.lua')
    if not chunk then
        lib.print.error(err)
        return {}
    end

    local ok, items = pcall(chunk)
    if not ok or type(items) ~= 'table' then return {} end

    local list = {}
    for name, data in pairs(items) do
        local status = type(data) == 'table' and type(data.client) == 'table' and data.client.status
        if type(status) == 'table' then
            local values = {}
            for key, value in pairs(status) do
                if STATUS_KEYS[key] and type(value) == 'number' then
                    -- same ESX-scale conversion as ox_inventory's qbx bridge
                    if value > 100 or value < -100 then value = value * 0.0001 end
                    values[key] = value
                end
            end
            if next(values) then list[name] = values end
        end
    end
    return list
end

local function registerStatusHook()
    if statusHandler then
        RemoveEventHandler(statusHandler)
        statusHandler = nil
    end

    itemStatus = loadItemStatus()
    local filter = {}
    for name in pairs(itemStatus) do filter[name] = true end
    if not next(filter) then return end

    local hookId = exports.ox_inventory:registerHook('usingItem', function() return true end, { itemFilter = filter })

    -- ox_inventory fires the hook id as an event once the use finished; success is false when cancelled
    statusHandler = AddEventHandler(hookId, function(success, payload)
        if not success or type(payload) ~= 'table' then return end
        local item = type(payload.item) == 'table' and payload.item.name
        local status = item and itemStatus[item]
        if not status then return end

        for key, value in pairs(status) do addStatus(payload.source, key, value) end
    end)
end

CreateThread(registerStatusHook)

---Status an item gives when used, e.g. { hunger = 15, stress = -2 } (for menus/shops).
---@param item string
---@return table<string, number>?
exports('GetItemStatus', function(item) return itemStatus[item] end)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_inventory' then SetTimeout(1000, registerStatusHook) end
end)

---Relieve a random amount of stress from the player's state
---@param source number
---@param min number lower limit for random generation
---@param max number upper limit for rancom generation
local function relieveStress(source, min, max)
    local playerState = Player(source).state
    local verifiedMin = (type(min) == "number" and min) or config.defaultStressRelief.min
    local verifiedMax = max or config.defaultStressRelief.max
    local amount = math.random(verifiedMin, verifiedMax)
    local newStress = (playerState.stress or 0) - amount
    newStress = lib.math.clamp(newStress, 0, 100)

    playerState:set("stress", newStress, true)
    if amount < 0 then
        exports.qbx_core:Notify(source, locale('error.stress_gain'), 'inform', 2500, nil, nil, { '#141517', '#ffffff' }, 'brain', '#C53030')
    else
        exports.qbx_core:Notify(source, locale('success.stress_relief'), 'inform', 2500, nil, nil, { '#141517', '#ffffff' }, 'brain', '#0F52BA')
    end
end

for alcohol, params in pairs(config.consumables.alcohol) do
    exports.qbx_core:CreateUseableItem(alcohol, function(source, item)
        local drank = lib.callback.await('consumables:client:DrinkAlcohol', source, params.alcoholLevel, params.anim, params.prop)
        if not drank then return end
        if not exports.ox_inventory:RemoveItem(source, item.name, 1, nil, item.slot) then return end

        local sustenance = math.random(params.min, params.max)
        relieveStress(source, params.stressRelief.min, params.stressRelief.max)

        addThirst(source, sustenance)
    end)
end

for drink, params in pairs(config.consumables.drink) do
    exports.qbx_core:CreateUseableItem(drink, function(source, item)
        local drank = lib.callback.await('consumables:client:Drink', source, params.anim, params.prop)
        if not drank then return end
        if not exports.ox_inventory:RemoveItem(source, item.name, 1, nil, item.slot) then return end

        local sustenance = math.random(params.min, params.max)
        relieveStress(source, params.stressRelief.min, params.stressRelief.max)

        addThirst(source, sustenance)
    end)
end

for food, params in pairs(config.consumables.food) do
    exports.qbx_core:CreateUseableItem(food, function(source, item)
        local ate = lib.callback.await('consumables:client:Eat', source, params.anim, params.prop)
        if not ate then return end
        if not exports.ox_inventory:RemoveItem(source, item.name, 1, nil, item.slot) then return end

        local sustenance = math.random(params.min, params.max)
        relieveStress(source, params.stressRelief.min, params.stressRelief.max)

        addHunger(source, sustenance)
    end)
end

exports.qbx_core:CreateUseableItem('joint', function(source)
    TriggerClientEvent('consumables:client:UseJoint', source)
end)

exports.qbx_core:CreateUseableItem('cokebaggy', function(source)
    TriggerClientEvent('consumables:client:Cokebaggy', source)
end)

exports.qbx_core:CreateUseableItem('crack_baggy', function(source)
    TriggerClientEvent('consumables:client:Crackbaggy', source)
end)

exports.qbx_core:CreateUseableItem('xtcbaggy', function(source)
    TriggerClientEvent('consumables:client:EcstasyBaggy', source)
end)

exports.qbx_core:CreateUseableItem('oxy', function(source)
    TriggerClientEvent('consumables:client:oxy', source)
end)

exports.qbx_core:CreateUseableItem('meth', function(source)
    TriggerClientEvent('consumables:client:meth', source)
end)

exports.qbx_core:CreateUseableItem('lockpick', function(source)
    TriggerClientEvent('lockpicks:UseLockpick', source, false)
    TriggerEvent('lockpicks:UseLockpick', source, false)
end)

exports.qbx_core:CreateUseableItem('advancedlockpick', function(source)
    TriggerClientEvent('lockpicks:UseLockpick', source, true)
    TriggerEvent('lockpicks:UseLockpick', source, true)
end)

lib.callback.register('consumables:server:usedItem', function(source, item)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    return exports.ox_inventory:RemoveItem(source, item, 1)
end)

-- consumables:server:set/addHunger and set/addThirst net events were removed: any client could
-- trigger them to fill its own bars. Hunger/thirst now only change server-side (exports below).

---@deprecated use SetHunger instead
exports('setHunger', setHunger)
---@deprecated use AddHunger instead
exports('addHunger', addHunger)
---@deprecated use SetThirst instead
exports('setThirst', setThirst)
---@deprecated use AddThirst instead
exports('addThirst', addThirst)

exports('SetHunger', setHunger)
exports('AddHunger', addHunger)
exports('SetThirst', setThirst)
exports('AddThirst', addThirst)
