local bridge = exports.community_bridge.Bridge()

local shops = {}
local shopPoints = {}
local shopEmployees = {}
local shopRoles = {}
local shopPrices = {}
local shopPriceLimits = {}
local shopFinance = {}
local shopOrders = {}
local shopSupplierOrders = {}
local shopStorage = {}
local shopVehicleUpgrades = {}
local shopAirCompressors = {}
local shopWebhooks = {}
local shopPresetCache = {}

local towCalls = {}
local nextTowCallId = 1

local function GenerateOrderNumber()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local orderNumber = "ORD-"
    for i = 1, 6 do
        orderNumber = orderNumber .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return orderNumber
end

local function GenerateInvoiceNumber()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local invoiceNumber = "INV-"
    for i = 1, 6 do
        invoiceNumber = invoiceNumber .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
    end
    return invoiceNumber
end

local function GetDiscordWebhook(shopId)
    if shopWebhooks[shopId] then
        return shopWebhooks[shopId]
    end
    return Config.AdminLogsDiscordWebhook
end

local function SendDiscordLog(shopId, message, color)
    local webhook = GetDiscordWebhook(shopId)
    if not webhook or webhook == "" then
        return
    end

    local embed = {
        {
            ["color"] = color or 16711680,
            ["title"] = "Mechanic Shop Log",
            ["description"] = message,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S"),
            },
        }
    }

    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ username = "Mechanic Logs", embeds = embed }), { ['Content-Type'] = 'application/json' })
end

local function LogAction(shopId, action, details, playerId)
    local playerName = GetPlayerName(playerId)
    local logMessage = string.format("[%s] %s: %s", playerName, action, details)
    SendDiscordLog(shopId, logMessage, 3447003)
end

-- Role Management
local function LoadShopRoles(shopId)
    local roles = MySQL.query.await('SELECT * FROM mechanic_shop_roles WHERE shop_id = ?', {shopId})
    if not roles or #roles == 0 then
        for _, defaultRole in ipairs(DefaultRoles) do
            local roleName = defaultRole.name
            local permissions = json.encode(defaultRole.permissions)
            local isDefault = defaultRole.isDefault and 1 or 0
            local isOwner = defaultRole.isOwner and 1 or 0
            MySQL.insert.await('INSERT INTO mechanic_shop_roles (shop_id, name, permissions, is_default, is_owner) VALUES (?, ?, ?, ?, ?)', {shopId, roleName, permissions, isDefault, isOwner})
        end
        roles = MySQL.query.await('SELECT * FROM mechanic_shop_roles WHERE shop_id = ?', {shopId})
    end

    shopRoles[shopId] = {}
    for _, role in ipairs(roles) do
        role.permissions = json.decode(role.permissions)
        role.isDefault = role.isDefault == 1
        role.isOwner = role.isOwner == 1
        shopRoles[shopId][role.id] = role
    end
end

local function GetEmployeeRole(shopId, employeeId)
    local employee = shopEmployees[shopId] and shopEmployees[shopId][employeeId]
    if not employee then
        return nil
    end

    if employee.role_id then
        return shopRoles[shopId] and shopRoles[shopId][employee.role_id]
    end

    for _, role in pairs(shopRoles[shopId] or {}) do
        if role.name == employee.role then
            return role
        end
    end
    return nil
end

local function HasPermission(shopId, playerId, permission)
    local employee = nil
    for _, emp in pairs(shopEmployees[shopId] or {}) do
        if emp.identifier == playerId then
            employee = emp
            break
        end
    end

    if not employee then
        return false
    end

    local role = GetEmployeeRole(shopId, employee.id)
    if not role then
        return false
    end

    if role.isOwner then
        return true
    end

    return role.permissions[permission] == true
end

-- Shop Loading
local function LoadAllShops()
    local allShops = MySQL.query.await('SELECT * FROM mechanic_shops')
    for _, shop in ipairs(allShops) do
        shop.blipSprite = shop.blip_sprite
        shop.blipColor = shop.blip_color
        shop.shopLocation = json.decode(shop.shop_location)
        shop.managementLocation = json.decode(shop.management_location)
        shop.shopOperationType = shop.operation_type
        shop.shopType = shop.type
        shop.points = {}
        shop.employees = {}
        shop.roles = {}
        shop.prices = {}
        shop.storage = {}
        shop.vehicleUpgrades = {}
        shop.airCompressors = {}
        shop.webhook = shop.discord_webhook
        shops[shop.id] = shop
        LoadShopRoles(shop.id)
    end
end

local function LoadShopPoints(shopId)
    local points = MySQL.query.await('SELECT * FROM mechanic_shop_points WHERE shop_id = ?', {shopId})
    shopPoints[shopId] = {}
    for _, point in ipairs(points) do
        point.coords = json.decode(point.coords)
        if point.spawn_coords then
            point.spawnCoords = json.decode(point.spawn_coords)
        end
        if point.lift then
            point.lift = json.decode(point.lift)
        end
        if point.dyno then
            point.dyno = json.decode(point.dyno)
        end
        point.markerEnabled = point.marker_enabled == 1
        point.enabled = point.enabled == 1
        shopPoints[shopId][point.id] = point
    end
end

local function LoadShopEmployees(shopId)
    local employees = MySQL.query.await('SELECT * FROM mechanic_shop_employees WHERE shop_id = ?', {shopId})
    shopEmployees[shopId] = {}
    for _, employee in ipairs(employees) do
        employee.salary = employee.salary or 0
        employee.performance = employee.performance or 100
        employee.role_id = employee.role_id
        employee.role = employee.role
        shopEmployees[shopId][employee.id] = employee
    end
end

local function LoadShopPrices(shopId)
    local prices = MySQL.query.await('SELECT * FROM mechanic_shop_prices WHERE shop_id = ?', {shopId})
    shopPrices[shopId] = {}
    for _, price in ipairs(prices) do
        local key = string.format("%s_%s_%s_%s", price.mod_id or "nil", price.mod_index or "nil", price.category or "nil", price.reference_number or "nil")
        shopPrices[shopId][key] = price.price
    end
end

local function LoadShopPriceLimits(shopId)
    local limits = MySQL.query.await('SELECT * FROM mechanic_shop_price_limits WHERE shop_id = ?', {shopId})
    shopPriceLimits[shopId] = {}
    for _, limit in ipairs(limits) do
        shopPriceLimits[shopId][limit.target] = { min = limit.min_price, max = limit.max_price }
    end
end

local function LoadShopStorage(shopId)
    local storageItems = MySQL.query.await('SELECT * FROM mechanic_shop_storage WHERE shop_id = ?', {shopId})
    shopStorage[shopId] = {}
    for _, item in ipairs(storageItems) do
        shopStorage[shopId][item.id] = { name = item.name, metadata = json.decode(item.metadata), quantity = item.quantity }
    end
end

local function LoadShopVehicleUpgrades(shopId)
    local upgrades = MySQL.query.await('SELECT * FROM mechanic_shop_vehicle_upgrades WHERE shop_id = ?', {shopId})
    shopVehicleUpgrades[shopId] = {}
    for _, upgrade in ipairs(upgrades) do
        upgrade.interactionLocation = json.decode(upgrade.interaction_location)
        upgrade.vehicleSpawnLocation = json.decode(upgrade.vehicle_spawn_location)
        upgrade.markerEnabled = upgrade.marker_enabled == 1
        shopVehicleUpgrades[shopId][upgrade.id] = upgrade
    end
end

local function LoadShopAirCompressors(shopId)
    local compressors = MySQL.query.await('SELECT * FROM mechanic_shop_air_compressors WHERE shop_id = ?', {shopId})
    shopAirCompressors[shopId] = {}
    for _, compressor in ipairs(compressors) do
        compressor.coords = json.decode(compressor.coords)
        shopAirCompressors[shopId][compressor.id] = compressor
    end
end

local function LoadShopWebhook(shopId)
    local webhook = MySQL.query.await('SELECT discord_webhook FROM mechanic_shops WHERE id = ?', {shopId})
    if webhook and webhook[1] then
        shopWebhooks[shopId] = webhook[1].discord_webhook
    end
end

local function LoadShopFinance(shopId)
    local finance = MySQL.query.await('SELECT * FROM mechanic_shop_finance WHERE shop_id = ?', {shopId})
    if finance and finance[1] then
        shopFinance[shopId] = { balance = finance[1].balance }
    else
        MySQL.insert.await('INSERT INTO mechanic_shop_finance (shop_id, balance) VALUES (?, ?)', {shopId, 0})
        shopFinance[shopId] = { balance = 0 }
    end
end

