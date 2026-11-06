-- Editor admin /tolatur: daftar gerbang & lajur (NUI) + mode tandai di dunia.
-- Tambah lajur: [E] di mobil samping jendela bilik (titik tap + arah lajur), lalu [G] posisi tiang palang.
local config = require 'config.shared'
local barrier = require 'client.barrier'
local route = require 'shared.route'

local editor = {}
local ui
local lanes, lokets = {}, {}
local open = false
local marking = false

local function dirLabel(l)
    return route.dir(l.gate, route.forward(l.tap.w)) == 'N' and 'Ke Paleto' or 'Ke Kota'
end

local function payload()
    local list = {}
    for _, id in ipairs(config.gateOrder) do
        local g = config.gates[id]
        local rows = {}
        for _, l in ipairs(lanes) do
            if l.gate == id then
                rows[#rows + 1] = { id = l.id, dir = dirLabel(l), x = l.tap.x, y = l.tap.y }
            end
        end
        local loket = false
        for _, k in ipairs(lokets) do
            if k.gate == id then loket = true break end
        end
        list[#list + 1] = { id = id, label = g.label, lanes = rows, loket = loket }
    end
    return { gates = list }
end

local function push()
    SendNUIMessage({ action = 'editor', data = payload() })
end

local function openUi()
    open = true
    ui.setMenuOpen(true)
    SetNuiFocus(true, true)
    push()
end

local function closeUi()
    open = false
    ui.setMenuOpen(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function editor.init(helpers) ui = helpers end

function editor.setData(list, lok)
    lanes, lokets = list, lok
    if open then push() end
end

function editor.closed() open = false end

RegisterNetEvent('f_toll:client:editor', function(p)
    if GetInvokingResource() then return end
    lanes, lokets = p.lanes or {}, p.lokets or {}
    if marking then return end
    openUi()
end)

---------------------------------------------------------------------------
-- Mode tandai
---------------------------------------------------------------------------

local function ground(p)
    local ok, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.0, false)
    return ok and z or p.z - 1.0
end

local function arrow(from, h, len, r, g, b)
    local rad = math.rad(h)
    local to = from + vec3(-math.sin(rad), math.cos(rad), 0.0) * len
    DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, r, g, b, 255)
    DrawMarker(2, to.x, to.y, to.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, r, g, b, 200, false, true, 2, false, nil, nil, false)
end

local function mark(gateId)
    marking = true
    CreateThread(function()
        local tap
        while marking and not tap do
            local veh = cache.vehicle
            if veh then
                ui.showText('[E] Simpan titik tap (mobil di samping jendela bilik, arah lajur)  \n[X] Batal')
                local c = GetEntityCoords(veh)
                arrow(c, GetEntityHeading(veh), 6.0, 80, 230, 255)
                DisableControlAction(0, 86, true)
                if IsDisabledControlJustReleased(0, 86) or IsControlJustReleased(0, 38) then
                    tap = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(veh) }
                end
            else
                ui.showText('Naik mobil & berhenti di samping jendela bilik  \n[X] Batal')
            end
            if IsControlJustReleased(0, 73) then marking = false end
            Wait(0)
        end

        local ghost
        local h = tap and (tap.w + 90.0) % 360.0 or 0.0
        local tapPos = tap and vec3(tap.x, tap.y, tap.z)
        while marking do
            if cache.vehicle then
                ui.showText('Turun dari mobil, berdiri di tempat tiang palang  \n[X] Batal')
                if ghost then barrier.delete(ghost) ghost = nil end
            else
                ui.showText('[←/→] Putar palang (Shift = cepat)  \n[G] Simpan  [X] Batal')
                local p = GetEntityCoords(cache.ped)
                local f = GetEntityForwardVector(cache.ped)
                local at = vec3(p.x + f.x * 1.2, p.y + f.y * 1.2, 0.0)
                at = vec3(at.x, at.y, ground(vec3(at.x, at.y, p.z)))

                DisableControlAction(0, 174, true)
                DisableControlAction(0, 175, true)
                local step = IsControlPressed(0, 21) and 2.0 or 0.5
                if IsDisabledControlPressed(0, 174) then h = (h + step) % 360.0 end
                if IsDisabledControlPressed(0, 175) then h = (h - step) % 360.0 end

                if not ghost then ghost = barrier.create(at, h, true) else barrier.move(ghost, at, h) end
                arrow(tapPos, tap.w, 6.0, 80, 230, 255)
                local d = barrier.armDir(h) * barrier.info().length
                DrawLine(at.x, at.y, at.z + 0.2, at.x + d.x, at.y + d.y, at.z + 0.2, 255, 200, 60, 255)

                if IsControlJustReleased(0, 47) then
                    local res = lib.callback.await('f_toll:server:addLane', false, gateId, tap, { x = at.x, y = at.y, z = at.z, w = h })
                    if res and res.ok then
                        lib.notify({ description = ('Lajur disimpan di %s.'):format(res.gate), type = 'success' })
                        marking = false
                    else
                        lib.notify({ description = res and res.msg or 'Gagal menyimpan lajur.', type = 'error' })
                    end
                end
            end
            if IsControlJustReleased(0, 73) then marking = false end
            Wait(0)
        end

        if ghost then barrier.delete(ghost) end
        ui.hideText()
        openUi()
    end)
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------

local function findLane(id)
    for _, l in ipairs(lanes) do
        if l.id == id then return l end
    end
end

local function result(res, cb)
    if res and res.ok then
        if res.data then lanes, lokets = res.data.lanes, res.data.lokets end
        cb({ ok = true, data = payload() })
    else
        cb({ ok = false, msg = res and res.msg or 'Gagal.' })
    end
end

RegisterNUICallback('editor:add', function(body, cb)
    cb(1)
    if not config.gates[body.gate] then return end
    closeUi()
    mark(body.gate)
end)

RegisterNUICallback('editor:delete', function(body, cb)
    result(lib.callback.await('f_toll:server:deleteLane', false, body.id), cb)
end)

RegisterNUICallback('editor:test', function(body, cb)
    result(lib.callback.await('f_toll:server:testLane', false, body.id), cb)
end)

RegisterNUICallback('editor:tp', function(body, cb)
    cb(1)
    local l = body.id and findLane(body.id)
    local c = l and vec3(l.tap.x, l.tap.y, l.tap.z) or (config.gates[body.gate] and config.gates[body.gate].coords)
    if not c then return end
    SetEntityCoords(cache.vehicle or cache.ped, c.x, c.y, c.z + 0.5, false, false, false, false)
    if l then SetEntityHeading(cache.vehicle or cache.ped, l.tap.w) end
end)

RegisterNUICallback('editor:loket', function(body, cb)
    if cache.vehicle then return cb({ ok = false, msg = 'Turun dari kendaraan dulu, berdiri di tempat NPC loket.' }) end
    local p = GetEntityCoords(cache.ped)
    result(lib.callback.await('f_toll:server:setLoket', false, body.gate, { x = p.x, y = p.y, z = p.z, w = GetEntityHeading(cache.ped) }), cb)
end)

RegisterNUICallback('editor:loketDelete', function(body, cb)
    result(lib.callback.await('f_toll:server:deleteLoket', false, body.gate), cb)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then marking = false end
end)

return editor
