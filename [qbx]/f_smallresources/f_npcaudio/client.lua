local config = lib.loadJson('f_npcaudio.config')

if config.disablePoliceScanner then
    SetAudioFlag('PoliceScannerDisabled', true)
end

if not (config.muteSpeech or config.mutePain or config.muteTrafficRadio) then return end

-- kendaraan NPC yang radionya sudah dimatikan; kendaraan baru di pool diproses sekali
local doneVehicles = {}

CreateThread(function()
    while true do
        local seen = {}

        if config.muteSpeech or config.mutePain then
            local peds = GetGamePool('CPed')
            for i = 1, #peds do
                local ped = peds[i]
                if not IsPedAPlayer(ped) then
                    if config.muteSpeech then
                        StopPedSpeaking(ped, true)
                    end
                    if config.mutePain then
                        DisablePedPainAudio(ped, true)
                    end
                end
            end
        end

        if config.muteTrafficRadio then
            local vehicles = GetGamePool('CVehicle')
            for i = 1, #vehicles do
                local veh = vehicles[i]
                local driver = GetPedInVehicleSeat(veh, -1)
                if driver ~= 0 and not IsPedAPlayer(driver) then
                    seen[veh] = true
                    -- hanya OFF, bukan SetVehicleRadioEnabled(false): kalau mobil dicuri pemain, F9 tetap bisa menyalakan radio
                    if not doneVehicles[veh] then
                        SetVehRadioStation(veh, 'OFF')
                    end
                end
            end
            doneVehicles = seen
        end

        Wait(config.interval)
    end
end)
