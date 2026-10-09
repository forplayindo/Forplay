local config = require 'config'
local META = 'paycheck'
local busy = {} -- [src] = true selama pencairan berjalan (anti spam / double klaim)

local function rupiah(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
    return 'Rp ' .. out:gsub('^%.', '')
end

local function breakdown(gross)
    local tax = math.floor(gross * config.taxRate / 100 + 0.5)
    return tax, gross - tax
end

local function pending(player)
    return math.max(0, math.floor(tonumber(player.PlayerData.metadata[META]) or 0))
end

local function nearDesk(src)
    local pos = GetEntityCoords(GetPlayerPed(src))
    for i = 1, #config.locations do
        if #(pos - config.locations[i].coords.xyz) <= config.useDistance then return true end
    end
    return false
end

---Email f_phone; tanpa akun Mail jatuh ke notifikasi ox_lib
local function mail(src, player, subject, lines)
    local cid = player.PlayerData.citizenid
    local okA, addresses = pcall(function() return exports['f_phone']:getMailAddresses(cid) end)
    if okA and type(addresses) == 'table' and #addresses > 0 then
        local to = {}
        for i = 1, #addresses do to[i] = addresses[i].email end
        local okS, res = pcall(function()
            return exports['f_phone']:sendMail({ to = to, subject = subject, body = table.concat(lines, '\n'), from = { name = config.mailFrom, email = '' } })
        end)
        if okS and res and (res.delivered or 0) > 0 then return end
    end
    TriggerClientEvent('ox_lib:notify', src, { title = subject, description = lines[3] or lines[1], type = 'info', duration = 10000 })
end

---Dipanggil qbx_core sendPaycheck tiap interval: simpan, jangan langsung ke bank
exports('Add', function(src, amount)
    local player = exports.qbx_core:GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not player or amount <= 0 then return false end

    local total = pending(player) + amount
    player.Functions.SetMetaData(META, total)

    local n = config.notify
    TriggerClientEvent('ox_lib:notify', src, {
        id = 'f_paycheck', title = n.title, icon = n.icon, iconColor = n.iconColor,
        position = n.position, duration = n.duration, style = n.style,
        description = ('Gaji %s masuk · Total %s  \nAmbil di %s'):format(rupiah(amount), rupiah(total), config.locations[1].label),
    })
    return true
end)

lib.callback.register('f_paycheck:get', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not nearDesk(src) then return end
    local gross = pending(player)
    local tax, net = breakdown(gross)
    return { gross = gross, rate = config.taxRate, tax = tax, net = net }
end)

lib.callback.register('f_paycheck:withdraw', function(src, method)
    if busy[src] then return { ok = false, msg = 'Sedang diproses.' } end
    if method ~= 'cash' and method ~= 'bank' then return { ok = false, msg = 'Metode tidak valid.' } end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { ok = false } end
    if not nearDesk(src) then return { ok = false, msg = 'Kamu terlalu jauh dari petugas.' } end

    local gross = pending(player)
    if gross <= 0 then return { ok = false, msg = 'Tidak ada paycheck untuk dicairkan.' } end

    busy[src] = true
    local tax, net = breakdown(gross)
    local methodLabel = method == 'cash' and 'Cash' or 'Transfer Bank'

    -- kosongkan dulu supaya tidak bisa diklaim dua kali, kembalikan kalau gagal
    player.Functions.SetMetaData(META, 0)
    local paid = net <= 0 or player.Functions.AddMoney(method, net, 'paycheck')
    if not paid then
        player.Functions.SetMetaData(META, gross)
        busy[src] = nil
        mail(src, player, 'Pencairan Paycheck Gagal', {
            ('Pencairan paycheck %s via %s gagal diproses.'):format(rupiah(net), methodLabel),
            '',
            'Paycheck kamu tetap tersimpan, silakan coba lagi di Kantor Gaji.',
        })
        return { ok = false, msg = 'Pencairan gagal, paycheck tetap tersimpan.' }
    end
    player.Functions.Save()

    if tax > 0 then
        local okT, added = pcall(function() return exports['Renewed-Banking']:addAccountMoney(config.govAccount, tax) end)
        if okT and added then
            -- tanpa riwayat transaksi per pencairan; cukup total di /auditpajak (Pajak Warga)
            pcall(function() exports.f_tax:AddCitizenTax(tax) end)
        else
            lib.print.error(('Pajak paycheck %s (%s) gagal masuk ke rekening %s'):format(rupiah(tax), player.PlayerData.citizenid, config.govAccount))
        end
    end
    busy[src] = nil

    local cinfo = player.PlayerData.charinfo
    mail(src, player, 'Pencairan Paycheck Berhasil', {
        ('Halo %s %s,'):format(cinfo.firstname or '', cinfo.lastname or ''),
        '',
        ('Paycheck kamu berhasil dicairkan via %s.'):format(methodLabel),
        '',
        ('Total paycheck   : %s'):format(rupiah(gross)),
        ('Pajak (%s%%)       : -%s'):format(config.taxRate, rupiah(tax)),
        ('Diterima         : %s'):format(rupiah(net)),
        '',
        ('Pajak disetorkan ke kas pemerintah. Tanggal: %s'):format(os.date('%d/%m/%Y %H:%M')),
    })
    return { ok = true, net = net }
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)
