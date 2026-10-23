-- Vehicle Customization Catalog System
-- Handles vehicle modifications, resprays, neon/xenon lights, extras, and more

local bridge = exports.community_bridge.Bridge()

-- Check if vehicle needs repair (public shop)
local function needsRepair(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    
    local bodyThreshold = (Config.PublicShopRepair and Config.PublicShopRepair.bodyThreshold) or 900
    local engineThreshold = (Config.PublicShopRepair and Config.PublicShopRepair.engineThreshold) or 900
    
    return bodyHealth < bodyThreshold or engineHealth < engineThreshold
end

-- Initialize State if not exists
if not State then
    State = {}
end

State.pendingCatalogOpen = nil

-- Open catalog UI
function OpenCatalog(shopId, pointId)
    local playerPed = PlayerPedId()
    local vehicleHash = GetEntityModel(State.Vehicle)
    
    State.currentShopId = shopId
    State.currentPointId = pointId
    State.vehicleProps = getVehicleProperties(State.Vehicle)
    State.catalogLightsState = nil
    State.shopPrices = {}
    
    -- Get shop prices
    if shopId then
        local prices = bridge.Callback.Trigger("nn_mechanic:getAllShopPrices", shopId)
        if prices then
            State.shopPrices = prices
        end
    end
    
    -- Store initial lights state
    if State.Vehicle and DoesEntityExist(State.Vehicle) and GetVehicleLightsState then
        local _, lightsOn, highbeamsOn = GetVehicleLightsState(State.Vehicle)
        State.catalogLightsState = {
            lightsOn = lightsOn == 1,
            highbeamsOn = highbeamsOn == 1
        }
    end
    
    if State.Vehicle then
        SetVehicleModKit(State.Vehicle, 0)
        
        local catalog = GenerateCatalog(State.Vehicle)
        local vehicleHash = GetEntityModel(State.Vehicle)
        local shopOperationType = (State.shop and State.shop.shopOperationType) or "auto"
        
        -- Check current modifications
        local neonInstalledAtOpen = false
        local xenonInstalledAtOpen = false
        
        if State.vehicleProps and type(State.vehicleProps) == "table" then
            if type(State.vehicleProps.neonEnabled) == "table" then
                for _, enabled in ipairs(State.vehicleProps.neonEnabled) do
                    if enabled == true then
                        neonInstalledAtOpen = true
                        break
                    end
                end
            end
            xenonInstalledAtOpen = (State.vehicleProps.modXenon == true)
        end
        
        -- Store initial colors and extras
        if State.Vehicle and DoesEntityExist(State.Vehicle) then
            local pearlescentColor, wheelColor = GetVehicleExtraColours(State.Vehicle)
            State.initialExtraColours = {
                wheelColorIndex = wheelColor or 0,
                pearlescentColorIndex = pearlescentColor or 0
            }
            
            local r, g, b = GetVehicleTyreSmokeColor(State.Vehicle)
            State.initialTyreSmoke = { r = r, g = g, b = b }
            
            local windowTint = GetVehicleWindowTint(State.Vehicle)
            State.initialWindowTint = windowTint or 0
            
            State.initialExtras = {}
            for extraIndex = 1, 14 do
                if DoesExtraExist(State.Vehicle, extraIndex) then
                    State.initialExtras[extraIndex] = IsVehicleExtraTurnedOn(State.Vehicle, extraIndex)
                end
            end
        end
        
        -- Price functions
        local function getBaseColorPrice()
            local price = tonumber(Data.Prices and Data.Prices.colors)
            return price or 1000
        end
        
        local function getNeonLightsPrice()
            local price = tonumber(Data.Prices and Data.Prices.neon_lights)
            return price or getBaseColorPrice()
        end
        
        local function getXenonLightsPrice()
            local price = tonumber(Data.Prices and Data.Prices.xenon_lights)
            return price or getBaseColorPrice()
        end
        
        -- Get initial respray colors
        local initialResprayColors = nil
        if State.Vehicle and DoesEntityExist(State.Vehicle) then
            local pr, pg, pb = GetVehicleCustomPrimaryColour(State.Vehicle)
            local sr, sg, sb = GetVehicleCustomSecondaryColour(State.Vehicle)
            local primaryPaintType = GetVehicleModColor_1(State.Vehicle)
            local secondaryPaintType = GetVehicleModColor_2(State.Vehicle)
            
            initialResprayColors = {
                primaryRgb = { r = pr or 0, g = pg or 0, b = pb or 0 },
                secondaryRgb = { r = sr or 0, g = sg or 0, b = sb or 0 },
                primaryPaintType = primaryPaintType or 0,
                secondaryPaintType = secondaryPaintType or 0
            }
        end
        
        -- Get initial neon and xenon colors
        local initialNeonRgb = nil
        local initialXenonRgb = nil
        
        if State.Vehicle and DoesEntityExist(State.Vehicle) then
            local nr, ng, nb = GetVehicleNeonLightsColour(State.Vehicle)
            initialNeonRgb = { r = nr or 0, g = ng or 0, b = nb or 0 }
            
            if GetVehicleXenonLightsCustomColor then
                local xr, xg, xb = GetVehicleXenonLightsCustomColor(State.Vehicle)
                if xr and xg and xb then
                    initialXenonRgb = { r = xr, g = xg, b = xb }
                end
            end
        end
        
        local isPublicShop = (State.shop and State.shop.shopType == "public")
        local publicRepairEnabled = Config.PublicShopRepair and Config.PublicShopRepair.enabled
        local vehicleNeedsRepair = needsRepair(State.Vehicle)
        
        if isPublicShop and publicRepairEnabled and vehicleNeedsRepair then
            -- Show repair modal first for public shops
            State.pendingCatalogOpen = { shopId = shopId, pointId = pointId }
            
            SendNUIMessage({
                action = "setCatalogData",
                data = {
                    catalog = catalog,
                    vehicleHash = vehicleHash,
                    shopOperationType = shopOperationType,
                    neonInstalledAtOpen = neonInstalledAtOpen,
                    xenonInstalledAtOpen = xenonInstalledAtOpen,
                    neonLightsPrice = getNeonLightsPrice(),
                    xenonLightsPrice = getXenonLightsPrice(),
                    currentExtraColours = State.initialExtraColours,
                    initialResprayColors = initialResprayColors,
                    initialNeonRgb = initialNeonRgb,
                    initialXenonRgb = initialXenonRgb
                }
            })
            
            SendNUIMessage({
                action = "setVisibility",
                data = {
                    visible = true,
                    page = "catalog"
                }
            })
            
            SendNUIMessage({
                action = "showRepairModal",
                data = {
                    price = (Config.PublicShopRepair and Config.PublicShopRepair.price) or 500
                }
            })
            
            State.openPage = "catalog"
            DisplayRadar(false)
            SetNuiFocus(true, true)
            return
        end
        
        -- Open catalog directly
        startDragCam(State.Vehicle)
        
        SendNUIMessage({
            action = "setCatalogData",
            data = {
                catalog = catalog,
                vehicleHash = vehicleHash,
                shopOperationType = shopOperationType,
                neonInstalledAtOpen = neonInstalledAtOpen,
                xenonInstalledAtOpen = xenonInstalledAtOpen,
                neonLightsPrice = getNeonLightsPrice(),
                xenonLightsPrice = getXenonLightsPrice(),
                currentExtraColours = State.initialExtraColours,
                initialResprayColors = initialResprayColors,
                initialNeonRgb = initialNeonRgb,
                initialXenonRgb = initialXenonRgb
            }
        })
        
        SendNUIMessage({
            action = "setVisibility",
            data = {
                visible = true,
                page = "catalog"
            }
        })
        
        State.openPage = "catalog"
        DisplayRadar(false)
        SetNuiFocus(true, true)
    end
end

-- Get mod label
function GetModLabel(vehicle, modType, modIndex)
    local modLabels = Data.ModLabels and Data.ModLabels[modType]
    if modLabels then
        for _, label in pairs(modLabels) do
            if label.id == modIndex then
                return label.label
            end
        end
    end
    
    local labelText = GetModTextLabel(vehicle, modType, modIndex)
    if not labelText or labelText == "" then
        return tostring(modIndex)
    end
    return GetLabelText(labelText)
end

-- Apply shop markup to price
local function applyShopMarkup(price)
    if not price then
        return nil
    end
    local markup = Config.DefaultShopMarkup or 0.2
    return math.floor(price * (1 + markup))
end

-- Get supplier price for a mod
function GetSupplierPrice(modId, modIndex, referenceNumber, category)
    -- Check price overrides first
    if referenceNumber then
        local override = Data.PricesOverrides and Data.PricesOverrides[referenceNumber]
        if override then
            return override
        end
    end
    
    -- Check specific price in Prices table
    if modId then
        local priceData = Data.Prices and Data.Prices[modId]
        if priceData then
            if type(priceData) == "table" then
                return priceData[modIndex + 1]
            else
                return priceData
            end
        end
    end
    
    -- Check category price
    if category then
        local categoryPrice = Data.Prices and Data.Prices[category]
        if categoryPrice then
            return categoryPrice
        end
    end
    
    -- Fallback to category from Mods table
    if modId and (not category or category == "") then
        local mods = Data.Mods
        if mods then
            for _, mod in pairs(mods) do
                if mod.id == modId and mod.category then
                    local categoryPrice = Data.Prices and Data.Prices[mod.category]
                    if categoryPrice then
                        return categoryPrice
                    end
                end
            end
        end
    end
    
    return 1000.0
end

-- Get mod price with shop markup
function GetModPrice(modId, modIndex, referenceNumber, category)
    local shopId = State.currentShopId
    
    -- Check for custom shop price
    if shopId and State.shopPrices then
        local key = string.format("%s_nil_%s_%s", 
            tostring(modId or "nil"), 
            tostring(modIndex or "nil"), 
            category or "nil"
        )
        
        -- Try specific combinations
        if referenceNumber and referenceNumber ~= "" then
            if modId and modIndex then
                local specificKey = string.format("%s_nil_%s_%s", 
                    tostring(modId), tostring(modIndex), referenceNumber
                )
                local price = State.shopPrices[specificKey]
                if price then
                    return tonumber(price)
                end
            end
            
            if modId then
                local modKey = string.format("%s_nil_nil_%s", tostring(modId), referenceNumber)
                local price = State.shopPrices[modKey]
                if price then
                    return tonumber(price)
                end
            end
            
            local refKey = string.format("nil_nil_nil_%s", referenceNumber)
            local price = State.shopPrices[refKey]
            if price then
                return tonumber(price)
            end
        end
        
        -- Try mod+index combination
        if modId and modIndex then
            local comboKey = string.format("%s_nil_%s_nil", tostring(modId), tostring(modIndex))
            local price = State.shopPrices[comboKey]
            if price then
                return tonumber(price)
            end
        end
        
        -- Try mod only
        if modId then
            local modOnlyKey = string.format("%s_nil_nil_nil", tostring(modId))
            local price = State.shopPrices[modOnlyKey]
            if price then
                return tonumber(price)
            end
        end
        
        -- Try category
        if category and category ~= "" then
            local catKey = string.format("nil_%s_nil_nil", category)
            local price = State.shopPrices[catKey]
            if price then
                return tonumber(price)
            end
        end
        
        -- Try derived category from Mods
        if modId and (not category or category == "") then
            local modCategory = nil
            local mods = Data.Mods
            if mods then
                for _, mod in pairs(mods) do
                    if mod.id == modId then
                        modCategory = mod.category
                        break
                    end
                end
            end
            if modCategory then
                local derivedKey = string.format("nil_%s_nil_nil", modCategory)
                local price = State.shopPrices[derivedKey]
                if price then
                    return tonumber(price)
                end
            end
        end
    end
    
    local supplierPrice = GetSupplierPrice(modId, modIndex, referenceNumber, category)
    
    if shopId then
        return applyShopMarkup(supplierPrice)
    end
    
    return supplierPrice
end

-- Generate catalog of all available modifications
function GenerateCatalog(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end
    
    local catalog = {}
    local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleListName = Data.VehicleList and Data.VehicleList[vehicleModel]
    
    local mods = Data.Mods
    for _, modConfig in pairs(mods) do
        local numMods = GetNumVehicleMods(vehicle, modConfig.id)
        local currentMod = GetVehicleMod(vehicle, modConfig.id)
        local currentWheelType = GetVehicleWheelType(vehicle)
        
        -- Handle different mod types
        if modConfig.id == 50 then -- License plates
            catalog[50] = { id = 50, label = modConfig.label, mods = {} }
            local currentPlateIndex = GetVehicleNumberPlateTextIndex(vehicle)
            
            if Data.PlateIndexes then
                for _, plate in pairs(Data.PlateIndexes) do
                    local refNumber = generateReferenceNumber(50, plate.id, vehicleModel)
                    local isInstalled = (currentPlateIndex == plate.id)
                    
                    table.insert(catalog[50].mods, {
                        id = plate.id,
                        modId = 50,
                        modIndex = plate.id,
                        label = plate.label,
                        price = GetModPrice(50, plate.id, refNumber),
                        image = string.format("https://s3.nanoscripts.cloud/plate_index_%d.webp", plate.id),
                        referenceNumber = refNumber,
                        isInstalled = isInstalled
                    })
                end
            end
            
        elseif modConfig.id == 51 then -- Window tint
            catalog[51] = { id = 51, label = modConfig.label, mods = {} }
            local currentTint = GetVehicleWindowTint(vehicle)
            
            if Data.WindowTints then
                for _, tint in pairs(Data.WindowTints) do
                    local refNumber = generateReferenceNumber(51, tint.id, vehicleModel)
                    local isInstalled = (currentTint == tint.id)
                    
                    table.insert(catalog[51].mods, {
                        id = tint.id,
                        modId = 51,
                        modIndex = tint.id,
                        label = tint.label,
                        price = GetModPrice(51, tint.id, refNumber),
                        image = "assets/icons/window_tint.png",
                        referenceNumber = refNumber,
                        isInstalled = isInstalled
                    })
                end
            end
            
        elseif modConfig.id == 52 then -- Vehicle extras
            local hasAnyExtra = false
            for i = 1, 14 do
                if DoesExtraExist(vehicle, i) then
                    hasAnyExtra = true
                    break
                end
            end
            
            if hasAnyExtra then
                catalog[52] = { id = 52, label = modConfig.label, mods = {} }
                
                for extraIndex = 1, 14 do
                    if DoesExtraExist(vehicle, extraIndex) then
                        local isInstalled = IsVehicleExtraTurnedOn(vehicle, extraIndex)
                        local refNumber = generateReferenceNumber(52, extraIndex, vehicleModel)
                        
                        table.insert(catalog[52].mods, {
                            id = extraIndex,
                            modId = 52,
                            modIndex = extraIndex,
                            label = string.format("Extra %d", extraIndex),
                            price = GetModPrice(52, extraIndex, refNumber),
                            image = "assets/icons/wrench.png",
                            referenceNumber = refNumber,
                            isInstalled = isInstalled
                        })
                    end
                end
            end
            
        elseif modConfig.id == 48 then -- Liveries
            local currentLivery = GetVehicleLivery(vehicle)
            local currentModLivery = GetVehicleMod(vehicle, 48)
            local useOldMethod = false
            local currentIndex = -1
            local totalLiveries = 0
            
            if currentModLivery >= 0 then
                useOldMethod = false
                currentIndex = currentModLivery
                totalLiveries = GetNumVehicleMods(vehicle, 48)
            elseif currentLivery >= 0 then
                useOldMethod = true
                currentIndex = currentLivery
                totalLiveries = GetVehicleLiveryCount(vehicle)
            end
            
            if totalLiveries > 0 then
                catalog[48] = {
                    id = 48,
                    label = modConfig.label,
                    mods = {},
                    liveryUseOldMethod = useOldMethod
                }
                
                if useOldMethod then
                    for liveryIndex = 0, totalLiveries - 1 do
                        local refNumber = generateReferenceNumber(48, liveryIndex, vehicleModel)
                        local isInstalled = (currentIndex == liveryIndex)
                        local imageUrl = string.format(
                            "https://s3.nanoscripts.cloud/mechanic/livery/livery_%s_%d.webp",
                            vehicleListName, liveryIndex
                        )
                        
                        table.insert(catalog[48].mods, {
                            id = liveryIndex,
                            modId = 48,
                            modIndex = liveryIndex,
                            liveryOldMethod = true,
                            label = string.format("%s %d", t("livery"), liveryIndex + 1),
                            price = GetModPrice(48, liveryIndex, refNumber),
                            image = imageUrl,
                            referenceNumber = refNumber,
                            isInstalled = isInstalled
                        })
                    end
                else
                    -- Add stock livery option
                    local isStock = (currentIndex == -1)
                    table.insert(catalog[48].mods, {
                        id = -1,
                        modId = 48,
                        modIndex = -1,
                        liveryOldMethod = false,
                        label = t("stock"),
                        price = 0,
                        referenceNumber = "",
                        isInstalled = isStock
                    })
                    
                    for liveryIndex = 0, totalLiveries - 1 do
                        local refNumber = generateReferenceNumber(48, liveryIndex, vehicleModel)
                        local isInstalled = (currentIndex == liveryIndex)
                        local label = GetLabelText(GetModTextLabel(vehicle, 48, liveryIndex))
                        
                        if not label or label == "" or label == "NULL" then
                            label = string.format("%s %d", t("livery"), liveryIndex + 1)
                        end
                        
                        local imageUrl = string.format(
                            "https://s3.nanoscripts.cloud/mechanic/livery/livery_%s_%d.webp",
                            vehicleListName, liveryIndex
                        )
                        
                        table.insert(catalog[48].mods, {
                            id = liveryIndex,
                            modId = 48,
                            modIndex = liveryIndex,
                            liveryOldMethod = false,
                            label = label,
                            price = GetModPrice(48, liveryIndex, refNumber),
                            image = imageUrl,
                            referenceNumber = refNumber,
                            isInstalled = isInstalled
                        })
                    end
                end
            end
            
        elseif numMods > 0 then
            catalog[modConfig.id] = {
                id = modConfig.id,
                label = modConfig.label,
                mods = {}
            }
            
            if modConfig.id == 23 then -- Wheels
                for _, wheelType in pairs(Data.Wheels) do
                    if isWheelTypeAllowed(wheelType.id, vehicle) then
                        -- Add stock option
                        local isStock = (currentMod == -1)
                        table.insert(catalog[23].mods, {
                            id = -1,
                            modId = 23,
                            modIndex = -1,
                            wheelId = wheelType.id,
                            label = t("stock"),
                            price = 0,
                            referenceNumber = "",
                            isInstalled = isStock
                        })
                        
                        for wheelIndex = 0, numMods - 1 do
                            local refNumber = generateReferenceNumber(23, wheelIndex, nil, wheelType.id)
                            local isInstalled = (currentMod == wheelIndex)
                            
                            table.insert(catalog[23].mods, {
                                id = wheelIndex,
                                modId = 23,
                                modIndex = wheelIndex,
                                wheelId = wheelType.id,
                                label = GetModLabel(vehicle, 23, wheelIndex),
                                price = GetModPrice(23, wheelIndex, refNumber),
                                image = string.format(
                                    "https://s3.nanoscripts.cloud/mechanic/wheels/wheel_%d_%d.webp",
                                    wheelType.id, wheelIndex
                                ),
                                referenceNumber = refNumber,
                                isInstalled = isInstalled
                            })
                        end
                    end
                end
                
            elseif modConfig.id == 11 then -- Engines (with custom swaps)
                -- Add stock option
                local isStock = (currentMod == -1)
                table.insert(catalog[11].mods, {
                    id = -1,
                    modId = 11,
                    modIndex = -1,
                    label = t("stock"),
                    price = 0,
                    referenceNumber = "",
                    isInstalled = isStock
                })
                
                local vehicleClass = GetVehicleClass(vehicle)
                local engineNames = Data.EngineNames and Data.EngineNames[vehicleClass]
                
                for engineIndex = 0, numMods - 1 do
                    local refNumber = generateReferenceNumber(11, engineIndex, vehicleModel)
                    local isInstalled = (currentMod == engineIndex)
                    local label = engineNames and engineNames[engineIndex + 1] or string.format("Engine %d", engineIndex + 1)
                    
                    table.insert(catalog[11].mods, {
                        id = engineIndex,
                        modId = 11,
                        modIndex = engineIndex,
                        label = label,
                        price = GetModPrice(11, engineIndex, refNumber),
                        referenceNumber = refNumber,
                        isInstalled = isInstalled
                    })
                end
                
                -- Add custom engine swaps
                if Config.EngineSwap and Config.EngineSwap.engines and Data.CustomEngineKeyToModIndex then
                    local classMap = {
                        [0] = "compacts", [1] = "sedans", [2] = "suvs", [3] = "coupes",
                        [4] = "muscle", [5] = "sportsclassics", [6] = "sports", [7] = "super",
                        [8] = "motorcycles", [9] = "off_road", [10] = "industrial", [11] = "utility",
                        [12] = "vans", [13] = "cycles", [17] = "service", [18] = "emergency",
                        [19] = "military", [22] = "open_wheel"
                    }
                    
                    local vehicleDisplayName = string.lower(GetDisplayNameFromVehicleModel(vehicleModel) or "")
                    
                    for engineId, engineData in pairs(Data.CustomEngineKeyToModIndex) do
                        local engineConfig = Config.EngineSwap.engines[engineId]
                        if engineConfig and engineConfig.meta and engineConfig.compatibility then
                            local compatibility = engineConfig.compatibility
                            local isCompatible = true
                            
                            if compatibility.allowedClasses and #compatibility.allowedClasses > 0 then
                                local classString = classMap[vehicleClass]
                                local found = false
                                for _, allowedClass in ipairs(compatibility.allowedClasses) do
                                    if allowedClass == classString then
                                        found = true
                                        break
                                    end
                                end
                                isCompatible = found
                            end
                            
                            if compatibility.blacklistModels then
                                for _, blacklisted in ipairs(compatibility.blacklistModels) do
                                    if string.lower(tostring(blacklisted)) == vehicleDisplayName then
                                        isCompatible = false
                                        break
                                    end
                                end
                            end
                            
                            if isCompatible then
                                local refNumber = generateReferenceNumber(11, engineId, vehicleModel)
                                local isInstalled = (currentMod == engineId)
                                local meta = engineConfig.meta or {}
                                
                                table.insert(catalog[11].mods, {
                                    id = engineId,
                                    modId = 11,
                                    modIndex = engineId,
                                    customEngineId = engineId,
                                    label = meta.label or engineId,
                                    price = GetModPrice(11, engineId, refNumber) or meta.price or 0,
                                    referenceNumber = refNumber,
                                    isInstalled = isInstalled,
                                    image = meta.icon and ("assets/icons/" .. meta.icon) or nil
                                })
                            end
                        end
                    end
                end
                
            else -- Standard mods
                -- Add stock option
                local isStock = (currentMod == -1)
                table.insert(catalog[modConfig.id].mods, {
                    id = -1,
                    modId = modConfig.id,
                    modIndex = -1,
                    label = t("stock"),
                    price = 0,
                    referenceNumber = "",
                    isInstalled = isStock
                })
                
                for modIndex = 0, numMods - 1 do
                    local refNumber = generateReferenceNumber(modConfig.id, modIndex, vehicleModel)
                    local isInstalled = (currentMod == modIndex)
                    local imageUrl = modConfig.imagePath and string.format(
                        "https://s3.nanoscripts.cloud/mechanic/%s/%s_%s_%d.webp",
                        modConfig.imagePath, modConfig.fileName, vehicleListName, modIndex
                    ) or nil
                    
                    table.insert(catalog[modConfig.id].mods, {
                        id = modIndex,
                        modId = modConfig.id,
                        modIndex = modIndex,
                        label = GetModLabel(vehicle, modConfig.id, modIndex),
                        price = GetModPrice(modConfig.id, modIndex, refNumber),
                        image = imageUrl,
                        referenceNumber = refNumber,
                        isInstalled = isInstalled
                    })
                end
            end
        end
    end
    
    return catalog
end

-- Helper: Clamp RGB value (0-255)
local function clampRgb(value)
    local num = tonumber(value)
    if not num then
        num = 0
    end
    if num < 0 then
        return 0
    end
    if num > 255 then
        return 255
    end
    return math.floor(num)
end

-- Helper: Normalize RGB input
local function normalizeRgb(rgb)
    if type(rgb) ~= "table" then
        return { r = 255, g = 255, b = 255 }
    end
    
    local r = rgb.r or rgb[1] or 255
    local g = rgb.g or rgb[2] or 255
    local b = rgb.b or rgb[3] or 255
    
    return {
        r = clampRgb(r),
        g = clampRgb(g),
        b = clampRgb(b)
    }
end

-- Create neon lights service object
local function createNeonLightsService(data)
    data = data or {}
    local action = (data.action == "remove") and "remove" or "install"
    local price = (action == "remove") and 0 or getNeonLightsPrice()
    local rgb = normalizeRgb(data.rgb or data)
    
    local description
    if action == "remove" then
        description = t("remove") or "Remove"
    else
        description = string.format("Install (RGB) (%d,%d,%d)", rgb.r, rgb.g, rgb.b)
    end
    
    return {
        id = "service-neon-lights",
        name = t("neon_lights") or "Neon Lights",
        category = "neon_lights",
        price = price,
        stats = { maxSpeed = 0, acceleration = 0, brakes = 0, suspension = 0 },
        image = "/src/assets/icons/neon-lights.png",
        description = description,
        compatible = true,
        serviceType = "neon_lights",
        neonLights = {
            action = action,
            rgb = (action == "install") and { r = rgb.r, g = rgb.g, b = rgb.b } or nil
        }
    }
end

-- Create xenon lights service object
local function createXenonLightsService(data)
    data = data or {}
    local action = (data.action == "remove") and "remove" or "install"
    local price = (action == "remove") and 0 or getXenonLightsPrice()
    local rgb = normalizeRgb(data.rgb or data)
    
    local description
    if action == "remove" then
        description = t("remove") or "Remove"
    else
        description = string.format("Install (RGB) (%d,%d,%d)", rgb.r, rgb.g, rgb.b)
    end
    
    return {
        id = "service-xenon-lights",
        name = t("xenon_lights") or "Xenon Lights",
        category = "xenon_lights",
        price = price,
        stats = { maxSpeed = 0, acceleration = 0, brakes = 0, suspension = 0 },
        image = "/src/assets/icons/xenon-lights.png",
        description = description,
        compatible = true,
        serviceType = "xenon_lights",
        xenonLights = {
            action = action,
            rgb = (action == "install") and { r = rgb.r, g = rgb.g, b = rgb.b } or nil
        }
    }
end

-- Clamp paint type (0-5)
local function clampPaintType(value)
    local num = tonumber(value)
    if num == nil then
        return 0
    end
    num = math.floor(num)
    if num < 0 then
        return 0
    end
    if num > 5 then
        return 5
    end
    return num
end

-- Get paint type name
local function getPaintTypeName(paintType)
    local names = {
        [0] = "Normal",
        [1] = "Metallic",
        [2] = "Pearl",
        [3] = "Matte",
        [4] = "Metal",
        [5] = "Chrome"
    }
    return names[paintType] or "Normal"
end

-- Cache for paint labels
local paintLabels = nil

local function loadPaintLabels()
    if paintLabels then
        return paintLabels
    end
    
    paintLabels = {}
    if Data.Paints then
        for _, paintGroup in pairs(Data.Paints) do
            if type(paintGroup) == "table" then
                for _, paint in ipairs(paintGroup) do
                    if paint and paint.id ~= nil and paint.label then
                        if paintLabels[paint.id] == nil then
                            paintLabels[paint.id] = paint.label
                        end
                    end
                end
            end
        end
    end
    return paintLabels
end

-- Get paint label by ID
local function getPaintLabel(colorId)
    local num = tonumber(colorId)
    local id = num or colorId or 0
    local labels = loadPaintLabels()
    local label = labels[id]
    if not label then
        label = string.format("Color %d", id)
    end
    return label
end

-- Get respray base price
local function getResprayBasePrice()
    local price = GetModPrice(nil, nil, nil, "colors")
    return price or 1000
end

-- Get extra colours price
local function getExtraColoursPrice()
    local price = GetModPrice(nil, nil, nil, "extra_colours")
    return price or getResprayBasePrice()
end

-- Get tyre smoke price
local function getTyreSmokePrice()
    local price = GetModPrice(nil, nil, nil, "tyre_smoke")
    return price or 0
end

-- Create respray service object
local function createResprayService(resprayData)
    local basePrice = getResprayBasePrice()
    local primary = resprayData.primary
    local secondary = resprayData.secondary
    local mode = resprayData.mode or "rgb"
    
    local description = ""
    local primaryRef = ""
    local secondaryRef = ""
    
    if mode == "stock" or (primary.colorIndex ~= nil and secondary.colorIndex ~= nil) then
        local primaryPaintName = getPaintTypeName(primary.paintType)
        local primaryColorLabel = getPaintLabel(primary.colorIndex)
        local primaryColorId = tonumber(primary.colorIndex) or 0
        
        local secondaryPaintName = getPaintTypeName(secondary.paintType)
        local secondaryColorLabel = getPaintLabel(secondary.colorIndex)
        local secondaryColorId = tonumber(secondary.colorIndex) or 0
        
        description = string.format(
            "Respray (Stock) (%s P: %s (#%d) | %s S: %s (#%d))",
            primaryPaintName, primaryColorLabel, primaryColorId,
            secondaryPaintName, secondaryColorLabel, secondaryColorId
        )
        
        primaryRef = generateResprayReferenceNumber("stock", primary.paintType, primary.colorIndex)
        secondaryRef = generateResprayReferenceNumber("stock", secondary.paintType, secondary.colorIndex)
    else
        local pr = tonumber(primary.r) or 0
        local pg = tonumber(primary.g) or 0
        local pb = tonumber(primary.b) or 0
        local sr = tonumber(secondary.r) or 0
        local sg = tonumber(secondary.g) or 0
        local sb = tonumber(secondary.b) or 0
        
        description = string.format(
            "Respray (RGB) (%s P: %d,%d,%d | %s S: %d,%d,%d)",
            getPaintTypeName(primary.paintType), pr, pg, pb,
            getPaintTypeName(secondary.paintType), sr, sg, sb
        )
        
        primaryRef = generateResprayReferenceNumber("rgb", primary.paintType, { r = pr, g = pg, b = pb })
        secondaryRef = generateResprayReferenceNumber("rgb", secondary.paintType, { r = sr, g = sg, b = sb })
    end
    
    return {
        id = "service-respray",
        name = t("respray_color") or "Respray Color",
        category = "respray",
        price = basePrice,
        stats = { maxSpeed = 0, acceleration = 0, brakes = 0, suspension = 0 },
        image = "/src/assets/icons/body.png",
        description = description,
        compatible = true,
        serviceType = "respray",
        respray = {
            mode = mode,
            primary = { primary.r or 0, primary.g or 0, primary.b or 0 },
            secondary = { secondary.r or 0, secondary.g or 0, secondary.b or 0 },
            primaryPaintType = primary.paintType,
            secondaryPaintType = secondary.paintType,
            primaryColorIndex = primary.colorIndex,
            secondaryColorIndex = secondary.colorIndex,
            primaryReferenceNumber = primaryRef,
            secondaryReferenceNumber = secondaryRef
        }
    }
end

-- Create extra colours service object
local function createExtraColoursService(extraData)
    local wheelColorIndex = extraData.wheelColorIndex
    if wheelColorIndex == nil and State.initialExtraColours then
        wheelColorIndex = State.initialExtraColours.wheelColorIndex
    end
    local wheelColorNum = tonumber(wheelColorIndex) or 0
    
    local pearlescentColorIndex = extraData.pearlescentColorIndex
    if pearlescentColorIndex == nil and State.initialExtraColours then
        pearlescentColorIndex = State.initialExtraColours.pearlescentColorIndex
    end
    local pearlescentColorNum = tonumber(pearlescentColorIndex) or 0
    
    local wheelLabel = (extraData.wheelColorIndex ~= nil) and
        string.format("%s (#%d)", getPaintLabel(wheelColorNum), wheelColorNum) or
        (t("none") or "None")
    
    local pearlLabel = (extraData.pearlescentColorIndex ~= nil) and
        string.format("%s (#%d)", getPaintLabel(pearlescentColorNum), pearlescentColorNum) or
        (t("none") or "None")
    
    local totalPrice = 0
    local hasChanges = false
    
    -- Check if wheel or pearl changes
    if extraData.wheelColorIndex ~= nil or extraData.pearlescentColorIndex ~= nil then
        if extraData.wheelColorIndex ~= nil or extraData.pearlescentColorIndex ~= nil then
            hasChanges = true
        end
    else
        local hasWheelChange = (extraData.wheelColorIndex ~= nil and tonumber(extraData.wheelColorIndex) ~= 0)
        local hasPearlChange = (extraData.pearlescentColorIndex ~= nil and tonumber(extraData.pearlescentColorIndex) ~= 0)
        if hasWheelChange or hasPearlChange then
            hasChanges = true
        end
    end
    
    if hasChanges then
        totalPrice = totalPrice + getExtraColoursPrice()
    end
    
    -- Handle tyre smoke
    local tyreSmokeRgb = extraData.tyreSmokeRgb
    local tyreSmokePrice = 0
    local hasTyreSmokeChange = false
    
    if tyreSmokeRgb then
        if State.initialTyreSmoke then
            local dr = math.abs((tyreSmokeRgb.r or 0) - State.initialTyreSmoke.r)
            local dg = math.abs((tyreSmokeRgb.g or 0) - State.initialTyreSmoke.g)
            local db = math.abs((tyreSmokeRgb.b or 0) - State.initialTyreSmoke.b)
            if dr + dg + db > 1 then
                hasTyreSmokeChange = true
            end
        else
            hasTyreSmokeChange = true
        end
    end
    
    if hasTyreSmokeChange then
        tyreSmokePrice = getTyreSmokePrice()
        totalPrice = totalPrice + tyreSmokePrice
    end
    
    -- Build description
    local description = string.format("Extra Colours (Wheel: %s | Pearl: %s", wheelLabel, pearlLabel)
    if tyreSmokeRgb then
        local hexColor = string.format("#%02X%02X%02X",
            math.max(0, math.min(255, math.floor(tyreSmokeRgb.r or 0))),
            math.max(0, math.min(255, math.floor(tyreSmokeRgb.g or 0))),
            math.max(0, math.min(255, math.floor(tyreSmokeRgb.b or 0)))
        )
        description = description .. string.format(" | Smoke: %s)", hexColor)
    else
        description = description .. ")"
    end
    
    local result = {
        id = "service-extra-colours",
        name = t("extra_colours") or "Extra Colours",
        category = "extra_colours",
        price = totalPrice,
        stats = { maxSpeed = 0, acceleration = 0, brakes = 0, suspension = 0 },
        image = "/src/assets/icons/wheels.png",
        description = description,
        compatible = true,
        serviceType = "extra_colours",
        extraColours = {
            wheelColorIndex = wheelColorNum,
            pearlescentColorIndex = pearlescentColorNum
        }
    }
    
    if tyreSmokeRgb then
        result.extraColours.tyreSmokeRgb = {
            r = tyreSmokeRgb.r,
            g = tyreSmokeRgb.g,
            b = tyreSmokeRgb.b
        }
    end
    
    return result
end

-- Apply neon lights to vehicle
local function applyNeonLights(vehicle, data)
    if not data then
        data = {}
    end
    
    local action = (data.action == "remove") and "remove" or "install"
    SetVehicleModKit(vehicle, 0)
    
    if action == "remove" then
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, false)
        end
        if DisableVehicleNeonLights then
            DisableVehicleNeonLights(vehicle, true)
        end
        return
    end
    
    local rgb = normalizeRgb(data.rgb or data)
    
    if DisableVehicleNeonLights then
        DisableVehicleNeonLights(vehicle, false)
    end
    
    for i = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, i, true)
    end
    
    SetVehicleNeonLightsColour(vehicle, rgb.r, rgb.g, rgb.b)
