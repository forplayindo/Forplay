-- Panel "Periksa Kendaraan" (client): opsi ox_target di kendaraan, NUI, dan progress perbaikan.
-- Semua keputusan ada di server (server/panel.lua); client hanya menampilkan & menjalankan animasi.
local cfg = require 'config.shared'
local clientCfg = require 'config.client'

local openNet ---@type number? netId kendaraan yang sedang dibuka
local busy = false
local tabletObj ---@type number?

---Tablet di tangan selama panel terbuka.
local function startTablet()
    if tabletObj and DoesEntityExist(tabletObj) then return end
    local t = clientCfg.tablet
    local ped = cache.ped
    lib.requestAnimDict(t.dict, 5000)
    lib.requestModel(t.prop, 5000)
    local pos = GetEntityCoords(ped)
    tabletObj = CreateObject(joaat(t.prop), pos.x, pos.y, pos.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(joaat(t.prop))
    local p = t.placement
    AttachEntityToEntity(tabletObj, ped, GetPedBoneIndex(ped, t.bone), p[1], p[2], p[3], p[4], p[5], p[6], true, true, false, true, 1, true)
    TaskPlayAnim(ped, t.dict, t.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    RemoveAnimDict(t.dict)
end

local function stopTablet()
    if tabletObj and DoesEntityExist(tabletObj) then DeleteEntity(tabletObj) end
    tabletObj = nil
    StopAnimTask(cache.ped, clientCfg.tablet.dict, clientCfg.tablet.clip, 1.0)
end

local function isMechanic()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == cfg.jobType and job.onduty
end

local function nuiConfig()
    return {
        parts = cfg.parts, groups = cfg.groups, liftParts = cfg.liftParts, fluids = cfg.fluids, tyre = cfg.tyre, tyres = cfg.tyres,
        levels = cfg.levels, levelLabels = cfg.levelLabels, needs = cfg.needs,
        itemLabels = cfg.itemLabels, itemIcons = cfg.itemIcons,
    }
end

local function closePanel()
    if not openNet then return end
    openNet = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTablet()
end

local function showPanel(status)
    SendNUIMessage({ action = 'open', status = status, config = nuiConfig() })
    SetNuiFocus(true, true)
    startTablet()
end

local function openPanel(netId)
    if openNet or busy then return end
    local res = lib.callback.await('f_mechanicjob:server:panelOpen', false, netId)
    if not res or res.error then
        return exports.qbx_core:Notify(res and res.error or 'Gagal membuka data kendaraan', 'error')
    end
    openNet = netId
    showPanel(res.status)

    -- segarkan data & tutup kalau mekanik menjauh
    CreateThread(function()
        while openNet == netId do
            Wait(2000)
            if openNet ~= netId then break end
            if not busy then
                local status = lib.callback.await('f_mechanicjob:server:panelStatus', false, netId)
                if openNet ~= netId then break end
                if not status then
                    exports.qbx_core:Notify('Kendaraan terlalu jauh', 'error')
                    closePanel()
                    break
                end
                SendNUIMessage({ action = 'update', status = status })
            end
        end
    end)
end

local function labelFor(action, key)
    if action == 'all' then return 'Memperbaiki semua...' end
    if action == 'tyres' then return 'Mengganti ban...' end
    if action == 'tyre' then return 'Mengganti ban...' end
    local def = cfg.parts[key]
    if not def then return 'Memperbaiki...' end
    return (def.fluid and 'Mengisi %s...' or 'Memperbaiki %s...'):format(def.label:lower())
end

---Kendaraan sedang di atas lift yang naik (status dari GlobalState, lihat client/lift.lua).
local function onRaisedLift(netId)
    for i = 1, #cfg.lift.lifts do
        local s = GlobalState['f_mech:lift:' .. i]
        if s and s.up and s.net == netId then return true end
    end
    return false
end

---Animasi & prop tangan untuk satu tindakan.
local function animFor(action, key, lifted)
    local isTyre = action == 'tyre' or action == 'tyres'
    local kind = isTyre and 'tyre' or (action == 'part' and clientCfg.animOf[key]) or 'under'
    if lifted and (isTyre or (action == 'part' and cfg.liftParts[key])) then kind = 'lift' end
    local prop = clientCfg.propOf[kind]
    return clientCfg.anims[kind] or clientCfg.anims.under, prop and clientCfg.props[prop]
end

---Prop yang muncul/hilang mengikuti posisi animasi (anim.props). Kembalikan fungsi stop.
local function startAnimProps(anim)
    local active, objs = true, {}
    local ped = cache.ped
    local function remove(i)
        if objs[i] and DoesEntityExist(objs[i]) then DeleteEntity(objs[i]) end
        objs[i] = nil
    end
    CreateThread(function()
        for _, p in ipairs(anim.props) do lib.requestModel(p.model, 5000) end
        local len = GetAnimDuration(anim.dict, anim.clip) * 1000
        while active do
            local t = -1
            if IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
                t = GetEntityAnimCurrentTime(ped, anim.dict, anim.clip) * len
            end
            for i, p in ipairs(anim.props) do
                local want = t >= p.at and (not p.life or t < p.at + p.life)
                if want and not objs[i] then
                    local obj = CreateObject(joaat(p.model), GetEntityCoords(ped), true, true, false)
                    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone), p.pos.x, p.pos.y, p.pos.z,
                        p.rot.x, p.rot.y, p.rot.z, true, true, false, true, 1, true)
                    objs[i] = obj
                elseif not want and objs[i] then
                    remove(i)
                end
            end
            Wait(50)
        end
        for i in pairs(objs) do remove(i) end
        for _, p in ipairs(anim.props) do SetModelAsNoLongerNeeded(joaat(p.model)) end
    end)
    return function() active = false end
