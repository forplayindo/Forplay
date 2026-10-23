-- Operasi (client): ox_target di meja operasi (dokter), pasien berbaring & dibius, panel NUI
-- #surgery dan progress bar tiap tahap. Semua keputusan di server (server/surgery.lua).
local cfg = require 'config.treatment'
local S = cfg.surgery

local panelIndex  ---@type integer? meja yang panelnya sedang dibuka dokter
local busy = false
local carrying = false -- dokter sedang menggendong pasien (f_police kidnap / carry)

AddEventHandler('hospital:client:SetEscortingState', function(state) carrying = state == true end)

-- animasi dokter semua tahap: tangan bekerja di meja (clip mekanik clubhouse). Aslinya jongkok, flag 49
-- = badan atas saja + loop, jadi kaki tetap berdiri di samping meja operasi
local WORK_ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 }
local L_HAND = { bone = 18905, pos = vec3(0.11, 0.03, 0.01), rot = vec3(0.0, 180.0, -70.0) } -- tangan kiri

-- tiap tahap = daftar fase { anim, props, time }; fase terakhir jalan sampai tahap selesai.
-- props: tiap entri = satu prop di satu tangan; models dicoba berurutan, dipakai yang pertama ada di
-- game (kalau tidak ada satu pun, prop itu dilewati, animasi tetap jalan)
local STEP_ANIM = {
    anesthesia = { -- bius
        { anim = WORK_ANIM, props = {
            { models = { 'prop_syringe_01', 'p_syringe_01_s' }, hand = L_HAND },
        } },
    },
    incision = { -- sayat
        { anim = WORK_ANIM, props = {
            { models = { 'bkr_prop_fakeid_scalpel_02a', 'prop_scalpel' }, hand = { bone = 18905, pos = vec3(0.11, 0.03, 0.01), rot = vec3(180.0, 0.0, 0.0) } },
        } },
    },
    repair = { -- ambil peluru / pasang pen
        { anim = WORK_ANIM, props = {
            { models = { 'prop_tool_pliers', 'prop_cs_pliers' }, hand = L_HAND }, -- pinset (sementara tang, belum ada prop pinset)
        } },
    },
    suture = { -- jahit
        { anim = WORK_ANIM, props = {
            { models = { 'prop_cs_scissors' }, hand = { bone = 18905, pos = vec3(0.11, 0.03, 0.01), rot = vec3(0.0, 0.0, 0.0) } },
        } },
    },
}
local DEFAULT_ANIM = { { anim = WORK_ANIM } } -- sterilisasi, perban