local function LoadShopOrders(shopId)
    local orders = MySQL.query.await('SELECT * FROM mechanic_orders WHERE shop_id = ?', {shopId})
    shopOrders[shopId] = {}
    for _, order in ipairs(orders) do
        order.parts = json.decode(order.parts)
        order.notes = order.notes
        order.started_by = order.started_by
        order.started_at = order.started_at
        order.completed_at = order.completed_at
        order.paid_at = order.paid_at
        shopOrders[shopId][order.id] = order
    end
end

local function LoadShopSupplierOrders(shopId)
    local supplierOrders = MySQL.query.await('SELECT * FROM mechanic_supplier_orders WHERE shop_id = ?', {shopId})
    shopSupplierOrders[shopId] = {}
    for _, order in ipairs(supplierOrders) do
        order.items = json.decode(order.items)
        order.delivered_at = order.delivered_at
        order.collected_at = order.collected_at
        shopSupplierOrders[shopId][order.id] = order
    end
end

local function LoadAllShopData()
    LoadAllShops()
    for shopId, _ in pairs(shops) do
        LoadShopPoints(shopId)
        LoadShopEmployees(shopId)
        LoadShopPrices(shopId)
        LoadShopPriceLimits(shopId)
        LoadShopStorage(shopId)
        LoadShopVehicleUpgrades(shopId)
        LoadShopAirCompressors(shopId)
        LoadShopWebhook(shopId)
        LoadShopFinance(shopId)
        LoadShopOrders(shopId)
        LoadShopSupplierOrders(shopId)
    end
end

-- Item Management
local function AddItemToStorage(shopId, itemName, quantity, metadata)
    local existingItem = nil
    for id, item in pairs(shopStorage[shopId] or {}) do
        if item.name == itemName and json.encode(item.metadata) == json.encode(metadata) then
            existingItem = id
            break
        end
    end

    if existingItem then
        local newQuantity = shopStorage[shopId][existingItem].quantity + quantity
        MySQL.update.await('UPDATE mechanic_shop_storage SET quantity = ? WHERE id = ?', {newQuantity, existingItem})
        shopStorage[shopId][existingItem].quantity = newQuantity
    else
        local result = MySQL.insert.await('INSERT INTO mechanic_shop_storage (shop_id, name, metadata, quantity) VALUES (?, ?, ?, ?)', {shopId, itemName, json.encode(metadata), quantity})
        shopStorage[shopId][result] = { name = itemName, metadata = metadata, quantity = quantity }
    end
end

local function RemoveItemFromStorage(shopId, itemId, quantity)
    local item = shopStorage[shopId][itemId]
    if not item then
        return false
    end

    if item.quantity < quantity then
        return false
    end

    local newQuantity = item.quantity - quantity
    if newQuantity <= 0 then
        MySQL.update.await('DELETE FROM mechanic_shop_storage WHERE id = ?', {itemId})
        shopStorage[shopId][itemId] = nil
    else
        MySQL.update.await('UPDATE mechanic_shop_storage SET quantity = ? WHERE id = ?', {newQuantity, itemId})
        shopStorage[shopId][itemId].quantity = newQuantity
    end
    return true
end

-- Financial Transactions
local function AddTransaction(shopId, amount, transactionType, description, playerId)
    local playerName = GetPlayerName(playerId)
    MySQL.insert.await('INSERT INTO mechanic_shop_transactions (shop_id, amount, type, description, performed_by) VALUES (?, ?, ?, ?, ?)', {shopId, amount, transactionType, description, playerName})
    if transactionType == "income" then
        MySQL.update.await('UPDATE mechanic_shop_finance SET balance = balance + ? WHERE shop_id = ?', {amount, shopId})
        shopFinance[shopId].balance = shopFinance[shopId].balance + amount
    elseif transactionType == "expense" then
        MySQL.update.await('UPDATE mechanic_shop_finance SET balance = balance - ? WHERE shop_id = ?', {amount, shopId})
        shopFinance[shopId].balance = shopFinance[shopId].balance - amount
    end
end

local function UpdateShopBalance(shopId, amount, transactionType, description, playerId)
    if transactionType == "expense" and shopFinance[shopId].balance < amount then
        return false
    end
    AddTransaction(shopId, amount, transactionType, description, playerId)
    return true
end

-- Order Management
local function CreateOrder(shopId, customerId, customerName, vehiclePlate, vehicleName, items, notes, employeeId)
    local orderNumber = GenerateOrderNumber()
    local parts = {}
    for _, item in ipairs(items) do
        table.insert(parts, {
            referenceNumber = item.referenceNumber,
            modId = item.modId,
            modIndex = item.modIndex,
            label = item.label,
            price = item.price,
            quantity = item.quantity,
            installed = false,
            serviceType = item.serviceType,
            respray = item.respray,
            extraColours = item.extraColours,
            neonLights = item.neonLights,
            xenonLights = item.xenonLights,
            liveryOldMethod = item.liveryOldMethod,
            wheelId = item.wheelId,
            customEngineId = item.customEngineId,
        })
    end

    local totalPrice = 0
    for _, item in ipairs(items) do
        totalPrice = totalPrice + (item.price * item.quantity)
    end

    local result = MySQL.insert.await('INSERT INTO mechanic_orders (shop_id, order_number, customer_id, customer_name, vehicle_plate, vehicle_name, parts, notes, total_price, status, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        shopId, orderNumber, customerId, customerName, vehiclePlate, vehicleName, json.encode(parts), notes, totalPrice, "pending", employeeId
    })

    local newOrder = {
        id = result,
        shop_id = shopId,
        order_number = orderNumber,
        customer_id = customerId,
        customer_name = customerName,
        vehicle_plate = vehiclePlate,
        vehicle_name = vehicleName,
        parts = parts,
        notes = notes,
        total_price = totalPrice,
        status = "pending",
        created_by = employeeId,
        created_at = os.time(),
        started_by = nil,
        started_at = nil,
        completed_at = nil,
        paid_at = nil,
    }
    shopOrders[shopId][result] = newOrder
    return newOrder
end

local function UpdateOrderStatus(shopId, orderId, status, employeeId)
    local order = shopOrders[shopId][orderId]
    if not order then
        return false
    end

    local updates = { status = status }
    if status == "started" then
        updates.started_by = employeeId
        updates.started_at = os.time()
    elseif status == "completed" then
        updates.completed_at = os.time()
    elseif status == "cancelled" then
        updates.completed_at = os.time()
    end

    local setClause = {}
    local values = {}
    for k, v in pairs(updates) do
        table.insert(setClause, k .. " = ?")
        table.insert(values, v)
    end
    table.insert(values, orderId)
    MySQL.update.await('UPDATE mechanic_orders SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)

    for k, v in pairs(updates) do
        order[k] = v
    end
    return true
end

local function UpdateOrderPartStatus(shopId, orderId, partIndex, installed, employeeId)
    local order = shopOrders[shopId][orderId]
    if not order then
        return false
    end

    order.parts[partIndex + 1].installed = installed
    MySQL.update.await('UPDATE mechanic_orders SET parts = ? WHERE id = ?', {json.encode(order.parts), orderId})
    return true
end

-- Supplier Order Management
local function CreateSupplierOrder(shopId, supplierCode, items, totalPrice, employeeId)
    local orderNumber = GenerateOrderNumber()
    local result = MySQL.insert.await('INSERT INTO mechanic_supplier_orders (shop_id, order_number, supplier_code, items, total_price, status, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        shopId, orderNumber, supplierCode, json.encode(items), totalPrice, "pending", employeeId
    })

    local newOrder = {
        id = result,
        shop_id = shopId,
        order_number = orderNumber,
        supplier_code = supplierCode,
        items = items,
        total_price = totalPrice,
        status = "pending",
        created_by = employeeId,
        created_at = os.time(),
        delivered_at = nil,
        collected_at = nil,
    }
    shopSupplierOrders[shopId][result] = newOrder

    if Config.InstantPartDelivery then
        local deliveryTime = Config.Rarity.baseDeliveryTime or 1
        SetTimeout(deliveryTime * 60 * 1000, function()
            if shopSupplierOrders[shopId][result] then
                shopSupplierOrders[shopId][result].status = "delivered"
                shopSupplierOrders[shopId][result].delivered_at = os.time()
                MySQL.update.await('UPDATE mechanic_supplier_orders SET status = ?, delivered_at = ? WHERE id = ?', {"delivered", os.time(), result})
                TriggerClientEvent('nn_mechanic:supplierOrderDelivered', -1, shopId, result)
            end
        end)
    end

    return newOrder
end

