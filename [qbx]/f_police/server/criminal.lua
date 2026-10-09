-- Interaksi warga / gang: rampok (hook ox_inventory), sandera, dan korban di bagasi.
-- Kondisi target dibaca dari statebag yang dipasang client TARGET sendiri (canSteal dari
-- ox_inventory) atau dari server (isDead dari f_medical, metadata borgol), jadi pelaku tidak bisa
-- memalsukannya.

local config = require 'config.criminal'
local rob, hostageCfg, text = config.rob, config.hostage, config.text

local hostageWeapons = {}
for _, hash in ipairs(hostageCfg.weapons) do hostageWeapons[hash & 0xFFFFFFFF] = true end

local MONEY_LABEL = { money = 'cash', black_money = 'uang kotor' }

---@type table<integer, integer> penyandera -> sandera
local hostageOf = {}
---@type table<integer, integer> sandera -> penyandera
local heldBy = {}
---@type table<integer, integer> korban -> netId kendaraan yang bagasinya ia tempati
local trunkOf = {}

local function playerOf(src)
    return exports.qbx_core:GetPlayer(src)
end

local function isGang(src)
    if GetResourceState('f_crew') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.f_crew:IsGang(src) end)
    return ok and res == true
end

local function isDown(src, player)
    if Player(src).state.isDead then return true end
    local meta = player and player.PlayerData.metadata
    return meta ~= nil and (meta.isdead or meta.inlaststand) == true
end

local function holdsHostageWeapon(src)
    return hostageWeapons[GetSelectedPedWeapon(GetPlayerPed(src)) & 0xFFFFFFFF] == true
end

---Target sudah menyerah: angkat tangan (canSteal ox_inventory), kena taser, atau pingsan/mati.
---@param src integer
---@param player? table
---@return boolean
function IsSubdued(src, player)
    local state = Player(src).state
    return state.canSteal == true or state.stunned == true or isDown(src, player or playerOf(src))
end

---Sedang disandera atau berada di bagasi: interaksi lain (borgol, seret, gendong) ditolak.
---@param src integer
---@return boolean
function IsHostageOrInTrunk(src)
    src = tonumber(src)
    return src ~= nil and (heldBy[src] ~= nil or trunkOf[src] ~= nil)
end

-- Buka borgol -------------------------------------------------------------------------------

local cuffs = config.cuffs
local UNLOCK_TIME = {
    hand = cuffs.hand.duration,
    key = cuffs.key.duration,
    cutter = cuffs.cutter.duration,
    lockpick = 1000, -- skill check, tidak ada progress tetap
}

---@type table<integer, { target: integer, method: string, started: integer }>
local unlocking = {}

---Penolong berdiri di belakang target (tangan diborgol di punggung).
local function isBehind(helper, target)
    local targetPed = GetPlayerPed(target)
    local tPos, hPos = GetEntityCoords(targetPed), GetEntityCoords(GetPlayerPed(helper))
    if #(tPos - hPos) > cuffs.maxDistance + 0.4 then return false end

    local dx, dy = hPos.x - tPos.x, hPos.y - tPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.05 then return false end

    local h = math.rad(GetEntityHeading(targetPed))
    -- sedikit lebih longgar dari prompt client supaya lag tidak menggagalkan aksi yang sah
    return (-math.sin(h) * dx + math.cos(h) * dy) / len <= cuffs.behindDot + 0.2
end

---@param method 'hand'|'key'|'lockpick'|'cutter'
---@return boolean
local function canUnlock(src, target, method)
    local player, victim = playerOf(src), playerOf(target)
    if not player or not victim or src == target then return false end
    if not victim.PlayerData.metadata.ishandcuffed or IsHostageOrInTrunk(target) then return false end
    if player.PlayerData.metadata.ishandcuffed or isDown(src, player) or heldBy[src] or hostageOf[src] then return false end
    if not isBehind(src, target) then return false end

    local kind = Player(target).state.cuffType == 'zip' and 'zip' or 'cuff'
    if method == 'hand' then return kind == 'zip' end
    if method == 'key' then return IsLeoAndOnDuty(player) == true end
    if kind ~= 'cuff' then return false end
    if method == 'lockpick' then return player.Functions.GetItemByName(cuffs.lockpick.item) ~= nil end
    if method == 'cutter' then return player.Functions.GetItemByName(cuffs.cutter.item) ~= nil end
    return false
end

RegisterNetEvent('f_police:server:unlockStart', function(target, method)
    local src = source
    target = tonumber(target)
    unlocking[src] = nil
    if not target or not UNLOCK_TIME[method] or not canUnlock(src, target, method) then return end

    unlocking[src] = { target = target, method = method, started = GetGameTimer() }
    exports.qbx_core:Notify(target, text.beingUnlocked, 'inform')
end)

