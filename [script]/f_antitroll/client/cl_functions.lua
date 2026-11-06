local isTimerInstance = false
local isTimerRunning = false -- flag variable to control the Timer thread
local uiShown = false
local watchId = 0

-- kartu disembunyikan selama pause menu (ESC / peta) terbuka; loop hanya jalan selama kartu tampil
local function watchPause()
    watchId = watchId + 1
    local id = watchId
    CreateThread(function()
        local paused = false
        while uiShown and id == watchId do
            local active = IsPauseMenuActive()
            if active ~= paused then
                paused = active
                SendNUIMessage({ type = "pause", paused = paused })
            end
            Wait(250)
        end
        if paused then SendNUIMessage({ type = "pause", paused = false }) end
    end)
end

function setUiShow(bool)
    SendNUIMessage({
        type = "show",
        show = bool
    })
    if bool and not uiShown then
        uiShown = true
        watchPause()
    elseif not bool then
        uiShown = false
    end
end

function updateUiTime(timeLeft)
    SendNUIMessage({
        type = "update",
        minleft = timeLeft
    })
end

function updateTimeToDatabase(overrideTime)
    TriggerServerEvent("bk_antitroll:updateTime", overrideTime or timeLeft)
end

function startTimer()
    local interval = timeToSafe

    updateTimeToDatabase()

    CreateThread(function()
        isTimerInstance = true
        isTimerRunning = true -- start the Timer thread
        while hasProtection do
            if interval == timeToSafe or timeLeft <= 0 then
                interval = 0
                setUiShow(true)
                updateTimeToDatabase()
            end

            interval = interval + 1

            if timeLeft <= 0 then
                stopAntiTroll()
                isTimerInstance = false
                return
            end

            timeLeft = timeLeft - 1

            updateUiTime(timeLeft)
            Wait(1000 * 60)
        end
        isTimerRunning = false -- stop the Timer thread
    end)
end

function startAntiTroll()
    if not isTimerInstance then
        startTimer()
    end
    setUiShow(true)

    -- Anti VDM
    if Config.DisableVDM then
        SetWeaponDamageModifier(-1553120962, 0.0)
    end

    -- Anti Driveby
    if not Config.DriveBy then
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end

    if Config.DisablePunching then
        CreateThread(function()
            while hasProtection do
                Wait(5)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
        end)
    end

    if Config.DisableShooting then
        CreateThread(function()
            while hasProtection do
                Wait(5)
                DisablePlayerFiring(player, true)
            end
        end)
    end

    if Config.DisablePunchingDamage then
        SetWeaponDamageModifier(-1569615261, 0.0)
    end
end

function stopAntiTroll()
    hasProtection = false
    timeLeft = 0

    isTimerInstance = false

    -- Anti VDM
    if Config.DisableVDM then
        SetWeaponDamageModifier(-1553120962, 1.0)
    end

    -- Anti Driveby
    if not Config.DriveBy then
        SetPlayerCanDoDriveBy(PlayerId(), true)
    end

    if Config.DisablePunching then
        EnableControlAction(0, 140, true)
        EnableControlAction(0, 141, true)
        EnableControlAction(0, 142, true)
    end

    if Config.DisablePunchingDamage then
        SetWeaponDamageModifier(-1569615261, 1.0)
    end
    setUiShow(false)
    isTimerRunning = false -- stop the Timer thread
end