end

-- Apply xenon lights to vehicle
local function applyXenonLights(vehicle, data)
    if not data then
        data = {}
    end
    
    local action = (data.action == "remove") and "remove" or "install"
    SetVehicleModKit(vehicle, 0)
    
    if action == "remove" then
        ToggleVehicleMod(vehicle, 22, false)
        if ClearVehicleXenonLightsCustomColor then
            ClearVehicleXenonLightsCustomColor(vehicle)
        end
        
        if State.catalogLightsState then
            SetVehicleLights(vehicle, State.catalogLightsState.lightsOn and 2 or 0)
            SetVehicleFullbeam(vehicle, State.catalogLightsState.highbeamsOn == true)
        end
        return
    end
    
    local rgb = normalizeRgb(data.rgb or data)
    
    ToggleVehicleMod(vehicle, 22, true)
    if SetVehicleXenonLightsCustomColor then
        SetVehicleXenonLightsCustomColor(vehicle, rgb.r, rgb.g, rgb.b)
    end
    
    SetVehicleLights(vehicle, 2)
    SetVehicleFullbeam(vehicle, true)
end

-- NUI Callbacks
RegisterNUICallback("onLeftShiftPressed", function(_, cb)
    State.cameraMovementActive = not State.cameraMovementActive
    if State.cameraMovementActive then
        SetNuiFocus(false, false)
    else
        SetNuiFocus(true, true)
    end
    cb("ok")
end)