end

local function progress(duration, label, anim, prop)
    local stopProps
    if anim and anim.dict and (anim.props or anim.fullCycle) then
        lib.requestAnimDict(anim.dict, 5000)
        if anim.fullCycle then
            duration = math.max(duration, math.ceil(GetAnimDuration(anim.dict, anim.clip) * 1000))
        end
        if anim.props then stopProps = startAnimProps(anim) end
    end
    local ok = lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = anim,
        prop = prop,
    })
    if stopProps then stopProps() end
    ClearPedTasks(cache.ped)
    return ok
end

local WHEEL_BONES = { [0] = 'wheel_lf', [1] = 'wheel_rf', [2] = 'wheel_lm1', [3] = 'wheel_rm1', [4] = 'wheel_lr', [5] = 'wheel_rr' }
local TYRE_ORDER = { FL = 1, FR = 2, RR = 3, RL = 4, F = 1, R = 2 } -- urutan keliling kendaraan

local function tyreLabel(key)
    for _, list in pairs(cfg.tyres) do
        for _, t in ipairs(list) do
            if t.key == key then return t.label end
        end
    end
    return 'Ban'
end

---Posisi dunia roda (index wheel GTA), atau nil kalau model tidak punya bone roda itu.
local function wheelPos(veh, index)
    local bone = GetEntityBoneIndexByName(veh, WHEEL_BONES[index] or '')
    if bone == -1 then return end
    return GetWorldPositionOfEntityBone(veh, bone)
end

---Urutkan ban keliling kendaraan, dimulai dari ban terdekat dengan mekanik.
local function orderTyres(veh, list)
    table.sort(list, function(a, b) return (TYRE_ORDER[a.key] or 9) < (TYRE_ORDER[b.key] or 9) end)
    local here = GetEntityCoords(cache.ped)
    local first, bestDist = 1, nil
    for i, t in ipairs(list) do
        local pos = wheelPos(veh, t.index)
        local d = pos and #(here - pos)
        if d and (not bestDist or d < bestDist) then first, bestDist = i, d end
    end
    local out = {}
    for i = 0, #list - 1 do out[#out + 1] = list[(first - 1 + i) % #list + 1] end
    return out
end

local ROUTE_MARGIN = 0.35 -- jarak aman dari bodi kendaraan saat memutar

---Apakah garis a->b (koordinat lokal kendaraan) memotong kotak r?
local function crossesBox(r, ax, ay, bx, by)
    local t0, t1 = 0.0, 1.0
    local dx, dy = bx - ax, by - ay
    for _, e in ipairs({ { -dx, ax - r.x0 }, { dx, r.x1 - ax }, { -dy, ay - r.y0 }, { dy, r.y1 - ay } }) do
        local p, q = e[1], e[2]
        if p == 0 then
            if q < 0 then return false end
        else
            local t = q / p
            if p < 0 then t0 = math.max(t0, t) else t1 = math.min(t1, t) end
            if t0 > t1 then return false end
        end
    end
    return true
