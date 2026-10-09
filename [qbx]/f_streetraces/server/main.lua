local Races = {}

-- f_dirtymoney: bagian kotor dari uang daftar dicatat per peserta, pot/refund tetap kotor
local function dirtyPart(src, amount)
    if GetResourceState('f_dirtymoney') ~= 'started' then return 0 end
    return math.min(amount, exports.f_dirtymoney:GetDirty(src))
end

local function markDirty(src, amount, reason)
    if (amount or 0) > 0 and GetResourceState('f_dirtymoney') == 'started' then
        exports.f_dirtymoney:AddDirty(src, amount, reason)
    end
end

local function GetCreatedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and Races[key].creator == identifier and not Races[key].started then
            return key
        end
    end
    return 0
end

local function RemoveFromRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for i, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    table.remove(Races[key].joined, i)
                end
            end
        end
    end
end

local function CancelRace(source)
    local RaceId = GetCreatedRace(GetPlayerIdentifierByType(source, 'license'))
    local Player = exports.qbx_core:GetPlayer(source)

    if RaceId ~= 0 then
        for key in pairs(Races) do
            if Races[key] ~= nil and Races[key].creator == Player.PlayerData.license then
                if not Races[key].started then
                    for _, iden in pairs(Races[key].joined) do
                        local xdPlayer = exports.qbx_core:GetPlayer(iden)
                            xdPlayer.Functions.AddMoney('cash', Races[key].amount, "race-cancelled")
                            markDirty(xdPlayer.PlayerData.source, Races[key].dirty and Races[key].dirty[iden], "race-cancelled")
                            exports.qbx_core:Notify(xdPlayer.PlayerData.source, "Balapan dihentikan, uangmu Rp "..Races[key].amount.." dikembalikan", 'error')
                            TriggerClientEvent('qb-streetraces:StopRace', xdPlayer.PlayerData.source)
                            RemoveFromRace(iden)
                    end
                else
                    exports.qbx_core:Notify(Player.PlayerData.source, "Balapan sudah dimulai", 'error')
                end
                exports.qbx_core:Notify(source, "Balapan Dihentikan!", 'error')
                Races[key] = nil
            end
        end
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    else
        exports.qbx_core:Notify(source, "Kamu belum memulai balapan!", 'error')
    end
end

function GetJoinedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for _, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    return key
                end
            end
        end
    end
    return 0
end

local RACE_MIN, RACE_MAX = 250000, 2500000 -- uang daftar balapan (Rp)

