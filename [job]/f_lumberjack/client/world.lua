-- pohon (prop lokal, hanya yang dekat) dan kayu di tanah (batang utuh / potongan), state dari server
local config, sharedConfig = FLJ.config, FLJ.shared
local notify = FLJ.notify

local trees = {}        -- index -> { coords, available, obj }
FLJ.items = {}          -- id -> { crew, kind, x, y, z, h, front, back, obj, placed }
local sawing = false    -- sedang menebang / memotong

local function mine(item)
    return item ~= nil and FLJ.working() and FLJ.crew.id == item.crew
end

local function idle()
    return not sawing and not FLJ.carrying() and not FLJ.waiting()
end

FLJ.busySawing = function() return sawing end

---------------------------------------------------------------------------
-- chainsaw: menebang pohon & memotong batang memakai progress yang sama
---------------------------------------------------------------------------
local function canSaw()
    if exports.ox_inventory:Search('count', 'chainsaw') < 1 then
        notify('Kamu butuh chainsaw (beli di Mandor Paleto).', 'error')
        return false
    end
    return true
end

local function saw(target, seconds, label)
    local me = GetEntityCoords(cache.ped)
    SetEntityHeading(cache.ped, GetHeadingFromVector_2d(target.x - me.x, target.y - me.y))

    -- serpihan kayu selama memotong (ptfx jaringan, terlihat pemain lain)
    local running = true
    CreateThread(function()
        lib.requestNamedPtfxAsset('core', 2000)
        while running do
            local p = GetOffsetFromEntityInWorldCoords(cache.ped, 0.235, 0.6, 0.0)
            UseParticleFxAssetNextCall('core')
            StartNetworkedParticleFxNonLoopedAtCoord('ent_dst_wood_splinter', p.x, p.y, p.z, 0.0, 0.0,
                GetEntityHeading(cache.ped) - 180.0, 0.4, false, false, false)
            Wait(250)
        end
    end)

    local cs = config.chainsaw
    local done = lib.progressBar({
        duration = seconds * 1000,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = config.cutAnim.dict, clip = config.cutAnim.clip, flag = 49 },
        prop = { model = cs.model, bone = cs.bone, pos = cs.pos, rot = cs.rot },
    })
    running = false
    return done
end

---------------------------------------------------------------------------
-- pohon
---------------------------------------------------------------------------
local function deleteTree(tree)
    if not tree.obj then return end
    exports.ox_target:removeLocalEntity(tree.obj)
    if DoesEntityExist(tree.obj) then DeleteEntity(tree.obj) end
    tree.obj = nil
end

local function cutTree(index)
    if not idle() or not canSaw() then return end
    sawing = true
    local res = lib.callback.await('f_lumberjack:server:reserveTree', false, index)
    if not res or not res.ok then
        sawing = false
        if res and res.msg then notify(res.msg, 'error') end
        return
    end

    if saw(trees[index].coords, res.seconds, 'Menebang pohon...') then
        -- the tree falls away from the player
        local ok = lib.callback.await('f_lumberjack:server:fellTree', false, index, GetEntityHeading(cache.ped))
        if not ok then notify('Gagal menebang pohon, coba lagi.', 'error') end
    else
        TriggerServerEvent('f_lumberjack:server:cancelTree', index)
    end
    sawing = false
end

local function spawnTree(index)
    local tree = trees[index]
    if tree.obj or not tree.available then return end
    local m = sharedConfig.tree.model
    lib.requestModel(m, 5000)
    local c = tree.coords
    tree.obj = CreateObject(m, c.x, c.y, c.z + sharedConfig.tree.zOffset, false, false, false)
    SetModelAsNoLongerNeeded(m)
    FreezeEntityPosition(tree.obj, true)
    exports.ox_target:addLocalEntity(tree.obj, {
        {
            name = 'flj_cut', icon = 'fas fa-tree', label = 'Tebang pohon', distance = 4.0,
            canInteract = function() return FLJ.working() and idle() end,
            onSelect = function() cutTree(index) end,
        },
    })
end

local function treeNear(index)
    return #(GetEntityCoords(cache.ped) - trees[index].coords) < config.treeDistance
end

---------------------------------------------------------------------------
-- pohon tumbang: berputar di titik potong (tinggi tanah saat berdiri), ikut kemiringan tanah
---------------------------------------------------------------------------
-- tinggi tanah dari collision peta saja (flag 1): prop pohon / batang / kendaraan di atasnya tidak ikut terhitung
local function groundZ(x, y, z)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(x, y, z + 10.0, x, y, z - 15.0, 1, 0, 4)
    local _, hit, at = GetShapeTestResult(ray)
    if hit == true or hit == 1 then return at.z end     -- CfxLua: BOOL keluar sebagai boolean
end

local function forward(h)
    local r = math.rad(h)
    return -math.sin(r), math.cos(r)
end

