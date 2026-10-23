OrderHelpers = {}

local RarityCache = {}

function OrderHelpers.GetRarityForReference(refNumber, modId, modIndex)
    if Data.RarityOverrides and Data.RarityOverrides[refNumber] then
        return Data.RarityOverrides[refNumber]
    end
    
    if Data.Rarity[modId] then
        local arrayIndex = modIndex  -- +1 for 1-based, +1 to skip stock (-1)
        
        if arrayIndex > 0 and arrayIndex <= #Data.Rarity[modId] then
            return Data.Rarity[modId][arrayIndex]
        end
    end
    
    return 'common'
end

function OrderHelpers.CheckReferenceAvailability(refNumber, modId, modIndex)
    if RarityCache[refNumber] ~= nil then
        return RarityCache[refNumber]
    end
    
    local rarity = OrderHelpers.GetRarityForReference(refNumber, modId, modIndex)
    
    local chance = Config.Rarity.availabilityChance[rarity] or 0.80
    
    local isAvailable = math.random() <= chance
    
    RarityCache[refNumber] = isAvailable
    
    return isAvailable
end

function OrderHelpers.ClearRarityCache()
    RarityCache = {}
end

OrderHelpers.Suppliers = {
    UB = {
        code = "UB",
        name = "UrbanBody Shop",
        fullName = "UrbanBody Shop – Cosmetics & Styling"
    },
    GL = {
        code = "GL",
        name = "GripLine Wheels",
        fullName = "GripLine Wheels – Tires, Wheels & Stance"
    },
    RL = {
        code = "RL",
        name = "Redline Tuning",
        fullName = "Redline Tuning – Performance & Maintenance"
    },
    MS = {
        code = "MS",
        name = "MechSupply",
        fullName = "MechSupply – Professional Mechanic Supplies"
    }
}

function OrderHelpers.GetSupplierNameFromCode(supplierCode)
    if OrderHelpers.Suppliers[supplierCode] then
        return OrderHelpers.Suppliers[supplierCode].name
    end
    return t('unknown_supplier')
end

function OrderHelpers.GetSupplierFullNameFromCode(supplierCode)
    if OrderHelpers.Suppliers[supplierCode] then
        return OrderHelpers.Suppliers[supplierCode].fullName
    end
    return t('unknown_supplier')
end

function OrderHelpers.GetSupplierCodeFromModId(modId)
    if modId == 0 or modId == 1 or modId == 2 or modId == 3 or modId == 4 or 
        modId == 5 or modId == 6 or modId == 7 or modId == 8 or modId == 9 or 
        modId == 10 or (modId >= 25 and modId <= 49) then
        return "UB"
    end
    
    if modId == 23 or modId == 24 or modId == 46 or modId == 47 then
        return "GL"
    end
    
    if modId == 11 or modId == 12 or modId == 13 or modId == 14 or 
        modId == 15 or modId == 16 or modId == 18 then
        return "RL"
    end
    
    return "UB"
end

function OrderHelpers.ValidateQuantityLimits(parts)
    local rarityCounts = {
        common = 0,
        rare = 0,
        epic = 0,
        legendary = 0
    }
    
    for _, part in ipairs(parts) do
        local rarity = part.rarity or 'common'
        if rarityCounts[rarity] then
            rarityCounts[rarity] = rarityCounts[rarity] + (part.quantity or 1)
        end
    end
    
    for rarity, count in pairs(rarityCounts) do
        local limit = Config.Rarity.quantityLimits[rarity]
        if limit and count > limit then
            return false, string.format(t('cannot_order_more_than'), limit, rarity, count)
        end
    end
    
    return true, nil
end

function OrderHelpers.CalculateDeliveryTime(parts)
    local highestRarity = 'common'
    local rarityPriority = {
        common = 1,
        rare = 2,
        epic = 3,
        legendary = 4
    }
    
    for _, part in ipairs(parts) do
        local rarity = part.rarity or 'common'
        if rarityPriority[rarity] and rarityPriority[rarity] > rarityPriority[highestRarity] then
            highestRarity = rarity
        end
    end
    
    local multiplier = Config.Rarity.deliveryTimeMultiplier[highestRarity] or 1.0
    local baseTime = Config.Rarity.baseDeliveryTime or 30
    
    local deliveryTime = math.ceil(baseTime * multiplier)
    
    return deliveryTime, highestRarity
end

function OrderHelpers.ValidateOrderParts(parts)
    if not parts or type(parts) ~= "table" or #parts == 0 then
        return false, t('order_must_contain_at_least_one_part')
    end
    
    for i, part in ipairs(parts) do
        -- Support service line items (e.g. respray) that do not have reference numbers
        if not part.referenceNumber and not part.serviceType then
            return false, string.format(t('part_missing_reference_number'), i)
        end
        
        if not part.quantity or part.quantity < 1 then
            return false, string.format(t('part_must_have_quantity'), i)
        end
    end
    
    return true, nil
end

function OrderHelpers.GetPartPrice(modId, modIndex, shopId)
    if shopId and GetShopPrice then
        local shopPrice = GetShopPrice(shopId, modId, modIndex, nil, nil)
        if shopPrice then
            return shopPrice
        end
    end
    
    if Data.Prices[modId] then
        if type(Data.Prices[modId]) == "table" then
            local arrayIndex = modIndex
            if arrayIndex > 0 and arrayIndex <= #Data.Prices[modId] then
                return Data.Prices[modId][arrayIndex] or 1000
            end
        elseif type(Data.Prices[modId]) == "number" then
            return Data.Prices[modId]
        end
    end
    
    if Data.Prices['cosmetic'] then
        return Data.Prices['cosmetic']
    end
    
    return 1000
end