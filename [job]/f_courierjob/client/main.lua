local config = require 'config.client'
local sharedConfig = require 'config.shared'
local depot = sharedConfig.depot

local crew            -- latest server payload, nil when not in a crew
local blip
local groundProps = {}  -- package index -> { obj, pos }
local npc             -- { ped, stopNum }
local vanTargetNet
local carry           -- { id, index, role = 'front' | 'back' | 'wait', big, obj }
local carryId = 0
local busy = false
local loopRunning = false
local spawnRequested = false
local lostReported = false
local rearOffsetY

local promptText
local outfitSaved
local menuOpen = false

local CARRY_DICT, CARRY_ANIM = 'anim@heists@box_carry@', 'idle'

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

local function vanEntity()
    if not crew or not crew.netId or not NetworkDoesEntityExistWithNetworkId(crew.netId) then return end
    local veh = NetToVeh(crew.netId)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
end

local function getPackage(index)
    return crew and crew.packages and crew.packages[index]
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
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, colour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

---------------------------------------------------------------------------
-- van rear doors
---------------------------------------------------------------------------
local function nearRear(veh)
    if not rearOffsetY then
        local min = GetModelDimensions(GetEntityModel(veh))
        rearOffsetY = min.y - 0.4
    end
    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, rearOffsetY, 0.0)
    return #(GetEntityCoords(cache.ped) - rear) < config.rearDistance
end

local rearCloseAt = 0

local function openRear(veh)
    for _, door in ipairs(config.rearDoors) do SetVehicleDoorOpen(veh, door, false, false) end
    rearCloseAt = GetGameTimer() + 2500
    SetTimeout(2600, function()
        if GetGameTimer() < rearCloseAt or not DoesEntityExist(veh) then return end
        for _, door in ipairs(config.rearDoors) do SetVehicleDoorShut(veh, door, false) end
    end)
end

---------------------------------------------------------------------------
-- carrying (driven by server state: front walks, back is attached to the front)
---------------------------------------------------------------------------
local function stopCarry()
    if not carry then return end
    if carry.obj and DoesEntityExist(carry.obj) then DeleteEntity(carry.obj) end
    if carry.role == 'back' then DetachEntity(cache.ped, true, false) end
    StopAnimTask(cache.ped, CARRY_DICT, CARRY_ANIM, 1.0)
    carry = nil
    hidePrompt()
end

