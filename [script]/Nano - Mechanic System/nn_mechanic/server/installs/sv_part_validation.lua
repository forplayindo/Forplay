-- server/install/sv_part_validation.lua
-- Part validation server-side

local validPartCache = {}

function ValidatePartItem(modId, expectedRef, itemData, itemName)
    -- Check for universal items
    if Config.UniversalItems and Config.UniversalItems.enabled then
        local allowedModIds = Config.UniversalItems.allowedModIds
        if allowedModIds == nil or allowedModIds[modId] ~= false then
            if itemData and itemData.universal == true then
                return true
            end
        end
    end
    
    -- Check reference number directly
    if expectedRef and expectedRef ~= "" and itemData and itemData.referenceNumber then
        if expectedRef == itemData.referenceNumber then
            return true
        end
    end
    
    -- Check item name matches mod
    local modItemMap = {
        [0] = "mechanic_spoiler",
        [1] = "mechanic_front_bumper",
        [2] = "mechanic_rear_bumper",
        [3] = "mechanic_side_skirt",
        [4] = "mechanic_exhaust",
        [5] = "mechanic_roll_cage",
        [6] = "mechanic_grille",
        [7] = "mechanic_hood",
        [8] = "mechanic_fender",
        [9] = "mechanic_fender",
        [10] = "mechanic_roof",
        [11] = "mechanic_engine",
        [12] = "mechanic_brakes",
        [13] = "mechanic_transmission",
        [14] = "mechanic_horn",
        [15] = "mechanic_suspension",
        [16] = "mechanic_armor",
        [17] = "mechanic_nitrous",
        [18] = "mechanic_turbo",
        [19] = "mechanic_subwoofer",
        [21] = "mechanic_hydraulics",
        [23] = "mechanic_wheels",
        [25] = "mechanic_plate_holder",
        [26] = "mechanic_vanity_plate",
        [27] = "mechanic_trim_a",
        [28] = "mechanic_ornaments",
        [29] = "mechanic_dashboard",
        [30] = "mechanic_dial",
        [31] = "mechanic_door_speaker",
        [32] = "mechanic_seats",
        [33] = "mechanic_steering_wheel",
        [34] = "mechanic_shifter_lever",
        [35] = "mechanic_plaque",
        [36] = "mechanic_speaker",
        [37] = "mechanic_trunk",
        [38] = "mechanic_hydraulic_kit",
        [39] = "mechanic_engine_block",
        [40] = "mechanic_air_filter",
        [41] = "mechanic_strut",
        [43] = "mechanic_aerial",
        [44] = "mechanic_trim_b",
        [45] = "mechanic_fuel_tank",
        [46] = "mechanic_left_door",
        [47] = "mechanic_right_door",
        [48] = "mechanic_livery",
        [49] = "mechanic_lightbar",
        [50] = "mechanic_plate_index",
        [51] = "mechanic_window_tint",
        [52] = "mechanic_extras",
    }
    
    local expectedItem = modItemMap[modId]
    if expectedItem and itemName == expectedItem then
        return true
    end
    
    return false
end

function IsValidPartItem(modId, expectedRef, inventoryData, itemName)
    local cacheKey = string.format("%s_%s_%s", modId, expectedRef or "", itemName or "")
    
    if validPartCache[cacheKey] then
        return validPartCache[cacheKey]
    end
    
    local isValid = ValidatePartItem(modId, expectedRef, inventoryData, itemName)
    validPartCache[cacheKey] = isValid
    
    -- Clear cache after 5 minutes
    Citizen.SetTimeout(300000, function()
        validPartCache[cacheKey] = nil
    end)
    
    return isValid
end

lib.callback.register("nn_mechanic:validatePartItem", function(source, modId, expectedRef, itemData, itemName)
    local isValid = IsValidPartItem(modId, expectedRef, itemData, itemName)
    return isValid
end)