local function LoadDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end
end

-- coords/heading opsional: kalau nil, player tidur di tempat dia berdiri (tidur dimana saja)
function HygieneStartSleep(coords, heading)
    if HygieneState.isSleeping or HygieneState.isBathing or HygieneState.isPeeing or HygieneState.isPooping then return end
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        HygieneNotify('Tidak bisa tidur di dalam kendaraan', 'error')
        return
    end

    HygieneState.isSleeping = true

    -- matikan dulu animasi lain yang mungkin masih nempel (lalat, kebelet dll) supaya tidak
    -- bentrok sama animasi tidur yang mau dimainkan
    ClearPedTasks(ped)

    local A = Config.Sleep.Anim

    if coords then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end
    local sleepHeading = heading or GetEntityHeading(ped)
    SetEntityHeading(ped, sleepHeading)

    -- ENTER: transisi ke posisi berbaring
    LoadDict(A.enterDict)
    TaskPlayAnim(ped, A.enterDict, A.enterClip, 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(math.floor(GetAnimDuration(A.enterDict, A.enterClip) * 900))

    -- BASE: posisi tidur (loop), dipertahankan selama sleeping
    LoadDict(A.baseDict)
    TaskPlayAnim(ped, A.baseDict, A.baseClip, 8.0, -8.0, -1, 1, 0, false, false, false)
    FreezeEntityPosition(ped, true)

    HygieneNotify('Kamu sedang tidur, tekan [E] untuk bangun', 'inform', 5000)

    CreateThread(function()
        while HygieneState.isSleeping do
            Wait(0)
            if not IsEntityPlayingAnim(ped, A.baseDict, A.baseClip, 3) then
                TaskPlayAnim(ped, A.baseDict, A.baseClip, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            if IsControlJustReleased(0, 38) then
                HygieneState.isSleeping = false
            end
        end
    end)

    while HygieneState.isSleeping do
        Wait(0)
    end

    -- EXIT: transisi bangun
    LoadDict(A.exitDict)
    TaskPlayAnim(ped, A.exitDict, A.exitClip, 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(math.floor(GetAnimDuration(A.exitDict, A.exitClip) * 900))

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetEntityHeading(ped, sleepHeading)
    PlaceObjectOnGroundProperly(ped)

    -- aktifkan lagi animasi/efek yang di-pause saat tidur (lalat, kebelet dll) kalau HUD-nya
    -- masih mengharuskan
    TriggerEvent('hygiene:client:RefreshHud')
end

-- opsi "Tidur" selalu tersedia di radial menu, bisa dipakai dimana saja tanpa deteksi apapun
local function RegisterSleepRadial()
    lib.addRadialItem({
        id = 'hygiene_sleep',
        label = 'Tidur',
        icon = 'bed',
        onSelect = function()
            HygieneStartSleep(nil, nil)
        end,
    })
end
RegisterNetEvent('hygiene:client:RegisterRadial', RegisterSleepRadial)
RegisterSleepRadial()

-- deteksi prop kasur berdasarkan model (bukan koordinat), berlaku dimanapun kasur itu berada
local bedHashes = {}
for _, model in ipairs(Config.Sleep.BedModels) do
    bedHashes[#bedHashes + 1] = GetHashKey(model)
end

CreateThread(function()
    local textShown = false
    while true do
        local sleepMs = 1000

        if not HygieneState.isSleeping then
            local coords = HygieneCoords()
            local bedObj = nil

            for _, hash in ipairs(bedHashes) do
                local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.Sleep.BedSearchRadius, hash, false, false, false)
                if obj ~= 0 then
                    bedObj = obj
                    break
                end
            end

            if bedObj then
                sleepMs = 0
                local bedCoords = GetEntityCoords(bedObj)
                local dist = #(coords - bedCoords)

                if dist < Config.Sleep.BedInteractDistance then
                    if not textShown then
                        lib.showTextUI('[E] Tidur di Kasur', { icon = 'bed' })
                        textShown = true
                    end
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        textShown = false
                        HygieneStartSleep(bedCoords, GetEntityHeading(bedObj))
                    end
                elseif textShown then
                    lib.hideTextUI()
                    textShown = false
                end
            elseif textShown then
                lib.hideTextUI()
                textShown = false
            end
        elseif textShown then
            lib.hideTextUI()
            textShown = false
        end

        Wait(sleepMs)
    end
end)
