-- Operasi (client): ox_target di meja operasi (dokter), pasien berbaring & dibius, panel NUI
-- #surgery dan progress bar tiap tahap. Semua keputusan di server (server/surgery.lua).
local cfg = require 'config.treatment'
local S = cfg.surgery

local panelIndex  ---@type integer? meja yang panelnya sedang dibuka dokter
local busy = false
local carrying = false -- dokter sedang menggendong pasien (f_police kidnap / carry)

AddEventHandler('hospital:client:SetEscortingState', function(state) carrying = state == true end)

-- animasi dokter per tahap (posisi berdiri di samping meja)
-- animasi tangan bekerja setinggi dada (dict di balik scenario PROP_HUMAN_PARKING_METER; scenario
-- sendiri tidak bisa digabung prop di tangan)
local WORK_ANIM = { dict = 'amb@prop_human_parking_meter@male@base', clip = 'base', flag = 1 }
local HAND = { bone = 57005, pos = vec3(0.10, 0.02, -0.02), rot = vec3(-80.0, 0.0, 0.0) } -- tangan kanan

-- props: daftar model, dipakai yang pertama ada di game (prop yang tidak ada dilewati, animasi tetap jalan)
local STEP_ANIM = {
    anesthesia = { anim = { dict = 'anim@heists@humane_labs@finale@keycards', clip = 'ped_a_enter_loop', flag = 49 },
                   props = { 'prop_syringe_01' }, hand = { bone = 18905, pos = vec3(0.11, 0.03, 0.01), rot = vec3(90.0, 0.0, -50.0) } },
    incision = { anim = WORK_ANIM, props = { 'prop_scalpel', 'prop_cs_scalpel', 'prop_cs_scissors' }, hand = HAND }, -- sayat
    repair   = { anim = WORK_ANIM, props = { 'prop_tool_pliers', 'prop_cs_pliers', 'prop_cs_scissors' }, hand = HAND }, -- ambil peluru / pasang pen
    suture   = { anim = WORK_ANIM, props = { 'prop_cs_scissors' }, hand = HAND }, -- jahit
}
local DEFAULT_ANIM = { anim = { dict = 'amb@medic@standing@tendtodead@base', clip = 'base', flag = 1 } }

local propCache = {}
---@return table? prop untuk lib.progressCircle
local function stepProp(a)
    if not a.props then return end
    local key = a.props[1]
    if propCache[key] == nil then
        propCache[key] = false
        for _, name in ipairs(a.props) do
            local model = joaat(name)
            if IsModelInCdimage(model) then
                propCache[key] = { model = model, bone = a.hand.bone, pos = a.hand.pos, rot = a.hand.rot }
                break
            end
        end
    end
    return propCache[key] or nil
end

local function isDoctor()
    local job = QBX.PlayerData and QBX.PlayerData.job
    return job and job.type == 'ems' and job.onduty and job.grade.level >= S.doctorGrade
end

local function sessionAt(index)
    return GlobalState['f_amb:surgery:' .. index]
end

-------------------------------------------------------------------------------
-- Dokter: panel
-------------------------------------------------------------------------------
local function closePanel()
    if not panelIndex then return end
    panelIndex = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'surgeryClose' })
end

local function showPanel(data)
    SendNUIMessage({ action = 'surgeryOpen', data = data })
    SetNuiFocus(true, true)
end

local function openPanel(index)
    if panelIndex or busy then return end
    local data = lib.callback.await('f_ambulancejob:server:surgeryPanel', false, index)
    if not data or data.error then return exports.qbx_core:Notify(data and data.error or 'Gagal', 'error') end
    panelIndex = index
    showPanel(data)
end

