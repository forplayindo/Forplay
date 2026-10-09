local prevHunger = {}

local function SeedBaseline(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        prevHunger[src] = player.PlayerData.metadata.hunger or 100
    end
end

-- isi baseline saat player login, supaya makan pertama kali langsung kehitung (bukan cuma dipakai
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

AddStateBagChangeHandler('hunger', '', function(bagName, key, value, reserved, replicated)
    local src = GetPlayerFromStateBagName(bagName)
    if src == 0 then return end

    local prev = prevHunger[src]
    prevHunger[src] = value
    if prev == nil then return end

    local delta = value - prev
    if delta <= 0 then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local current = player.PlayerData.metadata.poop or 0
    if current >= 100 then return end

    HygieneClampSet(src, 'poop', current + (delta * Config.Poop.HungerMultiplier))
    HygieneSyncHud(src)
end)

RegisterNetEvent('hygiene:server:FinishPoop', function()
    local src = source
    HygieneClampSet(src, 'poop', 0)
    HygieneSyncHud(src)
end)

AddEventHandler('playerDropped', function()
    prevHunger[source] = nil
end)
