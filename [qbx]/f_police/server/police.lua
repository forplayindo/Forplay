-- Server untuk ox_target polisi: ambil DNA, cek plat, dan catatan penggeledahan ke Logs MDT
-- (f_phone). Satu penggeledahan = satu baris log saat inventory ditutup, jadi ringan.

local text = require 'config.criminal'.text
local serverConfig = require 'config.server'

local function playerOf(src)
    return exports.qbx_core:GetPlayer(src)
end

local function distance(a, b)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b)))
end

local function trimPlate(plate)
    return (plate or ''):match('^%s*(.-)%s*$')
end

-- Ambil DNA ---------------------------------------------------------------------------------

RegisterNetEvent('f_police:server:takeDna', function(target)
    local src = source
    target = tonumber(target)
    if not target or target == src then return end

    local officer, suspect = playerOf(src), playerOf(target)
    if not officer or not suspect or not IsLeoAndOnDuty(officer) then return end
    if distance(src, target) > 2.5 then return end

    local meta = suspect.PlayerData.metadata
    if not (meta.ishandcuffed or meta.isdead or meta.inlaststand or Player(target).state.isDead) then return end

    if not exports.ox_inventory:RemoveItem(src, 'empty_evidence_bag', 1) then
        return exports.qbx_core:Notify(src, locale('error.have_evidence_bag'), 'error')
    end

    -- kode DNA acak; siapa pemiliknya hanya bisa diketahui di Lab Forensik
    exports.ox_inventory:AddItem(src, 'filled_evidence_bag', 1,
        EvidenceMeta(officer, 'sample', { dna = DnaCode(suspect) }, 'Sampel langsung dari tersangka'))
end)

-- Cek plat ----------------------------------------------------------------------------------

