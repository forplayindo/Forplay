local view -- nil | 'menu' | 'orders' | 'supplier'

local function open(action, data)
    view = action == 'openMenu' and 'menu' or action == 'openSupplier' and 'supplier' or 'orders'
    SendNUIMessage({ action = action, data = data })
    SetNuiFocus(true, true)
end

local function close()
    view = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function OpenMenu()
    if view then return end
    local data = lib.callback.await('f_cafe:getMenu', false)
    if not data then return end
    data.images = 'nui://ox_inventory/web/images/'
    open('openMenu', data)
end

function OpenOrders()
    if view then return end
    local orders = lib.callback.await('f_cafe:getOrders', false)
    if not orders then return lib.notify({ title = Config.Label, description = 'Kamu harus on duty.', type = 'error' }) end
    open('openOrders', { label = Config.Label, orders = orders })
end

-- Manager: panel supplier (beli bahan ke kulkas, dibayar rekening organisasi)
function OpenSupplier()
    if view then return end
    local data = lib.callback.await('f_cafe:getSupplier', false)
    if not data then return lib.notify({ title = Config.Label, description = 'Hanya Manager yang bisa restock.', type = 'error' }) end
    data.images = 'nui://ox_inventory/web/images/'
    open('openSupplier', data)
end

RegisterNUICallback('supplierBuy', function(data, cb)
    if view ~= 'supplier' then return cb({ ok = false, msg = 'Menu tidak terbuka.' }) end
    local res = lib.callback.await('f_cafe:restockCart', false, data.cart)
    if res and res.msg then lib.notify({ title = Config.Label, description = res.msg, type = res.ok and 'success' or 'error' }) end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

function RefreshOrders()
    if view ~= 'orders' then return end
    local orders = lib.callback.await('f_cafe:getOrders', false)
    if not orders then return close() end
    SendNUIMessage({ action = 'orders', data = orders })
end

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('order', function(data, cb)
    local res = lib.callback.await('f_cafe:placeOrder', false, data.cart, data.method)
    if res and res.ok then
        if res.paid then
            lib.notify({ title = Config.Label, type = 'success',
                description = res.npc and ('Order #%s dibayar. Pesanan sudah masuk inventory.'):format(res.code)
                    or ('Order #%s dibayar. Tunggu pesananmu di kasir.'):format(res.code) })
        else
            lib.notify({ title = Config.Label, type = 'inform', duration = 8000,
                description = ('Invoice order #%s dikirim ke HP. Bayar lewat Bank dalam %d menit.'):format(res.code, res.timeout) })
        end
        close()
    end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_cafe:getOrders', false) or {})
end)

RegisterNUICallback('serve', function(data, cb)
    local res = lib.callback.await('f_cafe:serveOrder', false, data.code)
    if res and res.msg then lib.notify({ title = Config.Label, description = res.msg, type = res.ok and 'success' or 'error' }) end
    cb(res or { ok = false })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and view then SetNuiFocus(false, false) end
end)
