-- f_petshop client: toko, NUI (toko & panel kontrol), radial menu.

local view -- nil | 'shop' | 'panel'
local keeper = 0
local points = {}

local function notify(msg, kind) lib.notify({ description = msg, type = kind or 'inform' }) end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function catalog()
    local pets, food = {}, {}
    for _, p in ipairs(Config.Pets) do
        pets[#pets + 1] = {
            id = p.id, label = p.label, group = p.group or 'Lainnya', price = p.price, icon = p.icon,
            variants = p.variants and p.variants.labels or nil,
        }
    end
    for _, f in ipairs(Config.Food) do
        food[#food + 1] = { item = f.item, label = f.label, price = f.price, icon = '🦴', desc = ('Kenyang +%d'):format(f.hunger) }
    end
    for _, d in ipairs(Config.Drinks) do
        food[#food + 1] = { item = d.item, label = d.label, price = d.price, icon = '💧', desc = ('Minum +%d'):format(d.thirst) }
    end
    for _, s in ipairs(Config.Supplies or {}) do
        food[#food + 1] = { item = s.item, label = s.label, price = s.price, icon = s.icon or '📦', desc = s.desc or '' }
    end
    return pets, food
end

local function accCatalog()
    local items = {}
    for _, a in ipairs(Config.Accessories) do
        items[#items + 1] = { prop = a.prop, slot = a.slot, label = a.label, price = Acc.price(a) }
    end
    local slots = {}
    for _, s in ipairs(Config.AccessorySlots) do slots[#slots + 1] = { id = s.id, label = s.label, price = s.price } end
    return { items = items, slots = slots, colors = Config.CollarColors }
end

local stopFit -- alat /petfit (di bawah)

local function close()
    if not view then return end
    if view == 'shop' then Preview.close() end
    if view == 'fit' then stopFit() end
    view = nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function openShop()
    if view then return end
    local info = lib.callback.await('f_petshop:getShop', false)
    if not info then return end
    local pets, food = catalog()
    view = 'shop'
    lib.hideTextUI()
    Preview.open({ keeper })
    SendNUIMessage({ action = 'openShop', data = {
        title = Config.Shop.label, pets = pets, food = food, info = info, nameMax = Config.NameMaxLength,
        acc = accCatalog(),
    } })
    SetNuiFocus(true, true)
end

local labels = {}
for _, p in ipairs(Config.Pets) do labels[p.id] = { label = p.label, icon = p.icon } end

local owned = {} -- daftar hewan milik pemain (dari server), di-refresh saat panel dibuka / panggil / pulangkan

local function refreshOwned()
    owned = lib.callback.await('f_petshop:getMyPets', false) or {}
    for _, r in ipairs(owned) do
        if r.trial then r.endsAt = GetGameTimer() + (r.left or 0) * 1000 end -- sisa waktu coba
    end
end

-- status hewan aktif diambil langsung dari client supaya panel tidak query database tiap ada perubahan
local function panelData()
    local pets = {}
    for _, r in ipairs(owned) do
        local l = labels[r.pet] or { label = r.pet, icon = '🐾' }
        local p = Pet.list[r.id]
        if r.trial and not p then goto continue end -- hewan coba yang sudah kembali ke toko
        local row = p and p.row or r
        pets[#pets + 1] = {
            id = r.id, name = r.name, breed = l.label, icon = l.icon,
            hunger = row.hunger, thirst = row.thirst or 100, health = row.health, dead = row.dead,
            active = p ~= nil,
            mode = p and p.mode or nil,
            inVehicle = p and p.vehicle ~= nil or false,
            carried = p and p.ped ~= 0 and Pet.isCarried(p.ped) or false,
            canCarry = not (p and p.cfg.carry == false),
            tricks = p and Pet.tricksFor(p.cfg) or nil,
            canLeash = p and Config.Leash.kinds[p.cfg.kind] == true or false,
            canFight = p and Pet.canFight(p.cfg) or false,
            guarding = p and p.guard ~= nil or false,
            leash = p and p.ped ~= 0 and DoesEntityExist(p.ped) and (Entity(p.ped).state.fpet or {}).leash == true or false,
            trial = r.trial == true,
            left = r.trial and math.max(0, math.floor((r.endsAt - GetGameTimer()) / 1000)) or nil,
        }
        ::continue::
    end
    local gr = Config.Attack.guardRadius
    return { pets = pets, carrying = Pet.isCarrying(), guard = { min = gr.min, max = gr.max, default = gr.default } }
end

---@param selectId number? hewan yang langsung dipilih (dibuka dari target hewan)
local function openPanel(selectId)
    if view then return close() end
    view = 'panel'
    refreshOwned()
    local data = panelData()
    data.select = selectId
    SendNUIMessage({ action = 'openPanel', data = data })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true) -- tetap bisa jalan selama panel terbuka

    CreateThread(function()
        while view == 'panel' do
            DisableControlAction(0, 1, true)   -- lihat kiri/kanan
            DisableControlAction(0, 2, true)   -- lihat atas/bawah
            DisableControlAction(0, 24, true)  -- serang
            DisableControlAction(0, 25, true)  -- bidik
            DisableControlAction(0, 200, true) -- ESC (menu jeda)
            DisableControlAction(0, 199, true)
            if IsDisabledControlJustPressed(0, 200) then close() end
            Wait(0)
        end
    end)
end

-- memilih target serangan / area jaga butuh layar bebas
AddEventHandler('f_petshop:client:closeUi', function()
    if view == 'panel' then close() end
end)

-- Daftar Teman: action = nil (lihat) | 'add' (server id) | 'remove' (citizenid) | 'job' (nama job)
RegisterNUICallback('friends', function(data, cb)
    cb(lib.callback.await('f_petshop:friends', false, data.action, data.value) or {})
end)

-- dari ox_target "Menu Hewan" (client/pet.lua)
AddEventHandler('f_petshop:client:openMenu', function(id)
    if view == 'shop' then return end
    if view == 'panel' then close() end
    openPanel(id)
end)

AddEventHandler('f_petshop:client:changed', function()
    if view ~= 'panel' then return end
    SendNUIMessage({ action = 'panelData', data = panelData() })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('preview', function(data, cb)
    if view == 'shop' then Preview.show(data.id, data.variant) end
    cb(1)
end)

RegisterNUICallback('rotate', function(data, cb)
    if view == 'shop' then Preview.rotate(data.dx) end
    cb(1)
end)

RegisterNUICallback('zoom', function(data, cb)
    if view == 'shop' then Preview.zoom(data.dir) end
    cb(1)
end)

-- Coba 5 menit: hewan sementara langsung muncul di depan pemain
RegisterNUICallback('trial', function(data, cb)
    local res = lib.callback.await('f_petshop:trial', false, data.id, data.variant)
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
    if res and res.ok then
        notify(res.msg, 'success')
        close()
        Pet.summon(res.id, true)
    end
end)

-- kembalikan hewan coba (sebelum waktunya habis)
RegisterNUICallback('trialReturn', function(_, cb)
    lib.callback.await('f_petshop:trialReturn', false)
    cb(lib.callback.await('f_petshop:getShop', false) or {})
end)

-- ajukan kepemilikan (gratis, disetujui Admin / Owner)
RegisterNUICallback('request', function(data, cb)
    local res = lib.callback.await('f_petshop:request', false, data.id, data.name, data.variant)
    if res and res.ok then
        notify(res.msg, 'success')
        res.info = lib.callback.await('f_petshop:getShop', false)
    end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

RegisterNUICallback('requestCancel', function(_, cb)
    lib.callback.await('f_petshop:requestCancel', false)
    cb(lib.callback.await('f_petshop:getShop', false) or {})
end)

RegisterNUICallback('buyFood', function(data, cb)
    local res = lib.callback.await('f_petshop:buyFood', false, data.item, data.amount, data.method)
    if res and res.ok then notify(res.msg, 'success') end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

---------------------------------------------------------------------------
-- Toko: tab Aksesoris
---------------------------------------------------------------------------
local petCfg = {}
for _, p in ipairs(Config.Pets) do petCfg[p.id] = p end
local accPets = {} -- [id hewan] = data dari server (untuk preview)

RegisterNUICallback('accPets', function(_, cb)
    local rows = lib.callback.await('f_petshop:accPets', false) or {}
    local out = {}
    accPets = {}
    for _, r in ipairs(rows) do
        local cfg = petCfg[r.pet]
        -- hanya aksesoris yang punya posisi untuk model hewan ini
        local items = {}
        for _, a in ipairs(Config.Accessories) do
            if Acc.fit(cfg.model, a.prop) then items[#items + 1] = a.prop end
        end
        accPets[r.id] = r
        out[#out + 1] = {
            id = r.id, name = r.name, icon = cfg.icon, breed = cfg.label, items = items, collar = Acc.collarAllowed(cfg),
            owned = r.owned, collars = r.collars, worn = r.worn,
        }
    end
    cb(out)
end)

-- tampilkan hewan milik sendiri + aksesoris yang sedang dicoba
RegisterNUICallback('previewAcc', function(data, cb)
    local r = accPets[tonumber(data.pet)]
    if view == 'shop' and r then Preview.show(r.pet, r.variant, data.worn) end
    cb(1)
end)

RegisterNUICallback('buyAcc', function(data, cb)
    local res = lib.callback.await('f_petshop:buyAcc', false, tonumber(data.pet), data.slot, data.value, data.method)
    if res and res.ok then
        notify(res.msg, 'success')
        local r = accPets[tonumber(data.pet)]
        if r then r.owned, r.collars, r.worn = res.owned, res.collars, res.worn end
    end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
end)

RegisterNUICallback('wearAcc', function(data, cb)
    local res = lib.callback.await('f_petshop:wearAcc', false, tonumber(data.pet), data.slot, data.value)
    if res and res.ok then
        local r = accPets[tonumber(data.pet)]
        if r then r.owned, r.collars, r.worn = res.owned, res.collars, res.worn end
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    cb(res or { ok = false })
end)

---------------------------------------------------------------------------
-- /petfit (admin): setel posisi aksesoris pada hewan sendiri yang sedang dipanggil
---------------------------------------------------------------------------
local fit -- { p = FPet, prop, values = {x,y,z,rx,ry,rz,bone}, obj }

local function fitAttach()
    if fit.obj and DoesEntityExist(fit.obj) then DeleteEntity(fit.obj) end
    fit.obj = nil
    if not fit.prop or not DoesEntityExist(fit.p.ped) then return end
    local v = fit.values
    local objs = Accessories.attach(fit.p.ped, fit.p.cfg.model, { [Acc.byProp[fit.prop].slot] = fit.prop })
    -- Accessories.attach memakai posisi tersimpan; tempel ulang dengan angka yang sedang disetel
    fit.obj = objs[1]
    if not fit.obj then
        local hash = joaat(fit.prop)
        if not pcall(lib.requestModel, hash, 5000) then return end
        local c = GetEntityCoords(fit.p.ped)
        fit.obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityCollision(fit.obj, false, false)
    end
    DetachEntity(fit.obj, false, false)
    AttachEntityToEntity(fit.obj, fit.p.ped, GetPedBoneIndex(fit.p.ped, v[7]), v[1], v[2], v[3], v[4], v[5], v[6],
        false, false, false, true, 0, true)
end

stopFit = function()
    if not fit then return end
    if fit.obj and DoesEntityExist(fit.obj) then DeleteEntity(fit.obj) end
    Accessories.suspend(fit.p.ped, false)
    fit = nil
end

RegisterNetEvent('f_petshop:client:petfit', function()
    if view then return end
    local nearest, best = nil, 6.0
    for _, p in pairs(Pet.list) do
        if p.ped ~= 0 and DoesEntityExist(p.ped) and not p.row.dead then
            local d = #(GetEntityCoords(cache.ped) - GetEntityCoords(p.ped))
            if d < best then nearest, best = p, d end
        end
    end
    if not nearest then return notify('Panggil hewanmu dan berdiri di dekatnya dulu.', 'error') end

    fit = { p = nearest }
    Pet.command('stay', nearest.id)
    Accessories.suspend(nearest.ped, true)
    local items = {}
    for _, a in ipairs(Config.Accessories) do
        items[#items + 1] = { prop = a.prop, label = a.label, slot = a.slot, fitted = Acc.fit(nearest.cfg.model, a.prop) ~= nil }
    end
    view = 'fit'
    SendNUIMessage({ action = 'openFit', data = { model = nearest.cfg.model, pet = nearest.row.name, items = items, slots = Config.AccessorySlots } })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    -- tahan klik kanan untuk memutar kamera; selain itu mouse untuk panel
    CreateThread(function()
        while view == 'fit' do
            if not IsDisabledControlPressed(0, 25) then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
            end
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 200) then close() end
            Wait(0)
        end
    end)
end)

RegisterNUICallback('fitSelect', function(data, cb)
    if view ~= 'fit' or not fit or not Acc.byProp[data.prop] then return cb(false) end
    local item = Acc.byProp[data.prop]
    local f = Acc.fit(fit.p.cfg.model, data.prop)
    fit.prop = data.prop
    fit.values = f and { f[1].x, f[1].y, f[1].z, f[2].x, f[2].y, f[2].z, f[3] }
        or { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Acc.slots[item.slot].bone or 31086 }
    fitAttach()
    cb(fit.values)
end)

RegisterNUICallback('fitUpdate', function(data, cb)
    if view == 'fit' and fit and fit.prop and type(data.values) == 'table' then
        for i = 1, 7 do fit.values[i] = tonumber(data.values[i]) or fit.values[i] end
        fit.values[7] = math.floor(fit.values[7])
        fitAttach()
    end
    cb(1)
end)

RegisterNUICallback('fitSave', function(_, cb)
    if view ~= 'fit' or not fit or not fit.prop then return cb(false) end
    local ok = lib.callback.await('f_petshop:saveFit', false, fit.p.cfg.model, fit.prop, fit.values)
    notify(ok and ('Posisi %s untuk %s disimpan.'):format(Acc.byProp[fit.prop].label, fit.p.cfg.label)
        or 'Gagal menyimpan (bukan admin?).', ok and 'success' or 'error')
    cb(ok)
end)

RegisterNUICallback('summon', function(data, cb)
    if data.id == 'all' then Pet.summonAll() else Pet.summon(tonumber(data.id)) end
    refreshOwned()
    cb(panelData())
end)

RegisterNUICallback('release', function(data, cb)
    local res = lib.callback.await('f_petshop:release', false, tonumber(data.id))
    if res and res.msg then notify(res.msg, res.ok and 'success' or 'error') end
    refreshOwned()
    cb(panelData())
end)

RegisterNUICallback('trick', function(data, cb)
    Pet.trick(tonumber(data.id), data.trick)
    cb(panelData())
end)

-- target = id hewan atau 'all'
RegisterNUICallback('command', function(data, cb)
    local target = data.target == 'all' and 'all' or tonumber(data.target)
    Pet.command(data.cmd, target, tonumber(data.radius))
    if data.cmd == 'dismiss' then refreshOwned() end
    cb(panelData())
end)

---------------------------------------------------------------------------
-- Radial menu
---------------------------------------------------------------------------
local function addRadial()
    lib.addRadialItem({
        id = 'f_petshop',
        label = 'Hewan',
        icon = 'paw',
        onSelect = function() openPanel() end, -- ox_lib mengirim argumen menu, jangan diteruskan
    })
end

-- f_radialmenu menjalankan lib.clearRadialItems() saat player loaded / mati / revive, jadi item
-- kita didaftarkan ulang sesudahnya (sama seperti f_hygiene)
local function reAddRadial()
    SetTimeout(1500, addRadial)
end

addRadial()
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', reAddRadial)
RegisterNetEvent('radialmenu:client:deadradial', function(isDead)
    if not isDead then reAddRadial() end
end)

---------------------------------------------------------------------------
-- Penjaga toko
---------------------------------------------------------------------------
local function spawnKeeper()
    local s = Config.Shop.coords
    local model = joaat(Config.Shop.keeperModel)
    if not lib.requestModel(model, 10000) then return end
    keeper = CreatePed(4, model, s.x, s.y, s.z, s.w, false, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(keeper, true)
    SetEntityInvincible(keeper, true)
    SetBlockingOfNonTemporaryEvents(keeper, true)
    TaskStartScenarioInPlace(keeper, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
end

local function textPoint(coords, distance, text, canUse, onUse)
    local shown = false
    local point = lib.points.new({ coords = coords, distance = distance })
    function point:nearby()
        local ok = not view and canUse()
        if ok and not shown then
            lib.showTextUI(text())
            shown = true
        elseif not ok and shown then
            lib.hideTextUI()
            shown = false
        end
        if ok and IsControlJustPressed(0, 38) then
            lib.hideTextUI()
            shown = false
            onUse()
        end
    end
    function point:onExit()
        if shown then lib.hideTextUI() shown = false end
    end
    points[#points + 1] = point
end

local function init()
    local s = Config.Shop.coords
    spawnKeeper()
    textPoint(vec3(s.x, s.y, s.z), 2.5,
        function() return ('[E] %s'):format(Config.Shop.label) end,
        function() return true end,
        openShop)
    -- hewan mati disembuhkan oleh EMS lewat target "Sembuhkan Hewan" (lihat client/pet.lua)
end

local function cleanup()
    for _, p in ipairs(points) do p:remove() end
    points = {}
    if keeper ~= 0 and DoesEntityExist(keeper) then DeleteEntity(keeper) end
    keeper = 0
    lib.hideTextUI()
    close()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', init)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    cleanup()
    Pet.dismiss()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= cache.resource then return end
    if LocalPlayer.state.isLoggedIn then init() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    cleanup()
    lib.removeRadialItem('f_petshop')
end)
