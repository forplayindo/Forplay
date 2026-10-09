-- Command admin untuk tes kondisi kendaraan (kendaraan yang sedang dinaiki, atau terdekat <= 5 m).
--  /setkondisi <bagian> <persen>   bagian: oil coolant brakefluid transfluid sparkplugs airfilter radiator
--                                  clutch axle suspension brakes engine body tank ban semua
--  /rusakkan                       kerusakan acak (untuk tes panel & efek)
--  /kondisipenuh                   semua bagian kembali 100%
local cfg = require 'config.shared'
local RESTRICT = 'group.admin'

local function targetVehicle(src)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local pos, best, bestDist = GetEntityCoords(ped), nil, 5.0
    for _, v in ipairs(GetAllVehicles()) do
        local d = #(GetEntityCoords(v) - pos)
        if d <= bestDist then best, bestDist = v, d end
    end
    return best
end

local function getTarget(src)
    local veh = targetVehicle(src)
    if not veh then
        exports.qbx_core:Notify(src, 'Tidak ada kendaraan (naiki atau berdiri <= 5 m dari kendaraan)', 'error')
        return
    end
    local c = Condition.Get(veh)
    if not c then
        exports.qbx_core:Notify(src, 'Jenis kendaraan ini tidak didukung', 'error')
        return
    end
    return veh, c
end

---Nilai bawaan GTA diterapkan oleh pemegang fisika kendaraan.
local function setNative(src, veh, values)
    local owner = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 then owner = src end
    TriggerClientEvent('f_mechanicjob:client:setNative', owner, NetworkGetNetworkIdFromEntity(veh), values)
end

local function clamp(v) return math.max(0.0, math.min(100.0, v)) end

lib.addCommand('setkondisi', {
    help = 'Atur kondisi bagian kendaraan (tes mekanik)',
    params = {
        { name = 'bagian', type = 'string', help = 'oil, coolant, brakefluid, transfluid, sparkplugs, airfilter, radiator, clutch, axle, suspension, brakes, engine, body, tank, ban, semua' },
        { name = 'persen', type = 'number', help = '0 - 100' },
    },
    restricted = RESTRICT,
}, function(src, args)
    local veh, c = getTarget(src)
    if not veh then return end
    local part, value = tostring(args.bagian):lower(), clamp(tonumber(args.persen) or 100)
    local native = {}

    if part == 'semua' then
        for _, k in ipairs(cfg.custom) do c[k] = value end
        for k in pairs(c.tw) do c.tw[k] = value end
        native = { engine = value, body = value, tank = value }
    elseif part == 'ban' then
        for k in pairs(c.tw) do c.tw[k] = value end
    elseif cfg.parts[part] and cfg.parts[part].native then
        native[cfg.parts[part].native] = value
    elseif cfg.parts[part] then
        c[part] = value
    else
        return exports.qbx_core:Notify(src, ('Bagian "%s" tidak dikenal'):format(part), 'error')
    end

    Condition.Set(veh, c)
    if next(native) then setNative(src, veh, native) end
    exports.qbx_core:Notify(src, ('%s diatur ke %d%%'):format(part, value), 'success')
end)

lib.addCommand('rusakkan', {
    help = 'Kerusakan acak pada kendaraan (tes mekanik)',
    restricted = RESTRICT,
}, function(src)
    local veh, c = getTarget(src)
    if not veh then return end
    for _, k in ipairs(cfg.custom) do c[k] = math.random(5, 75) + 0.0 end
    local burst
    for k in pairs(c.tw) do
        c.tw[k] = math.random(10, 70) + 0.0
        burst = burst or k
    end
    Condition.Set(veh, c)

    local index
    for _, t in ipairs(cfg.tyres[Condition.Kind(veh)]) do
        if t.key == burst then index = t.index end
    end
    setNative(src, veh, { engine = math.random(30, 60), body = math.random(30, 60), tank = math.random(50, 80), burst = { index } })
    exports.qbx_core:Notify(src, 'Kendaraan dirusak secara acak', 'success')
end)

lib.addCommand('kondisipenuh', {
    help = 'Semua bagian kendaraan kembali 100% (tes mekanik)',
    restricted = RESTRICT,
}, function(src)
    local veh, c = getTarget(src)
    if not veh then return end
    for _, k in ipairs(cfg.custom) do c[k] = 100.0 end
    for k in pairs(c.tw) do c.tw[k] = 100.0 end
    Condition.Set(veh, c)
    for idx = 0, 7 do
        if Entity(veh).state['f_mech:wheelOff:' .. idx] then Entity(veh).state:set('f_mech:wheelOff:' .. idx, nil, true) end
    end
    setNative(src, veh, { engine = 100, body = 100, tank = 100, fixAll = true })
    exports.qbx_core:Notify(src, 'Semua bagian kendaraan 100%', 'success')
end)