-- Invoice Management
local function CreateInvoice(shopId, orderId, customerId, customerName, vehiclePlate, vehicleName, items, notes, employeeId)
    local invoiceNumber = GenerateInvoiceNumber()
    local totalPrice = 0
    for _, item in ipairs(items) do
        totalPrice = totalPrice + (item.price * item.quantity)
    end

    local result = MySQL.insert.await('INSERT INTO mechanic_invoices (shop_id, invoice_number, order_id, customer_id, customer_name, vehicle_plate, vehicle_name, items, notes, total_price, status, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        shopId, invoiceNumber, orderId, customerId, customerName, vehiclePlate, vehicleName, json.encode(items), notes, totalPrice, "draft", employeeId
    })

    local newInvoice = {
        id = result,
        shop_id = shopId,
        invoice_number = invoiceNumber,
        order_id = orderId,
        customer_id = customerId,
        customer_name = customerName,
        vehicle_plate = vehiclePlate,
        vehicle_name = vehicleName,
        items = items,
        notes = notes,
        total_price = totalPrice,
        status = "draft",
        created_by = employeeId,
        created_at = os.time(),
        sent_at = nil,
        paid_at = nil,
    }
    return newInvoice
end

local function UpdateInvoiceStatus(invoiceId, status, paymentMethod)
    local invoice = MySQL.query.await('SELECT * FROM mechanic_invoices WHERE id = ?', {invoiceId})
    if not invoice or #invoice == 0 then
        return false
    end
    invoice = invoice[1]

    local updates = { status = status }
    if status == "sent" then
        updates.sent_at = os.time()
    elseif status == "paid" then
        updates.paid_at = os.time()
        updates.payment_method = paymentMethod
    end

    local setClause = {}
    local values = {}
    for k, v in pairs(updates) do
        table.insert(setClause, k .. " = ?")
        table.insert(values, v)
    end
    table.insert(values, invoiceId)
    MySQL.update.await('UPDATE mechanic_invoices SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)
    return true
end

-- Tow Call Management
local function CreateTowCall(callerId, callerName, vehicleName, vehiclePlate, vehicleColor, location, reason, phone)
    local callId = nextTowCallId
    nextTowCallId = nextTowCallId + 1
    towCalls[callId] = {
        id = callId,
        callerId = callerId,
        callerName = callerName,
        vehicleName = vehicleName,
        vehiclePlate = vehiclePlate,
        vehicleColor = vehicleColor,
        location = location,
        reason = reason,
        phone = phone,
        status = "pending",
        acceptedBy = nil,
        acceptedByName = nil,
        createdAt = os.time(),
        expiresAt = os.time() + (Config.TowDispatch.CallTimeout * 60),
    }

    SetTimeout(Config.TowDispatch.CallTimeout * 60 * 1000, function()
        if towCalls[callId] and towCalls[callId].status == "pending" then
            towCalls[callId].status = "expired"
            TriggerClientEvent('nn_mechanic:towCallExpired', callerId)
            TriggerClientEvent('nn_mechanic:removeTowCall', -1, callId)
        end
    end)

    return callId
end

lib.callback.register('nn_mechanic:checkIsAdmin', function(source)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local isAdmin = MySQL.query.await('SELECT is_admin FROM mechanic_admins WHERE identifier = ?', {playerIdentifier})
    return isAdmin and #isAdmin > 0
end)

lib.callback.register('nn_mechanic:hasItem', function(source, itemName, count)
    count = count or 1
    return bridge.Inventory.HasItem(source, itemName, count)
end)

lib.callback.register('nn_mechanic:consumeItem', function(source, itemName, count)
    count = count or 1
    return bridge.Inventory.RemoveItem(source, itemName, count)
end)

lib.callback.register('nn_mechanic:hasBrakePadItem', function(source, padType)
    local itemName = "brake_pads_" .. padType
    return bridge.Inventory.HasItem(source, itemName, 1)
end)

lib.callback.register('nn_mechanic:removeBrakePadItem', function(source, padType)
    local itemName = "brake_pads_" .. padType
    return bridge.Inventory.RemoveItem(source, itemName, 1)
end)

lib.callback.register('nn_mechanic:hasOilType', function(source, oilType)
    local itemName = "mechanic_oil_" .. oilType
    return bridge.Inventory.HasItem(source, itemName, 1)
end)

lib.callback.register('nn_mechanic:removeOilItem', function(source, itemName)
    return bridge.Inventory.RemoveItem(source, itemName, 1)
end)

lib.callback.register('nn_mechanic:hasEmptySprayGun', function(source)
    return bridge.Inventory.HasItem(source, "empty_spray_gun", 1)
end)

lib.callback.register('nn_mechanic:getPlayerShop', function(source)
    print("[nn_mechanic:server] getPlayerShop called by source: " .. tostring(source))
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    for shopId, employees in pairs(shopEmployees) do
        for _, employee in pairs(employees) do
            if employee.identifier == playerIdentifier then
                return { shop = shops[shopId], employee = employee }
            end
        end
    end
    return nil
end)

lib.callback.register('nn_mechanic:getAllShops', function(source)
    print("[nn_mechanic:server] getAllShops called by source: " .. tostring(source))
    local allShops = {}
    for _, shop in pairs(shops) do
        table.insert(allShops, shop)
    end
    return allShops
end)

lib.callback.register('nn_mechanic:getAllPoints', function(source)
    print("[nn_mechanic:server] getAllPoints called by source: " .. tostring(source))
    return shopPoints
end)

lib.callback.register('nn_mechanic:getShopById', function(source, shopId)
    return shops[tonumber(shopId)]
end)

lib.callback.register('nn_mechanic:getShopOrders', function(source, shopId)
    local orders = {}
    for _, order in pairs(shopOrders[shopId] or {}) do
        table.insert(orders, order)
    end
    table.sort(orders, function(a, b) return a.created_at > b.created_at end)
    return orders
end)

lib.callback.register('nn_mechanic:getOrderById', function(source, orderId)
    for shopId, orders in pairs(shopOrders) do
        for _, order in pairs(orders) do
            if tostring(order.id) == tostring(orderId) then
                return order
            end
        end
    end
    return nil
end)

lib.callback.register('nn_mechanic:getOrderByNumber', function(source, orderNumber)
    for shopId, orders in pairs(shopOrders) do
        for _, order in pairs(orders) do
            if order.order_number == orderNumber then
                return order
            end
        end
    end
    return nil
end)

lib.callback.register('nn_mechanic:getVehicleTireData', function(source, plate, wheelIndex)
    local stateBagKey = ("entity:%s"):format(plate)
    local pressure = GetStateBagValue(stateBagKey, ("ns_psi%s"):format(wheelIndex))
    local tread = GetStateBagValue(stateBagKey, ("ns_tr%s"):format(wheelIndex))
    local burst = GetStateBagValue(stateBagKey, ("ns_burst%s"):format(wheelIndex))

    return {
        psi = pressure or 320,
        tread = tread or 10000,
        burst = burst == 1,
    }
end)

lib.callback.register('nn_mechanic:getBrakePadData', function(source, plate)
    local stateBagKey = ("entity:%s"):format(plate)
    local front = GetStateBagValue(stateBagKey, "ns_brake_front")
    local rear = GetStateBagValue(stateBagKey, "ns_brake_rear")
    local heat = GetStateBagValue(stateBagKey, "ns_brake_heat")

    return {
        front = front or 10000,
        rear = rear or 10000,
        heat = heat or 0,
    }
end)

lib.callback.register('nn_mechanic:getVehicleStanceData', function(source, plate)
    local stateBagKey = ("entity:%s"):format(plate)
    local stanceData = GetStateBagValue(stateBagKey, "nn_vehicle_stance")
    if stanceData then
        return json.decode(stanceData)
    end
    return nil
end)

lib.callback.register('nn_mechanic:getVehicleNeonEffect', function(source, plate)
    local stateBagKey = ("entity:%s"):format(plate)
    return GetStateBagValue(stateBagKey, "nn_neon_effect") or "static"
end)

lib.callback.register('nn_mechanic:getVehicleNeonColor', function(source, plate)
    local stateBagKey = ("entity:%s"):format(plate)
    return GetStateBagValue(stateBagKey, "nn_neon_color") or "#FFFFFF"
end)

lib.callback.register('nn_mechanic:getVehicleNeonZones', function(source, plate)
    local stateBagKey = ("entity:%s"):format(plate)
    return GetStateBagValue(stateBagKey, "nn_neon_zones") or "{}"
end)

lib.callback.register('nn_mechanic:getClosestShop', function(source, x, y, z)
    local closestShopId = nil
    local closestDistance = nil
    for shopId, shop in pairs(shops) do
        if shop.shopLocation then
            local distance = #(vector3(x, y, z) - vector3(shop.shopLocation.x, shop.shopLocation.y, shop.shopLocation.z))
            if not closestDistance or distance < closestDistance then
                closestDistance = distance
                closestShopId = shopId
            end
        end
    end
    if closestShopId then
        local shop = shops[closestShopId]
        return closestShopId, shop.shopLocation
    end
    return nil, nil
end)

lib.callback.register('nn_mechanic:getAllAirCompressors', function(source)
    return shopAirCompressors
end)

lib.callback.register('nn_mechanic:getShopForAdminManagement', function(source, shopId)
    if not HasPermission(shopId, source, 'management') then
        return nil
    end
    return { shop = shops[shopId] }
end)

lib.callback.register('nn_mechanic:getPublicShops', function(source)
    local publicShops = {}
    for _, shop in pairs(shops) do
        if shop.shopType == "public" then
            table.insert(publicShops, shop)
        end
    end
    return publicShops
end)

lib.callback.register('nn_mechanic:canAdminManageShops', function(source)
    print("[nn_mechanic:server] canAdminManageShops called by source: " .. tostring(source))
    return lib.callback.await('nn_mechanic:checkIsAdmin', source)
end)

lib.callback.register('nn_mechanic:getShopPrices', function(source)
    if not State.currentShopId then
        return nil
    end
    return { prices = shopPrices[State.currentShopId] or {}, defaultMarkup = Config.DefaultShopMarkup, supplierPrices = Data.Prices }
end)

lib.callback.register('nn_mechanic:getPriceLimits', function(source)
    if not State.currentShopId then
        return nil
    end
    return { limits = shopPriceLimits[State.currentShopId] or {} }
end)

lib.callback.register('nn_mechanic:getAllShopPrices', function(source, shopId)
    return shopPrices[shopId] or {}
end)

lib.callback.register('nn_mechanic:getServicePointCtx', function(source, shopId, pointId)
    return nil
end)

lib.callback.register('nn_mechanic:getNearbyPlayersAdmin', function(source)
    local players = {}
    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    for _, playerId in ipairs(GetPlayers()) do
        if tonumber(playerId) ~= source then
            local ped = GetPlayerPed(playerId)
            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local distance = #(sourceCoords - coords)
                if distance < 10.0 then
                    table.insert(players, { id = playerId, name = GetPlayerName(playerId), distance = distance })
                end
            end
        end
    end
    table.sort(players, function(a, b) return a.distance < b.distance end)
    return players
end)

lib.callback.register('nn_mechanic:getCurrentAdminInfo', function(source)
    return { id = source, name = GetPlayerName(source) }
end)

lib.callback.register('nn_mechanic:getRepairHistory', function(source, plate, vin, limit)
    local history = MySQL.query.await('SELECT * FROM mechanic_repair_history WHERE vehicle_plate = ? OR vehicle_vin = ? ORDER BY repaired_at DESC LIMIT ?', {plate, vin, limit})
    return history
end)

lib.callback.register('nn_mechanic:collectPickup', function(source, shopId, supplierCode, currentOrderNumber)
    local employee = nil
    for _, emp in pairs(shopEmployees[shopId] or {}) do
        if emp.identifier == GetPlayerIdentifierByType(source, 'license') then
            employee = emp
            break
        end
    end

    if not employee then
        return { success = false, error = t('not_an_employee') }
    end

    local ordersToCollect = {}
    if currentOrderNumber then
        for _, order in pairs(shopSupplierOrders[shopId] or {}) do
            if order.order_number == currentOrderNumber and order.supplier_code == supplierCode and order.status == "delivered" then
                ordersToCollect = { order }
                break
            end
        end
    else
        for _, order in pairs(shopSupplierOrders[shopId] or {}) do
            if order.supplier_code == supplierCode and order.status == "delivered" then
                table.insert(ordersToCollect, order)
            end
        end
    end

    if #ordersToCollect == 0 then
        return { success = false, error = t('pickup_no_deliveries') }
    end

    local totalItems = 0
    for _, order in ipairs(ordersToCollect) do
        for _, item in ipairs(order.items) do
            AddItemToStorage(shopId, item.name, item.quantity, item.metadata or {})
            totalItems = totalItems + item.quantity
        end
        order.status = "collected"
        order.collected_at = os.time()
        MySQL.update.await('UPDATE mechanic_supplier_orders SET status = ?, collected_at = ? WHERE id = ?', {"collected", os.time(), order.id})
    end

    LogAction(shopId, "Order Collected", string.format("Collected %d items from %d order(s)", totalItems, #ordersToCollect), source)
    return { success = true, itemCount = totalItems }
end)

lib.callback.register('nn_mechanic:getAllWarehousePeds', function(source)
    return shopWarehousePeds
end)

-- Event Handlers
RegisterNetEvent('nn_mechanic:createShop', function(shopData)
    local src = source
    local playerId = src
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local playerName = GetPlayerName(playerId)

    if not lib.callback.await('nn_mechanic:checkIsAdmin', src) then
        return
    end

    local shopLocation = json.encode(shopData.shopLocation)
    local managementLocation = json.encode(shopData.managementLocation)
    local result = MySQL.insert.await('INSERT INTO mechanic_shops (name, description, logo_url, blip_sprite, blip_color, shop_location, management_location, type, operation_type, discord_webhook) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        shopData.name, shopData.description, shopData.logoUrl, shopData.blipSprite, shopData.blipColor, shopLocation, managementLocation, shopData.shopType, shopData.operationType, shopData.discordWebhook
    })

    local newShopId = result
    shops[newShopId] = {
        id = newShopId,
        name = shopData.name,
        description = shopData.description,
        logoUrl = shopData.logoUrl,
        blipSprite = shopData.blipSprite,
        blipColor = shopData.blipColor,
        shopLocation = shopData.shopLocation,
        managementLocation = shopData.managementLocation,
        shopType = shopData.shopType,
        shopOperationType = shopData.operationType,
        discordWebhook = shopData.discordWebhook,
        points = {},
        employees = {},
        roles = {},
        prices = {},
        storage = {},
        vehicleUpgrades = {},
        airCompressors = {},
        webhook = shopData.discordWebhook,
    }

    LoadShopRoles(newShopId)
    LoadShopFinance(newShopId)

    local ownerRoleId = nil
    for id, role in pairs(shopRoles[newShopId]) do
        if role.isOwner then
            ownerRoleId = id
            break
        end
    end

    local employeeResult = MySQL.insert.await('INSERT INTO mechanic_shop_employees (shop_id, identifier, name, role_id, role, salary, performance, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        newShopId, playerIdentifier, playerName, ownerRoleId, "Owner", 0, 100, 1
    })

    shopEmployees[newShopId] = shopEmployees[newShopId] or {}
    shopEmployees[newShopId][employeeResult] = {
        id = employeeResult,
        shop_id = newShopId,
        identifier = playerIdentifier,
        name = playerName,
        role_id = ownerRoleId,
        role = "Owner",
        salary = 0,
        performance = 100,
        is_active = 1,
    }

    LogAction(newShopId, "Shop Created", string.format("Shop %s created", shopData.name), src)
    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
end)

RegisterNetEvent('nn_mechanic:updateShopInformation', function(data)
    local src = source
    if not HasPermission(data.id, src, 'management') then
        return
    end

    local updates = {}
    if data.name then updates.name = data.name end
    if data.description then updates.description = data.description end
    if data.logoUrl then updates.logo_url = data.logoUrl end
    if data.blipSprite then updates.blip_sprite = data.blipSprite end
    if data.blipColor then updates.blip_color = data.blipColor end
    if data.shopType then updates.type = data.shopType end
    if data.operationType then updates.operation_type = data.operationType end
    if data.discordWebhook then updates.discord_webhook = data.discordWebhook end

    if next(updates) then
        local setClause = {}
        local values = {}
        for k, v in pairs(updates) do
            table.insert(setClause, k .. " = ?")
            table.insert(values, v)
        end
        table.insert(values, data.id)
        MySQL.update.await('UPDATE mechanic_shops SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)

        for k, v in pairs(updates) do
            shops[data.id][k] = v
        end

        if updates.discord_webhook then
            shopWebhooks[data.id] = updates.discord_webhook
        end

        TriggerClientEvent('nn_mechanic:updateShopState', -1, { shop = shops[data.id] })
        LogAction(data.id, "Shop Updated", "Shop information updated", src)
    end
end)

RegisterNetEvent('nn_mechanic:addPoint', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local coords = json.encode(data.coords)
    local spawnCoords = data.spawnCoords and json.encode(data.spawnCoords) or nil
    local lift = data.lift and json.encode(data.lift) or nil
    local dyno = data.dyno and json.encode(data.dyno) or nil
    local prop = data.prop or nil

    local result = MySQL.insert.await('INSERT INTO mechanic_shop_points (shop_id, name, type, coords, spawn_coords, lift, dyno, prop, marker_enabled, enabled) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.shopId, data.name, data.type, coords, spawnCoords, lift, dyno, prop, data.markerEnabled and 1 or 0, data.enabled and 1 or 0
    })

    local newPoint = {
        id = result,
        shop_id = data.shopId,
        name = data.name,
        type = data.type,
        coords = data.coords,
        spawnCoords = data.spawnCoords,
        lift = data.lift,
        dyno = data.dyno,
        prop = data.prop,
        markerEnabled = data.markerEnabled,
        enabled = data.enabled,
    }
    shopPoints[data.shopId][result] = newPoint

    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
    LogAction(data.shopId, "Point Added", string.format("Added point %s (%s)", data.name, data.type), src)
end)

RegisterNetEvent('nn_mechanic:updatePoint', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local point = shopPoints[data.shopId][data.pointId]
    if not point then
        return
    end

    local updates = {}
    if data.updates.name then updates.name = data.updates.name end
    if data.updates.type then updates.type = data.updates.type end
    if data.updates.coords then updates.coords = json.encode(data.updates.coords) end
    if data.updates.spawnCoords then updates.spawn_coords = json.encode(data.updates.spawnCoords) end
    if data.updates.lift then updates.lift = json.encode(data.updates.lift) end
    if data.updates.dyno then updates.dyno = json.encode(data.updates.dyno) end
    if data.updates.prop then updates.prop = data.updates.prop end
    if data.updates.markerEnabled ~= nil then updates.marker_enabled = data.updates.markerEnabled and 1 or 0 end
    if data.updates.enabled ~= nil then updates.enabled = data.updates.enabled and 1 or 0 end

    if next(updates) then
        local setClause = {}
        local values = {}
        for k, v in pairs(updates) do
            table.insert(setClause, k .. " = ?")
            table.insert(values, v)
        end
        table.insert(values, data.pointId)
        MySQL.update.await('UPDATE mechanic_shop_points SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)

        for k, v in pairs(data.updates) do
            point[k] = v
        end
        if data.updates.coords then point.coords = data.updates.coords end
        if data.updates.spawnCoords then point.spawnCoords = data.updates.spawnCoords end
        if data.updates.lift then point.lift = data.updates.lift end
        if data.updates.dyno then point.dyno = data.updates.dyno end

        TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
        LogAction(data.shopId, "Point Updated", string.format("Updated point %s", point.name), src)
    end
end)

RegisterNetEvent('nn_mechanic:removePoint', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    MySQL.update.await('DELETE FROM mechanic_shop_points WHERE id = ?', {data.pointId})
    shopPoints[data.shopId][data.pointId] = nil

    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
    LogAction(data.shopId, "Point Removed", string.format("Removed point ID %d", data.pointId), src)
end)

RegisterNetEvent('nn_mechanic:updateVehicleUpgradeLocations', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local upgrade = shopVehicleUpgrades[data.shopId][data.upgradeId]
    if not upgrade then
        return
    end

    local updates = {}
    if data.interactionLocation then
        updates.interaction_location = json.encode(data.interactionLocation)
        upgrade.interactionLocation = data.interactionLocation
    end
    if data.vehicleSpawnLocation then
        updates.vehicle_spawn_location = json.encode(data.vehicleSpawnLocation)
        upgrade.vehicleSpawnLocation = data.vehicleSpawnLocation
    end

    if next(updates) then
        local setClause = {}
        local values = {}
        for k, v in pairs(updates) do
            table.insert(setClause, k .. " = ?")
            table.insert(values, v)
        end
        table.insert(values, data.upgradeId)
        MySQL.update.await('UPDATE mechanic_shop_vehicle_upgrades SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)

        TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
        LogAction(data.shopId, "Upgrade Locations Updated", string.format("Updated locations for upgrade %s", data.upgradeId), src)
    end
end)

RegisterNetEvent('nn_mechanic:toggleVehicleUpgradeMarker', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local upgrade = shopVehicleUpgrades[data.shopId][data.upgradeId]
    if not upgrade then
        return
    end

    local markerEnabled = data.markerEnabled and 1 or 0
    MySQL.update.await('UPDATE mechanic_shop_vehicle_upgrades SET marker_enabled = ? WHERE id = ?', {markerEnabled, data.upgradeId})
    upgrade.markerEnabled = data.markerEnabled

    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
    LogAction(data.shopId, "Marker Toggled", string.format("Toggled marker for upgrade %s: %s", data.upgradeId, data.markerEnabled), src)
end)

RegisterNetEvent('nn_mechanic:hireEmployee', function(shopId)
    local src = source
    if not HasPermission(shopId, src, 'hire_fire') then
        return
    end

    local closestPlayer, distance = GetClosestPlayer(src)
    if not closestPlayer or distance > 3.0 then
        TriggerClientEvent('chat:addMessage', src, { args = { "System", "No player nearby" } })
        return
    end

    local playerIdentifier = GetPlayerIdentifierByType(closestPlayer, 'license')
    local playerName = GetPlayerName(closestPlayer)

    local defaultRoleId = nil
    for id, role in pairs(shopRoles[shopId]) do
        if role.isDefault then
            defaultRoleId = id
            break
        end
    end

    local result = MySQL.insert.await('INSERT INTO mechanic_shop_employees (shop_id, identifier, name, role_id, role, salary, performance, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        shopId, playerIdentifier, playerName, defaultRoleId, "Mechanic", 0, 100, 1
    })

    shopEmployees[shopId][result] = {
        id = result,
        shop_id = shopId,
        identifier = playerIdentifier,
        name = playerName,
        role_id = defaultRoleId,
        role = "Mechanic",
        salary = 0,
        performance = 100,
        is_active = 1,
    }

    TriggerClientEvent('nn_mechanic:updateShopState', closestPlayer, { shop = shops[shopId], employee = shopEmployees[shopId][result] })
    TriggerClientEvent('chat:addMessage', src, { args = { "System", "Employee hired successfully" } })
    LogAction(shopId, "Employee Hired", string.format("Hired %s", playerName), src)
end)

RegisterNetEvent('nn_mechanic:fireEmployee', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'hire_fire') then
        return
    end

    local employee = shopEmployees[data.shopId][data.employeeId]
    if not employee then
        return
    end

    local employeeIdentifier = employee.identifier
    MySQL.update.await('DELETE FROM mechanic_shop_employees WHERE id = ?', {data.employeeId})
    shopEmployees[data.shopId][data.employeeId] = nil

    for playerId, _ in pairs(GetPlayers()) do
        local identifier = GetPlayerIdentifierByType(playerId, 'license')
        if identifier == employeeIdentifier then
            TriggerClientEvent('nn_mechanic:clearShopAccess', playerId)
            TriggerClientEvent('chat:addMessage', playerId, { args = { "System", t("you_have_been_fired") } })
            break
        end
    end

    TriggerClientEvent('nn_mechanic:updateShopState', -1, { shop = shops[data.shopId] })
    LogAction(data.shopId, "Employee Fired", string.format("Fired %s", employee.name), src)
end)

RegisterNetEvent('nn_mechanic:updateEmployee', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local employee = shopEmployees[data.shopId][data.employeeId]
    if not employee then
        return
    end

    local updates = {}
    if data.role_id then updates.role_id = data.role_id end
    if data.salary then updates.salary = data.salary end
    if data.performance then updates.performance = data.performance end

    if next(updates) then
        local setClause = {}
        local values = {}
        for k, v in pairs(updates) do
            table.insert(setClause, k .. " = ?")
            table.insert(values, v)
        end
        table.insert(values, data.employeeId)
        MySQL.update.await('UPDATE mechanic_shop_employees SET ' .. table.concat(setClause, ", ") .. ' WHERE id = ?', values)

        for k, v in pairs(updates) do
            employee[k] = v
        end

        if data.role_id then
            local role = shopRoles[data.shopId][data.role_id]
            if role then
                employee.role = role.name
            end
        end

        local employeeIdentifier = employee.identifier
        for playerId, _ in pairs(GetPlayers()) do
            local identifier = GetPlayerIdentifierByType(playerId, 'license')
            if identifier == employeeIdentifier then
                TriggerClientEvent('nn_mechanic:updateShopState', playerId, { shop = shops[data.shopId], employee = employee })
                break
            end
        end

        LogAction(data.shopId, "Employee Updated", string.format("Updated %s: %s", employee.name, json.encode(updates)), src)
    end
end)

RegisterNetEvent('nn_mechanic:depositMoney', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'finance') then
        return
    end

    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        return
    end

    if not bridge.Inventory.RemoveItem(src, "money", amount) then
        return
    end

    UpdateShopBalance(data.shopId, amount, "income", "Cash deposit", src)
    TriggerClientEvent('chat:addMessage', src, { args = { "System", string.format("Deposited $%d", amount) } })
    LogAction(data.shopId, "Money Deposited", string.format("Deposited $%d", amount), src)
end)

