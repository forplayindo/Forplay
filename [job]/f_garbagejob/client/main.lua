local config = require 'config.client'
local sharedConfig = require 'config.shared'
local depot = sharedConfig.depot
local truckCfg = sharedConfig.truck

local crew            -- latest server payload, nil when not in a crew
local blip
local stopProps = { bags = {} }
local truckTargetNet
local handBag
local carrying = false
local busy = false
local loopRunning = false
local spawnRequested = false


local promptText
local outfitSaved
local menuOpen = false

local function notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

local function isLeader()
    return crew ~= nil and crew.leader == cache.serverId
end

local function showPrompt(text)
    if promptText == text then return end
    promptText = text
    lib.showTextUI(text)
end

local function hidePrompt()
    if not promptText then return end
    promptText = nil
    lib.hideTextUI()
end

local function truckEntity()
    if not crew or not crew.netId or not NetworkDoesEntityExistWithNetworkId(crew.netId) then return end
    local veh = NetToVeh(crew.netId)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
end

---------------------------------------------------------------------------
-- outfit
---------------------------------------------------------------------------
-- same component mapping as illenium-appearance LoadJobOutfit, applied directly
local OUTFIT_COMPONENTS = { pants = 4, arms = 3, ['t-shirt'] = 8, torso2 = 11, shoes = 6 }

local function applyOutfit()
    if outfitSaved then return end
    local ok, appearance = pcall(function()
        return exports['illenium-appearance']:getPedAppearance(cache.ped)
    end)
    outfitSaved = ok and appearance or true

    local female = tonumber(QBX.PlayerData.charinfo and QBX.PlayerData.charinfo.gender) == 1
    local outfit = female and config.outfit.female or config.outfit.male
    for name, component in pairs(OUTFIT_COMPONENTS) do
        local part = outfit[name]
        if part then SetPedComponentVariation(cache.ped, component, part.item, part.texture, 0) end
    end
    if outfit.hat then
        if outfit.hat.item > 0 then
            SetPedPropIndex(cache.ped, 0, outfit.hat.item, outfit.hat.texture, true)
        else
            ClearPedProp(cache.ped, 0)
        end
    end
end

local function restoreOutfit()
    if not outfitSaved then return end
    local saved = outfitSaved
    outfitSaved = nil
    if type(saved) == 'table' and pcall(function()
        exports['illenium-appearance']:setPedAppearance(cache.ped, saved)
    end) then return end
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

---------------------------------------------------------------------------
-- blips
---------------------------------------------------------------------------
local function clearBlip()
    if blip then RemoveBlip(blip) end
    blip = nil
end

local function setRouteBlip(coords, colour, label)
    clearBlip()
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 318)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, colour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------------------
-- carried bag
---------------------------------------------------------------------------
local function dropHandBag()
    carrying = false
    if handBag and DoesEntityExist(handBag) then DeleteEntity(handBag) end
    handBag = nil
    StopAnimTask(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 1.0)
end

local function holdBag()
    lib.requestModel(config.handBagModel, 5000)
    handBag = CreateObject(config.handBagModel, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(config.handBagModel)
    AttachEntityToEntity(handBag, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
    carrying = true
    CreateThread(function()
        while carrying do
            if not IsEntityPlayingAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 3)
                and not IsEntityPlayingAnim(cache.ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 3) then
                lib.playAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, false, false, false)
            end
            Wait(1000)
        end
    end)
end

local function takeBag(index)
    if carrying or busy then return end
    busy = true
    if lib.callback.await('f_garbagejob:server:takeBag', false, index) then
        lib.playAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 700, 0, 0.0, false, false, false)
        Wait(450)
        holdBag()
    else
        notify('Kantong itu sudah diambil.', 'error')
    end
    busy = false
end

local function nearTruck(veh)
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) < truckCfg.throwDistance
end

-- hopper on top of the truck (bone 'boot')
local function hopperPos(veh)
    local bone = GetEntityBoneIndexByName(veh, truckCfg.hopperBone)
    if bone ~= -1 then return GetWorldPositionOfEntityBone(veh, bone) end
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, -2.0, 3.0)
end

local hopperCloseAt = 0

local function openHopper(veh)
    SetVehicleDoorOpen(veh, truckCfg.hopperDoor, false, false)
    hopperCloseAt = GetGameTimer() + 1800
    SetTimeout(1900, function()
        -- another bag thrown meanwhile keeps it open, and so does a container being emptied (same door)
        local containerBusy = crew and crew.stop and crew.stop.container == 'attached'
        if GetGameTimer() >= hopperCloseAt and not containerBusy and DoesEntityExist(veh) then
            SetVehicleDoorShut(veh, truckCfg.hopperDoor, false)
        end
    end)
