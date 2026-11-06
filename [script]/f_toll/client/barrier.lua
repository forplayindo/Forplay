-- Palang tol: prop lokal (tidak di-network) per pemain, status buka/tutup dari server.
-- Lengan dikunci (beku, tidak bisa patah) + penahan tak terlihat selama tertutup; patah = lengan jatuh.
local config = require 'config.shared'
local B = config.barrier

local barrier = {}
local info -- sumbu panjang lengan & penahan, dihitung sekali dari ukuran model

function barrier.info()
    if info then return info end
    local arm = lib.requestModel(B.arm)
    local mn, mx = GetModelDimensions(arm)
    local lx, ly = mx.x - mn.x, mx.y - mn.y
    if lx >= ly then
        info = { axis = 'x', sign = mx.x >= -mn.x and 1 or -1, length = lx }
    else
        info = { axis = 'y', sign = mx.y >= -mn.y and 1 or -1, length = ly }
    end
    local bl = lib.requestModel(B.blocker)
    local bmn, bmx = GetModelDimensions(bl)
    local bx, by = bmx.x - bmn.x, bmx.y - bmn.y
    info.block = { axis = bx >= by and 'x' or 'y', length = math.max(bx, by) }
    return info
end

---Arah lengan di dunia (dari engsel ke ujung) untuk heading h
function barrier.armDir(h)
    local i = barrier.info()
    local r = math.rad(h)
    if i.axis == 'x' then return vec3(math.cos(r), math.sin(r), 0.0) * i.sign end
    return vec3(-math.sin(r), math.cos(r), 0.0) * i.sign
end

-- angle 0 = tertutup (mendatar), B.openAngle = terbuka (naik)
local function rotation(h, angle)
    local i = barrier.info()
    local a = angle * (B.invert and -1 or 1) * i.sign
    if i.axis == 'x' then return 0.0, -a, h end
    return a, 0.0, h
end

local function lock(e)
    FreezeEntityPosition(e, true)
    SetEntityInvincible(e, true)
    SetEntityCanBeDamaged(e, false)
    SetDisableFragDamage(e, true)
end

local function makeArm(set)
    local m = lib.requestModel(B.arm)
    -- lengan palang GTA (ld_01a/ld_02a) terdaftar sebagai pintu: tanpa doorFlag hasilnya 0
    local arm = CreateObjectNoOffset(m, set.hinge.x, set.hinge.y, set.hinge.z, false, false, true)
    if arm == 0 then arm = CreateObjectNoOffset(m, set.hinge.x, set.hinge.y, set.hinge.z, false, false, false) end
    SetModelAsNoLongerNeeded(m)
    if arm == 0 then
        print(('[f_toll] gagal membuat lengan palang (%s)'):format(B.arm))
        return
    end
    lock(arm)
    -- engsel ada di dalam tiang: jangan saling tabrak (lengan bisa terlempar/hilang)
    if set.base then SetEntityNoCollisionEntity(arm, set.base, false) end
    set.arm = arm
    barrier.setAngle(set, set.angle or 0.0)
end

local function hingeOf(set)
    if set.base then
        return GetOffsetFromEntityInWorldCoords(set.base, B.armOffset.x, B.armOffset.y, B.armOffset.z)
    end
    return set.pos
end

---@param pos vector3 titik tiang di aspal
---@param h number heading tiang
---@param ghost? boolean pratinjau editor (transparan, tanpa collision)
function barrier.create(pos, h, ghost)
    local set = { pos = pos, h = h, angle = 0.0, alive = true, ghost = ghost }
    if B.base then
        local m = lib.requestModel(B.base)
        set.base = CreateObjectNoOffset(m, pos.x, pos.y, pos.z, false, false, false)
        SetModelAsNoLongerNeeded(m)
        SetEntityHeading(set.base, h)
        lock(set.base)
    end
    set.hinge = hingeOf(set)
    makeArm(set)
    if ghost then
        for _, e in ipairs({ set.base, set.arm }) do
            if e then
                SetEntityAlpha(e, 160, false)
                SetEntityCollision(e, false, false)
            end
        end
    end
    return set
end

