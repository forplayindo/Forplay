local BASE36_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- Convert a number to base-36 string
function toBase36(num)
    if num == 0 then
        return "0"
    end
    
    local result = ""
    while num > 0 do
        local remainder = num % 36
        local char = string.sub(BASE36_CHARS, remainder + 1, remainder + 1)
        result = char .. result
        num = math.floor(num / 36)
    end
    return result
end

-- Convert a base-36 string back to number
function fromBase36(str)
    local result = 0
    for i = 1, #str do
        local char = string.sub(str, i, i)
        local pos = string.find(BASE36_CHARS, char)
        if pos then
            result = result * 36 + (pos - 1)
        end
    end
    return result
end

-- Generate a checksum character for a mod ID and index
function generateChecksumChar(modId, modIndex)
    local checksum = (modId * 7 + (modIndex + 1) * 13) % 36
    return toBase36(checksum)
end

-- Pad a string to a specified length with a padding character
function padString(str, length, padChar)
    padChar = padChar or "0"
    local strStr = tostring(str)
    local paddingNeeded = length - #strStr
    if paddingNeeded <= 0 then
        return strStr
    end
    return string.rep(padChar, paddingNeeded) .. strStr
end

-- Convert signed hash to unsigned (for vehicle model hashes)
function toUnsignedHash(signedHash)
    if signedHash < 0 then
        return signedHash + 4294967296
    end
    return signedHash
end

-- Mod ID to supplier and category mapping
local ModCategories = {
    [0]  = { supplier = "UB", category = "SP" },      -- Spoiler
    [1]  = { supplier = "UB", category = "BMP-FR" },  -- Front Bumper
    [2]  = { supplier = "UB", category = "BMP-RR" },  -- Rear Bumper
    [3]  = { supplier = "UB", category = "SK" },      -- Side Skirt
    [4]  = { supplier = "UB", category = "EXH" },     -- Exhaust
    [5]  = { supplier = "UB", category = "CAGE" },    -- Roll Cage
    [6]  = { supplier = "UB", category = "GRL" },     -- Grille
    [7]  = { supplier = "UB", category = "HD" },      -- Hood
    [8]  = { supplier = "UB", category = "FD-L" },    -- Left Fender
    [9]  = { supplier = "UB", category = "FD-R" },    -- Right Fender
    [10] = { supplier = "UB", category = "RF" },      -- Roof
    [11] = { supplier = "RL", category = "ENG-STG" }, -- Engine Stage
    [12] = { supplier = "RL", category = "BRK-PAD" }, -- Brake Pads
    [13] = { supplier = "RL", category = "TRN" },     -- Transmission
    [14] = { supplier = "RL", category = "HORN" },    -- Horn
    [15] = { supplier = "RL", category = "SUS" },     -- Suspension
    [16] = { supplier = "RL", category = "ARM" },     -- Armor
    [17] = { supplier = "RL", category = "NTR" },     -- Nitrous
    [18] = { supplier = "RL", category = "TRB" },     -- Turbo
    [19] = { supplier = "UB", category = "SUB" },     -- Subwoofer
    [21] = { supplier = "UB", category = "HYD" },     -- Hydraulics
    [23] = { supplier = "GL", category = "WH-ALLOY", useVehicleModel = false }, -- Front Wheels
    [24] = { supplier = "GL", category = "WH-REAR", useVehicleModel = false },  -- Rear Wheels
    [25] = { supplier = "UB", category = "PLH" },     -- Plate Holder
    [26] = { supplier = "UB", category = "VNP" },     -- Vanity Plate
    [27] = { supplier = "UB", category = "TRM-A" },   -- Trim A
    [28] = { supplier = "UB", category = "ORN" },     -- Ornaments
    [29] = { supplier = "UB", category = "DSH" },     -- Dashboard
    [30] = { supplier = "UB", category = "DIA" },     -- Dial
    [31] = { supplier = "UB", category = "DSPK" },    -- Door Speaker
    [32] = { supplier = "UB", category = "STS" },     -- Seats
    [33] = { supplier = "UB", category = "STW" },     -- Steering Wheel
    [34] = { supplier = "UB", category = "SHL" },     -- Shifter Lever
    [35] = { supplier = "UB", category = "PLQ" },     -- Plaque
    [36] = { supplier = "UB", category = "SPK" },     -- Speaker
    [37] = { supplier = "UB", category = "TRK" },     -- Trunk
    [38] = { supplier = "UB", category = "HYD-X" },   -- Hydraulic Kit
    [39] = { supplier = "RL", category = "ENG-BLK" }, -- Engine Block
    [40] = { supplier = "RL", category = "AIR-FLT" }, -- Air Filter
    [41] = { supplier = "GL", category = "STRT" },    -- Strut
    [42] = { supplier = "UB", category = "ARCH" },    -- Arch Cover
    [43] = { supplier = "UB", category = "AER" },     -- Aerial
    [44] = { supplier = "UB", category = "TRM-B" },   -- Trim B
    [45] = { supplier = "UB", category = "FT" },      -- Fuel Tank
    [46] = { supplier = "UB", category = "DR-L" },    -- Left Door
    [47] = { supplier = "UB", category = "DR-R" },    -- Right Door
    [48] = { supplier = "UB", category = "LVR" },     -- Livery
    [49] = { supplier = "UB", category = "LBR" },     -- Lightbar
    [50] = { supplier = "UB", category = "PLT" },     -- Plate Index
    [51] = { supplier = "UB", category = "WNT" },     -- Window Tint
    [52] = { supplier = "UB", category = "EXTR" },    -- Extras
}

