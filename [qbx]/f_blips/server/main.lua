local RESOURCE = GetCurrentResourceName()

local allowed = {}
for _, l in ipairs(Config.AllowedLicenses) do allowed[l:lower()] = true end

-- Salinan kerja di memori server. Client baru melihat perubahan setelah "ensure f_blips".
local List = Blips or {}
local pending = 0

local validCategory = {}
for _, c in ipairs(Config.Categories) do validCategory[c] = true end

-- Owner/Admin di f_admin, atau license di Config.AllowedLicenses (cadangan kalau f_admin mati)
local function isAdmin(src)
    if GetResourceState('f_admin') == 'started' then
        local role = exports.f_admin:GetRole(src)
        if role == 'owner' or role == 'admin' then return true end
    end
    local license = GetPlayerIdentifierByType(src, 'license')
    return license ~= nil and allowed[license:lower()] == true
end

local function log(src, msg)
    print(('^3[f_blips]^0 %s: %s'):format(src and GetPlayerName(src) or 'console', msg))
    lib.logger(src or 0, 'f_blips', msg)
end

local function find(id)
    for i = 1, #List do
        if List[i].id == id then return List[i], i end
    end
end

---------------------------------------------------------------------------
-- Tulis data/blips.lua
---------------------------------------------------------------------------
local function save()
    table.sort(List, function(a, b) return a.id < b.id end)
    local out = {
        '-- File ini ditulis otomatis oleh menu /blips. Perubahan berlaku setelah "ensure f_blips".',
        'Blips = {',
    }
    for _, b in ipairs(List) do
        out[#out + 1] = ('    { id = %d, label = %q, category = %q, sprite = %d, color = %d, scale = %.1f, active = %s, coords = vec3(%.2f, %.2f, %.2f) },')
            :format(b.id, b.label, b.category, b.sprite, b.color, b.scale, tostring(b.active), b.coords.x, b.coords.y, b.coords.z)
    end
    out[#out + 1] = '}'
    out[#out + 1] = ''
    SaveResourceFile(RESOURCE, 'data/blips.lua', table.concat(out, '\n'), -1)
    pending += 1
end

---------------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------------
local function adminList()
    local list = {}
    for i, b in ipairs(List) do
        list[i] = {
            id = b.id, label = b.label, category = b.category, sprite = b.sprite, color = b.color,
            scale = b.scale, active = b.active, dirty = b.dirty,
            coords = { x = b.coords.x, y = b.coords.y, z = b.coords.z },
        }
    end
    return list
end

local function result(msg)
    return { ok = true, msg = msg, blips = adminList(), pending = pending }
end

---@return table? data, string? err
local function validate(d)
    if type(d) ~= 'table' then return nil, 'Data tidak valid.' end
    local label = type(d.label) == 'string' and d.label:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #label < 2 or #label > 40 then return nil, 'Nama blip 2-40 karakter.' end
    if not validCategory[d.category] then return nil, 'Kategori tidak valid.' end

    local sprite, color = math.tointeger(tonumber(d.sprite)), math.tointeger(tonumber(d.color))
    if not sprite or sprite < 1 or sprite > Config.MaxSprite then return nil, ('Ikon (sprite) 1-%d.'):format(Config.MaxSprite) end
    if not color or color < 0 or color > Config.MaxColor then return nil, ('Warna 0-%d.'):format(Config.MaxColor) end

    local scale = tonumber(d.scale)
    if not scale or scale < Config.MinScale or scale > Config.MaxScale then
        return nil, ('Ukuran %.1f-%.1f.'):format(Config.MinScale, Config.MaxScale)
    end

    local c = d.coords
    if type(c) ~= 'table' or not tonumber(c.x) or not tonumber(c.y) or not tonumber(c.z) then
        return nil, 'Koordinat tidak valid.'
    end

    return {
        label = label, category = d.category, sprite = sprite, color = color,
        scale = math.floor(scale * 10 + 0.5) / 10, active = d.active ~= false,
        coords = vec3(tonumber(c.x) + 0.0, tonumber(c.y) + 0.0, tonumber(c.z) + 0.0),
    }
end

local function adminCallback(name, fn)
    lib.callback.register('f_blips:admin:' .. name, function(src, ...)
        if not isAdmin(src) then
            log(src, 'memanggil menu admin blips tanpa izin')
            return { ok = false, msg = 'Tidak punya izin.' }
        end
        return fn(src, ...)
    end)
end

adminCallback('open', function()
    local r = result()
    r.categories = Config.Categories
    r.limits = { sprite = Config.MaxSprite, color = Config.MaxColor, minScale = Config.MinScale, maxScale = Config.MaxScale }
    return r
end)

adminCallback('create', function(src, d)
    local data, err = validate(d)
    if not data then return { ok = false, msg = err } end

    local id = 0
    for _, b in ipairs(List) do if b.id > id then id = b.id end end
    data.id = id + 1
    data.dirty = true
    List[#List + 1] = data
    save()
    log(src, ('membuat blip #%d "%s" (sprite %d, warna %d)'):format(data.id, data.label, data.sprite, data.color))
    return result('Blip disimpan.')
end)

adminCallback('update', function(src, id, d)
    local b = find(id)
    if not b then return { ok = false, msg = 'Blip tidak ditemukan.' } end
    local data, err = validate(d)
    if not data then return { ok = false, msg = err } end

    for k, v in pairs(data) do b[k] = v end
    b.dirty = true
    save()
    log(src, ('mengubah blip #%d "%s"'):format(id, b.label))
    return result('Blip diperbarui.')
end)

adminCallback('move', function(src, id)
    local b = find(id)
    if not b then return { ok = false, msg = 'Blip tidak ditemukan.' } end

    b.coords = GetEntityCoords(GetPlayerPed(src))
    b.dirty = true
    save()
    log(src, ('memindah blip #%d "%s" ke %.2f, %.2f, %.2f'):format(id, b.label, b.coords.x, b.coords.y, b.coords.z))
    return result('Blip dipindah ke posisi kamu.')
end)

adminCallback('delete', function(src, id)
    local b, i = find(id)
    if not b then return { ok = false, msg = 'Blip tidak ditemukan.' } end

    table.remove(List, i)
    save()
    log(src, ('menghapus blip #%d "%s"'):format(id, b.label))
    return result('Blip dihapus.')
end)

RegisterCommand(Config.Command, function(src)
    if src == 0 or not isAdmin(src) then return end
    TriggerClientEvent('f_blips:client:openAdmin', src)
end, false)
