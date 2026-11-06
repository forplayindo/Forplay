local config = require 'config.client'
local sharedConfig = require 'config.shared'
local M = sharedConfig.models
local A = config.anims

NLY = NLY or {}

local job               -- payload kru terakhir dari server (milik pemain ini), nil saat tidak di kru
local readyAt = 0       -- GetGameTimer() saat jaringku siap ditarik
local returnAt          -- GetGameTimer() batas mengembalikan bison (bagianku sudah habis terjual)
local busy = false
local loopRunning = false
local menuOpen = false
local promptText
local carry             -- { obj, from = 'pier' | 'truck' | 'net' }
local blip, radiusBlip
local shoal
local pierProps = {}
local pierGround = {}
local truckTargetNet
local lostReported = false

local function notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
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

local function working()
    return job ~= nil and job.phase == 'work'
end

local function netEntity(netId)
    if not netId or not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local ent = NetToVeh(netId)
    if ent ~= 0 and DoesEntityExist(ent) then return ent end
end

local function boat() return working() and netEntity(job.boatNet) end
local function truck() return working() and netEntity(job.truckNet) end

local function nearOffset(veh, off, radius)
    return #(GetEntityCoords(cache.ped) - GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)) < radius
end

---------------------------------------------------------------------------
-- blip & waypoint
---------------------------------------------------------------------------
local function clearBlips()
    if blip then RemoveBlip(blip) end
    if radiusBlip then RemoveBlip(radiusBlip) end
    blip, radiusBlip = nil, nil
end

local function setBlip(coords, sprite, colour, label, radius)
    clearBlips()
    if radius then
        radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
        SetBlipColour(radiusBlip, colour)
        SetBlipAlpha(radiusBlip, 90)
    end
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

-- tugas pemain ini sekarang (urut prioritas)
local function stage()
    if not working() then return end
    if job.carry == 'pier' then return 'loadTruck' end
    if job.carry == 'truck' then return 'sell' end
    if job.net then return GetGameTimer() < readyAt and 'soak' or 'haul' end
    if job.catch > 0 then return 'sort' end
    if job.quota > 0 then return 'pier' end          -- bagianku masih di dermaga
    if job.truck > 0 then return 'market' end        -- bagianku di bison, antar ke pasar
    if returnAt then return 'returnTruck' end        -- bison kosong wajib kembali ke parkiran dermaga
    if job.deckEmpty > 0 then return 'cast' end
    return 'return'                                  -- semua peti di kapal penuh
end

local WHERE = {
    cast = 'sea', soak = 'sea', haul = 'sea', sort = 'sea',
    ['return'] = 'dock', pier = 'pier', loadTruck = 'pier', market = 'market', sell = 'market', returnTruck = 'parking',
}

local lastBlip
local function updateBlip()
    local where = WHERE[stage() or '']
    local key = where and (where .. (job.spot and job.spot.label or ''))
    if key == lastBlip then return end
    lastBlip = key
    if not where then return clearBlips() end
    local target
    if where == 'sea' then
        target = job.spot.coords
        setBlip(target, 68, job.spot.far and 46 or 3, ('Spot Ikan: %s'):format(job.spot.label), sharedConfig.spotRadius)
    elseif where == 'dock' then
        target = sharedConfig.dock
        setBlip(target, 410, 2, 'Sandaran Kapal Nelayan')
    elseif where == 'parking' then
        target = sharedConfig.truckSpawn.xyz
        setBlip(target, 50, 2, 'Parkir Bison Nelayan')
    elseif where == 'pier' then
        target = sharedConfig.pier.xyz
        setBlip(target, 478, 2, 'Tumpukan Peti Ikan')
    else
        target = sharedConfig.market.coords.xyz
        setBlip(target, 52, 5, sharedConfig.market.label)
    end
    -- rute GPS tidak jalan di laut: tujuan baru langsung dipasang sebagai waypoint peta
    SetNewWaypoint(target.x, target.y)
end

---------------------------------------------------------------------------
-- HUD (kanan tengah, dikirim saat state berubah + tiap detik selama jaring direndam)
---------------------------------------------------------------------------
local TITLES = {
    cast = { 'Tebar jaring', '' },
    soak = { 'Jaring direndam', '' },
    haul = { 'Tarik jaring!', 'Berdiri di buritan, tekan [E]' },
    sort = { 'Masukkan ke peti', 'Bawa jaring isi ikan ke tumpukan peti di dek' },
    ['return'] = { 'Peti kapal penuh', 'Pulang, sandarkan kapal, turunkan peti' },
    pier = { 'Muat bagianmu', 'Angkat peti dari dermaga ke bak bison-mu' },
    loadTruck = { 'Muat bagianmu', 'Bawa peti ke bak belakang bison-mu' },
    market = { 'Jual di Pasar Ikan', 'Parkir bison di pasar, bawa peti ke pedagang' },
    sell = { 'Jual di Pasar Ikan', 'Serahkan peti ke pedagang' },
    nonet = { 'Tidak punya jaring', 'Beli jaring di Syahbandar dermaga' },
    returnTruck = { 'Kembalikan bison', '' },
}

