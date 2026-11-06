local sharedConfig = require 'config.shared'

local ox_inventory = exports.ox_inventory

local function firstSlot(src, itemName)
    local found = ox_inventory:Search(src, 1, itemName)
    for _, v in pairs(found or {}) do --luacheck: ignore
        return v
    end
end

function NewMetaDataLicense(src, itemName)
    local item = firstSlot(src, itemName)
    if not item then return end
    item.metadata.mugShot = lib.callback.await('um-idcard:client:callBack:getMugShot', src)
    -- licenses created before this feature existed (or handed out without CreateMetaLicense) won't have one yet
    item.metadata.expireDate = item.metadata.expireDate or (os.time() + LicenseExpirySeconds(itemName))
    ox_inventory:SetMetadata(src, item.slot, item.metadata)
end

--- Stamp an expiry date onto a license that already has a mugshot but predates this feature
---@param src number
---@param itemName string
---@param metadata table
local function EnsureExpireDate(src, itemName, metadata)
    if metadata.expireDate then return end

    local item = firstSlot(src, itemName)
    if not item then return end

    metadata.expireDate = os.time() + LicenseExpirySeconds(itemName)
    item.metadata.expireDate = metadata.expireDate
    ox_inventory:SetMetadata(src, item.slot, item.metadata)
end

local function notify(src, title, desc, icon, color)
    TriggerClientEvent('um-idcard:client:notifyOx', src, { title = title, desc = desc, icon = icon, iconColor = color })
end

--- Shows a card to the closest player (or to the owner when nobody is near) and plays the animation
local function displayCard(src, item, data)
    lib.callback('um-idcard:client:callBack:getClosestPlayer', src, function(player)
        local target = src
        if player and player ~= 0 then
            notify(src, 'Kartu ditunjukkan', 'Kamu menunjukkan kartumu ke pemain terdekat', 'id-card', 'green')
            target = player
        end
        TriggerClientEvent('um-idcard:client:sendData', target, data)
    end)
    TriggerClientEvent('um-idcard:client:startAnim', src, item)
end

local function formatDate(ts)
    return ts and os.date('%d.%m.%Y', ts) or nil
end

-- card item -> key in PlayerData.metadata.licences (set to false by police /revokelicense)
local LICENCE_META = { driver_license = 'driver', weaponlicense = 'weapon' }

local function showLicense(src, item, metadata)
    EnsureExpireDate(src, item, metadata)
    local isExpired = metadata.expireDate < os.time()

    local ownerPlayer = exports.qbx_core:GetPlayer(src)
    local metaKey = LICENCE_META[item]
    local licences = ownerPlayer.PlayerData.metadata.licences or {}
    local isRevoked = metaKey ~= nil and licences[metaKey] == false

    if isRevoked then
        notify(src, 'Lisensi dicabut', 'Lisensi ini sudah dicabut oleh kepolisian.', 'id-card', 'red')
    elseif isExpired then
        if item == 'ktp_sementara' then
            notify(src, 'KTP Sementara kedaluwarsa', 'Buat KTP di Balai Kota.', 'id-card', 'red')
        else
            notify(src, 'Kartu kedaluwarsa', 'Kartu ini sudah kedaluwarsa. Datangi kantor layanan untuk memperpanjang.', 'id-card', 'red')
        end
    end

    local data = table.clone(ownerPlayer.PlayerData.charinfo)
    data.sex = data.gender == 0 and 'Laki-laki' or 'Perempuan'
    data.cardtype = item or 'id_card'
    data.mugShot = metadata.mugShot
    data.job = ownerPlayer.PlayerData.job.label
    data.expired = formatDate(metadata.expireDate)
    data.isExpired = isExpired
    data.isRevoked = isRevoked

    displayCard(src, item, data)
end

