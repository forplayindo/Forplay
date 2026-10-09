-- logo baru muncul setelah player benar-benar masuk kota (bukan di layar pilih karakter),
-- dan hilang lagi saat logout/ganti karakter
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SendNUIMessage({ action = 'showLogo' })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    SendNUIMessage({ action = 'hideLogo' })
end)

-- kalau resource ini di-restart saat player sudah lama masuk kota (bukan baru login),
-- tampilkan lagi tanpa perlu relog
CreateThread(function()
    Wait(500)
    if LocalPlayer.state.isLoggedIn then
        SendNUIMessage({ action = 'showLogo' })
    end
end)