RegisterNetEvent('f_police:server:unlockFinish', function(success)
    local src = source
    local job = unlocking[src]
    unlocking[src] = nil
    if not job then return end
    if GetGameTimer() - job.started < UNLOCK_TIME[job.method] - 500 then return end
    if not canUnlock(src, job.target, job.method) then return end

    if job.method == 'lockpick' and success ~= true then
        playerOf(src).Functions.RemoveItem(cuffs.lockpick.item, 1)
        exports.qbx_core:Notify(src, text.lockpickBroke, 'error')
        return
    end
    if success ~= true then return end

    ReleaseCuffs(job.target, src)
end)

-- Rampok ------------------------------------------------------------------------------------

---@type table<string, { expires: integer, [string]: integer }> 'perampok:korban' -> uang yang sudah diambil
local tallies = {}

local function tallyFor(robber, victim)
    local key = robber .. ':' .. victim
    local now = os.time()
    local tally = tallies[key]
    if tally and tally.expires >= now then return tally end

    for k, t in pairs(tallies) do
        if t.expires < now then tallies[k] = nil end
    end
    tally = { expires = now + rob.limitWindow }
    tallies[key] = tally
    return tally
end

---Uang yang berpindah KELUAR dari inventory pemain lain dalam satu aksi ox_inventory.
---@return integer? victim, string? item, integer? amount
local function takenFromOther(p)
    local src = p.source
    local from, to = tonumber(p.fromInventory), tonumber(p.toInventory)
    if from == to then return end

    local fromSlot, toSlot = p.fromSlot, p.toSlot
    if p.fromType == 'player' and from ~= src and type(fromSlot) == 'table' and rob.limits[fromSlot.name] then
        return from, fromSlot.name, p.action == 'swap' and fromSlot.count or p.count
    end
    -- menukar barang sendiri ke slot uang korban juga memindahkan uang itu ke perampok
    if p.action == 'swap' and p.toType == 'player' and to ~= src and type(toSlot) == 'table' and rob.limits[toSlot.name] then
        return to, toSlot.name, toSlot.count
    end
end

local function registerInventoryHooks()
    -- inventory pemain lain hanya untuk polisi on-duty (geledah) dan anggota gang (rampok)
    exports.ox_inventory:registerHook('openInventory', function(payload)
        local src = payload.source
        local player = playerOf(src)
        if not player then return false end
        if IsLeoAndOnDuty(player) then return end

        if hostageOf[src] or heldBy[src] or (rob.gangOnly and not isGang(src)) then
            exports.qbx_core:Notify(src, text.robNotAllowed, 'error')
            return false
        end

        local victim = tonumber(payload.inventoryId)
        if victim then exports.qbx_core:Notify(victim, text.beingRobbed, 'error') end
    end, { typeFilter = { player = true } })

    local limited, any = {}, false
    for name, limit in pairs(rob.limits) do
        if limit ~= false then limited[name], any = true, true end
    end
    if not any then return end

    exports.ox_inventory:registerHook('swapItems', function(p)
        local victim, item, amount = takenFromOther(p)
        if not victim or not limited[item] then return end

        local src = p.source
        local player = playerOf(src)
        if not player or IsLeoAndOnDuty(player) then return end

        local limit = rob.limits[item]
        local tally = tallyFor(src, victim)
        local taken = tally[item] or 0
        if taken + amount > limit then
            exports.qbx_core:Notify(src, text.robLimit:format(MONEY_LABEL[item] or item, math.max(limit - taken, 0)), 'error')
            return false
        end
        tally[item] = taken + amount
    end, { itemFilter = limited })
end

CreateThread(function()
    if GetResourceState('ox_inventory') == 'started' then registerInventoryHooks() end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'ox_inventory' then registerInventoryHooks() end
end)

-- Sandera -----------------------------------------------------------------------------------

---@param taker integer
---@param kind 'release'|'execute'|'broken'
local function endHostage(taker, kind)
    local victim = hostageOf[taker]
    if not victim then return end
    hostageOf[taker], heldBy[victim] = nil, nil
    if GetPlayerName(victim) then Player(victim).state:set('hostage', nil, true) end
    TriggerClientEvent('f_police:client:hostageEnd', taker, kind)
    TriggerClientEvent('f_police:client:hostageEnd', victim, kind)
end

