local QBCore = exports['qb-core']:GetCoreObject()

local Active = true
local test = nil
local test1 = nil
local spam = true

RegisterCommand("help", function(source, args, raw)
    local meta = QBCore.Functions.GetPlayerData().metadata
    if (meta["isdead"] or meta["inlaststand"]) and spam then
        QBCore.Functions.TriggerCallback('hhfw:docOnline', function(EMSOnline, hasEnoughMoney)
            if EMSOnline <= Config.Doctor and hasEnoughMoney and spam then
                TriggerServerEvent('hhfw:charge')
                Notify("Petugas medis sedang menuju lokasimu")
                SpawnDoctor(GetEntityCoords(PlayerPedId()))
            else
                if EMSOnline > Config.Doctor then
                    Notify("Terlalu banyak petugas medis yang online", "error")
                elseif not hasEnoughMoney then
                    Notify("Uang tidak cukup", "error")
                else
                    Notify("Tunggu, paramedis sedang dalam perjalanan", "primary")
                end    
            end
        end)
    else
        Notify("Ini hanya bisa dipakai saat kamu pingsan/meninggal", "error")
    end
end)

function SpawnDoctor(coords)
    spam = false
    local loc = coords
    RequestModel('s_m_m_doctor_01')
    while not HasModelLoaded('s_m_m_doctor_01') do
        Wait(1)
    end

    -- Teleport NPC Doctor to nearby location
    local spawnRadius = 1
    local spawnPos = vector3(loc.x + math.random(-spawnRadius, spawnRadius), loc.y + math.random(-spawnRadius, spawnRadius), loc.z)
    
    test1 = CreatePed(26, GetHashKey('s_m_m_doctor_01'), spawnPos, 0, true, false)
    Active = true

    -- Add a blip for the NPC doctor
    local blip = AddBlipForEntity(test1)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 5)
    SetBlipFlashes(blip, true)

    Citizen.CreateThread(function()
        while Active do
            Citizen.Wait(200)
            local loc = GetEntityCoords(PlayerPedId())
            local ld = GetEntityCoords(test1)
            local dist1 = Vdist(loc.x, loc.y, loc.z, ld.x, ld.y, ld.z)
            if dist1 > 1 then
                TaskGoToCoordAnyMeans(test1, loc.x, loc.y, loc.z, 1.0, 0, 0, 786603, 0xbf800000)
            elseif dist1 <= 1 then
                Active = false
                ClearPedTasksImmediately(test1)
                DoctorNPC()
            end
        end
    end)
end

function DoctorNPC()
    RequestAnimDict("mini@cpr@char_a@cpr_str")
    while not HasAnimDictLoaded("mini@cpr@char_a@cpr_str") do
        Citizen.Wait(1000)
    end

    TaskPlayAnim(test1, "mini@cpr@char_a@cpr_str","cpr_pumpchest",1.0, 1.0, -1, 9, 1.0, 0, 0, 0)
    QBCore.Functions.Progressbar("revive_doc", "Dokter sedang memberimu pertolongan medis", Config.ReviveTime, false, false, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(test1)
        Citizen.Wait(500)
        -- hospital:client:Revive cuma jalan kalau player lagi di kasur RS, buat revive
        -- di lapangan (dokter AI dateng ke player) harus panggil ini langsung
        TriggerEvent("f_medical:client:playerRevived")
        StopScreenEffect('DeathFailOut')
        Notify("Perawatan selesai, kamu dikenakan biaya Rp "..Config.Price, "success")
        SetEntityAsMissionEntity(test1, false, true)
        DeleteEntity(test1)
        spam = true
    end)
end

function Notify(msg, state)
    QBCore.Functions.Notify(msg, state)
end