RegisterNetEvent('nn_mechanic:withdrawMoney', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'finance') then
        return
    end

    local amount = tonumber(data.amount)
    if not amount or amount <= 0 then
        return
    end

    if shopFinance[data.shopId].balance < amount then
        return
    end

    UpdateShopBalance(data.shopId, amount, "expense", "Cash withdrawal", src)
    bridge.Inventory.AddItem(src, "money", amount)
    TriggerClientEvent('chat:addMessage', src, { args = { "System", string.format("Withdrew $%d", amount) } })
    LogAction(data.shopId, "Money Withdrawn", string.format("Withdrew $%d", amount), src)
end)

RegisterNetEvent('nn_mechanic:payAllSalaries', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'finance') then
        return
    end

    local totalSalaries = 0
    for _, employee in pairs(shopEmployees[data.shopId]) do
        totalSalaries = totalSalaries + employee.salary
    end

    if totalSalaries <= 0 then
        return
    end

    if shopFinance[data.shopId].balance < totalSalaries then
        return
    end

    UpdateShopBalance(data.shopId, totalSalaries, "expense", "Salary payments", src)

    for _, employee in pairs(shopEmployees[data.shopId]) do
        if employee.salary > 0 then
            local playerId = nil
            for pid, _ in pairs(GetPlayers()) do
                local identifier = GetPlayerIdentifierByType(pid, 'license')
                if identifier == employee.identifier then
                    playerId = pid
                    break
                end
            end
            if playerId then
                bridge.Inventory.AddItem(playerId, "money", employee.salary)
                TriggerClientEvent('chat:addMessage', playerId, { args = { "System", string.format("You received $%d salary", employee.salary) } })
            end
        end
    end

    TriggerClientEvent('chat:addMessage', src, { args = { "System", string.format("Paid $%d in salaries", totalSalaries) } })
    LogAction(data.shopId, "Salaries Paid", string.format("Paid $%d in salaries", totalSalaries), src)
