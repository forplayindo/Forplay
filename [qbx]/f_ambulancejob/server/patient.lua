-- Panel "Cek Pasien" (server). Semua tindakan EMS divalidasi di sini: job EMS on duty, jarak,
-- item, kondisi pasien, dan durasi progress bar (actionStart -> actionFinish dengan jeda minimal).

local cfg = require 'config.treatment'
local WEAPONS = exports.qbx_core:GetWeapons()

local DEATH = { ALIVE = 1, LAST_STAND = 2, DEAD = 3 } -- sama dengan f_medical config.shared deathState
local BODY_PREFIX = 'f_medical:injuries:'
local BLEED_BAG = 'f_medical:bleedLevel'

---@type table<number, { target: number, action: string, part?: string, startedAt: number, duration: number }>
local pending = {}

---Pasien tergeletak yang sudah ditransfusi: saat di-revive darahnya penuh, bukan afterRevive.
---@type table<number, true>
local transfused = {}

local function isEms(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == 'ems' and job.onduty, player
end

local function isNear(src, target, dist)
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= (dist or cfg.distance)
end

local function getInjuries(target)
    local state = Player(target).state
    local list = {}
    for part in pairs(cfg.bodyParts) do
        local injury = state[BODY_PREFIX .. part]
        if type(injury) == 'table' and tonumber(injury.severity) then
            list[part] = injury
        end
    end
    return list
end

local function getBleed(target)
    return tonumber(Player(target).state[BLEED_BAG]) or 0
end

---Item yang dibutuhkan untuk mengobati satu area.
local function partNeed(part, severity)
    if severity <= 2 then return 'bandage', 'light' end
    return cfg.bodyParts[part].kind == 'limb' and 'splint' or 'suture', 'heavy'
end

local function bleedNeed(level)
    if level <= 0 then return nil end
    return level >= cfg.heavyBleed and 'hemostatic' or 'bandage'
end

---Total item untuk "Obati Semua".
local function allCost(target)
    local cost, services = {}, {}
    local function add(item, service)
        cost[item] = (cost[item] or 0) + 1
        services[#services + 1] = service
    end
    local bItem = bleedNeed(getBleed(target))
    if bItem then add(bItem, 'bleed') end
    for part, injury in pairs(getInjuries(target)) do
        -- luka perlu operasi yang sudah distabilkan tidak bisa diobati lagi di lapangan
        if not (injury.stabilized and NeedsSurgery(part, injury)) then
            local item, service = partNeed(part, injury.severity)
            add(item, service)
        end
    end
    return cost, services
end

---Darah maksimal: 60% selama ada luka yang perlu operasi, selain itu 100%.
local function bloodCeiling(target)
    return #SurgeryParts(target) > 0 and cfg.surgery.bloodCap or 100
end

local BAG = 'tas_emergency'

---Stok Gudang per kunci item panel (cfg.items: kunci -> nama item = kunci Stok).
local function stockOf()
    local out = {}
    for key, name in pairs(cfg.items) do out[key] = Stock.Get(name) end
    return out
end

---Kunci item panel -> kebutuhan Stok Gudang.
local function stockNeed(items)
    local need = {}
    for key, count in pairs(items) do need[cfg.items[key]] = (need[cfg.items[key]] or 0) + count end
    return need
end

local function deathStateOf(target)
    return exports.f_medical:GetDeathState(target)
end

---Jeda countdown f_deathscreen selama EMS menangani (seperti dokter AI). Dipanggil berulang sebagai
---heartbeat (buka panel, refresh 2 detik, mulai/selesai tindakan); lepas saat panel ditutup.
local function holdCountdown(target, active)
    pcall(function() exports.f_deathscreen:SetEmsTreating(target, active) end)
end

local function buildStatus(src, target)
    local patient = exports.qbx_core:GetPlayer(target)
    if not patient then return end
    local ci = patient.PlayerData.charinfo or {}
    local death = deathStateOf(target)

    local injuries = {}
    for part, injury in pairs(getInjuries(target)) do
        local weapon = injury.weaponHash and WEAPONS[injury.weaponHash]
        injuries[#injuries + 1] = {
            part = part,
            severity = injury.severity,
            cause = weapon and weapon.label or 'Tidak diketahui',
            surgery = NeedsSurgery(part, injury),
            stabilized = injury.stabilized == true,
        }
    end

    local remaining
    if death ~= DEATH.ALIVE then
        local ok, value = pcall(function() return exports.f_deathscreen:GetRemaining(target) end)
        remaining = ok and value or nil
    else
        transfused[target] = nil -- sudah sadar (revive / RS): tanda transfusi tidak berlaku lagi
    end

    return {
        id = target,
        name = ('%s %s'):format(ci.firstname or '', ci.lastname or ''),
        down = death ~= DEATH.ALIVE,
        remaining = remaining,
        blood = exports.f_medical:GetBloodPct(target),
        bleed = getBleed(target),
        transfused = transfused[target] == true,
        recovery = Recovery.Get(target),
        pendingBill = Billing.PendingCount(patient.PlayerData.citizenid),
        hasCrutch = exports.ox_inventory:Search(target, 'count', cfg.items.crutch) > 0,
        injuries = injuries,
        stock = stockOf(),
        bag = HasValidBag(src, BAG),
    }
end

---Validasi umum. Mengembalikan pesan error (string) atau nil kalau aman.
local function checkCommon(src, target)
    target = tonumber(target)
    if not target or target == src or not exports.qbx_core:GetPlayer(target) then return 'Pasien tidak ditemukan' end
    if not isEms(src) then return 'Hanya EMS yang sedang bertugas' end
    if not isNear(src, target) then return 'Pasien terlalu jauh' end
    if deathStateOf(src) ~= DEATH.ALIVE then return 'Kamu sedang tidak sadar' end
end

---Syarat tiap tindakan. Mengembalikan error, atau { items = {name = count}, duration, services }.
local function plan(src, target, action, part)
    if not HasValidBag(src, BAG) then return 'Kamu tidak membawa Emergency Bag yang masih berlaku (ambil di Armory)' end
    local death = deathStateOf(target)
    local stock = stockOf()
    local function need(map)
        for key, count in pairs(map) do
            if (stock[key] or 0) < count then return ('Stok %s di gudang habis'):format(cfg.itemLabels[key] or key) end
        end
    end

    if action == 'part' then
        local def = cfg.bodyParts[part]
        local injury = def and getInjuries(target)[part]
        if not injury then return 'Tidak ada luka di area itu' end
        if injury.stabilized and NeedsSurgery(part, injury) then return 'Luka ini sudah distabilkan, perlu operasi' end
        local item, service = partNeed(part, injury.severity)
        local err = need({ [item] = 1 })
        if err then return err end
        return { items = { [item] = 1 }, duration = cfg.durations.treat, services = { service } }

    elseif action == 'bleed' then
        local item = bleedNeed(getBleed(target))
        if not item then return 'Pasien tidak berdarah' end
        local err = need({ [item] = 1 })
        if err then return err end
        return { items = { [item] = 1 }, duration = cfg.durations.bleed, services = { 'bleed' } }

    elseif action == 'all' then
        local cost, services = allCost(target)
        if #services == 0 then return 'Tidak ada yang perlu diobati' end
        local err = need(cost)
        if err then return err end
        return { items = cost, duration = cfg.durations.all, services = services }

    elseif action == 'painkiller' then
        if death ~= DEATH.ALIVE then return 'Pasien tidak sadar' end
        local err = need({ painkillers = 1 })
        if err then return err end
        return { items = { painkillers = 1 }, duration = cfg.durations.painkiller, services = { 'painkiller' } }

    elseif action == 'transfusion' then
        if death == DEATH.ALIVE then
            if exports.f_medical:GetBloodPct(target) >= cfg.blood.critical then
                return ('Darah pasien masih di atas %d%%'):format(cfg.blood.critical)
            end
        elseif transfused[target] then
            return 'Pasien sudah ditransfusi'
        end
        local err = need({ bloodBag = 1 })
        if err then return err end
        return { items = { bloodBag = 1 }, duration = cfg.durations.transfusion, services = { 'transfusion' } }

    elseif action == 'crutch' then
        if not Recovery.Get(target) then return 'Pasien tidak sedang masa pemulihan' end
        if exports.ox_inventory:Search(target, 'count', cfg.items.crutch) > 0 then return 'Pasien sudah punya Crutch' end
        if not exports.ox_inventory:CanCarryItem(target, cfg.items.crutch, 1) then return 'Tas pasien penuh' end
        local err = need({ crutch = 1 })
        if err then return err end
        return { items = { crutch = 1 }, duration = cfg.durations.crutch, services = { 'crutch' } }

    elseif action == 'revive' then
        if death == DEATH.ALIVE then return 'Pasien sudah sadar' end
        if getBleed(target) >= cfg.heavyBleed then return 'Hentikan pendarahan berat dulu' end
        local err = need({ firstaid = 1 })
        if err then return err end
        return { items = { firstaid = 1 }, duration = cfg.durations.revive, services = { 'revive' } }
    end

    return 'Tindakan tidak dikenal'
end

---Darah setelah diobati: di bawah batas kritis hanya bisa naik sampai batas kritis.
local function raiseBlood(target, amount)
    if deathStateOf(target) ~= DEATH.ALIVE then return end
    local current = exports.f_medical:GetBloodPct(target)
    local cap = current < cfg.blood.critical and cfg.blood.critical or bloodCeiling(target)
    local new = amount == 'max' and cap or math.min(cap, current + amount)
    if new > current then exports.f_medical:SetBloodPct(target, new) end
end

---Splint di kaki / telapak / tulang belakang memulai masa pemulihan (wajib Crutch).
local function startRecoveryIfSplint(target, part, injury)
    if not injury or not cfg.recovery.parts[part] then return end
    if partNeed(part, injury.severity) == 'splint' then Recovery.Start(target, part) end
end

---Obati satu area: luka yang perlu operasi hanya distabilkan, selain itu sembuh.
local function treatPart(target, part, injury)
    if NeedsSurgery(part, injury) then
        if not injury.stabilized then StabilizeInjury(target, part, injury) end
        return
    end
    startRecoveryIfSplint(target, part, injury)
    exports.f_medical:HealBodyPart(target, part)
end

local function apply(target, action, part)
    if action == 'part' then
        local injury = getInjuries(target)[part]
        if injury then treatPart(target, part, injury) end
        raiseBlood(target, cfg.blood.perTreat)

    elseif action == 'bleed' then
        exports.f_medical:SetBleedLevel(target, 0)

    elseif action == 'all' then
        for p, injury in pairs(getInjuries(target)) do treatPart(target, p, injury) end
        exports.f_medical:SetBleedLevel(target, 0)
        raiseBlood(target, 'max')

    elseif action == 'crutch' then
        exports.ox_inventory:AddItem(target, cfg.items.crutch, 1)
        TriggerClientEvent('f_ambulancejob:client:crutchGiven', target)

    elseif action == 'painkiller' then
        TriggerClientEvent('f_ambulancejob:client:painkillerEffect', target)

    elseif action == 'transfusion' then
        if deathStateOf(target) == DEATH.ALIVE then
            exports.f_medical:SetBloodPct(target, bloodCeiling(target))
        else
            transfused[target] = true -- darah penuh begitu di-revive
        end

    elseif action == 'revive' then
        exports.f_medical:ReviveKeepInjuries(target, transfused[target] and bloodCeiling(target) or cfg.blood.afterRevive)
        transfused[target] = nil
    end
end

lib.callback.register('f_ambulancejob:server:patientOpen', function(src, target)
    local err = checkCommon(src, target)
    if err then return { error = err } end
    target = tonumber(target) --[[@as number]]
    holdCountdown(target, true)
    return { status = buildStatus(src, target) }
end)

lib.callback.register('f_ambulancejob:server:patientStatus', function(src, target)
    target = tonumber(target)
    if not target or not isEms(src) or not isNear(src, target, cfg.closeDistance) then return end
    holdCountdown(target, true)
    return buildStatus(src, target)
end)

lib.callback.register('f_ambulancejob:server:patientClose', function(src, target)
    target = tonumber(target)
    if not target or not isEms(src) then return end
    holdCountdown(target, false)
end)

lib.callback.register('f_ambulancejob:server:actionStart', function(src, target, action, part)
    local err = checkCommon(src, target)
    if err then return { error = err } end
    target = tonumber(target) --[[@as number]]
    holdCountdown(target, true)
    local p = plan(src, target, action, part)
    if type(p) == 'string' then return { error = p } end
    pending[src] = { target = target, action = action, part = part, startedAt = GetGameTimer(), duration = p.duration }
    return { duration = p.duration }
end)

lib.callback.register('f_ambulancejob:server:actionFinish', function(src)
    local job = pending[src]
    pending[src] = nil
    if not job then return { error = 'Tidak ada tindakan berjalan' } end
    if GetGameTimer() - job.startedAt < job.duration - 500 then return { error = 'Tindakan terlalu cepat' } end

    local err = checkCommon(src, job.target)
    if err then return { error = err } end
    -- kondisi bisa berubah selama progress (pasien sembuh, item dipindah, dll.)
    local p = plan(src, job.target, job.action, job.part)
    if type(p) == 'string' then return { error = p } end

    -- obat dari Stok Gudang (dicek ulang: stok bisa dipakai petugas lain selama progress)
    local ok, missing = Stock.Take(stockNeed(p.items))
    if not ok then return { error = ('Stok %s di gudang habis'):format(Stock.Label(missing)) } end

    apply(job.target, job.action, job.part)
    for i = 1, #p.services do Billing.Record(src, job.target, p.services[i]) end

    -- beri waktu state bag pasien tersinkron sebelum status dikirim balik
    Wait(300)
    return { status = buildStatus(src, job.target) }
end)

lib.callback.register('f_ambulancejob:server:actionCancel', function(src)
    pending[src] = nil
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    transfused[source] = nil
end)
