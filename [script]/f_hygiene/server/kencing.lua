local prevThirst = {}

local function SeedBaseline(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        prevThirst[src] = player.PlayerData.metadata.thirst or 100
    end
end

-- isi baseline saat player login, supaya minum pertama kali langsung kehitung (bukan cuma dipakai
-- untuk catat nilai awal)
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    SeedBaseline(source)
end)

-- isi baseline untuk player yang sudah online saat resource ini baru di-(re)start
CreateThread(function()
    for _, strSrc in ipairs(GetPlayers()) do
        SeedBaseline(tonumber(strSrc))
    end
end)

AddStateBagChangeHandler('thirst', '', function(bagName, key, value, reserved, replicated)
    local src = GetPlayerFromStateBagName(bagName)
    if src == 0 then return end

    local prev = prevThirst[src]
    prevThirst[src] = value
    if prev == nil then return end

    local delta = value - prev
    if delta <= 0 then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local current = player.PlayerData.metadata.kencing or 0
    if current >= 100 then return end

    HygieneClampSet(src, 'kencing', current + (delta * Config.Kencing.ThirstMultiplier))
    HygieneSyncHud(src)
end)

RegisterNetEvent('hygiene:server:FinishKencing', function()
    local src = source
    HygieneClampSet(src, 'kencing', 0)
    HygieneSyncHud(src)
end)

AddEventHandler('playerDropped', function()
    prevThirst[source] = nil
end)