end)

RegisterNetEvent('nn_mechanic:purchaseVehicleUpgrade', function(data)
    local src = source
    if not HasPermission(data.shopId, src, 'management') then
        return
    end

    local upgrade = Config.VehicleUpgrades[data.upgradeId]
    if not upgrade then
        return
    end

    if shopFinance[data.shopId].balance < upgrade.price then
        return
    end

    UpdateShopBalance(data.shopId, upgrade.price, "expense", string.format("Purchased %s", upgrade.label), src)

    local result = MySQL.insert.await('INSERT INTO mechanic_shop_vehicle_upgrades (shop_id, upgrade_id, model, label, price, purchased_at) VALUES (?, ?, ?, ?, ?, ?)', {
        data.shopId, data.upgradeId, upgrade.model, upgrade.label, upgrade.price, os.time()
    })

    shopVehicleUpgrades[data.shopId][result] = {
        id = result,
        shop_id = data.shopId,
        upgrade_id = data.upgradeId,
        model = upgrade.model,
        label = upgrade.label,
        price = upgrade.price,
        purchased_at = os.time(),
        interactionLocation = nil,
        vehicleSpawnLocation = nil,
        markerEnabled = false,
    }

    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
    LogAction(data.shopId, "Upgrade Purchased", string.format("Purchased %s", upgrade.label), src)
end)