end

---Titik-titik jalan (dunia) dari posisi mekanik ke `target` tanpa menembus kendaraan:
---kalau garis lurus memotong bodi, lewati sudut-sudut kendaraan dari arah yang lebih pendek.
local function routeAround(veh, target)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local r = { x0 = min.x - ROUTE_MARGIN, x1 = max.x + ROUTE_MARGIN, y0 = min.y - ROUTE_MARGIN, y1 = max.y + ROUTE_MARGIN }
    local here = GetEntityCoords(cache.ped)
    local a = GetOffsetFromEntityGivenWorldCoords(veh, here.x, here.y, here.z)
    local b = GetOffsetFromEntityGivenWorldCoords(veh, target.x, target.y, target.z)
    if not crossesBox(r, a.x, a.y, b.x, b.y) then return { target } end

    -- keliling kotak searah jarum jam mulai dari sudut depan kiri: A(x0,y1) B(x1,y1) C(x1,y0) D(x0,y0)
    local W, H = r.x1 - r.x0, r.y1 - r.y0
    local L = 2 * (W + H)
    local corners = { { r.x0, r.y1, 0 }, { r.x1, r.y1, W }, { r.x1, r.y0, W + H }, { r.x0, r.y0, 2 * W + H } }
    local function param(x, y)
        x, y = math.max(r.x0, math.min(r.x1, x)), math.max(r.y0, math.min(r.y1, y))
        local dTop, dRight, dBottom, dLeft = r.y1 - y, r.x1 - x, y - r.y0, x - r.x0
        local m = math.min(dTop, dRight, dBottom, dLeft)
        if m == dTop then return x - r.x0 end
        if m == dRight then return W + (r.y1 - y) end
        if m == dBottom then return W + H + (r.x1 - x) end
        return 2 * W + H + (y - r.y0)
    end
    local sA, sB = param(a.x, a.y), param(b.x, b.y)
    local cw = (sB - sA) % L
    local forward = cw <= L - cw

    local list = {}
    for _, c in ipairs(corners) do
        local d = forward and (c[3] - sA) % L or (sA - c[3]) % L
        if d > 0.01 and d < (forward and cw or L - cw) then list[#list + 1] = { d = d, x = c[1], y = c[2] } end
    end
    table.sort(list, function(p, q) return p.d < q.d end)

    local points = {}
    for _, c in ipairs(list) do points[#points + 1] = GetOffsetFromEntityInWorldCoords(veh, c.x, c.y, 0.0) end
    points[#points + 1] = target
    return points
end

---Berjalan ke `target` (memutari kendaraan bila perlu) lalu menghadap `face`.
---false kalau berhenti lebih jauh dari `maxDist` dari `face`.
local function walkTo(veh, target, face, timeoutMs, maxDist)
    local ped = cache.ped
    local timeout = GetGameTimer() + timeoutMs
    local points = routeAround(veh, target)
    for i, point in ipairs(points) do
        local last = i == #points
        TaskGoStraightToCoord(ped, point.x, point.y, GetEntityCoords(ped).z, 1.0, math.max(500, timeout - GetGameTimer()), GetEntityHeading(ped), 0.1)
        while GetGameTimer() < timeout do
            if #(GetEntityCoords(ped).xy - point.xy) < (last and 0.35 or 0.6) then break end
            Wait(100)
        end
        if GetGameTimer() >= timeout then break end
    end
    ClearPedTasks(ped)
    if #(GetEntityCoords(ped).xy - face.xy) > maxDist then return false end
    TaskTurnPedToFaceCoord(ped, face.x, face.y, face.z, 800)
    Wait(800)
    return true
end

---Berjalan ke samping roda lalu menghadap ke roda. false kalau tidak bisa mendekat.
local function goToTyre(veh, index)
    local wheel = wheelPos(veh, index)
    if not wheel then return true end
    local walk = clientCfg.tyreWalk
    local rel = GetOffsetFromEntityGivenWorldCoords(veh, wheel.x, wheel.y, wheel.z)
    local side = rel.x
    if math.abs(side) < 0.2 then -- motor: roda di tengah, pakai sisi tempat mekanik berdiri
        local here = GetEntityCoords(cache.ped)
        side = GetOffsetFromEntityGivenWorldCoords(veh, here.x, here.y, here.z).x
    end
    local target = GetOffsetFromEntityInWorldCoords(veh, rel.x + (side < 0 and -walk.distance or walk.distance), rel.y, rel.z)
    return walkTo(veh, target, wheel, walk.timeout, walk.distance + 0.8)
end

local HOOD = 4 -- door index kap mesin

---Berjalan ke depan kendaraan (menghadap kap). false kalau tidak bisa mendekat.
local function goToHood(veh)
    local walk = clientCfg.hoodWalk
    local _, max = GetModelDimensions(GetEntityModel(veh))
    local target = GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y + walk.distance, 0.0)
    local face = GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y - 1.0, 0.0)
    return walkTo(veh, target, face, walk.timeout, walk.distance + 1.8)
end

local DRIVER_DOOR = 0
local DOOR_BONES = { [DRIVER_DOOR] = 'door_dside_f', [HOOD] = 'bonnet' }

---Buka / tutup pintu (kap = 4). Pintu disinkron oleh pemegang fisika, jadi minta kontrol sebentar.
local function setDoor(veh, door, open)
    if GetEntityBoneIndexByName(veh, DOOR_BONES[door] or '') == -1 then return end
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do Wait(50) end
    end
    if open then SetVehicleDoorOpen(veh, door, false, false) else SetVehicleDoorShut(veh, door, false) end
end

local function setHood(veh, open) setDoor(veh, HOOD, open) end

---Berjalan ke sisi kendaraan ('front' / 'left' / 'rear' / 'right') sejauh `gap` dari bodi, menghadap bodi.
local function goToSide(veh, side, gap)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    local lx, ly, fx, fy = 0.0, max.y + gap, 0.0, max.y
    if side == 'rear' then lx, ly, fx, fy = 0.0, min.y - gap, 0.0, min.y
    elseif side == 'left' then lx, ly, fx, fy = min.x - gap, 0.0, min.x, 0.0
    elseif side == 'right' then lx, ly, fx, fy = max.x + gap, 0.0, max.x, 0.0 end
    local target = GetOffsetFromEntityInWorldCoords(veh, lx, ly, 0.0)
    local face = GetOffsetFromEntityInWorldCoords(veh, fx, fy, 0.0)
    return walkTo(veh, target, face, 10000, gap + 1.2)
end

---Berjalan ke pintu pengemudi (motor: sisi kiri).
local function goToDriverDoor(veh)
    local bone = GetEntityBoneIndexByName(veh, 'door_dside_f')
    if bone == -1 then return goToSide(veh, 'left', 0.8) end
    local door = GetWorldPositionOfEntityBone(veh, bone)
    local min = GetModelDimensions(GetEntityModel(veh))
    local rel = GetOffsetFromEntityGivenWorldCoords(veh, door.x, door.y, door.z)
    local target = GetOffsetFromEntityInWorldCoords(veh, min.x - 1.1, rel.y - 0.6, 0.0)
    local face = GetOffsetFromEntityInWorldCoords(veh, 0.0, rel.y - 0.6, 0.0)
    return walkTo(veh, target, face, 10000, 2.5)
end

---Kaleng semprot + kabut cat (terlihat pemain lain). Kembalikan handle untuk stopSpray.
local function startSpray()
    local S = clientCfg.spray
    local ped = cache.ped
    lib.requestModel(S.prop.model, 5000)
    local obj = CreateObject(joaat(S.prop.model), GetEntityCoords(ped), true, true, false)
    SetModelAsNoLongerNeeded(joaat(S.prop.model))
    local p, r = S.prop.pos, S.prop.rot
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, S.prop.bone), p.x, p.y, p.z, r.x, r.y, r.z, true, true, false, true, 1, true)

    local fx
    if pcall(lib.requestNamedPtfxAsset, S.fx.asset, 5000) then
        local o, fr = S.fx.offset, S.fx.rot
        UseParticleFxAssetNextCall(S.fx.asset)
        fx = StartNetworkedParticleFxLoopedOnEntity(S.fx.name, obj, o.x, o.y, o.z, fr.x, fr.y, fr.z, S.fx.scale, false, false, false)
        if fx and fx ~= 0 and S.fx.color then SetParticleFxLoopedColour(fx, S.fx.color[1], S.fx.color[2], S.fx.color[3], false) end
    end
    return obj, fx
