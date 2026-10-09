local config = require 'config.server'
local sharedConfig = require 'config.shared'

-- Server-authoritative delivery record: the client only ever gets to pick
-- WHICH delivery it wants to start (item/amount/payout look-up happens here,
-- not client-side), and successDelivery always pays out based on this, never
-- on whatever the client sends back. This also means a delivery can only be
-- claimed once - the record is cleared the moment successDelivery runs.
local activeDeliveries = {} ---@type table<integer, {item: string, itemName: string, amount: integer, payout: number, deadline: integer}>
local DELIVERY_TIME_LIMIT_MS = 300000 -- matches the client's 300s countdown

local function pickDeliveryItem(rep)
    local available = {}
    for k, v in pairs(sharedConfig.deliveryItems) do
        if v.minrep <= rep then
            available[#available + 1] = k
        end
    end
    if #available == 0 then return nil end
    return available[math.random(1, #available)]
end

exports('GetDealers', function()
    return sharedConfig.dealers
end)

lib.callback.register('qb-drugs:server:RequestConfig', function()
    return sharedConfig.dealers
end)

RegisterNetEvent('qb-drugs:server:randomPoliceAlert', function()
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    if config.policeCallChance >= math.random(1, 100) then
        TriggerEvent('police:server:policeAlert', locale('info.possible_drug_dealing'), nil, player.PlayerData.source)
    end
end)

RegisterNetEvent('qb-drugs:server:updateDealerItems', function(itemData, amount, dealer)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player then return end
    if not dealer or not sharedConfig.dealers[dealer] then return end
    if not itemData or not itemData.slot or not sharedConfig.dealers[dealer].products[itemData.slot] then return end

    local product = sharedConfig.dealers[dealer].products[itemData.slot]
    -- this only keeps the dealer's displayed stock in sync across clients -
    -- ox_inventory's own shop system already handles the actual purchase and
    -- payment, so this handler never touches money or items on its own.
    local clampedAmount = math.max(0, math.min(tonumber(amount) or 0, product.amount))
    product.amount = math.max(0, product.amount - clampedAmount)
    TriggerClientEvent('qb-drugs:client:setDealerItems', -1, itemData, clampedAmount, dealer)
end)

RegisterNetEvent('qb-drugs:server:giveDeliveryItems', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)

    if not player then return end
    if activeDeliveries[src] then return end -- already has one pending

    local rep = player.PlayerData.metadata.dealerrep
    local itemKey = pickDeliveryItem(rep)
    if not itemKey then return end

    local itemData = sharedConfig.deliveryItems[itemKey]
    local amount = math.random(1, 3)

    activeDeliveries[src] = {
        item = itemKey,
        itemName = itemData.item,
        amount = amount,
        payout = itemData.payout * amount,
        deadline = GetGameTimer() + DELIVERY_TIME_LIMIT_MS,
    }

    exports.ox_inventory:AddItem(src, itemData.item, amount)
end)

RegisterNetEvent('qb-drugs:server:successDelivery', function(deliveryData)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local delivery = activeDeliveries[src]

    if not player or not delivery then return end
    activeDeliveries[src] = nil -- one claim per delivery, no matter the outcome

    local item = delivery.itemName
    local itemAmount = delivery.amount
    local payout = delivery.payout
    local inTime = GetGameTimer() <= delivery.deadline
    local copsOnline = exports.qbx_core:GetDutyCountType('leo')
    local curRep = player.PlayerData.metadata.dealerrep
    local invItem = exports.ox_inventory:Search(src, 'count', item)

    if inTime then
        if invItem and invItem.amount >= itemAmount then -- on time correct amount
            exports.ox_inventory:RemoveItem(src, item, itemAmount)
            -- f_dirtymoney: hasil antar narkoba = cash kotor (markedbills tidak dipakai)
            if copsOnline > 0 then
                local copModifier = copsOnline * config.policeDeliveryModifier
                exports.f_dirtymoney:AddDirtyCash(src, math.floor(payout * copModifier), 'drug-delivery')
            else
                exports.f_dirtymoney:AddDirtyCash(src, payout, 'drug-delivery')
            end
            exports.qbx_core:Notify(src, locale('success.order_delivered'), 'success')
            SetTimeout(math.random(5000, 10000), function()
                TriggerClientEvent('qb-drugs:client:sendDeliveryMail', src, 'perfect', deliveryData)
                player.Functions.SetMetaData('dealerrep', (curRep + config.deliveryRepGain))
            end)
        else
            exports.qbx_core:Notify(src, locale('error.order_not_right'), 'error')-- on time incorrect amount
            if invItem then
                local newItemAmount = invItem.amount
                local modifiedPayout = delivery.payout / itemAmount * newItemAmount
                exports.ox_inventory:RemoveItem(src, item, newItemAmount)
                exports.f_dirtymoney:AddDirtyCash(src, math.floor(modifiedPayout / config.wrongAmountFee), 'drug-delivery')
            end
            SetTimeout(math.random(5000, 10000), function()
                TriggerClientEvent('qb-drugs:client:sendDeliveryMail', src, 'bad', deliveryData)
                if curRep - 1 > 0 then
                    player.Functions.SetMetaData('dealerrep', (curRep - config.deliveryRepLoss))
                else
                    player.Functions.SetMetaData('dealerrep', 0)
                end
            end)
        end
    else
        if invItem and invItem.amount >= itemAmount then -- late correct amount
            exports.qbx_core:Notify(src, locale('error.too_late'), 'error')
            exports.ox_inventory:RemoveItem(src, item, itemAmount)
            exports.f_dirtymoney:AddDirtyCash(src, math.floor(payout / config.overdueDeliveryFee), 'delivery-drugs-too-late')
            SetTimeout(math.random(5000, 10000), function()
                TriggerClientEvent('qb-drugs:client:sendDeliveryMail', src, 'late', deliveryData)
                if curRep - 1 > 0 then
                    player.Functions.SetMetaData('dealerrep', (curRep - config.deliveryRepLoss))
                else
                    player.Functions.SetMetaData('dealerrep', 0)
                end
            end)
        else
            if invItem then -- late incorrect amount
                local newItemAmount = invItem.amount
                local modifiedPayout = delivery.payout / itemAmount * newItemAmount
                exports.qbx_core:Notify(src, locale('error.too_late'), 'error')
                exports.ox_inventory:RemoveItem(src, item, newItemAmount)
                exports.f_dirtymoney:AddDirtyCash(src, math.floor(modifiedPayout / config.overdueDeliveryFee), 'delivery-drugs-too-late')
                SetTimeout(math.random(5000, 10000), function()
                    TriggerClientEvent('qb-drugs:client:sendDeliveryMail', src, 'late', deliveryData)
                    if curRep - 1 > 0 then
                        player.Functions.SetMetaData('dealerrep', (curRep - config.deliveryRepLoss))
                    else
                        player.Functions.SetMetaData('dealerrep', 0)
                    end
                end)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    activeDeliveries[source] = nil
end)


lib.addCommand('newdealer', {
    help = locale('info.newdealer_command_desc'),
    params = {
        {
            name = 'name',
            type = 'string',
            help = locale('info.newdealer_command_help1_help'),
            optional = false
        },
        {
            name = 'min',
            type = 'number',
            help = locale('info.newdealer_command_help2_help'),
            optional = false
        },
        {
            name = 'max',
            type = 'number',
            help = locale('info.newdealer_command_help3_help'),
            optional = false
        }
    },
    restricted = 'group.admin'
}, function(source, args)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end
    local dealerName = args.name
    local minTime = args.min
    local maxTime = args.max
    local time = json.encode({min = minTime, max = maxTime})
    local pos = json.encode({x = coords.x, y = coords.y, z = coords.z})
    local result = MySQL.scalar.await('SELECT name FROM dealers WHERE name = ?', {dealerName})
    if result then return exports.qbx_core:Notify(source, locale('error.dealer_already_exists'), 'error') end
    MySQL.insert('INSERT INTO dealers (name, coords, time, createdby) VALUES (?, ?, ?, ?)', {dealerName, pos, time, player.PlayerData.citizenid}, function()
        sharedConfig.dealers[dealerName] = {
            name = dealerName,
            coords = vec3(coords.x, coords.y, coords.z),
            time = { min = minTime, max = maxTime },
            products = config.products
        }
        TriggerClientEvent('qb-drugs:client:RefreshDealers', -1, sharedConfig.dealers)
    end)
end)

lib.addCommand('deletedealer', {
    help = locale('info.newdealer_command_desc'),
    params = {
        {
            name = 'name',
            type = 'string',
            help = locale('info.deletedealer_command_help1_help'),
            optional = false
        },
    },
    restricted = 'group.admin'
}, function(source, args)
    local dealerName = args.name
    local result = MySQL.scalar.await('SELECT * FROM dealers WHERE name = ?', {dealerName})
    if result then
        MySQL.query('DELETE FROM dealers WHERE name = ?', {dealerName})
        sharedConfig.dealers[dealerName] = nil
        TriggerClientEvent('qb-drugs:client:RefreshDealers', -1, sharedConfig.dealers)
        exports.qbx_core:Notify(source, locale('success.dealer_deleted', dealerName), 'success')
    else
        exports.qbx_core:Notify(source, locale('error.dealer_not_exists_command', dealerName), 'error')
    end
end)

lib.addCommand('dealers', {
    help = 'Lihat daftar dealer',
    restricted = 'group.admin'
}, function(source)
    local dealersText = ''
    if sharedConfig.dealers ~= nil and next(sharedConfig.dealers) ~= nil then
        for _, v in pairs(sharedConfig.dealers) do
            dealersText = dealersText .. locale('info.list_dealers_name_prefix') .. v.name .. '<br>'
        end
        TriggerClientEvent('chat:addMessage', source, {
            color = { 0, 0, 255 },
            template = "<div class='chat-message advert'><div class='chat-message-body'><strong>' .. locale('info.list_dealers_title') .. '</strong><br><br> ' .. dealersText .. '</div></div>",
            args = {}
        })
    else
        exports.qbx_core:Notify(source, locale('error.no_dealers'), 'error')
    end
end)

lib.addCommand('dealergoto', {
    help = 'To teleport to dealer',
    params = {
        {
            name = 'name',
            type = 'string',
            help = locale('info.dealergoto_command_help1_help'),
            optional = false
        },
    },
    restricted = 'group.admin'
}, function(source, args)
    local dealerName = args.name
    if sharedConfig.dealers[dealerName] then
        local ped = GetPlayerPed(source)
        SetEntityCoords(ped, sharedConfig.dealers[dealerName].coords.x, sharedConfig.dealers[dealerName].coords.y, sharedConfig.dealers[dealerName].coords.z, false, false, false, false)
        exports.qbx_core:Notify(source, locale('success.teleported_to_dealer', dealerName), 'success')
    else
        exports.qbx_core:Notify(source, locale('error.dealer_not_exists'), 'error')
    end
end)


CreateThread(function()
    Wait(500)
    local dealers = MySQL.query.await('SELECT * FROM dealers')
    if dealers and #dealers ~= 0 then
        for i = 1, #dealers do
            local data = dealers[i]
            local coords = json.decode(data.coords)
            local time = json.decode(data.time)

            sharedConfig.dealers[data.name] = {
                name = data.name,
                coords = vec3(coords.x, coords.y, coords.z),
                time = { min = time.min, max = time.max },
                products = config.products
            }
        end
    end
    TriggerClientEvent('qb-drugs:client:RefreshDealers', -1, sharedConfig.dealers)
end)