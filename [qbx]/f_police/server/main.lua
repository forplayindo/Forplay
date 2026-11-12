local sharedConfig = require 'config.shared'
local cuffConfig = require 'config.criminal'.cuffs
local playerStatus = {}
local casings = {}
local bloodDrops = {}
local fingerDrops = {}
local updatingCops = false
-- f_prison (ex xt-prison) start SETELAH f_police ([standalone] di-ensure setelah [qbx]), jadi cek
-- "ada" bukan "sudah start"; kalau tidak, /jail lama + police:server:JailPlayer ikut terdaftar.
IsUsingXTPrison = GetResourceState('f_prison') ~= 'missing'

---@param player Player
---@param minGrade? integer
---@return boolean?
function IsLeoAndOnDuty(player, minGrade)
    local job = player.PlayerData.job
    if job and job.type == 'leo' and job.onduty then
        return job.grade.level >= (minGrade or 0)
    end
end

-- Functions

---The officer's callsign from the f_phone MDT (the single source of truth), falling back to
---their last name when the MDT is down or has not minted one yet.
---@param src integer
---@param playerData? table
---@return string
function GetCallsign(src, playerData)
    if GetResourceState('f_phone') == 'started' then
        local ok, callsign = pcall(function() return exports.f_phone:mdtGetCallsign(src) end)
        if ok and type(callsign) == 'string' and callsign ~= '' then return callsign end
    end
    playerData = playerData or exports.qbx_core:GetPlayer(src)?.PlayerData
    return playerData and playerData.charinfo.lastname or 'UNIT'
end

lib.callback.register('f_police:server:getCallsign', function(source)
    return GetCallsign(source)
end)

---@type table<integer, true> players who received duty blips last round
local blipReceivers = {}

---Positions of on-duty police/EMS, sent ONLY to on-duty police/EMS (never to everyone, so other
---players cannot read where the police are). Nothing is sent while nobody is on duty; players who
---went off duty get one empty update so their old blips are cleared.
local function updateBlips()
    local dutyPlayers, receivers = {}, {}
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local playerData = player.PlayerData
        local job = playerData.job
        if (job.type == 'leo' or job.type == 'ems') and job.onduty then
            local source = playerData.source
            local ped = GetPlayerPed(source)
            local coords = GetEntityCoords(ped)
            dutyPlayers[#dutyPlayers + 1] = {
                job = job.name,
                source = source,
                label = GetCallsign(source, playerData),
                location = vec4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
            }
            receivers[source] = true
        end
    end

    for source in pairs(receivers) do
        TriggerClientEvent('police:client:UpdateBlips', source, dutyPlayers)
    end
    for source in pairs(blipReceivers) do
        if not receivers[source] and GetPlayerName(source) then
            TriggerClientEvent('police:client:UpdateBlips', source, {})
        end
    end
    blipReceivers = receivers
end

local function generateId(table)
    local id = lib.string.random('11111')
    if not table then return id end
    while table[id] do
        id = lib.string.random('11111')
    end
    return id
end

RegisterNetEvent('police:server:SendTrackerLocation', function(coords, requestId)
    local target = exports.qbx_core:GetPlayer(source)
    local msg = locale('info.target_location', target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname)
    local alertData = {
        title = locale('info.anklet_location'),
        coords = coords,
        description = msg
    }
    TriggerClientEvent('police:client:TrackerMessage', requestId, msg, coords)
    TriggerClientEvent('qb-phone:client:addPoliceAlert', requestId, alertData)
end)

-- Items
exports.qbx_core:CreateUseableItem('handcuffs', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player.Functions.GetItemByName('handcuffs') then return end
    TriggerClientEvent('police:client:CuffPlayerSoft', source)
end)

exports.qbx_core:CreateUseableItem(cuffConfig.zipItem, function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player.Functions.GetItemByName(cuffConfig.zipItem) then return end
    TriggerClientEvent('police:client:ZipTiePlayer', source)
end)