-- titik potong + pitch pohon rebah mengikuti kemiringan tanah; nil = collision belum dimuat
local function fallenPose(sx, sy, sz, h)
    local fx, fy = forward(h)
    local L = config.fallen.probe
    local z1 = groundZ(sx, sy, sz)
    local z2 = groundZ(sx + fx * L, sy + fy * L, sz)
    if not z1 or not z2 then return end
    return vec3(sx, sy, z1 + config.fallen.radius), -90.0 + math.deg(math.atan(z2 - z1, L))
end

-- pitch 0 = berdiri, -90 = rebah ke arah heading; titik potong tetap di pivot
local function setTreePose(obj, pivot, h, pitch)
    local cut = -sharedConfig.tree.zOffset
    local fx, fy = forward(h)
    local p = math.rad(pitch)
    local ax, ay, az = -math.sin(p) * fx, -math.sin(p) * fy, math.cos(p)    -- sumbu batang
    SetEntityCoordsNoOffset(obj, pivot.x - ax * cut, pivot.y - ay * cut, pivot.z - az * cut, false, false, false)
    SetEntityRotation(obj, pitch, 0.0, h, 2, true)
end

-- tumbang (berputar di tunggul) lalu diganti batang besar di tanah
local function fallTree(tree, heading, onDone)
    local obj = tree.obj
    tree.obj = nil
    if not obj or not DoesEntityExist(obj) then return onDone() end
    exports.ox_target:removeLocalEntity(obj)
    local c = tree.coords
    local pivot, target = fallenPose(c.x, c.y, c.z, heading)
    pivot, target = pivot or vec3(c.x, c.y, c.z), target or -90.0
    CreateThread(function()
        local start = GetGameTimer()
        while true do
            local t = math.min((GetGameTimer() - start) / config.fallMs, 1.0)
            setTreePose(obj, vec3(c.x, c.y, c.z + (pivot.z - c.z) * t), heading, target * t * t * t)
            if t >= 1.0 then break end
            Wait(0)
        end
        local fx, fy = forward(heading)
        lib.requestNamedPtfxAsset('scr_reconstructionaccident', 500)
        UseParticleFxAssetNextCall('scr_reconstructionaccident')
        StartParticleFxNonLoopedAtCoord('scr_reconstruct_pipe_impact', pivot.x + fx * 10.0, pivot.y + fy * 10.0, pivot.z,
            0.0, 0.0, 0.0, 3.0, false, false, false)
        -- hapus pohon dulu supaya batang baru diletakkan di tanah, bukan di atas pohon yang rebah
        DeleteEntity(obj)
        onDone()
    end)
end

---------------------------------------------------------------------------
-- kayu di tanah: rebah mengikuti kemiringan tanah (tinggi tanah di kedua ujung)
---------------------------------------------------------------------------
-- false = collision belum dimuat, coba lagi saat pemain lebih dekat
local function placeItem(item)
    local model = FLJ.models[item.kind]
    local a = FLJ.modelAxis(model)
    local r = math.rad(item.h)
    local dx, dy = -math.sin(r), math.cos(r)
    local half = a.len / 2
    local z1 = groundZ(item.x - dx * half, item.y - dy * half, item.z)
    local z2 = groundZ(item.x + dx * half, item.y + dy * half, item.z)
    if not z1 or not z2 then
        SetEntityCoords(item.obj, item.x, item.y, item.z, false, false, false, false)
        SetEntityHeading(item.obj, item.h + a.yaw)
        return false
    end
    local pitch = math.deg(math.atan(z2 - z1, a.len))
    SetEntityCoords(item.obj, item.x, item.y, (z1 + z2) / 2 - a.bottom, false, false, false, false)
    if a.yaw == 0.0 then
        SetEntityRotation(item.obj, pitch, 0.0, item.h, 2, true)
    else
        SetEntityRotation(item.obj, 0.0, -pitch, item.h + a.yaw, 2, true)
    end
    return true
end

local function buckTrunk(id)
    local item = FLJ.items[id]
    if not idle() or not canSaw() or not item then return end
    sawing = true
    local res = lib.callback.await('f_lumberjack:server:reserveBuck', false, id)
    if not res or not res.ok then
        sawing = false
        if res and res.msg then notify(res.msg, 'error') end
        return
    end
    if saw(item, res.seconds, 'Memotong batang...') then
        if not lib.callback.await('f_lumberjack:server:buck', false, id) then notify('Gagal memotong batang, coba lagi.', 'error') end
    else
        TriggerServerEvent('f_lumberjack:server:cancelBuck', id)
    end
    sawing = false
end

local function takePiece(id)
    if not idle() or cache.vehicle then return end
    if not lib.callback.await('f_lumberjack:server:takePiece', false, id) then
        notify('Tidak bisa mengambil potongan ini.', 'error')
    end
end

