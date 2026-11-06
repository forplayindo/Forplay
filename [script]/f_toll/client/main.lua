local config = require 'config.shared'
local barrier = require 'client.barrier'
local display = require 'client.display'
local editor = require 'client.editor'
local route = require 'shared.route'

local B = config.barrier

local gateLanes = {} -- gate -> { lane, ... }
local states = {}    -- id -> 'closed' | 'open' | 'broken'
local spawned = {}   -- id -> set palang
local npcOpen = {}   -- id -> GetGameTimer() batas buka lokal untuk mobil NPC
local lokets = {}

local textShown
local function showText(text)
    if textShown == text then return end
    textShown = text
    lib.showTextUI(text)
end
local function hideText()
    if not textShown then return end
    textShown = nil
    lib.hideTextUI()
end

local function headingDiff(a, b)
    return math.abs(((a - b + 180.0) % 360.0) - 180.0)
end

---------------------------------------------------------------------------
-- Palang
---------------------------------------------------------------------------

local function setLight(set, green)
    if not config.trafficLights then return end
    if not set.light or not DoesEntityExist(set.light) then
        local p = set.pos
        set.light = GetClosestObjectOfType(p.x, p.y, p.z, 10.0, config.trafficLightModel, false, false, false)
        if set.light == 0 then set.light = nil return end
    end
    SetEntityTrafficlightOverride(set.light, green and 0 or 1)
end

local function isOpen(id)
    return states[id] == 'open' or (npcOpen[id] or 0) > GetGameTimer()
end

local function refresh(id)
    local set = spawned[id]
    if not set then return end
    if states[id] == 'broken' then
        if not set.broken then
            set.broken = true
            barrier.breakArm(set)
        end
        setLight(set, false)
        return
    end
    if set.broken then
        set.broken = false
        barrier.restoreArm(set)
    end
    if isOpen(id) then
        barrier.removeBlockers(set)
        barrier.animate(set, B.openAngle)
        setLight(set, true)
    else
        barrier.animate(set, 0.0)
        set.needBlockers = true
        setLight(set, false)
    end
end

local function spawnLane(l)
    local b = l.barrier
    local set = barrier.create(vec3(b.x, b.y, b.z), b.w)
    spawned[l.id] = set
    set.needBlockers = true
    refresh(l.id)
end

local function despawnLane(id)
    local set = spawned[id]
    if not set then return end
    if set.light and DoesEntityExist(set.light) then SetEntityTrafficlightOverride(set.light, -1) end
    barrier.delete(set)
    spawned[id] = nil
end

local function despawnAll()
    for id in pairs(spawned) do despawnLane(id) end
end

---------------------------------------------------------------------------
-- Loket NPC & minimarket
---------------------------------------------------------------------------

local points = {}
local menuOpen = false

local function openLoket()
    local data = lib.callback.await('f_toll:server:loket', false)
    if not data then return end
    hideText()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'loket', data = data })
end

