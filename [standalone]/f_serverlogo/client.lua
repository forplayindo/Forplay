local shown = false
local watchId = 0

-- logo disembunyikan selama pause menu (ESC / peta) terbuka; loop hanya jalan selama logo tampil
local function watchPause()
    watchId = watchId + 1
    local id = watchId
    CreateThread(function()
        local paused = false
        while shown and id == watchId do
            local active = IsPauseMenuActive()
            if active ~= paused then
                paused = active
                SendNUIMessage({ action = 'pause', paused = paused })
            end
            Wait(250)
        end
        if paused then SendNUIMessage({ action = 'pause', paused = false }) end
    end)
end

local function show()
    SendNUIMessage({ action = 'showLogo' })
    if shown then return end
    shown = true
    watchPause()
end

-- logo baru muncul setelah player benar-benar masuk kota (bukan di layar pilih karakter),
-- dan hilang lagi saat logout/ganti karakter
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', show)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    shown = false
    SendNUIMessage({ action = 'hideLogo' })
end)

-- kalau resource ini di-restart saat player sudah lama masuk kota (bukan baru login),
-- tampilkan lagi tanpa perlu relog
CreateThread(function()
    Wait(500)
    if LocalPlayer.state.isLoggedIn then
        show()
    end
end)
