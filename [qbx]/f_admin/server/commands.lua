---------------------------------------------------------------------------
-- Command chat (pindahan f_adminmenu). Command dengan restricted = 'group.admin'
-- ikut aturan Daftar Command lewat ACE command.<nama>.
---------------------------------------------------------------------------
lib.addCommand('admin', { help = 'Buka panel admin (staff)' }, function(src)
    OpenPanel(src)
end)

local function lapor(src, args, raw)
    local text = raw and raw:match('^%S+%s+(.+)$')
    if text and text:gsub('%s', '') ~= '' then
        local ok, msg = SendReport(src, text, 'Lainnya')
        if not ok then Notify(src, msg, 'error') end
        return
    end
    TriggerClientEvent('f_admin:client:lapor', src, true)
end

lib.addCommand('lapor', {
    help = 'Lapor ke staff (tanpa isi = buka form)',
    params = { { name = 'isi', help = 'Isi laporan (opsional)', type = 'longString', optional = true } },
}, lapor)

lib.addCommand('report', {
    help = 'Lapor ke staff (sama dengan /lapor)',
    params = { { name = 'isi', help = 'Isi laporan (opsional)', type = 'longString', optional = true } },
}, lapor)

-- mode staff lewat chat: izin sama dengan tombol di panel (dicek di sini, bukan lewat ACE command)
local function staffToggle(mode, key)
    return function(src)
        if not Can(src, key) then return Notify(src, 'Tidak punya izin.', 'error') end
        TriggerClientEvent('f_admin:client:toggle', src, mode)
    end
end
lib.addCommand('noclip', { help = 'Noclip on/off (staff)' }, staffToggle('noclip', 'self.noclip'))
lib.addCommand('names', { help = 'Nama pemain di atas kepala (staff)' }, staffToggle('names', 'self.names'))
-- /blips sudah dipakai editor f_blips
lib.addCommand('blippemain', { help = 'Blip semua pemain di peta (staff)' }, staffToggle('blips', 'self.blips'))

local function copyTo(kind)
    return function(src) TriggerClientEvent('f_admin:client:copy', src, kind) end
end
lib.addCommand('vec2', { help = 'Salin vector2 ke clipboard', restricted = 'group.admin' }, copyTo('vec2'))
lib.addCommand('vec3', { help = 'Salin vector3 ke clipboard', restricted = 'group.admin' }, copyTo('vec3'))
lib.addCommand('vec4', { help = 'Salin vector4 ke clipboard', restricted = 'group.admin' }, copyTo('vec4'))
lib.addCommand('heading', { help = 'Salin heading ke clipboard', restricted = 'group.admin' }, copyTo('heading'))

lib.addCommand('setmodel', {
    help = 'Ganti model karakter (diri sendiri atau pemain lain)',
    restricted = 'group.admin',
    params = {
        { name = 'model', help = 'Model ped', type = 'string' },
        { name = 'id', help = 'ID pemain', type = 'playerId', optional = true },
    },
}, function(src, args)
    local target = args.id or src
    TriggerClientEvent('f_admin:client:setModel', target, args.model)
    Log(src, 'self', ('mengganti model ped %s ke %s'):format(target == src and 'sendiri' or ('**' .. Who(target) .. '**'), args.model), target ~= src and target or nil)
end)

lib.addCommand('admincar', {
    help = 'Simpan kendaraan yang kamu naiki sebagai milik (kamu atau pemain tertentu)',
    restricted = 'group.admin',
    params = { { name = 'id', type = 'playerId', help = 'ID pemilik baru (bawaan: kamu)', optional = true } },
}, function(src, args)
    local res = SaveVehicle(src, { id = args.id })
    if res.confirm then
        if not lib.callback.await('f_admin:confirm', src, res.msg) then return Notify(src, 'Dibatalkan.', 'inform') end
        res = SaveVehicle(src, { id = args.id, force = true })
    end
    Notify(src, res.msg, res.ok and 'success' or 'error')
end)

lib.addCommand('givecar', {
    help = 'Beri kendaraan baru ke garasi pemain (kunci didapat saat pertama dikeluarkan)',
    restricted = 'group.admin',
    params = {
        { name = 'id', type = 'playerId', help = 'ID pemain' },
        { name = 'model', type = 'string', help = 'Model kendaraan' },
    },
}, function(src, args)
    local p = exports.qbx_core:GetPlayer(args.id)
    if not p then return Notify(src, 'Pemain belum memilih karakter.', 'error') end
    local model = args.model:lower()
    local info = exports.qbx_core:GetVehiclesByName()[model]
    if not info then return Notify(src, 'Kendaraan tidak dikenal.', 'error') end
    local plate = exports.f_vehicles:GeneratePlate()
    local id = exports.f_vehicles:CreatePlayerVehicle({ model = model, citizenid = p.PlayerData.citizenid, garage = 'motelgarage', props = { plate = plate } })
    if not id then return Notify(src, 'Gagal menyimpan kendaraan.', 'error') end
    Log(src, 'vehicle', ('memberikan kendaraan %s (%s) ke **%s** (lewat /givecar)'):format(info.name or model, plate, Who(args.id)), args.id)
    Notify(src, ('%s (%s) masuk garasi %s.'):format(info.name or model, plate, CharName(args.id)), 'success')
    Notify(args.id, ('Staff memberimu %s (%s). Ambil di garasi Motel.'):format(info.name or model, plate), 'success')
end)

lib.addCommand('addsociety', {
    help = 'Tambah/kurangi saldo rekening organisasi (khusus Owner)',
    restricted = 'group.admin',
    params = {
        { name = 'account', help = 'Nama job/gang, contoh police atau cafe', type = 'string' },
        { name = 'amount', help = 'Jumlah, minus untuk mengurangi (contoh -5000)', type = 'number' },
    },
}, function(src, args)
    if GetResourceState('f_banking') ~= 'started' then return Notify(src, 'f_banking tidak berjalan.', 'error') end
    local account, amount = args.account:lower(), math.floor(args.amount)
    local banking = exports['f_banking']
    local balance = banking:getAccountMoney(account)
    if type(balance) ~= 'number' then return Notify(src, ('Rekening organisasi "%s" tidak ditemukan.'):format(account), 'error') end
    if amount == 0 then return Notify(src, 'Jumlah tidak valid.', 'error') end

    local ok = amount > 0 and banking:addAccountMoney(account, amount) or banking:removeAccountMoney(account, -amount)
    if not ok then return Notify(src, ('Saldo %s tidak cukup (Rp %d).'):format(account, balance), 'error') end
    banking:handleTransaction(account, 'Admin', math.abs(amount), amount > 0 and 'Admin deposit' or 'Admin withdraw',
        GetPlayerName(src), account, amount > 0 and 'deposit' or 'withdraw')
    Log(src, 'money', ('mengubah saldo rekening %s %+d'):format(account, amount))
    Notify(src, ('Saldo %s sekarang Rp %d.'):format(account, banking:getAccountMoney(account)), 'success')
end)
