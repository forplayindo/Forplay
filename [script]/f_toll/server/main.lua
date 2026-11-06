-- F_Toll server: semua keputusan (tap, saldo, lewat gerbang, tabrakan palang, dispatch) dibuat di sini.
-- Client hanya menampilkan palang & mengirim permintaan tap / laporan tabrakan.
local config = require 'config.shared'
local serverConfig = require 'config.server'
local route = require 'shared.route'

local CARD = config.card.item
local LAND = { automobile = true, bike = true, quadbike = true, amphibious_automobile = true, amphibious_quadbike = true }

local data = { lanes = {}, lokets = {} }
local lanes = {}      -- id -> lane (dari data/lanes.json)
local geo = {}        -- id -> { gate, dir, fwd, side, tap, bar }
local gateLanes = {}  -- gate -> { id, ... }
local laneState = {}  -- id -> { state, hits, lastHit, openFor, openUntil, entry, brokenUntil }
local track = {}      -- src -> { [laneId] = posisi along terakhir }
local lastBreach = {} -- src -> { [gate] = os.time() }
local hitCooldown = {}
local busy = {}

local admins = {}
for _, id in ipairs(serverConfig.editorLicenses or {}) do admins[id:lower()] = true end

local function isAdmin(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if admins[id:lower()] then return true end
    end
    return false
end

local function rupiah(n)
    return 'Rp ' .. lib.math.groupdigits(math.floor(n or 0), '.')
end

---------------------------------------------------------------------------
-- Data lajur
---------------------------------------------------------------------------

local function makeGeo(l)
    local fwd = route.forward(l.tap.w)
    return {
        gate = l.gate,
        dir = route.dir(l.gate, fwd), -- arah lajur: N = menuju Paleto, S = menuju kota
        fwd = fwd,
        side = vec3(fwd.y, -fwd.x, 0.0),
        tap = vec3(l.tap.x, l.tap.y, l.tap.z),
        bar = vec3(l.barrier.x, l.barrier.y, l.barrier.z),
    }
end

local function rebuild()
    lanes, geo, gateLanes = {}, {}, {}
    for _, l in ipairs(data.lanes) do
        if config.gates[l.gate] then
            lanes[l.id] = l
            geo[l.id] = makeGeo(l)
            gateLanes[l.gate] = gateLanes[l.gate] or {}
            gateLanes[l.gate][#gateLanes[l.gate] + 1] = l.id
            laneState[l.id] = laneState[l.id] or { state = 'closed', hits = 0, lastHit = 0 }
        end
    end
    for id in pairs(laneState) do
        if not lanes[id] then laneState[id] = nil end
    end
end

local function load()
    local raw = LoadResourceFile(cache.resource, 'data/lanes.json')
    local ok, decoded = pcall(json.decode, raw or '')
    if ok and type(decoded) == 'table' then
        data.lanes = decoded.lanes or {}
        data.lokets = decoded.lokets or {}
    end
    rebuild()
end

local function save()
    SaveResourceFile(cache.resource, 'data/lanes.json', json.encode(data, { indent = true }), -1)
end

local function states()
    local out = {}
    for id, s in pairs(laneState) do out[id] = s.state end
    return out
end

local function broadcastData()
    TriggerClientEvent('f_toll:client:data', -1, data.lanes, data.lokets, states())
end

local function setState(id, state)
    local s = laneState[id]
    if not s then return end
    s.state = state
    TriggerClientEvent('f_toll:client:state', -1, id, state)
end

-- along: posisi sepanjang lajur dari garis palang (+ = sudah lewat). across: jarak dari garis tengah lajur.
local function laneLocal(g, pos)
    local b = pos - g.bar
    local t = pos - g.tap
    return b.x * g.fwd.x + b.y * g.fwd.y, math.abs(t.x * g.side.x + t.y * g.side.y), math.abs(pos.z - g.tap.z)
end

---------------------------------------------------------------------------
-- Tarif & kartu
---------------------------------------------------------------------------

local function addRevenue(amount, reason)
    if not config.revenueAccount or amount <= 0 then return end
    local ok, added = pcall(function() return exports['Renewed-Banking']:addAccountMoney(config.revenueAccount, amount) end)
    if not (ok and added) then
        lib.print.error(('%s %s gagal masuk ke rekening %s'):format(reason, rupiah(amount), config.revenueAccount))
    end
end

local function newSerial()
    return ('ET %04d %04d'):format(math.random(0, 9999), math.random(0, 9999))
end

local function cardDescription(m)
    local text = ('No. %s  \nSaldo: %s'):format(m.serial, rupiah(m.balance))
    if m.trip and config.gates[m.trip.gate] then
        text = text .. ('  \nMasuk: %s'):format(config.gates[m.trip.gate].label)
    end
    return text
end

local function findCards(src)
    return exports.ox_inventory:Search(src, 'slots', CARD) or {}
end

local function writeCard(src, slot, m)
    m.description = cardDescription(m)
    exports.ox_inventory:SetMetadata(src, slot, m)
end

-- kartu tanpa nomor (mis. dari /giveitem) dilengkapi dulu
local function ensureMeta(src, s)
    local m = s.metadata or {}
    if not m.serial then
        m.serial = newSerial()
        m.balance = math.floor(tonumber(m.balance) or 0)
        writeCard(src, s.slot, m)
    end
    s.metadata = m
    return m
end

-- kartu dengan perjalanan terbuka dulu, kalau tidak ada: saldo terbesar
local function pickCard(src)
    local best
    for _, s in ipairs(findCards(src)) do
        local m = s.metadata or {}
        if m.trip then return s end
        if not best or (m.balance or 0) > ((best.metadata or {}).balance or 0) then best = s end
    end
    return best
end

local function findBySerial(src, serial)
    for _, s in ipairs(findCards(src)) do
        if s.metadata and s.metadata.serial == serial then return s end
    end
end

---------------------------------------------------------------------------
-- Dispatch polisi
---------------------------------------------------------------------------

local function plateOf(veh)
    return (GetVehicleNumberPlateText(veh) or '?'):gsub('^%s+', ''):gsub('%s+$', '')
end

local function dispatch(src, gateId, body)
    local gate = config.gates[gateId]
    lastBreach[src] = lastBreach[src] or {}
    lastBreach[src][gateId] = os.time()

    local coords = gate.coords
    local _, cops = exports.qbx_core:GetDutyCountType(config.dispatch.jobType)
    for _, cop in ipairs(cops or {}) do
        pcall(function()
            exports['f_phone']:emergencyAlert(cop, {
                app = 'Dispatch',
                appId = 'maps',
                title = 'Pelanggaran Gerbang Tol',
                body = body,
                time = 'now',
            })
        end)
        TriggerClientEvent('f_toll:client:dispatchBlip', cop, coords, gate.label)
    end
    lib.print.info(('[dispatch] %s (%s): %s'):format(GetPlayerName(src) or src, src, body))
end

local function recentlyReported(src, gateId)
    local t = lastBreach[src] and lastBreach[src][gateId]
    return t and os.time() - t < config.dispatch.cooldown
end

---------------------------------------------------------------------------
-- Kendaraan & lewat gerbang
---------------------------------------------------------------------------

local function driverVehicle(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if not LAND[GetVehicleType(veh)] then return end
    return veh
end

local function commitEntry(src, entry)
    local s = findBySerial(src, entry.serial)
    if not s then return end
    local m = s.metadata
    m.trip = { gate = entry.gate, dir = entry.dir, t = os.time(), paid = 0 }
    writeCard(src, s.slot, m)
end

local function closeLater(id, src)
    SetTimeout(3000, function()
        local s = laneState[id]
        if s and s.state == 'open' and (s.openFor == nil or s.openFor == src) then
            s.openFor, s.entry = nil, nil
            setState(id, 'closed')
        end
    end)
end

local function crossed(src, id, veh, forward)
    local s, l = laneState[id], lanes[id]
    if forward and s.openFor == src and os.time() <= (s.openUntil or 0) + 5 then
        if s.entry then commitEntry(src, s.entry) end
        s.entry = nil
        if s.state == 'open' then closeLater(id, src) else s.openFor = nil end
        return
    end
    if recentlyReported(src, l.gate) then return end
    local gate = config.gates[l.gate]
    local how = forward and 'menerobos' or 'melawan arah di'
    dispatch(src, l.gate, ('Kendaraan plat %s %s %s tanpa membayar.'):format(plateOf(veh), how, gate.label))
end

CreateThread(function()
    while true do
        Wait(300)
        local now = os.time()

        for id, s in pairs(laneState) do
            if s.state == 'open' and now >= (s.openUntil or 0) + 5 then
                s.openFor, s.entry = nil, nil
                setState(id, 'closed')
            elseif s.state == 'broken' and now >= (s.brokenUntil or 0) then
                s.hits, s.openFor, s.entry = 0, nil, nil
                setState(id, 'closed')
            elseif s.state == 'broken' and s.openFor and now > (s.openUntil or 0) + 5 then
                s.openFor, s.entry = nil, nil
            end
        end

        for _, sid in ipairs(GetPlayers()) do
            local src = tonumber(sid)
            local veh = driverVehicle(src)
            local t = track[src]
            if not veh then
                if t then track[src] = nil end
            else
                local pos = GetEntityCoords(veh)
                local seen
                for gateId, gate in pairs(config.gates) do
                    local list = gateLanes[gateId]
                    if list and #(pos - gate.coords) < 80.0 then
                        for _, id in ipairs(list) do
                            local along, across, dz = laneLocal(geo[id], pos)
                            if across <= config.zone.halfWidth and math.abs(along) <= config.zone.length and dz <= config.zone.height then
                                t = t or {}
                                track[src] = t
                                local prev = t[id]
                                if prev then
                                    if prev < 0 and along >= 0 then
                                        crossed(src, id, veh, true)
                                    elseif prev > 0 and along <= 0 then
                                        crossed(src, id, veh, false)
                                    end
                                end
                                t[id] = along
                                seen = seen or {}
                                seen[id] = true
                            end
                        end
                    end
                end
                if t then
                    for id in pairs(t) do
                        if not (seen and seen[id]) then t[id] = nil end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Tap kartu
---------------------------------------------------------------------------

lib.callback.register('f_toll:server:tap', function(src, id)
    local l, g, s = lanes[id], geo[id], laneState[id]
    if not l or busy[src] then return { ok = false } end

    local veh = driverVehicle(src)
    if not veh then return { ok = false, msg = 'Kamu harus menyetir kendaraan darat.' } end
    if #(GetEntityCoords(veh) - g.tap) > config.tap.distance + 2.0 then
        return { ok = false, msg = 'Terlalu jauh dari bilik tol.' }
    end
    local diff = math.abs(((GetEntityHeading(veh) - l.tap.w + 180.0) % 360.0) - 180.0)
    if diff > config.tap.maxAngle + 15.0 then
        return { ok = false, msg = 'Salah lajur. Gunakan lajur dengan tanda hijau.' }
    end
    if s.openFor == src and os.time() <= (s.openUntil or 0) then
        return { ok = false, msg = 'Palang sudah terbuka, silakan jalan.' }
    end
    if s.state == 'open' and s.openFor and s.openFor ~= src then
        return { ok = false, msg = 'Palang sedang terbuka untuk kendaraan lain.' }
    end

    local card = pickCard(src)
    if not card then return { ok = false, code = 'nocard', msg = 'Kamu tidak punya kartu e-toll. Beli di loket tol atau minimarket.' } end

    busy[src] = true
    local m = ensureMeta(src, card)
    local gate = config.gates[l.gate]
    local trip = m.trip
    local valid = trip and config.gates[trip.gate] and trip.dir == g.dir and route.ahead(trip.gate, l.gate, g.dir)
        and os.time() - (trip.t or 0) <= config.fare.tripTimeout
    local final = route.terminal(l.gate, g.dir)
    local result

    if valid or final then
        -- lewat gerbang tengah (bayar sebagian) atau keluar di gerbang akhir (bayar sisanya).
        -- Keluar tanpa catatan masuk yang sah = tarif dari gerbang sebelumnya.
        local fromId = valid and trip.gate or route.previous(l.gate, g.dir)
        local paid = valid and (trip.paid or 0) or 0
        local price = math.max(0, route.fare(fromId, l.gate) - paid)
        local from = config.gates[fromId].label
        if (m.balance or 0) < price then
            busy[src] = nil
            return { ok = false, code = 'saldo', fare = price, balance = m.balance or 0, gate = gate.label, from = from,
                msg = ('Saldo kurang. Tarif %s, saldo %s. Isi ulang dulu.'):format(rupiah(price), rupiah(m.balance)) }
        end
        m.balance = m.balance - price
        if final then
            m.trip = nil
        else
            m.trip = { gate = fromId, dir = g.dir, t = os.time(), paid = paid + price }
        end
        writeCard(src, card.slot, m)
        addRevenue(price, 'Tarif tol')
        s.entry = nil
        result = { ok = true, mode = final and 'exit' or 'pass', fare = price, total = paid + price, balance = m.balance,
            gate = gate.label, from = from }
    else
        -- masuk: dicatat di kartu setelah mobil benar-benar lewat palang
        local need = route.maxAhead(l.gate, g.dir)
        if (m.balance or 0) < need then
            busy[src] = nil
            return { ok = false, code = 'saldo', balance = m.balance or 0, gate = gate.label,
                msg = ('Saldo minimal masuk tol di sini %s. Isi ulang dulu.'):format(rupiah(need)) }
        end
        if trip then
            -- perjalanan lama tidak tuntas (crash, mati, putar balik, kedaluwarsa): dibuang tanpa potongan
            m.trip = nil
            writeCard(src, card.slot, m)
        end
        s.entry = { serial = m.serial, gate = l.gate, dir = g.dir }
        result = { ok = true, mode = 'entry', balance = m.balance, gate = gate.label }
    end

    s.hits = 0
    s.openFor = src
    s.openUntil = os.time() + config.tap.openTime
    if s.state ~= 'broken' then setState(id, 'open') end
    busy[src] = nil
    return result
end)

---------------------------------------------------------------------------
-- Tabrakan palang: tahan 2x, patah di tabrakan ke-3
---------------------------------------------------------------------------

RegisterNetEvent('f_toll:server:hit', function(id, kmh)
    local src = source
    local s, g, l = laneState[id], geo[id], lanes[id]
    if not s or type(kmh) ~= 'number' then return end

    local now = GetGameTimer()
    if (hitCooldown[src] or 0) > now then return end
    hitCooldown[src] = now + 2000

    if s.state ~= 'closed' or kmh < config.hits.speed then return end
    local veh = driverVehicle(src)
    if not veh or #(GetEntityCoords(veh) - g.bar) > 12.0 then return end

    local t = os.time()
    if t - (s.lastHit or 0) > config.hits.resetAfter then s.hits = 0 end
    s.hits = (s.hits or 0) + 1
    s.lastHit = t

    if s.hits < config.hits.breakAt then
        exports.qbx_core:Notify(src, 'Hati-hati, kamu menabrak palang tol!', 'error')
        return
    end

    s.hits = 0
    s.brokenUntil = t + config.hits.restoreAfter
    setState(id, 'broken')
    local gate = config.gates[l.gate]
    dispatch(src, l.gate, ('Palang %s dijebol kendaraan plat %s.'):format(gate.label, plateOf(veh)))
end)

---------------------------------------------------------------------------
-- Loket (NPC gerbang & minimarket): beli kartu, isi saldo
---------------------------------------------------------------------------

local function nearLoket(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, k in ipairs(data.lokets) do
        if #(pos - vec3(k.x, k.y, k.z)) <= config.loket.distance + 2.0 then return true end
    end
    for _, c in ipairs(config.minimarkets) do
        if #(pos - c) <= config.minimarketDistance + 2.0 then return true end
    end
    return false
end

local function loketData(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local cards = {}
    for _, s in ipairs(findCards(src)) do
        local m = ensureMeta(src, s)
        cards[#cards + 1] = {
            serial = m.serial,
            balance = m.balance or 0,
            trip = m.trip and config.gates[m.trip.gate] and config.gates[m.trip.gate].label or nil,
        }
    end
    return {
        cards = cards,
        cash = player.PlayerData.money.cash or 0,
        bank = player.PlayerData.money.bank or 0,
        price = config.card.price,
        topups = config.card.topups,
        min = config.card.minTopup,
        max = config.card.maxBalance,
    }
end

local function pay(src, method, amount, reason)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    return player.Functions.RemoveMoney(method == 'bank' and 'bank' or 'cash', amount, reason)
end

lib.callback.register('f_toll:server:loket', function(src)
    if not nearLoket(src) then return end
    return loketData(src)
end)

lib.callback.register('f_toll:server:buyCard', function(src, method)
    if busy[src] then return { ok = false } end
    if not nearLoket(src) then return { ok = false, msg = 'Kamu terlalu jauh dari loket.' } end
    if not exports.ox_inventory:CanCarryItem(src, CARD, 1) then return { ok = false, msg = 'Tas kamu penuh.' } end

    busy[src] = true
    local price = config.card.price
    if not pay(src, method, price, 'beli-kartu-etoll') then
        busy[src] = nil
        return { ok = false, msg = method == 'bank' and 'Saldo bank tidak cukup.' or 'Uang cash tidak cukup.' }
    end
    local m = { serial = newSerial(), balance = 0 }
    m.description = cardDescription(m)
    if not exports.ox_inventory:AddItem(src, CARD, 1, m) then
        local player = exports.qbx_core:GetPlayer(src)
        if player then player.Functions.AddMoney(method == 'bank' and 'bank' or 'cash', price, 'refund-kartu-etoll') end
        busy[src] = nil
        return { ok = false, msg = 'Gagal memberi kartu, uang dikembalikan.' }
    end
    addRevenue(price, 'Penjualan kartu e-toll')
    busy[src] = nil
    return { ok = true, msg = ('Kartu e-toll %s dibeli.'):format(m.serial), data = loketData(src) }
end)

lib.callback.register('f_toll:server:topup', function(src, serial, amount, method)
    amount = math.floor(tonumber(amount) or 0)
    if busy[src] or type(serial) ~= 'string' then return { ok = false } end
    if not nearLoket(src) then return { ok = false, msg = 'Kamu terlalu jauh dari loket.' } end
    if amount < config.card.minTopup then return { ok = false, msg = ('Isi ulang minimal %s.'):format(rupiah(config.card.minTopup)) } end

    local s = findBySerial(src, serial)
    if not s then return { ok = false, msg = 'Kartu tidak ditemukan di tas kamu.' } end
    local m = s.metadata
    if (m.balance or 0) + amount > config.card.maxBalance then
        return { ok = false, msg = ('Saldo maksimal kartu %s.'):format(rupiah(config.card.maxBalance)) }
    end

    busy[src] = true
    if not pay(src, method, amount, 'isi-saldo-etoll') then
        busy[src] = nil
        return { ok = false, msg = method == 'bank' and 'Saldo bank tidak cukup.' or 'Uang cash tidak cukup.' }
    end
    s = findBySerial(src, serial) or s
    m = s.metadata
    m.balance = (m.balance or 0) + amount
    writeCard(src, s.slot, m)
    busy[src] = nil
    return { ok = true, msg = ('Saldo %s ditambah %s. Saldo sekarang %s.'):format(m.serial, rupiah(amount), rupiah(m.balance)), data = loketData(src) }
end)

---------------------------------------------------------------------------
-- Data untuk client
---------------------------------------------------------------------------

lib.callback.register('f_toll:server:init', function()
    return { lanes = data.lanes, lokets = data.lokets, states = states() }
end)

---------------------------------------------------------------------------
-- Editor admin: /tolatur
---------------------------------------------------------------------------

local function num(v) return type(v) == 'number' and v == v and math.abs(v) < 20000 end
local function validPoint(p) return type(p) == 'table' and num(p.x) and num(p.y) and num(p.z) and num(p.w) end
local function round(v) return math.floor(v * 100 + 0.5) / 100 end
local function point(p) return { x = round(p.x), y = round(p.y), z = round(p.z), w = round(p.w % 360.0) } end

local function editorPayload()
    return { lanes = data.lanes, lokets = data.lokets }
end

RegisterCommand('tolatur', function(src)
    if src == 0 or not isAdmin(src) then return end
    TriggerClientEvent('f_toll:client:editor', src, editorPayload())
end, false)

RegisterCommand('tolarm', function(src, args)
    if src == 0 or not isAdmin(src) then return end
    TriggerClientEvent('f_toll:client:armOffset', src, tonumber(args[1]), tonumber(args[2]), tonumber(args[3]))
end, false)

lib.callback.register('f_toll:server:addLane', function(src, gateId, tap, bar)
    if not isAdmin(src) then return { ok = false } end
    if not validPoint(tap) or not validPoint(bar) then return { ok = false, msg = 'Data lajur tidak valid.' } end
    local tp, bp = vec3(tap.x, tap.y, tap.z), vec3(bar.x, bar.y, bar.z)

    -- lajur masuk ke gerbang terdekat (bukan harus gerbang yang diklik di menu)
    local best, bestDist
    for id, g in pairs(config.gates) do
        local d = #(tp.xy - g.coords.xy)
        if not bestDist or d < bestDist then best, bestDist = id, d end
    end
    if not best or bestDist > config.editor.maxDistance then
        return { ok = false, msg = ('Titik tap terlalu jauh dari gerbang mana pun (terdekat %s, %d m; maks %d m).')
            :format(best and config.gates[best].label or '-', math.floor(bestDist or 0), math.floor(config.editor.maxDistance)) }
    end
    gateId = best
    local gate = config.gates[gateId]
    if #(gateLanes[gateId] or {}) >= config.editor.maxLanesPerGate then return { ok = false, msg = 'Lajur di gerbang ini sudah maksimal.' } end
    if #(bp - tp) > 12.0 then return { ok = false, msg = 'Palang terlalu jauh dari titik tap (maks 12 m).' } end

    local id = ('ln%d%03d'):format(os.time(), math.random(0, 999))
    data.lanes[#data.lanes + 1] = { id = id, gate = gateId, tap = point(tap), barrier = point(bar) }
    rebuild()
    save()
    broadcastData()
    lib.print.info(('%s menambah lajur %s di %s'):format(GetPlayerName(src), id, gate.label))
    return { ok = true, gate = gate.label, data = editorPayload() }
end)

lib.callback.register('f_toll:server:deleteLane', function(src, id)
    if not isAdmin(src) then return { ok = false } end
    for i, l in ipairs(data.lanes) do
        if l.id == id then
            table.remove(data.lanes, i)
            rebuild()
            save()
            broadcastData()
            return { ok = true, data = editorPayload() }
        end
    end
    return { ok = false, msg = 'Lajur tidak ditemukan.' }
end)

lib.callback.register('f_toll:server:testLane', function(src, id)
    if not isAdmin(src) or not laneState[id] then return { ok = false } end
    local s = laneState[id]
    if s.state ~= 'closed' then return { ok = false, msg = 'Palang sedang tidak tertutup.' } end
    s.openFor, s.entry = nil, nil
    s.openUntil = os.time() + 3
    setState(id, 'open')
    return { ok = true }
end)

lib.callback.register('f_toll:server:setLoket', function(src, gateId, p)
    if not isAdmin(src) then return { ok = false } end
    local gate = config.gates[gateId]
    if not gate or not validPoint(p) then return { ok = false, msg = 'Data loket tidak valid.' } end
    if #(vec3(p.x, p.y, p.z) - gate.coords) > 150.0 then return { ok = false, msg = 'Loket terlalu jauh dari gerbang.' } end
    for i = #data.lokets, 1, -1 do
        if data.lokets[i].gate == gateId then table.remove(data.lokets, i) end
    end
    local k = point(p)
    k.gate = gateId
    data.lokets[#data.lokets + 1] = k
    save()
    broadcastData()
    return { ok = true, data = editorPayload() }
end)

lib.callback.register('f_toll:server:deleteLoket', function(src, gateId)
    if not isAdmin(src) then return { ok = false } end
    for i = #data.lokets, 1, -1 do
        if data.lokets[i].gate == gateId then table.remove(data.lokets, i) end
    end
    save()
    broadcastData()
    return { ok = true, data = editorPayload() }
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src], track[src], lastBreach[src], hitCooldown[src] = nil, nil, nil, nil
    for _, s in pairs(laneState) do
        if s.openFor == src then s.openFor, s.entry = nil, nil end
    end
end)

load()