local function carryLoop(id)
    CreateThread(function()
        local nextAnim = 0
        while carry and carry.id == id do
            -- running is fine, but no jump, vehicles, cover or weapons while holding a box
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            if carry.role ~= 'wait' and GetGameTimer() >= nextAnim then
                nextAnim = GetGameTimer() + 1000
                if not IsEntityPlayingAnim(cache.ped, CARRY_DICT, CARRY_ANIM, 3) then
                    lib.playAnim(cache.ped, CARRY_DICT, CARRY_ANIM, 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
            if IsControlJustPressed(0, 73) and not busy then -- X
                busy = true
                if carry.role == 'wait' then
                    lib.callback.await('f_courierjob:server:cancelLift', false)
                else
                    lib.callback.await('f_courierjob:server:drop', false)
                end
                busy = false
            end
            Wait(0)
        end
    end)
end

local function startCarry(index, pkg, role)
    stopCarry()
    carryId += 1
    carry = { id = carryId, index = index, role = role, big = pkg.big }
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)

    if role == 'front' then
        local model = pkg.big and config.bigBoxModel or config.boxModel
        lib.requestModel(model, 5000)
        local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        SetModelAsNoLongerNeeded(model)
        local a = pkg.big and config.bigAttach or config.boxAttach
        local bone = a.bone == 0 and 0 or GetPedBoneIndex(cache.ped, a.bone)
        AttachEntityToEntity(obj, cache.ped, bone, a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, true, true, false, true, 1, true)
        carry.obj = obj
        showPrompt(pkg.big and '[X] Turunkan paket · Rekan ikut di depanmu' or '[X] Turunkan paket')
    elseif role == 'back' then
        -- GetPlayerPed(-1) would be our own ped, so check the partner is actually streamed in
        local player = GetPlayerFromServerId(pkg.front)
        local frontPed = player ~= -1 and GetPlayerPed(player) or 0
        if frontPed ~= 0 and frontPed ~= cache.ped then
            local o = config.backAttach
            AttachEntityToEntity(cache.ped, frontPed, 11816, o.x, o.y, o.z, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
        end
        showPrompt('Rekanmu yang berjalan · [X] Turunkan paket')
    else
        showPrompt('Menunggu rekan angkat belakang · [X] Batal')
    end
    carryLoop(carry.id)
end

local function reconcileCarry()
    local me = cache.serverId
    local index, pkg
    for i, p in ipairs(crew and crew.packages or {}) do
        if p.front == me or p.back == me then
            index, pkg = i, p
            break
        end
    end
    if not pkg then return stopCarry() end
    local role = pkg.state ~= 'held' and 'wait' or pkg.front == me and 'front' or 'back'
    if carry and carry.index == index and carry.role == role then return end
    startCarry(index, pkg, role)
end

local function lift(index)
    if busy or carry then return end
    busy = true
    local res = lib.callback.await('f_courierjob:server:lift', false, index)
    if res and res.ok and not res.wait then
        lib.playAnim(cache.ped, 'pickup_object', 'pickup_low', 8.0, -8.0, 700, 0, 0.0, false, false, false)
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

local function liftBack(index)
    if busy or carry then return end
    busy = true
    local res = lib.callback.await('f_courierjob:server:lift', false, index)
    if res and not res.ok and res.msg then notify(res.msg, 'error') end
    busy = false
end

---------------------------------------------------------------------------
-- packages on the ground (pile at the depot / dropped), local props
---------------------------------------------------------------------------
local function deleteProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    exports.ox_target:removeLocalEntity(obj)
    DeleteEntity(obj)
end

local function spawnProp(model, pos, heading)
    if not IsModelInCdimage(model) then model = config.boxModel end
    lib.requestModel(model, 5000)
    local obj = CreateObject(model, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(obj, heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    return obj
end

local function addPackageTarget(obj, index, pkg)
    local me = cache.serverId
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'fcj_take',
            label = ('Ambil paket · Titik %s'):format(pkg.stop),
            icon = 'fa-solid fa-box',
            distance = 2.0,
            canInteract = function()
                local p = getPackage(index)
                return p and not p.big and not carry and not busy
            end,
            onSelect = function() lift(index) end,
        },
        {
            name = 'fcj_front',
            label = ('Angkat depan · Paket BESAR titik %s'):format(pkg.stop),
            icon = 'fa-solid fa-people-carry-box',
            distance = 2.0,
            canInteract = function()
                local p = getPackage(index)
                return p and p.big and not p.front and not carry and not busy
            end,
            onSelect = function() lift(index) end,
        },
        {
            name = 'fcj_back',
            label = 'Angkat belakang · Paket BESAR',
            icon = 'fa-solid fa-people-carry-box',
            distance = 2.0,
            canInteract = function()
                local p = getPackage(index)
                return p and p.big and p.front and p.front ~= me and not carry and not busy
            end,
            onSelect = function() liftBack(index) end,
        },
    })
end

local function clearGround()
    for i, g in pairs(groundProps) do
        deleteProp(g.obj)
        groundProps[i] = nil
    end
end

local function renderGround()
    local pkgs = crew and crew.packages
    if not pkgs then return clearGround() end
    local myPos = GetEntityCoords(cache.ped)
    local keep = {}
    for i, p in ipairs(pkgs) do
        if p.state == 'ground' and p.pos and #(myPos - p.pos) < config.propDistance then
            local g = groundProps[i]
            if g and #(g.pos - p.pos) > 0.05 then
                deleteProp(g.obj)
                g, groundProps[i] = nil, nil
            end
            if not g then
                local obj = spawnProp(p.big and config.bigBoxModel or config.boxModel, p.pos, (i * 37) % 360 + 0.0)
                groundProps[i] = { obj = obj, pos = p.pos }
                addPackageTarget(obj, i, p)
            end
            keep[i] = true
        end
    end
    for i, g in pairs(groundProps) do
        if not keep[i] then
            deleteProp(g.obj)
            groundProps[i] = nil
        end
    end
end

---------------------------------------------------------------------------
-- receiver NPC (local, only near the current stop)
---------------------------------------------------------------------------
local function clearNpc()
    if not npc then return end
    if DoesEntityExist(npc.ped) then
        exports.ox_target:removeLocalEntity(npc.ped)
        DeleteEntity(npc.ped)
    end
    npc = nil
end