lib.callback.register('f_police:server:plateInfo', function(src, netId)
    local officer = playerOf(src)
    if not officer or not IsLeoAndOnDuty(officer) then return end

    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 8.0 then return end

    local plate = trimPlate(GetVehicleNumberPlateText(veh))
    local row = MySQL.single.await([[
        SELECT p.charinfo FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid
        WHERE pv.plate = ? LIMIT 1
    ]], { plate })

    local owner
    if row then
        local ci = row.charinfo and json.decode(row.charinfo) or {}
        owner = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
    end

    -- tanda dicuri / BOLO dari data kendaraan di MDT
    local flags = PlateFlags(plate) or {}
    local marks = {}
    if flags.stolen then marks[#marks + 1] = 'DICURI' end
    if flags.bolo then marks[#marks + 1] = 'BOLO' end
    return {
        plate = plate,
        owner = owner,
        flagged = #marks > 0,
        reason = table.concat(marks, ' · '),
    }
end)

-- Administrasi / tilang (data & penebusan di f_cityhall) --------------------------------------

local function ticketOptions()
    if GetResourceState('f_cityhall') ~= 'started' then return end
    local ok, opts = pcall(function() return exports.f_cityhall:TicketOptions() end)
    return ok and opts or nil
end

local function mdtLog(src, cid, details)
    if GetResourceState('f_phone') ~= 'started' then return end
    pcall(function() exports.f_phone:mdtLog(src, 'tilang', 'person', cid, details) end)
end

local function fullName(player)
    local ci = player.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end

---Polisi on-duty yang berdiri dekat target. Mengembalikan officer, suspect.
local function officerNear(src, target)
    target = tonumber(target)
    if not target or target == src then return end
    local officer, suspect = playerOf(src), playerOf(target)
    if not officer or not suspect or not IsLeoAndOnDuty(officer) then return end
    if distance(src, target) > 3.0 then return end
    return officer, suspect, target
end

local function canRevoke(officer)
    return officer.PlayerData.job.grade.level >= serverConfig.licenseRank
end

local function revokeRankLabel(officer)
    local job = exports.qbx_core:GetJob(officer.PlayerData.job.name)
    local grade = job and job.grades and job.grades[serverConfig.licenseRank]
    return grade and grade.name or ('grade %d'):format(serverConfig.licenseRank)
end

-- Cabut lisensi: kartu diambil dari inventory, status lisensi mati. Tidak bisa diperpanjang atau
-- ditebus; pemain harus mengajukan baru di loket polisi (f_cityhall sudah mengenali status ini).
lib.callback.register('f_police:server:revokeLicense', function(src, target, kind, note)
    local officer, suspect, tsrc = officerNear(src, target)
    if not suspect then return { ok = false, msg = 'Target terlalu jauh.' } end
    if not canRevoke(officer) then return { ok = false, msg = ('Khusus pangkat %s ke atas.'):format(revokeRankLabel(officer)) } end

    local info = serverConfig.licenseItems[kind]
    if not info then return { ok = false, msg = 'Data tidak valid.' } end
    local licences = suspect.PlayerData.metadata.licences or {}
    if licences[kind] ~= true then return { ok = false, msg = ('%s target sudah tidak aktif.'):format(info.label) } end

    licences[kind] = false
    suspect.Functions.SetMetaData('licences', licences)
    local count = exports.ox_inventory:GetItemCount(tsrc, info.item) or 0
    if count > 0 then exports.ox_inventory:RemoveItem(tsrc, info.item, count) end
    if GetResourceState('f_cityhall') == 'started' then
        -- kartu yang sedang ditahan (tilang) ikut hangus
        pcall(function() exports.f_cityhall:ForfeitItem(suspect.PlayerData.citizenid, info.item) end)
    end

    note = type(note) == 'string' and note:sub(1, 100) or ''
    exports.qbx_core:Notify(tsrc, ('%s kamu dicabut polisi. Ajukan baru di loket Kantor Polisi.'):format(info.label), 'error')
    mdtLog(src, suspect.PlayerData.citizenid, {
        Tersangka = fullName(suspect), Jenis = ('Cabut %s'):format(info.label), Catatan = note ~= '' and note or '-',
    })
    return { ok = true, msg = ('%s milik %s dicabut.'):format(info.label, fullName(suspect)) }
end)

lib.callback.register('f_police:server:ticketOptions', function(src)
    local officer = playerOf(src)
    if not officer or not IsLeoAndOnDuty(officer) then return end
    return ticketOptions()
end)

lib.callback.register('f_police:server:issueFine', function(src, target, indexes)
    local _, suspect, tsrc = officerNear(src, target)
    if not suspect or type(indexes) ~= 'table' then return { ok = false, msg = 'Target terlalu jauh.' } end
    if not ticketOptions() then return { ok = false, msg = 'Layanan tilang sedang tidak tersedia.' } end
    local ok, msg, total = exports.f_cityhall:IssueFine(src, tsrc, indexes)
    if ok then mdtLog(src, suspect.PlayerData.citizenid, { Tersangka = fullName(suspect), Jenis = 'Denda', Nominal = ('Rp %d'):format(total or 0) }) end
    return { ok = ok == true, msg = msg }
end)

---Semua yang dibutuhkan panel Administrasi dalam satu panggilan: daftar harga/denda, dan kalau ada
---orang di dekat petugas: nama, apakah membawa SIM, dan STNK yang dibawanya.
lib.callback.register('f_police:server:adminData', function(src, target)
    local officer = playerOf(src)
    if not officer or not IsLeoAndOnDuty(officer) then return end
    local opts = ticketOptions()
    if not opts then
        exports.qbx_core:Notify(src, 'Layanan tilang sedang tidak tersedia.', 'error')
        return
    end

    local data = { opts = opts, canRevoke = canRevoke(officer), revokeRank = revokeRankLabel(officer) }
    local _, suspect, tsrc = officerNear(src, target)
    if suspect then
        local sim = exports.ox_inventory:Search(tsrc, 'slots', opts.simItem)
        local stnks = {}
        for _, slot in ipairs(exports.ox_inventory:Search(tsrc, 'slots', opts.stnkItem) or {}) do
            local m = slot.metadata or {}
            stnks[#stnks + 1] = { slot = slot.slot, plate = m.plate or '-', vehicle = m.vehicle or '' }
        end
        local licences = suspect.PlayerData.metadata.licences or {}
        local active = {}
        for kind, info in pairs(serverConfig.licenseItems) do
            if licences[kind] == true then active[#active + 1] = { kind = kind, label = info.label } end
        end
        table.sort(active, function(a, b) return a.label < b.label end)
        data.target = { name = fullName(suspect), hasSim = sim ~= nil and sim[1] ~= nil, stnks = stnks, licences = active }
    end
    return data
end)

lib.callback.register('f_police:server:holdDocument', function(src, target, kind, slot, note)
    local _, suspect, tsrc = officerNear(src, target)
    local opts = suspect and ticketOptions()
    if not opts then return { ok = false, msg = 'Target terlalu jauh.' } end

    if kind == 'sim' then
        local found = exports.ox_inventory:Search(tsrc, 'slots', opts.simItem)
        slot = found and found[1] and found[1].slot
        if not slot then return { ok = false, msg = 'Target tidak membawa SIM.' } end
    elseif kind ~= 'stnk' then
        return { ok = false, msg = 'Data tidak valid.' }
    end

    local ok, msg = exports.f_cityhall:HoldDocument(src, tsrc, kind, slot, note)
    if ok then mdtLog(src, suspect.PlayerData.citizenid, { Tersangka = fullName(suspect), Jenis = kind == 'sim' and 'Tahan SIM' or 'Tahan STNK' }) end
    return { ok = ok == true, msg = msg }
end)

RegisterNetEvent('f_police:server:seizeVehicle', function(netId, reasonIndex, body, engine, fuel)
    local src = source
    local officer = playerOf(src)
    if not officer or not IsLeoAndOnDuty(officer) then return end

    local opts = ticketOptions()
    local reason = opts and opts.vehicleReasons[tonumber(reasonIndex) or 0]
    if not reason then return end

    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 8.0 then return end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return end

    local plate = trimPlate(GetVehicleNumberPlateText(veh))
    local row = MySQL.single.await('SELECT id, citizenid, plate, vehicle FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    DeleteEntity(veh)

    if not row then
        return exports.qbx_core:Notify(src, 'Kendaraan lokal, hanya diderek.', 'inform')
    end

    ImpoundForever(math.floor(tonumber(body) or 1000), math.floor(tonumber(engine) or 1000), math.floor(tonumber(fuel) or 100), plate)
    local ok, msg = exports.f_cityhall:HoldVehicle(src, row, reasonIndex)
    exports.qbx_core:Notify(src, msg or 'Kendaraan disita.', ok and 'success' or 'error')
    if ok then
        mdtLog(src, row.citizenid, { Jenis = 'Sita Kendaraan', Plat = plate, Alasan = reason.label })
    end
end)

-- Catatan penggeledahan ke MDT ---------------------------------------------------------------

---@type table<integer, { target: integer, cid: string, name: string, taken: table<string, integer>, given: table<string, integer> }>
local searches = {}
local itemList

local function labelOf(name)
    itemList = itemList or exports.ox_inventory:Items()
    local item = itemList and itemList[name]
    return item and item.label or name
end

local function describe(list)
    local parts = {}
    for name, count in pairs(list) do
        if name == 'money' or name == 'black_money' then
            parts[#parts + 1] = ('%s Rp %d'):format(labelOf(name), count)
        else
            parts[#parts + 1] = ('%s x%d'):format(labelOf(name), count)
        end
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ', ') or '-'
end

local function writeSearchLog(officer, s)
    if GetResourceState('f_phone') ~= 'started' then return end
    pcall(function()
        exports.f_phone:mdtLog(officer, 'penggeledahan', 'person', s.cid, {
            Tersangka = s.name,
            Diambil = describe(s.taken),
            Dimasukkan = describe(s.given),
        })
    end)
end

AddEventHandler('ox_inventory:openedInventory', function(playerId, inventoryId)
    local target = tonumber(inventoryId)
    if not target or target == playerId then return end

    local officer, suspect = playerOf(playerId), playerOf(target)
    if not officer or not suspect or not IsLeoAndOnDuty(officer) then return end

    local ci = suspect.PlayerData.charinfo
    searches[playerId] = {
        target = target,
        cid = suspect.PlayerData.citizenid,
        name = ('%s %s'):format(ci.firstname, ci.lastname),
        taken = {},
        given = {},
    }
    exports.qbx_core:Notify(target, text.beingSearched, 'inform')

    -- f_dirtymoney: polisi melihat bagian kotor dari cash tersangka. Cash yang diambil = kotor dulu,
    -- jadi mengambil cash sejumlah ini = menyita uang kotornya (tetap kotor di inventory polisi).
    if GetResourceState('f_dirtymoney') == 'started' then
        local dirty = exports.f_dirtymoney:GetDirty(target) or 0
        if dirty > 0 then
            exports.qbx_core:Notify(playerId, ('Uang Kotor tersangka: Rp %s. Ambil cash sejumlah itu untuk menyita.'):format(lib.math.groupdigits(dirty, '.')), 'warning', 10000)
        else
            exports.qbx_core:Notify(playerId, 'Tersangka tidak membawa uang kotor.', 'inform')
        end
    end
end)

AddEventHandler('ox_inventory:closedInventory', function(playerId, inventoryId)
    local s = searches[playerId]
    if not s or tonumber(inventoryId) ~= s.target then return end
    searches[playerId] = nil
    writeSearchLog(playerId, s)
end)

AddEventHandler('playerDropped', function()
    local s = searches[source]
    if not s then return end
    searches[source] = nil
    writeSearchLog(source, s)
end)

local function add(list, slot, count)
    if type(slot) ~= 'table' or not slot.name then return end
    list[slot.name] = (list[slot.name] or 0) + (tonumber(count) or 0)
end

local function registerSearchHook()
    -- catat barang yang keluar dari / masuk ke inventory tersangka selama digeledah
    exports.ox_inventory:registerHook('swapItems', function(p)
        local s = searches[p.source]
        if not s then return end

        local from, to = tonumber(p.fromInventory), tonumber(p.toInventory)
        if from == to then return end
        local swap = p.action == 'swap'

        if from == s.target then
            add(s.taken, p.fromSlot, swap and p.fromSlot.count or p.count)
            if swap then add(s.given, p.toSlot, p.toSlot.count) end
        elseif to == s.target then
            add(s.given, p.fromSlot, swap and p.fromSlot.count or p.count)
            if swap then add(s.taken, p.toSlot, p.toSlot.count) end
        end
    end)
end

CreateThread(function()
    if GetResourceState('ox_inventory') == 'started' then registerSearchHook() end
end)

AddEventHandler('onServerResourceStart', function(resource)
    if resource == 'ox_inventory' then
        itemList = nil
        registerSearchHook()
    end
end)
