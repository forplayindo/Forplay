local config = require 'config.server'.commandPerms

lib.addCommand('report', {
    help = 'Send Report',
    params = {
        {name = 'report', help = 'Isi laporanmu', type = 'string'}
    }
}, function(source, args, raw)
    SendReport(source, string.sub(raw, 8))
end)

lib.addCommand('admin', {
    help = 'Opens Admin Menu',
    restricted = config.useMenu,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:openMenu', source)
end)

lib.addCommand('noclip', {
    help = 'Toggle NoClip',
    restricted = config.noclip,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:ToggleNoClip', source)
end)

lib.addCommand('names', {
    help = 'Toggle Player Names',
    restricted = config.names,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:names', source)
end)

lib.addCommand('blips', {
    help = 'Toggle Player Blips',
    restricted = config.blips,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:blips', source)
end)

lib.addCommand('admincar', {
    help = 'Simpan kendaraan yang kamu naiki sebagai milik (kamu atau pemain tertentu)',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID of the new owner (default: you)', optional = true },
    },
    restricted = config.saveVehicle,
}, function(source, args)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    local target = args.id or source
    local targetPlayer = exports.qbx_core:GetPlayer(target)
    if not targetPlayer then
        return exports.qbx_core:Notify(source, 'Pemain sedang tidak online.', 'error')
    end

    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if vehicle == 0 then
        return exports.qbx_core:Notify(source, 'Kamu harus berada di kendaraan untuk memakai ini', 'error')
    end

    local vehModel = GetEntityModel(vehicle)

    if not exports.qbx_core:GetVehiclesByHash()[vehModel] then
        return exports.qbx_core:Notify(source, 'Kendaraan tidak dikenal, hubungi developer untuk mendaftarkannya.', 'error')
    end

    local playerData = targetPlayer.PlayerData
    local vehName, props = lib.callback.await('qbx_admin:client:GetVehicleInfo', source)
    local existingVehicleId = Entity(vehicle).state.vehicleid
    if existingVehicleId then
        local response = lib.callback.await('qbx_admin:client:SaveCarDialog', source)

        if not response then
            return exports.qbx_core:Notify(source, 'Canceled.', 'inform')
        end
        local success, err = exports.f_vehicles:SetPlayerVehicleOwner(existingVehicleId, playerData.citizenid)
        if not success then error(err) end
        -- new owner gets a fresh key, keys of the previous owner stop working
        exports.f_vehiclekeys:RekeyVehicle(target, vehicle, existingVehicleId)
    else
        local vehicleId, err = exports.f_vehicles:CreatePlayerVehicle({
            model = vehName,
            citizenid = playerData.citizenid,
            props = props,
        })
        if err then error(err) end
        Entity(vehicle).state:set('vehicleid', vehicleId, true)
        exports.f_vehiclekeys:GiveKeys(target, vehicle)
    end

    if target == source then
        exports.qbx_core:Notify(source, 'Kendaraan ini sekarang milikmu.', 'success')
    else
        exports.qbx_core:Notify(source, ('Kendaraan disimpan atas nama %s %s.'):format(playerData.charinfo.firstname, playerData.charinfo.lastname), 'success')
        exports.qbx_core:Notify(target, 'Admin memberimu kendaraan, kuncinya ada di tasmu.', 'success')
    end
end)

lib.addCommand('givecar', {
    help = 'Munculkan kendaraan baru di depanmu, milik pemain tertentu (kunci masuk ke inventarisnya)',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID of the new owner' },
        { name = 'model', type = 'string', help = 'Vehicle model' },
    },
    restricted = config.saveVehicle,
}, function(source, args)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    local target = args.id
    local targetPlayer = exports.qbx_core:GetPlayer(target)
    if not targetPlayer then
        return exports.qbx_core:Notify(source, 'Pemain sedang tidak online.', 'error')
    end

    local model = args.model:lower()
    if not exports.qbx_core:GetVehiclesByName()[model] then
        return exports.qbx_core:Notify(source, 'Kendaraan tidak dikenal, hubungi developer untuk mendaftarkannya.', 'error')
    end

    local plate = exports.f_vehicles:GeneratePlate()
    local vehicleId, err = exports.f_vehicles:CreatePlayerVehicle({
        model = model,
        citizenid = targetPlayer.PlayerData.citizenid,
        props = { plate = plate },
    })
    if err then error(err) end

    -- 5m in front of the admin, facing the same way
    local ped = GetPlayerPed(source)
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local rad = math.rad(heading)
    local coords = vec4(pos.x - math.sin(rad) * 5.0, pos.y + math.cos(rad) * 5.0, pos.z, heading)

    local _, vehicle = qbx.spawnVehicle({
        model = model,
        spawnSource = coords,
        bucket = GetPlayerRoutingBucket(source),
        props = { plate = plate },
    })
    Entity(vehicle).state:set('vehicleid', vehicleId, true)
    exports.f_vehiclekeys:GiveKeys(target, vehicle)

    local charinfo = targetPlayer.PlayerData.charinfo
    exports.qbx_core:Notify(source, ('%s (%s) diberikan ke %s %s.'):format(model, plate, charinfo.firstname, charinfo.lastname), 'success')
    if target ~= source then
        exports.qbx_core:Notify(target, ('Admin memberimu kendaraan (%s), kuncinya ada di tasmu.'):format(plate), 'success')
    end
end)

lib.addCommand('setmodel', {
    help = 'Ganti model karaktermu',
    restricted = config.setModel,
    params = {
        {name = 'model', help = 'NPC Model', type = 'string'},
        {name = 'id', help = 'Player ID', type = 'number', optional = true},
    }
}, function(source, args)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    local Target = args.id or source

    if not exports.qbx_core:GetPlayer(Target) then return end

    TriggerClientEvent('qbx_admin:client:setModel', Target, args.model)
end)

lib.addCommand('vec2', {
    help = 'Copy vector2 to clipboard (Admin only)',
    restricted = config.dev,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:copyToClipboard', source, 'coords2')
end)

lib.addCommand('vec3', {
    help = 'Copy vector3 to clipboard (Admin only)',
    restricted = config.dev,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:copyToClipboard', source, 'coords3')
end)

lib.addCommand('vec4', {
    help = 'Copy vector4 to clipboard (Admin only)',
    restricted = config.dev,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:copyToClipboard', source, 'coords4')
end)

lib.addCommand('addsociety', {
    help = 'Tambah/kurangi saldo rekening organisasi (Admin only)',
    restricted = config.society,
    params = {
        {name = 'account', help = 'Nama job/gang, contoh police atau cafe', type = 'string'},
        {name = 'amount', help = 'Jumlah, minus untuk mengurangi (contoh -5000)', type = 'number'},
    }
}, function(source, args)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    if GetResourceState('Renewed-Banking') ~= 'started' then
        return exports.qbx_core:Notify(source, 'Renewed-Banking tidak berjalan.', 'error')
    end

    local account, amount = args.account:lower(), math.floor(args.amount)
    local banking = exports['Renewed-Banking']
    local balance = banking:getAccountMoney(account)
    if type(balance) ~= 'number' then
        return exports.qbx_core:Notify(source, ('Rekening organisasi "%s" tidak ditemukan.'):format(account), 'error')
    end
    if amount == 0 then return exports.qbx_core:Notify(source, 'Jumlah tidak valid.', 'error') end

    local ok
    if amount > 0 then
        ok = banking:addAccountMoney(account, amount)
    else
        ok = banking:removeAccountMoney(account, -amount)
    end
    if not ok then
        return exports.qbx_core:Notify(source, ('Saldo %s tidak cukup (Rp %d).'):format(account, balance), 'error')
    end

    local adminName = GetPlayerName(source)
    banking:handleTransaction(account, 'Admin', math.abs(amount), amount > 0 and 'Admin deposit' or 'Admin withdraw',
        adminName, account, amount > 0 and 'deposit' or 'withdraw')
    lib.print.info(('%s (%s) mengubah saldo %s %+d'):format(adminName, source, account, amount))
    exports.qbx_core:Notify(source, ('Saldo %s sekarang Rp %d.'):format(account, banking:getAccountMoney(account)), 'success')
end)

lib.addCommand('heading', {
    help = 'Copy heading to clipboard (Admin only)',
    restricted = config.dev,
}, function(source)
    if not exports.qbx_core:IsOptin(source) then exports.qbx_core:Notify(source, locale('error.not_optin'), 'error') return end
    TriggerClientEvent('qbx_admin:client:copyToClipboard', source, 'heading')
end)