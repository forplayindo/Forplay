-- server/install/sv_order_install.lua
-- Handle order installation tracking

local orderInstalls = {}

function StartOrderInstall(orderId, shopId, vehicleNetId, callback)
    local src = source
    
    -- Get order details
    local order = MySQL.single.await('SELECT * FROM mechanic_orders WHERE id = ? AND shop_id = ?', {orderId, shopId})
    if not order then
        if callback then callback(false, "Order not found") end
        return false
    end
    
    if order.status ~= "started" then
        if callback then callback(false, "Order not in started state") end
        return false
    end
    
    -- Parse parts
    local parts = json.decode(order.parts) or {}
    
    -- Create installation record
    local installId = MySQL.insert.await([[
        INSERT INTO mechanic_order_installs (order_id, shop_id, vehicle_net_id, status, started_by, started_at)
        VALUES (?, ?, ?, 'in_progress', ?, NOW())
    ]], {orderId, shopId, vehicleNetId, src})
    
    if not installId then
        if callback then callback(false, "Failed to create install record") end
        return false
    end
    
    orderInstalls[installId] = {
        id = installId,
        orderId = orderId,
        shopId = shopId,
        vehicleNetId = vehicleNetId,
        parts = parts,
        completedParts = {},
        status = "in_progress",
        startedBy = src,
        startedAt = os.time()
    }
    
    if callback then callback(true, installId) end
    return true
end

function CompletePartInstall(installId, modId, modIndex, success, callback)
    local install = orderInstalls[installId]
    if not install then
        if callback then callback(false, "Install not found") end
        return false
    end
    
    if install.status ~= "in_progress" then
        if callback then callback(false, "Install not in progress") end
        return false
    end
    
    -- Mark part as completed
    local partKey = string.format("%d_%d", modId, modIndex or 0)
    install.completedParts[partKey] = success
    
    -- Check if all parts are completed
    local allCompleted = true
    for _, part in ipairs(install.parts) do
        local key = string.format("%d_%d", part.modId, part.modIndex or 0)
        if not install.completedParts[key] then
            allCompleted = false
            break
        end
    end
    
    if allCompleted then
        -- Update order status
        MySQL.update.await([[
            UPDATE mechanic_orders SET status = 'completed', completed_at = NOW() WHERE id = ?
        ]], {install.orderId})
        
        -- Update install record
        MySQL.update.await([[
            UPDATE mechanic_order_installs SET status = 'completed', completed_at = NOW() WHERE id = ?
        ]], {installId})
        
        install.status = "completed"
        install.completedAt = os.time()
    end
    
    if callback then callback(true) end
    return true
end

function GetOrderInstall(installId)
    return orderInstalls[installId]
end

-- Register callbacks
lib.callback.register("nn_mechanic:startOrderInstall", function(source, orderId, shopId, vehicleNetId)
    local p1, p2
    StartOrderInstall(orderId, shopId, vehicleNetId, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)

lib.callback.register("nn_mechanic:completePartInstall", function(source, installId, modId, modIndex, success)
    local p1, p2
    CompletePartInstall(installId, modId, modIndex, success, function(r1, r2)
        p1, p2 = r1, r2
    end)
    return p1, p2
end)