-- tips langkah berikutnya (kotak bawah HUD), sesuai posisi pemain
local TIPS = {
    soak = 'Tunggu ikan masuk ke jaring. Jangan bawa kapal lebih dari 120 m dari jaring, nanti jaring putus.',
    haul = 'Ke dek belakang (lingkaran biru), tekan [E]. Tekan [E] saat penanda di zona hijau. Minimal 2 dari 3 harus tepat, kalau tidak ikannya lepas.',
    sort = 'Bawa jaring ke tumpukan peti di dek. Arahkan target ke peti → "Masukkan ikan ke peti".',
    ['return'] = 'Kemudikan kapal ke dermaga (waypoint). Setelah bersandar, arahkan target ke peti → "Turunkan semua peti".',
    pier = 'Arahkan target ke tumpukan peti di dermaga → "Angkat peti", lalu bawa ke bak belakang bison-mu (berjajar di dekat tumpukan).',
    loadTruck = 'Ke bak belakang bison-mu, arahkan target → "Muat peti ke bak". Tekan [X] untuk menaruh kembali.',
    market = 'Setir bison ke Pasar Ikan (waypoint). Parkir dekat pedagang, arahkan target ke bak → "Ambil peti dari bak".',
    sell = 'Bawa peti ke pedagang Pasar Ikan, arahkan target → "Jual peti ikan".',
    returnTruck = 'Setir bison ke parkiran dermaga (waypoint), parkir lalu turun. Bison hilang otomatis tanpa denda.',
}

