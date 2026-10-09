-- Setelah spawn: tahan pemain (freeze + kebal + keyboard ditahan NUI) minimal Config.MinSeconds,
-- lalu tunggu sampai map, HUD dan semua resource siap (maksimal Config.MaxSeconds).

local running = false
local firstCharacterAt = -10000 -- karakter baru: langsung masuk menu baju, loader dilewati

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function hudReady()
    if GetResourceState('f_hud') ~= 'started' then return true end
    local ok, ready = pcall(function() return exports.f_hud:IsReady() end)
    return not ok or ready -- export tidak ada -> jangan menahan pemain
end

local function resourcesReady()
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'starting' then return false end
    end
    return true
end

local function worldReady(ped)
    return not IsScreenFadedOut() and HasCollisionLoadedAroundEntity(ped)
end

local function run()
    if running then return end
    running = true

    local playerId = PlayerId()
    local wasInvincible = GetPlayerInvincible(playerId)
    local minMs, maxMs = Config.MinSeconds * 1000, Config.MaxSeconds * 1000
    local startedAt = GetGameTimer()
    local lastShown

    send('show', {
        title = Config.Text.title,
        description = Config.Text.description,
        seconds = Config.MinSeconds,
    })
    -- fokus keyboard ke NUI kita (tanpa kursor): key mapping chat/HP/inventory tidak jalan
    SetNuiFocus(true, false)

    while true do
        local ped = PlayerPedId()
        -- diulang terus karena f_spawn melepas freeze setelah teleport
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)

        local elapsed = GetGameTimer() - startedAt
        if elapsed >= maxMs then break end

        if elapsed < minMs then
            local left = math.ceil((minMs - elapsed) / 1000)
            if left ~= lastShown then
                lastShown = left
                send('tick', left)
            end
        elseif worldReady(ped) and hudReady() and resourcesReady() then
            break
        elseif lastShown ~= 0 then
            lastShown = 0
            send('finishing', Config.Text.finishing)
        end

        Wait(100)
    end

    SetNuiFocus(false, false)
    send('hide')
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, wasInvincible)
    running = false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    -- qbx_core memicu CreateFirstCharacter tepat setelah event ini untuk karakter baru
    Wait(500)
    if GetGameTimer() - firstCharacterAt < 3000 then return end
    run()
end)

RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
    firstCharacterAt = GetGameTimer()
end)
