function HygieneSyncHud(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local meta = player.PlayerData.metadata
    TriggerClientEvent('hygiene:client:SyncHud', src, {
        mandi = meta.mandi or 0,
        kencing = meta.kencing or 0,
        poop = meta.poop or 0,
    })
end

function HygieneClampSet(src, key, value)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    value = math.max(0, math.min(100, value))
    player.Functions.SetMetaData(key, value)
    return value
end

local function InitPlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local meta = player.PlayerData.metadata

    if meta.mandi == nil then player.Functions.SetMetaData('mandi', 0) end
    if meta.kencing == nil then player.Functions.SetMetaData('kencing', 0) end
    if meta.poop == nil then player.Functions.SetMetaData('poop', 0) end

    HygieneSyncHud(src)
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    InitPlayer(source)
end)

RegisterNetEvent('hygiene:server:RequestSync', function()
    InitPlayer(source)
end)