RegisterNetEvent('nn_mechanic:createOrder', function(data)
    local src = source
    local playerId = src
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local playerName = GetPlayerName(playerId)

    local shopId = data.shopId
    if not HasPermission(shopId, src, 'orders') then
        return
    end

    local employeeId = nil
    for id, employee in pairs(shopEmployees[shopId]) do
        if employee.identifier == playerIdentifier then
            employeeId = id
            break
        end
    end

    if not employeeId then
        return
    end

    local newOrder = CreateOrder(shopId, data.customerId, data.customerName, data.vehiclePlate, data.vehicleName, data.items, data.notes, employeeId)
    TriggerClientEvent('nn_mechanic:refreshOrders', src)
    LogAction(shopId, "Order Created", string.format("Created order %s for %s", newOrder.order_number, data.customerName), src)
end)

RegisterNetEvent('nn_mechanic:updateOrderStatus', function(orderId, status)
    local src = source
    for shopId, orders in pairs(shopOrders) do
        if orders[orderId] then
            if not HasPermission(shopId, src, 'orders') then
                return
            end
            UpdateOrderStatus(shopId, orderId, status, src)
            TriggerClientEvent('nn_mechanic:refreshOrders', src)
            LogAction(shopId, "Order Status Updated", string.format("Order %s status: %s", orderId, status), src)
            break
        end
    end
end)

RegisterNetEvent('nn_mechanic:startOrder', function(orderId)
    local src = source
    for shopId, orders in pairs(shopOrders) do
        if orders[orderId] then
            if not HasPermission(shopId, src, 'orders') then
                return
            end
            UpdateOrderStatus(shopId, orderId, "started", src)
            TriggerClientEvent('nn_mechanic:refreshOrders', src)
            LogAction(shopId, "Order Started", string.format("Started order %s", orderId), src)
            break
        end
    end
end)

RegisterNetEvent('nn_mechanic:cancelOrder', function(orderId)
    local src = source
    for shopId, orders in pairs(shopOrders) do
        if orders[orderId] then
            if not HasPermission(shopId, src, 'orders') then
                return
            end
            UpdateOrderStatus(shopId, orderId, "cancelled", src)
            TriggerClientEvent('nn_mechanic:refreshOrders', src)
            LogAction(shopId, "Order Cancelled", string.format("Cancelled order %s", orderId), src)
            break
        end
    end
end)

RegisterNetEvent('nn_mechanic:updateOrderPartStatusSync', function(orderId, partIndex, installed)
    local src = source
    for shopId, orders in pairs(shopOrders) do
        if orders[orderId] then
            if not HasPermission(shopId, src, 'orders') then
                return
            end
            UpdateOrderPartStatus(shopId, orderId, partIndex, installed, src)
            TriggerClientEvent('nn_mechanic:refreshOrders', src)
            LogAction(shopId, "Part Installed", string.format("Part %d installed for order %s", partIndex + 1, orderId), src)
            break
        end
    end
end)

RegisterNetEvent('nn_mechanic:sendInvoice', function(orderId)
    local src = source
    for shopId, orders in pairs(shopOrders) do
        if orders[orderId] then
            if not HasPermission(shopId, src, 'orders') then
                return
            end

            local order = orders[orderId]
            if order.status ~= "completed" then
                return
            end

            if order.paid_at then
                return
            end

            local items = {}
            for _, part in ipairs(order.parts) do
                table.insert(items, {
                    name = part.label or ("Part " .. (part.modId or "Unknown")),
                    quantity = 1,
                    price = part.price,
                })
            end

            local invoice = CreateInvoice(shopId, orderId, order.customer_id, order.customer_name, order.vehicle_plate, order.vehicle_name, items, order.notes, src)
            UpdateInvoiceStatus(invoice.id, "sent", nil)

            local customerId = order.customer_id
            if customerId then
                TriggerClientEvent('nn_mechanic:receiveInvoice', customerId, invoice)
            end

            TriggerClientEvent('nn_mechanic:refreshOrders', src)
            LogAction(shopId, "Invoice Sent", string.format("Sent invoice %s for order %s", invoice.invoice_number, orderId), src)
            break
        end
    end
end)

