-- Donor darah (server). EMS on duty mengambil darah pemain lewat ox_target "Ambil Darah":
-- pendonor harus setuju (pop-up), sadar, darah >= minBlood, tanpa luka berat / pendarahan, dan
-- lewat cooldown. Kantong kosong EMS berubah jadi blood_bag berisi golongan darah pendonor.
-- Imbalan pendonor diurus manual lewat RP (tidak di-script).

local cfg = require 'config.treatment'
local donor = cfg.donor

local BODY_PREFIX = 'f_medical:injuries:'
local BLEED_BAG = 'f_medical:bleedLevel'

---@type table<number, { target: number, startedAt: number }>
local pending = {}
---@type table<number, true> pendonor yang sedang ditanya / diambil darahnya
local busyDonor = {}

local function isEms(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData.job
    return job and job.type == 'ems' and job.onduty, player
end

local function isNear(src, target)
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= cfg.distance
end

local function charName(player)
    local ci = player.PlayerData.charinfo or {}
    return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
end

---Syarat pendonor. Mengembalikan pesan error atau nil.
local function checkDonor(src, target)
    target = tonumber(target)
    local patient = target and exports.qbx_core:GetPlayer(target)
    if not patient or target == src then return 'Pemain tidak ditemukan' end
    if not isEms(src) then return 'Hanya EMS yang sedang bertugas' end
    if not isNear(src, target) then return 'Pemain terlalu jauh' end
    if exports.f_medical:GetDeathState(src) ~= 1 then return 'Kamu sedang tidak sadar' end
    if exports.f_medical:GetDeathState(target) ~= 1 then return 'Pendonor harus sadar' end

    local blood = exports.f_medical:GetBloodPct(target)
    if blood < donor.minBlood then return ('Darah pendonor kurang dari %d%%'):format(donor.minBlood) end

    local state = Player(target).state
    if (tonumber(state[BLEED_BAG]) or 0) > 0 then return 'Pendonor sedang berdarah' end
    for part in pairs(cfg.bodyParts) do
        local injury = state[BODY_PREFIX .. part]
        if type(injury) == 'table' and (tonumber(injury.severity) or 0) >= 3 then
            return 'Pendonor punya luka berat'
        end
    end

    local last = tonumber(patient.PlayerData.metadata.lastblooddonation) or 0
    local wait = last + donor.cooldown * 60 - os.time()
    if wait > 0 then return ('Pendonor baru saja donor, tunggu %d menit lagi'):format(math.ceil(wait / 60)) end

    if exports.ox_inventory:Search(src, 'count', donor.emptyBag) < 1 then return 'Kamu tidak punya Empty Blood Bag' end
end

lib.callback.register('f_ambulancejob:server:donorStart', function(src, target)
    local err = checkDonor(src, target)
    if err then return { error = err } end
    target = tonumber(target) --[[@as number]]
    if busyDonor[target] then return { error = 'Pemain sedang ditangani EMS lain' } end

    -- pendonor wajib setuju (mencegah ambil darah paksa dari orang yang diikat / tidak berdaya)
    busyDonor[target] = true
    local ems = exports.qbx_core:GetPlayer(src)
    local agreed = lib.callback.await('f_ambulancejob:client:donorConsent', target, charName(ems), donor.bloodLoss, donor.consentTimeout)
    busyDonor[target] = nil
    if not agreed then return { error = 'Pemain menolak donor darah' } end

    -- kondisi bisa berubah selama menunggu jawaban
    err = checkDonor(src, target)
    if err then return { error = err } end

    busyDonor[target] = true
    pending[src] = { target = target, startedAt = GetGameTimer() }
    return { duration = donor.duration }
end)

lib.callback.register('f_ambulancejob:server:donorFinish', function(src)
    local job = pending[src]
    pending[src] = nil
    if not job then return { error = 'Tidak ada pengambilan darah berjalan' } end
    busyDonor[job.target] = nil
    if GetGameTimer() - job.startedAt < donor.duration - 500 then return { error = 'Terlalu cepat' } end

    local err = checkDonor(src, job.target)
    if err then return { error = err } end

    local patient = exports.qbx_core:GetPlayer(job.target)
    local bloodtype = patient.PlayerData.metadata.bloodtype or '?'
    if not exports.ox_inventory:RemoveItem(src, donor.emptyBag, 1) then return { error = 'Item gagal diambil' } end
    -- darah hasil donor langsung masuk Stok Gudang (tidak lewat tas petugas)
    Stock.Add(cfg.items.bloodBag, 1)

    patient.Functions.SetMetaData('lastblooddonation', os.time())
    local blood = exports.f_medical:GetBloodPct(job.target)
    exports.f_medical:SetBloodPct(job.target, math.max(1, blood - donor.bloodLoss))
    TriggerClientEvent('f_ambulancejob:client:donorWeak', job.target, donor.weakTime)

    return { ok = true, bloodtype = bloodtype, stock = Stock.Get(cfg.items.bloodBag) }
end)

lib.callback.register('f_ambulancejob:server:donorCancel', function(src)
    local job = pending[src]
    pending[src] = nil
    if job then busyDonor[job.target] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local job = pending[src]
    if job then busyDonor[job.target] = nil end
    pending[src] = nil
    busyDonor[src] = nil
end)
