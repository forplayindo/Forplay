local ox = exports.ox_inventory
local FRIDGE, READY = Config.Stash.fridge.id, Config.Stash.ready.id

local MenuByItem = {}
for _, m in ipairs(Config.Menu) do MenuByItem[m.item] = m end

local SupplierByItem = {}
for _, s in ipairs(Config.Supplier) do SupplierByItem[s.item] = s end

local Orders = {}        -- [code] = order (status unpaid / paid)
local ByInvoice = {}     -- [invoiceId] = code
local Promos = {}        -- [id] = { id, label, food, drink, price }
local Cooking = {}       -- [src] = sesi masak aktif
local Cooldowns = {}     -- [src..action] = GetGameTimer()

---------------------------------------------------------------------------
-- Util
---------------------------------------------------------------------------
local function notify(src, msg, typ) Bridge.Notify(src, msg, typ) end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityCoords(ped) or nil
end

local function near(src, point, dist)
    local c = coordsOf(src)
    return c ~= nil and #(c - point) <= dist
end

local function throttle(src, action, ms)
    local key = src .. action
    local now = GetGameTimer()
    if Cooldowns[key] and now - Cooldowns[key] < ms then return false end
    Cooldowns[key] = now
    return true
end

local function isInt(n, min, max)
    return type(n) == 'number' and n == math.floor(n) and n >= min and n <= max
end

--- job pemain jika karyawan cafe (opsional: harus on duty & grade minimal)
local function staffJob(src, minGrade, needDuty)
    local job = Bridge.GetJob(src)
    if not job or job.name ~= Config.Job then return end
    if needDuty ~= false and not job.onduty then return end
    if job.grade < (minGrade or 0) then return end
    return job
end

local function itemLabel(name)
    local m = MenuByItem[name] or SupplierByItem[name]
    if m then return m.label end
    local def = ox:Items(name)
    return def and def.label or name
end

local function newCode()
    local code
    repeat code = ('CF%04d'):format(math.random(0, 9999)) until not Orders[code]
    return code
end

