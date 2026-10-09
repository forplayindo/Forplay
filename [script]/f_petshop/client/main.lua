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
        -- gambar dicari di html/pets/ dengan nama = nama model (variasi warna: model_<texture>),
        -- format png/webp/jpg. Kalau tidak ada: `image` di config, lalu emoji.
        local names = {}
        if p.texture then names[#names + 1] = ('%s_%d'):format(p.model, p.texture) end
        names[#names + 1] = p.model
        local photos = {}
        for _, n in ipairs(names) do
            for _, ext in ipairs({ 'png', 'webp', 'jpg' }) do photos[#photos + 1] = ('pets/%s.%s'):format(n, ext) end
        end
        if p.image then photos[#photos + 1] = p.image end
        pets[#pets + 1] = { id = p.id, label = p.label, price = p.price, icon = p.icon, photos = photos }
    end
    for _, f in ipairs(Config.Food) do
        food[#food + 1] = { item = f.item, label = f.label, price = f.price, hunger = f.hunger }
    end
    return pets, food
end

local function close()
    if not view then return end
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
    SendNUIMessage({ action = 'openShop', data = {
        title = Config.Shop.label, pets = pets, food = food, info = info, nameMax = Config.NameMaxLength,
    } })
    SetNuiFocus(true, true)
end

local labels = {}
for _, p in ipairs(Config.Pets) do labels[p.id] = { label = p.label, icon = p.icon } end

local owned = {} -- daftar hewan milik pemain (dari server), di-refresh saat panel dibuka / panggil / pulangkan

local function refreshOwned()
    owned = lib.callback.await('f_petshop:getMyPets', false) or {}
end

-- status hewan aktif diambil langsung dari client supaya panel tidak query database tiap ada perubahan
local function panelData()
    local pets = {}
    for _, r in ipairs(owned) do
        local l = labels[r.pet] or { label = r.pet, icon = '🐾' }
        local p = Pet.list[r.id]
        local row = p and p.row or r
        pets[#pets + 1] = {
            id = r.id, name = r.name, breed = l.label, icon = l.icon,
            hunger = row.hunger, health = row.health, dead = row.dead,
            active = p ~= nil,
            mode = p and p.mode or nil,
            inVehicle = p and p.vehicle ~= nil or false,
            carried = p and p.ped ~= 0 and Pet.isCarried(p.ped) or false,
            canCarry = not (p and p.cfg.carry == false),
        }
    end
    return { pets = pets, carrying = Pet.isCarrying() }
end

local function openPanel()
    if view then return close() end
    view = 'panel'
    refreshOwned()
    SendNUIMessage({ action = 'openPanel', data = panelData() })
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

AddEventHandler('f_petshop:client:changed', function()
    if view ~= 'panel' then return end
    SendNUIMessage({ action = 'panelData', data = panelData() })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb(1)
end)

RegisterNUICallback('buyPet', function(data, cb)
    local res = lib.callback.await('f_petshop:buyPet', false, data.id, data.name, data.method)
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
    if res and res.ok then
        notify(res.msg, 'success')
        close()
        -- hewan baru langsung muncul di depan pemain
        if res.id then Pet.summon(res.id, true) end
    end
end)

RegisterNUICallback('buyFood', function(data, cb)
    local res = lib.callback.await('f_petshop:buyFood', false, data.item, data.amount, data.method)
    if res and res.ok then notify(res.msg, 'success') end
    cb(res or { ok = false, msg = 'Server tidak merespons.' })
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

-- target = id hewan atau 'all'
RegisterNUICallback('command', function(data, cb)
    local target = data.target == 'all' and 'all' or tonumber(data.target)
    Pet.command(data.cmd, target)
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
        onSelect = openPanel,
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
