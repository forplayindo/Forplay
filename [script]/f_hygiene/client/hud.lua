local function RefreshNui()
    SendNUIMessage({
        action = 'update',
        mandi = HygieneState.mandi,
        kencing = HygieneState.kencing,
        poop = HygieneState.poop,
    })
end
RegisterNetEvent('hygiene:client:RefreshHud', RefreshNui)

local function SetHudVisible(state)
    HygieneState.hudVisible = state
    SendNUIMessage({ action = 'visibility', visible = state })
end

RegisterCommand('hygienehud', function()
    SetHudVisible(not HygieneState.hudVisible)
end, false)

-- keybind agar player bisa atur sendiri tombol show/hide HUD (default F3, bisa di-rebind
-- lewat Settings > Key Bindings di FiveM, keterangan & tombol yang terpasang otomatis
-- mengikuti apa yang di-set player di sana)
RegisterKeyMapping('hygienehud', 'Show/Hide HUD Hygiene (Mandi, Kencing, Poop)', 'keyboard', 'F3')

-- label tombol yang ditampilkan di judul HUD (misal "F3") - dibaca dari keymapping yang sama
-- di atas via GetControlInstructionalButton, jadi otomatis ikut berubah kalau player rebind
-- tombolnya lewat Settings > Key Bindings, tidak perlu direstart manual
local hudKeyHash = joaat('hygienehud') | 0x80000000
local lastHudKeyLabel = nil

local function PushHudKeyLabel()
    local label = GetControlInstructionalButton(0, hudKeyHash, true):sub(3)
    if label ~= lastHudKeyLabel then
        lastHudKeyLabel = label
        SendNUIMessage({ action = 'keybind', key = label })
    end
end

CreateThread(function()
    while true do
        PushHudKeyLabel()
        Wait(1000)
    end
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