end

-- the bag leaves the hand and flies in an arc into the hopper
local function throwBagInto(veh)
    local obj = handBag
    handBag = nil
    if not obj or not DoesEntityExist(obj) then return end
    DetachEntity(obj, true, false)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    local from, to = GetEntityCoords(obj), hopperPos(veh)
    local start, duration = GetGameTimer(), 650
    CreateThread(function()
        while true do
            local t = math.min((GetGameTimer() - start) / duration, 1.0)
            local pos = from + (to - from) * t + vec3(0.0, 0.0, math.sin(t * math.pi) * 1.5)
            SetEntityCoords(obj, pos.x, pos.y, pos.z, false, false, false, false)
            if t >= 1.0 then break end
            Wait(0)
        end
        DeleteEntity(obj)
    end)
end

local function depositBag(data)
    if not carrying or busy then return end
    local veh = data and data.entity or truckEntity()
    if not veh then return end
    busy = true
    local target, me = hopperPos(veh), GetEntityCoords(cache.ped)
    SetEntityHeading(cache.ped, GetHeadingFromVector_2d(target.x - me.x, target.y - me.y))

    local worth = lib.callback.await('f_garbagejob:server:depositBag', false)
    if worth then
        carrying = false
        StopAnimTask(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 1.0)
        lib.playAnim(cache.ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, false, false, false)
        openHopper(veh)
        Wait(450) -- release point of the throw
        throwBagInto(veh)
        notify(('Kantong masuk truk, kas kru +%s'):format(rupiah(worth)), 'success')
    end
    busy = false
end

