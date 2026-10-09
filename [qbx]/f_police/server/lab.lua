-- Lab Forensik: identifikasi pemilik DNA (darah / sampel) dan sidik jari dari kantong bukti.
-- Kode DNA di kantong bukti acak (DnaCode di main.lua), jadi identitas hanya bisa diketahui di sini.
-- Pemeriksaan = mulai (cek bukti) + selesai minimal 10 detik kemudian (progress di client).

local sharedConfig = require 'config.shared'

local BAG = 'filled_evidence_bag'
local ANALYZE_MS = 10000

---@type table<integer, { slot: integer, kind: string, value: string, started: integer }>
local analyzing = {}

local function playerOf(src)
    return exports.qbx_core:GetPlayer(src)
end

local function nearLab(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, point in ipairs(sharedConfig.locations.lab) do
        if #(pos - point) < 4.0 then return true end
    end
    return false
end

local function officerAtLab(src)
    local player = playerOf(src)
    if not player or not IsLeoAndOnDuty(player) or not nearLab(src) then return end
    return player
end

---Isi kantong bukti: ('dna', kode) / ('fingerprint', id). Kantong lama (sebelum lab) hanya punya
---deskripsi; DNA lama adalah citizenid dalam hex ('legacy').
---@return string? kind, string? value
local function readBag(meta)
    if type(meta) ~= 'table' then return end
    if meta.evidence == 'dna' and type(meta.dna) == 'string' then return 'dna', meta.dna end
    if meta.evidence == 'fingerprint' and type(meta.fingerprint) == 'string' then return 'fingerprint', meta.fingerprint end
    local desc = type(meta.description) == 'string' and meta.description or ''
    local legacy = desc:match('DNA ID: (%x+)') or (type(meta.dnalabel) == 'string' and meta.dnalabel:match('^(%x+)$'))
    if legacy then return 'legacy', legacy end
    local fid = desc:match('Fingerprint ID: (%S+)')
    if fid then return 'fingerprint', fid end
end

local function sameEvidence(kindA, valueA, kindB, valueB)
    local a = kindA == 'fingerprint' and 'f' or 'd'
    local b = kindB == 'fingerprint' and 'f' or 'd'
    return a == b and valueA == valueB
end

---@return string? citizenid
local function findOwner(kind, value)
    if kind == 'legacy' then
        local cid = value:gsub('%x%x', function(byte) return string.char(tonumber(byte, 16)) end)
        return MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { cid })
    end

    local field = kind == 'dna' and 'dnacode' or 'fingerprint'
    for _, player in pairs(exports.qbx_core:GetQBPlayers()) do
        if player.PlayerData.metadata[field] == value then return player.PlayerData.citizenid end
    end
    -- pemain offline: cari di metadata (jarang dipakai, hanya saat pemeriksaan lab)
    return MySQL.scalar.await(
        ("SELECT citizenid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.%s')) = ? LIMIT 1"):format(field),
        { value })
end

local function personInfo(cid)
    if GetResourceState('f_phone') == 'started' then
        local ok, p = pcall(function() return exports.f_phone:mdtGetTrustedPerson(cid, 'leo') end)
        if ok and type(p) == 'table' then
            return {
                name = p.name, dob = p.dob, sex = p.sex, bloodtype = p.bloodtype, mugshot = p.mugshot,
                wanted = p.wanted == true, warrants = #(p.warrants or {}), arrests = tonumber(p.arrests) or 0,
            }
        end
    end
    local raw = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { cid })
    local ci = raw and json.decode(raw) or {}
    return { name = ('%s %s'):format(ci.firstname or '?', ci.lastname or ''), dob = ci.birthdate, warrants = 0, arrests = 0 }
end

local function bagSummary(slot)
    local m = slot.metadata or {}
    local kind = readBag(m)
    return {
        slot = slot.slot,
        kind = kind == 'fingerprint' and 'fingerprint' or (m.type == 'Sampel DNA' and 'sample' or 'blood'),
        title = m.type or 'Kantong Bukti',
        street = m.street,
        collectedBy = m.collectedBy,
        collectedAt = m.collectedAt,
        bloodtype = m.bloodtype,
        identified = m.identified,
    }
end

lib.callback.register('f_police:server:labBags', function(src)
    if not officerAtLab(src) then return end
    local list = {}
    for _, slot in ipairs(exports.ox_inventory:Search(src, 'slots', BAG) or {}) do
        if readBag(slot.metadata) then list[#list + 1] = bagSummary(slot) end
    end
    return list
end)

lib.callback.register('f_police:server:labStart', function(src, slot)
    analyzing[src] = nil
    if not officerAtLab(src) then return false end
    local item = exports.ox_inventory:GetSlot(src, tonumber(slot) or -1)
    if not item or item.name ~= BAG then return false end
    local kind, value = readBag(item.metadata)
    if not kind then return false end
    analyzing[src] = { slot = item.slot, kind = kind, value = value, started = GetGameTimer() }
    return true
end)

lib.callback.register('f_police:server:labCancel', function(src)
    analyzing[src] = nil
end)

lib.callback.register('f_police:server:labResult', function(src)
    local job = analyzing[src]
    analyzing[src] = nil
    if not job or GetGameTimer() - job.started < ANALYZE_MS - 500 then return end
    local officer = officerAtLab(src)
    if not officer then return end

    local item = exports.ox_inventory:GetSlot(src, job.slot)
    if not item or item.name ~= BAG then return end
    local kind, value = readBag(item.metadata)
    if kind ~= job.kind or value ~= job.value then return end

    local result = { evidence = bagSummary(item) }
    local cid = findOwner(kind, value)
    if not cid then
        result.found = false
        return result
    end

    local person = personInfo(cid)
    result.found = true
    result.person = person

    -- kantong bukti lain di inventory petugas dengan DNA / sidik jari yang sama
    result.matches = {}
    for _, slot in ipairs(exports.ox_inventory:Search(src, 'slots', BAG) or {}) do
        if slot.slot ~= item.slot then
            local k, v = readBag(slot.metadata)
            if k and sameEvidence(k, v, kind, value) then result.matches[#result.matches + 1] = bagSummary(slot) end
        end
    end

    local meta = item.metadata
    if meta.identified ~= person.name then
        meta.identified = person.name
        local base = (meta.description or ''):gsub('\n\nTeridentifikasi: .*$', '')
        meta.description = ('%s\n\nTeridentifikasi: %s'):format(base, person.name)
        exports.ox_inventory:SetMetadata(src, item.slot, meta)
    end

    if GetResourceState('f_phone') == 'started' then
        pcall(function()
            exports.f_phone:mdtLog(src, 'lab_forensik', 'person', cid, {
                Hasil = person.name,
                Bukti = result.evidence.title,
                Lokasi = result.evidence.street or '-',
            })
        end)
    end
    return result
end)

AddEventHandler('playerDropped', function()
    analyzing[source] = nil
end)