local function runStep(stepIndex)
    local index = panelIndex
    if not index or busy then return end
    busy = true
    local res = lib.callback.await('f_ambulancejob:server:surgeryStart', false, index, stepIndex)
    if not res or res.error then
        busy = false
        return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error')
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'surgeryHide' })
    local a = STEP_ANIM[res.id] or DEFAULT_ANIM
    local ok = lib.progressCircle({
        duration = res.duration,
        position = 'bottom',
        label = ('Operasi: %s...'):format(res.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
        anim = a.anim,
        prop = stepProp(a),
    })
    ClearPedTasks(cache.ped)

    local done
    if ok then done = lib.callback.await('f_ambulancejob:server:surgeryFinish', false, index) end
    busy = false
    if not ok then
        exports.qbx_core:Notify('Tahap dibatalkan', 'error')
        if panelIndex == index then
            local data = lib.callback.await('f_ambulancejob:server:surgeryPanel', false, index)
            if data and not data.error then showPanel(data) else closePanel() end
        end
        return
    end
    if not done or done.error then
        exports.qbx_core:Notify(done and done.error or 'Gagal', 'error')
        local data = lib.callback.await('f_ambulancejob:server:surgeryPanel', false, index)
        if data and not data.error and panelIndex == index then showPanel(data) else closePanel() end
        return
    end
    if done.done then
        closePanel()
        return
    end
    if panelIndex == index then showPanel(done) end
end

RegisterNUICallback('srClose', function(_, cb) cb(1) closePanel() end)
RegisterNUICallback('srStep', function(data, cb)
    cb(1)
    local step = data and data.step
    CreateThread(function() runStep(step == 'transfusion' and step or tonumber(step)) end)
end)
RegisterNUICallback('srCancel', function(_, cb)
    local index = panelIndex
    cb(1)
    if not index then return end
    local res = lib.callback.await('f_ambulancejob:server:surgeryCancel', false, index)
    if res and res.error then exports.qbx_core:Notify(res.error, 'error') end
    closePanel()
end)

-------------------------------------------------------------------------------
-- ox_target meja operasi
-------------------------------------------------------------------------------
CreateThread(function()
    if #S.tables == 0 then return end -- meja belum diisi di config (MLO belum siap)
    for index, def in ipairs(S.tables) do
        exports.ox_target:addSphereZone({
            name = 'f_ambulancejob:surgery' .. index,
            coords = def.coords.xyz,
            radius = 1.4,
            options = {
                {
                    name = 'surgery_lay',
                    icon = 'fa-solid fa-bed-pulse',
                    label = 'Baringkan Pasien (Operasi)',
                    distance = 3.0,
                    canInteract = function() return isDoctor() and not sessionAt(index) end,
                    onSelect = function()
                        local player = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
                        if not player then return exports.qbx_core:Notify('Tidak ada pasien di dekatmu', 'error') end
                        local res = lib.callback.await('f_ambulancejob:server:surgeryLay', false, index, GetPlayerServerId(player))
                        if not res or res.error then return exports.qbx_core:Notify(res and res.error or 'Gagal', 'error') end
                        if carrying then TriggerEvent('police:client:GetKidnappedDragger') end -- lepas animasi gendong
                        exports.qbx_core:Notify('Pasien dibaringkan. Buka Panel Operasi untuk mulai.', 'success')
                    end,
                },
                {
                    name = 'surgery_panel',
                    icon = 'fa-solid fa-kit-medical',
                    label = 'Panel Operasi',
                    distance = 3.0,
                    canInteract = function()
                        local s = sessionAt(index)
                        return s ~= nil and s.doctor == cache.serverId and not panelIndex and not busy
                    end,
                    onSelect = function() openPanel(index) end,
                },
            },
        })
    end
end)

-------------------------------------------------------------------------------
-- Pasien di meja operasi
-------------------------------------------------------------------------------
local onTable = nil ---@type integer?
local canGetUp = false

local function releaseFromTable()
    onTable, canGetUp = nil, false
    lib.hideTextUI()
    TriggerEvent('police:client:DeEscort')
    FreezeEntityPosition(cache.ped, false)
    ClearPedTasksImmediately(cache.ped)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(1500) end
    exports.f_medical:EnableDamageEffects()
end

---@param unconscious boolean pasien dibawa dalam keadaan pingsan: layar tetap gelap sampai operasi selesai
RegisterNetEvent('f_ambulancejob:client:surgeryLay', function(index, unconscious)
    if GetInvokingResource() then return end
    local def = S.tables[index]
    if not def then return end
    onTable, canGetUp = index, false
    exports.f_medical:DisableDamageEffects()
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(50) end
    -- lepas dari gendongan / seretan (f_police) sebelum dipindah ke meja. Selalu dipanggil: revive
    -- pasien pingsan (NetworkResurrectLocalPlayer) sudah melepas attach, tapi flag IsEscorted f_police
    -- tetap true dan mengunci semua kontrol sampai di-reset.
    TriggerEvent('police:client:DeEscort')
    DetachEntity(cache.ped, true, false)
    ClearPedTasksImmediately(cache.ped)
    SetEntityCoords(cache.ped, def.coords.x, def.coords.y, def.coords.z, false, false, false, false)
    SetEntityHeading(cache.ped, def.coords.w)
    FreezeEntityPosition(cache.ped, true)
    lib.playAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
    if unconscious then
        exports.qbx_core:Notify('Kamu tidak sadarkan diri di meja operasi.', 'inform')
    else
        DoScreenFadeIn(800)
        exports.qbx_core:Notify('Kamu dibaringkan di meja operasi.', 'inform')
    end

    CreateThread(function()
        while onTable == index do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- lihat kiri/kanan
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true) -- chat
            EnableControlAction(0, 249, true) -- push to talk
            if canGetUp then
                EnableControlAction(0, 38, true)
                if IsControlJustPressed(0, 38) then releaseFromTable() break end
            end
            if not IsEntityPlayingAnim(cache.ped, InBedDict, InBedAnim, 3) then
                lib.playAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end)

-- dibius: layar gelap sampai operasi selesai / dibatalkan
RegisterNetEvent('f_ambulancejob:client:surgeryAnesthesia', function()
    if GetInvokingResource() or not onTable then return end
    exports.qbx_core:Notify('Obat bius mulai bekerja...', 'inform')
    DoScreenFadeOut(3000)
end)

RegisterNetEvent('f_ambulancejob:client:surgeryDone', function(recoverTime)
    if GetInvokingResource() or not onTable then return end
    DoScreenFadeIn(3000)
    exports.qbx_core:Notify(('Operasi selesai. Istirahat %d detik sebelum bangun.'):format(recoverTime or 30), 'success', 7000)
    local index = onTable
    SetTimeout((recoverTime or 30) * 1000, function()
        if onTable ~= index then return end
        canGetUp = true
        lib.showTextUI('[E] Bangun dari meja operasi')
    end)
end)

RegisterNetEvent('f_ambulancejob:client:surgeryRelease', function()
    if GetInvokingResource() or not onTable then return end
    releaseFromTable()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if panelIndex then SetNuiFocus(false, false) end
    if onTable then releaseFromTable() end
end)
