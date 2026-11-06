local config = require 'config.client'
local sharedConfig = require 'config.shared'
local cave = require 'shared.cave'
local lobby = sharedConfig.lobby

local FURNACE = `avp_prop_mining_furnace`
local LIQUID = `avp_prop_mining_furnace_melted_liquid`
local WADAH = `avp_prop_mining_storage`
local GUDANG = `avp_prop_mining_cart_storage`
local CART = `avp_prop_mining_cart`
local LAMP = `avp_prop_mining_cave_lamp`
local RAIL = `avp_prop_mining_rail_straight`
local BAR_MODELS = { copper = `avp_prop_mining_copper_bar`, silverbar = `avp_prop_mining_silver_bar`, goldbar = `avp_prop_mining_gold_bar` }
local FILL_BY_ORE = { bijih_tembaga = `avp_prop_mining_fill_copper`, bijih_perak = `avp_prop_mining_fill_silver`, bijih_emas = `avp_prop_mining_fill_gold` }
local FILL_BY_BAR = { copper = FILL_BY_ORE.bijih_tembaga, silverbar = FILL_BY_ORE.bijih_perak, goldbar = FILL_BY_ORE.bijih_emas }

local inArea = false
local lobbyProps = {}
local furnaceProps = {}   -- [idx] = entity
local furnaceFx = {}      -- [idx] = { entities }
local furnaceState = {}   -- [idx] = { cid, out, total, endsAt }
local inCave              -- label gua saat di dalam
local caveProps = {}
local rockProps = {}      -- [id] = entity
local rockStage = {}      -- [id] = 0..4 (4 = hancur)
local cart, cartBin
local cartFill = {}
local busy = false
local carrying            -- { item, count, props }
local pickaxe, helmet
local outfitSaved
local menuOpen = false
local labels = {}

local function notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end