local function deliver()
    if busy or not carry or carry.role ~= 'front' then return end
    local pkg = getPackage(carry.index)
    if not pkg then return end
    busy = true
    if pkg.sign then
        -- receiver writes on a notepad: plain anim + local props, works on every ped model
        -- (WORLD_HUMAN_CLIPBOARD is male only, so most female receivers just stood still)
        local receiver = npc and DoesEntityExist(npc.ped) and npc.ped
        local props = {}
        if receiver then
            local sign = config.signAnim
            lib.playAnim(receiver, sign.dict, sign.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            local pos = GetEntityCoords(receiver)
            for _, p in ipairs(sign.props) do
                lib.requestModel(p.model, 2000)
                local obj = CreateObject(p.model, pos.x, pos.y, pos.z, false, false, false)
                SetModelAsNoLongerNeeded(p.model)
                AttachEntityToEntity(obj, receiver, GetPedBoneIndex(receiver, p.bone), p.pos.x, p.pos.y, p.pos.z,
                    p.rot.x, p.rot.y, p.rot.z, true, true, false, true, 1, true)
                props[#props + 1] = obj
            end
        end
        local signed = lib.progressBar({
            duration = config.signDuration,
            label = 'Penerima menandatangani tanda terima...',
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })
        for _, obj in ipairs(props) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end
        if receiver and DoesEntityExist(receiver) then ClearPedTasks(receiver) end
        if not signed then
            busy = false
            return
        end
    end
    local res = lib.callback.await('f_courierjob:server:deliver', false)
    if res and res.ok then
        notify(('Paket diterima, kas kru +%s'):format(rupiah(res.worth)), 'success')
        if npc and DoesEntityExist(npc.ped) then
            lib.playAnim(npc.ped, 'mp_common', 'givetake1_b', 8.0, -8.0, 1500, 0, 0.0, false, false, false)
        end
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

-- the receiver waits on the pavement in front of the address, never inside a shop or behind a house.
-- Navmesh based, so every crew member gets the same spot.
local function receiverSpot(c)
    -- 13 = only pavement + not interior + not water, 12 = any ground outside
    local spot = c
    for _, flags in ipairs({ 13, 12 }) do
        local ok, pos = GetSafeCoordForPed(c.x, c.y, c.z, true, flags)
        if ok and #(pos - c) <= config.npcSnapDistance then
            spot = pos
            break
        end
    end
    -- navmesh height is not the real ground (curbs, slopes): drop to the actual surface
    local found, groundZ = GetGroundZFor_3dCoord(spot.x, spot.y, spot.z + 1.0, false)
    return vec3(spot.x, spot.y, found and groundZ or spot.z - 1.0)
end

local function renderNpc()
    local stop = crew and crew.phase == 'route' and crew.stop
    if not stop then return clearNpc() end
    local c = stop.coords
    local myPos = GetEntityCoords(cache.ped)
    local near = #(myPos - c) < config.npcDistance
    if npc and (npc.stopNum ~= crew.stopNum or not near) then clearNpc() end
    if npc or not near then return end

    local model = config.receiverModels[stop.index % #config.receiverModels + 1]
    lib.requestModel(model, 5000)
    local pos = receiverSpot(c)
    local heading = GetHeadingFromVector_2d(myPos.x - pos.x, myPos.y - pos.y)
    local ped = CreatePed(4, model, pos.x, pos.y, pos.z, heading, false, true)
    SetModelAsNoLongerNeeded(model)
    -- let gravity put the feet on the ground first, then freeze so the van can't push them
    SetPedCanRagdoll(ped, false)
    SetTimeout(1500, function()
        if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end
    end)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    npc = { ped = ped, stopNum = crew.stopNum }

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'fcj_deliver',
            label = 'Serahkan paket',
            icon = 'fa-solid fa-box-open',
            distance = 2.5,
            canInteract = function()
                local p = carry and carry.role == 'front' and getPackage(carry.index)
                return p and p.state == 'held' and p.stop == crew.stopNum and not busy
            end,
            onSelect = deliver,
        },
    })
end

---------------------------------------------------------------------------
-- van target
---------------------------------------------------------------------------
local VAN_OPTIONS = { 'fcj_load', 'fcj_unload', 'fcj_unload_big', 'fcj_unload_back', 'fcj_cancel', 'fcj_leave' }

local function removeVanTarget()
    if not vanTargetNet then return end
    exports.ox_target:removeEntity(vanTargetNet, VAN_OPTIONS)
    vanTargetNet = nil
end

