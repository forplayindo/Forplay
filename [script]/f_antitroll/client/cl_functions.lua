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

-- Waktu dihitung server; client hanya countdown tampilan + blokir aksi.
local timerGen = 0

local function startTimer()
    timerGen = timerGen + 1
    local gen = timerGen
    CreateThread(function()
        while hasProtection and gen == timerGen do
            Wait(1000 * 60)
            if not hasProtection or gen ~= timerGen then return end
            if timeLeft > 0 then timeLeft = timeLeft - 1 end
            updateUiTime(timeLeft)
        end
    end)
end

function startAntiTroll()
    startTimer()
    setUiShow(true)
    updateUiTime(timeLeft)

    if Config.DisableVDM then
        SetWeaponDamageModifier(-1553120962, 0.0)
    end

    if not Config.DriveBy then
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end

    if Config.DisablePunchingDamage then
        SetWeaponDamageModifier(-1569615261, 0.0)
    end

    -- satu thread per-frame untuk pukul + tembak (sebelumnya dua thread)
    if Config.DisablePunching or Config.DisableShooting then
        local gen = timerGen
        CreateThread(function()
            local pid = PlayerId()
            while hasProtection and gen == timerGen do
                if Config.DisablePunching then
                    DisableControlAction(0, 140, true)
                    DisableControlAction(0, 141, true)
                    DisableControlAction(0, 142, true)
                end
                if Config.DisableShooting then
                    DisablePlayerFiring(pid, true)
                end
                Wait(0)
            end
        end)
    end
end

function stopAntiTroll()
    hasProtection = false
    timeLeft = 0
    timerGen = timerGen + 1

    if Config.DisableVDM then
        SetWeaponDamageModifier(-1553120962, 1.0)
    end

    if not Config.DriveBy then
        SetPlayerCanDoDriveBy(PlayerId(), true)
    end

    if Config.DisablePunchingDamage then
        SetWeaponDamageModifier(-1569615261, 1.0)
    end
    setUiShow(false)
end