local propCache = {}
---@return table[]? daftar prop { model, bone, pos, rot } fase ini
local function stepProp(a)
    if not a.props then return end
    if propCache[a] == nil then
        local list = {}
        for _, p in ipairs(a.props) do
            for _, name in ipairs(p.models) do
                local model = joaat(name)
                if IsModelInCdimage(model) then
                    list[#list + 1] = { model = model, bone = p.hand.bone, pos = p.hand.pos, rot = p.hand.rot }
                    break
                end
            end
        end
        propCache[a] = #list > 0 and list or false
    end
    return propCache[a] or nil
end

local function attachProp(t)
    AttachEntityToEntity(t.obj, cache.ped, GetPedBoneIndex(cache.ped, t.bone), t.pos.x, t.pos.y, t.pos.z,
        t.rot.x, t.rot.y, t.rot.z, true, true, false, true, 1, true)
end

---Putar fase animasi berurutan (anim + prop tiap fase); fase terakhir di-loop sampai stop().
---@param phases table[]
---@param networked boolean prop terlihat pemain lain
---@return { props: table[], stop: fun() }
local function playPhases(phases, networked)
    local h = { props = {}, active = true }

    local function clearProps()
        for i = #h.props, 1, -1 do
            local obj = h.props[i].obj
            if DoesEntityExist(obj) then DeleteEntity(obj) end
            h.props[i] = nil
        end
    end

    function h.stop()
        h.active = false
        clearProps()
        ClearPedTasks(cache.ped)
    end

    CreateThread(function()
        for i, ph in ipairs(phases) do
            if not h.active then break end
            clearProps()
            local anim = ph.anim
            if not pcall(lib.playAnim, cache.ped, anim.dict, anim.clip, 3.0, -3.0, -1, anim.flag or 1, 0, false, false, false) then
                exports.qbx_core:Notify(('Animasi tidak ada: %s / %s'):format(anim.dict, anim.clip), 'error')
            end
            local c = GetEntityCoords(cache.ped)
            for _, p in ipairs(stepProp(ph) or {}) do
                lib.requestModel(p.model)
                if not h.active then break end
                local t = { obj = CreateObject(p.model, c.x, c.y, c.z, networked, true, false), bone = p.bone, pos = p.pos, rot = p.rot }
                attachProp(t)
                SetModelAsNoLongerNeeded(p.model)
                h.props[#h.props + 1] = t
            end
            local untilTime = ph.time and i < #phases and GetGameTimer() + ph.time
            while h.active and (not untilTime or GetGameTimer() < untilTime) do
                if not untilTime and not IsEntityPlayingAnim(cache.ped, anim.dict, anim.clip, 3) then
                    pcall(lib.playAnim, cache.ped, anim.dict, anim.clip, 3.0, -3.0, -1, anim.flag or 1, 0, false, false, false)
                end
                Wait(200)
            end
        end
        if not h.active then clearProps() end
    end)
    return h
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
    local anim = playPhases(STEP_ANIM[res.id] or DEFAULT_ANIM, true)
    local ok = lib.progressCircle({
        duration = res.duration,
        position = 'bottom',
        label = ('Operasi: %s...'):format(res.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, mouse = false },
    })
    anim.stop()

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

-------------------------------------------------------------------------------
-- TEST animasi operasi (sementara, hapus setelah animasi final)
-- /optest bius|steril|sayat|pen|jahit|perban [fase]   -> tanpa fase: semua fase berurutan seperti operasi;
--                                                        dengan fase (1/2): hanya fase itu, di-loop
-- /optest baring | stop
-- /optest custom <dict> <clip> [flag]   -> coba animasi lain (tanpa prop)
-------------------------------------------------------------------------------
local TEST_STEP = { bius = 'anesthesia', steril = 'sterilize', sayat = 'incision', pen = 'repair', peluru = 'repair', jahit = 'suture', perban = 'dress' }
local testAnim ---@type { props: table[], stop: fun() }?

local function stopTest()
    if testAnim then testAnim.stop() end
    testAnim = nil
    ClearPedTasks(cache.ped)
end

local function testProp(no)
    local t = testAnim and testAnim.props[no]
    if not t then exports.qbx_core:Notify('Jalankan /optest dulu', 'error') end
    return t
end

local function reattach(t, no, extra)
    DetachEntity(t.obj, true, false)
    attachProp(t)
    local line = ('prop %d%s: pos = vec3(%.3f, %.3f, %.3f), rot = vec3(%.1f, %.1f, %.1f)'):format(no, extra or '',
        t.pos.x, t.pos.y, t.pos.z, t.rot.x, t.rot.y, t.rot.z)
    print(line)
    exports.qbx_core:Notify(line, 'inform', 8000)
end

-- /opprop <no> x y z rx ry rz  -> geser/putar prop ke-<no> dari /optest; '_' = nilai tetap
RegisterCommand('opprop', function(_, args)
    local no = tonumber(args[1]) or 1
    local t = testProp(no)
    if not t then return end
    local n = {}
    for k = 2, 7 do n[k - 1] = tonumber(args[k]) end
    t.pos = vec3(n[1] or t.pos.x, n[2] or t.pos.y, n[3] or t.pos.z)
    t.rot = vec3(n[4] or t.rot.x, n[5] or t.rot.y, n[6] or t.rot.z)
    reattach(t, no)
end, false)

-- /opputar [no] -> putar prop ke arah berikutnya (24 arah kelipatan 90 derajat), posisi tetap
local ORIENT = {}
for _, base in ipairs({ { 0, 0 }, { 90, 0 }, { 180, 0 }, { 270, 0 }, { 0, 90 }, { 0, 270 } }) do
    for z = 0, 270, 90 do ORIENT[#ORIENT + 1] = vec3(base[1], base[2], z) end
end

RegisterCommand('opputar', function(_, args)
    local no = tonumber(args[1]) or 1
    local t = testProp(no)
    if not t then return end
    t.orient = (t.orient or 0) % #ORIENT + 1
    t.rot = ORIENT[t.orient]
    reattach(t, no, (' arah %d/%d'):format(t.orient, #ORIENT))
end, false)

RegisterCommand('optest', function(_, args)
    local name = args[1]
    stopTest()
    if not name or name == 'stop' then return end

    if name == 'baring' then
        lib.playAnim(cache.ped, InBedDict, InBedAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
        return exports.qbx_core:Notify(('Pasien: %s / %s'):format(InBedDict, InBedAnim), 'inform')
    end

    local phases
    if name == 'custom' then
        if not args[2] or not args[3] then return exports.qbx_core:Notify('/optest custom <dict> <clip> [flag]', 'error') end
        phases = { { anim = { dict = args[2], clip = args[3], flag = tonumber(args[4]) or 1 } } }
    else
        local step = TEST_STEP[name]
        if not step then return exports.qbx_core:Notify('Tahap: bius, steril, sayat, pen, jahit, perban, baring, stop', 'error') end
        phases = STEP_ANIM[step] or DEFAULT_ANIM
        local only = tonumber(args[2])
        if only then
            if not phases[only] then return exports.qbx_core:Notify(('%s hanya punya %d fase'):format(name, #phases), 'error') end
            phases = { phases[only] }
        end
    end

    testAnim = playPhases(phases, false)
    local desc = {}
    for i, ph in ipairs(phases) do desc[i] = ('%s / %s (flag %d)'):format(ph.anim.dict, ph.anim.clip, ph.anim.flag or 1) end
    exports.qbx_core:Notify(('%s: %s'):format(name, table.concat(desc, ' → ')), 'inform', 6000)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if panelIndex then SetNuiFocus(false, false) end
    if onTable then releaseFromTable() end
    if testAnim then stopTest() end
end)