-- Map mod ID to item name
local ModItemMap = {
    [0]  = "mechanic_spoiler",
    [1]  = "mechanic_front_bumper",
    [2]  = "mechanic_rear_bumper",
    [3]  = "mechanic_side_skirt",
    [4]  = "mechanic_exhaust",
    [5]  = "mechanic_roll_cage",
    [6]  = "mechanic_grille",
    [7]  = "mechanic_hood",
    [8]  = "mechanic_fender",
    [9]  = "mechanic_fender",
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
    [20] = "mechanic_tyre_smoke",
    [21] = "mechanic_hydraulics",
    [22] = "mechanic_xenon",
    [23] = "mechanic_wheels",
    [24] = "mechanic_wheels",
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
    [42] = "mechanic_fender",
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

-- Map mod ID to part name
local ModIdToPartName = {
    [0]  = "spoiler",
    [1]  = "front_bumper",
    [2]  = "rear_bumper",
    [3]  = "side_skirt",
    [4]  = "exhaust",
    [5]  = "roll_cage",
    [6]  = "grille",
    [7]  = "hood",
    [8]  = "fender",
    [9]  = "fender",
    [10] = "roof",
    [11] = "engine",
    [12] = "brakes",
    [13] = "transmission",
    [14] = "horn",
    [15] = "suspension",
    [16] = "armor",
    [17] = "nitrous",
    [18] = "turbo",
    [19] = "subwoofer",
    [20] = "tyre_smoke",
    [21] = "hydraulics",
    [22] = "xenon",
    [23] = "wheels",
    [24] = "wheels",
    [25] = "plate_holder",
    [26] = "vanity_plate",
    [27] = "trim_a",
    [28] = "ornaments",
    [29] = "dashboard",
    [30] = "dial",
    [31] = "door_speaker",
    [32] = "seats",
    [33] = "steering_wheel",
    [34] = "shifter_lever",
    [35] = "plaque",
    [36] = "speaker",
    [37] = "trunk",
    [38] = "hydraulic_kit",
    [39] = "engine_block",
    [40] = "air_filter",
    [41] = "strut",
    [42] = "fender",
    [43] = "aerial",
    [44] = "trim_b",
    [45] = "fuel_tank",
    [46] = "left_door",
    [47] = "right_door",
    [48] = "livery",
    [49] = "lightbar",
    [50] = "plate_index",
    [51] = "window_tint",
    [52] = "extras",
}

-- Get part name from mod ID
function GetPartNameFromModId(modId)
    return ModIdToPartName[modId] or "part"
end

-- Get item name from mod ID
function GetItemNameFromModId(modId)
    return ModItemMap[modId]
end

-- Check if an item name matches a mod ID
function ItemMatchesModId(itemName, modId)
    if not itemName or modId == nil then
        return false
    end
    
    local expectedItem = GetItemNameFromModId(modId)
    if itemName == expectedItem then
        return true
    end
    
    -- Handle interior parts (various mods)
    if itemName == "mechanic_interior" then
        local interiorMods = {
            [27] = true, [28] = true, [29] = true, [30] = true,
            [31] = true, [32] = true, [33] = true, [34] = true,
            [35] = true, [36] = true, [37] = true, [44] = true
        }
        return interiorMods[modId] == true
    end
    
    -- Handle doors
    if itemName == "mechanic_doors" and (modId == 46 or modId == 47) then
        return true
    end
    
    return false
end

-- Check if a part item is valid for installation
function IsValidPartItem(modId, expectedRef, metadata, itemName)
    metadata = metadata or {}
    
    local metadataRef = metadata.referenceNumber or metadata.reference
    if expectedRef and expectedRef ~= "" and metadataRef and metadataRef == expectedRef then
        return true
    end
    
    -- Check universal items
    if Config and Config.UniversalItems and Config.UniversalItems.enabled then
        if metadata.universal == true then
            if ItemMatchesModId(itemName, modId) then
                local allowedModIds = Config.UniversalItems.allowedModIds
                if allowedModIds == nil or allowedModIds[modId] ~= false then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Check if metadata indicates a universal part
function IsUniversalPartMetadata(metadata)
    if not metadata then
        return false
    end
    
    if metadata.universal ~= true then
        return false
    end
    
    return Config and Config.UniversalItems and Config.UniversalItems.enabled == true
end

-- Generate a reference number for a part
function generateReferenceNumber(modId, modIndex, vehicleModel, wheelType)
    local modInfo = ModCategories[modId]
    local category = (modInfo and modInfo.category) or "MISC"
    local supplier = (modInfo and modInfo.supplier) or "UB"
    local useVehicleModel = (modInfo and modInfo.useVehicleModel) == nil and true or modInfo.useVehicleModel
    
    -- Format components
    local modIdStr = padString(toBase36(modId), 2)
    local modIndexStr = padString(toBase36(modIndex + 1), 3)
    local checksumChar = generateChecksumChar(modId, modIndex)
    
    -- Handle vehicle model hash
    local vehicleHashStr = ""
    if useVehicleModel and vehicleModel then
        local unsignedHash = toUnsignedHash(type(vehicleModel) == "string" and GetHashKey(vehicleModel) or vehicleModel)
        vehicleHashStr = padString(toBase36(unsignedHash), 7)
    end
    
    -- Handle wheel type
    local wheelTypeStr = ""
    if (modId == 23 or modId == 24) and wheelType then
        wheelTypeStr = padString(toBase36(wheelType), 2)
    end
    
    -- Build the reference number
    if vehicleHashStr ~= "" then
        return string.format("%s-%s-%s%s%s", category, modIdStr, modIndexStr, checksumChar, vehicleHashStr)
    elseif wheelTypeStr ~= "" then
        return string.format("%s-%s-%s%s%s", category, modIdStr, modIndexStr, checksumChar, wheelTypeStr)
    else
        return string.format("%s-%s-%s%s", category, modIdStr, modIndexStr, checksumChar)
    end
end

-- Generate a respray reference number
function generateResprayReferenceNumber(paintType, colorData)
    paintType = tonumber(paintType) or 0
    paintType = math.min(5, math.max(0, paintType))
    local paintTypeStr = tostring(paintType)
    
    if paintType == 0 then
        -- Stock paint
        local colorIndex = tonumber(colorData) or 0
        local colorHash = padString(toBase36(colorIndex), 3)
        local checksumChar = string.char(65 + (paintType + colorIndex) % 26)
        return string.format("RSPRY-STK-%s%s%s", paintTypeStr, colorHash, checksumChar)
    else
        -- RGB custom paint
        local r = math.min(255, math.max(0, math.floor(colorData.r or colorData[1] or 0)))
        local g = math.min(255, math.max(0, math.floor(colorData.g or colorData[2] or 0)))
        local b = math.min(255, math.max(0, math.floor(colorData.b or colorData[3] or 0)))
        
        local rgbHex = string.format("%02X%02X%02X", r, g, b)
        local checksumChar = string.char(65 + (paintType + r + g + b) % 26)
        
        return string.format("RSPRY-RGB-%s%s%s", paintTypeStr, rgbHex, checksumChar)
    end
end

function decodeResprayReferenceNumber(refNumber)
    if not refNumber or type(refNumber) ~= "string" then
        return nil
    end
    
    local prefix = string.sub(refNumber, 1, 10)
    
    if prefix == "RSPRY-STK-" then
        local suffix = string.sub(refNumber, 11)
        local paintType = tonumber(string.sub(suffix, 1, 1)) or 0
        local colorHash = string.sub(suffix, 2, 4)
        local colorIndex = fromBase36(colorHash)
        
        return {
            mode = "stock",
            paintType = paintType,
            colorIndex = colorIndex
        }
        
    elseif prefix == "RSPRY-RGB-" then
        local suffix = string.sub(refNumber, 11)
        local paintType = tonumber(string.sub(suffix, 1, 1)) or 0
        local rgbHex = string.sub(suffix, 2, 7)
        
        local r = tonumber("0x" .. string.sub(rgbHex, 1, 2)) or 0
        local g = tonumber("0x" .. string.sub(rgbHex, 3, 4)) or 0
        local b = tonumber("0x" .. string.sub(rgbHex, 5, 6)) or 0
        
        return {
            mode = "rgb",
            paintType = paintType,
            r = r,
            g = g,
            b = b
        }
    end
    
    return nil
end

function decodeReferenceNumber(refNumber)
    local parts = {}
    for part in string.gmatch(refNumber, "[^-]+") do
        table.insert(parts, part)
    end
    
    if #parts < 3 then
        return nil, nil, nil, nil
    end
    
    local suffix = parts[#parts]
    local checksumPart = parts[#parts - 1]
    local categoryCode = fromBase36(checksumPart)
    local checksumChar = string.sub(suffix, 1, 3)
    local checksumValue = fromBase36(checksumChar) - 1
    
    local vehicleHash = nil
    local wheelType = nil
    
    if categoryCode == 23 or categoryCode == 24 then
        -- Wheels
        if #suffix >= 6 then
            local wheelTypeStr = string.sub(suffix, 5, 6)
            wheelType = fromBase36(wheelTypeStr)
        end
    else
        -- Other parts
        if #suffix >= 11 then
            local hashStr = string.sub(suffix, 5, 11)
            vehicleHash = fromBase36(hashStr)
        end
    end
    
    return categoryCode, checksumValue, vehicleHash, wheelType
end

-- Get vehicle name from a reference number
function getVehicleNameFromReference(refNumber)
    local _, _, vehicleHash = decodeReferenceNumber(refNumber)
    
    if not vehicleHash then
        return nil
    end
    
    local displayName = GetDisplayNameFromVehicleModel(vehicleHash)
    if not displayName or displayName == "" then
        return nil
    end
    
    local labelText = GetLabelText(displayName)
    if not labelText or labelText == "NULL" or labelText == "" then
        return displayName
    end
    
    return labelText
end

-- Verify that a reference number matches a vehicle model
function verifyReferenceForVehicle(refNumber, vehicleModel)
    local _, _, refHash = decodeReferenceNumber(refNumber)
    
    if not refHash then
        return false
    end
    
    local unsignedVehicleHash = toUnsignedHash(vehicleModel)
    return refHash == unsignedVehicleHash
end