---------------------------------------------------------------------------
-- stop props (local, driven by server state so the whole crew sees the same)
---------------------------------------------------------------------------
local function spawnProp(model, x, y, z, heading)
    if not IsModelInCdimage(model) then return end
    lib.requestModel(model, 5000)
    local obj = CreateObject(model, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(obj, heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    return obj
end

local function deleteProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    exports.ox_target:removeLocalEntity(obj)
    DeleteEntity(obj)
end

local function clearStopProps(keepKey)
    deleteProp(stopProps.container)
    for _, obj in pairs(stopProps.bags) do deleteProp(obj) end
    stopProps = { bags = {}, key = keepKey and stopProps.key or nil }
end

local function placeContainer(obj, coords)
    if IsEntityAttached(obj) then DetachEntity(obj, false, false) end
    SetEntityCoords(obj, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(obj, coords.w)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
end

local function updateContainer(state, coords)
    local obj = stopProps.container
    if not obj or stopProps.containerState == state then return end
    local veh = truckEntity()

    if state == 'attached' then
        if not veh then return end
        local bone = GetEntityBoneIndexByName(veh, 'scoop')
        if bone == -1 then return end
        FreezeEntityPosition(obj, false)
        local o, r = config.scoop.offset, config.scoop.rotation
        AttachEntityToEntity(obj, veh, bone, o.x, o.y, o.z, r.x, r.y, r.z, false, false, false, false, 2, true)
    else
        placeContainer(obj, coords)
        if veh and stopProps.containerState == 'attached' then SetVehicleDoorShut(veh, truckCfg.scoopDoor, false) end
    end
    stopProps.containerState = state
end

local function bagModel(index)
    local model = config.bagModels[(index - 1) % #config.bagModels + 1]
    return IsModelInCdimage(model) and model or config.bagModels[1]
end

local function renderStop()
    local stop = crew and crew.phase == 'route' and crew.stop
    if not stop then return clearStopProps() end
    if stopProps.key ~= crew.stopNum then
        clearStopProps()
        stopProps.key = crew.stopNum

    end

    local c = stop.coords
    if #(GetEntityCoords(cache.ped) - vec3(c.x, c.y, c.z)) > config.propDistance then
        if stopProps.container or next(stopProps.bags) then clearStopProps(true) end
        return
    end

    if stop.container and not stopProps.container then
        stopProps.container = spawnProp(config.containerModel, c.x, c.y, c.z, c.w)
            or spawnProp(config.containerFallback, c.x, c.y, c.z, c.w)
        stopProps.containerState = 'idle'
    end
    if stop.container then updateContainer(stop.container, c) end

    for i, bag in ipairs(stop.bags) do
        local obj = stopProps.bags[i]
        if bag.state == 0 and not obj then
            obj = spawnProp(bagModel(i), c.x + bag.x, c.y + bag.y, c.z + 0.5, (i * 47) % 360 + 0.0)
            if obj then
                stopProps.bags[i] = obj
                exports.ox_target:addLocalEntity(obj, {
                    {
                        name = 'fgj_take',
                        label = 'Ambil kantong sampah',
                        icon = 'fa-solid fa-trash',
                        distance = 2.0,
                        canInteract = function() return not carrying and not busy end,
                        onSelect = function() takeBag(i) end,
                    },
                })
            end
        elseif bag.state ~= 0 and obj then
            deleteProp(obj)
            stopProps.bags[i] = nil
        end
    end
end

---------------------------------------------------------------------------
-- truck target
---------------------------------------------------------------------------
local TRUCK_OPTIONS = { 'fgj_deposit', 'fgj_cancel', 'fgj_leave' }

local function removeTruckTarget()
    if not truckTargetNet then return end
    exports.ox_target:removeEntity(truckTargetNet, TRUCK_OPTIONS)
    truckTargetNet = nil
end

local function confirmLeave()
    local leader = isLeader()
    local answer = lib.alertDialog({
        header = leader and 'Batalkan shift?' or 'Keluar dari kru?',
        content = leader
            and 'Truk akan dikembalikan dan seluruh kru selesai. Kas kru yang sudah terkumpul dibagi rata ke semua anggota.'
            or 'Kamu menerima bagian rata dari kas kru sejauh ini, sisanya tetap untuk kru.',
        centered = true,
        cancel = true,
        labels = { confirm = leader and 'Batalkan' or 'Keluar', cancel = 'Kembali' },
    })
    if answer == 'confirm' then lib.callback.await('f_garbagejob:server:leave', false) end
end

local function registerTruckTarget()
    if not crew or not crew.netId or truckTargetNet == crew.netId then return end
    if not NetworkDoesNetworkIdExist(crew.netId) then return end
    removeTruckTarget()
    truckTargetNet = crew.netId
    exports.ox_target:addEntity(crew.netId, {
        {
            name = 'fgj_deposit',
            label = 'Lempar kantong ke atas truk',
            icon = 'fa-solid fa-dumpster',
            distance = 3.0,
            canInteract = function(entity) return carrying and not busy and nearTruck(entity) end,
            onSelect = depositBag,
        },
        {
            name = 'fgj_cancel',
            label = 'Batalkan shift',
            icon = 'fa-solid fa-ban',
            distance = 3.0,
            canInteract = function() return isLeader() and not carrying end,
            onSelect = confirmLeave,
        },
        {
            name = 'fgj_leave',
            label = 'Keluar dari kru',
            icon = 'fa-solid fa-person-walking-arrow-right',
            distance = 3.0,
            canInteract = function() return crew ~= nil and not isLeader() and not carrying end,
            onSelect = confirmLeave,
        },
    })
end

---------------------------------------------------------------------------
-- work loop
---------------------------------------------------------------------------
-- GTA arrow (marker 0, bobbing + rotating) over every bag and the container still to collect
local function drawArrow(pos, colour, scale)
    DrawMarker(0, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, scale,
        colour[1], colour[2], colour[3], 200, true, true, 2, false, nil, nil, false)
end

local function drawStopMarkers()
    local m = config.markers
    for _, obj in pairs(stopProps.bags) do
        if DoesEntityExist(obj) then
            drawArrow(GetEntityCoords(obj) + vec3(0.0, 0.0, m.bagHeight), m.bagColour, m.bagScale)
        end
    end
    local container = stopProps.container
    if container and DoesEntityExist(container) and stopProps.containerState == 'idle' then
        drawArrow(GetEntityCoords(container) + vec3(0.0, 0.0, m.containerHeight), m.containerColour, m.containerScale)
    end
end

-- the master2 scoop arm is its bonnet door (FLAG_HAS_TWO_BONNET_BONES): closed = down, open = lifted
local function handleScoop(veh, stopPos)
    local door = truckCfg.scoopDoor
    local bone = GetEntityBoneIndexByName(veh, 'scoop')
    local scoopPos = bone ~= -1 and GetWorldPositionOfEntityBone(veh, bone) or GetOffsetFromEntityInWorldCoords(veh, 0.0, 4.5, 0.0)

    if crew.stop.container == 'idle' then
        if #(scoopPos - stopPos) < config.scoop.attachDistance then
            showPrompt('[E] Kaitkan kontainer')
            if IsControlJustPressed(0, 38) and not busy then
                busy = true
                hidePrompt()
                lib.callback.await('f_garbagejob:server:attachContainer', false)
                busy = false
            end
        else
            showPrompt('Arahkan scoop depan truk ke kontainer')
        end
    elseif crew.stop.container == 'attached' then
        showPrompt('[SHIFT] Angkat & tuang  ·  [E] Lepas kontainer')
        -- hooked by mistake: put it back down and try again
        if IsControlJustPressed(0, 38) and not busy then
            busy = true
            hidePrompt()
            lib.callback.await('f_garbagejob:server:detachContainer', false)
            SetVehicleDoorShut(veh, door, false)
            busy = false
            return
        end
        -- LSHIFT: INPUT_SPRINT or INPUT_VEH_MOVE_UP_ONLY, whichever the game reports inside the truck
        if (IsControlJustPressed(0, 21) or IsControlJustPressed(0, 61)) and not busy then
            busy = true
            hidePrompt()
            SetVehicleDoorOpen(veh, door, false, false)
            local timeout = GetGameTimer() + 3000
            while GetVehicleDoorAngleRatio(veh, door) < config.scoop.liftRatio and GetGameTimer() < timeout do Wait(50) end
            lib.progressBar({
                duration = config.scoop.emptyDuration,
                label = 'Menuang kontainer...',
                canCancel = false,
                disable = { car = true },
            })
            local worth = lib.callback.await('f_garbagejob:server:emptyContainer', false)
            if worth then
                notify(('Kontainer dituang, kas kru +%s'):format(rupiah(worth)), 'success')
            end
            -- the driver owns the truck, so closing it here syncs to everyone. Don't wait for the
            -- container prop: on the last stop the route ends and the prop is gone before it is put back
            SetVehicleDoorShut(veh, door, false)
            busy = false
        end
    else
        hidePrompt()
    end
end

local function workLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local nextRender = 0
        while crew and crew.phase ~= 'lobby' do
            local wait = 1000
            local veh = truckEntity()
            if veh and truckTargetNet ~= crew.netId then registerTruckTarget() end
            local inTruck = veh and cache.vehicle == veh and cache.seat == -1

            if crew.phase == 'depot' then
                if not spawnRequested and #(GetEntityCoords(cache.ped) - depot.coords) < 60.0 then
                    spawnRequested = true
                    if not lib.callback.await('f_garbagejob:server:spawnTruck', false) then
                        SetTimeout(5000, function() spawnRequested = false end)
                    end
                end
            elseif crew.phase == 'route' and crew.stop then
                if GetGameTimer() >= nextRender then
                    nextRender = GetGameTimer() + 500
                    renderStop()
                end
                local c = crew.stop.coords
                local stopPos = vec3(c.x, c.y, c.z)
                if #(GetEntityCoords(cache.ped) - stopPos) < config.markerDistance then
                    wait = 0
                    drawStopMarkers()
                end
                if inTruck and crew.stop.container and crew.stop.container ~= 'done'
                    and #(GetEntityCoords(veh) - stopPos) < 30.0 then
                    wait = 0
                    handleScoop(veh, stopPos)
                else
                    hidePrompt()
                end
            elseif crew.phase == 'return' and inTruck then
                local dist = #(GetEntityCoords(veh) - depot.coords)
                if dist < 50.0 then
                    wait = 0
                    DrawMarker(1, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        depot.finishRadius * 2, depot.finishRadius * 2, 0.8, 243, 179, 84, 90, false, false, 2, false, nil, nil, false)
                    if dist < depot.finishRadius then
                        showPrompt('[E] Selesai shift')
                        if IsControlJustPressed(0, 38) and not busy then
                            busy = true
                            hidePrompt()
                            if not lib.callback.await('f_garbagejob:server:finish', false) then
                                notify('Parkir truk di area depo dulu.', 'error')
                            end
                            busy = false
                        end
                    else
                        hidePrompt()
                    end
                end
            else
                hidePrompt()
            end

            Wait(wait)
        end
        hidePrompt()
        loopRunning = false
    end)
end

---------------------------------------------------------------------------
-- server state
---------------------------------------------------------------------------
local function resetWork()
    dropHandBag()
    clearStopProps()
    clearBlip()
    removeTruckTarget()
    hidePrompt()
    spawnRequested, busy = false, false
end

local refreshMenu

-- right-centre progress panel, only sent when the server state changes
local function updateHud(data)
    if not data or data.phase == 'lobby' then
        return SendNUIMessage({ action = 'hud' })
    end

    local hud = { pool = data.pool, share = data.share, size = #data.members, crew = {} }
    if #data.members > 1 then
        for _, m in ipairs(data.members) do
            hud.crew[#hud.crew + 1] = { name = m.name, bags = m.bags }
        end
    end

    if data.phase == 'depot' then
        hud.title, hud.sub = 'Ambil truk di depo', 'Ikuti GPS ke Depo Sampah'
    elseif data.phase == 'return' then
        hud.title, hud.sub = 'Kembalikan truk', 'Parkir di depo lalu tekan [E]'
    elseif data.stop then
        local done = 0
        for _, bag in ipairs(data.stop.bags) do
            if bag.state == 2 then done += 1 end
        end
        hud.title = ('Titik %s/%s'):format(data.stopNum, data.totalStops)
        hud.sub = data.stop.label
        hud.bags = { done = done, total = #data.stop.bags }
        hud.container = data.stop.container
    end
    SendNUIMessage({ action = 'hud', data = hud })
end

-- panel Alur Kerja (f_panduan), opsional
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

AddEventHandler('f_panduan:client:requestStep', function(job)
    if job ~= 'sampah' or not crew or crew.phase == 'lobby' then return end
    local n = 2
    if crew.phase == 'return' then n = 5
    elseif crew.phase == 'route' and crew.stop then
        n = 4
        for _, bag in ipairs(crew.stop.bags) do
            if bag.state ~= 2 then n = 3 break end
        end
        if n == 4 and not crew.stop.container then n = 3 end
    end
    panduan('SetStep', 'sampah', n)
end)

RegisterNetEvent('f_garbagejob:client:sync', function(data)
    local prev = crew
    crew = data
    local wasWorking = prev ~= nil and prev.phase ~= 'lobby'
    if data.phase ~= 'lobby' and not wasWorking then panduan('Start', 'sampah')
    elseif data.phase == 'lobby' and wasWorking then panduan('Stop', 'sampah') end

    if data.phase ~= 'lobby' then
        applyOutfit()
        workLoop()
    end

    if data.phase == 'depot' then
        setRouteBlip(depot.coords, 2, 'Ambil Truk Sampah')
    elseif data.phase == 'route' and data.stop then
        if not prev or prev.phase ~= 'route' or prev.stopNum ~= data.stopNum then
            setRouteBlip(data.stop.coords, 25, ('Titik %s/%s: %s'):format(data.stopNum, data.totalStops, data.stop.label))
        end
        renderStop()
    elseif data.phase == 'return' then
        if not prev or prev.phase ~= 'return' then setRouteBlip(depot.coords, 2, 'Kembalikan Truk') end
        clearStopProps()
    else
        clearBlip()
    end

    updateHud(data)
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_garbagejob:client:ended', function(reason)
    crew = nil
    panduan('Stop', 'sampah')
    updateHud()
    resetWork()
    restoreOutfit()
    if reason then notify(reason, 'inform') end
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_garbagejob:client:invite', function(leaderName)
    local answer = lib.alertDialog({
        header = 'Ajakan Kerja Sampah',
        content = ('%s mengajakmu bergabung ke kru petugas kebersihan. Total gaji kru dibagi rata ke semua anggota.'):format(leaderName),
        centered = true,
        cancel = true,
        labels = { confirm = 'Terima', cancel = 'Tolak' },
    })
    lib.callback.await('f_garbagejob:server:respond', false, answer == 'confirm')
end)

---------------------------------------------------------------------------
-- menu (opened by f_cityhall job centre)
---------------------------------------------------------------------------
local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function refreshMenu()
    local data = lib.callback.await('f_garbagejob:server:getMenu', false)
    if not data or data.err then return closeMenu() end
    SendNUIMessage({ action = 'update', data = data })
end

local function openMenu()
    if menuOpen then return end
    local data = lib.callback.await('f_garbagejob:server:getMenu', false)
    if not data then return end
    if data.err then return notify(data.err, 'error') end
    menuOpen = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

-- local event only, triggered by f_cityhall after choosing Petugas Kebersihan
AddEventHandler('f_garbagejob:client:openMenu', openMenu)

RegisterNetEvent('f_garbagejob:client:menuRefresh', function()
    if menuOpen then refreshMenu() end
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_garbagejob:server:getMenu', false) or {})
end)

RegisterNUICallback('invite', function(data, cb)
    cb(lib.callback.await('f_garbagejob:server:invite', false, data.id) or { ok = false })
end)

RegisterNUICallback('start', function(data, cb)
    local res = lib.callback.await('f_garbagejob:server:start', false, data.difficulty) or { ok = false }
    if res.ok then closeMenu() end
    cb(res)
end)

RegisterNUICallback('leave', function(_, cb)
    lib.callback.await('f_garbagejob:server:leave', false)
    cb(lib.callback.await('f_garbagejob:server:getMenu', false) or {})
end)

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    resetWork()
    restoreOutfit()
    if menuOpen then SetNuiFocus(false, false) end
end)