RegisterNUICallback("previewPart", function(data, cb)
    local vehicle = State.Vehicle
    
    if data.modId == 23 then -- Wheels
        if data.wheelId then
            SetVehicleWheelType(vehicle, data.wheelId)
            SetVehicleMod(vehicle, data.modId, data.modIndex, false)
        end
    elseif data.modId == 50 then -- License plates
        SetVehicleNumberPlateTextIndex(vehicle, data.modIndex)
    elseif data.modId == 51 then -- Window tint
        SetVehicleWindowTint(vehicle, data.modIndex)
    elseif data.modId == 48 then -- Liveries
        if data.liveryOldMethod then
            SetVehicleLivery(vehicle, data.modIndex)
        else
            SetVehicleMod(vehicle, 48, data.modIndex, false)
        end
    elseif data.modId == 52 then -- Extras
        if data.modIndex and DoesExtraExist(vehicle, data.modIndex) then
            SetVehicleExtra(vehicle, data.modIndex, false)
        end
    elseif data.modId == 11 then -- Engines
        if Data.CustomEngineStartIndex and data.modIndex >= Data.CustomEngineStartIndex then
            local numMods = GetNumVehicleMods(vehicle, 11) - 1
            SetVehicleMod(vehicle, 11, (numMods >= 0 and numMods) or -1, false)
        end
    else
        SetVehicleMod(vehicle, data.modId, data.modIndex, false)
    end
    
    cb("ok")
end)

function CloseCatalogUI()
    State.openPage = nil
    State.pendingCatalogOpen = nil
    
    SendNUIMessage({
        action = "setVisibility",
        data = { visible = false, page = nil }
    })
    
    SetNuiFocus(false, false)
    DisplayRadar(true)
    stopDragCam()
end