exports.qbx_core:CreateUseableItem('moneybag', function(source, item)
    if not item.info or item.info == '' then return end
    local player = exports.qbx_core:GetPlayer(source)
    if not player
        or player.PlayerData.job.type == 'leo'
        or not player.Functions.GetItemByName('moneybag')
        or not player.Functions.RemoveItem('moneybag', 1, item.slot)
    then
        return
    end
    player.Functions.AddMoney('cash', tonumber(item.info.cash), 'used-moneybag')
end)

-- Callbacks
lib.callback.register('police:server:isPlayerDead', function(_, playerId)
    local player = exports.qbx_core:GetPlayer(playerId)
    return player.PlayerData.metadata.isdead
end)

lib.callback.register('police:GetPlayerStatus', function(_, targetSrc)
    local player = exports.qbx_core:GetPlayer(targetSrc)
    if not player or not next(playerStatus[targetSrc]) then return {} end
    local status = playerStatus[targetSrc]

    local statList = {}
    for _, statusData in pairs(status) do
        statList[#statList + 1] = statusData.text
    end

    return statList
end)

-- police garage / helipad models, so the spawn callback cannot be used to spawn anything else
local spawnableModels = {}
do
    local clientConfig = require 'config.client'
    for _, list in pairs(clientConfig.authorizedVehicles) do
        for model in pairs(list) do spawnableModels[model] = true end
    end
    for model in pairs(clientConfig.whitelistedVehicles) do spawnableModels[model] = true end
    spawnableModels[clientConfig.policeHelicopter] = true
end

---Spawn point is one of the station's garage or helipad spots.
local function nearPoliceSpawn(coords)
    if type(coords) ~= 'vector4' and type(coords) ~= 'vector3' then return false end
    local point = vec3(coords.x, coords.y, coords.z)
    for _, list in ipairs({ sharedConfig.locations.vehicle, sharedConfig.locations.helicopter }) do
        for i = 1, #list do
            if #(point - vec3(list[i].x, list[i].y, list[i].z)) < 10.0 then return true end
        end
    end
    return false
end

lib.callback.register('qbx_policejob:server:spawnVehicle', function(source, model, coords, plate, giveKeys)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not IsLeoAndOnDuty(player) then return end
    if not spawnableModels[model] or not nearPoliceSpawn(coords) then return end
    if #(GetEntityCoords(GetPlayerPed(source)) - vec3(coords.x, coords.y, coords.z)) > 15.0 then return end

    local netId, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        warp = GetPlayerPed(source)
    })

    if not netId or netId == 0 or not veh or veh == 0 then return end

    SetVehicleNumberPlateText(veh, tostring(plate):sub(1, 8))
    if giveKeys == true then exports.f_vehiclekeys:GiveKeys(source, veh) end

    return netId
end)

---Stolen / BOLO flags from the vehicle record in the f_phone MDT.
---@param plate string
---@return table? flags { stolen, bolo, ownerName, notes }
function PlateFlags(plate)
    if type(plate) ~= 'string' or GetResourceState('f_phone') ~= 'started' then return end
    local ok, vehicle = pcall(function() return exports.f_phone:mdtGetTrustedVehicle(plate) end)
    if not ok or type(vehicle) ~= 'table' then return end
    return { stolen = vehicle.stolen == true, bolo = vehicle.bolo == true, ownerName = vehicle.ownerName, notes = vehicle.notes }
end

local function isPlateFlagged(plate)
    local flags = PlateFlags(plate)
    return flags ~= nil and (flags.stolen or flags.bolo)
end

lib.callback.register('police:server:isPlateFlagged', function(_, plate)
    return isPlateFlagged(plate)
end)

---An on-duty officer of grade 2+ is in the city (robbery scripts gate on this).
local function isPoliceForcePresent()
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if IsLeoAndOnDuty(player, 2) then return true end
    end
    return false