local function mmss(s)
    s = math.max(0, math.floor(s or 0))
    return ('%d:%02d'):format(s // 60, s % 60)
end

local function itemLabel(name)
    if not labels[name] then
        local item = exports.ox_inventory:Items(name)
        labels[name] = item and item.label or name
    end
    return labels[name]
end

local function spawnProp(model, pos, rot, list)
    if type(model) == 'string' then model = joaat(model) end
    if not pcall(lib.requestModel, model, 5000) then return end
    local obj = CreateObjectNoOffset(model, pos.x, pos.y, pos.z, false, false, false)
    SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    if list then list[#list + 1] = obj end
    return obj
end

-- prop yang titik tengahnya di tengah badan: angkat supaya bagian bawah tepat di lantai (pos.z = lantai)
local function spawnOnGround(model, pos, heading, list)
    if type(model) == 'string' then model = joaat(model) end
    if not pcall(lib.requestModel, model, 5000) then return end
    local min = GetModelDimensions(model)
    return spawnProp(model, vec3(pos.x, pos.y, pos.z - min.z), vec3(0, 0, heading), list)
end

local function deleteAll(list)
    for i = 1, #list do
        if DoesEntityExist(list[i]) then DeleteEntity(list[i]) end
        list[i] = nil
    end
end

local function teleport(coords, heading)
    DoScreenFadeOut(400)
    Wait(450)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(cache.ped, heading or 0.0)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    local timeout = GetGameTimer() + 2000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < timeout do Wait(50) end
    DoScreenFadeIn(400)
end

local function attachNet(model, bone, pos, rot)
    lib.requestModel(model, 5000)
    local c = GetEntityCoords(cache.ped)
    local obj = CreateObject(model, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    return obj
end

local function dropEntity(obj)
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
end

-- rpemotes dimatikan selama di gua / membawa wadah supaya tidak bentrok dengan animasi tambang
local emotesLocked = false
local function lockEmotes(lock)
    if lock == emotesLocked then return end
    emotesLocked = lock
    if lock and GetResourceState('rpemotes') == 'started' then
        pcall(function() exports.rpemotes:EmoteCancel(true) end)
    end
    LocalPlayer.state:set('canEmote', not lock, true)
end

---------------------------------------------------------------------------
-- baju tambang + helm
---------------------------------------------------------------------------
-- mapping komponen sama dengan f_garbagejob (illenium LoadJobOutfit)
local OUTFIT_COMPONENTS = { pants = 4, arms = 3, ['t-shirt'] = 8, torso2 = 11, shoes = 6 }

local function myOutfit()
    local female = tonumber(QBX.PlayerData.charinfo and QBX.PlayerData.charinfo.gender) == 1
    return female and config.outfit.female or config.outfit.male
end

local function putHelmet()
    dropEntity(helmet)
    helmet = attachNet(config.helmet.model, config.helmet.bone, config.helmet.pos, config.helmet.rot)
end

-- panel Alur Kerja (f_panduan), opsional: dimulai saat memakai baju tambang
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

AddEventHandler('f_panduan:client:requestStep', function(job)
    if job ~= 'tambang' or not outfitSaved then return end
    panduan('SetStep', 'tambang', carrying and 5 or inCave and 3 or 2)
end)

local function applyOutfit()
    if outfitSaved then return end
    local ok, appearance = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(cache.ped)
    end)
    outfitSaved = ok and appearance or true
    for name, component in pairs(OUTFIT_COMPONENTS) do
        local part = myOutfit()[name]
        if part then SetPedComponentVariation(cache.ped, component, part.item, part.texture, 0) end
    end
    putHelmet()
    TriggerServerEvent('f_mining:server:outfit', true)
    notify('Baju tambang terpasang.', 'success')
    panduan('Start', 'tambang')
end

local function restoreOutfit()
    dropEntity(helmet)
    helmet = nil
    if not outfitSaved then return end
    local saved = outfitSaved
    outfitSaved = nil
    TriggerServerEvent('f_mining:server:outfit', false)
    panduan('Stop', 'tambang')
    if type(saved) == 'table' and pcall(function()
        exports['illenium-appearance']:setPedAppearance(cache.ped, saved)
    end) then return end
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

local function wearingOutfit()
    if not outfitSaved then return false end
    if GetPedDrawableVariation(cache.ped, 11) == myOutfit().torso2.item then return true end
    -- baju diganti di tempat lain
    outfitSaved = nil
    dropEntity(helmet)
    helmet = nil
    TriggerServerEvent('f_mining:server:outfit', false)
    panduan('Stop', 'tambang')
    return false
end

---------------------------------------------------------------------------
-- tungku (lobby)
---------------------------------------------------------------------------
local function clearFurnaceFx(idx)
    if furnaceFx[idx] then deleteAll(furnaceFx[idx]) end
    furnaceFx[idx] = nil
end

local function showFurnaceFx(idx)
    clearFurnaceFx(idx)
    local st, obj, spot = furnaceState[idx], furnaceProps[idx], lobby.furnaces[idx]
    if not st or not obj then return end
    local list = {}
    local main = st.outs[1]
    for _, o in ipairs(st.outs) do if o.count > main.count then main = o end end
    local liquid = spawnProp(LIQUID, spot.xyz, vec3(0, 0, spot.w), list)
    if liquid then AttachEntityToEntity(liquid, obj, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true) end
    if BAR_MODELS[main.out] then
        spawnProp(BAR_MODELS[main.out], GetOffsetFromEntityInWorldCoords(obj, -1.05, 0.0, 0.42), vec3(0, -180.0, spot.w), list)
    end
    local wadah = spawnProp(WADAH, GetOffsetFromEntityInWorldCoords(obj, -2.1, 0.0, -0.19), vec3(0, 0, spot.w + 90.0), list)
    if wadah and FILL_BY_BAR[main.out] then
        local fill = spawnProp(FILL_BY_BAR[main.out], GetEntityCoords(wadah), vec3(0, 0, spot.w + 90.0), list)
        if fill then AttachEntityToEntity(fill, wadah, 0, 0.0, 0.0, 0.05, 0.0, 0.0, 0.0, false, false, false, false, 2, true) end
    end
    furnaceFx[idx] = list
end

local function setFurnace(idx, pub)
    furnaceState[idx] = pub and {
        cid = pub.cid, outs = pub.outs, total = pub.total,
        endsAt = GetGameTimer() + pub.remaining * 1000,
    } or nil
    if inArea then
        if furnaceState[idx] then showFurnaceFx(idx) else clearFurnaceFx(idx) end
    end
end

RegisterNetEvent('f_mining:client:furnace', setFurnace)

local function furnaceText(idx)
    local st = furnaceState[idx]
    if not st then return ('Tungku %d~n~~g~Kosong'):format(idx) end
    local remaining = math.max(0, (st.endsAt - GetGameTimer()) / 1000)
    if st.cid == QBX.PlayerData.citizenid then
        local per = sharedConfig.secondsPerBar
        local done = math.min(st.total, math.floor((st.total * per - remaining) / per))
        -- dilebur berurutan: cari jenis yang sedang dilebur
        local current, left = st.outs[#st.outs].out, done
        for _, o in ipairs(st.outs) do
            if left < o.count then current = o.out break end
            left = left - o.count
        end
        return ('Tungku %d~n~~y~Lebur %d/%d~s~ · %s~n~%s'):format(idx, done, st.total, mmss(remaining), itemLabel(current))
    end
    return ('Tungku %d~n~~o~Sedang dipakai~s~ · sisa %s'):format(idx, mmss(remaining))
end

local function draw3D(coords, text)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function furnaceTextLoop()
    CreateThread(function()
        while inArea do
            local sleep = 500
            if not inCave then
                local pos = GetEntityCoords(cache.ped)
                for idx, spot in ipairs(lobby.furnaces) do
                    if #(pos - spot.xyz) < config.textDistance and furnaceProps[idx] then
                        sleep = 0
                        draw3D(GetOffsetFromEntityInWorldCoords(furnaceProps[idx], -1.05, 0.0, 1.7), furnaceText(idx))
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

---------------------------------------------------------------------------
-- penerangan lobby & gua
---------------------------------------------------------------------------
local caveLights = {}
for i, l in ipairs(cave.lamps) do caveLights[i] = l.pos - vec3(0, 0, 0.3) end

local function lightLoop()
    local L = config.light
    local r, g, b = L.colour[1], L.colour[2], L.colour[3]
    CreateThread(function()
        while inArea do
            local pos = GetEntityCoords(cache.ped)
            local list = inCave and caveLights or L.lobby
            for i = 1, #list do
                local p = list[i]
                if #(pos - p) < L.distance then
                    DrawLightWithRange(p.x, p.y, p.z, r, g, b, L.range, L.intensity)
                end
            end
            Wait(0)
        end
    end)
end

---------------------------------------------------------------------------
-- wadah
---------------------------------------------------------------------------
local function stopCarry()
    if not carrying then return end
    for _, obj in ipairs(carrying.props) do dropEntity(obj) end
    carrying = nil
    LocalPlayer.state:set('invBusy', false, false)
    StopAnimTask(cache.ped, config.carryAnim.dict, config.carryAnim.clip, 1.0)
    if not inCave then lockEmotes(false) end
end

local function startCarry(item, count)
    stopCarry()
    lockEmotes(true)
    dropEntity(pickaxe)
    pickaxe = nil
    local a = config.wadahAttach
    local wadah = attachNet(WADAH, a.bone, a.pos, vec3(0, 0, 0))
    local props = { wadah }
    if FILL_BY_ORE[item] then
        lib.requestModel(FILL_BY_ORE[item], 5000)
        local fill = CreateObject(FILL_BY_ORE[item], 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(fill, wadah, 0, 0.0, 0.0, 0.05, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        props[2] = fill
    end
    carrying = { item = item, count = count, props = props }
    LocalPlayer.state:set('invBusy', true, false)
    lib.requestAnimDict(config.carryAnim.dict)

    CreateThread(function()
        local nextCheck = 0
        while carrying do
            -- jalan pelan: tanpa lari, lompat, naik kendaraan, senjata
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            if GetGameTimer() > nextCheck then
                nextCheck = GetGameTimer() + 500
                local meta = QBX.PlayerData.metadata or {}
                if IsPedDeadOrDying(cache.ped, true) or meta.isdead or meta.inlaststand then
                    TriggerServerEvent('f_mining:server:dropWadah')
                    stopCarry()
                    break
                end
                if not IsEntityPlayingAnim(cache.ped, config.carryAnim.dict, config.carryAnim.clip, 3) then
                    TaskPlayAnim(cache.ped, config.carryAnim.dict, config.carryAnim.clip, 8.0, 8.0, -1, 49, 0, false, false, false)
                end
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('f_mining:client:wadah', function(state)
    if not state then stopCarry() end
end)

RegisterNetEvent('f_mining:client:smelted', function(msg)
    notify(msg, 'success')
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

local function placeWadah(idx)
    local res = lib.callback.await('f_mining:server:placeWadah', false, idx)
    if not res or not res.ok then
        if res and res.msg then notify(res.msg, 'error') end
        return
    end
    stopCarry()
    notify(res.msg, 'success')
end

---------------------------------------------------------------------------
-- lobby (prop lokal hanya saat dekat)
---------------------------------------------------------------------------
local lobbyTargets = {}

local function spawnLobby()
    for idx, spot in ipairs(lobby.furnaces) do
        local obj = spawnProp(FURNACE, spot.xyz, vec3(0, 0, spot.w), lobbyProps)
        if obj then
            furnaceProps[idx] = obj
            lobbyTargets[#lobbyTargets + 1] = obj
            exports.ox_target:addLocalEntity(obj, {
                {
                    name = 'f_mining_place', icon = 'fas fa-fire', distance = 2.5,
                    label = ('Taruh Wadah (Tungku %d)'):format(idx),
                    canInteract = function() return carrying ~= nil and not furnaceState[idx] end,
                    onSelect = function() placeWadah(idx) end,
                },
            })
            if furnaceState[idx] then showFurnaceFx(idx) end
        end
    end

    local gudang = spawnOnGround(GUDANG, lobby.gudang.xyz, lobby.gudang.w, lobbyProps)
    if gudang then
        lobbyTargets[#lobbyTargets + 1] = gudang
        exports.ox_target:addLocalEntity(gudang, {
            {
                name = 'f_mining_gudang', icon = 'fas fa-warehouse', label = 'Buka Gudang Tambang', distance = 2.5,
                canInteract = function() return not carrying end,
                onSelect = function() exports.ox_inventory:openInventory('stash', 'f_mining_gudang') end,
            },
            {
                name = 'f_mining_wadah', icon = 'fas fa-box', label = 'Ambil Wadah', distance = 2.5,
                canInteract = function() return not carrying end,
                onSelect = function() TriggerEvent('f_mining:client:openWadah') end,
            },
            {
                name = 'f_mining_return', icon = 'fas fa-rotate-left', label = 'Kembalikan Wadah', distance = 2.5,
                canInteract = function() return carrying ~= nil end,
                onSelect = function()
                    if lib.callback.await('f_mining:server:returnWadah', false) then stopCarry() end
                end,
            },
        })
    end

    for _, piece in ipairs(cave.gateLobby) do
        spawnProp(cave.rockModel(piece.cx, piece.cy, 0), piece.pos, vec3(0, 0, piece.heading), lobbyProps)
    end
end

local function hideMloProps(hide)
    for _, p in ipairs(config.hideProps) do
        local c = p.coords
        if hide then
            CreateModelHideExcludingScriptObjects(c.x, c.y, c.z, 0.8, p.model, true)
        else
            RemoveModelHide(c.x, c.y, c.z, 0.8, p.model, false)
        end
    end
end

local function despawnLobby()
    for idx in pairs(furnaceFx) do clearFurnaceFx(idx) end
    for i = 1, #lobbyTargets do
        exports.ox_target:removeLocalEntity(lobbyTargets[i])
        lobbyTargets[i] = nil
    end
    deleteAll(lobbyProps)
    furnaceProps = {}
end

---------------------------------------------------------------------------
-- gua (prop lokal selama sesi)
---------------------------------------------------------------------------
local function hitFx(pos)
    lib.requestNamedPtfxAsset('core', 5000)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_brk_concrete', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 1.25, false, false, false)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('ent_brk_metal_frag', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    SendNUIMessage({ action = 'sfx', name = ('hit%d'):format(math.random(3)), volume = config.hitVolume })
end

-- ayun beberapa kali; tiap ayunan bunyi + serpihan tepat saat kapak kena batu
local function swing(pos)
    local a = config.swingAnim
    lib.requestAnimDict(a.dict)
    local length = math.max(800, math.floor(GetAnimDuration(a.dict, a.clip) * 1000))
    for _ = 1, config.swings do
        TaskPlayAnim(cache.ped, a.dict, a.clip, 4.0, 4.0, length, 0, 0, false, false, false)
        Wait(math.floor(length * config.impactAt))
        hitFx(pos)
        Wait(length - math.floor(length * config.impactAt))
    end
    StopAnimTask(cache.ped, a.dict, a.clip, 1.0)
end

local nextSwing = 0

local function hitRock(id)
    if busy or carrying then return end
    if not wearingOutfit() then return notify('Pakai baju tambang dulu di loker lobby.', 'error') end
    if exports.ox_inventory:Search('count', 'kapak_tambang') < 1 then
        return notify('Kamu butuh Kapak Tambang (beli di rak lobby).', 'error')
    end
    if exports.ox_inventory:GetPlayerWeight() + 500 > exports.ox_inventory:GetPlayerMaxWeight() then
        return notify('Tas penuh! Setor dulu ke lori.', 'error')
    end
    local wait = nextSwing - GetGameTimer()
    if wait > 0 then
        return notify(('Tarik napas dulu... (%.1f dtk)'):format(wait / 1000), 'inform')
    end

    busy = true
    nextSwing = GetGameTimer() + config.swingTime
    local def = cave.rockById[id]
    TaskTurnPedToFaceCoord(cache.ped, def.pos.x, def.pos.y, def.pos.z, 700)
    Wait(700)
    if not pickaxe or not DoesEntityExist(pickaxe) then
        local p = config.pickaxe
        pickaxe = attachNet(p.model, p.bone, p.pos, p.rot)
    end
    swing(def.pos)

    local res = lib.callback.await('f_mining:server:hit', false, id)
    busy = false
    if not res then return end
    if not res.ok then
        if res.msg then notify(res.msg, 'error') end
        return
    end
    if res.rare then
        notify(('Kamu mendapat %s!'):format(res.label), 'success')
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        notify(('Kamu mendapat %s.'):format(res.label), 'inform')
    end
    if res.broke then
        notify('Kapak Tambang patah!', 'error')
        dropEntity(pickaxe)
        pickaxe = nil
    end
end

local function spawnRock(id)
    local old = rockProps[id]
    if old then
        exports.ox_target:removeLocalEntity(old)
        dropEntity(old)
        rockProps[id] = nil
    end
    local stage = rockStage[id]
    if not inCave or not stage or stage >= 4 then return end
    local def = cave.rockById[id]
    local obj = spawnProp(cave.rockModel(def.cx, def.cy, stage), def.pos, vec3(0, 0, def.heading))
    if not obj then return end
    rockProps[id] = obj
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'f_mining_hit', icon = 'fas fa-hammer', label = 'Tambang Batu', distance = 2.5,
            canInteract = function() return not busy and not carrying end,
            onSelect = function() hitRock(id) end,
        },
    })
end

RegisterNetEvent('f_mining:client:rock', function(id, stage)
    if not inCave then return end
    rockStage[id] = stage
    spawnRock(id)
end)

-- isian bijih di bak lori: 3 lembar berjejer, di dalam bak (bukan di bibir)
local function setLoad(state)
    for i = 1, #cartFill do dropEntity(cartFill[i]) end
    cartFill = {}
    if not state or not cartBin or not DoesEntityExist(cartBin) then return end
    local _, max = GetModelDimensions(GUDANG)
    for _, y in ipairs({ -0.43, 0.0, 0.43 }) do
        local fill = spawnProp(FILL_BY_ORE.bijih_tembaga, GetEntityCoords(cartBin), vec3(0, 0, 0), cartFill)
        if fill then
            AttachEntityToEntity(fill, cartBin, 0, 0.0, y, max.z - 0.35, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    end
end

RegisterNetEvent('f_mining:client:load', function(state)
    if inCave then setLoad(state) end
end)

local function moveCart(from, to, ms, fadeOut)
    local start = GetGameTimer()
    while cart and DoesEntityExist(cart) do
        local t = math.min(1.0, (GetGameTimer() - start) / ms)
        local p = from + (to - from) * t
        SetEntityCoordsNoOffset(cart, p.x, p.y, p.z, false, false, false)
        local alpha = math.floor(255 * (fadeOut and (1.0 - t) or t))
        SetEntityAlpha(cart, alpha, false)
        if cartBin then SetEntityAlpha(cartBin, alpha, false) end
        for i = 1, #cartFill do SetEntityAlpha(cartFill[i], alpha, false) end
        if t >= 1.0 then break end
        Wait(0)
    end
end

-- lori jalan ke pintu (menuju gudang lobby), hilang, lalu kembali
RegisterNetEvent('f_mining:client:lori', function(travel)
    if not inCave or not cart then return end
    CreateThread(function()
        moveCart(cave.cartPark, cave.cartOut, 6000, true)
        setLoad(false)
        Wait(math.max(0, travel * 1000 - 6000))
        if inCave then moveCart(cave.cartOut, cave.cartPark, 6000, false) end
        if cart and DoesEntityExist(cart) then ResetEntityAlpha(cart) end
        if cartBin and DoesEntityExist(cartBin) then ResetEntityAlpha(cartBin) end
    end)
end)

local function deposit()
    local res = lib.callback.await('f_mining:server:deposit', false)
    if not res then return end
    if not res.ok then
        if res.msg then notify(res.msg, 'error') end
        return
    end
    notify(('%d barang masuk bak lori. Lori berangkat dalam %s.'):format(res.total, mmss(res.lori)), 'success')
end

local function spawnCave(load)
    for _, t in ipairs(cave.tubes) do spawnProp(t.model, t.pos, vec3(0, 0, t.heading), caveProps) end
    for _, l in ipairs(cave.lamps) do spawnProp(LAMP, l.pos, vec3(0, 0, l.heading), caveProps) end
    for _, piece in ipairs(cave.backing) do
        spawnProp(cave.rockModel(piece.cx, piece.cy, 0), piece.pos, vec3(0, 0, piece.heading), caveProps)
    end
    for _, piece in ipairs(cave.gateCave) do
        spawnProp(cave.rockModel(piece.cx, piece.cy, 0), piece.pos, vec3(0, 0, piece.heading), caveProps)
    end
    for _, r in ipairs(cave.rails) do spawnProp(RAIL, r.pos, vec3(0, 0, r.heading), caveProps) end

    cart = spawnProp(CART, cave.cartPark, vec3(0, 0, 0), caveProps)
    if cart then
        local storage = spawnProp(GUDANG, cave.cartPark, vec3(0, 0, 0), caveProps)
        if storage then
            AttachEntityToEntity(storage, cart, 0, 0.0, 0.0, 0.85, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            cartBin = storage
        end
        setLoad(load)
    end

    for _, r in ipairs(cave.rocks) do spawnRock(r.id) end
end

local function despawnCave()
    for id, obj in pairs(rockProps) do
        exports.ox_target:removeLocalEntity(obj)
        dropEntity(obj)
        rockProps[id] = nil
    end
    deleteAll(cartFill)
    deleteAll(caveProps)
    cart, cartBin = nil, nil
    rockStage = {}
end

-- helm & kapak adalah objek jaringan: lepas sebelum pindah bucket supaya tidak tertinggal di bucket lama
local function dropNetProps()
    local hadHelmet = helmet ~= nil
    dropEntity(helmet)
    dropEntity(pickaxe)
    helmet, pickaxe = nil, nil
    return hadHelmet
end

local function joinCave(res, hadHelmet)
    inCave = res.label
    lockEmotes(true)
    rockStage = res.rocks
    spawnCave(res.load)
    teleport(cave.arrival.xyz, cave.arrival.w)
    if hadHelmet then putHelmet() end
    notify(('Masuk %s. Lori berangkat dalam %s.'):format(res.label, mmss(res.lori)), 'success')
end

local function leaveCave()
    local hadHelmet = dropNetProps()
    if not lib.callback.await('f_mining:server:leaveCave', false) and hadHelmet then putHelmet() end
end

RegisterNetEvent('f_mining:client:leftCave', function(doTeleport)
    if not inCave then return end
    local hadHelmet = helmet ~= nil or outfitSaved ~= nil
    inCave = nil
    busy = false
    if not carrying then lockEmotes(false) end
    despawnCave()
    dropNetProps()
    if doTeleport then teleport(lobby.gateExit.xyz, lobby.gateExit.w) end
    if hadHelmet and outfitSaved then putHelmet() end
end)

---------------------------------------------------------------------------
-- NUI (pilih gua, ambil wadah)
---------------------------------------------------------------------------
local function openMenu(action, data)
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = action, data = data })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openCaves()
    if carrying then return notify('Taruh wadahmu dulu.', 'error') end
    openMenu('caves', lib.callback.await('f_mining:server:getCaves', false))
end

AddEventHandler('f_mining:client:openWadah', function()
    local info = lib.callback.await('f_mining:server:wadahInfo', false)
    if not info then return notify('Terlalu jauh dari gudang.', 'error') end
    openMenu('wadah', info)
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refreshCaves', function(_, cb)
    cb(lib.callback.await('f_mining:server:getCaves', false))
end)

RegisterNUICallback('enterCave', function(data, cb)
    local hadHelmet = dropNetProps()
    local res = lib.callback.await('f_mining:server:enterCave', false, data.cave)
    cb(res and { ok = res.ok, msg = res.msg } or { ok = false })
    if res and res.ok then
        closeMenu()
        joinCave(res, hadHelmet)
    elseif hadHelmet then
        putHelmet()
    end
end)

RegisterNUICallback('takeWadah', function(data, cb)
    local res = lib.callback.await('f_mining:server:takeWadah', false, data.items)
    if res and res.ok then
        closeMenu()
        startCarry(res.item, res.count)
        notify(('Wadah berisi %s. Bawa ke tungku yang kosong.'):format(res.label), 'success')
    end
    cb(res or { ok = false })
end)

---------------------------------------------------------------------------
-- titik tetap: lift, loker, rak kapak, pintu gua
---------------------------------------------------------------------------
exports.ox_target:addSphereZone({
    coords = sharedConfig.surface.xyz, radius = 1.6,
    options = {
        {
            name = 'f_mining_down', icon = 'fas fa-person-arrow-down-to-line', label = 'Turun ke Tambang', distance = 2.5,
            canInteract = function() return not cache.vehicle end,
            onSelect = function() teleport(lobby.entrance.xyz, lobby.entrance.w) end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = lobby.entrance.xyz + vec3(0, 0, 1.0), radius = 1.6,
    options = {
        {
            name = 'f_mining_up', icon = 'fas fa-person-arrow-up-from-line', label = 'Naik ke Atas', distance = 2.5,
            onSelect = function()
                if carrying then return notify('Taruh wadahmu dulu.', 'error') end
                teleport(sharedConfig.surface.xyz, sharedConfig.surface.w)
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = lobby.locker + vec3(0, 0, 1.0), radius = 1.2,
    options = {
        {
            name = 'f_mining_outfit_on', icon = 'fas fa-helmet-safety', label = 'Pakai Baju Tambang', distance = 2.5,
            canInteract = function() return not outfitSaved and not carrying end,
            onSelect = applyOutfit,
        },
        {
            name = 'f_mining_outfit_off', icon = 'fas fa-shirt', label = 'Ganti Baju Biasa', distance = 2.5,
            canInteract = function() return outfitSaved ~= nil and not carrying end,
            onSelect = function()
                restoreOutfit()
                notify('Baju biasa terpasang.', 'inform')
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = lobby.toolRack, radius = 1.2,
    options = {
        {
            name = 'f_mining_kapak', icon = 'fas fa-hammer', distance = 2.5,
            label = ('Beli Kapak Tambang (Rp %s)'):format(lib.math.groupdigits(sharedConfig.kapakPrice, '.')),
            onSelect = function()
                local res = lib.callback.await('f_mining:server:buyKapak', false)
                if res and res.ok then
                    notify('Kapak Tambang dibeli.', 'success')
                elseif res and res.msg then
                    notify(res.msg, 'error')
                end
            end,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = lobby.gateExit.xyz + vec3(0, 2.2, 1.0), radius = 1.6,
    options = {
        {
            name = 'f_mining_cave_in', icon = 'fas fa-dungeon', label = 'Masuk Gua', distance = 3.0,
            canInteract = function() return not inCave end,
            onSelect = openCaves,
        },
    },
})

-- titik setor lori: zona tetap (bukan entity lori, karena lori bergerak & target kena badan lori)
exports.ox_target:addSphereZone({
    coords = cave.cartPark + vec3(0, 0, 0.8), radius = 1.4,
    options = {
        {
            name = 'f_mining_deposit', icon = 'fas fa-cart-flatbed', label = 'Setor Semua ke Lori', distance = 2.5,
            canInteract = function() return inCave ~= nil and not busy end,
            onSelect = deposit,
        },
    },
})

exports.ox_target:addSphereZone({
    coords = cave.gateCaveTarget, radius = 1.6,
    options = {
        {
            name = 'f_mining_cave_out', icon = 'fas fa-door-open', label = 'Kembali ke Lobby', distance = 3.0,
            canInteract = function() return inCave ~= nil and not busy end,
            onSelect = leaveCave,
        },
    },
})

---------------------------------------------------------------------------
-- area tambang
---------------------------------------------------------------------------
local function syncFurnaces()
    local list = lib.callback.await('f_mining:server:getFurnaces', false) or {}
    for idx in ipairs(lobby.furnaces) do setFurnace(idx, list[idx]) end
end

lib.points.new({
    coords = lobby.center,
    distance = lobby.areaRadius,
    onEnter = function()
        inArea = true
        hideMloProps(true)
        spawnLobby()
        syncFurnaces()
        furnaceTextLoop()
        lightLoop()
        -- relog di dalam gua (bucket 0, tanpa prop gua): kembalikan ke lobby
        local pos = GetEntityCoords(cache.ped)
        if not inCave and pos.y > cave.gateCaveTarget.y - 1.0 and #(pos - cave.center) < 40.0 then
            teleport(lobby.gateExit.xyz, lobby.gateExit.w)
        end
    end,
    onExit = function()
        inArea = false
        despawnLobby()
        hideMloProps(false)
    end,
})

-- Gudang Hasil di atas (dekat parkir): prop lokal hanya saat dekat
local hasilProp
lib.points.new({
    coords = sharedConfig.hasil.xyz,
    distance = 60.0,
    onEnter = function()
        local h = sharedConfig.hasil
        hasilProp = spawnOnGround(GUDANG, h.xyz, h.w)
        if not hasilProp then return end
        PlaceObjectOnGroundProperly(hasilProp) -- tanah luar tidak rata
        exports.ox_target:addLocalEntity(hasilProp, {
            {
                name = 'f_mining_hasil', icon = 'fas fa-boxes-stacked', label = 'Buka Gudang Hasil', distance = 2.5,
                canInteract = function() return not carrying end,
                onSelect = function() exports.ox_inventory:openInventory('stash', 'f_mining_hasil') end,
            },
        })
    end,
    onExit = function()
        if hasilProp then exports.ox_target:removeLocalEntity(hasilProp) end
        dropEntity(hasilProp)
        hasilProp = nil
    end,
})

-- kalibrasi: salin posisi TELAPAK KAKI (lantai) + arah hadap
RegisterCommand('tambangpos', function()
    local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local feet = c.z - GetEntityHeightAboveGround(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, feet, h)
    lib.setClipboard(text)
    notify(('Disalin: %s'):format(text), 'success')
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopCarry()
    dropEntity(pickaxe)
    dropEntity(hasilProp)
    despawnCave()
    despawnLobby()
    if inCave then
        SetEntityCoords(cache.ped, lobby.gateExit.x, lobby.gateExit.y, lobby.gateExit.z, false, false, false, false)
    end
    restoreOutfit()
    lockEmotes(false)
    if menuOpen then SetNuiFocus(false, false) end
end)
