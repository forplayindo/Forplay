-- Jalur tol (server & client): urutan gerbang, arah perjalanan, tarif rute.
local config = require 'config.shared'

local route = {}
local order = config.gateOrder
local index = {}
for i, id in ipairs(order) do index[id] = i end

function route.forward(heading)
    local r = math.rad(heading)
    return vec3(-math.sin(r), math.cos(r), 0.0)
end

---'N' = menuju gerbang terakhir di gateOrder (Paleto), 'S' = menuju gerbang pertama (kota)
function route.dir(gateId, fwd)
    local i = index[gateId]
    if not i or #order < 2 then return 'N' end
    local a = config.gates[order[math.max(1, i - 1)]].coords
    local b = config.gates[order[math.min(#order, i + 1)]].coords
    return (fwd.x * (b.x - a.x) + fwd.y * (b.y - a.y)) >= 0 and 'N' or 'S'
end

---`to` ada di depan `from` untuk arah `dir`
function route.ahead(from, to, dir)
    local a, b = index[from], index[to]
    if not a or not b then return false end
    if dir == 'N' then return b > a end
    return b < a
end

---Gerbang terakhir untuk arah ini (keluar tol)
function route.terminal(gateId, dir)
    local i = index[gateId]
    return (dir == 'N' and i == #order) or (dir == 'S' and i == 1)
end

---Gerbang sebelumnya di arah perjalanan
function route.previous(gateId, dir)
    local i = index[gateId]
    return i and order[i + (dir == 'N' and -1 or 1)]
end

function route.fare(a, b)
    if a == b then return 0 end
    local r = config.fare.routes
    return r[a .. ':' .. b] or r[b .. ':' .. a] or 0
end

---Tarif termahal dari gerbang ini ke depan (saldo minimal saat masuk)
function route.maxAhead(gateId, dir)
    local best = 0
    for _, id in ipairs(order) do
        if route.ahead(gateId, id, dir) then best = math.max(best, route.fare(gateId, id)) end
    end
    return best
end

return route