RegisterNetEvent('nn_mechanic:payInvoice', function(invoiceId, paymentMethod)
    local src = source
    local invoice = MySQL.query.await('SELECT * FROM mechanic_invoices WHERE id = ?', {invoiceId})
    if not invoice or #invoice == 0 then
        return
    end
    invoice = invoice[1]

    if invoice.status ~= "sent" and invoice.status ~= "unpaid" then
        return
    end

    local totalPrice = invoice.total_price
    local playerMoney = 0
    if paymentMethod == "cash" then
        playerMoney = bridge.Inventory.GetItemCount(src, "money")
        if playerMoney < totalPrice then
            return
        end
        bridge.Inventory.RemoveItem(src, "money", totalPrice)
    elseif paymentMethod == "bank" then
        playerMoney = bridge.Inventory.GetItemCount(src, "bank")
        if playerMoney < totalPrice then
            return
        end
        bridge.Inventory.RemoveItem(src, "bank", totalPrice)
    else
        return
    end

    UpdateInvoiceStatus(invoiceId, "paid", paymentMethod)

    local shopId = invoice.shop_id
    local employeeShare = math.floor(totalPrice * Config.PlayerShare)
    local shopShare = totalPrice - employeeShare

    UpdateShopBalance(shopId, shopShare, "income", string.format("Invoice payment (%s)", invoice.invoice_number), src)

    local employeeIdentifier = invoice.created_by
    for playerId, _ in pairs(GetPlayers()) do
        local identifier = GetPlayerIdentifierByType(playerId, 'license')
        if identifier == employeeIdentifier then
            bridge.Inventory.AddItem(playerId, "money", employeeShare)
            TriggerClientEvent('chat:addMessage', playerId, { args = { "System", string.format("You received $%d from invoice %s", employeeShare, invoice.invoice_number) } })
            break
        end
    end

    if invoice.order_id then
        UpdateOrderStatus(shopId, invoice.order_id, "paid", src)
    end

    LogAction(shopId, "Invoice Paid", string.format("Invoice %s paid for $%d via %s", invoice.invoice_number, totalPrice, paymentMethod), src)
    TriggerClientEvent('chat:addMessage', src, { args = { "System", string.format("Paid $%d", totalPrice) } })
end)

RegisterNetEvent('nn_mechanic:declineInvoice', function(invoiceId)
    local src = source
    local invoice = MySQL.query.await('SELECT * FROM mechanic_invoices WHERE id = ?', {invoiceId})
    if not invoice or #invoice == 0 then
        return
    end
    invoice = invoice[1]

    if invoice.status ~= "sent" and invoice.status ~= "unpaid" then
        return
    end

    UpdateInvoiceStatus(invoiceId, "declined", nil)
    TriggerClientEvent('chat:addMessage', src, { args = { "System", "Invoice declined" } })
end)

RegisterNetEvent('nn_mechanic:saveVehicleProps', function(vehicleProps)
    local src = source
    if IsVehicleOwned(src, vehicleProps.plate) then
        if GetResourceState('qbx_core') == 'started' or GetResourceState('qb-core') == 'started' then
            MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
        elseif GetResourceState('es_extended') == 'started' then
            MySQL.update.await('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
        end
    end
end)

RegisterNetEvent('nn_mechanic:setVehicleStanceData', function(plate, stanceData)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_vehicle_stance", stanceData, true)
end)

RegisterNetEvent('nn_mechanic:setVehicleNeonEffect', function(plate, effect)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_neon_effect", effect, true)
end)

RegisterNetEvent('nn_mechanic:setVehicleNeonColor', function(plate, color)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_neon_color", color, true)
end)

RegisterNetEvent('nn_mechanic:setVehicleNeonZones', function(plate, zones)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_neon_zones", zones, true)
end)

RegisterNetEvent('nn_mechanic:takeControlNeonEffect', function(plate)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_neon_effect_owner", source, true)
end)

RegisterNetEvent('nn_mechanic:releaseControlNeonEffect', function(plate)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "nn_neon_effect_owner", nil, true)
end)

RegisterNetEvent('nn_mechanic:changeBrakePads', function(vehicleNetId, axis)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local stateBagKey = ("entity:%s"):format(plate)
    if axis == "front" then
        SetStateBagValue(stateBagKey, "ns_brake_front", 10000, true)
    else
        SetStateBagValue(stateBagKey, "ns_brake_rear", 10000, true)
    end
end)

RegisterNetEvent('nn_mechanic:setVehicleTirePressure', function(plate, wheelIndex, pressure)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, ("ns_psi%s"):format(wheelIndex), pressure * 10, true)
end)

RegisterNetEvent('nn_mechanic:setVehicleTireBurst', function(plate, wheelIndex, burst)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, ("ns_burst%s"):format(wheelIndex), burst and 1 or 0, true)
end)

RegisterNetEvent('nn_mechanic:resetTireDataForWheel', function(plate, wheelIndex)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, ("ns_psi%s"):format(wheelIndex), 320, true)
    SetStateBagValue(stateBagKey, ("ns_tr%s"):format(wheelIndex), 10000, true)
    SetStateBagValue(stateBagKey, ("ns_burst%s"):format(wheelIndex), 0, true)
end)

RegisterNetEvent('nn_mechanic:changeOilForVehicle', function(vehicleNetId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local stateBagKey = ("entity:%s"):format(plate)
    SetStateBagValue(stateBagKey, "ns_oil_quality", 10000, true)
end)

RegisterNetEvent('nn_mechanic:setCustomEngine', function(vehicleNetId, customEngineId)
    local stateBagKey = ("entity:%d"):format(vehicleNetId)
    SetStateBagValue(stateBagKey, "nn_custom_engine", customEngineId, true)
end)

RegisterNetEvent('nn_mechanic:clearCustomEngine', function(vehicleNetId)
    local stateBagKey = ("entity:%d"):format(vehicleNetId)
    SetStateBagValue(stateBagKey, "nn_custom_engine", nil, true)
end)

RegisterNetEvent('nn_mechanic:startOilParticle', function(vehicleNetId, vehicleCoords)
    TriggerClientEvent('nn_mechanic:startOilParticle', -1, vehicleNetId, vehicleCoords)
end)

RegisterNetEvent('nn_mechanic:stopOilParticle', function(vehicleNetId)
    TriggerClientEvent('nn_mechanic:stopOilParticle', -1, vehicleNetId)
end)

RegisterNetEvent('nn_mechanic:setVehicleWheelXOffsets', function(vehicleNetId, offsets)
    local stateBagKey = ("entity:%d"):format(vehicleNetId)
    SetStateBagValue(stateBagKey, "nn_wheel_x_offsets", offsets, true)
end)

RegisterNetEvent('nn_mechanic:setVehicleWheelXOffsetsSynced', function(vehicleNetId, offsets)
    local stateBagKey = ("entity:%d"):format(vehicleNetId)
    SetStateBagValue(stateBagKey, "nn_wheel_x_offsets", offsets, true)
end)

RegisterNetEvent('nn_mechanic:createTowCall', function(details)
    local src = source
    local playerName = GetPlayerName(src)
    local callId = CreateTowCall(src, playerName, details.vehicleName, details.vehiclePlate, details.vehicleColor, details.location, details.reason, details.phone)

    TriggerClientEvent('nn_mechanic:newTowCall', -1, { id = callId, callerName = playerName, vehicleName = details.vehicleName, vehiclePlate = details.vehiclePlate, vehicleColor = details.vehicleColor, location = details.location, reason = details.reason, status = "pending", createdAt = os.time() })
    TriggerClientEvent('chat:addMessage', src, { args = { "System", t("tow_call_placed") } })
end)

lib.callback.register('nn_mechanic:getTowCalls', function(source)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local myActiveCall = nil

    for id, call in pairs(towCalls) do
        if call.acceptedBy == playerIdentifier then
            myActiveCall = id
            break
        end
    end

    local calls = {}
    for _, call in pairs(towCalls) do
        if call.status == "pending" or call.status == "accepted" then
            table.insert(calls, call)
        end
    end

    return { success = true, calls = calls, myActiveCall = myActiveCall }
end)

lib.callback.register('nn_mechanic:takeTowCall', function(source, callId)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local playerName = GetPlayerName(playerId)

    local call = towCalls[callId]
    if not call or call.status ~= "pending" then
        return { success = false, error = "Call not available" }
    end

    call.status = "accepted"
    call.acceptedBy = playerIdentifier
    call.acceptedByName = playerName

    TriggerClientEvent('nn_mechanic:towCallTaken', -1, { callId = callId, acceptedBy = playerIdentifier, acceptedByName = playerName })
    TriggerClientEvent('nn_mechanic:towCallAccepted', call.callerId, { mechanicName = playerName })
    return { success = true }
end)

lib.callback.register('nn_mechanic:releaseTowCall', function(source, callId)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')

    local call = towCalls[callId]
    if not call or call.acceptedBy ~= playerIdentifier then
        return { success = false, error = "Not your call" }
    end

    call.status = "pending"
    call.acceptedBy = nil
    call.acceptedByName = nil

    TriggerClientEvent('nn_mechanic:towCallReleased', -1, { callId = callId })
    TriggerClientEvent('nn_mechanic:towCallCancelled', call.callerId, { cancelledBy = "mechanic" })
    return { success = true }
end)

lib.callback.register('nn_mechanic:completeTowCall', function(source, callId)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')

    local call = towCalls[callId]
    if not call or call.acceptedBy ~= playerIdentifier then
        return { success = false, error = "Not your call" }
    end

    local distance = #(GetEntityCoords(GetPlayerPed(playerId)) - vector3(call.location.x, call.location.y, call.location.z))
    local price = Config.TowDispatch.BaseTowPrice + math.floor(distance / 1609.34) * Config.TowDispatch.PricePerMile

    local employeeShare = math.floor(price * Config.PlayerShare)
    local shopShare = price - employeeShare

    local shopId = nil
    for _, employee in pairs(shopEmployees) do
        for _, emp in pairs(employee) do
            if emp.identifier == playerIdentifier then
                shopId = emp.shop_id
                break
            end
        end
    end

    if shopId then
        UpdateShopBalance(shopId, shopShare, "income", string.format("Tow service (Call #%d)", callId), playerId)
        bridge.Inventory.AddItem(playerId, "money", employeeShare)
    else
        bridge.Inventory.AddItem(playerId, "money", price)
    end

    TriggerClientEvent('nn_mechanic:towCallCompleted', call.callerId, { price = price })
    TriggerClientEvent('nn_mechanic:removeTowCall', -1, callId)
    towCalls[callId] = nil

    return { success = true, price = price }
end)

lib.callback.register('nn_mechanic:canOpenTowDispatch', function(source)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    for shopId, employees in pairs(shopEmployees) do
        for _, employee in pairs(employees) do
            if employee.identifier == playerIdentifier then
                return true
            end
        end
    end
    return false
end)

lib.callback.register('nn_mechanic:isPlayerEmployee', function(source)
    local playerId = source
    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    for shopId, employees in pairs(shopEmployees) do
        for _, employee in pairs(employees) do
            if employee.identifier == playerIdentifier then
                return { isEmployee = true, shopId = shopId, employee = employee }
            end
        end
    end
    return { isEmployee = false }
end)

lib.callback.register('nn_mechanic:saveRepairHistory', function(source, data)
    MySQL.insert.await('INSERT INTO mechanic_repair_history (vehicle_plate, vehicle_vin, vehicle_model, repair_target, procedure_id, procedure_label, health_before, health_after, cost, repaired_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.vehiclePlate, data.vehicleVin, data.vehicleModel, data.repairTarget, data.procedureId, data.procedureLabel, data.healthBefore, data.healthAfter, data.cost, GetPlayerName(source)
    })
    return true
end)

