-- Armory EMS (server): tas medis & penarikan obat lama.
--  * Tas Emergency / Tas Operasi: maksimal 1 yang masih berlaku per petugas. Tas yang sudah
--    kedaluwarsa dibuang otomatis saat mengambil tas baru.
--  * Global HasValidBag(src, item) dipakai Cek Pasien & operasi (tas kedaluwarsa tidak bisa dipakai).
--  * Sekali per karakter: obat EMS lama di tas petugas EMS ditarik (Blood Bag berisi masuk Stok Gudang).

local ARMORY = 'AmbulanceArmory'
local BAGS = {
    tas_emergency = 'Emergency Bag',
    tas_operasi = 'Surgery Bag',
}

local function notify(src, msg, typ) exports.qbx_core:Notify(src, msg, typ or 'inform', 6000) end

---Durability item degrade ox_inventory = waktu kedaluwarsa (os.time).
local function expired(slot)
    local d = slot.metadata and tonumber(slot.metadata.durability)
    return d ~= nil and d > 100 and d <= os.time()
end

local function bagSlots(src, item)
    return exports.ox_inventory:Search(src, 'slots', item) or {}
end

---@return boolean
function HasValidBag(src, item)
    for _, slot in pairs(bagSlots(src, item)) do
        if not expired(slot) then return true end
    end
    return false
end

-- dipakai f_petshop (EMS menyembuhkan hewan dengan syarat tas yang sama)
exports('HasValidBag', HasValidBag)

exports.ox_inventory:registerHook('buyItem', function(payload)
    if payload.shopType ~= ARMORY then return true end
    local src, item = payload.source, payload.itemName
    if payload.count ~= 1 then
        notify(src, ('Ambil %s satu per satu.'):format(BAGS[item]), 'error')
        return false
    end
    if HasValidBag(src, item) then
        notify(src, ('Kamu sudah membawa %s.'):format(BAGS[item]), 'error')
        return false
    end
    -- buang tas kedaluwarsa setelah tas baru masuk
    local old = {}
    for _, slot in pairs(bagSlots(src, item)) do
        if expired(slot) then old[#old + 1] = slot.slot end
    end
    if #old > 0 then
        SetTimeout(0, function()
            for _, s in ipairs(old) do exports.ox_inventory:RemoveItem(src, item, 1, nil, s) end
        end)
    end
    return true
end, { itemFilter = { tas_emergency = true, tas_operasi = true } })

---------------------------------------------------------------------------
-- Penarikan obat EMS lama (sekali per karakter, hanya yang ber-job EMS saat itu)
---------------------------------------------------------------------------
local FLAG = 'ems_armory_v2'
local OLD_ITEMS = { 'bandage', 'painkillers', 'hemostatic', 'splint', 'suture', 'firstaid', 'anesthetic', 'surgical_kit', 'blood_bag' }

local function migrate(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or player.PlayerData.metadata[FLAG] then return end

    local job = player.PlayerData.job
    if job and job.type == 'ems' then
        local removed = 0
        for _, item in ipairs(OLD_ITEMS) do
            local count = exports.ox_inventory:GetItemCount(src, item) or 0
            if count > 0 and exports.ox_inventory:RemoveItem(src, item, count) then
                removed += count
                if item == 'blood_bag' then Stock.Add('blood_bag', count) end
            end
        end
        if removed > 0 then
            notify(src, 'Obat EMS di tasmu ditarik ke Stok Gudang. Ambil Emergency Bag di Armory untuk bertugas.', 'inform')
        end
    end
    -- semua karakter ditandai, supaya warga yang baru masuk EMS nanti tidak kehilangan obat pribadinya
    player.Functions.SetMetaData(FLAG, true)
end

local function migrateLater(src)
    CreateThread(function()
        Wait(5000) -- tunggu inventory pemain selesai dimuat
        while not Stock.Ready() do Wait(500) end
        migrate(src)
    end)
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function() migrateLater(source) end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, src in ipairs(GetPlayers()) do migrateLater(tonumber(src)) end
end)
