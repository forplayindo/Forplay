-- Operasi (server).
--  * Luka yang perlu operasi (NeedsSurgery): tingkat 4 akibat senjata api di kepala/leher/badan
--    (peluru bersarang) atau tingkat 4 di kaki/telapak/tulang belakang (patah parah). Splint / Suture
--    Kit di panel Cek Pasien hanya MENSTABILKAN luka ini (StabilizeInjury).
--  * Selama belum dioperasi: darah maksimal surgery.bloodCap, luka distabilkan bisa berdarah lagi.
--  * Dokter (grade >= doctorGrade) membaringkan pasien di meja operasi lalu menjalankan tahap
--    berurutan (progress bar + item). Selesai: luka dihapus, kaki -> masa pemulihan (Crutch).

local cfg = require 'config.treatment'
local S = cfg.surgery
local WEAPONS = exports.qbx_core:GetWeapons()
local BODY_PREFIX = 'f_medical:injuries:'
local BLEED_BAG = 'f_medical:bleedLevel'
local ALIVE = 1

-------------------------------------------------------------------------------
-- Luka yang perlu operasi (dipakai juga oleh server/patient.lua)
-------------------------------------------------------------------------------

---@param part string
---@param injury table? { severity, weaponHash, stabilized? }
---@return boolean
function NeedsSurgery(part, injury)
    if type(injury) ~= 'table' or (tonumber(injury.severity) or 0) < 4 then return false end
    local def = cfg.bodyParts[part]
    if not def then return false end
    if def.limp then return true end
    if def.kind == 'skin' then
        local weapon = injury.weaponHash and WEAPONS[injury.weaponHash]
        return weapon ~= nil and weapon.ammotype ~= nil
    end
    return false
end

