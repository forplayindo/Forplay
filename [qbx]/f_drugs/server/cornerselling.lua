local config = require 'config.server'

-- Server-authoritative offer storage. The client is never trusted to send
-- back the item/amount/price it was quoted - the server remembers what it
-- actually offered and only ever pays out or removes items based on that.
local pendingOffers = {} ---@type table<integer, {item: string, idx: integer, amount: integer, total: number, expiry: integer}>
local pendingSteals = {} ---@type table<integer, {item: string, idx: integer, amount: integer}>

local OFFER_TTL_MS = 60000

local function getAvailableDrugs(source)
    local availableDrugs = {}
    local player = exports.qbx_core:GetPlayer(source)

    if not player then return nil end

    for i = 1, #config.cornerSellingDrugsList do
        local itemName = config.cornerSellingDrugsList[i]
        local itemCount = exports.ox_inventory:Search(source, 'count', itemName)
        if itemCount > 0 then
            availableDrugs[#availableDrugs + 1] = {
                item = itemName,
                amount = itemCount,
                label = exports.ox_inventory:Items()[itemName].label
            }
        end
    end
    return table.type(availableDrugs) ~= 'empty' and availableDrugs or nil
end

lib.callback.register('qb-drugs:server:getDrugOffer', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local availableDrugs = getAvailableDrugs(player.PlayerData.source)
    if availableDrugs == nil then return nil end

    local randomDrug = math.random(1, #availableDrugs)
    local chosenDrug = availableDrugs[randomDrug]
    local offeredAmount = math.random(1, chosenDrug.amount > 15 and 15 or chosenDrug.amount)
    local basePrice = math.random(config.cornerSellingDrugsPrice[chosenDrug.item].min, config.cornerSellingDrugsPrice[chosenDrug.item].max)
    -- scamChance % pembeli menawar jauh di bawah harga pasar (sebelumnya terbalik: 75% penawaran murah)
    local isScam = config.scamChance >= math.random(1, 100)
    local totalPrice = isScam and math.random(10000, 35000) * offeredAmount or basePrice * offeredAmount

    -- remember exactly what was offered - sellCornerDrugs/robCornerDrugs will
    -- only ever pay out or remove items based on this, never on what the
    -- client sends back
    pendingOffers[source] = {
        item = chosenDrug.item,
        idx = randomDrug,
        amount = offeredAmount,
        total = totalPrice,
        expiry = GetGameTimer() + OFFER_TTL_MS,
    }

    return { chosen = chosenDrug, idx = randomDrug, amount = offeredAmount, total = totalPrice }
end)

RegisterNetEvent('qb-drugs:server:giveStealItems', function()
    local steal = pendingSteals[source]
    local player = exports.qbx_core:GetPlayer(source)
    if not steal or not player then return end

    pendingSteals[source] = nil
    exports.ox_inventory:AddItem(player.PlayerData.source, steal.item, steal.amount)
end)

RegisterNetEvent('qb-drugs:server:sellCornerDrugs', function()
    local player = exports.qbx_core:GetPlayer(source)
    local offer = pendingOffers[source]
    if not player or not offer then return end

    if GetGameTimer() > offer.expiry then
        pendingOffers[source] = nil
        return
    end

    local hasItem = player.Functions.GetItemByName(offer.item)
    if hasItem and hasItem.amount >= offer.amount then
        pendingOffers[source] = nil
        exports.qbx_core:Notify(player.PlayerData.source, locale('success.offer_accepted'), 'success')
        exports.ox_inventory:RemoveItem(player.PlayerData.source, offer.item, offer.amount)
        exports.f_dirtymoney:AddDirtyCash(player.PlayerData.source, offer.total, 'sold-cornerdrugs')
        -- rep wilayah gang (f_crew mencari zonanya dari posisi pemain di server)
        if GetResourceState('f_crew') == 'started' then
            local src = player.PlayerData.source
            pcall(function() exports.f_crew:AddTurfActivity(src, 'drugselling') end)
        end
        if config.policeCallChance >= math.random(1, 100) then
            TriggerEvent('police:server:policeAlert', locale('info.possible_drug_dealing'), nil, player.PlayerData.source)
        end
    else
        TriggerClientEvent('qb-drugs:client:cornerselling', player.PlayerData.source)
    end
end)

RegisterNetEvent('qb-drugs:server:robCornerDrugs', function()
    local player = exports.qbx_core:GetPlayer(source)
    local offer = pendingOffers[source]
    if not player or not offer then return end

    pendingOffers[source] = nil
    if GetGameTimer() > offer.expiry then return end

    exports.ox_inventory:RemoveItem(player.PlayerData.source, offer.item, offer.amount)
    -- the ped that robbed the player "carries" the stolen goods until the
    -- player kills it and picks them back up via giveStealItems
    pendingSteals[source] = { item = offer.item, idx = offer.idx, amount = offer.amount }
end)

AddEventHandler('playerDropped', function()
    pendingOffers[source] = nil
    pendingSteals[source] = nil
end)