end

lib.callback.register('f_police:server:isPoliceForcePresent', isPoliceForcePresent)

if GetConvar('qbx:enablebridge', 'true') == 'true' then
    local QBCore = exports['qb-core']:GetCoreObject()
    ---@deprecated use police:server:isPlateFlagged
    QBCore.Functions.CreateCallback('police:IsPlateFlagged', function(_, cb, plate)
        lib.print.warn(GetInvokingResource(),
            'invoked deprecated callback police:IsPlateFlagged. Use police:server:isPlateFlagged instead.')
        cb(isPlateFlagged(plate))
    end)

    ---@deprecated
    QBCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(_, cb)
        lib.print.warn(GetInvokingResource(),
            'invoked deprecated callback police:server:IsPoliceForcePresent. Use lib callback f_police:server:isPoliceForcePresent instead')
        cb(isPoliceForcePresent())
    end)
end

-- Events
RegisterNetEvent('police:server:Radar', function(fine)
    local src    = source
    local price  = sharedConfig.radars.speedFines[fine].fine
    local player = exports.qbx_core:GetPlayer(src)
    if not player.Functions.RemoveMoney('bank', math.floor(price), 'Radar Fine') then return end
    exports['f_banking']:addAccountMoney('police', price)
    exports.qbx_core:Notify(src, locale('info.fine_received', price), 'inform')
end)

---@type table<integer, integer> source -> GetGameTimer() of the last alert it sent
local lastAlert = {}
local ALERT_COOLDOWN = 10000 -- ms per player; robbery scripts send one alert per action

---Sends `text` to every on-duty officer from the position of the player who triggered it.
---Robbery scripts call it from the client, so client calls are rate limited per player and the text
---is capped: a cheater can no longer flood every officer with fake alerts. Server scripts may pass
---the player as the third argument and are not limited.
RegisterNetEvent('police:server:policeAlert', function(text, camId, playerSource)
    local fromClient = GetInvokingResource() == nil
    local src = fromClient and source or tonumber(playerSource) or tonumber(source)
    if not src or src <= 0 or not GetPlayerName(src) then return end

    if fromClient then
        local now = GetGameTimer()
        if lastAlert[src] and now - lastAlert[src] < ALERT_COOLDOWN then return end
        lastAlert[src] = now
    end

    text = type(text) == 'string' and text:gsub('[<>]', ''):sub(1, 120) or ''
    if text == '' then text = 'Laporan aktivitas mencurigakan' end
    camId = tonumber(camId)

    local coords = GetEntityCoords(GetPlayerPed(src))
    local players = exports.qbx_core:GetQBPlayers()
    for k, v in pairs(players) do
        if IsLeoAndOnDuty(v) then
            if camId then
                local alertData = {
                    title = locale('info.new_call'),
                    coords = coords,
                    description = text ..
                        locale('info.camera_id') .. camId
                }
                TriggerClientEvent('qb-phone:client:addPoliceAlert', k, alertData)
                TriggerClientEvent('police:client:policeAlert', k, coords, text, camId)
            else
                local alertData = { title = locale('info.new_call'), coords = coords, description = text }
                TriggerClientEvent('qb-phone:client:addPoliceAlert', k, alertData)
                TriggerClientEvent('police:client:policeAlert', k, coords, text)
            end
        end
    end
end)


local function isTargetTooFar(src, targetSrc, maxDistance)
    maxDistance = maxDistance or 2.5
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > maxDistance then
        return true
    end
end

---@type table<integer, integer> source -> os.time() until which the player may report themselves uncuffed
local uncuffAllowed = {}

---Lets a cuffed player's client report itself free for a short while: after a server-approved
---unlock, during the soft-cuff escape skill check, and around login/logout.
---@param src integer
---@param seconds? integer
function AllowUncuff(src, seconds)
    uncuffAllowed[src] = os.time() + (seconds or 10)
