-- Tampilan HUD sekarang ada di f_hud (bar Mandi / Kencing / Poop, warnanya bisa diganti di setting f_hud).
-- Resource ini tetap menghitung nilainya dan meneruskannya ke f_hud; panel NUI lamanya tidak ditampilkan lagi.
local function PushToFHud()
    TriggerEvent('f_hud:client:setHygiene', {
        mandi = HygieneState.mandi,
        kencing = HygieneState.kencing,
        poop = HygieneState.poop,
        visible = HygieneState.hudVisible,
    })
end

local function RefreshNui()
    PushToFHud()
end
RegisterNetEvent('hygiene:client:RefreshHud', RefreshNui)

local function SetHudVisible(state)
    HygieneState.hudVisible = state
    SendNUIMessage({ action = 'visibility', visible = false }) -- panel lama selalu disembunyikan
    PushToFHud()
end

RegisterCommand('hygienehud', function()
    SetHudVisible(not HygieneState.hudVisible)
end, false)

-- keybind agar player bisa atur sendiri tombol show/hide HUD (default F3, bisa di-rebind
-- lewat Settings > Key Bindings di FiveM, keterangan & tombol yang terpasang otomatis
-- mengikuti apa yang di-set player di sana)
RegisterKeyMapping('hygienehud', 'Show/Hide HUD Hygiene (Mandi, Kencing, Poop)', 'keyboard', 'F3')

exports('GetHygieneState', function()
    return {
        mandi = HygieneState.mandi,
        kencing = HygieneState.kencing,
        poop = HygieneState.poop,
        visible = HygieneState.hudVisible,
    }
end)
exports('ShowHygieneHud', function() SetHudVisible(true) end)
exports('HideHygieneHud', function() SetHudVisible(false) end)
exports('ToggleHygieneHud', function() SetHudVisible(not HygieneState.hudVisible) end)

-- HUD baru muncul setelah player benar-benar masuk kota (bukan di layar pilih karakter),
-- dan hilang lagi saat logout/ganti karakter
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetHudVisible(true)
    RefreshNui()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    SetHudVisible(false)
end)

-- kalau resource ini di-restart saat player sudah lama masuk kota (bukan baru login),
-- tampilkan lagi tanpa perlu relog
CreateThread(function()
    Wait(500)
    if LocalPlayer.state.isLoggedIn then
        SetHudVisible(true)
        RefreshNui()
    end
end)