RegisterNetEvent('qb-streetraces:NewRace', function(RaceTable)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    if not xPlayer or type(RaceTable) ~= 'table' then return end
    if GetJoinedRace(GetPlayerIdentifierByType(src, 'license')) ~= 0 then return end

    -- data balapan dibangun ulang di server; pot & daftar peserta tidak pernah diambil dari client
    local amount = math.tointeger(tonumber(RaceTable.amount))
    local ex, ey, ez = tonumber(RaceTable.endx), tonumber(RaceTable.endy), tonumber(RaceTable.endz)
    if not amount or not ex or not ey or not ez then return end
    if amount < RACE_MIN or amount > RACE_MAX then
        return exports.qbx_core:Notify(src, ('Uang daftar balapan harus Rp %s - Rp %s'):format(lib.math.groupdigits(RACE_MIN, '.'), lib.math.groupdigits(RACE_MAX, '.')), 'error')
    end

    local RaceId
    repeat RaceId = math.random(1000, 9999) until not Races[RaceId]
    local dirty = dirtyPart(src, amount)
    if xPlayer.Functions.RemoveMoney('cash', amount, "streetrace-created") then
        local start = GetEntityCoords(GetPlayerPed(src))
        Races[RaceId] = {
            started = false, startx = start.x, starty = start.y, startz = start.z,
            endx = ex, endy = ey, endz = ez, amount = amount, pot = amount, joined = {},
            dirty = { [GetPlayerIdentifierByType(src, 'license')] = dirty },
        }
        Races[RaceId].creator = GetPlayerIdentifierByType(src, 'license')
        Races[RaceId].joined[#Races[RaceId].joined+1] = GetPlayerIdentifierByType(src, 'license')
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
        exports.qbx_core:Notify(src, "Kamu ikut balapan dengan biaya Rp "..Races[RaceId].amount, 'success')
    end
end)

RegisterNetEvent('qb-streetraces:RaceWon', function(RaceId)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    local race = Races[RaceId]

    -- must be a real, started race that this player actually joined, and the
    -- pot can only ever be paid out once - closes both "claim a race you
    -- never joined" and "spam this event to drain the same pot repeatedly"
    if not race or not race.started then return end

    local identifier = GetPlayerIdentifierByType(src --[[@as string]], 'license')
    local joined = false
    for _, iden in pairs(race.joined) do
        if iden == identifier then joined = true break end
    end
    if not joined then return end

    local pot = race.pot
    local potDirty = 0
    for _, d in pairs(race.dirty or {}) do potDirty = potDirty + d end
    Races[RaceId] = nil

    xPlayer.Functions.AddMoney('cash', pot, "race-won")
    markDirty(src, math.min(potDirty, pot), "race-won")
    exports.qbx_core:Notify(src, "Kamu menang balapan dan menerima Rp "..pot, 'success')
    TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    TriggerClientEvent('qb-streetraces:RaceDone', -1, RaceId, GetPlayerName(src))
end)

RegisterNetEvent('qb-streetraces:JoinRace', function(RaceId)
    local src = source
    local xPlayer = exports.qbx_core:GetPlayer(src)
    local zPlayer = exports.qbx_core:GetPlayer(Races[RaceId].creator)
    if zPlayer ~= nil then
        if xPlayer.PlayerData.money.cash >= Races[RaceId].amount then
            Races[RaceId].pot = Races[RaceId].pot + Races[RaceId].amount
            Races[RaceId].joined[#Races[RaceId].joined+1] = GetPlayerIdentifierByType(src, 'license')
            local dirty = dirtyPart(src, Races[RaceId].amount)
            if xPlayer.Functions.RemoveMoney('cash', Races[RaceId].amount, "streetrace-joined") then
                Races[RaceId].dirty = Races[RaceId].dirty or {}
                Races[RaceId].dirty[GetPlayerIdentifierByType(src, 'license')] = dirty
                TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
                TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
                exports.qbx_core:Notify(zPlayer.PlayerData.source, GetPlayerName(src).." ikut balapan", 'primary')
            end
        else
            exports.qbx_core:Notify(src, "Uang tunaimu tidak cukup", 'error')
        end
    else
        exports.qbx_core:Notify(src, "Pembuat balapan sedang offline!", 'error')
        Races[RaceId] = {}
    end
end)

lib.addCommand('createrace', {help = 'Start A Street Race', params = {{name = 'amount', type = 'number', help = 'Jumlah taruhan balapan.'}}}, function(source, args)
    local src = source
    if GetJoinedRace(GetPlayerIdentifierByType(src, 'license')) == 0 then
        TriggerClientEvent('qb-streetraces:CreateRace', src, args.amount)
    else
        exports.qbx_core:Notify(src, "Kamu sudah ikut balapan", 'error')
    end
end)

lib.addCommand('stoprace', {help = 'Stop The Race You Created'}, function(source, _)
    CancelRace(source)
end)

lib.addCommand('quitrace', {help = 'Keluar dari balapan. (Uang TIDAK dikembalikan!)'}, function(source, _)
    local src = source
    local RaceId = GetJoinedRace(GetPlayerIdentifierByType(src, 'license'))
    if RaceId ~= 0 then
        if GetCreatedRace(GetPlayerIdentifierByType(src, 'license')) ~= RaceId then
            RemoveFromRace(GetPlayerIdentifierByType(src, 'license'))
            exports.qbx_core:Notify(src, "Kamu keluar dari balapan! Uangmu hangus", 'error')
        else
            exports.qbx_core:Notify(src, "/stoprace untuk menghentikan balapan", 'error')
        end
    else
        exports.qbx_core:Notify(src, "Kamu tidak sedang ikut balapan", 'error')
    end
end)

lib.addCommand('startrace', {help = 'Mulai balapan'}, function(source)
    local src = source
    local RaceId = GetCreatedRace(GetPlayerIdentifierByType(src, 'license'))

    if RaceId ~= 0 then

        Races[RaceId].started = true
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent("qb-streetraces:StartRace", -1, RaceId)
    else
        exports.qbx_core:Notify(src, "Kamu belum memulai balapan", 'error')

    end
end)