end

---Unlocks a cuffed player. The victim's client clears its own state and reports back.
---@param target integer
---@param by integer
function ReleaseCuffs(target, by)
    AllowUncuff(target)
    -- suara terdengar pemain di sekitar (xsound emulator interact-sound); ziptie dilepas tangan tidak berbunyi klik
    if Player(target).state.cuffType ~= 'zip' then
        TriggerClientEvent('InteractSound_CL:PlayWithinDistance', -1, target, 5.0, 'Uncuff', 0.3)
    end
    TriggerClientEvent('police:client:Uncuffed', target, by)
end

---Dipakai f_admin (borgol diri sendiri): lepas borgol lewat jalur resmi server.
exports('ReleaseCuffs', function(target)
    local player = exports.qbx_core:GetPlayer(tonumber(target) or -1)
    if not player or not player.PlayerData.metadata.ishandcuffed then return end
    ReleaseCuffs(player.PlayerData.source, player.PlayerData.source)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    AllowUncuff(player.PlayerData.source, 30)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    AllowUncuff(src, 30)
end)

---@param kind? 'zip'|'cuff' force an item (using it from the inventory); nil = handcuffs first, else zip ties
lib.callback.register('police:server:CuffPlayer', function(src, cuffedSrc, isSoftcuff, kind)
    if isTargetTooFar(src, cuffedSrc) then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local cuffedPlayer = exports.qbx_core:GetPlayer(cuffedSrc)
    if not cuffedPlayer or IsHostageOrInTrunk(cuffedSrc) then return end
    local isLeo = IsLeoAndOnDuty(player)

    if cuffedPlayer.PlayerData.metadata.ishandcuffed then
        -- officers carry the key; everyone else unlocks through the ox_target actions (lockpick, cutter, by hand)
        if not isLeo then return end
        ReleaseCuffs(cuffedSrc, src)
        return true
    end

    local hasCuffs = player.Functions.GetItemByName(cuffConfig.handcuffItem) ~= nil
    local hasZip = player.Functions.GetItemByName(cuffConfig.zipItem) ~= nil
    if kind ~= 'cuff' and kind ~= 'zip' then kind = hasCuffs and 'cuff' or 'zip' end
    local zip = kind == 'zip'
    if not (zip and hasZip or not zip and hasCuffs) then return end
    local item = zip and cuffConfig.zipItem or cuffConfig.handcuffItem

    -- only someone who has given up can be cuffed: hands up, tased, or down; non-police always soft cuff
    if not IsSubdued(cuffedSrc, cuffedPlayer) then return end
    if not isLeo then isSoftcuff = true end
    if zip and not player.Functions.RemoveItem(item, 1) then return end

    Player(cuffedSrc).state:set('cuffType', zip and 'zip' or 'cuff', true)
    TriggerClientEvent('InteractSound_CL:PlayWithinDistance', -1, cuffedSrc, 5.0, zip and 'ziptie' or 'Cuff', 0.3)
    if isSoftcuff then AllowUncuff(cuffedSrc, 15) end -- the one escape skill check
    TriggerClientEvent('police:client:GetCuffed', cuffedPlayer.PlayerData.source, player.PlayerData.source, isSoftcuff)

    return true
end)

