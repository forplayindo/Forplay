-- Helper kecil: envelope balasan ke UI, sanitasi teks & angka.
local util = {}

---@param data any
function util.ok(data) return { ok = true, data = data } end

---@param msg string
function util.fail(msg) return { ok = false, err = msg } end

---Teks satu baris yang aman ditampilkan: tanpa karakter kontrol, tanpa < >, spasi dirapikan,
---dipotong ke `max` karakter (aman untuk UTF-8).
---@param value any
---@param max integer
---@return string
function util.text(value, max)
    if type(value) ~= 'string' then return '' end
    local s = value:gsub('%c', ' '):gsub('[<>]', ''):gsub('%s+', ' ')
    s = s:match('^%s*(.-)%s*$') or ''
    if not utf8.len(s) then s = s:gsub('[\128-\255]', '') end
    if utf8.len(s) > max then
        s = s:sub(1, utf8.offset(s, max + 1) - 1)
    end
    return s
end

---Bilangan bulat dalam rentang, atau nil.
---@param value any
---@param min integer
---@param max integer
---@return integer?
function util.int(value, min, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    if n < min or n > max then return nil end
    return n
end

---Warna hex #rrggbb, atau nil.
---@param value any
---@return string?
function util.color(value)
    if type(value) ~= 'string' then return nil end
    return value:match('^#%x%x%x%x%x%x$') and value:lower() or nil
end

---Nama karakter dari charinfo (tabel atau JSON).
---@param charinfo any
---@return string
function util.charName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) end
    if type(charinfo) ~= 'table' then return 'Tidak dikenal' end
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):match('^%s*(.-)%s*$')
end

return util
