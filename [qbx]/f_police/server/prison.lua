-- Meja administrasi penjara. Pendataan (pasal + lama hukuman) dilakukan di MDT f_phone; booking
-- penjara di sana berstatus "menunggu". Di meja ini polisi on-duty melihat data tahanan yang
-- berdiri di dekat meja lalu menekan "Masukkan ke Penjara" -> f_phone mdtJailServe -> f_prison.

local sharedConfig = require 'config.shared'

local DESK_RADIUS = sharedConfig.prisonDeskRadius or 3.0

---@return vector3? titik meja terdekat dalam `range` meter dari pemain
local function deskNear(src, range)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, point in ipairs(sharedConfig.locations.prisonDesk or {}) do
        if #(pos - point) < range then return point end
    end
end

local function officerAtDesk(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not IsLeoAndOnDuty(player) then return end
    local desk = deskNear(src, 4.0)
    if not desk then return end
    return player, desk
end

local function mdtReady()
    return GetResourceState('f_phone') == 'started'
end

---@return table[] booking menunggu untuk warga ini (kosong kalau MDT mati)
local function pendingFor(officer, citizenid)
    local ok, rows = pcall(function() return exports.f_phone:mdtJailPending(officer, citizenid) end)
    return ok and type(rows) == 'table' and rows or {}
end

---Satu tahanan untuk panel: semua booking menunggu + total hukuman.
local function prisonerEntry(officer, target)
    local player = exports.qbx_core:GetPlayer(target)
    if not player then return end
    local rows = pendingFor(officer, player.PlayerData.citizenid)
    if #rows == 0 then return end

    local total, bookings = 0, {}
    for i = 1, #rows do
        local row = rows[i]
        total = total + (tonumber(row.months) or 0)
        local charges = {}
        for c = 1, #(row.charges or {}) do
            local line = row.charges[c]
            charges[c] = { code = line.code, label = line.label, count = line.count or 1 }
        end
        bookings[i] = {
            ref = row.ref,
            reportRef = row.reportRef,
            reportTitle = row.reportTitle,
            months = tonumber(row.months) or 0,
            officer = row.callsign and ('%s · %s'):format(row.callsign, row.officer) or row.officer,
            createdAt = row.createdAt,
            charges = charges,
        }
    end

    local ci = player.PlayerData.charinfo
    return {
        id = target,
        name = ('%s %s'):format(ci.firstname, ci.lastname),
        citizenid = player.PlayerData.citizenid,
        cuffed = player.PlayerData.metadata.ishandcuffed == true,
        months = total,
        bookings = bookings,
    }
end

lib.callback.register('f_police:server:prisonDesk', function(src)
    local officer, desk = officerAtDesk(src)
    if not officer then return end
    if not mdtReady() then return { error = 'MDT sedang tidak aktif' } end

    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target ~= src and #(GetEntityCoords(GetPlayerPed(target)) - desk) <= DESK_RADIUS then
            local entry = prisonerEntry(src, target)
            if entry then list[#list + 1] = entry end
        end
    end
    return { prisoners = list }
end)

---Dipakai f_phone MDT ("Penjarakan langsung"): lepas borgol/escort sebelum tahanan dipindah.
exports('ReleaseForJail', function(target)
    local prisoner = exports.qbx_core:GetPlayer(tonumber(target) or -1)
    if not prisoner or not prisoner.PlayerData.metadata.ishandcuffed then return end
    ReleaseCuffs(prisoner.PlayerData.source, prisoner.PlayerData.source)
    Wait(750)
end)

---@type table<integer, true> petugas yang sedang memproses (cegah klik ganda)
local busy = {}

lib.callback.register('f_police:server:prisonServe', function(src, target)
    target = tonumber(target)
    if not target or busy[src] then return false, 'Sedang diproses' end
    local officer, desk = officerAtDesk(src)
    if not officer then return false, 'Kamu harus on-duty dan berada di meja administrasi' end
    if not mdtReady() then return false, 'MDT sedang tidak aktif' end

    local prisoner = exports.qbx_core:GetPlayer(target)
    if not prisoner or target == src then return false, 'Tahanan tidak ditemukan' end
    if #(GetEntityCoords(GetPlayerPed(target)) - desk) > DESK_RADIUS then
        return false, 'Tahanan harus berada di dekat meja'
    end
    if #pendingFor(src, prisoner.PlayerData.citizenid) == 0 then
        return false, 'Tidak ada data penahanan di MDT untuk orang ini'
    end

    busy[src] = true
    -- lepas borgol/escort dulu: ped yang masih menempel tidak bisa dipindah ke dalam penjara
    if prisoner.PlayerData.metadata.ishandcuffed then
        ReleaseCuffs(target, src)
        Wait(750)
    end

    local ok, okServe, result = pcall(function() return exports.f_phone:mdtJailServe(src, target) end)
    busy[src] = nil
    if not ok then return false, 'Gagal menghubungi MDT' end
    if not okServe then return false, type(result) == 'string' and result or 'Hukuman tidak bisa dijalankan' end

    exports.qbx_core:Notify(target, ('Kamu dipenjara selama %d bulan.'):format(result.months), 'error')
    return true, ('%s dimasukkan ke penjara selama %d bulan.'):format(result.subject or 'Tahanan', result.months)
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)

-- Anti kabur lewat logout: tahanan yang sudah didata penjara di MDT (masih "menunggu") lalu
-- logout/disconnect sebelum sampai meja, langsung dipenjara begitu karakternya login lagi.
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    local cid = player.PlayerData.citizenid
    CreateThread(function()
        if not mdtReady() then return end
        -- cek ringan dulu: kebanyakan login tidak punya data penahanan
        local pending = MySQL.scalar.await(
            "SELECT 1 FROM phone_mdt_arrests WHERE citizenid = ? AND status = 'pending' LIMIT 1", { cid })
        if not pending then return end

        -- tunggu sampai ped benar-benar ada di dunia (spawn selesai), maks ~60 detik
        for _ = 1, 60 do
            local ped = GetPlayerPed(src)
            if ped ~= 0 and #(GetEntityCoords(ped)) > 1.0 then break end
            Wait(1000)
        end
        Wait(5000)

        local current = exports.qbx_core:GetPlayer(src)
        if not current or current.PlayerData.citizenid ~= cid then return end
        if current.PlayerData.metadata.ishandcuffed then
            ReleaseCuffs(src, src)
            Wait(750)
        end

        local okCall, served, result = pcall(function() return exports.f_phone:mdtJailServeOnLogin(src) end)
        if okCall and served then
            exports.qbx_core:Notify(src,
                ('Kamu logout saat dalam penahanan. Kamu langsung dipenjara selama %d bulan.'):format(result.months),
                'error', 10000)
        end
    end)
end)
