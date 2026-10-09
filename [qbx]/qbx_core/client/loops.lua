local statusInterval = require 'config.client'.statusIntervalSeconds
local playerState = LocalPlayer.state

CreateThread(function()
    local timeout = 1000 * statusInterval
    while true do
        Wait(timeout)

        if QBX.IsLoggedIn then
            if ((playerState.hunger or 0) <= 0 or (playerState.thirst or 0) <= 0) and not playerState.isDead then
                -- f_deathscreen: SetEntityHealth tidak mencatat penyebab, jadi tandai sendiri (lokal, tidak direplikasi)
                local hungry, thirsty = (playerState.hunger or 0) <= 0, (playerState.thirst or 0) <= 0
                playerState:set('f_starveAt', { t = GetGameTimer(), kind = hungry and thirsty and 'both' or hungry and 'hunger' or 'thirst' }, false)
                local currentHealth = GetEntityHealth(cache.ped)
                local decreaseThreshold = math.random(5, 10)
                SetEntityHealth(cache.ped, currentHealth - decreaseThreshold)
            end
        end
    end
end)