-- package in the van for the current stop. withFront: a big one a partner already lifted at the front
local function vanPackage(big, withFront)
    if not crew or crew.phase ~= 'route' or not crew.packages then return end
    local me = cache.serverId
    for i, p in ipairs(crew.packages) do
        if p.state == 'van' and p.stop == crew.stopNum and (p.big == true) == big then
            if withFront and p.front and p.front ~= me then return i end
            if not withFront and not p.front then return i end
        end
    end
end

local function confirmLeave()
    local leader = isLeader()
    local answer = lib.alertDialog({
        header = leader and 'Batalkan kerja kurir?' or 'Keluar dari kru?',
        content = leader
            and 'Van akan dikembalikan dan seluruh kru selesai. Kas kru yang sudah terkumpul dibagi rata ke semua anggota.'
            or 'Kamu menerima bagian rata dari kas kru sejauh ini, sisanya tetap untuk kru.',
        centered = true,
        cancel = true,
        labels = { confirm = leader and 'Batalkan' or 'Keluar', cancel = 'Kembali' },
    })
    if answer == 'confirm' then lib.callback.await('f_courierjob:server:leave', false) end
end

local function loadIntoVan(data)
    if busy or not carry or carry.role ~= 'front' then return end
    busy = true
    local ok, msg = lib.callback.await('f_courierjob:server:load', false)
    if ok then
        openRear(data.entity)
    elseif msg then
        notify(msg, 'error')
    end
    busy = false
end

local function takeFromVan(data, big, withFront)
    local index = vanPackage(big, withFront)
    if not index then return end
    openRear(data.entity)
    if withFront then liftBack(index) else lift(index) end
end

local function registerVanTarget()
    if not crew or not crew.netId or vanTargetNet == crew.netId then return end
    if not NetworkDoesNetworkIdExist(crew.netId) then return end
    removeVanTarget()
    vanTargetNet = crew.netId
    exports.ox_target:addEntity(crew.netId, {
        {
            name = 'fcj_load',
            label = 'Masukkan paket ke van',
            icon = 'fa-solid fa-truck-ramp-box',
            distance = 3.0,
            canInteract = function(entity) return carry and carry.role == 'front' and not busy and nearRear(entity) end,
            onSelect = loadIntoVan,
        },
        {
            name = 'fcj_unload',
            label = 'Ambil paket untuk titik ini',
            icon = 'fa-solid fa-box',
            distance = 3.0,
            canInteract = function(entity) return not carry and not busy and vanPackage(false) and nearRear(entity) end,
            onSelect = function(data) takeFromVan(data, false) end,
        },
        {
            name = 'fcj_unload_big',
            label = 'Angkat depan · Paket BESAR',
            icon = 'fa-solid fa-people-carry-box',
            distance = 3.0,
            canInteract = function(entity) return not carry and not busy and vanPackage(true) and nearRear(entity) end,
            onSelect = function(data) takeFromVan(data, true) end,
        },
        {
            name = 'fcj_unload_back',
            label = 'Angkat belakang · Paket BESAR',
            icon = 'fa-solid fa-people-carry-box',
            distance = 3.0,
            canInteract = function(entity) return not carry and not busy and vanPackage(true, true) and nearRear(entity) end,
            onSelect = function(data) takeFromVan(data, true, true) end,
        },
        {
            name = 'fcj_cancel',
            label = 'Batalkan kerja kurir',
            icon = 'fa-solid fa-ban',
            distance = 3.0,
            canInteract = function() return isLeader() and crew.phase ~= 'lobby' and not carry end,
            onSelect = confirmLeave,
        },
        {
            name = 'fcj_leave',
            label = 'Keluar dari kru',
            icon = 'fa-solid fa-person-walking-arrow-right',
            distance = 3.0,
            canInteract = function() return crew ~= nil and not isLeader() and not carry end,
            onSelect = confirmLeave,
        },
    })
end

---------------------------------------------------------------------------
-- work loop
---------------------------------------------------------------------------
local openMenu