local function castTip()
    if job.nets <= 0 then return 'Beli Jaring Ikan lewat target NPC Syahbandar di dermaga.' end
    local veh = boat()
    if not veh then return 'Kapal belum terlihat, dekati dermaga.' end
    local onBoat = cache.vehicle == veh or (#(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) < 20.0)
    if not onBoat then return 'Arahkan target ke kapal tug di dermaga → "Naik ke kapal".' end
    if #(GetEntityCoords(veh).xy - job.spot.coords.xy) > sharedConfig.spotRadius then
        return 'Kemudikan kapal ke spot ikan (lingkaran di peta, waypoint sudah dipasang).'
    end
    if cache.vehicle == veh then return 'Sudah di spot ikan! Pelankan kapal, keluar dari kemudi, jalan ke dek belakang.' end
    return 'Berdiri di dek belakang (lingkaran biru), tekan [E] untuk menebar jaring.'
end

local function updateHud()
    if not working() then return SendNUIMessage({ action = 'hud' }) end
    local s = stage()
    local t = TITLES[s]
    local sub = t[2]
    if s == 'sort' and job.catchLabel then
        sub = ('Di tanganmu: %s'):format(job.catchLabel)
    elseif s == 'soak' then
        sub = ('Siap ditarik dalam %s detik'):format(math.ceil((readyAt - GetGameTimer()) / 1000))
    elseif s == 'returnTruck' then
        local left = math.max(0, math.ceil((returnAt - GetGameTimer()) / 1000))
        sub = ('Parkir di dermaga & turun dalam %d:%02d, atau denda'):format(left // 60, left % 60)
    elseif s == 'cast' then
        sub = job.spot.label .. (job.spot.far and ' (spot jauh: ikan mahal lebih sering)' or '')
        if job.nets <= 0 then t = TITLES.nonet sub = t[2] end
    end
    local rows = {}
    if #job.members > 1 then rows[#rows + 1] = { 'Kru', ('%s orang'):format(#job.members) } end
    rows[#rows + 1] = { 'Jaring di tas', ('%s buah'):format(job.nets) }
    rows[#rows + 1] = { 'Peti di kapal', ('%s/%s isi'):format(job.deckFull, job.capacity) }
    if job.pier > 0 or job.quota > 0 then
        rows[#rows + 1] = { 'Di dermaga', ('%s peti · bagianmu %s'):format(job.pier, job.quota) }
    end
    rows[#rows + 1] = { 'Bison-mu', ('%s/%s peti'):format(job.truck, sharedConfig.bedCapacity) }
    local tip = s == 'cast' and castTip() or TIPS[s]
    SendNUIMessage({ action = 'hud', data = { title = t[1], sub = sub, rows = rows, earned = job.earned, tip = tip } })
end

---------------------------------------------------------------------------
-- kerumunan ikan di spot (lokal)
---------------------------------------------------------------------------
local function clearShoal()
    if shoal and DoesEntityExist(shoal) then DeleteEntity(shoal) end
    shoal = nil
end

local function renderShoal()
    local s = stage()
    local active = s == 'cast' or s == 'soak' or s == 'haul'
    local c = active and job.spot.coords
    if not c or #(GetEntityCoords(cache.ped).xy - c.xy) > config.shoalDistance then return clearShoal() end
    if shoal and DoesEntityExist(shoal) and #(GetEntityCoords(shoal).xy - c.xy) < 1.0 then return end
    clearShoal()
    lib.requestModel(M.shoal, 5000)
    local found, h = GetWaterHeight(c.x, c.y, 5.0)
    shoal = CreateObject(M.shoal, c.x, c.y, (found and h or 0.0) - 1.0, false, false, false)
    SetModelAsNoLongerNeeded(M.shoal)
    FreezeEntityPosition(shoal, true)
    SetEntityCollision(shoal, false, false)
end

---------------------------------------------------------------------------
-- membawa peti / jaring isi ikan (prop network supaya pemain lain melihat)
---------------------------------------------------------------------------
local function stopCarry()
    if not carry then return end
    if DoesEntityExist(carry.obj) then DeleteEntity(carry.obj) end
    StopAnimTask(cache.ped, A.carry.dict, A.carry.clip, 1.0)
    carry = nil
    hidePrompt()
end

-- from: 'pier' / 'truck' = peti ikan, 'net' = jaring isi ikan hasil tarikan (dipegang sampai masuk peti)
local function startCarry(from)
    stopCarry()
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
    local isNet = from == 'net'
    local model = isNet and M.netFish or M.crateFull
    lib.requestModel(model, 5000)
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(obj, false, false)
    local a = isNet and config.netFishAttach or config.crateAttach
    local bone = a.bone == 0 and 0 or GetPedBoneIndex(cache.ped, a.bone)
    AttachEntityToEntity(obj, cache.ped, bone, a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, true, true, false, true, 1, true)
    carry = { obj = obj, from = from }
    showPrompt(isNet and 'Bawa ke tumpukan peti di dek, lalu Masukkan ikan' or '[X] Taruh kembali peti')
    local me = carry
    CreateThread(function()
        local nextAnim = 0
        while carry == me do
            DisableControlAction(0, 21, true)  -- lari (berat)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            if GetGameTimer() >= nextAnim then
                nextAnim = GetGameTimer() + 1000
                if not IsEntityPlayingAnim(cache.ped, A.carry.dict, A.carry.clip, 3) then
                    lib.playAnim(cache.ped, A.carry.dict, A.carry.clip, 8.0, -8.0, -1, 49, 0, false, false, false)
                end
            end
            if me.from ~= 'net' and IsControlJustPressed(0, 73) and not busy then -- X
                busy = true
                lib.callback.await('f_nelayan:server:putBack', false)
                busy = false
            end
            Wait(0)
        end
    end)
end

local function reconcileCarry()
    local from = working() and (job.catch > 0 and 'net' or job.carry)
    if not from then return stopCarry() end
    if carry and carry.from == from then return end
    startCarry(from)
end

local function take(from)
    if busy or carry then return end
    busy = true
    local res = lib.callback.await('f_nelayan:server:take', false, from)
    if res and res.ok then
        lib.playAnim(cache.ped, A.pickup.dict, A.pickup.clip, 8.0, -8.0, 700, 0, 0.0, false, false, false)
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

---------------------------------------------------------------------------
-- tumpukan peti di dermaga (lokal): 4 kolom x 2 baris per lapis, maks 4 lapis (32 peti)
---------------------------------------------------------------------------
local function pierSpot(i)
    local p = sharedConfig.pier
    local slot, layer = (i - 1) % 8, (i - 1) // 8
    local h = math.rad(p.w)
    local rx, ry = math.cos(h), math.sin(h)
    local fx, fy = -math.sin(h), math.cos(h)
    local side, fwd = (slot % 4 - 1.5) * 0.7, (slot // 4) * 0.5
    local x, y = p.x + rx * side + fx * fwd, p.y + ry * side + fy * fwd
    if not pierGround[slot] then
        local found, z = GetGroundZFor_3dCoord(x, y, p.z + 1.5, false)
        pierGround[slot] = found and z or p.z - 1.0
    end
    return vec3(x, y, pierGround[slot] + layer * config.tug.crateLayer)
end

local function clearPier()
    for i, obj in pairs(pierProps) do
        if DoesEntityExist(obj) then
            exports.ox_target:removeLocalEntity(obj)
            DeleteEntity(obj)
        end
        pierProps[i] = nil
    end
end

local function renderPier()
    local count = working() and job.pier or 0
    if count == 0 or #(GetEntityCoords(cache.ped) - sharedConfig.pier.xyz) > 80.0 then return clearPier() end
    for i = 1, math.max(count, #pierProps) do
        if i <= count and not pierProps[i] then
            local pos = pierSpot(i)
            lib.requestModel(M.crateFull, 5000)
            local obj = CreateObject(M.crateFull, pos.x, pos.y, pos.z, false, false, false)
            SetModelAsNoLongerNeeded(M.crateFull)
            SetEntityHeading(obj, sharedConfig.pier.w)
            FreezeEntityPosition(obj, true)
            exports.ox_target:addLocalEntity(obj, {
                {
                    name = 'fnl_pier_take', label = 'Angkat peti ikan (bagianmu)', icon = 'fa-solid fa-box', distance = 2.5,
                    canInteract = function() return working() and job.quota > 0 and not carry and not busy end,
                    onSelect = function() take('pier') end,
                },
            })
            pierProps[i] = obj
        elseif i > count and pierProps[i] then
            exports.ox_target:removeLocalEntity(pierProps[i])
            DeleteEntity(pierProps[i])
            pierProps[i] = nil
        end
    end
end

---------------------------------------------------------------------------
-- peti di dek tug (prop dari client/visual.lua, tanpa collision): opsi dipasang di entitas tug
---------------------------------------------------------------------------
local function nearCrates(veh)
    local me = GetEntityCoords(cache.ped)
    for _, off in ipairs(config.tug.crates) do
        local p = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
        if #(me.xy - p.xy) < config.tug.crateReach then return true end
    end
    return false
end

-- jaring isi ikan di tangan -> peti berikutnya (progress 5 detik)
local function sortFish()
    if busy or not carry or carry.from ~= 'net' then return end
    busy = true
    local ok = lib.progressBar({
        duration = config.sortDuration,
        label = 'Memasukkan ikan ke peti...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = A.sort.dict, clip = A.sort.clip },
    })
    if ok then
        local res = lib.callback.await('f_nelayan:server:sort', false)
        if res and res.ok and not res.full then
            notify('Ikan masuk peti. Tebar jaring lagi.', 'success')
        elseif res and res.msg then
            notify(res.msg, 'error')
        end
    end
    busy = false
end

local function unloadCrates()
    if busy or carry then return end
    busy = true
    local ok = lib.progressBar({
        duration = 4000,
        label = 'Menurunkan peti ke dermaga...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = A.sort.dict, clip = A.sort.clip },
    })
    if ok then
        local res = lib.callback.await('f_nelayan:server:unload', false)
        if res and not res.ok and res.msg then notify(res.msg, 'error') end
    end
    busy = false
end

---------------------------------------------------------------------------
-- tug: naik / turun di dermaga (tanpa berenang), masukkan ikan, turunkan peti
---------------------------------------------------------------------------
local BOAT_OPTIONS = { 'fnl_board', 'fnl_leave', 'fnl_sort', 'fnl_unload' }
local boatTargetNet

-- pemain berdiri di atas tug (posisi relatif kapal, tinggi badan diabaikan)
local function onDeck(veh)
    local me = GetEntityCoords(cache.ped)
    local o = GetOffsetFromEntityGivenWorldCoords(veh, me.x, me.y, me.z)
    return math.abs(o.x) < 6.0 and o.y > -18.0 and o.y < 15.0 and o.z > -1.0 and o.z < 12.0
end

local function docked(veh)
    return #(GetEntityCoords(veh) - sharedConfig.dock) <= sharedConfig.dockRadius
end

local function moveTo(x, y, z, h)
    busy = true
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    SetEntityCoords(cache.ped, x, y, z, false, false, false, false)
    SetEntityHeading(cache.ped, h)
    Wait(300)
    DoScreenFadeIn(400)
    busy = false
end

local function removeBoatTarget()
    if not boatTargetNet then return end
    exports.ox_target:removeEntity(boatTargetNet, BOAT_OPTIONS)
    boatTargetNet = nil
end

local function registerBoatTarget()
    if not working() or not job.boatNet or boatTargetNet == job.boatNet then return end
    if not NetworkDoesNetworkIdExist(job.boatNet) then return end
    removeBoatTarget()
    boatTargetNet = job.boatNet
    exports.ox_target:addEntity(job.boatNet, {
        {
            name = 'fnl_board', label = 'Naik ke kapal', icon = 'fa-solid fa-ship', distance = 8.0,
            canInteract = function(entity)
                return not busy and not carry and not cache.vehicle and docked(entity) and not onDeck(entity)
            end,
            onSelect = function(data)
                local b = config.tug.board
                local p = GetOffsetFromEntityInWorldCoords(data.entity, b.x, b.y, b.z)
                moveTo(p.x, p.y, p.z, GetEntityHeading(data.entity) + b.w)
            end,
        },
        {
            name = 'fnl_leave', label = 'Turun ke dermaga', icon = 'fa-solid fa-person-walking-arrow-right', distance = 8.0,
            canInteract = function(entity)
                return not busy and not carry and not cache.vehicle and docked(entity) and onDeck(entity)
            end,
            onSelect = function()
                local p = sharedConfig.boardPoint
                moveTo(p.x, p.y, p.z, p.w)
            end,
        },
        {
            name = 'fnl_sort', label = 'Masukkan ikan ke peti', icon = 'fa-solid fa-fish', distance = 4.0,
            canInteract = function(entity)
                return carry and carry.from == 'net' and not busy and job.deckEmpty > 0 and nearCrates(entity)
            end,
            onSelect = sortFish,
        },
        {
            name = 'fnl_unload', label = 'Turunkan semua peti ke dermaga', icon = 'fa-solid fa-boxes-stacked', distance = 4.0,
            canInteract = function(entity)
                return job.deckFull > 0 and not carry and not busy and docked(entity) and nearCrates(entity)
            end,
            onSelect = unloadCrates,
        },
    })
end

---------------------------------------------------------------------------
-- bison milik pemain ini (muncul saat peti dibongkar)
---------------------------------------------------------------------------
local TRUCK_OPTIONS = { 'fnl_truck_load', 'fnl_truck_take' }

local function removeTruckTarget()
    if not truckTargetNet then return end
    exports.ox_target:removeEntity(truckTargetNet, TRUCK_OPTIONS)
    truckTargetNet = nil
end

local function registerTruckTarget()
    if not working() or not job.truckNet or truckTargetNet == job.truckNet then return end
    if not NetworkDoesNetworkIdExist(job.truckNet) then return end
    removeTruckTarget()
    truckTargetNet = job.truckNet
    exports.ox_target:addEntity(job.truckNet, {
        {
            name = 'fnl_truck_load', label = 'Muat peti ke bak', icon = 'fa-solid fa-truck-ramp-box', distance = 3.0,
            canInteract = function(entity)
                return carry and carry.from == 'pier' and not busy and nearOffset(entity, config.bison.rear, config.bison.rearRadius)
            end,
            onSelect = function()
                busy = true
                local res = lib.callback.await('f_nelayan:server:loadTruck', false)
                if res and res.ok and res.done then
                    notify('Bagianmu sudah dimuat semua. Antar ke Pasar Ikan, lokasi di waypoint.', 'success')
                elseif res and not res.ok and res.msg then
                    notify(res.msg, 'error')
                end
                busy = false
            end,
        },
        {
            name = 'fnl_truck_take', label = 'Ambil peti dari bak', icon = 'fa-solid fa-box', distance = 3.0,
            canInteract = function(entity)
                return working() and job.truck > 0 and not carry and not busy and nearOffset(entity, config.bison.rear, config.bison.rearRadius)
            end,
            onSelect = function() take('truck') end,
        },
    })
end

---------------------------------------------------------------------------
-- tebar & tarik jaring
---------------------------------------------------------------------------
local function castNet(veh)
    busy = true
    hidePrompt()
    if #(GetEntityVelocity(veh)) > 2.5 then
        notify('Pelankan kapal dulu.', 'error')
        busy = false
        return
    end
    local ped = cache.ped
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    lib.requestModel(M.netHand, 5000)
    local hand = CreateObject(M.netHand, 0.0, 0.0, 0.0, false, false, false)
    local a = config.handAttach
    AttachEntityToEntity(hand, ped, GetPedBoneIndex(ped, a.bone), a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(M.netHand)
    lib.playAnim(ped, A.throw.dict, A.throw.clip, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    Wait(A.throw.releaseMs)

    -- jaring lepas dari tangan, terbang melengkung ke titik di belakang buritan
    local from = GetEntityCoords(hand)
    DeleteEntity(hand)
    local o = config.tug.castOffset
    -- tiap anggota kru menebar sedikit bergeser ke samping supaya jaring tidak menumpuk
    local spread = ((job.me or 0) % 5 - 2) * 4.0
    local target = GetOffsetFromEntityInWorldCoords(veh, o.x + spread, o.y, o.z)
    local found, water = GetWaterHeight(target.x, target.y, 5.0)
    target = vec3(target.x, target.y, found and water or 0.0)
    lib.requestModel(M.netThrow, 5000)
    local fly = CreateObject(M.netThrow, from.x, from.y, from.z, false, false, false)
    SetModelAsNoLongerNeeded(M.netThrow)
    SetEntityCollision(fly, false, false)
    SetEntityHeading(fly, GetEntityHeading(veh))
    local start, dur = GetGameTimer(), 900
    while GetGameTimer() - start < dur do
        local t = (GetGameTimer() - start) / dur
        local p = from + (target - from) * t
        SetEntityCoordsNoOffset(fly, p.x, p.y, p.z + math.sin(t * math.pi) * 3.0, false, false, false)
        Wait(0)
    end
    DeleteEntity(fly)

    local res = lib.callback.await('f_nelayan:server:cast', false, target)
    if res and res.ok then
        notify('Jaring ditebar. Tunggu ikan masuk, jangan jauh-jauh dari jaring.', 'success')
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

---------------------------------------------------------------------------
-- tali dari tangan ke jaring di laut saat menarik (rope bawaan GTA, lokal)
---------------------------------------------------------------------------
local function ropeTextures()
    if RopeAreTexturesLoaded() then return true end
    RopeLoadTextures()
    local deadline = GetGameTimer() + 3000
    while not RopeAreTexturesLoaded() and GetGameTimer() < deadline do Wait(0) end
    return RopeAreTexturesLoaded()
end

local function handRope(obj)
    if not ropeTextures() then return end
    local hand = GetPedBoneCoords(cache.ped, 57005, 0.0, 0.0, 0.0)
    local np = GetEntityCoords(obj) + vec3(0.0, 0.0, 0.3)
    local len = #(hand - np) + 1.0
    -- (posisi, rotasi, panjang maks, tipe 4 = tali tipis, panjang awal, panjang min, laju ubah, ...)
    local rope = AddRope(hand.x, hand.y, hand.z, 0.0, 0.0, 0.0, len + 20.0, 4, len, 0.5, 0.5, false, false, false, 1.0, false)
    AttachEntitiesToRope(rope, cache.ped, obj, hand.x, hand.y, hand.z, np.x, np.y, np.z, len, false, false, nil, nil)
    return rope
end

-- jaring di laut ditarik mendekat ke buritan selama tarik-ulur; panjang tali ikut memendek (tidak pernah tegang)
local function reelIn(obj, rope, veh, untilFn)
    CreateThread(function()
        local from = GetEntityCoords(obj)
        local o = config.tug.castOffset
        local started = GetGameTimer()
        while untilFn() and DoesEntityExist(obj) do
            local t = math.min(1.0, (GetGameTimer() - started) / config.reelMs)
            local to = GetOffsetFromEntityInWorldCoords(veh, o.x * 0.3, o.y * 0.45, 0.0)
            local found, water = GetWaterHeight(to.x, to.y, 5.0)
            local p = from + (vec3(to.x, to.y, found and water - 0.05 or from.z) - from) * t
            SetEntityCoordsNoOffset(obj, p.x, p.y, p.z, false, false, false)
            if rope then
                local hand = GetPedBoneCoords(cache.ped, 57005, 0.0, 0.0, 0.0)
                RopeForceLength(rope, #(hand - p) + 1.0)
            end
            Wait(0)
        end
    end)
end

local pullPromise
RegisterNUICallback('pullDone', function(data, cb)
    cb(1)
    if pullPromise then pullPromise:resolve(tonumber(data.hits) or 0) end
end)

local function haulNet()
    busy = true
    hidePrompt()
    local res = lib.callback.await('f_nelayan:server:haulStart', false)
    if not res or not res.ok then
        if res and res.msg then notify(res.msg, 'error') end
        busy = false
        return
    end
    local started = GetGameTimer()
    lib.playAnim(cache.ped, A.pull.dict, A.pull.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    pullPromise = promise.new()
    local mine = pullPromise
    -- tali dari tangan ke jaring, jaring mendekat ke kapal selama tarik-ulur
    local veh = boat()
    local seaObj = veh and job.net and NLY.seaNetNear and NLY.seaNetNear(job.net.pos)
    local rope = seaObj and handRope(seaObj)
    local reeling = true
    if seaObj then reelIn(seaObj, rope, veh, function() return reeling end) end
    SetTimeout(20000, function()  -- NUI tidak menjawab: anggap gagal, jangan macet
        if pullPromise == mine then mine:resolve(0) end
    end)
    SendNUIMessage({ action = 'pull', data = config.pull })
    CreateThread(function()
        local p = pullPromise
        while p and pullPromise == p do
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 24, true)
            if IsDisabledControlJustPressed(0, 38) then SendNUIMessage({ action = 'pullHit' }) end
            Wait(0)
        end
    end)
    local hits = Citizen.Await(pullPromise)
    pullPromise = nil
    -- tarik minimal 5 detik (sama dengan server)
    local left = 5500 - (GetGameTimer() - started)
    if left > 0 then Wait(left) end
    StopAnimTask(cache.ped, A.pull.dict, A.pull.clip, 1.0)
    reeling = false
    if rope then DeleteRope(rope) end

    local done = lib.callback.await('f_nelayan:server:haul', false, hits)
    if done and done.ok and done.empty then
        notify(('Tarikan gagal (%s/3 tepat), ikannya lepas. Jaring tidak aus, tebar lagi.'):format(done.hits or 0), 'error')
    elseif done and done.ok then
        notify(('Dapat %s%s%s! Bawa ke tumpukan peti di dek.'):format(done.fish or 'ikan', done.rare and ' (LANGKA)' or '',
            done.perfect and ', tarikan sempurna +10%' or ''), done.rare and 'success' or 'inform')
        if done.broke then notify(('Jaringmu sudah dipakai %s kali dan rusak.'):format(sharedConfig.netUses), 'inform') end
    elseif done and done.msg then
        notify(done.msg, 'error')
    end
    busy = false
end

---------------------------------------------------------------------------
-- loop kerja
---------------------------------------------------------------------------
local function workLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        local nextRender, nextHud = 0, 0
        while working() do
            local wait = 1000
            local veh = boat()
            local now = GetGameTimer()
            if job.boatNet and boatTargetNet ~= job.boatNet then registerBoatTarget() end
            if job.truckNet and truckTargetNet ~= job.truckNet then registerTruckTarget() end
            if not job.truckNet and truckTargetNet then removeTruckTarget() end

            if now >= nextRender then
                nextRender = now + 1000
                renderPier()
                renderShoal()
                updateBlip()
            end
            -- HUD: tiap detik saat ada hitung mundur, selain itu tiap 2 detik (tips ikut posisi pemain)
            if now >= nextHud then
                nextHud = now + (((job.net and now < readyAt + 1000) or returnAt) and 1000 or 2000)
                updateHud()
            end

            -- tug kerja lebih cepat saat dikemudikan anggota kru (diulang tiap detik: hilang saat pemilik entitas berganti)
            if veh and cache.vehicle == veh and cache.seat == -1 then
                SetVehicleEnginePowerMultiplier(veh, config.tugBoost.power)
                ModifyVehicleTopSpeed(veh, config.tugBoost.topSpeed)
            end

            -- tug / bison hancur atau tenggelam (server hanya menerima dari anggota kru)
            local trk = truck()
            if not lostReported then
                if veh and IsEntityDead(veh) then
                    lostReported = true
                    lib.callback.await('f_nelayan:server:lost', false, 'boat')
                elseif trk and (IsEntityDead(trk) or (IsEntityInWater(trk) and GetEntitySubmergedLevel(trk) > 0.7)) then
                    lostReported = true
                    lib.callback.await('f_nelayan:server:lost', false, 'truck')
                    SetTimeout(5000, function() lostReported = false end)
                end
            end

            -- buritan tug: tebar / tarik jaring (tidak sambil menyetir)
            if veh and not cache.vehicle and not carry and not busy then
                local s = stage()
                local tc = config.tug
                -- posisi relatif kapal (x kanan, y depan, z atas); tinggi badan diabaikan, seluruh dek belakang dihitung
                local me = GetEntityCoords(cache.ped)
                local o = GetOffsetFromEntityGivenWorldCoords(veh, me.x, me.y, me.z)
                local deck = math.abs(o.x) < 6.0 and o.y > -18.0 and o.y < 15.0 and o.z > -1.0 and o.z < 12.0
                local atStern = deck and o.y <= tc.sternEdge and math.abs(o.x) < 5.0 and o.z < 4.5
                if deck and (s == 'cast' or s == 'haul' or s == 'soak') then
                    wait = 0
                    local m = GetOffsetFromEntityInWorldCoords(veh, tc.stern.x, tc.stern.y, tc.stern.z)
                    DrawMarker(1, m.x, m.y, m.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        tc.sternRadius * 2, tc.sternRadius * 2, 0.4, 61, 165, 222, 90, false, false, 2, false, nil, nil, false)
                    if not atStern then
                        showPrompt(s == 'soak' and 'Jaring direndam di belakang kapal' or 'Ke dek belakang kapal (lingkaran biru) untuk menebar / menarik jaring')
                    elseif s == 'cast' and job.nets <= 0 then
                        showPrompt('Kamu tidak punya jaring · beli di Syahbandar')
                    elseif s == 'cast' then
                        showPrompt(('[E] Tebar jaring · %s jaring di tas'):format(job.nets))
                        if IsControlJustPressed(0, 38) then castNet(veh) end
                    elseif s == 'haul' then
                        showPrompt('[E] Tarik jaring')
                        if IsControlJustPressed(0, 38) then haulNet() end
                    else
                        showPrompt(('Jaring direndam · %s detik lagi'):format(math.ceil((readyAt - now) / 1000)))
                    end
                else
                    hidePrompt()
                end
            elseif not carry and not busy then
                hidePrompt()    -- menyetir / jauh dari kapal: tulisan dek jangan tertinggal
            end
            Wait(wait)
        end
        loopRunning = false
    end)
end

---------------------------------------------------------------------------
-- state dari server
---------------------------------------------------------------------------
local function resetWork()
    stopCarry()
    clearPier()
    clearShoal()
    clearBlips()
    removeTruckTarget()
    removeBoatTarget()
    hidePrompt()
    lastBlip = nil
    busy, lostReported = false, false
end

local refreshMenu, closeMenu

-- panel Alur Kerja (f_panduan), opsional
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

local STEP = { soak = 3, haul = 3, sort = 3, ['return'] = 4, pier = 5, loadTruck = 5, market = 6, sell = 6, returnTruck = 6 }
AddEventHandler('f_panduan:client:requestStep', function(key)
    if key ~= 'nelayan' or not working() then return end
    local s = stage()
    local n = STEP[s]
    if not n then
        -- cast: belum naik kapal / masih menuju spot / sudah di spot
        local veh = boat()
        if not veh or cache.vehicle ~= veh then n = 1
        elseif #(GetEntityCoords(veh).xy - job.spot.coords.xy) > sharedConfig.spotRadius then n = 2
        else n = 3 end
    end
    panduan('SetStep', 'nelayan', n)
end)

RegisterNetEvent('f_nelayan:client:sync', function(data)
    local was = working()
    job = data
    if working() and not was then panduan('Start', 'nelayan')
    elseif not working() and was then panduan('Stop', 'nelayan') end
    readyAt = data.net and GetGameTimer() + data.net.readyIn * 1000 or 0
    returnAt = data.truckReturn and GetGameTimer() + data.truckReturn * 1000 or nil
    if working() then workLoop() end
    reconcileCarry()
    renderPier()
    updateBlip()
    updateHud()
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_nelayan:client:ended', function(reason)
    job = nil
    panduan('Stop', 'nelayan')
    resetWork()
    updateHud()
    if reason then notify(reason, 'inform') end
    if menuOpen then refreshMenu() end
end)

RegisterNetEvent('f_nelayan:client:invite', function(leaderName)
    local answer = lib.alertDialog({
        header = 'Ajakan Melaut',
        content = ('%s mengajakmu bergabung ke kru nelayan. Tangkapan dibagi rata ke semua anggota (8 peti per orang kalau penuh). Bawa jaringmu sendiri.'):format(leaderName),
        centered = true,
        cancel = true,
        labels = { confirm = 'Terima', cancel = 'Tolak' },
    })
    lib.callback.await('f_nelayan:server:respond', false, answer == 'confirm')
end)

RegisterNetEvent('f_nelayan:client:menuRefresh', function()
    if menuOpen then refreshMenu() end
end)

---------------------------------------------------------------------------
-- menu Syahbandar (NUI F-UI)
---------------------------------------------------------------------------
function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function refreshMenu()
    local data = lib.callback.await('f_nelayan:server:getMenu', false)
    if not data or data.err then return closeMenu() end
    SendNUIMessage({ action = 'update', data = data })
end

local function openMenu()
    if menuOpen then return end
    local data = lib.callback.await('f_nelayan:server:getMenu', false)
    if not data then return end
    if data.err then return notify(data.err, 'error') end
    menuOpen = true
    SendNUIMessage({ action = 'open', data = data })
    SetNuiFocus(true, true)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(lib.callback.await('f_nelayan:server:getMenu', false) or {})
end)

RegisterNUICallback('invite', function(data, cb)
    cb(lib.callback.await('f_nelayan:server:invite', false, data.id) or { ok = false })
end)

RegisterNUICallback('kick', function(data, cb)
    cb(lib.callback.await('f_nelayan:server:kick', false, data.id) or {})
end)

RegisterNUICallback('start', function(_, cb)
    local res = lib.callback.await('f_nelayan:server:start', false) or { ok = false }
    if res.ok then closeMenu() end
    cb(res)
end)

RegisterNUICallback('leave', function(_, cb)
    lib.callback.await('f_nelayan:server:leave', false)
    cb(lib.callback.await('f_nelayan:server:getMenu', false) or {})
end)

---------------------------------------------------------------------------
-- NPC Syahbandar & pedagang Pasar Ikan (lokal, hanya saat dekat)
---------------------------------------------------------------------------
local function spawnNpc(n, scenario, options)
    lib.requestModel(n.model, 5000)
    local c = n.coords
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    local ped = CreatePed(4, n.model, c.x, c.y, found and groundZ or c.z, c.w, false, true)
    SetModelAsNoLongerNeeded(n.model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, scenario, 0, true)
    exports.ox_target:addLocalEntity(ped, options)
    return ped
end

local function deletePed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    exports.ox_target:removeLocalEntity(ped)
    DeletePed(ped)
end

local officePed, marketPed

lib.points.new({
    coords = sharedConfig.office.coords.xyz,
    distance = 60.0,
    onEnter = function()
        officePed = spawnNpc(sharedConfig.office, 'WORLD_HUMAN_CLIPBOARD', {
            { name = 'fnl_menu', icon = 'fa-solid fa-fish', label = 'Kerja Nelayan', distance = 2.5, onSelect = openMenu },
            {
                name = 'fnl_buynet', icon = 'fa-solid fa-cart-shopping', distance = 2.5,
                label = ('Beli Jaring Ikan (%s)'):format(rupiah(sharedConfig.netPrice)),
                onSelect = function()
                    if busy then return end
                    busy = true
                    local res = lib.callback.await('f_nelayan:server:buyNet', false)
                    if res and res.ok then
                        notify(('Jaring Ikan dibeli. Rusak setelah %s kali tebar.'):format(sharedConfig.netUses), 'success')
                    elseif res and res.msg then
                        notify(res.msg, 'error')
                    end
                    busy = false
                end,
            },
        })
    end,
    onExit = function()
        deletePed(officePed)
        officePed = nil
    end,
})

local function sell()
    if busy or not carry then return end
    busy = true
    local res = lib.callback.await('f_nelayan:server:sell', false)
    if res and res.ok then
        notify(('Peti %s terjual %s, masuk ke rekening bank.'):format(res.fish or 'ikan', rupiah(res.worth)), 'success')
        if res.done then
            notify(('Bagianmu habis terjual! Kembali ke kapal, spot ikan berikutnya: %s.'):format(res.spot), 'inform')
        end
        if marketPed and DoesEntityExist(marketPed) then
            lib.playAnim(marketPed, 'mp_common', 'givetake1_b', 8.0, -8.0, 1500, 0, 0.0, false, false, false)
        end
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

lib.points.new({
    coords = sharedConfig.market.coords.xyz,
    distance = 60.0,
    onEnter = function()
        marketPed = spawnNpc(sharedConfig.market, 'WORLD_HUMAN_STAND_IMPATIENT', {
            {
                name = 'fnl_sell', icon = 'fa-solid fa-sack-dollar', label = 'Jual peti ikan', distance = 2.5,
                canInteract = function() return carry and carry.from == 'truck' and not busy end,
                onSelect = sell,
            },
        })
    end,
    onExit = function()
        deletePed(marketPed)
        marketPed = nil
    end,
})

---------------------------------------------------------------------------
-- kalibrasi
---------------------------------------------------------------------------
RegisterCommand('nelayanpos', function()
    local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    local text = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, c.z, h)
    lib.setClipboard(text)
    notify(('Disalin: %s'):format(text), 'success')
end, false)

-- offset posisimu relatif tug / bison terdekat (untuk config.client tug.* / bison.*)
RegisterCommand('nelayandek', function()
    local me = GetEntityCoords(cache.ped)
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local model = GetEntityModel(veh)
        if model == joaat(sharedConfig.boatModel) or model == joaat(sharedConfig.truckModel) then
            local d = #(GetEntityCoords(veh) - me)
            if d < 40.0 and (not bestDist or d < bestDist) then best, bestDist = veh, d end
        end
    end
    if not best then return notify('Tidak ada tug / bison di dekatmu.', 'error') end
    local o = GetOffsetFromEntityGivenWorldCoords(best, me.x, me.y, me.z - 0.95)
    local text = ('vec3(%.2f, %.2f, %.2f)'):format(o.x, o.y, o.z)
    lib.setClipboard(text)
    notify(('Offset kaki relatif %s disalin: %s'):format(GetEntityModel(best) == joaat(sharedConfig.boatModel) and 'tug' or 'bison', text), 'success')
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    resetWork()
    if menuOpen then SetNuiFocus(false, false) end
    deletePed(officePed)
    deletePed(marketPed)
end)
