-- Bel lobi/kasir: warga memanggil pegawai suatu job (on-duty maupun off-duty) lewat notifikasi ox_lib.

---@type table<integer, integer> index bel -> waktu boleh dibunyikan lagi (os.time)
local nextRing = {}

---@param src number
---@param title string
---@param description string
---@param kind string
local function notify(src, title, description, kind)
    TriggerClientEvent('ox_lib:notify', src, {title = title, description = description, type = kind})
end

RegisterNetEvent('f_bell:server:ring', function(index)
    local src = source
    local bell = type(index) == 'number' and BellConfig.Bells[index]
    if not bell then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - bell.coords) > BellConfig.Distance then return end

    local now = os.time()
    if nextRing[index] and now < nextRing[index] then
        return notify(src, bell.title, ('Bel baru saja dibunyikan, tunggu %d detik lagi'):format(nextRing[index] - now), 'error')
    end

    local staff = {}
    for staffSrc, player in pairs(exports.qbx_core:GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.name == bell.job then staff[#staff + 1] = staffSrc end
    end

    if #staff == 0 then
        return notify(src, bell.title, ('Tidak ada %s di kota saat ini'):format(bell.staff), 'error')
    end

    nextRing[index] = now + BellConfig.Cooldown
    TriggerClientEvent('f_bell:client:rang', -1, bell.coords)

    for i = 1, #staff do
        TriggerClientEvent('ox_lib:notify', staff[i], {
            title = bell.title,
            description = ('Ada warga menunggu di %s'):format(bell.label),
            type = 'inform',
            icon = 'bell',
            duration = 10000,
        })
    end

    notify(src, bell.title, 'Petugas sudah dipanggil, mohon tunggu', 'success')
end)