---------------------------------------------------------------------------
-- Staff on duty (GlobalState dipakai client untuk spawn NPC)
---------------------------------------------------------------------------
local function staffOnDuty()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if staffJob(src, 0, true) then list[#list + 1] = src end
    end
    return list
end

local function refreshStaffCount()
    local n = #staffOnDuty()
    if GlobalState.cafeStaff ~= n then GlobalState.cafeStaff = n end
    return n
end

CreateThread(function()
    while true do
        refreshStaffCount()
        Wait(20000)
    end
end)

AddEventHandler('QBCore:Server:SetDuty', function() SetTimeout(500, refreshStaffCount) end)
AddEventHandler('QBCore:Server:OnJobUpdate', function() SetTimeout(500, refreshStaffCount) end)

local function broadcastStaff(event, data)
    for _, src in ipairs(staffOnDuty()) do TriggerClientEvent(event, src, data) end
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
local function saveOrder(o)
    MySQL.prepare.await([[
        INSERT INTO cafe_orders (code, citizenid, name, order_lines, needs, total, method, mode, status, invoice_id, reserved, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE mode = VALUES(mode), status = VALUES(status), reserved = VALUES(reserved), updated_at = VALUES(updated_at)
    ]], { o.code, o.citizenid, o.name, json.encode(o.lines), json.encode(o.needs), o.total, o.method, o.mode, o.status,
          o.invoice, o.reserved and 1 or 0, o.created, os.time() })
end

local function setStatus(o, status)
    o.status = status
    o.updated = os.time()
    saveOrder(o)
    if status ~= 'unpaid' and status ~= 'paid' then
        Orders[o.code] = nil
        if o.invoice then ByInvoice[o.invoice] = nil end
    end
end

---------------------------------------------------------------------------
-- Stok
---------------------------------------------------------------------------
local function stockOf(inv, item) return ox:GetItemCount(inv, item) or 0 end

--- daftar item yang kurang: { {item, label, need, have} }
local function shortage(inv, needs)
    local short = {}
    for item, need in pairs(needs) do
        local have = stockOf(inv, item)
        if have < need then short[#short + 1] = { item = item, label = itemLabel(item), need = need, have = have } end
    end
    return short
end

local function removeAll(inv, needs)
    for item, count in pairs(needs) do ox:RemoveItem(inv, item, count) end
end

local function addAll(inv, needs)
    for item, count in pairs(needs) do ox:AddItem(inv, item, count) end
end

local function needsWeight(needs)
    local w = 0
    for item, count in pairs(needs) do
        local def = ox:Items(item)
        w = w + (def and def.weight or 0) * count
    end
    return w
end

--- Kirim item ke pemain (dengan kadaluarsa dari definisi item). Sisa yang tidak muat di-drop di kaki pemain.
local function giveToCustomer(src, needs)
    local dropped = {}
    for item, count in pairs(needs) do
        if ox:CanCarryItem(src, item, count) then
            if not ox:AddItem(src, item, count) then dropped[#dropped + 1] = { item, count } end
        else
            dropped[#dropped + 1] = { item, count }
        end
    end
    if #dropped > 0 then
        ox:CustomDrop(Config.Label, dropped, coordsOf(src))
        notify(src, 'Tas kamu penuh, sebagian pesanan diletakkan di lantai dekatmu.', 'warning')
    end
end

---------------------------------------------------------------------------
-- Keranjang -> order
---------------------------------------------------------------------------
local function buildOrder(cart)
    if type(cart) ~= 'table' or #cart == 0 or #cart > Config.Order.maxLines then return end
    local lines, needs, total, seen = {}, {}, 0, {}

    for _, row in ipairs(cart) do
        if type(row) ~= 'table' then return end
        local qty = tonumber(row.qty)
        if not qty or not isInt(qty, Config.Order.minQty, Config.Order.maxQty) then return end
        local key = tostring(row.kind) .. ':' .. tostring(row.id)
        if seen[key] then return end
        seen[key] = true

        if row.kind == 'item' then
            local m = MenuByItem[row.id]
            if not m then return end
            lines[#lines + 1] = { kind = 'item', id = m.item, label = m.label, qty = qty, price = m.price }
            needs[m.item] = (needs[m.item] or 0) + qty
            total = total + m.price * qty
        elseif row.kind == 'promo' then
            local p = Promos[tonumber(row.id)]
            if not p then return end
            lines[#lines + 1] = { kind = 'promo', id = p.id, label = p.label, qty = qty, price = p.price,
                                  sub = ('%s + %s'):format(itemLabel(p.food), itemLabel(p.drink)) }
            needs[p.food] = (needs[p.food] or 0) + qty
            needs[p.drink] = (needs[p.drink] or 0) + qty
            total = total + p.price * qty
        else
            return
        end
    end
    return lines, needs, total
end

local function activeOrderOf(cid)
    for _, o in pairs(Orders) do
        if o.citizenid == cid then return o end
    end
end

local function publicOrder(o)
    local needs = {}
    local ready = true
    for item, need in pairs(o.needs) do
        local have = stockOf(READY, item)
        if have < need then ready = false end
        needs[#needs + 1] = { item = item, label = itemLabel(item), need = need, have = have }
    end
    table.sort(needs, function(a, b) return a.label < b.label end)
    return {
        code = o.code, name = o.name, lines = o.lines, needs = needs, total = o.total,
        method = o.method, status = o.status, ready = ready, time = o.paidAt or o.created,
    }
end

local function onOrderPaid(o)
    o.paidAt = os.time()
    local src = Bridge.GetSourceByCitizenId(o.citizenid)

    if o.mode == 'npc' and o.reserved then
        if src then
            giveToCustomer(src, o.needs)
            o.reserved = false
            setStatus(o, 'delivered')
            notify(src, ('Pembayaran #%s diterima. Pesanan sudah masuk ke inventory kamu. Selamat menikmati!'):format(o.code), 'success')
            return
        end
        -- pelanggan offline setelah bayar: kembalikan stok & jadikan order untuk karyawan
        addAll(READY, o.needs)
        o.reserved = false
        o.mode = 'staff'
    end

    setStatus(o, 'paid')
    if src then notify(src, ('Pembayaran #%s diterima. Mohon tunggu, pesanan sedang disiapkan.'):format(o.code), 'success') end
    broadcastStaff('f_cafe:client:newOrder', { code = o.code, name = o.name, total = o.total })
end

---------------------------------------------------------------------------
-- Customer: menu & order
---------------------------------------------------------------------------
local function promoList()
    local list = {}
    for _, p in pairs(Promos) do
        local normal = (MenuByItem[p.food] and MenuByItem[p.food].price or 0) + (MenuByItem[p.drink] and MenuByItem[p.drink].price or 0)
        list[#list + 1] = {
            id = p.id, label = p.label, price = p.price, normal = normal,
            food = p.food, drink = p.drink, foodLabel = itemLabel(p.food), drinkLabel = itemLabel(p.drink),
            emoji = (MenuByItem[p.food] and MenuByItem[p.food].emoji or '') .. (MenuByItem[p.drink] and MenuByItem[p.drink].emoji or ''),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---Pelanggan wajib membawa KTP / KTP Sementara miliknya yang masih berlaku (f_idcard).
---@return string? message alasan ditolak
local function identityError(src)
    local ok, valid, message = pcall(function() return exports.f_idcard:CheckIdentity(src) end)
    if ok and not valid then return message or 'Anda tidak membawa KTP' end
end

lib.callback.register('f_cafe:getMenu', function(src)
    local idErr = identityError(src)
    if idErr then
        exports.qbx_core:Notify(src, idErr, 'error')
        return false
    end
    local cid = Bridge.GetCitizenId(src)
    local active = cid and activeOrderOf(cid)
    return {
        label = Config.Label,
        menu = Config.Menu,
        promos = promoList(),
        order = { default = Config.Order.defaultQty, min = Config.Order.minQty, max = Config.Order.maxQty },
        npc = refreshStaffCount() == 0 and Config.NPC.enabled,
        transfer = Invoice.Available(),
        active = active and { code = active.code, status = active.status, total = active.total } or nil,
    }
end)

lib.callback.register('f_cafe:placeOrder', function(src, cart, method)
    if not throttle(src, 'order', Config.Order.cooldown * 1000) then return { ok = false, msg = 'Tunggu sebentar sebelum order lagi.' } end
    if method ~= 'cash' and method ~= 'transfer' then return { ok = false, msg = 'Metode pembayaran tidak valid.' } end
    local range = Config.Order.counterDistance + 2.0
    if not near(src, Config.Points.counter.coords, range) and not (Config.NPC.enabled and near(src, Config.NPC.coords.xyz, range)) then
        return { ok = false, msg = 'Kamu harus berada di meja kasir.' }
    end
    local idErr = identityError(src)
    if idErr then return { ok = false, msg = idErr } end

    local cid = Bridge.GetCitizenId(src)
    if not cid then return { ok = false, msg = 'Data pemain tidak ditemukan.' } end
    if activeOrderOf(cid) then return { ok = false, msg = 'Kamu masih punya pesanan yang belum selesai.' } end

    local lines, needs, total = buildOrder(cart)
    if not lines then return { ok = false, msg = 'Keranjang tidak valid.' } end

    local mode = refreshStaffCount() > 0 and 'staff' or (Config.NPC.enabled and 'npc' or 'staff')

    if mode == 'npc' then
        local short = shortage(READY, needs)
        if #short > 0 then
            local t = {}
            for i, s in ipairs(short) do t[i] = ('%s (sisa %d)'):format(s.label, s.have) end
            return { ok = false, msg = 'Stok habis: ' .. table.concat(t, ', ') }
        end
        if not ox:CanCarryWeight(src, needsWeight(needs)) then return { ok = false, msg = 'Tas kamu tidak cukup untuk pesanan ini.' } end
    end

    local o = {
        code = newCode(), citizenid = cid, name = Bridge.GetName(src), lines = lines, needs = needs,
        total = total, method = method, mode = mode, status = 'unpaid', created = os.time(), reserved = false,
    }

    if method == 'cash' then
        if stockOf(src, Config.CashItem) < total then return { ok = false, msg = ('Uang cash kamu kurang (Rp %d).'):format(total) } end
        if not ox:RemoveItem(src, Config.CashItem, total) then return { ok = false, msg = 'Gagal mengambil uang cash.' } end
        Society.Add(total, ('Order #%s (cash)'):format(o.code))

        if mode == 'npc' then
            removeAll(READY, needs)
            o.reserved = true
        end
        Orders[o.code] = o
        onOrderPaid(o)
        return { ok = true, code = o.code, paid = true, npc = mode == 'npc' }
    end

    -- transfer: invoice f_phone
    if not Invoice.Available() then return { ok = false, msg = 'Pembayaran transfer sedang tidak tersedia.' } end
    if mode == 'npc' then
        removeAll(READY, needs) -- stok dikunci agar pasti ada saat dibayar
        o.reserved = true
    end

    local invoiceId = Invoice.Create(src, total, ('%s · #%s'):format(Config.Label, o.code), ('Pesanan #%s'):format(o.code))
    if not invoiceId then
        if o.reserved then addAll(READY, needs) end
        return { ok = false, msg = 'Gagal membuat invoice.' }
    end

    o.invoice = invoiceId
    Orders[o.code] = o
    ByInvoice[invoiceId] = o.code
    saveOrder(o)
    return { ok = true, code = o.code, paid = false, timeout = Config.Order.invoiceTimeout }
end)

-- f_phone: invoice dibayar
AddEventHandler('f_phone:server:services:invoicePaid', function(data)
    if type(data) ~= 'table' or data.job ~= Config.Job then return end
    local code = ByInvoice[data.id]
    local o = code and Orders[code]
    if not o or o.status ~= 'unpaid' then return end
    onOrderPaid(o)
end)

-- Kadaluarsa invoice + sinkron status (jika event terlewat, mis. saat restart)
local function checkUnpaid(o)
    local status = Invoice.Status(o.invoice)
    if status == 'paid' then return onOrderPaid(o) end

    local expired = os.time() - o.created >= Config.Order.invoiceTimeout * 60
    if status == 'pending' and not expired then return end
    if status == 'pending' and not Invoice.Cancel(o.invoice, o.citizenid) then
        if Invoice.Status(o.invoice) == 'paid' then onOrderPaid(o) end
        return
    end

    if o.reserved then addAll(READY, o.needs) end
    o.reserved = false
    setStatus(o, 'cancelled')
    local src = Bridge.GetSourceByCitizenId(o.citizenid)
    if src then notify(src, ('Invoice pesanan #%s kadaluarsa dan dibatalkan.'):format(o.code), 'error') end
end

CreateThread(function()
    while true do
        Wait(30000)
        for _, o in pairs(Orders) do
            if o.status == 'unpaid' and o.invoice then checkUnpaid(o) end
        end
    end
end)

---------------------------------------------------------------------------
-- Staff: list pemesanan & serve
---------------------------------------------------------------------------
lib.callback.register('f_cafe:getOrders', function(src)
    if not staffJob(src, 0, true) then return false end
    local list = {}
    for _, o in pairs(Orders) do
        if o.status == 'paid' then list[#list + 1] = publicOrder(o) end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    return list
end)

lib.callback.register('f_cafe:serveOrder', function(src, code)
    if not throttle(src, 'serve', 1500) then return { ok = false, msg = 'Tunggu sebentar.' } end
    if not staffJob(src, Config.Grades.serve, true) then return { ok = false, msg = 'Kamu harus on duty.' } end
    if not near(src, Config.Center, Config.Radius) then return { ok = false, msg = 'Kamu harus berada di cafe.' } end

    local o = Orders[code]
    if not o or o.status ~= 'paid' then return { ok = false, msg = 'Pesanan tidak ditemukan atau sudah diserahkan.' } end

    local target = Bridge.GetSourceByCitizenId(o.citizenid)
    if not target then return { ok = false, msg = 'Pembeli sedang tidak ada di kota.' } end

    local a, b = coordsOf(src), coordsOf(target)
    if not a or not b or #(a - b) > Config.Order.serveDistance then return { ok = false, msg = 'Pembeli tidak ada di sekitar kamu.' } end

    local short = shortage(READY, o.needs)
    if #short > 0 then return { ok = false, msg = 'Stok siap jual belum cukup untuk pesanan ini.' } end
    if not ox:CanCarryWeight(target, needsWeight(o.needs)) then return { ok = false, msg = 'Tas pembeli penuh.' } end

    removeAll(READY, o.needs)
    giveToCustomer(target, o.needs)
    setStatus(o, 'delivered')

    notify(target, ('Pesanan #%s sudah diterima. Selamat menikmati!'):format(o.code), 'success')
    broadcastStaff('f_cafe:client:ordersChanged')
    return { ok = true, msg = ('Pesanan #%s diserahkan ke %s.'):format(o.code, o.name) }
end)

---------------------------------------------------------------------------
-- Duty
---------------------------------------------------------------------------
lib.callback.register('f_cafe:toggleDuty', function(src)
    local job = staffJob(src, 0, false)
    if not job then return false end
    if not near(src, Config.Points.duty.coords, 4.0) then return false end
    local state = not job.onduty
    Bridge.SetDuty(src, state)
    SetTimeout(300, refreshStaffCount)
    return true, state
end)

---------------------------------------------------------------------------
-- Memasak
---------------------------------------------------------------------------
lib.callback.register('f_cafe:getStationInfo', function(src, station)
    if not staffJob(src, Config.Grades.cook, true) or not Config.Stations[station] then return false end
    local list = {}
    for item, r in pairs(Config.Recipes) do
        if r.station == station then
            local ing = {}
            for name, amt in pairs(r.ingredients) do
                ing[#ing + 1] = { item = name, label = itemLabel(name), amount = amt, have = stockOf(FRIDGE, name) }
            end
            table.sort(ing, function(x, y) return x.label < y.label end)
            list[#list + 1] = { item = item, label = itemLabel(item), ingredients = ing, ready = stockOf(READY, item) }
        end
    end
    table.sort(list, function(x, y) return x.label < y.label end)
    return list
end)

lib.callback.register('f_cafe:startCook', function(src, item, portions)
    if Cooking[src] then return { ok = false, msg = 'Kamu sedang memasak.' } end
    if not staffJob(src, Config.Grades.cook, true) then return { ok = false, msg = 'Kamu harus on duty.' } end

    local r = Config.Recipes[item]
    if not r then return { ok = false, msg = 'Resep tidak ditemukan.' } end
    local validPortion = false
    for _, v in ipairs(Config.BatchOptions) do if v == portions then validPortion = true break end end
    if not validPortion then return { ok = false, msg = 'Jumlah porsi tidak valid.' } end

    local st = Config.Stations[r.station]
    if not near(src, st.coords, 3.5) then return { ok = false, msg = 'Kamu terlalu jauh dari stasiun.' } end

    local batches = portions // Config.BatchSize
    local needs = {}
    for name, amt in pairs(r.ingredients) do needs[name] = amt * batches end

    local short = shortage(FRIDGE, needs)
    if #short > 0 then
        local t = {}
        for i, s in ipairs(short) do t[i] = ('%s %d/%d'):format(s.label, s.have, s.need) end
        return { ok = false, msg = 'Bahan kurang: ' .. table.concat(t, ', ') }
    end

    removeAll(FRIDGE, needs)
    local duration = r.time + (batches - 1) * math.floor(r.time * 0.6)
    Cooking[src] = { item = item, portions = portions, needs = needs, started = GetGameTimer(), duration = duration, station = r.station }
    return { ok = true, duration = duration, label = itemLabel(item) }
end)

local function refundCooking(src)
    local c = Cooking[src]
    if not c then return end
    Cooking[src] = nil
    addAll(FRIDGE, c.needs)
end

lib.callback.register('f_cafe:finishCook', function(src)
    local c = Cooking[src]
    if not c then return { ok = false } end
    if GetGameTimer() - c.started < c.duration - 1500 then
        refundCooking(src)
        return { ok = false, msg = 'Proses masak dibatalkan.' }
    end
    if not near(src, Config.Stations[c.station].coords, 5.0) then
        refundCooking(src)
        return { ok = false, msg = 'Kamu meninggalkan stasiun, bahan dikembalikan.' }
    end
    if not ox:CanCarryItem(READY, c.item, c.portions) then
        refundCooking(src)
        return { ok = false, msg = 'Stok siap jual penuh, bahan dikembalikan ke kulkas.' }
    end
    Cooking[src] = nil
    ox:AddItem(READY, c.item, c.portions)
    return { ok = true, msg = ('%dx %s masuk ke stok siap jual.'):format(c.portions, itemLabel(c.item)) }
end)

RegisterNetEvent('f_cafe:server:cancelCook', function() refundCooking(source) end)

---------------------------------------------------------------------------
-- Manager: supplier, buang stok, promo
---------------------------------------------------------------------------
lib.callback.register('f_cafe:getSupplier', function(src)
    if not staffJob(src, Config.Grades.restock, true) then return false end
    local list = {}
    for i, s in ipairs(Config.Supplier) do
        list[i] = { item = s.item, label = s.label, price = s.price, have = stockOf(FRIDGE, s.item) }
    end
    return { balance = Society.Balance(), items = list, max = Config.SupplierMaxPerBuy }
end)

lib.callback.register('f_cafe:restock', function(src, item, amount)
    if not throttle(src, 'restock', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    if not staffJob(src, Config.Grades.restock, true) then return { ok = false, msg = 'Hanya Manager yang bisa restock.' } end
    if not near(src, Config.Points.fridge.coords, 4.0) then return { ok = false, msg = 'Kamu harus berada di dekat gudang.' } end

    local s = SupplierByItem[item]
    amount = tonumber(amount)
    if not s or not amount or not isInt(amount, 1, Config.SupplierMaxPerBuy) then return { ok = false, msg = 'Jumlah tidak valid.' } end
    if not ox:CanCarryItem(FRIDGE, item, amount) then return { ok = false, msg = 'Gudang penuh.' } end

    local cost = s.price * amount
    if not Society.Remove(cost, ('Restock %dx %s'):format(amount, s.label)) then
        return { ok = false, msg = ('Saldo organisasi tidak cukup (Rp %d).'):format(cost) }
    end
    if not ox:AddItem(FRIDGE, item, amount) then
        Society.Add(cost, 'Refund restock')
        return { ok = false, msg = 'Gagal menambah stok.' }
    end
    return { ok = true, msg = ('Membeli %dx %s seharga Rp %d.'):format(amount, s.label, cost) }
end)

lib.callback.register('f_cafe:getReadyStock', function(src)
    if not staffJob(src, 0, true) then return false end
    local list = {}
    for _, m in ipairs(Config.Menu) do
        list[#list + 1] = { item = m.item, label = m.label, count = stockOf(READY, m.item) }
    end
    return list
end)

lib.callback.register('f_cafe:discard', function(src, item, amount)
    if not staffJob(src, Config.Grades.discard, true) then return { ok = false, msg = 'Hanya Manager yang bisa membuang stok.' } end
    if not near(src, Config.Points.ready.coords, 4.0) then return { ok = false, msg = 'Kamu harus berada di dekat rak stok.' } end
    amount = tonumber(amount)
    if not MenuByItem[item] or not amount or not isInt(amount, 1, 10000) then return { ok = false, msg = 'Jumlah tidak valid.' } end
    if stockOf(READY, item) < amount then return { ok = false, msg = 'Stok tidak sebanyak itu.' } end
    ox:RemoveItem(READY, item, amount)
    print(('[f_cafe] %s (%s) membuang %dx %s dari stok siap jual'):format(Bridge.GetName(src), Bridge.GetCitizenId(src), amount, item))
    broadcastStaff('f_cafe:client:ordersChanged')
    return { ok = true, msg = ('%dx %s dibuang.'):format(amount, itemLabel(item)) }
end)

lib.callback.register('f_cafe:getPromos', function(src)
    if not staffJob(src, Config.Grades.promo, true) then return false end
    return { promos = promoList(), min = Config.Promo.minPercent, max = Config.Promo.maxPercent, limit = Config.Promo.maxPromos }
end)

lib.callback.register('f_cafe:savePromo', function(src, data)
    if not throttle(src, 'promo', 1000) then return { ok = false, msg = 'Tunggu sebentar.' } end
    if not staffJob(src, Config.Grades.promo, true) then return { ok = false, msg = 'Hanya Manager yang bisa mengatur promo.' } end
    if type(data) ~= 'table' then return { ok = false, msg = 'Data tidak valid.' } end

    local label = type(data.label) == 'string' and data.label:gsub('[<>]', ''):match('^%s*(.-)%s*$') or ''
    local food, drink, price = MenuByItem[data.food], MenuByItem[data.drink], tonumber(data.price)
    if #label < 3 or #label > 40 then return { ok = false, msg = 'Nama promo 3-40 karakter.' } end
    if not food or food.category ~= 'food' or not drink or drink.category ~= 'drink' then return { ok = false, msg = 'Pilih 1 makanan dan 1 minuman.' } end

    local normal = food.price + drink.price
    local minP = math.ceil(normal * Config.Promo.minPercent / 100)
    local maxP = math.floor(normal * Config.Promo.maxPercent / 100)
    if not price or not isInt(price, minP, maxP) then return { ok = false, msg = ('Harga promo harus Rp %d - Rp %d.'):format(minP, maxP) } end

    local id = tonumber(data.id)
    if id then
        local p = Promos[id]
        if not p then return { ok = false, msg = 'Promo tidak ditemukan.' } end
        MySQL.update.await('UPDATE cafe_promos SET label = ?, food = ?, drink = ?, price = ? WHERE id = ?', { label, food.item, drink.item, price, id })
        p.label, p.food, p.drink, p.price = label, food.item, drink.item, price
    else
        local n = 0
        for _ in pairs(Promos) do n = n + 1 end
        if n >= Config.Promo.maxPromos then return { ok = false, msg = 'Jumlah promo sudah maksimal.' } end
        id = MySQL.insert.await('INSERT INTO cafe_promos (label, food, drink, price) VALUES (?, ?, ?, ?)', { label, food.item, drink.item, price })
        Promos[id] = { id = id, label = label, food = food.item, drink = drink.item, price = price }
    end
    return { ok = true, msg = 'Promo disimpan.' }
end)

lib.callback.register('f_cafe:deletePromo', function(src, id)
    if not staffJob(src, Config.Grades.promo, true) then return { ok = false, msg = 'Hanya Manager yang bisa mengatur promo.' } end
    id = tonumber(id)
    if not id or not Promos[id] then return { ok = false, msg = 'Promo tidak ditemukan.' } end
    MySQL.update.await('DELETE FROM cafe_promos WHERE id = ?', { id })
    Promos[id] = nil
    return { ok = true, msg = 'Promo dihapus.' }
end)

---------------------------------------------------------------------------
-- Command /orderan
---------------------------------------------------------------------------
lib.addCommand('orderan', { help = 'Buka list pemesanan cafe' }, function(src)
    if not staffJob(src, 0, true) then return notify(src, 'Hanya karyawan cafe yang on duty.', 'error') end
    TriggerClientEvent('f_cafe:client:openOrders', src)
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    refundCooking(src)
    for key in pairs(Cooldowns) do
        if key:find('^' .. src .. '%a') then Cooldowns[key] = nil end
    end
    SetTimeout(500, refreshStaffCount)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Cooking) do refundCooking(src) end
end)

---------------------------------------------------------------------------
-- Init: tabel, stash, hook ox_inventory
---------------------------------------------------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS cafe_orders (
            code        VARCHAR(10)  NOT NULL,
            citizenid   VARCHAR(64)  NOT NULL,
            name        VARCHAR(128) DEFAULT NULL,
            order_lines LONGTEXT     NOT NULL,
            needs       LONGTEXT     NOT NULL,
            total       BIGINT       NOT NULL,
            method      VARCHAR(16)  NOT NULL,
            mode        VARCHAR(8)   NOT NULL,
            status      VARCHAR(16)  NOT NULL,
            invoice_id  VARCHAR(48)  DEFAULT NULL,
            reserved    TINYINT(1)   NOT NULL DEFAULT 0,
            created_at  INT          NOT NULL,
            updated_at  INT          NOT NULL,
            PRIMARY KEY (code),
            INDEX idx_status (status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS cafe_promos (
            id     INT          NOT NULL AUTO_INCREMENT,
            label  VARCHAR(64)  NOT NULL,
            food   VARCHAR(64)  NOT NULL,
            drink  VARCHAR(64)  NOT NULL,
            price  BIGINT       NOT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    local promos = MySQL.query.await('SELECT * FROM cafe_promos') or {}
    if #promos == 0 then
        for _, p in ipairs(Config.Promo.defaults) do
            MySQL.insert.await('INSERT INTO cafe_promos (label, food, drink, price) VALUES (?, ?, ?, ?)', { p.label, p.food, p.drink, p.price })
        end
        promos = MySQL.query.await('SELECT * FROM cafe_promos') or {}
    end
    for _, p in ipairs(promos) do Promos[p.id] = p end

    -- Orders lama (yang masih dicatat 'delivered'/'cancelled' tidak dimuat)
    MySQL.update.await("DELETE FROM cafe_orders WHERE status IN ('delivered', 'cancelled') AND updated_at < ?", { os.time() - 7 * 86400 })
    for _, r in ipairs(MySQL.query.await("SELECT * FROM cafe_orders WHERE status IN ('unpaid', 'paid')") or {}) do
        local o = {
            code = r.code, citizenid = r.citizenid, name = r.name, lines = json.decode(r.order_lines), needs = json.decode(r.needs),
            total = r.total, method = r.method, mode = r.mode, status = r.status, invoice = r.invoice_id,
            reserved = r.reserved == 1 or r.reserved == true, created = r.created_at, paidAt = r.status == 'paid' and r.updated_at or nil,
        }
        Orders[o.code] = o
        if o.invoice then ByInvoice[o.invoice] = o.code end
    end

    -- Stash kulkas & siap jual didaftarkan oleh f_stash (ID tetap Config.Stash.*.id); lokasi diatur lewat /stash.

    local menuFilter = {}
    for item in pairs(MenuByItem) do menuFilter[item] = true end

    -- Stok siap jual tidak punya kadaluarsa
    ox:registerHook('createItem', function(payload)
        local meta = payload.metadata
        meta.durability = nil
        meta.degrade = nil
        return meta
    end, { inventoryFilter = { '^' .. READY .. '$' }, itemFilter = menuFilter })

    -- Stash siap jual terkunci: tidak bisa keluar/masuk manual (hanya lewat Serve Order / masak)
    ox:registerHook('swapItems', function(payload)
        if payload.fromInventory == payload.toInventory then return true end
        if type(payload.source) == 'number' then
            notify(payload.source, 'Stok siap jual hanya bisa keluar lewat Serve Order.', 'error')
        end
        return false
    end, { inventoryFilter = { '^' .. READY .. '$' } })

    refreshStaffCount()
end)
