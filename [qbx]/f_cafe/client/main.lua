local P = Config.Points
local savedAppearance

local function notify(msg, typ) lib.notify({ title = Config.Label, description = msg, type = typ or 'inform' }) end

local function result(res)
    if res and res.msg then notify(res.msg, res.ok and 'success' or 'error') end
end

local function onDuty(grade) return Bridge.IsOnDuty(grade) end
local function employee() return Bridge.IsEmployee(0) end

-- Sphere zone di titik berdiri (hasil /vec3): radiusnya menutupi benda di depan pemain
local function addZone(name, point, options)
    for _, opt in ipairs(options) do opt.distance = opt.distance or Config.TargetDistance end
    exports.ox_target:addSphereZone({
        name = 'f_cafe_' .. name,
        coords = point.coords,
        radius = point.radius or Config.TargetRadius,
        debug = Config.Debug,
        options = options,
    })
end

---------------------------------------------------------------------------
-- Blip
---------------------------------------------------------------------------
if Config.Blip.enabled then
    local blip = AddBlipForCoord(Config.Center.x, Config.Center.y, Config.Center.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Label)
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------------------
-- Seragam
---------------------------------------------------------------------------
local function hasIllenium() return GetResourceState('illenium-appearance') == 'started' end

local function wearUniform()
    local ped = cache.ped
    local uniform = Bridge.IsMale() and Config.Uniform.male or Config.Uniform.female
    if not savedAppearance and hasIllenium() then
        savedAppearance = exports['illenium-appearance']:getPedAppearance(ped)
    end
    for comp, v in pairs(uniform.components) do SetPedComponentVariation(ped, comp, v[1], v[2], 0) end
    for prop, v in pairs(uniform.props) do SetPedPropIndex(ped, prop, v[1], v[2], true) end
    LocalPlayer.state:set('cafeUniform', true, false)
    notify('Seragam dipakai.', 'success')
end

local function wearCivilian(silent)
    if not LocalPlayer.state.cafeUniform then return end
    if savedAppearance and hasIllenium() then
        exports['illenium-appearance']:setPedAppearance(cache.ped, savedAppearance)
    else
        ExecuteCommand('reloadskin')
    end
    savedAppearance = nil
    LocalPlayer.state:set('cafeUniform', false, false)
    if not silent then notify('Kembali memakai baju biasa.', 'success') end
end

---------------------------------------------------------------------------
-- Masak
---------------------------------------------------------------------------
local cooking = false

