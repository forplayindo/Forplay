hasProtection = false
timeLeft = 0

RegisterNetEvent("bk_antitroll:toggle", function(toggle, minutes)
    if toggle then
        timeLeft = tonumber(minutes) or Config.HowLong
        if hasProtection then
            updateUiTime(timeLeft) -- sudah aktif: cukup sinkron waktu, jangan buat thread baru
            return
        end
        hasProtection = true
        startAntiTroll()
    elseif hasProtection then
        stopAntiTroll()
    end
end)

if Config.Framework == "ESX" then
    RegisterNetEvent("esx:playerLoaded")
    AddEventHandler("esx:playerLoaded", function(xPlayer, isNew, skin)
        TriggerServerEvent("bk_antitroll:onjoin", isNew)
    end)

    AddEventHandler("onResourceStart", function(resourceName)
        if resourceName == GetCurrentResourceName() then
            TriggerServerEvent("bk_antitroll:onjoin", false)
        end
    end)
elseif Config.Framework == "QBCore" then
    RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
    AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
        TriggerServerEvent("bk_antitroll:onjoin", false)
    end)
    RegisterNetEvent("QBCore:Client:OnPlayerUnload")
    AddEventHandler("QBCore:Client:OnPlayerUnload", function()
        if hasProtection then stopAntiTroll() end
    end)

    -- restart resource saat sudah di dalam kota
    AddEventHandler("onClientResourceStart", function(resourceName)
        if resourceName == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then
            TriggerServerEvent("bk_antitroll:onjoin", false)
        end
    end)
end