local function workLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local nextRender = 0
        while crew and (crew.phase ~= 'lobby' or crew.atDepot) do
            local wait = 1000
            local veh = vanEntity()
            if veh and vanTargetNet ~= crew.netId then registerVanTarget() end
            local inVan = veh and cache.vehicle == veh and cache.seat == -1

            if GetGameTimer() >= nextRender then
                nextRender = GetGameTimer() + 500
                renderGround()
                renderNpc()
            end

            -- destroyed or sunk van ends the job (server only trusts this from a crew member)
            if veh and not lostReported and crew.phase ~= 'depot'
                and (IsEntityDead(veh) or (IsEntityInWater(veh) and GetEntitySubmergedLevel(veh) > 0.7)) then
                lostReported = true
                lib.callback.await('f_courierjob:server:vanLost', false)
            end

            if crew.phase == 'depot' then
                if not spawnRequested and #(GetEntityCoords(cache.ped) - depot.coords) < 60.0 then
                    spawnRequested = true
                    if not lib.callback.await('f_courierjob:server:spawnVan', false) then
                        SetTimeout(5000, function() spawnRequested = false end)
                    end
                end
            elseif crew.phase == 'return' and inVan then
                local dist = #(GetEntityCoords(veh) - depot.coords)
                if dist < 50.0 then
                    wait = 0
                    DrawMarker(1, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        depot.finishRadius * 2, depot.finishRadius * 2, 0.8, 243, 179, 84, 90, false, false, 2, false, nil, nil, false)
                    if dist < depot.finishRadius then
                        showPrompt('[E] Selesai rute')
                        if IsControlJustPressed(0, 38) and not busy then
                            busy = true
                            hidePrompt()
                            if not lib.callback.await('f_courierjob:server:finish', false) then
                                notify('Parkir van di area depot dulu.', 'error')
                            end
                            busy = false
                        end
                    else
                        hidePrompt()
                    end
                end
            elseif crew.phase == 'lobby' and not menuOpen and #(GetEntityCoords(cache.ped) - depot.coords) < 10.0 then
                -- menu closed by mistake after a route: reopen it here while the crew still waits
                wait = 0
                showPrompt('[E] Buka menu kurir')
                if IsControlJustPressed(0, 38) then
                    hidePrompt()
                    openMenu()
                end
            elseif not carry then
                hidePrompt()
            end

            Wait(wait)
        end
        if not carry then hidePrompt() end
        loopRunning = false
    end)
end

---------------------------------------------------------------------------
-- server state
---------------------------------------------------------------------------
local function resetWork()
    stopCarry()
    clearGround()
    clearNpc()
    clearBlip()
    removeVanTarget()
    hidePrompt()
    spawnRequested, busy, lostReported = false, false, false
end

local refreshMenu, closeMenu