---Pindahkan (editor pratinjau / ganti offset engsel)
function barrier.move(set, pos, h)
    set.pos, set.h = pos, h
    if set.base then
        SetEntityCoordsNoOffset(set.base, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(set.base, h)
    end
    set.hinge = hingeOf(set)
    barrier.setAngle(set, set.angle)
end

function barrier.setAngle(set, angle)
    set.angle = angle
    if not set.arm then return end
    local x, y, z = rotation(set.h, angle)
    SetEntityCoordsNoOffset(set.arm, set.hinge.x, set.hinge.y, set.hinge.z, false, false, false)
    SetEntityRotation(set.arm, x, y, z, 2, false)
end

---Gerak halus ke sudut target (satu thread per palang, hanya saat bergerak)
function barrier.animate(set, target)
    set.target = target
    if set.animating or set.angle == target then return end
    set.animating = true
    CreateThread(function()
        local speed = B.openAngle / B.animTime
        local last = GetGameTimer()
        while set.alive and set.arm and set.angle ~= set.target do
            local now = GetGameTimer()
            local step = speed * (now - last)
            last = now
            local a = set.angle < set.target and math.min(set.target, set.angle + step) or math.max(set.target, set.angle - step)
            barrier.setAngle(set, a)
            Wait(0)
        end
        set.animating = false
    end)
end

local function blockerPoints(set)
    local i = barrier.info()
    local dir = barrier.armDir(set.h)
    local n = math.max(1, math.ceil(i.length / i.block.length))
    local step = i.length / n
    local pts = {}
    for k = 1, n do pts[k] = set.pos + dir * (step * (k - 0.5)) end
    local heading = i.block.axis == 'x' and math.deg(math.atan(dir.y, dir.x)) or math.deg(math.atan(-dir.x, dir.y))
    return pts, heading
end

---Masih ada kendaraan di bawah lengan? (penahan jangan muncul di dalam mobil)
function barrier.blocked(set)
    local pts = blockerPoints(set)
    for _, p in ipairs(pts) do
        if IsAnyVehicleNearPoint(p.x, p.y, p.z + 0.5, 1.6) then return true end
    end
    return false
end

function barrier.addBlockers(set)
    if set.blockers or set.ghost then return end
    local m = lib.requestModel(B.blocker)
    local pts, heading = blockerPoints(set)
    set.blockers = {}
    for k, p in ipairs(pts) do
        local o = CreateObjectNoOffset(m, p.x, p.y, set.pos.z, false, false, false)
        SetEntityHeading(o, heading)
        lock(o)
        if not B.showBlockers then SetEntityVisible(o, false, false) end
        set.blockers[k] = o
    end
    SetModelAsNoLongerNeeded(m)
end

function barrier.removeBlockers(set)
    if not set.blockers then return end
    for _, o in ipairs(set.blockers) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    set.blockers = nil
end

---Kendaraan menyentuh lengan / penahan?
function barrier.touching(set, veh)
    if set.arm and IsEntityTouchingEntity(veh, set.arm) then return true end
    if set.blockers then
        for _, o in ipairs(set.blockers) do
            if IsEntityTouchingEntity(veh, o) then return true end
        end
    end
    return false
end

---Palang patah: lengan dilepas dan jatuh (fisika lokal), penahan hilang
function barrier.breakArm(set)
    barrier.removeBlockers(set)
    if not set.arm then return end
    local arm = set.arm
    set.arm = nil
    FreezeEntityPosition(arm, false)
    SetEntityInvincible(arm, false)
    SetEntityDynamic(arm, true)
    ActivatePhysics(arm)
    local dir = barrier.armDir(set.h)
    ApplyForceToEntity(arm, 1, dir.y * 2.0, -dir.x * 2.0, 1.5, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    set.debris = arm
end

function barrier.restoreArm(set)
    if set.debris and DoesEntityExist(set.debris) then DeleteEntity(set.debris) end
    set.debris = nil
    if not set.arm then
        set.angle = 0.0
        makeArm(set)
    end
end

function barrier.delete(set)
    set.alive = false
    barrier.removeBlockers(set)
    for _, e in ipairs({ set.arm, set.base, set.debris }) do
        if e and DoesEntityExist(e) then DeleteEntity(e) end
    end
    set.arm, set.base, set.debris = nil, nil, nil
end

return barrier
