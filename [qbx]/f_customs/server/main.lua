-- f_customs (server): hanya memeriksa posisi pemain (di dalam zona kustom) / izin admin,
-- lalu meneruskan ke f_mechanicjob yang menghitung harga, membuat order kasir, dan memasang mod.
local cfg = require 'config.shared'

---Titik di dalam poligon (2D) + selisih tinggi.
local function inPoly(p, points)
    local inside, j = false, #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if ((a.y > p.y) ~= (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) then
            inside = not inside
        end
        j = i
    end
    return inside and math.abs(p.z - points[1].z) <= cfg.thickness / 4 -- sama dengan lib.zones (client)
end

---Jenis zona (station) di koordinat ini: 'mod' / 'paint' / nil.
local function stationAt(pos)
    for _, z in ipairs(cfg.zones) do
        if inPoly(pos, z.points) then return z.station end
    end
end

---Dipakai f_mechanicjob: order hanya dipasang di zona dengan jenis yang sama.
exports('StationAt', function(coords)
    return coords and stationAt(vec3(coords.x, coords.y, coords.z)) or nil
end)

local function isAdmin(src)
    return exports.qbx_core:HasPermission(src, 'admin')
end

---@return string? err, string? station
local function check(src, admin)
    if GetResourceState('f_mechanicjob') ~= 'started' then return 'Bengkel sedang tidak tersedia' end
    if admin then
        if not isAdmin(src) then return 'Tidak punya izin' end
        return
    end
    local ped = GetPlayerPed(src)
    local station = ped ~= 0 and stationAt(GetEntityCoords(ped))
    if not station then return 'Kamu harus berada di zona kustom' end
    return nil, station
end

lib.callback.register('f_customs:server:info', function(src, netId, admin)
    local err, station = check(src, admin)
    if err then return { error = err } end
    local info = exports.f_mechanicjob:CustomInfo(src, netId)
    if admin and not info.error then info.free, info.admin = true, true end
    info.station = station
    return info
end)

local busy = {}
---@param dry boolean true = hanya hitung harga (konfirmasi)
lib.callback.register('f_customs:server:submit', function(src, netId, lines, dry, admin)
    local err, station = check(src, admin)
    if err then return { error = err } end
    if busy[src] then return { error = 'Tunggu sebentar' } end
    busy[src] = true
    local ok, res = pcall(function()
        return exports.f_mechanicjob:CustomSubmit(src, netId, lines, { dry = dry == true, admin = admin == true, station = station })
    end)
    busy[src] = nil
    if not ok then
        print(('[f_customs] submit gagal: %s'):format(res))
        return { error = 'Terjadi kesalahan' }
    end
    return res
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
