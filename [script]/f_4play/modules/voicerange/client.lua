-- Marker jarak suara: satu thread saja, hanya hidup selama VoiceRangeConfig.Duration setelah ganti mode.

local voiceModes
local drawRange = 0
local drawUntil = 0
local drawing = false

-- pma-voice di-ensure setelah [script], jadi daftar mode diambil saat pertama dibutuhkan
local function getVoiceModes()
    if not voiceModes then
        TriggerEvent('pma-voice:settingsCallback', function(voiceSettings)
            voiceModes = voiceSettings.voiceModes
        end)
    end
    return voiceModes
end

AddEventHandler('pma-voice:setTalkingMode', function(mode)
    local modes = getVoiceModes()
    local range = modes and modes[mode] and modes[mode][1]
    if not range then return end

    drawRange = range
    drawUntil = GetGameTimer() + VoiceRangeConfig.Duration
    if drawing then return end

    drawing = true
    CreateThread(function()
        while GetGameTimer() < drawUntil do
            VoiceRangeConfig.DrawMarker(drawRange)
            Wait(0)
        end
        drawing = false
    end)
end)
