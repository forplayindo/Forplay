---------------------------------------------------------------------------
-- Beri item / kendaraan / uang + kendaraan admin. Semua tercatat di Discord.
---------------------------------------------------------------------------
local function online(id)
    id = tonumber(id)
    return id and GetPlayerName(id) and id or nil
end

local function fmtRp(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    return 'Rp ' .. s
end

---------------------------------------------------------------- item
Handle('items', 'give.item', function(src)
    local list, money = {}, Can(src, 'give.money')
    for name, it in pairs(exports.ox_inventory:Items()) do
        if name ~= 'money' or money then list[#list + 1] = { n = name, l = it.label or name } end
    end
    table.sort(list, function(a, b) return a.l < b.l end)
    return { ok = true, items = list }
end)

Handle('give_items', 'give.item', function(src, d)
    local t = online(d.id)
    if not t then return { ok = false, msg = 'Pemain sudah keluar.' } end
    if type(d.items) ~= 'table' or #d.items == 0 or #d.items > 25 then return { ok = false, msg = 'Keranjang kosong.' } end

    local Items, given, failed = exports.ox_inventory:Items(), {}, {}
    for _, line in ipairs(d.items) do
        local name = type(line.n) == 'string' and line.n
        local item = name and Items[name]
        local count = math.max(1, math.min(10000, math.floor(tonumber(line.c) or 1)))
        if not item then
            failed[#failed + 1] = tostring(name)
        elseif name == 'money' and not Can(src, 'give.money') then
            failed[#failed + 1] = 'uang tunai (khusus Owner)'
        else
            local ok, resp = exports.ox_inventory:AddItem(t, name, count)
            if ok then
                given[#given + 1] = ('%s%s'):format(item.label:lower(), count > 1 and (' x' .. count) or '')
            else
                failed[#failed + 1] = ('%s (%s)'):format(item.label, resp == 'inventory_full' and 'tas penuh' or tostring(resp))
            end
        end
    end

    if #given > 0 then
        Log(src, 'item', ('memberikan %s ke **%s**'):format(table.concat(given, ', '), Who(t)), t)
        Notify(t, 'Staff memberimu: ' .. table.concat(given, ', '), 'success')
    end
    if #failed > 0 then
        return { ok = #given > 0, msg = (#given > 0 and 'Sebagian terkirim. ' or '') .. 'Gagal: ' .. table.concat(failed, ', ') }
    end
    return { ok = true, msg = 'Terkirim ke ' .. CharName(t) }
end)

---------------------------------------------------------------- kendaraan
Handle('vehicles', false, function()
    local list = {}
    for model, v in pairs(exports.qbx_core:GetVehiclesByName()) do
        list[#list + 1] = { m = model, n = v.name or model, b = v.brand or '', c = v.category or '' }
    end
    table.sort(list, function(a, b) return a.n < b.n end)

    local garages = {}
    if GetResourceState('f_garages') == 'started' then
        for name, g in pairs(exports.f_garages:GetGarages()) do
            if not g.groups and g.type ~= 'depot' and (g.vehicleType or 'car') == 'car' then
                garages[#garages + 1] = { name = name, label = g.label or name }
            end
        end
        table.sort(garages, function(a, b) return a.label < b.label end)
    end
    return { ok = true, vehicles = list, garages = garages }
end)

Handle('give_vehicle', 'give.vehicle', function(src, d)
    local t = online(d.id)
    if not t then return { ok = false, msg = 'Pemain sudah keluar.' } end
    local p = exports.qbx_core:GetPlayer(t)
    if not p then return { ok = false, msg = 'Pemain belum memilih karakter.' } end
    local model = type(d.model) == 'string' and d.model:lower()
    local info = model and exports.qbx_core:GetVehiclesByName()[model]
    if not info then return { ok = false, msg = 'Kendaraan tidak dikenal.' } end
    local garage = type(d.garage) == 'string' and d.garage ~= '' and d.garage or 'motelgarage'

    local plate = exports.f_vehicles:GeneratePlate()
    local id, err = exports.f_vehicles:CreatePlayerVehicle({ model = model, citizenid = p.PlayerData.citizenid, garage = garage, props = { plate = plate } })
    if not id then return { ok = false, msg = err and err.message or 'Gagal menyimpan kendaraan.' } end

    Log(src, 'vehicle', ('memberikan kendaraan %s (%s) ke **%s**'):format(info.name or model, plate, Who(t)), t)
    Notify(t, ('Staff memberimu %s (%s). Ambil di garasi, kuncinya didapat saat pertama dikeluarkan.'):format(info.name or model, plate), 'success', nil, 10000)
    return { ok = true, msg = ('%s (%s) masuk garasi %s'):format(info.name or model, plate, CharName(t)) }
end)

Handle('veh_spawn', 'vehicle.spawn', function(src, d)
    local model = type(d.model) == 'string' and d.model:lower()
    local info = model and exports.qbx_core:GetVehiclesByName()[model]
    if not info then return { ok = false, msg = 'Kendaraan tidak dikenal.' } end
    local netId, veh = qbx.spawnVehicle({
        model = model,
        spawnSource = GetPlayerPed(src),
        warp = true,
        props = { plate = exports.f_vehicles:GeneratePlate() },
    })
    if not netId then return { ok = false, msg = 'Gagal spawn kendaraan.' } end
    exports.f_vehiclekeys:GiveKeys(src, veh, true)
    Log(src, 'vehicle', ('spawn kendaraan sementara %s'):format(info.name or model))
    return { ok = true, msg = (info.name or model) .. ' di-spawn', close = true }
end)

-- Beli / simpan kendaraan yang dinaiki ke garasi sendiri (atau pemain lain). Dipakai panel & /admincar.
function SaveVehicle(src, d)
    local t = online(d.id) or src
    if t ~= src and not Can(src, 'give.vehicle') and not IsPlayerAceAllowed(tostring(src), 'command.admincar') then
        return { ok = false, msg = 'Tidak punya izin memberi kendaraan.' }
    end
    local tp = exports.qbx_core:GetPlayer(t)
    if not tp then return { ok = false, msg = 'Pemain belum memilih karakter.' } end
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 then return { ok = false, msg = 'Kamu harus berada di kendaraan.' } end
    if not exports.qbx_core:GetVehiclesByHash()[GetEntityModel(veh)] then
        return { ok = false, msg = 'Kendaraan tidak terdaftar di qbx_core.' }
    end

    local existing = Entity(veh).state.vehicleid
    if existing and not d.force then
        return { ok = false, confirm = true, msg = 'Kendaraan ini sudah ada pemiliknya. Ganti pemiliknya?' }
    end

    local model, props = lib.callback.await('f_admin:vehprops', src)
    if not model then return { ok = false, msg = 'Gagal membaca kendaraan.' } end
    local cid = tp.PlayerData.citizenid
    if existing then
        local okOwner, err = exports.f_vehicles:SetPlayerVehicleOwner(existing, cid)
        if not okOwner then return { ok = false, msg = err and err.message or 'Gagal mengganti pemilik.' } end
        exports.f_vehiclekeys:RekeyVehicle(t, veh, existing)
    else
        local id, err = exports.f_vehicles:CreatePlayerVehicle({ model = model, citizenid = cid, props = props })
        if not id then return { ok = false, msg = err and err.message or 'Gagal menyimpan.' } end
        Entity(veh).state:set('vehicleid', id, true)
        exports.f_vehiclekeys:GiveKeys(t, veh)
    end
    Log(src, 'vehicle', t == src and ('menyimpan kendaraan %s (%s) ke garasinya sendiri'):format(model, props and props.plate or '-')
        or ('menyimpan kendaraan %s (%s) atas nama **%s**'):format(model, props and props.plate or '-', Who(t)), t ~= src and t or nil)
    if t ~= src then Notify(t, 'Staff memberimu kendaraan, kuncinya ada di tasmu.', 'success') end
    return { ok = true, msg = t == src and 'Kendaraan ini sekarang milikmu' or ('Kendaraan disimpan atas nama ' .. CharName(t)) }
end

Handle('veh_save', 'vehicle.save', SaveVehicle)

Handle('veh_plate', 'vehicle.plate', function(src, d)
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 then return { ok = false, msg = 'Kamu harus berada di kendaraan.' } end
    local plate = type(d.plate) == 'string' and d.plate:upper():gsub('^%s+', ''):gsub('%s+$', '') or ''
    if plate == '' or #plate > Config.PlateMax or not plate:match('^[A-Z0-9 ]+$') then
        return { ok = false, msg = ('Plat 1-%d karakter, huruf/angka/spasi.'):format(Config.PlateMax) }
    end
    if exports.f_vehicles:DoesPlayerVehiclePlateExist(plate) then return { ok = false, msg = 'Plat sudah dipakai kendaraan lain.' } end

    local old = GetVehicleNumberPlateText(veh)
    SetVehicleNumberPlateText(veh, plate)
    local id = Entity(veh).state.vehicleid
    if id then
        MySQL.update.await('UPDATE player_vehicles SET plate = ?, mods = JSON_SET(mods, "$.plate", ?) WHERE id = ?', { plate, plate, id })
    end
    Log(src, 'vehicle', ('mengganti plat %s → %s'):format(old, plate))
    return { ok = true, msg = 'Plat diganti ke ' .. plate }
end)

Handle('veh_delete', 'vehicle.delete', function(src, d)
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.net) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return { ok = false, msg = 'Tidak ada kendaraan di dekatmu.' }
    end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 15.0 then return { ok = false, msg = 'Kendaraan terlalu jauh.' } end
    DeleteEntity(veh)
    return { ok = true, msg = 'Kendaraan dihapus' }
end)

Handle('weapons', 'self.weapons', function(src, d)
    local list = Config.WeaponList[d.cat]
    if not list then return { ok = false, msg = 'Kategori tidak dikenal.' } end
    local n = 0
    for _, w in ipairs(list) do
        if exports.ox_inventory:Items()[w] and exports.ox_inventory:AddItem(src, w, 1) then n += 1 end
    end
    Log(src, 'weapons', ('mengambil semua senjata kategori %s (%d senjata)'):format(d.cat, n))
    return { ok = true, msg = ('%d senjata %s masuk ke tas'):format(n, d.cat) }
end)

---------------------------------------------------------------- uang (Owner)
Handle('money', 'give.money', function(src, d)
    local t = online(d.id)
    local p = t and exports.qbx_core:GetPlayer(t)
    if not p then return { ok = false, msg = 'Pemain belum memilih karakter.' } end
    local kind = d.kind == 'bank' and 'bank' or 'cash'
    local amount = math.floor(tonumber(d.amount) or 0)
    if amount < 0 or (amount == 0 and d.act ~= 'set') or amount > 1000000000 then return { ok = false, msg = 'Jumlah tidak valid.' } end

    local okMoney
    if d.act == 'set' then
        okMoney = p.Functions.SetMoney(kind, amount, 'f_admin')
    elseif d.act == 'remove' then
        okMoney = p.Functions.RemoveMoney(kind, amount, 'f_admin')
    else
        okMoney = p.Functions.AddMoney(kind, amount, 'f_admin')
    end
    if okMoney == false then return { ok = false, msg = 'Gagal (saldo tidak cukup?).' } end

    local label = kind == 'cash' and 'uang tunai' or 'saldo bank'
    local verb = ({ set = 'mengatur %s **%s** menjadi %s', remove = 'mengurangi %s **%s** sebesar %s' })[d.act] or 'memberikan %s ke **%s** sebesar %s'
    Log(src, 'money', verb:format(label, Who(t), fmtRp(amount)), t)
    return { ok = true, msg = 'Uang ' .. CharName(t) .. ' diperbarui' }
end)
