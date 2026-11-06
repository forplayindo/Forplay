--[[
 ______     __         ______     ______     __   __     ______     _____        ______     __  __        __  __     ______     __   __   __     __   __    
/\  ___\   /\ \       /\  ___\   /\  __ \   /\ "-.\ \   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \/ /    /\  ___\   /\ \ / /  /\ \   /\ "-.\ \   
\ \ \____  \ \ \____  \ \  __\   \ \  __ \  \ \ \-.  \  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  _"-.  \ \  __\   \ \ \'/   \ \ \  \ \ \-.  \  
 \ \_____\  \ \_____\  \ \_____\  \ \_\ \_\  \ \_\\"\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_____\  \ \__|    \ \_\  \ \_\\"\_\ 
  \/_____/   \/_____/   \/_____/   \/_/\/_/   \/_/ \/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_____/   \/_/      \/_/   \/_/ \/_/ 
 ______   __     __  __     ______     _____        ______     __  __        __  __     ______     ______     __     __    __        __  __     ______     ______     ______     ______     ______     ______    
/\  ___\ /\ \   /\_\_\_\   /\  ___\   /\  __-.     /\  == \   /\ \_\ \      /\ \_\ \   /\  __ \   /\___  \   /\ \   /\ "-./  \      /\ \_\ \   /\  ___\   /\  == \   /\  == \   /\  ___\   /\  == \   /\  __ \   
\ \  __\ \ \ \  \/_/\_\/_  \ \  __\   \ \ \/\ \    \ \  __<   \ \____ \     \ \  __ \  \ \  __ \  \/_/  /__  \ \ \  \ \ \-./\ \     \ \  __ \  \ \  __\   \ \  __<   \ \  __<   \ \  __\   \ \  __<   \ \  __ \  
 \ \_\    \ \_\   /\_\/\_\  \ \_____\  \ \____-     \ \_____\  \/\_____\     \ \_\ \_\  \ \_\ \_\   /\_____\  \ \_\  \ \_\ \ \_\     \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\  \ \_____\  \ \_\ \_\  \ \_\ \_\ 
  \/_/     \/_/   \/_/\/_/   \/_____/   \/____/      \/_____/   \/_____/      \/_/\/_/   \/_/\/_/   \/_____/   \/_/   \/_/  \/_/      \/_/\/_/   \/_____/   \/_/ /_/   \/_/ /_/   \/_____/   \/_/ /_/   \/_/\/_/ 
                                                                                                                                                                    
]]

-- Server inventory operations shared by all gameplay handlers.
local inventory = Config.Inventory
assert(inventory == 'ox_inventory' or inventory == 'qb' or inventory == 'qb-inventory' or inventory == 'esx',
    'electus_pets: server inventory supports ox_inventory, qb, qb-inventory or esx')
assert(inventory ~= 'esx' or Config.Framework == 'esx', 'electus_pets: esx inventory requires ESX')
assert(inventory ~= 'qb' or Config.Framework == 'qb', 'electus_pets: qb inventory requires QBCore; use ox_inventory for Qbox')
if inventory == 'ox_inventory' or inventory == 'qb-inventory' then
    assert(GetResourceState(inventory) == 'started', 'electus_pets: start the configured inventory first: ' .. inventory)
end

function EP.itemCount(src, item)
    if type(item) ~= 'string' then return 0 end
    if inventory == 'ox_inventory' then return exports.ox_inventory:Search(src, 'count', item) or 0 end
    if inventory == 'qb-inventory' then
        local entry = exports['qb-inventory']:GetItemByName(src, item)
        return entry and entry.amount or 0
    end
    local player = EP.player(src)
    if not player then return 0 end
    local entry
    if inventory == 'esx' then entry = player.getInventoryItem(item) else entry = player.Functions.GetItemByName(item) end
    return entry and (entry.count or entry.amount) or 0
end

function EP.addItem(src, item, count)
    if inventory == 'ox_inventory' then return exports.ox_inventory:AddItem(src, item, count) end
    if inventory == 'qb-inventory' then return exports['qb-inventory']:AddItem(src, item, count, false, false, 'electus-pets') end
    local player = EP.player(src)
    if not player then return false end
    if inventory == 'esx' then
        if player.canCarryItem and not player.canCarryItem(item, count) then return false end
        player.addInventoryItem(item, count)
        return true
    end
    return player.Functions.AddItem(item, count)
end

function EP.removeItem(src, item, count)
    if EP.itemCount(src, item) < count then return false end
    if inventory == 'ox_inventory' then return exports.ox_inventory:RemoveItem(src, item, count) end
    if inventory == 'qb-inventory' then return exports['qb-inventory']:RemoveItem(src, item, count, false, 'electus-pets') end
    local player = EP.player(src)
    if inventory == 'esx' then player.removeInventoryItem(item, count); return true end
    return player.Functions.RemoveItem(item, count)
end

function EP.itemLabel(item)
    if type(item) ~= 'string' then return '' end
    if inventory == 'ox_inventory' then
        local entry = exports.ox_inventory:Items(item)
        return entry and entry.label or item
    end
    if EP.ESX then return EP.ESX.GetItemLabel(item) or item end
    if EP.QBCore then
        local entry = EP.QBCore.Shared.Items[item]
        return entry and entry.label or item
    end
    return item
end