local function loketPoint(coords, distance, ped)
    local point = lib.points.new({
        coords = coords,
        distance = ped and 40.0 or distance + 3.0,
        onEnter = function(self)
            if not ped then return end
            local m = lib.requestModel(config.loket.ped)
            self.ped = CreatePed(4, m, coords.x, coords.y, coords.z - 1.0, ped, false, false)
            SetModelAsNoLongerNeeded(m)
            FreezeEntityPosition(self.ped, true)
            SetEntityInvincible(self.ped, true)
            SetBlockingOfNonTemporaryEvents(self.ped, true)
            TaskStartScenarioInPlace(self.ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        end,
        onExit = function(self)
            if self.ped and DoesEntityExist(self.ped) then DeleteEntity(self.ped) end
            self.ped = nil
            hideText()
        end,
        nearby = function(self)
            if menuOpen or cache.vehicle or self.currentDistance > distance then
                if textShown == '[E] Loket E-Toll' then hideText() end
                return
            end
            showText('[E] Loket E-Toll')
            if IsControlJustReleased(0, 38) then openLoket() end
        end,
    })
    points[#points + 1] = point
end

local function buildPoints()
    for _, p in ipairs(points) do
        if p.ped and DoesEntityExist(p.ped) then DeleteEntity(p.ped) end
        p:remove()
    end
    points = {}
    for _, k in ipairs(lokets) do
        loketPoint(vec3(k.x, k.y, k.z), config.loket.distance, k.w)
    end
    for _, c in ipairs(config.minimarkets) do
        loketPoint(c, config.minimarketDistance)
    end
end

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    editor.closed()
    SetNuiFocus(false, false)
    cb(1)
end)

RegisterNUICallback('buyCard', function(body, cb)
    cb(lib.callback.await('f_toll:server:buyCard', false, body.method) or { ok = false })
end)

RegisterNUICallback('topup', function(body, cb)
    cb(lib.callback.await('f_toll:server:topup', false, body.serial, body.amount, body.method) or { ok = false })
end)

---------------------------------------------------------------------------
-- Data dari server
---------------------------------------------------------------------------

local function setData(list, lokList, stateMap)
    despawnAll()
    gateLanes = {}
    for _, l in ipairs(list or {}) do
        if config.gates[l.gate] then
            l.fwd = route.forward(l.tap.w)
            l.tapPos = vec3(l.tap.x, l.tap.y, l.tap.z)

            gateLanes[l.gate] = gateLanes[l.gate] or {}
            gateLanes[l.gate][#gateLanes[l.gate] + 1] = l
        end
    end
    states = stateMap or {}
    lokets = lokList or {}
    buildPoints()
    editor.setData(list or {}, lokets)
end

RegisterNetEvent('f_toll:client:data', function(list, lokList, stateMap)
    if GetInvokingResource() then return end
    setData(list, lokList, stateMap)
end)

RegisterNetEvent('f_toll:client:state', function(id, state)
    if GetInvokingResource() then return end
    states[id] = state
    refresh(id)
end)

CreateThread(function()
    local d = lib.callback.await('f_toll:server:init', false)
    if d then setData(d.lanes, d.lokets, d.states) end
end)

---------------------------------------------------------------------------
-- Muat / hapus palang sesuai jarak (tiap detik)
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local pos = GetEntityCoords(cache.ped)
        for gateId, gate in pairs(config.gates) do
            local near = #(pos - gate.coords) < B.spawnDistance
            for _, l in ipairs(gateLanes[gateId] or {}) do
                if near and not spawned[l.id] then
                    spawnLane(l)
                elseif not near and spawned[l.id] then
                    despawnLane(l.id)
                end
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------------
-- Dekat gerbang: penahan, mobil NPC, tap kartu, tabrakan
---------------------------------------------------------------------------

local tapping = false
local hitUntil = 0
local speeds = {} -- { t, kmh } 400 ms terakhir (kecepatan sebelum tabrakan)
local nextNpc = 0
local promptLane

local function pushSpeed(now, kmh)
    speeds[#speeds + 1] = { now, kmh }
    while speeds[1] and now - speeds[1][1] > 400 do table.remove(speeds, 1) end
end

local function peakSpeed()
    local peak = 0
    for _, s in ipairs(speeds) do
        if s[2] > peak then peak = s[2] end
    end
    return peak
end

-- panel ikut mobil: di depan kaca, sedikit ke sisi pengemudi, terlihat dari kamera mana pun
local function hologramAt(veh)
    local _, mx = GetModelDimensions(GetEntityModel(veh))
    return { entity = veh, offset = vec3(-0.35, mx.y + 0.6, mx.z + 0.25) }
end

local function doTap(l, veh)
    tapping = true
    hideText()
    CreateThread(function()
        local res = lib.callback.await('f_toll:server:tap', false, l.id) or { ok = false }
        local at = hologramAt(veh)
        if res.ok and res.mode == 'entry' then
            display.show(at, { status = 'MASUK', state = 'done', gate = res.gate, note = 'Selamat jalan',
                rows = { { label = 'SALDO', value = res.balance, kind = 'money' } } }, config.hologram.duration)
        elseif res.ok and (res.mode == 'exit' or res.mode == 'pass') then
            local note = ('%s  >  %s'):format(res.from, res.gate)
            if res.total and res.total ~= res.fare then
                note = ('%s  ·  total %s'):format(note, 'Rp ' .. lib.math.groupdigits(res.total, '.'))
            end
            display.show(at, { status = res.mode == 'exit' and 'KELUAR' or 'LEWAT', state = 'done', gate = res.gate, note = note,
                rows = { { label = 'TARIF', value = res.fare, kind = 'minus' }, { label = 'SISA SALDO', value = res.balance, kind = 'money' } } },
                config.hologram.duration)
        elseif res.code == 'saldo' then
            local rows = { { label = 'SALDO', value = res.balance, kind = 'money' } }
            if res.fare then table.insert(rows, 1, { label = 'TARIF', value = res.fare, kind = 'minus' }) end
            display.show(at, { status = 'SALDO KURANG', state = 'warn', gate = res.gate, note = 'Isi ulang di loket tol / minimarket', rows = rows },
                config.hologram.duration)
            lib.notify({ description = res.msg, type = 'error' })
        elseif res.msg then
            lib.notify({ description = res.msg, type = 'error' })
        end
        Wait(1000)
        tapping = false
    end)
end

CreateThread(function()
    while true do
        local sleep = 500
        local ped = cache.ped
        local pos = GetEntityCoords(ped)
        local gateId
        for id, gate in pairs(config.gates) do
            if gateLanes[id] and #(pos - gate.coords) < 60.0 then gateId = id break end
        end

        local prompt
        if gateId then
            sleep = 250
            local now = GetGameTimer()
            local veh = cache.vehicle
            local driving = veh and GetPedInVehicleSeat(veh, -1) == ped
            if driving then
                sleep = 0
                pushSpeed(now, GetEntitySpeed(veh) * 3.6)
            end

            local npcCheck = now >= nextNpc
            if npcCheck then nextNpc = now + 250 end

            for _, l in ipairs(gateLanes[gateId]) do
                local set = spawned[l.id]
                if set then
                    -- mobil NPC: palang buka sendiri (lokal) supaya lalu lintas tidak macet
                    if npcCheck and states[l.id] == 'closed' then
                        for _, v in ipairs(lib.getNearbyVehicles(l.tapPos, 6.0, false)) do
                            local driver = GetPedInVehicleSeat(v.vehicle, -1)
                            if driver ~= 0 and not IsPedAPlayer(driver) then
                                local wasOpen = isOpen(l.id)
                                npcOpen[l.id] = now + B.npcOpenTime
                                if not wasOpen then refresh(l.id) end
                                break
                            end
                        end
                        if npcOpen[l.id] and npcOpen[l.id] <= now then
                            npcOpen[l.id] = nil
                            refresh(l.id)
                        end
                    end

                    -- penahan muncul setelah lengan turun penuh & tidak ada kendaraan di bawahnya
                    if set.needBlockers and not set.broken and not isOpen(l.id) and set.angle == 0.0 and not set.animating then
                        if npcCheck and not barrier.blocked(set) then
                            barrier.addBlockers(set)
                            set.needBlockers = false
                        end
                    end

                    if driving then
                        -- tabrakan palang tertutup
                        if states[l.id] == 'closed' and not isOpen(l.id) and set.angle == 0.0 and not set.animating
                            and now >= hitUntil and barrier.touching(set, veh) then
                            hitUntil = now + 2000
                            TriggerServerEvent('f_toll:server:hit', l.id, peakSpeed())
                        end

                        -- tap kartu di samping bilik
                        if not prompt and #(GetEntityCoords(veh) - l.tapPos) <= config.tap.distance then
                            local diff = headingDiff(GetEntityHeading(veh), l.tap.w)
                            if diff <= config.tap.maxAngle and states[l.id] ~= 'open' then
                                prompt = l
                            elseif diff >= 180.0 - config.tap.maxAngle then
                                prompt = 'wrong'
                            end
                        end
                    end
                end
            end

            if driving and prompt then
                if prompt == 'wrong' then
                    showText('Salah lajur - gunakan lajur dengan tanda hijau')
                elseif not tapping then
                    showText('[E] Tap Kartu E-Toll')
                    DisableControlAction(0, 86, true) -- klakson
                    if IsDisabledControlJustReleased(0, 86) or IsControlJustReleased(0, 38) then doTap(prompt, veh) end
                end
            end
            if not driving and #speeds > 0 then speeds = {} end
        end

        if not prompt and promptLane then
            if textShown == '[E] Tap Kartu E-Toll' or textShown == 'Salah lajur - gunakan lajur dengan tanda hijau' then hideText() end
        end
        promptLane = prompt
        Wait(sleep)
    end
end)

---------------------------------------------------------------------------
-- Dispatch: blip untuk polisi
---------------------------------------------------------------------------

RegisterNetEvent('f_toll:client:dispatchBlip', function(coords, label)
    if GetInvokingResource() then return end
    local cfg = config.dispatch.blip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite)
    SetBlipColour(blip, cfg.color)
    SetBlipScale(blip, cfg.scale)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Pelanggaran Tol: ' .. label)
    EndTextCommandSetBlipName(blip)
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    SetTimeout(cfg.duration * 1000, function() RemoveBlip(blip) end)
end)

---------------------------------------------------------------------------
-- Editor: atur offset engsel lengan secara langsung (/tolarm x y z, admin)
---------------------------------------------------------------------------

RegisterNetEvent('f_toll:client:armOffset', function(x, y, z)
    if GetInvokingResource() then return end
    if x and y and z then
        B.armOffset = vec3(x, y, z)
        for _, set in pairs(spawned) do barrier.move(set, set.pos, set.h) end
    end
    local o = B.armOffset
    lib.notify({ description = ('armOffset = vec3(%.2f, %.2f, %.2f) - salin ke config/shared.lua'):format(o.x, o.y, o.z), type = 'info', duration = 10000 })
    print(('[f_toll] armOffset = vec3(%.2f, %.2f, %.2f),'):format(o.x, o.y, o.z))
end)

-- Diagnosa: tiang/lengan/penahan benar-benar ada? (F8 + penanda 15 detik)
RegisterCommand('toldebug', function()
    local function desc(name, e)
        if not e then return ('%s: nil'):format(name) end
        if not DoesEntityExist(e) then return ('%s: %s TIDAK ADA'):format(name, e) end
        local c = GetEntityCoords(e)
        return ('%s: model=%s vis=%s alpha=%s coll=%s pos=%.2f %.2f %.2f'):format(name, GetEntityModel(e),
            tostring(IsEntityVisible(e)), GetEntityAlpha(e), tostring(not GetEntityCollisionDisabled(e)), c.x, c.y, c.z)
    end
    local marks, n = {}, 0
    for id, set in pairs(spawned) do
        n = n + 1
        print(('[f_toll] %s state=%s angle=%.1f broken=%s'):format(id, tostring(states[id]), set.angle or -1, tostring(set.broken)))
        print('  ' .. desc('tiang', set.base))
        print('  ' .. desc('lengan', set.arm))
        print(('  model ada: tiang=%s lengan=%s'):format(tostring(IsModelInCdimage(B.base)), tostring(IsModelInCdimage(B.arm))))
        for k, o in ipairs(set.blockers or {}) do print('  ' .. desc('penahan' .. k, o)) end
        for _, e in ipairs({ set.base, set.arm }) do
            if e and DoesEntityExist(e) then marks[#marks + 1] = e end
        end
    end
    print(('[f_toll] %d palang termuat'):format(n))
    lib.notify({ description = ('%d palang termuat - lihat F8'):format(n), type = 'info' })
    CreateThread(function()
        local untilT = GetGameTimer() + 15000
        while GetGameTimer() < untilT do
            for _, e in ipairs(marks) do
                if DoesEntityExist(e) then
                    local c = GetEntityCoords(e)
                    DrawMarker(0, c.x, c.y, c.z + 2.0, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 255, 60, 60, 200, true, false, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end)
end, false)

editor.init({
    showText = showText,
    hideText = hideText,
    setMenuOpen = function(v) menuOpen = v end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    hideText()
    despawnAll()
    for _, p in ipairs(points) do
        if p.ped and DoesEntityExist(p.ped) then DeleteEntity(p.ped) end
    end
    if menuOpen then SetNuiFocus(false, false) end
end)