local function cook(stationId, recipe)
    local options = {}
    for i, n in ipairs(Config.BatchOptions) do options[i] = { value = n, label = ('%d porsi'):format(n) } end
    local input = lib.inputDialog(('Masak %s'):format(recipe.label), {
        { type = 'select', label = 'Jumlah porsi', options = options, default = Config.BatchOptions[1], required = true },
    })
    if not input then return end

    local res = lib.callback.await('f_cafe:startCook', false, recipe.item, tonumber(input[1]))
    if not res or not res.ok then return result(res) end

    cooking = true
    local st = Config.Stations[stationId]
    local done = lib.progressBar({
        duration = res.duration,
        label = ('Membuat %d %s...'):format(tonumber(input[1]), res.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = st.anim,
        prop = st.prop,
    })
    cooking = false

    if done then
        result(lib.callback.await('f_cafe:finishCook', false))
    else
        TriggerServerEvent('f_cafe:server:cancelCook')
        notify('Masak dibatalkan, bahan dikembalikan ke kulkas.', 'error')
    end
end

local function openStation(stationId)
    if cooking then return end
    local list = lib.callback.await('f_cafe:getStationInfo', false, stationId)
    if not list then return notify('Kamu harus on duty.', 'error') end

    local options = {}
    for _, r in ipairs(list) do
        local parts, can = {}, true
        for _, ing in ipairs(r.ingredients) do
            parts[#parts + 1] = ('%dx %s (stok %d)'):format(ing.amount, ing.label, ing.have)
            if ing.have < ing.amount then can = false end
        end
        options[#options + 1] = {
            title = r.label,
            description = ('Per %d porsi: %s'):format(Config.BatchSize, table.concat(parts, ', ')),
            icon = can and 'check' or 'xmark',
            iconColor = can and '#4ade80' or '#f87171',
            metadata = { { label = 'Stok siap jual', value = r.ready } },
            onSelect = function() cook(stationId, r) end,
        }
    end
    lib.registerContext({ id = 'f_cafe_station', title = Config.Stations[stationId].label, options = options })
    lib.showContext('f_cafe_station')
end

---------------------------------------------------------------------------
-- Manager: supplier, buang stok, promo
---------------------------------------------------------------------------
local function openDiscard()
    local list = lib.callback.await('f_cafe:getReadyStock', false)
    if not list then return end
    local options = {}
    for _, s in ipairs(list) do
        options[#options + 1] = {
            title = s.label,
            description = ('Stok: %d'):format(s.count),
            icon = 'trash',
            disabled = s.count == 0,
            onSelect = function()
                local input = lib.inputDialog(('Buang %s'):format(s.label), {
                    { type = 'number', label = 'Jumlah', min = 1, max = s.count, default = s.count, required = true },
                })
                if not input then return end
                local ok = lib.alertDialog({ header = 'Buang stok?', content = ('Buang %dx %s? Tidak bisa dibatalkan.'):format(input[1], s.label), centered = true, cancel = true })
                if ok ~= 'confirm' then return end
                result(lib.callback.await('f_cafe:discard', false, s.item, tonumber(input[1])))
            end,
        }
    end
    lib.registerContext({ id = 'f_cafe_discard', title = 'Buang Stok Siap Jual', options = options })
    lib.showContext('f_cafe_discard')
end

local openPromos

local function editPromo(data, promo)
    local foods, drinks = {}, {}
    for _, m in ipairs(Config.Menu) do
        local opt = { value = m.item, label = ('%s (Rp %d)'):format(m.label, m.price) }
        if m.category == 'food' then foods[#foods + 1] = opt else drinks[#drinks + 1] = opt end
    end
    local input = lib.inputDialog(promo and 'Edit Promo' or 'Tambah Promo', {
        { type = 'input', label = 'Nama promo', default = promo and promo.label, required = true, min = 3, max = 40 },
        { type = 'select', label = 'Makanan', options = foods, default = promo and promo.food, required = true },
        { type = 'select', label = 'Minuman', options = drinks, default = promo and promo.drink, required = true },
        { type = 'number', label = 'Harga paket ($)', description = ('Harus %d%% - %d%% dari harga normal'):format(data.min, data.max),
          default = promo and promo.price, min = 1, required = true },
    })
    if not input then return openPromos() end
    result(lib.callback.await('f_cafe:savePromo', false, { id = promo and promo.id, label = input[1], food = input[2], drink = input[3], price = tonumber(input[4]) }))
    openPromos()
end

openPromos = function()
    local data = lib.callback.await('f_cafe:getPromos', false)
    if not data then return notify('Hanya Manager yang bisa mengatur promo.', 'error') end
    local options = {
        { title = 'Tambah Promo', icon = 'plus', disabled = #data.promos >= data.limit, onSelect = function() editPromo(data) end },
    }
    for _, p in ipairs(data.promos) do
        options[#options + 1] = {
            title = ('%s - Rp %d'):format(p.label, p.price),
            description = ('%s + %s (normal Rp %d)'):format(p.foodLabel, p.drinkLabel, p.normal),
            icon = 'tag',
            onSelect = function()
                lib.registerContext({
                    id = 'f_cafe_promo_one', title = p.label, menu = 'f_cafe_promos',
                    options = {
                        { title = 'Edit', icon = 'pen', onSelect = function() editPromo(data, p) end },
                        { title = 'Hapus', icon = 'trash', onSelect = function()
                            result(lib.callback.await('f_cafe:deletePromo', false, p.id))
                            openPromos()
                        end },
                    },
                })
                lib.showContext('f_cafe_promo_one')
            end,
        }
    end
    lib.registerContext({ id = 'f_cafe_promos', title = 'Kelola Promo', options = options })
    lib.showContext('f_cafe_promos')
end

---------------------------------------------------------------------------
-- Target
---------------------------------------------------------------------------
CreateThread(function()
    addZone('duty', P.duty, {
        { name = 'f_cafe_duty', icon = 'fa-solid fa-clipboard-user', label = 'Mulai / Selesai Shift',
          canInteract = employee,
          onSelect = function()
              local ok, state = lib.callback.await('f_cafe:toggleDuty', false)
              if not ok then return notify('Gagal mengubah status duty.', 'error') end
              if state then
                  notify('Shift dimulai. Jangan lupa ganti seragam di loker.', 'success')
              else
                  wearCivilian(true)
                  notify('Shift selesai. Terima kasih!', 'inform')
              end
          end },
    })

    addZone('locker', P.locker, {
        { name = 'f_cafe_uniform', icon = 'fa-solid fa-shirt', label = 'Pakai Seragam',
          canInteract = function() return onDuty() and not LocalPlayer.state.cafeUniform end, onSelect = wearUniform },
        { name = 'f_cafe_civil', icon = 'fa-solid fa-user', label = 'Pakai Baju Biasa',
          canInteract = function() return LocalPlayer.state.cafeUniform == true end, onSelect = function() wearCivilian() end },
    })

    -- Buka kulkas & stok siap jual: lewat [E] dari f_stash.
    addZone('fridge', P.fridge, {
        { name = 'f_cafe_supplier', icon = 'fa-solid fa-truck', label = 'Pesan Bahan (Supplier)',
          canInteract = function() return onDuty(Config.Grades.restock) end, onSelect = function() OpenSupplier() end },
    })

    addZone('ready', P.ready, {
        { name = 'f_cafe_discard', icon = 'fa-solid fa-trash', label = 'Buang Stok',
          canInteract = function() return onDuty(Config.Grades.discard) end, onSelect = openDiscard },
    })

    for i, point in ipairs(P.orders) do
        addZone('orders_' .. i, point, {
            { name = 'f_cafe_orders_' .. i, icon = 'fa-solid fa-receipt', label = 'List Pemesanan',
              canInteract = function() return onDuty() end, onSelect = function() OpenOrders() end },
            { name = 'f_cafe_promos_' .. i, icon = 'fa-solid fa-tags', label = 'Kelola Promo',
              canInteract = function() return onDuty(Config.Grades.promo) end, onSelect = function() openPromos() end },
        })
    end

    for i, point in ipairs(P.counter) do
        addZone('counter_' .. i, point, {
            { name = 'f_cafe_menu_' .. i, icon = 'fa-solid fa-utensils', label = 'Lihat Menu & Pesan', distance = Config.Order.counterDistance,
              onSelect = function() OpenMenu() end },
        })
    end

    for id, st in pairs(Config.Stations) do
        addZone('station_' .. id, st, {
            { name = 'f_cafe_station_' .. id, icon = st.icon, label = ('Masak di %s'):format(st.label),
              canInteract = function() return onDuty(Config.Grades.cook) and not cooking end,
              onSelect = function() openStation(id) end },
        })
    end
end)

---------------------------------------------------------------------------
-- NPC kasir (hanya saat tidak ada karyawan on duty)
---------------------------------------------------------------------------
local npc
local inRange = false

local function despawnNpc()
    if npc and DoesEntityExist(npc) then DeleteEntity(npc) end
    npc = nil
end

local function spawnNpc()
    if npc or not Config.NPC.enabled then return end
    local c = Config.NPC.coords
    local model = lib.requestModel(Config.NPC.model)
    if not model then return end
    npc = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, true) -- coords dari /vec4 (pinggang) -> kaki
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    if Config.NPC.scenario then TaskStartScenarioInPlace(npc, Config.NPC.scenario, 0, true) end
end

local function updateNpc()
    if inRange and (GlobalState.cafeStaff or 0) == 0 then spawnNpc() else despawnNpc() end
end

lib.points.new({
    coords = Config.NPC.coords.xyz,
    distance = 60.0,
    onEnter = function() inRange = true updateNpc() end,
    onExit = function() inRange = false updateNpc() end,
})

AddStateBagChangeHandler('cafeStaff', 'global', function() SetTimeout(0, updateNpc) end)

---------------------------------------------------------------------------
-- Event
---------------------------------------------------------------------------
RegisterNetEvent('f_cafe:client:newOrder', function(data)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    lib.notify({ title = 'Order Baru #' .. data.code, description = ('%s - Rp %d. Cek List Pemesanan (/orderan).'):format(data.name, data.total), type = 'inform', duration = 8000 })
    RefreshOrders()
end)

RegisterNetEvent('f_cafe:client:ordersChanged', function() RefreshOrders() end)
RegisterNetEvent('f_cafe:client:openOrders', function() OpenOrders() end)

RegisterNetEvent('QBCore:Client:SetDuty', function(state)
    if not state then wearCivilian(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then despawnNpc() end
end)