-- right-centre progress panel, only sent when the server state changes
local function updateHud(data)
    if not data or (data.phase == 'lobby' and not data.atDepot) then
        return SendNUIMessage({ action = 'hud' })
    end

    local hud = { pool = data.pool, share = data.share, size = #data.members, crew = {}, rows = {} }
    if #data.members > 1 then
        for _, m in ipairs(data.members) do
            hud.crew[#hud.crew + 1] = { name = m.name, delivered = m.delivered }
        end
    end

    local pkgs = data.packages or {}
    if data.phase == 'lobby' then
        hud.title, hud.sub = 'Rute selesai', 'Pilih rute berikutnya di menu'
    elseif data.phase == 'depot' then
        hud.title, hud.sub = 'Ambil van di depot', 'Ikuti GPS ke depot GoPostal'
    elseif data.phase == 'load' then
        local loaded = 0
        for _, p in ipairs(pkgs) do
            if p.state == 'van' then loaded += 1 end
        end
        hud.title, hud.sub = 'Muat paket ke van', 'Ambil dari tumpukan, masukkan lewat pintu belakang'
        hud.bar = { label = 'Dimuat', done = loaded, total = #pkgs }
    elseif data.phase == 'return' then
        hud.title, hud.sub = 'Kembalikan van', 'Parkir di depot GoPostal lalu tekan [E]'
    elseif data.stop then
        local done, total, inVan = 0, 0, 0
        for _, p in ipairs(pkgs) do
            if p.stop == data.stopNum then
                total += 1
                if p.state == 'done' then done += 1 end
            end
            if p.state == 'van' then inVan += 1 end
        end
        hud.title = ('Titik %s/%s'):format(data.stopNum, data.totalStops)
        hud.sub = data.stop.label
        hud.bar = { label = 'Paket titik ini', done = done, total = total }
        hud.rows[1] = { 'Sisa di van', ('%s paket'):format(inVan) }
    end
    SendNUIMessage({ action = 'hud', data = hud })
end

-- panel Alur Kerja (f_panduan), opsional
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

AddEventHandler('f_panduan:client:requestStep', function(job)
    if job ~= 'kurir' or not crew or crew.phase == 'lobby' then return end
    local n = ({ depot = 2, load = 2, route = 3, ['return'] = 5 })[crew.phase] or 2
    panduan('SetStep', 'kurir', n)
end)

RegisterNetEvent('f_courierjob:client:sync', function(data)
    local prev = crew
    crew = data
    local wasWorking = prev ~= nil and prev.phase ~= 'lobby'
    if data.phase ~= 'lobby' and not wasWorking then panduan('Start', 'kurir')
    elseif data.phase == 'lobby' and wasWorking then panduan('Stop', 'kurir') end

    if data.phase ~= 'lobby' then
        applyOutfit()
        lostReported = false
    end
    if data.phase ~= 'lobby' or data.atDepot then workLoop() end
    -- a new route reuses the same pile spots, so rebuild the props (their targets name the stop)
    if data.phase == 'load' and (not prev or prev.phase ~= 'load') then clearGround() end

    if data.phase == 'depot' then
        setRouteBlip(depot.coords, 2, 'Depot GoPostal')
    elseif data.phase == 'route' and data.stop then
        if not prev or prev.phase ~= 'route' or prev.stopNum ~= data.stopNum then
            setRouteBlip(data.stop.coords, 5, ('Titik %s/%s: %s'):format(data.stopNum, data.totalStops, data.stop.label))
        end
    elseif data.phase == 'return' then
        if not prev or prev.phase ~= 'return' then setRouteBlip(depot.coords, 2, 'Kembalikan Van') end
    else
        clearBlip()
    end

    reconcileCarry()
    renderGround()
    renderNpc()
    updateHud(data)
    if menuOpen then
        -- the leader started the next route: members' menus close too
        if data.phase ~= 'lobby' then closeMenu() else refreshMenu() end
    end
end)

RegisterNetEvent('f_courierjob:client:ended', function(reason)
    crew = nil
    panduan('Stop', 'kurir')
    updateHud()
    resetWork()
    restoreOutfit()
    if reason then notify(reason, 'inform') end
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_courierjob:client:invite', function(leaderName)
    local answer = lib.alertDialog({
        header = 'Ajakan Kurir Paket',
        content = ('%s mengajakmu bergabung ke kru kurir paket GoPostal. Total gaji kru dibagi rata ke semua anggota.'):format(leaderName),
        centered = true,
        cancel = true,
        labels = { confirm = 'Terima', cancel = 'Tolak' },
    })
    lib.callback.await('f_courierjob:server:respond', false, answer == 'confirm')
end)

---------------------------------------------------------------------------
-- menu (opened by f_cityhall job centre, and at the depot after every route)
---------------------------------------------------------------------------
function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function refreshMenu()
    local data = lib.callback.await('f_courierjob:server:getMenu', false)
    if not data or data.err then return closeMenu() end
    SendNUIMessage({ action = 'update', data = data })
end

function openMenu()
    if menuOpen then return end
    local data = lib.callback.await('f_courierjob:server:getMenu', false)
    if not data then return end
    if data.err then return notify(data.err, 'error') end
    menuOpen = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

-- local event only, triggered by f_cityhall after choosing Kurir Paket
AddEventHandler('f_courierjob:client:openMenu', openMenu)

RegisterNetEvent('f_courierjob:client:routeDone', function()
    hidePrompt()
    openMenu()
end)

RegisterNetEvent('f_courierjob:client:menuRefresh', function()
    if menuOpen then refreshMenu() end
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_courierjob:server:getMenu', false) or {})
end)

RegisterNUICallback('invite', function(data, cb)
    cb(lib.callback.await('f_courierjob:server:invite', false, data.id) or { ok = false })
end)

RegisterNUICallback('kick', function(data, cb)
    cb(lib.callback.await('f_courierjob:server:kick', false, data.id) or {})
end)

RegisterNUICallback('start', function(data, cb)
    local res = lib.callback.await('f_courierjob:server:start', false, data.difficulty) or { ok = false }
    if res.ok then closeMenu() end
    cb(res)
end)

RegisterNUICallback('leave', function(_, cb)
    lib.callback.await('f_courierjob:server:leave', false)
    cb(lib.callback.await('f_courierjob:server:getMenu', false) or {})
end)

---------------------------------------------------------------------------
-- calibration helper: stand on the spot facing the street, copies vec4 to the clipboard
---------------------------------------------------------------------------
RegisterCommand('kurirpos', function()
    local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h)
    lib.setClipboard(text)
    notify(('Disalin: %s'):format(text), 'success')
end, false)

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    resetWork()
    restoreOutfit()
    if menuOpen then SetNuiFocus(false, false) end
end)