local function canLift(id, role)
    local item = FLJ.items[id]
    return mine(item) and idle() and #FLJ.crew.members > 1 and not item[role]
end

local function targetOptions(id, kind)
    if kind == 'piece' then
        return {
            {
                name = 'flj_take', icon = 'fas fa-hand', label = 'Ambil potongan', distance = 2.5,
                canInteract = function() return mine(FLJ.items[id]) and idle() end,
                onSelect = function() takePiece(id) end,
            },
        }
    end
    return {
        {
            name = 'flj_buck', icon = 'fas fa-scissors', label = 'Potong batang', distance = 3.5,
            canInteract = function()
                local item = FLJ.items[id]
                -- hanya solo; kru mengangkat batang besar utuh ke flatbed
                return mine(item) and idle() and #FLJ.crew.members == 1 and not item.front and not item.back
            end,
            onSelect = function() buckTrunk(id) end,
        },
        {
            name = 'flj_front', icon = 'fas fa-people-carry-box', label = 'Angkat depan', distance = 3.5,
            canInteract = function() return canLift(id, 'front') end,
            onSelect = function() FLJ.claimTrunk(id, 'front') end,
        },
        {
            name = 'flj_back', icon = 'fas fa-people-carry-box', label = 'Angkat belakang', distance = 3.5,
            canInteract = function() return canLift(id, 'back') end,
            onSelect = function() FLJ.claimTrunk(id, 'back') end,
        },
    }
end

local function spawnItem(id, item)
    local model = FLJ.models[item.kind]
    lib.requestModel(model, 5000)
    item.obj = CreateObject(model, item.x, item.y, item.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(item.obj, true)
    item.placed = placeItem(item)
    exports.ox_target:addLocalEntity(item.obj, targetOptions(id, item.kind))
end

local function deleteItem(item)
    if not item.obj then return end
    exports.ox_target:removeLocalEntity(item.obj)
    if DoesEntityExist(item.obj) then DeleteEntity(item.obj) end
    item.obj = nil
end

local itemLoop = false

local function startItemLoop()
    if itemLoop then return end
    itemLoop = true
    CreateThread(function()
        while next(FLJ.items) do
            local me = GetEntityCoords(cache.ped)
            for id, item in pairs(FLJ.items) do
                local dist = #(me.xy - vec2(item.x, item.y))
                local near = dist < config.itemDistance
                if near and not item.obj then spawnItem(id, item)
                elseif not near and item.obj then deleteItem(item)
                elseif item.obj and not item.placed and dist < 60.0 then item.placed = placeItem(item) end
            end
            Wait(2000)
        end
        itemLoop = false
    end)
end

local function addItems(list)
    local me = GetEntityCoords(cache.ped)
    for id, data in pairs(list) do
        id = tonumber(id)
        if FLJ.items[id] then deleteItem(FLJ.items[id]) end
        local item = { crew = data.crew, kind = data.kind, x = data.x, y = data.y, z = data.z, h = data.h, front = data.front, back = data.back }
        FLJ.items[id] = item
        -- spawn the near ones right away instead of waiting for the loop tick
        if #(me.xy - vec2(item.x, item.y)) < config.itemDistance then spawnItem(id, item) end
    end
    startItemLoop()
end

RegisterNetEvent('f_lumberjack:client:itemsAdd', addItems)

RegisterNetEvent('f_lumberjack:client:itemsRemove', function(ids)
    for _, id in ipairs(ids) do
        local item = FLJ.items[id]
        if item then
            deleteItem(item)
            FLJ.items[id] = nil
        end
    end
end)

RegisterNetEvent('f_lumberjack:client:itemClaim', function(id, front, back)
    local item = FLJ.items[id]
    if item then item.front, item.back = front, back end
end)

---------------------------------------------------------------------------
-- server events
---------------------------------------------------------------------------
RegisterNetEvent('f_lumberjack:client:treeFall', function(index, heading, added)
    local tree = trees[index]
    if not tree then return end
    tree.available = false
    if tree.obj and treeNear(index) then
        fallTree(tree, heading, function() addItems(added) end)
    else
        deleteTree(tree)
        addItems(added)
    end
end)

RegisterNetEvent('f_lumberjack:client:treeBack', function(index)
    local tree = trees[index]
    if not tree then return end
    tree.available = true
    if treeNear(index) then spawnTree(index) end
end)

CreateThread(function()
    local world = lib.callback.await('f_lumberjack:server:world', false)
    for i, c in ipairs(sharedConfig.trees) do
        trees[i] = { coords = c, available = not world or world.trees[i] ~= false }
        lib.points.new({
            coords = c,
            distance = config.treeDistance,
            onEnter = function() spawnTree(i) end,
            onExit = function() deleteTree(trees[i]) end,
        })
    end
    if world and world.items then addItems(world.items) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, tree in pairs(trees) do deleteTree(tree) end
    for _, item in pairs(FLJ.items) do deleteItem(item) end
end)