---@return { part: string, injury: table }[]
function SurgeryParts(target)
    local state, out = Player(target).state, {}
    for part in pairs(cfg.bodyParts) do
        local injury = state[BODY_PREFIX .. part]
        if NeedsSurgery(part, injury) then out[#out + 1] = { part = part, injury = injury } end
    end
    return out
end

---Semua luka pasien (operasi bebas diputuskan EMS, tidak harus luka tingkat 4).
---@return { part: string, injury: table, surgery: boolean }[]
local function injuredParts(target)
    local state, out = Player(target).state, {}
    for part in pairs(cfg.bodyParts) do
        local injury = state[BODY_PREFIX .. part]
        if type(injury) == 'table' then
            out[#out + 1] = { part = part, injury = injury, surgery = NeedsSurgery(part, injury) }
        end
    end
    return out
end

---Item lapangan pada luka yang perlu operasi: luka tetap ada, ditandai distabilkan.
function StabilizeInjury(target, part, injury)
    Player(target).state:set(BODY_PREFIX .. part, {
        severity = injury.severity, weaponHash = injury.weaponHash, stabilized = true,
    }, true)
end

-- efek luka yang belum dioperasi: darah dibatasi, luka distabilkan kadang berdarah lagi
CreateThread(function()
    local tick = 0
    while true do
        Wait(60000)
        tick += 1
        for src in pairs(exports.qbx_core:GetQBPlayers()) do
            local parts = SurgeryParts(src)
            if #parts > 0 and exports.f_medical:GetDeathState(src) == ALIVE then
                if exports.f_medical:GetBloodPct(src) > S.bloodCap then exports.f_medical:SetBloodPct(src, S.bloodCap) end
                if tick % 5 == 0 and (tonumber(Player(src).state[BLEED_BAG]) or 0) == 0 then
                    for _, p in ipairs(parts) do
                        if p.injury.stabilized and math.random(100) <= S.rebleedChance then
                            exports.f_medical:SetBleedLevel(src, 1)
                            exports.qbx_core:Notify(src, 'Lukamu berdarah lagi. Segera operasi di rumah sakit.', 'error', 7000)
                            break
                        end
                    end
                end
            end
        end
    end
end)

-------------------------------------------------------------------------------
-- Sesi meja operasi
-------------------------------------------------------------------------------

---@class SurgerySession
---@field doctor number
---@field patient number
---@field step integer tahap terakhir yang selesai
---@field kitPaid boolean? jatah Surgical Kit sesi ini sudah dipotong dari Stok Gudang
---@field services string[]? layanan tambahan selama operasi (transfusi), ditagih bersama operasi
---@field pending { step: integer?, startedAt: integer, duration: integer, transfusion: boolean?, transfuse: boolean? }?

---@type table<integer, SurgerySession>
local sessions = {}

local function charName(src)
    local p = exports.qbx_core:GetPlayer(src)
    local ci = p and p.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

local function isDoctor(src)
    local p = exports.qbx_core:GetPlayer(src)
    local job = p and p.PlayerData.job
    return job and job.type == 'ems' and job.onduty and job.grade.level >= S.doctorGrade
end

local function distTo(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

local function publish(index)
    local s = sessions[index]
    GlobalState['f_amb:surgery:' .. index] = s and { doctor = s.doctor, patient = s.patient } or nil
end

local function sessionOf(src)
    for index, s in pairs(sessions) do
        if s.doctor == src or s.patient == src then return index, s end
    end
end

-- Obat & alat operasi diambil dari Stok Gudang (server/stock.lua); dokter wajib membawa Surgery Bag.
-- Surgical Kit = "jatah operasi": 1 jatah dipotong sekali per operasi, di tahap pertama yang memakai kit.
local BAG = 'tas_operasi'
local KIT_STOCK = 'surgery'

---Jatah kit yang tersedia untuk sesi ini (1 kalau sesi sudah memotong jatahnya).
local function kitLeft(s)
    return s.kitPaid and math.max(1, Stock.Get(KIT_STOCK)) or Stock.Get(KIT_STOCK)
end

---Darah minimal yang dibutuhkan sekarang: batas kritis, atau syarat tahap berikutnya kalau lebih tinggi.
---Di bawah ini dokter bisa transfusi langsung dari panel operasi.
local function bloodNeed(s)
    local need = cfg.blood.critical
    local nextStep = S.steps[s.step + 1]
    if nextStep and nextStep.needBlood and nextStep.needBlood > need then need = nextStep.needBlood end
    return need
end

local function panelData(index)
    local s = sessions[index]
    if not s then return end
    local parts = {}
    for _, p in ipairs(injuredParts(s.patient)) do
        parts[#parts + 1] = { part = p.part, label = cfg.bodyParts[p.part].label, stabilized = p.injury.stabilized == true,
                              surgery = p.surgery, severity = tonumber(p.injury.severity) or 0 }
    end
    local steps = {}
    for i, st in ipairs(S.steps) do
        steps[i] = { label = st.label, desc = st.desc, duration = st.duration, itemKey = st.item, needBlood = st.needBlood,
                     item = st.item and (cfg.itemLabels[st.item] or st.item), kit = st.kit == true, done = i <= s.step }
    end
    return {
        index = index,
        table = S.tables[index].label,
        patient = charName(s.patient),
        blood = exports.f_medical:GetBloodPct(s.patient),
        bleed = tonumber(Player(s.patient).state[BLEED_BAG]) or 0,
        parts = parts,
        steps = steps,
        next = s.step + 1,
        stock = {
            anesthetic = Stock.Get(S.anesthetic),
            suture = Stock.Get(cfg.items.suture),
            bandage = Stock.Get(cfg.items.bandage),
            bloodBag = Stock.Get(cfg.items.bloodBag),
            kit = kitLeft(s),
        },
        bag = HasValidBag(s.doctor, BAG),
        kitWear = 1,
        transfusion = { need = bloodNeed(s), duration = cfg.durations.transfusion, item = cfg.itemLabels.bloodBag or 'Blood Bag' },
    }
end

---Akhiri sesi. done = operasi selesai (pasien bangun setelah recoverTime), selain itu dibatalkan.
local function endSession(index, done)
    local s = sessions[index]
    if not s then return end
    sessions[index] = nil
    publish(index)
    if GetPlayerPed(s.patient) ~= 0 then
        TriggerClientEvent(done and 'f_ambulancejob:client:surgeryDone' or 'f_ambulancejob:client:surgeryRelease', s.patient, S.recoverTime)
    end
end

local function complete(index)
    local s = sessions[index]
    -- operasi membereskan semua luka; masa pemulihan hanya untuk patah parah di kaki / tulang belakang
    for _, p in ipairs(injuredParts(s.patient)) do
        exports.f_medical:HealBodyPart(s.patient, p.part)
        if p.surgery and cfg.bodyParts[p.part].limp then Recovery.Start(s.patient, p.part) end
    end
    exports.f_medical:SetBleedLevel(s.patient, 0)
    -- operasi selesai = sehat: darah penuh, dan kalau sempat pingsan di meja langsung sadar (tanpa Revive)
    if exports.f_medical:GetDeathState(s.patient) ~= ALIVE then
        exports.f_medical:ReviveKeepInjuries(s.patient, 100)
    else
        exports.f_medical:SetBloodPct(s.patient, 100)
    end
    -- tagihan operasi (+ transfusi selama operasi) langsung masuk Kasir
    local services = s.services or {}
    services[#services + 1] = 'surgery'
    Billing.SurgeryBill(s.doctor, s.patient, services)
    exports.qbx_core:Notify(s.doctor, ('Operasi %s selesai.'):format(charName(s.patient)), 'success')
    endSession(index, true)
end

---Validasi umum dokter + pasien di meja. Mengembalikan error atau nil.
local function checkTable(src, index)
    local s = sessions[index]
    local def = S.tables[index]
    if not s or not def or s.doctor ~= src then return 'Kamu tidak sedang menangani operasi di meja ini' end
    if not isDoctor(src) then return 'Hanya Dokter yang bertugas' end
    if not HasValidBag(src, BAG) then return 'Kamu tidak membawa Surgery Bag yang masih berlaku (ambil di Armory)' end
    if distTo(src, def.coords.xyz) > 3.5 then return 'Kamu terlalu jauh dari meja operasi' end
    if distTo(s.patient, def.coords.xyz) > 3.0 then return 'Pasien tidak ada di meja operasi' end
end

lib.callback.register('f_ambulancejob:server:surgeryLay', function(src, index, target)
    index, target = tonumber(index), tonumber(target)
    local def = index and S.tables[index]
    if not def then return { error = 'Meja operasi tidak ditemukan' } end
    if not isDoctor(src) then return { error = ('Hanya Dokter (grade %d+) yang bertugas'):format(S.doctorGrade) } end
    if not HasValidBag(src, BAG) then return { error = 'Kamu tidak membawa Surgery Bag yang masih berlaku (ambil di Armory)' } end
    if sessions[index] then return { error = 'Meja operasi sedang dipakai' } end
    if sessionOf(src) then return { error = 'Kamu sedang menangani operasi lain' } end
    if distTo(src, def.coords.xyz) > 3.5 then return { error = 'Kamu terlalu jauh dari meja operasi' } end
    if not target or target == src or not exports.qbx_core:GetPlayer(target) then return { error = 'Tidak ada pasien di dekatmu' } end
    if sessionOf(target) then return { error = 'Pasien sedang dioperasi' } end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if #(GetEntityCoords(a) - GetEntityCoords(b)) > 3.0 then return { error = 'Pasien harus dekat kamu' } end

    -- pasien pingsan boleh langsung dioperasi: dibangkitkan diam-diam (luka tetap) supaya sistem
    -- kematian tidak melawan posisi di meja, layarnya tetap gelap sampai operasi selesai
    local unconscious = exports.f_medical:GetDeathState(target) ~= ALIVE
    if unconscious then
        exports.f_medical:ReviveKeepInjuries(target, math.max(cfg.blood.afterRevive, exports.f_medical:GetBloodPct(target) or 0))
    end
    -- di meja operasi pendarahan ditangani tim: tanpa ini bleed tick menurunkan darah (= HP) sampai
    -- pasien pingsan lagi di tengah operasi
    exports.f_medical:SetBleedLevel(target, 0)

    sessions[index] = { doctor = src, patient = target, step = 0 }
    publish(index)
    TriggerClientEvent('f_ambulancejob:client:surgeryLay', target, index, unconscious)
    return { ok = true }
end)

lib.callback.register('f_ambulancejob:server:surgeryPanel', function(src, index)
    index = tonumber(index)
    local s = index and sessions[index]
    if not s or s.doctor ~= src then return { error = 'Kamu tidak sedang menangani operasi di meja ini' } end
    return panelData(index)
end)

---Transfusi di meja operasi: Blood Bag dipotong dari Stok Gudang. Mengembalikan error atau nil.
local function transfuse(src, s)
    if not Stock.Take({ [cfg.items.bloodBag] = 1 }) then return 'Stok Blood Bag di gudang habis' end
    -- sama seperti Cek Pasien: maksimal bloodCap selama luka berat belum selesai dioperasi
    exports.f_medical:SetBloodPct(s.patient, #SurgeryParts(s.patient) > 0 and S.bloodCap or 100)
    s.services = s.services or {}
    s.services[#s.services + 1] = 'transfusion'
end

lib.callback.register('f_ambulancejob:server:surgeryStart', function(src, index, stepIndex)
    index = tonumber(index)
    local err = checkTable(src, index)
    if err then return { error = err } end
    local s = sessions[index]

    -- transfusi langsung di meja operasi (tidak perlu bolak-balik ke Cek Pasien)
    if stepIndex == 'transfusion' then
        local need = bloodNeed(s)
        if exports.f_medical:GetBloodPct(s.patient) >= need then return { error = ('Darah pasien sudah %d%% atau lebih'):format(need) } end
        if Stock.Get(cfg.items.bloodBag) < 1 then return { error = 'Stok Blood Bag di gudang habis' } end
        s.pending = { transfusion = true, startedAt = GetGameTimer(), duration = cfg.durations.transfusion }
        return { duration = cfg.durations.transfusion, id = 'transfusion', label = 'Transfusi darah' }
    end

    stepIndex = tonumber(stepIndex)
    local step = S.steps[stepIndex or 0]
    if not step or stepIndex ~= s.step + 1 then return { error = 'Tahap operasi harus berurutan' } end
    if step.item and Stock.Get(step.item) < 1 then return { error = ('Stok %s di gudang habis'):format(cfg.itemLabels[step.item] or step.item) } end
    if step.kit and kitLeft(s) < 1 then return { error = 'Jatah Surgical Kit di gudang habis' } end
    -- darah kurang: transfusi otomatis jadi bagian tahap ini (Blood Bag dari Stok Gudang)
    local withTransfusion = step.needBlood ~= nil and exports.f_medical:GetBloodPct(s.patient) < step.needBlood
    if withTransfusion and Stock.Get(cfg.items.bloodBag) < 1 then
        return { error = ('Darah pasien di bawah %d%%, stok Blood Bag di gudang habis'):format(step.needBlood) }
    end
    local duration = step.duration + (withTransfusion and cfg.durations.transfusion or 0)
    s.pending = { step = stepIndex, startedAt = GetGameTimer(), duration = duration, transfuse = withTransfusion }
    return { duration = duration, id = step.id, label = withTransfusion and ('Transfusi + %s'):format(step.label) or step.label }
end)

lib.callback.register('f_ambulancejob:server:surgeryFinish', function(src, index)
    index = tonumber(index)
    local s = index and sessions[index]
    local job = s and s.pending
    if s then s.pending = nil end
    if not job then return { error = 'Tidak ada tahap berjalan' } end

    if GetGameTimer() - job.startedAt < job.duration - 500 then return { error = 'Terlalu cepat' } end
    local err = checkTable(src, index)
    if err then return { error = err } end

    if job.transfusion then
        err = transfuse(src, s)
        if err then return { error = err } end
        return panelData(index)
    end

    local step = S.steps[job.step]
    if job.transfuse then
        err = transfuse(src, s)
        if err then return { error = err } end
    end

    local need = {}
    if step.item then need[step.item] = 1 end
    if step.kit and not s.kitPaid then need[KIT_STOCK] = 1 end
    if next(need) then
        local ok, missing = Stock.Take(need)
        if not ok then return { error = ('Stok %s di gudang habis'):format(Stock.Label(missing)) } end
        if need[KIT_STOCK] then s.kitPaid = true end
    end
    if step.bloodLoss then
        exports.f_medical:SetBloodPct(s.patient, math.max(1, exports.f_medical:GetBloodPct(s.patient) - step.bloodLoss))
    end
    if step.id == 'anesthesia' then TriggerClientEvent('f_ambulancejob:client:surgeryAnesthesia', s.patient) end

    s.step = job.step
    if s.step >= #S.steps then
        complete(index)
        return { done = true }
    end
    return panelData(index)
end)

lib.callback.register('f_ambulancejob:server:surgeryCancel', function(src, index)
    index = tonumber(index)
    local s = index and sessions[index]
    if not s or s.doctor ~= src then return { error = 'Bukan operasimu' } end
    exports.qbx_core:Notify(s.patient, 'Operasi dibatalkan.', 'error')
    endSession(index, false)
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local index, s = sessionOf(source)
    if not index then return end
    if s.doctor == source and GetPlayerPed(s.patient) ~= 0 then
        exports.qbx_core:Notify(s.patient, 'Dokter meninggalkan operasi. Operasi dibatalkan.', 'error')
    end
    endSession(index, false)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i = 1, #S.tables do GlobalState['f_amb:surgery:' .. i] = nil end
end)