end

local function stopSpray(obj, fx)
    if fx and fx ~= 0 then StopParticleFxLooped(fx, false) end
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    RemoveNamedPtfxAsset(clientCfg.spray.fx.asset)
end

local SIDE_LABEL = { front = 'bagian depan', left = 'sisi kiri', rear = 'bagian belakang', right = 'sisi kanan' }

---Tahap-tahap pemasangan kustom: { label, duration, go, anim?, prop?, door?, spray? }.
local function customSteps(veh, res)
    local T = cfg.customInstall
    local steps = {}
    if res.station == 'paint' then
        for i, side in ipairs({ 'front', 'left', 'rear', 'right' }) do
            steps[#steps + 1] = {
                label = ('Mengecat %s (%d/4)'):format(SIDE_LABEL[side], i), duration = T.paintSide, spray = true,
                go = function() return goToSide(veh, side, clientCfg.spray.distance) end,
            }
        end
        return steps
    end
    for _, g in ipairs(res.groups or {}) do
        if g == 'perf' then
            steps[#steps + 1] = { label = 'Memasang komponen mesin', duration = T.perf, door = HOOD,
                anim = clientCfg.anims.engine, prop = clientCfg.props.wrench, go = function() return goToHood(veh) end }
        elseif g == 'wheel' then
            local list = {}
            for _, t in ipairs(cfg.tyres[GetVehicleClass(veh) == 8 and 'bike' or 'car']) do list[#list + 1] = { key = t.key, index = t.index } end
            for _, t in ipairs(orderTyres(veh, list)) do
                local where = tyreLabel(t.key):gsub('^Ban ', '')
                steps[#steps + 1] = { label = 'Memasang velg ' .. where, duration = T.wheel,
                    anim = clientCfg.anims.tyre, go = function() return goToTyre(veh, t.index) end }
            end
        elseif g == 'interior' then
            steps[#steps + 1] = { label = 'Memasang interior', duration = T.interior, door = DRIVER_DOOR,
                anim = clientCfg.anims.interior, prop = clientCfg.props.tool, go = function() return goToDriverDoor(veh) end }
        else
            steps[#steps + 1] = { label = 'Memasang bodi', duration = T.body,
                anim = clientCfg.anims.body, go = function() return goToSide(veh, 'left', 0.8) end }
        end
    end
    return steps
end

local function runAction(action, key)
    local netId = openNet
    if not netId or busy then return end
    busy = true

    local res = lib.callback.await('f_mechanicjob:server:actionStart', false, netId, action, key)
    if not res or res.error then
        busy = false
        return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error')
    end

    -- panel & tablet disembunyikan selama animasi supaya progress bar & animasi memperbaiki terlihat
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    stopTablet()

    local veh = NetworkGetEntityFromNetworkId(netId)
    local lifted = onRaisedLift(netId)
    local tyres = veh ~= 0 and res.tyres or {}
    local tyreTime = #tyres > 0 and (res.tyreDuration or 0) or 0
    local partTime = res.duration - tyreTime
    if #tyres > 0 and partTime < 500 then tyreTime, partTime = res.duration, 0 end
    local ok = true

    -- bagian kendaraan (Perbaiki Semua: semua bagian sekaligus). Ruang mesin: di depan kendaraan, kap dibuka.
    if partTime > 0 then
        local hood = res.hood and veh ~= 0
        if hood then
            if not goToHood(veh) then
                ok = false
                exports.qbx_core:Notify('Tidak bisa ke depan kendaraan', 'error')
            else
                setHood(veh, true)
            end
        elseif veh ~= 0 then
            TaskTurnPedToFaceEntity(cache.ped, veh, 800) Wait(600)
        end
        if ok then
            local anim, prop = animFor(action, key, lifted)
            if hood and action == 'all' then anim, prop = clientCfg.anims.engine, clientCfg.props.wrench end
            ok = progress(partTime, labelFor(action, key), anim, prop)
        end
        if hood and DoesEntityExist(veh) then setHood(veh, false) end
    end

    -- ban: datangi tiap roda yang diganti
    if ok and #tyres > 0 then
        local each = math.ceil(tyreTime / #tyres)
        local anim, prop = animFor('tyre', nil, lifted)
        tyres = orderTyres(veh, tyres)
        for i, t in ipairs(tyres) do
            if not DoesEntityExist(veh) or not goToTyre(veh, t.index) then
                ok = false
                exports.qbx_core:Notify('Tidak bisa mendekati ' .. tyreLabel(t.key):lower(), 'error')
                break
            end
            local label = ('Mengganti %s'):format(tyreLabel(t.key):lower())
            if #tyres > 1 then label = ('%s (%d/%d)'):format(label, i, #tyres) end
            ok = progress(each, label .. '...', anim, prop)
            if not ok then break end
        end
    end

    if not ok then
        lib.callback.await('f_mechanicjob:server:actionCancel', false)
        busy = false
        exports.qbx_core:Notify('Perbaikan dibatalkan', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    local done = lib.callback.await('f_mechanicjob:server:actionFinish', false)
    busy = false
    if not done or done.error then
        exports.qbx_core:Notify(done and done.error or 'Gagal', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    exports.qbx_core:Notify('Perbaikan selesai', 'success')
    if openNet == netId then showPanel(done.status) end
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closePanel()
end)

RegisterNUICallback('action', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    CreateThread(function() runAction(data.action, data.key) end)
end)

-- Tab Tagihan: jawaban server langsung dikembalikan ke halaman
RegisterNUICallback('billingGet', function(_, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingGet', false, openNet) or { error = 'Gagal' })
end)

RegisterNUICallback('billingAdd', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingAdd', false, openNet, type(data) == 'table' and data.code or nil) or { error = 'Gagal' })
end)

RegisterNUICallback('billingSend', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    data = type(data) == 'table' and data or {}
    local res = lib.callback.await('f_mechanicjob:server:billingSend', false, openNet, data.target, data.lines or {}, data.channel)
    if res and res.sent then
        exports.qbx_core:Notify(res.channel == 'kasir' and ('Tagihan Rp %d masuk kasir atas nama %s'):format(res.sent, res.to or 'pelanggan')
            or ('Tagihan Rp %d dikirim ke HP %s'):format(res.sent, res.to or 'pelanggan'), 'success')
    end
    cb(res or { error = 'Gagal' })
end)

-- Tab Kustom: order kustom yang sudah lunas untuk kendaraan ini
RegisterNUICallback('customGet', function(_, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:customGet', false, openNet) or { error = 'Gagal' })
end)

local function runCustom(billId)
    local netId = openNet
    if not netId or busy then return end
    busy = true

    local res = lib.callback.await('f_mechanicjob:server:customStart', false, netId, billId)
    if not res or res.error then
        busy = false
        SendNUIMessage({ action = 'custom', data = { error = res and res.error or 'Gagal' } })
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    stopTablet()

    local veh = NetworkGetEntityFromNetworkId(netId)
    local ok = veh ~= 0 and DoesEntityExist(veh)
    local steps = ok and customSteps(veh, res) or {}

    -- total waktu tahap disesuaikan dengan durasi dari server
    local sum = 0
    for _, s in ipairs(steps) do sum += s.duration end
    local scale = sum > 0 and res.duration / sum or 1

    for _, s in ipairs(steps) do
        if not DoesEntityExist(veh) or not s.go() then
            ok = false
            exports.qbx_core:Notify('Tidak bisa mendekati kendaraan', 'error')
            break
        end
        if s.door then setDoor(veh, s.door, true) end
        local obj, fx
        if s.spray then obj, fx = startSpray() end
        ok = progress(math.ceil(s.duration * scale), s.label .. '...', s.spray and clientCfg.spray.anim or s.anim, s.prop)
        if s.spray then stopSpray(obj, fx) end
        if s.door and DoesEntityExist(veh) then setDoor(veh, s.door, false) end
        if not ok then break end
    end

    if not ok then
        lib.callback.await('f_mechanicjob:server:customCancel', false)
        busy = false
        exports.qbx_core:Notify('Pemasangan dibatalkan, modifikasi tidak dipasang', 'error')
        if openNet == netId then showPanel(nil) end
        return
    end

    local done = lib.callback.await('f_mechanicjob:server:customFinish', false)
    busy = false
    if done and not done.error then exports.qbx_core:Notify(done.msg or 'Modifikasi terpasang', 'success')
    else exports.qbx_core:Notify(done and done.error or 'Gagal', 'error') end
    if openNet == netId then
        showPanel(nil)
        SendNUIMessage({ action = 'custom', data = done or { error = 'Gagal' } })
    end
end

RegisterNUICallback('customInstall', function(data, cb)
    cb(1)
    if type(data) ~= 'table' then return end
    CreateThread(function() runCustom(tonumber(data.id)) end)
end)

RegisterNUICallback('billingDiscard', function(data, cb)
    if not openNet then return cb({ error = 'Panel tidak terbuka' }) end
    cb(lib.callback.await('f_mechanicjob:server:billingDiscard', false, openNet, type(data) == 'table' and data.id or nil) or { error = 'Gagal' })
end)

---Server meminta nilai mesin / body / tangki / ban bocor dari client pemegang fisika kendaraan
---(nilai di server sering tidak ter-update). MechNativeSnapshot ada di client/wear.lua.
lib.callback.register('f_mechanicjob:client:nativeSnap', function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    return MechNativeSnapshot(veh)
end)

---Kendaraan dari netId yang fisikanya kita pegang (minta kontrol sebentar), atau nil.
local function controlled(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if not NetworkHasControlOfEntity(veh) then
        NetworkRequestControlOfEntity(veh)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < timeout do Wait(50) end
        if not NetworkHasControlOfEntity(veh) then return end -- pemegang fisika yang menerapkan
    end
    return veh
end

---Command admin (/setkondisi, /rusakkan, /kondisipenuh): nilai bawaan GTA dalam persen.
RegisterNetEvent('f_mechanicjob:client:setNative', function(netId, v)
    if type(v) ~= 'table' then return end
    local veh = controlled(netId)
    if not veh then return end
    if v.fixAll then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
    end
    if v.engine then SetVehicleEngineHealth(veh, v.engine * 10.0) end
    if v.body then SetVehicleBodyHealth(veh, v.body * 10.0) end
    if v.tank then SetVehiclePetrolTankHealth(veh, v.tank * 10.0) end
    for _, idx in ipairs(v.burst or {}) do SetVehicleTyreBurst(veh, idx, false, 1000.0) end
end)

---Perbaikan bagian bawaan GTA. Dikirim server ke client pemegang fisika kendaraan (dan mekaniknya).
RegisterNetEvent('f_mechanicjob:client:applyNative', function(netId, native)
    if type(native) ~= 'table' then return end
    local veh = controlled(netId)
    if not veh then return end

    local fixed = {}
    for _, idx in ipairs(native.tyres or {}) do fixed[idx] = true end

    if native.body then
        -- SetVehicleFixed memulihkan semuanya (termasuk memasang roda yang lepas); kembalikan bagian
        -- yang tidak sedang diperbaiki
        local engine, tank = GetVehicleEngineHealth(veh), GetVehiclePetrolTankHealth(veh)
        local fuel, dirt = GetVehicleFuelLevel(veh), GetVehicleDirtLevel(veh)
        local burst = {}
        for idx = 0, 7 do
            if IsVehicleTyreBurst(veh, idx, false) and not fixed[idx] then burst[#burst + 1] = idx end
        end
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        if not native.engine then SetVehicleEngineHealth(veh, engine) end
        if not native.tank then SetVehiclePetrolTankHealth(veh, tank) end
        for i = 1, #burst do SetVehicleTyreBurst(veh, burst[i], false, 1000.0) end
        SetVehicleFuelLevel(veh, fuel)
        SetVehicleDirtLevel(veh, dirt)
    end
    if native.engine then
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleUndriveable(veh, false)
    end
    if native.tank then SetVehiclePetrolTankHealth(veh, 1000.0) end
    for idx in pairs(fixed) do SetVehicleTyreFixed(veh, idx) end
end)

exports.ox_target:addGlobalVehicle({
    {
        name = 'f_mechanicjob:inspect',
        icon = 'fa-solid fa-screwdriver-wrench',
        label = 'Periksa Kendaraan',
        distance = cfg.distance,
        canInteract = function(entity)
            if not isMechanic() or openNet or busy then return false end
            local class = GetVehicleClass(entity)
            return class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 and class ~= 21
        end,
        onSelect = function(data)
            openPanel(NetworkGetNetworkIdFromEntity(data.entity))
        end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if openNet then SetNuiFocus(false, false) end
    if tabletObj and DoesEntityExist(tabletObj) then DeleteEntity(tabletObj) end
end)
