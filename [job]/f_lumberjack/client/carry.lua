-- memanggul: potongan sendiri di bahu; batang utuh berdua (tiap pemain jalan sendiri, batang di bahu kanan keduanya,
-- jarak keduanya dijaga seperti tongkat kaku: menjauh = rekan ikut tertarik, mendorong = berat & rekan terdorong pelan)
local config, sharedConfig = FLJ.config, FLJ.shared
local cc = config.carry
local tc = cc.trunk
local notify = FLJ.notify

local carry             -- { id, kind, role = 'piece' | 'front' | 'back', partner, obj, rest, setup, farSince, lostSince }
local waiting           -- { id, role, since } menunggu rekan di ujung lain batang
local prompt
local loading = false

function FLJ.carrying() return carry end
function FLJ.waiting() return waiting end

local function showPrompt(text)
    if prompt == text then return end
    prompt = text
    lib.showTextUI(text)
end

local function hidePrompt()
    if not prompt then return end
    prompt = nil
    lib.hideTextUI()
end

local function playAnim(a)
    if IsEntityPlayingAnim(cache.ped, a.dict, a.clip, 3) then return end
    lib.requestAnimDict(a.dict, 2000)
    TaskPlayAnim(cache.ped, a.dict, a.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function carryAnim()
    return carry.kind == 'piece' and cc.pieceAnim or cc.trunkAnim
end

-- potongan di bahu, dibuat jaringan supaya pemain lain melihat
local function attachProp(model, bone, pos, rot)
    lib.requestModel(model, 5000)
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(obj, false, false)
    local b = bone == 0 and 0 or GetPedBoneIndex(cache.ped, bone)
    AttachEntityToEntity(obj, cache.ped, b, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    return obj
end

-- jarak antar titik pegang kedua pemain saat batang lurus
local function restLength()
    return math.max(FLJ.modelAxis(FLJ.models.trunk).len - tc.endInset * 2, 1.5)
end

-- pusat batang dari tengah pemain: titik bahu + jari-jari batang ke kanan & ke atas
local grip
local function gripOffset()
    if not grip then
        local a = FLJ.modelAxis(FLJ.models.trunk)
        local r = math.min(a.width, a.height) / 2
        local s = tc.shoulder
        grip = vec3(s.x + r, s.y, s.z + r * tc.lift)
    end
    return grip
end

local function handPoint(ped)
    local g = gripOffset()
    return GetOffsetFromEntityInWorldCoords(ped, g.x, g.y, g.z)
end

---------------------------------------------------------------------------
-- batang yang sedang diangkat berdua: digambar lokal di SEMUA client di antara tangan kedua pemain
---------------------------------------------------------------------------
local lifts = {}        -- id -> { front, back, obj }
local liftLoop = false

local function liftPeds(l)
    local pf, pb = GetPlayerFromServerId(l.front), GetPlayerFromServerId(l.back)
    if pf == -1 or pb == -1 then return end
    local f, b = GetPlayerPed(pf), GetPlayerPed(pb)
    if f == 0 or b == 0 or not DoesEntityExist(f) or not DoesEntityExist(b) then return end
    return f, b
end

-- p1 = tangan pemain depan, p2 = tangan pemain belakang; rotasi sama seperti kayu di tanah (world.lua placeItem)
local function placeLog(obj, a, p1, p2)
    local dx, dy, dz = p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
    local h = math.deg(math.atan(-dx, dy))
    local pitch = math.deg(math.atan(dz, math.sqrt(dx * dx + dy * dy)))
    SetEntityCoordsNoOffset(obj, (p1.x + p2.x) / 2, (p1.y + p2.y) / 2, (p1.z + p2.z) / 2 - a.bottom - a.height / 2, false, false, false)
    if a.yaw == 0.0 then
        SetEntityRotation(obj, pitch, 0.0, h, 2, true)
    else
        SetEntityRotation(obj, 0.0, -pitch, h + a.yaw, 2, true)
    end
end

local function deleteLift(l)
    if l and l.obj then
        if DoesEntityExist(l.obj) then DeleteEntity(l.obj) end
        l.obj = nil
    end
end

local function startLiftLoop()
    if liftLoop then return end
    liftLoop = true
    CreateThread(function()
        local model = FLJ.models.trunk
        local a = FLJ.modelAxis(model)
        lib.requestModel(model, 5000)
        while next(lifts) do
            local me = GetEntityCoords(cache.ped)
            local drawn = false
            for _, l in pairs(lifts) do
                local f, b = liftPeds(l)
                if f and #(me - GetEntityCoords(f)) < 150.0 then
                    if not l.obj then
                        l.obj = CreateObject(model, me.x, me.y, me.z - 50.0, false, false, false)
                        SetEntityCollision(l.obj, false, false)
                    end
                    placeLog(l.obj, a, handPoint(f), handPoint(b))
                    drawn = true
                else
                    deleteLift(l)
                end
            end
            Wait(drawn and 0 or 500)
        end
        SetModelAsNoLongerNeeded(model)
        liftLoop = false
    end)
end

function FLJ.setLift(id, front, back)
    deleteLift(lifts[id])
    lifts[id] = front and { front = front, back = back } or nil
    if front then startLiftLoop() end
end

RegisterNetEvent('f_lumberjack:client:lift', FLJ.setLift)

---------------------------------------------------------------------------
-- jaga jarak dengan rekan (hanya ped sendiri yang digeser; rekan menggeser ped-nya sendiri di client-nya)
---------------------------------------------------------------------------
local function partnerPed(c)
    local player = GetPlayerFromServerId(c.partner)
    local ped = player ~= -1 and GetPlayerPed(player) or 0
    if ped == 0 or ped == cache.ped or not DoesEntityExist(ped) then return end
    return ped
end

-- false = batang harus dilepas
local function constrain(c)
    local now = GetGameTimer()
    local other = partnerPed(c)
    if not other then
        c.lostSince = c.lostSince or now
        return now - c.lostSince < 3000
    end
    c.lostSince = nil

    local me, p = GetEntityCoords(cache.ped), GetEntityCoords(other)
    local dx, dy = p.x - me.x, p.y - me.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 0.05 then return true end
    local ux, uy = dx / d, dy / d       -- arah dari aku ke rekan
    local e = d - c.rest                -- + = batang tertarik (terlalu jauh), - = terdorong (terlalu dekat)

    if e > tc.breakDist then
        c.farSince = c.farSince or now
        if now - c.farSince > tc.breakMs then return false end
    else
        c.farSince = nil
    end

    -- jalan melawan batang terasa berat
    local v = GetEntityVelocity(cache.ped)
    local toward = v.x * ux + v.y * uy
    if e > -tc.slack and toward < -0.2 then
        SetPedMoveRateOverride(cache.ped, tc.pullRate)
    elseif e < tc.slack and toward > 0.2 then
        SetPedMoveRateOverride(cache.ped, tc.pushRate)
    end

    -- ikut tertarik / terdorong
    local over = math.abs(e) - tc.slack
    if over > 0 then
        local speed = e > 0 and tc.dragSpeed or tc.pushSpeed
        local step = math.min(over, speed * GetFrameTime())
        if e < 0 then step = -step end
        SetEntityCoordsNoOffset(cache.ped, me.x + ux * step, me.y + uy * step, me.z, false, false, false)
    end
    return true
end

-- jalan ke ujung batang masing-masing sebelum mengangkat
local function walkToEnd(c, data)
    local r = math.rad(data.h or 0.0)
    local fx, fy = -math.sin(r), math.cos(r)        -- arah batang (depan)
    local rx, ry = math.cos(r), math.sin(r)         -- kanan
    local s = c.role == 'front' and 0.5 or -0.5
    local hx, hy = data.x + fx * c.rest * s, data.y + fy * c.rest * s
    local g = gripOffset()
    local x = hx - fx * g.y - rx * g.x
    local y = hy - fy * g.y - ry * g.x
    local target = vec2(x, y)

    TaskGoStraightToCoord(cache.ped, x, y, data.z + 1.0, 1.0, tc.setupMs, data.h or 0.0, 0.2)
    local deadline = GetGameTimer() + tc.setupMs
    while carry == c and GetGameTimer() < deadline and #(GetEntityCoords(cache.ped).xy - target) > 0.35 do Wait(100) end
    if carry ~= c then return end
    ClearPedTasks(cache.ped)
    SetEntityHeading(cache.ped, data.h or 0.0)
    c.setup = false
end

function FLJ.stopCarry()
    waiting = nil
    if not carry then return end
    local c = carry
    carry = nil
    if c.obj and DoesEntityExist(c.obj) then DeleteEntity(c.obj) end
    if c.setup then ClearPedTasks(cache.ped) end
    StopAnimTask(cache.ped, cc.pieceAnim.dict, cc.pieceAnim.clip, 1.0)
    StopAnimTask(cache.ped, cc.trunkAnim.dict, cc.trunkAnim.clip, 1.0)
    hidePrompt()
end

---------------------------------------------------------------------------
-- belakang bak truk kru
---------------------------------------------------------------------------
local function nearRear()
    local veh = FLJ.truck()
    if not veh then return false end
    local mn = GetModelDimensions(GetEntityModel(veh))
    local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, mn.y - 0.6, 0.0)
    return #(GetEntityCoords(cache.ped).xy - rear.xy) < config.truck.rearRadius
end

local function load()
    loading = true
    if carry.kind == 'trunk' then
        -- mendorong batang ke bak
        local ok = lib.progressBar({
            duration = 2000, label = 'Memasukkan batang ke bak...', canCancel = true,
            disable = { move = true, car = true, combat = true },
        })
        if not ok or not carry then
            loading = false
            return
        end
    end
    local res = lib.callback.await('f_lumberjack:server:load', false)
    if res and not res.ok and res.msg then notify(res.msg, 'error') end
    loading = false
end

---------------------------------------------------------------------------
-- loop per frame selama memanggul / mengangkat
---------------------------------------------------------------------------
local BLOCK = { 21, 22, 23, 24, 25, 37, 44, 45, 140, 141, 142, 143, 257, 263, 264 }
local MOVE = { 30, 31, 32, 33, 34, 35 }

local function carryLoop(c)
    CreateThread(function()
        local trunk = c.kind == 'trunk'
        while carry == c do
            for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end

            if IsEntityDead(cache.ped) or cache.vehicle then
                TriggerServerEvent('f_lumberjack:server:drop')
                FLJ.stopCarry()
                break
            end

            if trunk and c.setup then
                for i = 1, #MOVE do DisableControlAction(0, MOVE[i], true) end
                showPrompt('Berjalan ke ujung batang...')
            else
                if not loading then playAnim(carryAnim()) end
                if trunk then
                    SetPedMaxMoveBlendRatio(cache.ped, 1.0)     -- hanya jalan
                    if not loading and not constrain(c) then
                        notify('Batang terlepas, kalian terlalu berjauhan.', 'error')
                        TriggerServerEvent('f_lumberjack:server:drop')
                        FLJ.stopCarry()
                        break
                    end
                end

                local canLoad = not loading and nearRear()
                if canLoad then
                    showPrompt(trunk and '[E] Masukkan batang ke bak  \n[X] Turunkan' or '[E] Masukkan ke bak  \n[X] Turunkan')
                elseif not loading then
                    showPrompt(trunk and '[X] Turunkan batang  \nAtur arah jalan bersama rekanmu' or '[X] Turunkan potongan')
                end

                if IsDisabledControlJustPressed(0, 73) and not loading then
                    TriggerServerEvent('f_lumberjack:server:drop')
                elseif canLoad and IsControlJustPressed(0, 38) then
                    hidePrompt()
                    load()
                end
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('f_lumberjack:client:carry', function(data)
    FLJ.stopCarry()
    if not data then return end
    local c = { id = data.id, kind = data.kind, role = data.role, partner = data.partner }
    carry = c
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)

    if data.kind == 'piece' then
        local p = cc.piece
        local yaw = FLJ.modelAxis(FLJ.models.piece).yaw
        c.obj = attachProp(FLJ.models.piece, p.bone, p.pos, vec3(p.rot.x, p.rot.y, p.rot.z + yaw))
    else
        c.rest = restLength()
        c.setup = true
        CreateThread(function() walkToEnd(c, data) end)
    end
    carryLoop(c)
end)

---------------------------------------------------------------------------
-- angkat batang berdua: pegang satu ujung, tunggu rekan di ujung lain
---------------------------------------------------------------------------
function FLJ.claimTrunk(id, role)
    local res = lib.callback.await('f_lumberjack:server:claimTrunk', false, id, role)
    if not res or not res.ok then
        if res and res.msg then notify(res.msg, 'error') end
        return
    end
    if not res.waiting or carry then return end

    local w = { id = id, role = role, since = GetGameTimer() }
    waiting = w
    notify(('Kamu memegang ujung %s. Tunggu rekan mengangkat ujung %s.'):format(
        role == 'front' and 'depan' or 'belakang', role == 'front' and 'belakang' or 'depan'), 'inform')
    CreateThread(function()
        while waiting == w and not carry do
            local item = FLJ.items[id]
            local left = sharedConfig.claimTimeout - (GetGameTimer() - w.since) / 1000
            local far = not item or #(GetEntityCoords(cache.ped).xy - vec2(item.x, item.y)) > 11.0
            showPrompt(('Menunggu rekan di ujung lain (%d)  \n[X] Batal'):format(math.max(0, math.ceil(left))))
            if left <= 0 or far or IsControlJustPressed(0, 73) or IsEntityDead(cache.ped) then
                TriggerServerEvent('f_lumberjack:server:unclaim')
                if left <= 0 then notify('Rekan tidak datang, batang dilepas.', 'inform') end
                break
            end
            Wait(0)
        end
        if waiting == w then
            waiting = nil
            if not carry then hidePrompt() end
        end
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    FLJ.stopCarry()
    for _, l in pairs(lifts) do deleteLift(l) end
end)
