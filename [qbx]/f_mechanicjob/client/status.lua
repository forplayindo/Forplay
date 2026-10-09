-- "Status Kendaraan" untuk semua pemain: item radial menu saat berada di dalam kendaraan.
-- Hanya teks + titik warna (tanpa persen); angka detail hanya terlihat lewat panel mekanik.
local cfg = require 'config.shared'
local W = require 'config.wear'

local DOTS = { '🟢', '🟡', '🟠', '🔴' }
local RADIAL_ID = 'f_mechanicjob:status'

local function level(v)
    v = tonumber(v) or 100
    for i, min in ipairs(cfg.levels) do
        if v >= min then return i end
    end
    return #cfg.levels + 1
end

local function showStatus()
    local veh = cache.vehicle
    if not veh then return end
    local c = Entity(veh).state['f_mech:cond']
    local bike = IsThisModelABike(GetEntityModel(veh))
    local plate = GetVehicleNumberPlateText(veh):gsub('^%s+', ''):gsub('%s+$', '')
    local name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    if name == 'NULL' then name = 'Kendaraan' end

    local values = {
        engine = GetVehicleEngineHealth(veh) / 10,
        body = MechBodyCondition(veh), -- client/wear.lua: termasuk penyok, kaca pecah, pintu & bumper
        tank = GetVehiclePetrolTankHealth(veh) / 10,
    }
    if type(c) == 'table' then
        for _, key in ipairs(cfg.custom) do values[key] = c[key] end
    end

    local rows = {}
    -- urutan sesuai panel mekanik
    for _, group in ipairs(cfg.groups) do
        for _, key in ipairs(group[2]) do
            if key == 'TYRES' then
                for _, t in ipairs(cfg.tyres[bike and 'bike' or 'car']) do
                    if Entity(veh).state['f_mech:wheelOff:' .. t.index] then
                        rows[#rows + 1] = { 4, ('%s %s — roda lepas'):format(DOTS[4], t.label) }
                    elseif IsVehicleTyreBurst(veh, t.index, false) then
                        rows[#rows + 1] = { 4, ('%s %s — bocor'):format(DOTS[4], t.label) }
                    elseif type(c) == 'table' and c.tw and (c.tw[t.key] or 100) < cfg.needs then
                        local lv = level(c.tw[t.key])
                        rows[#rows + 1] = { lv, ('%s %s — %s'):format(DOTS[lv], t.label, cfg.tyre.fx[lv]:lower()) }
                    end
                end
            elseif values[key] and values[key] < cfg.needs then
                local def = cfg.parts[key]
                local lv = level(values[key])
                rows[#rows + 1] = { lv, ('%s %s — %s'):format(DOTS[lv], bike and def.bikeLabel or def.label, def.fx[lv]:lower()) }
            end
        end
    end
    table.sort(rows, function(a, b) return a[1] > b[1] end)

    local lines = {}
    for i, r in ipairs(rows) do lines[i] = r[2] end
    local desc
    if #lines == 0 then
        desc = DOTS[1] .. ' Semua bagian dalam kondisi baik.'
    else
        desc = table.concat(lines, '  \n') .. '  \n  \nSegera bawa ke mekanik.'
    end

    lib.notify({
        title = ('Status Kendaraan — %s · %s'):format(name, plate),
        description = desc,
        type = #lines == 0 and 'success' or 'inform',
        duration = 10000 + #lines * 1000,
        icon = 'car-burst',
    })
end

lib.onCache('vehicle', function(veh)
    if veh and not W.ignoredClasses[GetVehicleClass(veh)] then
        lib.addRadialItem({ id = RADIAL_ID, icon = 'car-burst', label = 'Status Kendaraan', onSelect = showStatus })
    else
        lib.removeRadialItem(RADIAL_ID)
    end
end)

if cache.vehicle and not W.ignoredClasses[GetVehicleClass(cache.vehicle)] then
    lib.addRadialItem({ id = RADIAL_ID, icon = 'car-burst', label = 'Status Kendaraan', onSelect = showStatus })
end
