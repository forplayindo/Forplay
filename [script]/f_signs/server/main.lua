local signs = {} -- [id] = data (format yang sama dengan yang dikirim ke client)
local count = 0
local loaded = false
local lastAction = {} -- rate limit per player

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

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `f_signs` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `text` VARCHAR(64) NOT NULL,
            `style` VARCHAR(8) NOT NULL DEFAULT 'led',
            `color` INT UNSIGNED NOT NULL DEFAULT 16777215,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `height` FLOAT NOT NULL DEFAULT 0.4,
            `depth` FLOAT NOT NULL DEFAULT 0.04,
            `always_on` TINYINT(1) NOT NULL DEFAULT 0,
            `render_distance` FLOAT NOT NULL DEFAULT 60,
            `active` TINYINT(1) NOT NULL DEFAULT 1,
            `created_by` VARCHAR(64) NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        )
    ]])

    local rows = MySQL.query.await('SELECT * FROM f_signs') or {}
    for i = 1, #rows do
        local r = rows[i]
        signs[r.id] = {
            id = r.id, text = r.text, style = SignFonts[r.style] and r.style or 'led', color = r.color,
            x = r.x, y = r.y, z = r.z, heading = r.heading,
            height = r.height, depth = r.depth,
            alwaysOn = r.always_on == 1 or r.always_on == true,
            renderDistance = r.render_distance,
            active = r.active == 1 or r.active == true,
        }
    end
    count = #rows
    loaded = true
    print(('[f_signs] %d papan nama dimuat'):format(count))
end)

---Validasi semua input dari client. Tidak ada nilai client yang dipakai tanpa dicek.
local function validate(data)
    if type(data) ~= 'table' then return nil, 'Data tidak valid' end

    local text = type(data.text) == 'string' and data.text:match('^%s*(.-)%s*$') or ''
    if text == '' then return nil, 'Tulisan masih kosong' end
    if #text > Config.MaxTextLength then return nil, ('Tulisan maksimal %d huruf'):format(Config.MaxTextLength) end
    if not text:match('^[ -~]+$') then return nil, 'Hanya huruf, angka, dan simbol standar' end

    if type(data.style) ~= 'string' or not SignFonts[data.style] then return nil, 'Gaya tidak valid' end

    local color = math.tointeger(data.color)
    if not color or color < 0 or color > 0xFFFFFF then return nil, 'Warna tidak valid' end

    local x, y, z, h = data.x, data.y, data.z, data.heading
    if not (validNumber(x, 20000) and validNumber(y, 20000) and validNumber(z, 5000) and validNumber(h, 720)) then
        return nil, 'Posisi tidak valid'
    end

    local height = data.height
    if not (validNumber(height, Config.MaxHeight) and height >= Config.MinHeight) then return nil, 'Ukuran tidak valid' end

    local depth = data.depth
    if not (validNumber(depth, Config.MaxDepth) and depth >= 0) then return nil, 'Ketebalan tidak valid' end

    local rd = validNumber(data.renderDistance, Config.MaxRenderDistance) and data.renderDistance or Config.DefaultRenderDistance
    rd = math.max(Config.MinRenderDistance, rd)

    return {
        text = text, style = data.style, color = color,
        x = round(x), y = round(y), z = round(z), heading = round(h % 360),
        height = round(height), depth = round(depth),
        alwaysOn = data.alwaysOn == true, renderDistance = round(rd),
        active = data.active ~= false,
    }
end

lib.callback.register('f_signs:getAll', function()
    while not loaded do Wait(100) end
    return signs
end)

lib.callback.register('f_signs:canUse', function(src)
    return isAllowed(src)
end)

lib.callback.register('f_signs:save', function(src, data)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    if not loaded then return false, 'Data belum siap' end

    local s, err = validate(data)
    if not s then return false, err end

    local id, old = data.id, nil
    if id ~= nil then
        old = type(id) == 'number' and signs[id]
        if not old then return false, 'Papan nama tidak ditemukan' end
    elseif count >= Config.MaxSigns then
        return false, 'Batas papan nama tercapai'
    end

    -- Cek jarak hanya kalau papan baru / dipindah (edit tulisan/warna dari jauh tetap boleh)
    local moved = not old or math.abs(old.x - s.x) > 0.05 or math.abs(old.y - s.y) > 0.05 or math.abs(old.z - s.z) > 0.05
    if moved and #(GetEntityCoords(GetPlayerPed(src)) - vec3(s.x, s.y, s.z)) > Config.MaxServerDistance then
        return false, 'Terlalu jauh dari posisi papan nama'
    end

    local params = {
        s.text, s.style, s.color, s.x, s.y, s.z, s.heading, s.height, s.depth,
        s.alwaysOn and 1 or 0, s.renderDistance, s.active and 1 or 0,
    }

    if old then
        params[#params + 1] = id
        MySQL.update.await([[UPDATE f_signs SET text = ?, style = ?, color = ?, x = ?, y = ?, z = ?, heading = ?,
            height = ?, depth = ?, always_on = ?, render_distance = ?, active = ? WHERE id = ?]], params)
    else
        params[#params + 1] = GetPlayerIdentifierByType(src, 'license') or tostring(src)
        id = MySQL.insert.await([[INSERT INTO f_signs (text, style, color, x, y, z, heading, height, depth,
            always_on, render_distance, active, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], params)
        if not id then return false, 'Gagal simpan ke database' end
        count += 1
    end

    s.id = id
    signs[id] = s

    TriggerClientEvent('f_signs:set', -1, s)
    print(('[f_signs] %s (%d) %s papan nama #%d "%s" (%s)'):format(
        GetPlayerName(src), src, old and 'mengubah' or 'membuat', id, s.text, s.style))
    return true, id
end)

lib.callback.register('f_signs:toggle', function(src, id)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    local s = type(id) == 'number' and signs[id]
    if not s then return false, 'Papan nama tidak ditemukan' end

    s.active = not s.active
    MySQL.update.await('UPDATE f_signs SET active = ? WHERE id = ?', { s.active and 1 or 0, id })

    TriggerClientEvent('f_signs:set', -1, s)
    print(('[f_signs] %s (%d) %s papan nama #%d'):format(GetPlayerName(src), src, s.active and 'menyalakan' or 'mematikan', id))
    return true, s.active
end)

lib.callback.register('f_signs:delete', function(src, id)
    if not isAllowed(src) then return false, 'Tidak punya izin' end
    if rateLimited(src) then return false, 'Terlalu cepat' end
    local s = type(id) == 'number' and signs[id]
    if not s then return false, 'Papan nama tidak ditemukan' end

    MySQL.update.await('DELETE FROM f_signs WHERE id = ?', { id })
    signs[id] = nil
    count -= 1

    TriggerClientEvent('f_signs:remove', -1, id)
    print(('[f_signs] %s (%d) menghapus papan nama #%d "%s"'):format(GetPlayerName(src), src, id, s.text))
    return true
end)
