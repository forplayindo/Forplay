-- f_patch: blur kaca ox_lib mengikuti tier blur f_hud (/hudblur, auto FPS).
-- f_hud memanggil event ini tiap 2 detik; diteruskan ke NUI ox_lib (f_ui.js).
local last

AddEventHandler('0r-hud:blurTier', function(tier)
    if type(tier) ~= 'string' or tier == last then return end
    last = tier
    SendNUIMessage({ action = 'ui:setBlurQuality', data = tier })
end)
