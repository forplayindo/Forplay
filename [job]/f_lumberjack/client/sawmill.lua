-- sawmill: batang dari bak lewat conveyor satu per satu (seperti 17mov) + tumpukan papan tetap di ujung conveyor
-- (ox_target pindahkan papan ke truk). Jumlah papan dihitung server, ini hanya tampilan.
local config, sharedConfig = FLJ.config, FLJ.shared
local notify = FLJ.notify
local path = config.conveyor

local active = {}       -- batang yang sedang berjalan: { obj, start, seg }
local running = false

-- panjang tiap segmen supaya kecepatan batang rata di sepanjang jalur
local segLen, total = {}, 0.0
for i = 1, #path - 1 do
    segLen[i] = #(path[i + 1].pos - path[i].pos)
    total += segLen[i]
end

local function ptfxAt(pos)
    lib.requestNamedPtfxAsset('scr_reconstructionaccident', 500)
    UseParticleFxAssetNextCall('scr_reconstructionaccident')
    StartParticleFxNonLoopedAtCoord('scr_reconstruct_pipefall_debris', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
end

local function animate()
    if running then return end
    running = true
    CreateThread(function()
        while next(active) do
            local now = GetGameTimer()
            for key, log in pairs(active) do
                local dist = math.min((now - log.start) / sharedConfig.conveyorMs, 1.0) * total
                local i = 1
                while i < #path - 1 and dist > segLen[i] do
                    dist -= segLen[i]
                    i += 1
                end
                if i ~= log.seg then
                    log.seg = i
                    if path[i].ptfx then ptfxAt(path[i].pos) end
                end
                local t = math.min(dist / segLen[i], 1.0)
                local a, b = path[i], path[i + 1]
                local pos = a.pos + (b.pos - a.pos) * t
                local rot = a.rot + (b.rot - a.rot) * t
                SetEntityCoords(log.obj, pos.x, pos.y, pos.z, false, false, false, false)
                SetEntityRotation(log.obj, rot.x, rot.y, rot.z, 2, true)
                if now - log.start >= sharedConfig.conveyorMs then
                    if path[#path].ptfx then ptfxAt(path[#path].pos) end
                    DeleteEntity(log.obj)
                    active[key] = nil
                end
            end
            Wait(0)
        end
        running = false
    end)
end

local function spawnConveyorLog(kind)
    local m = FLJ.models[kind] or FLJ.models.piece
    lib.requestModel(m, 5000)
    local p = path[1].pos
    local o = CreateObject(m, p.x, p.y, p.z, false, false, false)
    SetModelAsNoLongerNeeded(m)
    SetEntityCollision(o, false, false)
    FreezeEntityPosition(o, true)
    active[o] = { obj = o, start = GetGameTimer(), seg = 0 }
    FLJ.playSound('logroll', p)
    animate()
end

-- seq: daftar 'piece' / 'trunk' sesuai urutan bongkar di server, tiap step ms satu batang
RegisterNetEvent('f_lumberjack:client:sawmill', function(seq, step)
    if #(GetEntityCoords(cache.ped) - config.sawmillCenter) > 150.0 then return end
    CreateThread(function()
        for _, kind in ipairs(seq) do
            spawnConveyorLog(kind)
            Wait(step)
        end
    end)
end)

---------------------------------------------------------------------------
-- tumpukan papan sawmill: prop tetap untuk semua pemain, ox_target memindahkan papan hasil olahan kru ke truk
---------------------------------------------------------------------------
local out = sharedConfig.plankOutput
local pile

local function movePlanks()
    if FLJ.busySawing() or FLJ.carrying() then return end
    local crew = FLJ.crew
    if crew.output <= 0 then
        return notify(crew.unloading and 'Kayumu masih diolah, tunggu sebentar.' or 'Tidak ada kayu yang diolah.', 'error')
    end
    local ok = lib.progressBar({
        duration = 2500, label = 'Memindahkan papan ke truk...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    })
    if not ok then return end
    local res = lib.callback.await('f_lumberjack:server:movePlanks', false)
    if res and res.ok then
        notify('Papan sudah di truk. Bawa ke markas Mandor Paleto lalu bongkar.', 'success')
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
end

local function hidePile()
    if not pile then return end
    exports.ox_target:removeLocalEntity(pile)
    if DoesEntityExist(pile) then DeleteEntity(pile) end
    pile = nil
end

local function showPile()
    if pile then return end
    local m = config.truck.plankModel
    local a = FLJ.modelAxis(m)
    lib.requestModel(m, 5000)
    pile = CreateObject(m, out.coords.x, out.coords.y, out.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(m)
    SetEntityHeading(pile, out.heading + a.yaw)
    PlaceObjectOnGroundProperly(pile)
    FreezeEntityPosition(pile, true)
    exports.ox_target:addLocalEntity(pile, {
        {
            name = 'flj_planks', icon = 'fas fa-truck-ramp-box', label = 'Pindahkan papan ke truk', distance = 3.0,
            canInteract = function() return FLJ.working() end,
            onSelect = movePlanks,
        },
    })
end

lib.points.new({
    coords = out.coords,
    distance = config.pileDistance,
    onEnter = showPile,
    onExit = hidePile,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for key, log in pairs(active) do
        if DoesEntityExist(log.obj) then DeleteEntity(log.obj) end
        active[key] = nil
    end
    hidePile()
end)
