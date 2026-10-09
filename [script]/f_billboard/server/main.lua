local billboards = {} -- [id] = data (format yang sama dengan yang dikirim ke client)
local count = 0
local loaded = false
local lastAction = {} -- rate limit per player

local presetModels = {}
for i = 1, #BillboardPresets do
    presetModels[BillboardPresets[i].model] = true
end

local FITS = { cover = true, contain = true, fill = true }

local function isAllowed(src)
    return IsPlayerAceAllowed(src, Config.Ace)
end

local function rateLimited(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 500 then return true end
    lastAction[src] = now
    return false
end

local function validNumber(n, limit)
    return type(n) == 'number' and n == n and math.abs(n) <= limit
end

local function round(n)
    return math.floor(n * 1000 + 0.5) / 1000
end

local function withMedia(bb)
    bb.mediaType, bb.mediaSrc = DetectMedia(bb.url)
    return bb
end

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_billboards` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(50) NOT NULL,
            `type` VARCHAR(8) NOT NULL,
            `model` VARCHAR(64) NOT NULL DEFAULT '',
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `rx` FLOAT NOT NULL DEFAULT 0, `rz` FLOAT NOT NULL DEFAULT 0,
            `ox` FLOAT NOT NULL DEFAULT 0, `oy` FLOAT NOT NULL DEFAULT 0, `oz` FLOAT NOT NULL DEFAULT 0,
            `width` FLOAT NOT NULL, `height` FLOAT NOT NULL,
            `media_url` VARCHAR(512) NOT NULL DEFAULT '',
            `fit` VARCHAR(8) NOT NULL DEFAULT 'cover',
            `brightness` TINYINT UNSIGNED NOT NULL DEFAULT 100,
            `render_distance` FLOAT NOT NULL DEFAULT 80,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            `created_by` VARCHAR(64) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]])

    local rows = MySQL.query.await('SELECT * FROM f_billboards') or {}
    for i = 1, #rows do
        local r = rows[i]
        billboards[r.id] = withMedia({
            id = r.id, label = r.label, type = r.type,
            model = r.model ~= '' and r.model or nil,
            x = r.x, y = r.y, z = r.z, rx = r.rx, rz = r.rz,
            ox = r.ox, oy = r.oy, oz = r.oz,
            width = r.width, height = r.height,
            url = r.media_url, fit = r.fit,
            brightness = r.brightness, renderDistance = r.render_distance,
            active = r.active == 1 or r.active == true,
        })
    end
    count = #rows
    loaded = true
    print(('[f_billboard] %d billboard dimuat'):format(count))
end)

---Validasi semua input dari client. Tidak ada nilai client yang dipakai tanpa dicek.
local function validate(data)
    if type(data) ~= 'table' then return nil, 'Data tidak valid' end

    local t = data.type
    if t ~= 'prop' and t ~= 'zone' then return nil, 'Tipe tidak valid' end

    local label = type(data.label) == 'string' and data.label or ''
    label = label:gsub('[%c<>]', ''):match('^%s*(.-)%s*$'):sub(1, 50)
    if label == '' then label = 'Billboard' end

    local model = ''
    if t == 'prop' then
        model = data.model
        if type(model) ~= 'string' or not presetModels[model] then return nil, 'Model tidak ada di daftar preset' end
    end

    local x, y, z, rx, rz = data.x, data.y, data.z, data.rx, data.rz
    local ox, oy, oz = data.ox, data.oy, data.oz
    if not (validNumber(x, 20000) and validNumber(y, 20000) and validNumber(z, 5000)
        and validNumber(rx, 90) and validNumber(rz, 720)
        and validNumber(ox, Config.MaxOffset) and validNumber(oy, Config.MaxOffset) and validNumber(oz, Config.MaxOffset)) then
        return nil, 'Posisi tidak valid'
    end

    local w, h = data.width, data.height
    if not (validNumber(w, Config.MaxSize) and validNumber(h, Config.MaxSize) and w >= 0.1 and h >= 0.1) then
        return nil, 'Ukuran tidak valid'
    end

    if not DetectMedia(data.url) then return nil, 'URL media tidak valid' end

    local brightness = validNumber(data.brightness, 100) and math.floor(math.max(10, data.brightness)) or 100
    local rd = validNumber(data.renderDistance, Config.MaxRenderDistance) and data.renderDistance or Config.DefaultRenderDistance
    rd = math.max(Config.MinRenderDistance, rd)

    if t == 'zone' then
        ox, oy, oz = 0.0, 0.0, 0.0
    else
        rx = 0.0 -- prop selalu tegak
    end

    return {
        label = label, type = t, model = model,
        x = round(x), y = round(y), z = round(z), rx = round(rx), rz = round(rz % 360),
        ox = round(ox), oy = round(oy), oz = round(oz),
        width = round(w), height = round(h),
        url = data.url, fit = FITS[data.fit] and data.fit or 'cover',
        brightness = brightness, renderDistance = round(rd),
        active = data.active ~= false,
    }
end

lib.callback.register('f_billboard:getAll', function()
    while not loaded do Wait(100) end
    return billboards
end)

lib.callback.register('f_billboard:canUse', function(src)
    return isAllowed(src)
end)

lib.callback.register('f_billboard:save', function(src, data)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    if not loaded then return false, 'Data belum siap' end

    local bb, err = validate(data)
    if not bb then return false, err end

    local id, old = data.id, nil
    if id ~= nil then
        old = type(id) == 'number' and billboards[id]
        if not old then return false, 'Billboard tidak ditemukan' end
    elseif count >= Config.MaxBillboards then
        return false, 'Batas billboard tercapai'
    end

    -- Cek jarak hanya kalau billboard baru / dipindah (edit media dari jauh tetap boleh)
    local moved = not old or math.abs(old.x - bb.x) > 0.05 or math.abs(old.y - bb.y) > 0.05 or math.abs(old.z - bb.z) > 0.05
    if moved and #(GetEntityCoords(GetPlayerPed(src)) - vec3(bb.x, bb.y, bb.z)) > Config.MaxServerDistance then
        return false, 'Terlalu jauh dari posisi billboard'
    end

    local params = {
        bb.label, bb.type, bb.model, bb.x, bb.y, bb.z, bb.rx, bb.rz, bb.ox, bb.oy, bb.oz,
        bb.width, bb.height, bb.url, bb.fit, bb.brightness, bb.renderDistance, bb.active and 1 or 0,
    }

    if old then
        params[#params + 1] = id
        MySQL.update.await([[UPDATE f_billboards SET label = ?, type = ?, model = ?, x = ?, y = ?, z = ?, rx = ?, rz = ?,
            ox = ?, oy = ?, oz = ?, width = ?, height = ?, media_url = ?, fit = ?, brightness = ?, render_distance = ?,
            active = ? WHERE id = ?]], params)
    else
        params[#params + 1] = GetPlayerIdentifierByType(src, 'license') or tostring(src)
        id = MySQL.insert.await([[INSERT INTO f_billboards (label, type, model, x, y, z, rx, rz, ox, oy, oz, width, height,
            media_url, fit, brightness, render_distance, active, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], params)
        if not id then return false, 'Gagal simpan ke database' end
        count += 1
    end

    bb.id = id
    if bb.model == '' then bb.model = nil end
    billboards[id] = withMedia(bb)

    TriggerClientEvent('f_billboard:set', -1, bb)
    print(('[f_billboard] %s (%d) %s billboard #%d "%s" -> %s'):format(
        GetPlayerName(src), src, old and 'mengubah' or 'membuat', id, bb.label, bb.url))
    return true, id
end)

lib.callback.register('f_billboard:toggle', function(src, id)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    local bb = type(id) == 'number' and billboards[id]
    if not bb then return false, 'Billboard tidak ditemukan' end

    bb.active = not bb.active
    MySQL.update.await('UPDATE f_billboards SET active = ? WHERE id = ?', { bb.active and 1 or 0, id })

    TriggerClientEvent('f_billboard:set', -1, bb)
    print(('[f_billboard] %s (%d) %s billboard #%d'):format(GetPlayerName(src), src, bb.active and 'menyalakan' or 'mematikan', id))
    return true, bb.active
end)

lib.callback.register('f_billboard:delete', function(src, id)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    local bb = type(id) == 'number' and billboards[id]
    if not bb then return false, 'Billboard tidak ditemukan' end

    MySQL.update.await('DELETE FROM f_billboards WHERE id = ?', { id })
    billboards[id] = nil
    count -= 1

    TriggerClientEvent('f_billboard:remove', -1, id)
    print(('[f_billboard] %s (%d) menghapus billboard #%d "%s"'):format(GetPlayerName(src), src, id, bb.label))
    return true
end)