RegisterNetEvent('f_police:server:takeHostage', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end

    local player, victim = playerOf(src), playerOf(target)
    if not player or not victim then return end

    local function fail()
        exports.qbx_core:Notify(src, text.hostageFailed, 'error')
    end

    if hostageOf[src] or heldBy[src] or hostageOf[target] or IsHostageOrInTrunk(target) or trunkOf[src] then return fail() end
    if IsLeoAndOnDuty(player) or (hostageCfg.gangOnly and not isGang(src)) then return fail() end
    if player.PlayerData.metadata.ishandcuffed or isDown(src, player) then return fail() end
    if not holdsHostageWeapon(src) then return fail() end

    local ped, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if GetVehiclePedIsIn(ped, false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then return fail() end
    if GetEntityAttachedTo(targetPed) ~= 0 then return fail() end
    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > hostageCfg.maxDistance + 0.5 then return fail() end
    -- sandera harus angkat tangan atau sudah diikat, dan masih sadar
    if Player(target).state.canSteal ~= true or isDown(target, victim) then return fail() end

    hostageOf[src], heldBy[target] = target, src
    Player(target).state:set('hostage', true, true)
    TriggerClientEvent('f_police:client:hostageTaker', src, target)
    TriggerClientEvent('f_police:client:hostageVictim', target, src)
end)

RegisterNetEvent('f_police:server:hostageRelease', function()
    endHostage(source, 'release')
end)

RegisterNetEvent('f_police:server:hostageExecute', function()
    local src = source
    if not hostageOf[src] then return end
    endHostage(src, holdsHostageWeapon(src) and 'execute' or 'broken')
end)

-- penyandera melapor (mati, jatuh, senjata lepas); sandera hanya boleh melapor kalau dia pingsan/mati
RegisterNetEvent('f_police:server:hostageBroken', function()
    local src = source
    if hostageOf[src] then return endHostage(src, 'broken') end
    local taker = heldBy[src]
    if taker and isDown(src, playerOf(src)) then endHostage(taker, 'broken') end
end)

-- Bagasi ------------------------------------------------------------------------------------

local function plateOf(veh)
    return (GetVehicleNumberPlateText(veh) or ''):match('^%s*(.-)%s*$')
end

---@param victim integer
local function leaveTrunk(victim)
    local netId = trunkOf[victim]
    if not netId then return end
    trunkOf[victim] = nil

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and DoesEntityExist(veh) then
        Entity(veh).state:set('trunkVictim', nil, true)
        TriggerEvent('qb-trunk:server:setTrunkBusy', plateOf(veh), nil)
    end
end

---@param netId any
---@return integer? vehicle
local function vehicleFromNet(netId)
    netId = tonumber(netId)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    return veh
end

-- korban yang sedang digendong/diseret pelaku dimasukkan ke bagasi kendaraan
RegisterNetEvent('f_police:server:putInTrunk', function(netId, target)
    local src = source
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end

    local veh = vehicleFromNet(netId)
    if not veh or Entity(veh).state.trunkVictim then return end

    local ped, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then return end
    if GetEntityAttachedTo(targetPed) ~= ped then return end
    if IsHostageOrInTrunk(target) then return end

    local victim = playerOf(target)
    if not victim or not (victim.PlayerData.metadata.ishandcuffed or isDown(target, victim)) then return end

    netId = tonumber(netId)
    trunkOf[target] = netId
    Entity(veh).state:set('trunkVictim', target, true)
    TriggerEvent('qb-trunk:server:setTrunkBusy', plateOf(veh), true)
    TriggerClientEvent('f_police:client:enterTrunk', target, netId)
    TriggerClientEvent('f_police:client:trunkLoaded', src)
end)

-- siapa pun di dekat kendaraan (pelaku, polisi, warga) bisa mengeluarkan korban
RegisterNetEvent('f_police:server:takeOutTrunk', function(netId)
    local src = source
    local veh = vehicleFromNet(netId)
    if not veh then return end

    local victim = Entity(veh).state.trunkVictim
    if not victim or victim == src or trunkOf[victim] ~= tonumber(netId) then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 6.0 then return end

    leaveTrunk(victim)
    TriggerClientEvent('f_police:client:exitTrunk', victim)
end)

-- korban melapor dirinya sudah tidak di bagasi; diterima hanya kalau memang sudah jauh dari kendaraan
RegisterNetEvent('f_police:server:trunkGone', function()
    local src = source
    local netId = trunkOf[src]
    if not netId then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and DoesEntityExist(veh)
        and #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) < 8.0 then
        return
    end
    leaveTrunk(src)
end)

AddEventHandler('entityRemoved', function(entity)
    local victim = Entity(entity).state.trunkVictim
    if not victim or not trunkOf[victim] then return end
    trunkOf[victim] = nil
    TriggerClientEvent('f_police:client:exitTrunk', victim)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if hostageOf[src] then endHostage(src, 'broken') end
    if heldBy[src] then endHostage(heldBy[src], 'broken') end
    leaveTrunk(src)
    unlocking[src] = nil
end)
