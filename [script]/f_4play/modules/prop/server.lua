local props = {}      -- [id] = { id, model, x, y, z, rx, ry, rz }
local propCount = 0
local loaded = false
local lastAction = {} -- rate limit per player

local function isAllowed(src)
    return IsPlayerAceAllowed(src, PropConfig.Ace)
end

local function rateLimited(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 750 then return true end
    lastAction[src] = now
    return false
end

local function validNumber(n, limit)
    return type(n) == 'number' and n == n and math.abs(n) <= limit
end

local function round(n)
    return math.floor(n * 1000 + 0.5) / 1000
end

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_props` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `model` VARCHAR(64) NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `rx` FLOAT NOT NULL DEFAULT 0, `ry` FLOAT NOT NULL DEFAULT 0, `rz` FLOAT NOT NULL DEFAULT 0,
            `created_by` VARCHAR(64) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]])

    local rows = MySQL.query.await('SELECT id, model, x, y, z, rx, ry, rz FROM f_props') or {}
    for i = 1, #rows do
        local r = rows[i]
        props[r.id] = r
    end
    propCount = #rows
    loaded = true
    print(('[f_prop] %d prop dimuat'):format(propCount))
end)

lib.callback.register('f_prop:getAll', function()
    while not loaded do Wait(100) end
    return props
end)

lib.callback.register('f_prop:canUse', function(src)
    return isAllowed(src)
end)

lib.callback.register('f_prop:save', function(src, data)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    if not loaded then return false, 'Data belum siap' end
    if propCount >= PropConfig.MaxProps then return false, 'Batas prop tercapai' end
    if type(data) ~= 'table' then return false, 'Data tidak valid' end

    local model = data.model
    if type(model) ~= 'string' or #model > 64 or not model:match('^[%w_]+$') then
        return false, 'Model tidak valid'
    end
    model = model:lower()
    if PropConfig.Blacklist[model] then return false, 'Model diblacklist' end

    local x, y, z, rx, ry, rz = data.x, data.y, data.z, data.rx, data.ry, data.rz
    if not (validNumber(x, 20000) and validNumber(y, 20000) and validNumber(z, 5000)
        and validNumber(rx, 360) and validNumber(ry, 360) and validNumber(rz, 360)) then
        return false, 'Posisi tidak valid'
    end

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - vec3(x, y, z)) > PropConfig.MaxServerDistance then
        return false, 'Terlalu jauh dari player'
    end

    x, y, z, rx, ry, rz = round(x), round(y), round(z), round(rx), round(ry), round(rz)

    local id = MySQL.insert.await(
        'INSERT INTO f_props (model, x, y, z, rx, ry, rz, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { model, x, y, z, rx, ry, rz, GetPlayerIdentifierByType(src, 'license') or tostring(src) }
    )
    if not id then return false, 'Gagal simpan ke database' end

    local prop = { id = id, model = model, x = x, y = y, z = z, rx = rx, ry = ry, rz = rz }
    props[id] = prop
    propCount += 1

    TriggerClientEvent('f_prop:add', -1, prop)
    print(('[f_prop] %s (%d) memasang %s #%d'):format(GetPlayerName(src), src, model, id))
    return true
end)

lib.callback.register('f_prop:delete', function(src, id)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    if type(id) ~= 'number' or not props[id] then return false, 'Prop tidak ditemukan' end

    MySQL.update.await('DELETE FROM f_props WHERE id = ?', { id })
    local model = props[id].model
    props[id] = nil
    propCount -= 1

    TriggerClientEvent('f_prop:remove', -1, id)
    print(('[f_prop] %s (%d) menghapus %s #%d'):format(GetPlayerName(src), src, model, id))
    return true
end)