lib.callback.register('nn_mechanic:preset:status', function(source)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end
    return { ok = true }
end)

lib.callback.register('nn_mechanic:preset:browse', function(source, query)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "browse"
    local response = PerformHttpRequest(apiUrl, 'GET', json.encode(query), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:get', function(source, presetId)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "get"
    local response = PerformHttpRequest(apiUrl, 'GET', json.encode({ id = presetId }), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:submit', function(source, payload)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "submit"
    local response = PerformHttpRequest(apiUrl, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:apply', function(source, presetId, targetShopId)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "apply"
    local response = PerformHttpRequest(apiUrl, 'POST', json.encode({ id = presetId, target_shop = targetShopId }), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:vote', function(source, presetId, voteType)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "vote"
    local response = PerformHttpRequest(apiUrl, 'POST', json.encode({ id = presetId, vote = voteType }), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:report', function(source, presetId, reason, notes)
    if not Config.PresetService or not Config.PresetService.enabled then
        return { error = "disabled" }
    end

    local apiUrl = Config.PresetService.apiUrl .. "report"
    local response = PerformHttpRequest(apiUrl, 'POST', json.encode({ id = presetId, reason = reason, notes = notes }), { ['Content-Type'] = 'application/json' })
    if response.code ~= 200 then
        return { error = "http_error" }
    end
    return json.decode(response.data)
end)

lib.callback.register('nn_mechanic:preset:exportPreview', function(source, shopId, presetType)
    if not HasPermission(shopId, source, 'management') then
        return { error = "not_authorized" }
    end

    if presetType == "layout" then
        if not shops[shopId] or not shops[shopId].shopLocation then
            return { error = "preset_err_shop_has_no_location" }
        end

        local points = {}
        for _, point in pairs(shopPoints[shopId] or {}) do
            if point.type == "car_lift" or point.type == "storage" or point.type == "part_deposit" or point.type == "color_mixing" or point.type == "dyno_station" then
                table.insert(points, {
                    type = point.type,
                    coords = point.coords,
                    spawn_coords = point.spawnCoords,
                    lift = point.lift,
                    dyno = point.dyno,
                    prop = point.prop,
                    marker_enabled = point.markerEnabled,
                })
            end
        end

        if #points == 0 then
            return { error = "preset_err_shop_has_no_points" }
        end

        local preset = {
            type = "layout",
            shop_type = shops[shopId].shopType,
            operation_type = shops[shopId].shopOperationType,
            anchor = shops[shopId].shopLocation,
            points = points,
        }
        return { success = true, preview = preset }

    elseif presetType == "management" then
        local roles = {}
        for _, role in pairs(shopRoles[shopId] or {}) do
            if not role.isOwner then
                table.insert(roles, {
                    name = role.name,
                    permissions = role.permissions,
                    is_default = role.isDefault,
                })
            end
        end

        if #roles == 0 then
            return { error = "preset_err_shop_has_no_custom_roles" }
        end

        local preset = {
            type = "management",
            roles = roles,
        }
        return { success = true, preview = preset }

    else
        return { error = "preset_err_unknown_preset_type" }
    end
end)

-- Admin Management
lib.callback.register('nn_mechanic:adminGetAllShops', function(source)
    if not lib.callback.await('nn_mechanic:checkIsAdmin', source) then
        return { success = false }
    end
    return { success = true, shops = shops }
end)

lib.callback.register('nn_mechanic:adminDeleteShop', function(source, shopId, password)
    if not lib.callback.await('nn_mechanic:checkIsAdmin', source) then
        return { success = false, error = "Not authorized" }
    end

    if password ~= Config.AdminPanel.DeletePassword then
        return { success = false, error = "Invalid password" }
    end

    MySQL.update.await('DELETE FROM mechanic_shops WHERE id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_points WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_employees WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_roles WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_prices WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_price_limits WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_storage WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_finance WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_orders WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_supplier_orders WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_vehicle_upgrades WHERE shop_id = ?', {shopId})
    MySQL.update.await('DELETE FROM mechanic_shop_air_compressors WHERE shop_id = ?', {shopId})

    shops[shopId] = nil
    shopPoints[shopId] = nil
    shopEmployees[shopId] = nil
    shopRoles[shopId] = nil
    shopPrices[shopId] = nil
    shopPriceLimits[shopId] = nil
    shopStorage[shopId] = nil
    shopFinance[shopId] = nil
    shopOrders[shopId] = nil
    shopSupplierOrders[shopId] = nil
    shopVehicleUpgrades[shopId] = nil
    shopAirCompressors[shopId] = nil
    shopWebhooks[shopId] = nil

    TriggerClientEvent('nn_mechanic:removeShopBlip', -1, shopId)
    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)

    LogAction(shopId, "Shop Deleted", string.format("Deleted shop ID %d", shopId), source)
    return { success = true }
end)

lib.callback.register('nn_mechanic:adminSetShopOwner', function(source, data)
    if not lib.callback.await('nn_mechanic:checkIsAdmin', source) then
        return { success = false, error = "Not authorized" }
    end

    local shopId = data.shopId
    local playerId = data.playerId

    local playerIdentifier = GetPlayerIdentifierByType(playerId, 'license')
    local playerName = GetPlayerName(playerId)

    local ownerRoleId = nil
    for id, role in pairs(shopRoles[shopId]) do
        if role.isOwner then
            ownerRoleId = id
            break
        end
    end

    if not ownerRoleId then
        return { success = false, error = "Owner role not found" }
    end

    for id, employee in pairs(shopEmployees[shopId]) do
        if employee.identifier == playerIdentifier then
            MySQL.update.await('UPDATE mechanic_shop_employees SET role_id = ?, role = ? WHERE id = ?', {ownerRoleId, "Owner", id})
            employee.role_id = ownerRoleId
            employee.role = "Owner"
            break
        end
    end

    TriggerClientEvent('nn_mechanic:reinitializeShop', -1)
    LogAction(shopId, "Owner Set", string.format("Set %s as owner", playerName), source)
    return { success = true }
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        LoadAllShopData()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, call in pairs(towCalls) do
            if call.status == "pending" then
                TriggerClientEvent('nn_mechanic:towCallExpired', call.callerId)
            end
        end
    end
end)