RegisterNetEvent('police:server:EscortPlayer', function(escortSrc)
    local src = source
    if isTargetTooFar(src, escortSrc) or IsHostageOrInTrunk(escortSrc) then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local escortPlayer = exports.qbx_core:GetPlayer(escortSrc)
    if not escortPlayer then return end

    if (player.PlayerData.job.type == 'leo' or player.PlayerData.job.type == 'ems') or (escortPlayer.PlayerData.metadata.ishandcuffed or escortPlayer.PlayerData.metadata.isdead or escortPlayer.PlayerData.metadata.inlaststand) then
        TriggerClientEvent('police:client:GetEscorted', escortPlayer.PlayerData.source, player.PlayerData.source)
    else
        exports.qbx_core:Notify(src, locale('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:KidnapPlayer', function(kidnapedSrc)
    local src = source
    if isTargetTooFar(src, kidnapedSrc) or IsHostageOrInTrunk(kidnapedSrc) then return end
    local player = exports.qbx_core:GetPlayer(source)
    local escortPlayer = exports.qbx_core:GetPlayer(kidnapedSrc)
    if not player or not escortPlayer then return end

    if escortPlayer.PlayerData.metadata.ishandcuffed or escortPlayer.PlayerData.metadata.isdead or escortPlayer.PlayerData.metadata.inlaststand then
        TriggerClientEvent('police:client:GetKidnappedTarget', escortPlayer.PlayerData.source, player.PlayerData.source)
        TriggerClientEvent('police:client:GetKidnappedDragger', player.PlayerData.source, escortPlayer.PlayerData.source)
    else
        exports.qbx_core:Notify(src, locale('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(targetSrc)
    local src = source
    -- target sits inside the vehicle, so allow reaching across it
    if isTargetTooFar(src, targetSrc, 5.0) then return end

    local escortPlayer = exports.qbx_core:GetPlayer(targetSrc)
    if not escortPlayer then return end
    local metadata = escortPlayer.PlayerData.metadata
    if not (metadata.ishandcuffed or metadata.isdead or metadata.inlaststand) then
        return exports.qbx_core:Notify(src, locale('error.not_cuffed_dead'), 'error')
    end

    TriggerClientEvent('police:client:SetOutVehicle', escortPlayer.PlayerData.source)
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(targetSrc)
    local src = source
    if isTargetTooFar(src, targetSrc) or IsHostageOrInTrunk(targetSrc) then return end

    local escortPlayer = exports.qbx_core:GetPlayer(targetSrc)
    if not escortPlayer then return end
    local metadata = escortPlayer.PlayerData.metadata

    if not (metadata.ishandcuffed or metadata.isdead or metadata.inlaststand) then
        return exports.qbx_core:Notify(src, locale('error.not_cuffed_dead'), 'error')
    end

    TriggerClientEvent('police:client:PutInVehicle', escortPlayer.PlayerData.source)
end)

RegisterNetEvent('police:server:BillPlayer', function(targetSrc, price)
    local src = source
    if isTargetTooFar(src, targetSrc) then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or player.PlayerData.job.type ~= 'leo' then return end
    local targetPlayer = exports.qbx_core:GetPlayer(targetSrc)
    if not targetPlayer then return end

    if not targetPlayer.Functions.RemoveMoney('bank', price, 'paid-bills') then return end
    exports['f_banking']:addAccountMoney('police', price)
    exports.qbx_core:Notify(targetPlayer.PlayerData.source, locale('info.fine_received', price), 'inform')
end)

if not IsUsingXTPrison then
    RegisterNetEvent('police:server:JailPlayer', function(targetSrc, time)
        local src = source
        if isTargetTooFar(src, targetSrc) then return end

        local player = exports.qbx_core:GetPlayer(src)
        if not player or player.PlayerData.job.type ~= 'leo' then return end
        local targetPlayer = exports.qbx_core:GetPlayer(targetSrc)
        if not targetPlayer then return end

        local currentDate = os.date('*t')
        if currentDate.day == 31 then
            currentDate.day = 30
        end

        targetPlayer.Functions.SetMetaData('injail', time)
        targetPlayer.Functions.SetMetaData('criminalrecord', {
            hasRecord = true,
            date = currentDate
        })
        if GetResourceState('qbx_prison') == 'started' then
            exports.qbx_prison:JailPlayer(targetPlayer.PlayerData.source, time)
        else
            TriggerClientEvent('police:client:SendToJail', targetPlayer.PlayerData.source, time)
        end
        exports.qbx_core:Notify(src, locale('info.sent_jail_for', time), 'inform')
    end)
end

RegisterNetEvent('police:server:SetHandcuffStatus', function(isHandcuffed)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    isHandcuffed = isHandcuffed == true

    -- a cuffed client may only free itself when the server allowed it
    if not isHandcuffed and player.PlayerData.metadata.ishandcuffed then
        if (uncuffAllowed[src] or 0) < os.time() then return end
        uncuffAllowed[src] = nil
    end

    player.Functions.SetMetaData('ishandcuffed', isHandcuffed)
    local state = Player(src).state
    state.invBusy = isHandcuffed
    state:set('cuffed', isHandcuffed, true)
    if not isHandcuffed then state:set('cuffType', nil, true) end
end)

AddEventHandler('playerDropped', function()
    uncuffAllowed[source] = nil
    lastAlert[source] = nil
end)

RegisterNetEvent('heli:spotlight', function(state)
    TriggerClientEvent('heli:spotlight', -1, source, state)
end)

-- speed camera saw a flagged plate (radars are off in config.client; kept for when they return)
RegisterNetEvent('police:server:FlaggedPlateTriggered', function(radar, plate, street)
    local src = source
    local now = GetGameTimer()
    if lastAlert[src] and now - lastAlert[src] < ALERT_COOLDOWN then return end
    if type(plate) ~= 'string' or not isPlateFlagged(plate) then return end
    lastAlert[src] = now

    radar = tonumber(radar) or 0
    street = type(street) == 'string' and street:gsub('[<>]', ''):sub(1, 80) or ''
    local coords = GetEntityCoords(GetPlayerPed(src))
    for id, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if IsLeoAndOnDuty(player) then
            TriggerClientEvent('qb-phone:client:addPoliceAlert', id, {
                title = locale('info.new_call'),
                coords = coords,
                description = locale('info.plate_triggered', plate, street, radar),
            })
            TriggerClientEvent('police:client:policeAlert', id, coords, locale('info.plate_triggered_blip', radar))
        end
    end
end)

RegisterNetEvent('police:server:SearchPlayer', function(targetSrc)
    local src = source
    if isTargetTooFar(src, targetSrc) then return end

    local targetPlayer = exports.qbx_core:GetPlayer(targetSrc)
    if not targetPlayer then return end

    exports.qbx_core:Notify(src, locale('info.searched_success'), 'inform')
    exports.qbx_core:Notify(targetPlayer.PlayerData.source, locale('info.being_searched'), 'inform')
end)

-- /seizecash removed: police take cash while searching (Geledah), logged to the MDT. The moneybag
-- item stays usable so bags already handed out can still be opened.

-- Vehicle seizure is the Administrasi panel (server/police.lua f_police:server:seizeVehicle);
-- release only through redemption at the police counter (f_cityhall).

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    playerStatus[source] = data
end)

---A character's DNA code: random, stored in metadata on first use. It does not reveal who it is;
---only the forensic lab (server/lab.lua) maps it back to a person.
---@param player table qbx player
---@return string
function DnaCode(player)
    local code = player.PlayerData.metadata.dnacode
    if type(code) == 'string' and code ~= '' then return code end
    code = 'DNA-' .. lib.string.random('........'):upper()
    player.Functions.SetMetaData('dnacode', code)
    return code
end

local function evidenceCoords(src, coords)
    local pos = GetEntityCoords(GetPlayerPed(src))
    if type(coords) == 'vector3' and #(coords - pos) < 10.0 then return coords end
    return pos
end

---Officer on duty standing next to a piece of evidence on the ground.
local function canCollect(src, coords)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not IsLeoAndOnDuty(player) then return end
    if not coords or #(GetEntityCoords(GetPlayerPed(src)) - coords) > 4.0 then return end
    return player
end

---Structured bag metadata the lab reads, plus a readable description for the inventory tooltip.
local function evidenceMeta(player, kind, data, street)
    local name = ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
    street = type(street) == 'string' and street:sub(1, 80) or '-'
    local lines = {}
    if kind == 'fingerprint' then
        lines[#lines + 1] = 'Sidik Jari: ' .. data.fingerprint
    else
        lines[#lines + 1] = 'DNA: ' .. data.dna
        if data.bloodtype then lines[#lines + 1] = 'Golongan darah: ' .. data.bloodtype end
    end
    lines[#lines + 1] = 'Diambil oleh: ' .. name
    lines[#lines + 1] = 'Lokasi: ' .. street
    lines[#lines + 1] = 'Waktu: ' .. os.date('%d-%m-%Y %H:%M')
    return {
        type = kind == 'fingerprint' and 'Bukti Sidik Jari' or kind == 'sample' and 'Sampel DNA' or 'Bukti Darah',
        evidence = kind == 'fingerprint' and 'fingerprint' or 'dna',
        dna = data.dna, fingerprint = data.fingerprint, bloodtype = data.bloodtype,
        street = street, collectedBy = name, collectedAt = os.time(),
        description = table.concat(lines, '\n\n'),
    }
end
EvidenceMeta = evidenceMeta

-- the bleeding player's client reports its own blood; identity is read on the server, never sent
RegisterNetEvent('evidence:server:CreateBloodDrop', function(_, _, coords)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    coords = evidenceCoords(src, coords)
    local bloodId = generateId(bloodDrops)
    local dna = DnaCode(player)
    local bloodtype = player.PlayerData.metadata.bloodtype
    bloodDrops[bloodId] = { dna = dna, bloodtype = bloodtype, coords = coords }
    TriggerClientEvent('evidence:client:AddBlooddrop', -1, bloodId, dna, bloodtype, coords)
end)

RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    coords = evidenceCoords(src, coords)
    local fingerId = generateId(fingerDrops)
    fingerDrops[fingerId] = { fingerprint = player.PlayerData.metadata.fingerprint, coords = coords }
    TriggerClientEvent('evidence:client:AddFingerPrint', -1, fingerId, nil, coords)
end)

RegisterNetEvent('evidence:server:ClearBlooddrops', function(bloodDropList)
    if not bloodDropList or not next(bloodDropList) then return end
    for _, v in pairs(bloodDropList) do
        TriggerClientEvent('evidence:client:RemoveBlooddrop', -1, v)
        bloodDrops[v] = nil
    end
end)

-- DNA / bloodtype / fingerprint come from the server copy of the drop, not from the client
RegisterNetEvent('evidence:server:AddBlooddropToInventory', function(bloodId, bloodInfo)
    local src = source
    local drop = bloodDrops[bloodId]
    local player = drop and canCollect(src, drop.coords)
    if not player then return end
    if not exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(src, locale('error.have_evidence_bag'), 'error')
    end
    local metadata = evidenceMeta(player, 'blood', drop, type(bloodInfo) == 'table' and bloodInfo.street)
    if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
        TriggerClientEvent('evidence:client:RemoveBlooddrop', -1, bloodId)
        bloodDrops[bloodId] = nil
    end
end)

RegisterNetEvent('evidence:server:AddFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local drop = fingerDrops[fingerId]
    local player = drop and canCollect(src, drop.coords)
    if not player then return end
    if not exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(src, locale('error.have_evidence_bag'), 'error')
    end
    local metadata = evidenceMeta(player, 'fingerprint', drop, type(fingerInfo) == 'table' and fingerInfo.street)
    if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
        TriggerClientEvent('evidence:client:RemoveFingerprint', -1, fingerId)
        fingerDrops[fingerId] = nil
    end
end)

RegisterNetEvent('evidence:server:CreateCasing', function(weapon, serial, coords)
    local casingId = generateId(casings)
    local serieNumber = exports.ox_inventory:GetCurrentWeapon(source).metadata.serial
    if not serieNumber then
        serieNumber = serial
    end
    TriggerClientEvent('evidence:client:AddCasing', -1, casingId, weapon, coords, serieNumber)
end)

---Broadcasts the on-duty officer count. Clients ask for it on login and duty toggle; coalesced so
---a burst of requests sends one update.
RegisterNetEvent('police:server:UpdateCurrentCops', function()
    if updatingCops then return end
    updatingCops = true
    SetTimeout(1000, function()
        TriggerClientEvent('police:SetCopCount', -1, exports.qbx_core:GetDutyCountType('leo'))
        updatingCops = false
    end)
end)

RegisterNetEvent('evidence:server:ClearCasings', function(casingList)
    if casingList and next(casingList) then
        for _, v in pairs(casingList) do
            TriggerClientEvent('evidence:client:RemoveCasing', -1, v)
            casings[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddCasingToInventory', function(casingId, casingInfo)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    local streetName = casingInfo.street
    local ammoType = casingInfo.ammolabel
    local serialNumber = casingInfo.serie
    local metadata = {}
    metadata.type = locale('info.casing')
    metadata.description = 'Jenis Amunisi: ' .. ammoType
    metadata.description = metadata.description .. '\n\nNomor Seri: ' .. serialNumber
    metadata.description = metadata.description .. '\n\nDiambil oleh: ' .. playerName
    metadata.description = metadata.description .. '\n\nLokasi: ' .. streetName
    if not exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(src, locale('error.have_evidence_bag'), 'error')
    end
    if exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1, metadata) then
        TriggerClientEvent('evidence:client:RemoveCasing', -1, casingId)
        casings[casingId] = nil
    end
end)

RegisterNetEvent('police:server:SetTracker', function(targetId)
    local src = source
    if isTargetTooFar(src, targetId) then return end

    local player, target = exports.qbx_core:GetPlayer(src), exports.qbx_core:GetPlayer(targetId)
    if not player or not target or not IsLeoAndOnDuty(player) then return end
    if not target.PlayerData.metadata.ishandcuffed then
        return exports.qbx_core:Notify(src, locale('error.not_cuffed_dead'), 'error')
    end

    local trackerMeta = target.PlayerData.metadata.tracker
    if trackerMeta then
        target.Functions.SetMetaData('tracker', false)
        exports.qbx_core:Notify(targetId, locale('success.anklet_taken_off'), 'success')
        exports.qbx_core:Notify(src,
            locale('success.took_anklet_from', target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname),
            'success')
        TriggerClientEvent('police:client:SetTracker', targetId, false)
    else
        target.Functions.SetMetaData('tracker', true)
        exports.qbx_core:Notify(targetId, locale('success.put_anklet'), 'success')
        exports.qbx_core:Notify(src,
            locale('success.put_anklet_on', target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname),
            'success')
        TriggerClientEvent('police:client:SetTracker', targetId, true)
    end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource ~= 'ox_inventory' then return end

    local jobs = {}
    for k, v in pairs(exports.qbx_core:GetJobs()) do
        if v.type == 'leo' then
            jobs[k] = 0
        end
    end

    for i = 1, #sharedConfig.locations.trash do
        exports.ox_inventory:RegisterStash(('policetrash_%s'):format(i), 'Police Trash', 300, 4000000, nil, jobs,
            sharedConfig.locations.trash[i])
    end
    -- 'policelocker' dikelola f_stash (/stash)
end)

-- Threads
CreateThread(function()
    Wait(1000)
    for i = 1, #sharedConfig.locations.trash do
        exports.ox_inventory:ClearInventory(('policetrash_%s'):format(i))
    end
    while true do
        Wait(1000 * 60 * 10)
        local curCops = exports.qbx_core:GetDutyCountType('leo')
        TriggerClientEvent('police:SetCopCount', -1, curCops)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        updateBlips()
    end
end)
