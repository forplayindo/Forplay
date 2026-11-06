-- memanggul: potongan sendiri, batang utuh berdua (depan berjalan, belakang menempel ke pemain depan)
local config, sharedConfig = FLJ.config, FLJ.shared
local cc = config.carry
local notify = FLJ.notify

local carry             -- { id, kind, role = 'piece' | 'front' | 'back', partner, obj, attached }
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

-- prop kayu di tangan / bahu, dibuat jaringan supaya pemain lain melihat
local function attachProp(model, bone, pos, rot)
    lib.requestModel(model, 5000)
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(obj, false, false)
    local b = bone == 0 and 0 or GetPedBoneIndex(cache.ped, bone)
    AttachEntityToEntity(obj, cache.ped, b, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    return obj
end

local function trunkLen()
    return FLJ.modelAxis(FLJ.models.trunk).len
end

local function attachTrunk()
    local a = FLJ.modelAxis(FLJ.models.trunk)
    local f = cc.trunk.frontEnd
    return attachProp(FLJ.models.trunk, 0, vec3(f.x, f.y - a.len / 2, f.z), vec3(0.0, 0.0, a.yaw))
end

-- pemain belakang menempel di belakang pemain depan, menghadap sama
local function attachToFront()
    local player = GetPlayerFromServerId(carry.partner)
    local front = player ~= -1 and GetPlayerPed(player) or 0
    if front == 0 or front == cache.ped or not DoesEntityExist(front) then return false end
    local y = cc.trunk.frontEnd.y - trunkLen() + cc.backGap
    AttachEntityToEntity(cache.ped, front, 0, 0.0, y, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    return true
end

function FLJ.stopCarry()
    waiting = nil
    if not carry then return end
    local c = carry
    carry = nil
    if c.obj and DoesEntityExist(c.obj) then DeleteEntity(c.obj) end
    if c.role == 'back' then DetachEntity(cache.ped, true, false) end
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
    if carry.role == 'front' then
        -- berdua mendorong batang ke bak
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
-- loop per frame selama memanggul
---------------------------------------------------------------------------
local BLOCK = { 21, 22, 23, 24, 25, 37, 44, 45, 140, 141, 142, 143, 257, 263, 264 }
local BLOCK_BACK = { 30, 31, 32, 33, 34, 35 }

local function carryLoop(c)
    CreateThread(function()
        while carry == c do
            for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
            if c.role == 'back' then
                for i = 1, #BLOCK_BACK do DisableControlAction(0, BLOCK_BACK[i], true) end
                if not c.attached then c.attached = attachToFront() end
            end
            if not loading then playAnim(carryAnim()) end

            if IsEntityDead(cache.ped) or cache.vehicle then
                TriggerServerEvent('f_lumberjack:server:drop')
                FLJ.stopCarry()
                break
            end

            local canLoad = c.role ~= 'back' and not loading and nearRear()
            if c.role == 'back' then
                showPrompt('Rekanmu yang berjalan  \n[X] Turunkan batang')
            elseif canLoad then
                showPrompt(c.kind == 'trunk' and '[E] Masukkan batang ke bak  \n[X] Turunkan' or '[E] Masukkan ke bak  \n[X] Turunkan')
            elseif not loading then
                showPrompt(c.kind == 'trunk' and '[X] Turunkan batang  \nRekanmu ikut di belakang' or '[X] Turunkan potongan')
            end

            if IsDisabledControlJustPressed(0, 73) and not loading then
                TriggerServerEvent('f_lumberjack:server:drop')
            elseif canLoad and IsControlJustPressed(0, 38) then
                hidePrompt()
                load()
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('f_lumberjack:client:carry', function(data)
    FLJ.stopCarry()
    if not data then return end
    carry = { id = data.id, kind = data.kind, role = data.role, partner = data.partner }
    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)

    if data.kind == 'piece' then
        local p = cc.piece
        local yaw = FLJ.modelAxis(FLJ.models.piece).yaw
        carry.obj = attachProp(FLJ.models.piece, p.bone, p.pos, vec3(p.rot.x, p.rot.y, p.rot.z + yaw))
    elseif data.role == 'front' then
        carry.obj = attachTrunk()
    else
        carry.attached = attachToFront()
    end
    carryLoop(carry)
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
end)
