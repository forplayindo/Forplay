if not lib then return end

local db = require(('bridge.%s.owned_vehicles'):format(Shared.framework))
local Framework = require(('bridge.%s.server'):format(Shared.framework))
local GaragesData = lib.load 'config.garages'
local utils = require 'server.functions'
local Interior = lib.load 'config.interior'
local Garages = {}
local PlayerVehicles = {}
local ClassList = lib.load 'config.impound'.ImpoundPrices
lib.locale()


-- The database table keeps its original name `mh_garage` (this resource was renamed from mh_garage):
-- it holds every purchased garage, renaming it would make them look lost.
MySQL.ready(function()

    local oldTableExists = pcall(MySQL.scalar.await, 'SELECT 1 FROM `uniq_garage`')
    if oldTableExists then
        MySQL.query('RENAME TABLE `uniq_garage` TO `mh_garage`')
        Wait(200)
    end

    local success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM `mh_garage`')

    if not success then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `mh_garage` (
                `owner` varchar(60) DEFAULT NULL,
                `name` varchar(100) NOT NULL,
                `data` longtext DEFAULT NULL,
                UNIQUE KEY `owner` (`owner`,`name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
        ]])

        print('^2[success]^7 database was created successfully!')
    end

    Wait(0)

    result = MySQL.query.await('SELECT * FROM `mh_garage`')

    if result[1] then
        for k,v in pairs(result) do
            local data = json.decode(v.data)

            if not Garages[v.owner] then
                Garages[v.owner] = {}
            end

            Garages[v.owner][v.name] = data
        end
    end
end)


lib.callback.register('f_vipgarage:cb:DoesOwn', function(source, garage)
    local identifier = Framework.GetIdentifier(source)

    if not Garages[identifier] then
        return false
    end

    return Garages[identifier][garage]
end)


-------------------------------
---- Admin garage activation ----
-------------------------------
-- Players cannot buy garages (there is no buy event anymore). The purchase is roleplayed and an
-- admin standing at the garage entrance activates it for a player standing next to them.

local AdminConfig = lib.load 'config.server'.Admin

---@param source integer
---@return boolean
local function isAdmin(source)
    return IsPlayerAceAllowed(tostring(source), AdminConfig.ace)
end

lib.callback.register('f_vipgarage:cb:IsAdmin', function(source)
    return isAdmin(source)
end)

---@type table<integer, {garage: string, players: table<integer, true>}> activation list an admin opened
local PendingGrants = {}

---@param source integer
---@param garage string
---@return boolean
local function isAdminAtGarage(source, garage)
    local coords = GetEntityCoords(GetPlayerPed(source))
    return #(coords - GaragesData[garage].enter) <= AdminConfig.atGarageDistance
end

lib.callback.register('f_vipgarage:cb:GetGrantCandidates', function(source, garage)
    if not isAdmin(source) or type(garage) ~= 'string' or not GaragesData[garage] then return end

    if not isAdminAtGarage(source, garage) then
        return false, 'admin_not_at_garage'
    end

    -- includes the admin, so an admin can also activate a garage for themselves
    local players = lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), AdminConfig.playerDistance)
    local options = {}
    local allowed = {}

    for i = 1, #players do
        local id = tonumber(players[i].id)
        if id then
            options[#options + 1] = { label = ('%s (%s)'):format(Framework.GetName(id), id), value = id }
            allowed[id] = true
        end
    end

    if #options == 0 then
        return false, 'admin_no_player_nearby'
    end

    -- the activation that follows is only accepted for these players and this garage
    PendingGrants[source] = { garage = garage, players = allowed }
    return options
end)

RegisterNetEvent('f_vipgarage:server:GrantGarage', function(target)
    local src = source
    local grant = PendingGrants[src]
    PendingGrants[src] = nil
    target = tonumber(target)

    if not grant or not target or not grant.players[target] or not isAdmin(src) then return end

    local garage = grant.garage
    if not isAdminAtGarage(src, garage) then return end

    -- the player must still be next to the admin
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target)))
    if distance > AdminConfig.playerDistance then
        TriggerClientEvent('f_vipgarage:Notify', src, locale('admin_no_player_nearby'), 'error')
        return
    end

    local identifier = Framework.GetIdentifier(target)
    if not identifier then return end
    local targetName = Framework.GetName(target)

    if Garages[identifier] and Garages[identifier][garage] then
        TriggerClientEvent('f_vipgarage:Notify', src, locale('admin_already_owns', targetName), 'error')
        return
    end

    local interior = GaragesData[garage].interior
    Garages[identifier] = Garages[identifier] or {}
    Garages[identifier][garage] = {
        name = garage,
        style = Interior[interior].Customization and Interior[interior].Customization.Default or {},
        slot = {},
    }

    MySQL.insert('INSERT INTO `mh_garage` (owner, name, data) VALUES (?, ?, ?)', { identifier, garage, json.encode(Garages[identifier][garage]) })

    TriggerClientEvent('f_vipgarage:Notify', src, locale('admin_activated', targetName, garage), 'success')
    TriggerClientEvent('f_vipgarage:Notify', target, locale('garage_activated', garage), 'success')
end)

AddEventHandler('playerDropped', function()
    PendingGrants[source] = nil
end)

lib.callback.register('f_vipgarage:cb:BuyCustomization', function(source, data)
    local identifier = Framework.GetIdentifier(source)
    local playerGarage = Garages[identifier] and Garages[identifier][data.garage]

    if not playerGarage then return false end

    local floorStyles = playerGarage.style[data.floor]

    for _, style in ipairs(floorStyles) do
        if data.interior.color then
            if style.name == data.interior.name and tonumber(style.color) == tonumber(data.color) then
                TriggerClientEvent('f_vipgarage:Notify', source, locale('have_customization'), 'error')
                return false
            end
        elseif style.name == data.interior.name then
            TriggerClientEvent('f_vipgarage:Notify', source, locale('have_customization'), 'error')
            return false
        end
    end

    local price
    for _, category in pairs(Interior[data.int].Customization.Purchasable) do
        for _, item in pairs(category) do
            if item.label == data.interior.label then
                price = item.price
                break
            end
        end
        if price then break end
    end

    if not price or type(price) ~= "number" then return false end

    if utils.PayPrice(source, price) then
        local found = false

        for _, style in ipairs(floorStyles) do
            if style.type == data.interior.type then
                style.name = data.interior.name
                if data.interior.color then style.color = data.color end
                found = true
                break
            end
        end

        if not found then
            floorStyles[#floorStyles + 1] = {
                name = data.interior.name,
                color = data.interior.color and data.color or nil,
                type = data.interior.type
            }
        end

        return true
    else
        TriggerClientEvent('f_vipgarage:Notify', source, locale('no_money'), 'error')
    end

    return false
end)


local function isSlotFree(name, identifier)
    if not GaragesData[name] or not Garages[identifier][name].slot then
        return false, false
    end

    local maxFloors = #Interior[GaragesData[name].interior].Vehicles or 1

    for floor = 1, maxFloors do
        if not Garages[identifier][name].slot[floor] then
            Garages[identifier][name].slot[floor] = {}
        end

        for slot = 1, #Interior[GaragesData[name].interior].Vehicles[floor] do
            if not Garages[identifier][name].slot[floor][slot] then
                return floor, slot
            end
        end
    end

    return false, false
end

local function FindSlotByPlate(name, identifier, plate)
    if not GaragesData[name] or not Garages[identifier][name].slot then
        return false, false
    end

    local maxFloors = #Interior[GaragesData[name].interior].Vehicles or 1

    for floor = 1, maxFloors do
        if Garages[identifier][name].slot[floor] then
            for slot = 1, #Interior[GaragesData[name].interior].Vehicles[floor] do
                if Garages[identifier][name].slot[floor][slot] and Garages[identifier][name].slot[floor][slot] == plate then
                    return floor, slot
                end
            end
        end
    end

    return false, false
end


lib.callback.register('f_vipgarage:cb:CheckSpawnPoint', function(source, name, plate)
    if #lib.getNearbyVehicles(GaragesData[name].vehicleSpawnPoint.xyz, 3.0, false) > 0 then
        return false
    end

    return true
end)


---@type table<integer, {plate: string, time: integer}> vehicle a player just took out, waiting for its entity
local PendingTakeOut = {}

RegisterNetEvent('f_vipgarage:server:TakeVehicleOut', function(name, plate)
    plate = string.strtrim(plate)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    local floor, slot = FindSlotByPlate(name, identifier, plate)

    if not floor or not slot then return end

    if Garages[identifier][name].slot[floor] and Garages[identifier][name].slot[floor][slot] then
        SetPlayerRoutingBucket(src, 0)
        Framework.ClearMeta(src, 'garage', nil)
        PendingTakeOut[src] = { plate = plate, time = os.time() }

        TriggerClientEvent('f_vipgarage:client:TakeVehicleOut', src, name, PlayerVehicles[identifier][name][plate])

        Garages[identifier][name].slot[floor][slot] = nil
        PlayerVehicles[identifier][name][plate] = nil
        db.UpdateStored(plate, identifier, 0)
    end
end)

lib.callback.register('f_vipgarage:cb:HasMoney', function(source, class)
    local price = ClassList[class] or 100

    return utils.PayPrice(source, price)
end)


RegisterNetEvent('f_vipgarage:server:UpdateBucket', function()
    local src = source
    SetPlayerRoutingBucket(src, src)
end)


lib.callback.register('f_vipgarage:cb:CanStore', function(source, garage, plate, class, properties)
    if GaragesData[garage] then
        local identifier = Framework.GetIdentifier(source)
        plate = string.strtrim(plate)

        if lib.table.contains(GaragesData[garage].blackListClass, class) then
            return false, 'cant_store_here'
        end

        if not Garages[identifier] or not Garages[identifier][garage] then
            return false, 'doesnt_own'
        end

        local owner = db.GetVehicleOwner(plate)

        if not owner then
            return false, 'doesnt_own2'
        end

        if owner == identifier then
            local floor, slot = isSlotFree(garage, identifier)

            if type(slot) == "number" then
                -- modif & tampilan dari database (server), dari client hanya kondisi (bensin, kerusakan)
                if GetResourceState('f_vehicles') == 'started' then
                    local vehicleId = exports.f_vehicles:GetVehicleIdByPlate(plate)
                    properties = vehicleId and exports.f_vehicles:MergeClientProps(vehicleId, properties)
                    if not properties then return false, 'something_wrong' end
                end

                Garages[identifier][garage].slot[floor][slot] = plate

                local cb = db.StoreVehicle(plate, garage, properties, GaragesData[garage].type)

                return cb > 0
            else
                return false, 'garage_full'
            end
        end
    else
        return false, 'something_wrong'
    end
end)


lib.callback.register('f_vipgarage:cb:GetImpoundList', function(source, index)
    local identifier = Framework.GetIdentifier(source)
    local vehicles = db.GetImpoundList(index, identifier)

    return vehicles
end)


lib.callback.register('f_vipgarage:cb:GetStyle', function(source, garage, floor)
    local identifier = Framework.GetIdentifier(source)

    return Garages[identifier][garage].style?[floor] or {}
end)


lib.callback.register('f_vipgarage:cb:GetGarageVehicles', function(source, garage, floor)
    local identifier = Framework.GetIdentifier(source)

    if Garages[identifier][garage] then
        if not PlayerVehicles[identifier] then
            PlayerVehicles[identifier] = {}
        end

        if not PlayerVehicles[identifier][garage] then
            PlayerVehicles[identifier][garage] = {}
        end

        local vehicles = db.GetPlayerVehicles(identifier, garage)

        for plate, mods in pairs(vehicles) do
            PlayerVehicles[identifier][garage][plate] = mods
        end

        return PlayerVehicles[identifier][garage], Garages[identifier][garage].slot[floor]
    end
end)


RegisterNetEvent('f_vipgarage:server:EnterGarage', function(garage, floor, inPreview)
    local playerId = source

    SetPlayerRoutingBucket(playerId, playerId)
    Framework.SetMetadata(playerId, 'garage', { garage = garage, floor = floor, inPreview = inPreview == true or nil })
end)


RegisterNetEvent('f_vipgarage:server:ExitGarage', function(garage)
    local playerId = source

    SetPlayerRoutingBucket(playerId, 0)
    Framework.ClearMeta(playerId, 'garage', nil)
end)

RegisterNetEvent('f_vipgarage:server:Orphan', function(id)
    local src = source
    if type(id) ~= 'number' then return end

    -- the vehicle is created by the client, the server may not know the entity yet
    local ent = NetworkGetEntityFromNetworkId(id)
    local timeout = GetGameTimer() + 2000
    while (ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < timeout do
        Wait(100)
        ent = NetworkGetEntityFromNetworkId(id)
    end
    if ent == 0 then return end

    SetEntityOrphanMode(ent, 2)

    -- The vehicle is spawned by the client, so mark it as the player's owned vehicle here: only for
    -- the plate this player just took out of their garage, and only once. This makes the key system
    -- (f_vehiclekeys: physical key, remote, security) treat it like any other owned vehicle.
    local pending = PendingTakeOut[src]
    PendingTakeOut[src] = nil
    if not pending or os.time() - pending.time > 30 then return end
    if ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then return end
    if string.strtrim(GetVehicleNumberPlateText(ent)) ~= pending.plate then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(ent)) > 15.0 then return end

    local vehicleId = GetResourceState('f_vehicles') == 'started' and exports.f_vehicles:GetVehicleIdByPlate(pending.plate)
    if vehicleId then
        Entity(ent).state:set('vehicleid', vehicleId, false)
        TriggerEvent('f_garages:server:vehicleSpawned', ent)
        -- kendaraan dibuat client; pasang ulang modif dari database supaya pasti sama
        exports.f_vehicles:EnsureAppearance(ent, vehicleId, 500)
    end
end)

AddEventHandler('playerDropped', function()
    PendingTakeOut[source] = nil
end)


local function saveToDB()
    local insertTable = {}
    local query = 'UPDATE `mh_garage` SET `data` = ? WHERE `owner` = ? AND `name` = ?'

    for owner, garages in pairs(Garages) do
        for name, garageData in pairs(garages) do
            insertTable[#insertTable + 1] = { query = query, values = { json.encode(garageData), owner, name } }
        end
    end

    if #insertTable > 0 then
        local success, response = pcall(MySQL.transaction, insertTable)

        if not success then print(response) end
    end
end


exports('DoesPlayerOwnGarage', function(identifier)
    return Garages[identifier]
end)


SetInterval(saveToDB, 600000)


---@type table<integer, {garage: string, floor: integer, players: table<integer, true>}> invite menu the owner opened
local PendingInvites = {}

---Validates the owner and shows them the players standing at the garage entrance.
---Used by the invite marker inside the garage (and the optional command).
---@param source integer
local function openInviteMenu(source)
    local data = lib.callback.await('f_vipgarage:cb:GetGarageClient', source)

    if not data or not data.garage or not data.floor or data.floor == 'exit' then
        TriggerClientEvent('f_vipgarage:Notify', source, locale('only_in_garage'), 'error')
        return
    end

    if data.preview then
        TriggerClientEvent('f_vipgarage:Notify', source, locale('not_in_preview'), 'error')
        return
    end

    local identifier = Framework.GetIdentifier(source)

    if not GaragesData[data.garage] or not Garages[identifier] or not Garages[identifier][data.garage] then
        TriggerClientEvent('f_vipgarage:Notify', source, locale('not_your_garage'), 'error')
        return
    end

    local players = lib.getNearbyPlayers(GaragesData[data.garage].enter, 10.0, false)

    if #players == 0 then
        TriggerClientEvent('f_vipgarage:Notify', source, locale('no_player_nearby'), 'error')
        return
    end

    local options = {}
    local allowed = {}

    for i = 1, #players do
        options[i] = { label = Framework.GetName(players[i].id), value = players[i].id }
        allowed[players[i].id] = true
    end

    -- the invite that follows is only accepted for these players and this garage/floor
    PendingInvites[source] = { garage = data.garage, floor = data.floor, players = allowed }
    TriggerClientEvent('f_vipgarage:client:InvitePlayer', source, options, { garage = data.garage, floor = data.floor })
end

RegisterNetEvent('f_vipgarage:server:RequestInvite', function()
    openInviteMenu(source)
end)

local Commands = lib.load 'config.server'.Commands

if Commands.invite.enable then
    lib.addCommand(Commands.invite.name, {
        help = Commands.invite.help,
        restricted = false
    }, function(source)
        openInviteMenu(source)
    end)
end

RegisterNetEvent('f_vipgarage:server:InvitePlayer', function(target)
    local src = source
    local invite = PendingInvites[src]
    PendingInvites[src] = nil
    target = tonumber(target)

    -- only a player from the list the server showed, into the garage the server recorded
    if not invite or not target or not invite.players[target] then return end

    local identifier = Framework.GetIdentifier(src)
    local garage = Garages[identifier] and Garages[identifier][invite.garage]
    if not garage then return end

    local inviter = Framework.GetName(src)
    local cb = lib.callback.await('f_vipgarage:cb:SendInvite', target, inviter)

    if cb ~= 'confirm' then
        TriggerClientEvent('f_vipgarage:Notify', src, locale('declined_invite'), 'info')
        return
    end

    local data = { garage = invite.garage, floor = invite.floor }
    SetPlayerRoutingBucket(target, src)
    TriggerClientEvent('f_vipgarage:client:TeleportPlayer', target, garage.style?[invite.floor] or {}, data)
end)

AddEventHandler('playerDropped', function()
    PendingInvites[source] = nil
end)

RegisterNetEvent('f_vipgarage:server:TeleportOut', function(name)
    local src = source
    if not GaragesData[name] then return end
    local ped = GetPlayerPed(src)
    local coords = GaragesData[name].enter

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetPlayerRoutingBucket(src, 0)
end)


AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then saveToDB() end
end)


AddEventHandler('txAdmin:events:serverShuttingDown', function()
	saveToDB()
end)


AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end

	saveToDB()
end)


AddEventHandler('playerDropped', function()
	if GetNumPlayerIndices() == 0 then
		saveToDB()
	end
end)