local function showStnk(src, metadata)
    local vehicleId = tonumber(metadata.vehicleId)
    if not vehicleId then
        -- e.g. spawned with /giveitem: only STNKs issued at the police station carry vehicle data
        return notify(src, 'STNK kosong', 'STNK ini tidak memiliki data kendaraan. Buat STNK di kantor polisi.', 'car', 'red')
    end

    local ok, row = pcall(MySQL.single.await, [[
        SELECT pv.vehicle, pv.plate, pv.citizenid, r.version, r.citizenid AS reg_cid, r.plate_expire, r.tax_expire
        FROM player_vehicles pv
        LEFT JOIN vehicle_registrations r ON r.vehicle_id = pv.id
        WHERE pv.id = ?
    ]], { vehicleId })
    if not ok then row = nil end

    local now = os.time()
    -- invalid when the vehicle is gone, the STNK was reissued (lost) or the vehicle changed owner
    local valid = row and row.version == metadata.version and row.reg_cid == row.citizenid
        and row.reg_cid == metadata.citizenid

    local data = {
        cardtype = 'stnk',
        model = metadata.model,
        vehicle = metadata.vehicle,
        plate = row and row.plate or metadata.plate,
        owner = metadata.owner,
        issued = formatDate(metadata.issued),
        plateExpire = row and formatDate(row.plate_expire),
        plateExpired = row and row.plate_expire and row.plate_expire < now or false,
        taxExpire = row and formatDate(row.tax_expire),
        taxExpired = row and row.tax_expire and row.tax_expire < now or false,
        invalid = not valid,
    }

    if data.invalid then
        notify(src, 'STNK tidak berlaku', 'STNK ini sudah tidak berlaku.', 'car', 'red')
    elseif data.plateExpired or data.taxExpired or not data.taxExpire then
        notify(src, 'STNK', 'Masa berlaku plat atau pajak kendaraan ini perlu diperhatikan.', 'car', 'orange')
    end

    displayCard(src, 'stnk', data)
end

--- Server-only (was a net event, which let any client show forged card data to anyone)
local function useCard(src, item, metadata)
    metadata = metadata or {}
    if item == 'stnk' then return showStnk(src, metadata) end
    if metadata.mugShot then return showLicense(src, item, metadata) end
    NewMetaDataLicense(src, item)
end

local IDENTITY_ITEMS = { 'id_card', 'ktp_sementara' }

--- Identitas wajib (dipakai menu pesan f_cafe & apotek EMS): KTP atau KTP Sementara milik pemain
--- sendiri (citizenid cocok) yang belum kedaluwarsa.
---@param src number
---@return boolean ok, string? message
local function checkIdentity(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false, 'Anda tidak membawa KTP' end
    local cid, now, expired = player.PlayerData.citizenid, os.time(), false
    for _, name in ipairs(IDENTITY_ITEMS) do
        for _, slot in pairs(ox_inventory:Search(src, 'slots', name) or {}) do
            local meta = slot.metadata or {}
            if meta.citizenid == cid then
                local expire = tonumber(meta.expireDate)
                if not expire or expire > now then return true end
                expired = true
            end
        end
    end
    if expired then return false, 'KTP Anda sudah kedaluwarsa. Buat KTP di Balai Kota.' end
    return false, 'Anda tidak membawa KTP'
end

exports('CheckIdentity', checkIdentity)

--- Admin: beri KTP / KTP Sementara lengkap dengan data pemilik (spawn /giveitem tidak punya citizenid)
lib.addCommand('buatktp', {
    help = 'Beri KTP (atau KTP Sementara) berisi data pemain',
    restricted = 'group.admin',
    params = {
        { name = 'id', help = 'ID pemain (me = diri sendiri)', type = 'playerId', optional = true },
        { name = 'jenis', help = 'ktp / sementara (default ktp)', type = 'string', optional = true },
    },
}, function(source, args)
    local target = args.id or source
    local item = args.jenis == 'sementara' and 'ktp_sementara' or 'id_card'
    if not exports.qbx_core:GetPlayer(target) then
        return exports.qbx_core:Notify(source, 'Pemain tidak ditemukan', 'error')
    end
    exports.f_idcard:CreateMetaLicense(target, item)
    local label = item == 'id_card' and 'KTP' or 'KTP Sementara'
    exports.qbx_core:Notify(target, ('Anda menerima %s'):format(label), 'success')
    if target ~= source then
        exports.qbx_core:Notify(source, ('%s diberikan ke ID %s'):format(label, target), 'success')
    end
end)

function CreateRegisterItem(k)
    exports.qbx_core:CreateUseableItem(k, function(source, item)
        useCard(source, k, item.info or item.metadata)
    end)
end

for k, _ in pairs(sharedConfig.licenses) do
    CreateRegisterItem(k)
end
