local tickInterval = math.floor(Config.Mandi.DirtyDuration / 10)

CreateThread(function()
    while true do
        Wait(tickInterval)
        for _, strSrc in ipairs(GetPlayers()) do
            local src = tonumber(strSrc)
            local player = exports.qbx_core:GetPlayer(src)
            if player then
                local current = player.PlayerData.metadata.mandi or 0
                if current < 100 then
                    HygieneClampSet(src, 'mandi', current + 10)
                    HygieneSyncHud(src)
                end
            end
        end
    end
end)

RegisterNetEvent('hygiene:server:FinishMandi', function()
    local src = source
    HygieneClampSet(src, 'mandi', 0)
    HygieneSyncHud(src)
end)
