-- Editor garasi (/garasi): panel NUI + mode menandai area (vec2) & titik keluar kendaraan (vec4).
-- Loop gambar hanya berjalan selama menandai / melihat area; saat bermain biasa tidak ada beban.
local EC = require 'config.editor'
local K = EC.keys
local nuiOpen = false
local drawing = false -- mode tandai / lihat sedang aktif

local function myPos()
    local c = GetEntityCoords(cache.ped)
    return { x = c.x, y = c.y, z = c.z }
end

local function openNui(payload)
    nuiOpen = true
    payload.pos = myPos()
    SendNUIMessage(payload)
    SetNuiFocus(true, true)
end

local function hideNui()
    nuiOpen = false
    SetNuiFocus(false, false)
end

---------------------------------------------------------------------------
-- gambar
---------------------------------------------------------------------------
local AREA = { 91, 157, 255 }  -- biru
local SPAWN = { 231, 195, 106 } -- emas

local function line(a, b, c, alpha)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, c[1], c[2], c[3], alpha or 255)
end

-- dinding transparan setinggi zona (dua sisi supaya terlihat dari dalam & luar)
local function wall(a, b, bottom, top)
    local r, g, bl, al = AREA[1], AREA[2], AREA[3], 45
    DrawPoly(a.x, a.y, bottom, b.x, b.y, bottom, b.x, b.y, top, r, g, bl, al)
    DrawPoly(a.x, a.y, bottom, b.x, b.y, top, a.x, a.y, top, r, g, bl, al)
    DrawPoly(b.x, b.y, top, b.x, b.y, bottom, a.x, a.y, bottom, r, g, bl, al)
    DrawPoly(a.x, a.y, top, b.x, b.y, top, a.x, a.y, bottom, r, g, bl, al)
end

local function minZ(points)
    local z
    for i = 1, #points do z = math.min(z or points[i].z, points[i].z) end
    return z
end

---@param points { x: number, y: number, z: number }[]
---@param height number
---@param cursor? vector3 titik bidikan (preview garis ke titik berikutnya)
local function drawArea(points, height, cursor)
    local n = #points
    if n == 0 then
        if cursor then DrawMarker(28, cursor.x, cursor.y, cursor.z, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, AREA[1], AREA[2], AREA[3], 200, false, false, 2, false, nil, nil, false) end
        return
    end
    local ground = minZ(points)
    local bottom, top = ground, ground + height - 2.0

    for i = 1, n do
        local a = points[i]
        local b = points[i % n + 1]
        local pa, pb = vec3(a.x, a.y, a.z + 0.05), vec3(b.x, b.y, b.z + 0.05)
        if i < n or n >= 3 then
            line(pa, pb, AREA, i == n and 120 or 255) -- sisi penutup lebih tipis
            if n >= 3 then wall(a, b, bottom, top) end
        end
        DrawMarker(28, a.x, a.y, a.z + 0.05, 0, 0, 0, 0, 0, 0, 0.18, 0.18, 0.18, 255, 255, 255, 220, false, false, 2, false, nil, nil, false)
    end

    if cursor then
        local last, first = points[n], points[1]
        line(vec3(last.x, last.y, last.z + 0.05), cursor, AREA, 180)
        if n >= 2 then line(cursor, vec3(first.x, first.y, first.z + 0.05), AREA, 90) end
        DrawMarker(28, cursor.x, cursor.y, cursor.z, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, AREA[1], AREA[2], AREA[3], 200, false, false, 2, false, nil, nil, false)
    end
end

-- kotak seukuran mobil + garis arah hadap
local function drawSpawn(s, index)
    local rad = math.rad(s.w)
    local fx, fy = -math.sin(rad), math.cos(rad) -- depan
    local rx, ry = fy, -fx                        -- kanan
    local hw, hl = 1.1, 2.4
    local z = s.z - 0.4
    local function corner(f, r) return vec3(s.x + fx * f + rx * r, s.y + fy * f + ry * r, z) end
    local c1, c2, c3, c4 = corner(hl, hw), corner(hl, -hw), corner(-hl, -hw), corner(-hl, hw)
    line(c1, c2, SPAWN); line(c2, c3, SPAWN); line(c3, c4, SPAWN); line(c4, c1, SPAWN)
    line(vec3(s.x, s.y, z), corner(hl + 1.5, 0), SPAWN)
    line(corner(hl + 1.5, 0), corner(hl + 0.8, 0.5), SPAWN)
    line(corner(hl + 1.5, 0), corner(hl + 0.8, -0.5), SPAWN)
    if index then
        SetDrawOrigin(s.x, s.y, s.z + 0.6, 0)
        SetTextScale(0.0, 0.35); SetTextFont(4); SetTextCentre(true); SetTextOutline()
        SetTextColour(SPAWN[1], SPAWN[2], SPAWN[3], 255)
        BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(tostring(index)); EndTextCommandDisplayText(0.0, 0.0)
        ClearDrawOrigin()
    end
end

local function disableCombat()
    DisablePlayerFiring(cache.playerId, true)
    DisableControlAction(0, 24, true)  -- attack
    DisableControlAction(0, 25, true)  -- aim
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
    DisableControlAction(0, K.cancel, true) -- jangan buka menu pause
    DisableControlAction(0, 199, true)
    DisableControlAction(0, K.spawn, true)
    DisableControlAction(0, 86, true)  -- klakson (E di kendaraan)
end

local function pressed(key)
    return IsDisabledControlJustPressed(0, key) or IsControlJustPressed(0, key)
end

---------------------------------------------------------------------------
-- mode tandai
---------------------------------------------------------------------------
---@param mode 'area'|'spawn'
---@param draft { points: table[], spawns: table[], height: number, z?: number }
---@return table? hasil (nil = batal)
local function mark(mode, draft)
    drawing = true
    local points, spawns = {}, {}
    for i, p in ipairs(draft.points or {}) do points[i] = { x = p.x, y = p.y, z = p.z or (draft.z or 0.0) } end
    for i, s in ipairs(draft.spawns or {}) do spawns[i] = { x = s.x, y = s.y, z = s.z, w = s.w } end
    local height = tonumber(draft.height) or EC.defaultHeight

    local function help()
        if mode == 'area' then
            lib.showTextUI(('**Tandai Area** · %d titik  \n[E] titik di kaki · [Klik Kiri] titik dibidik  \n[Backspace] hapus terakhir · [Enter] selesai · [Esc] batal'):format(#points))
        else
            lib.showTextUI(('**Titik Keluar Kendaraan** · %d titik  \n[G] tambah (posisi & arah kendaraan/badan)  \n[Backspace] hapus terakhir · [Enter] selesai · [Esc] batal'):format(#spawns))
        end
    end
    help()

    -- raycast menunggu 1 frame per panggilan, jadi dijalankan di thread sendiri supaya gambar tidak berkedip
    local cursor
    if mode == 'area' then
        CreateThread(function()
            while drawing do
                local hit, _, endCoords = lib.raycast.fromCamera(1 | 16, 4, 80.0)
                cursor = (hit and hit ~= 0) and endCoords or nil
            end
        end)
    end

    local result
    while true do
        disableCombat()

        if mode == 'area' then
            if pressed(K.pointHere) and #points < EC.maxPoints then
                local c = GetEntityCoords(cache.ped)
                points[#points + 1] = { x = c.x, y = c.y, z = c.z - 1.0 }
                help()
            elseif pressed(K.pointAim) and cursor and #points < EC.maxPoints then
                points[#points + 1] = { x = cursor.x, y = cursor.y, z = cursor.z }
                help()
            end
        else
            if pressed(K.spawn) and #spawns < EC.maxSpawns then
                local ent = cache.vehicle or cache.ped
                local c = GetEntityCoords(ent)
                spawns[#spawns + 1] = { x = c.x, y = c.y, z = cache.vehicle and c.z or c.z - 0.5, w = GetEntityHeading(ent) }
                help()
            end
        end

        if pressed(K.undo) then
            if mode == 'area' then points[#points] = nil else spawns[#spawns] = nil end
            help()
        elseif pressed(K.finish) then
            if mode == 'area' and #points < 3 then
                lib.notify({ type = 'error', description = 'Area butuh minimal 3 titik.' })
            elseif mode == 'spawn' and #spawns < 1 then
                lib.notify({ type = 'error', description = 'Tambah minimal 1 titik keluar.' })
            else
                result = { points = points, spawns = spawns, z = minZ(points) }
                break
            end
        elseif pressed(K.cancel) then
            break
        end

        drawArea(points, height, cursor)
        for i = 1, #spawns do drawSpawn(spawns[i], i) end
        Wait(0)
    end

    lib.hideTextUI()
    drawing = false
    return result
end

-- lihat area garasi yang sudah ada (maks. 60 detik)
local function preview(g)
    drawing = true
    local points = {}
    for i, p in ipairs(g.points) do points[i] = { x = p.x, y = p.y, z = g.z } end
    lib.showTextUI(('**%s**  \nBiru = area · Kuning = titik keluar  \n[Backspace] selesai'):format(g.label))
    local untilAt = GetGameTimer() + 60000
    while GetGameTimer() < untilAt do
        DisableControlAction(0, K.cancel, true)
        if pressed(K.undo) or pressed(K.cancel) then break end
        drawArea(points, g.height or EC.defaultHeight)
        for i = 1, #g.spawns do drawSpawn(g.spawns[i], i) end
        Wait(0)
    end
    lib.hideTextUI()
    drawing = false
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
RegisterNetEvent('f_garages:client:openEditor', function()
    if nuiOpen or drawing then return end
    local res = lib.callback.await('f_garages:editor:open', false)
    if not res or not res.ok then
        return lib.notify({ type = 'error', description = res and res.msg or 'Gagal membuka editor garasi.' })
    end
    openNui({ action = 'open', data = res })
end)

RegisterNUICallback('close', function(_, cb)
    hideNui()
    cb(1)
end)

local function relay(name, ...)
    local res = lib.callback.await('f_garages:editor:' .. name, false, ...) or { ok = false, msg = 'Tidak ada respon server.' }
    res.pos = myPos()
    return res
end

RegisterNUICallback('create', function(d, cb) cb(relay('create', d)) end)
RegisterNUICallback('update', function(d, cb) cb(relay('update', d.id, d)) end)
RegisterNUICallback('delete', function(d, cb) cb(relay('delete', d.id)) end)

-- panel disembunyikan, admin menandai di dunia, lalu panel dibuka lagi dengan hasilnya
RegisterNUICallback('mark', function(d, cb)
    cb(1)
    if drawing then return end
    hideNui()
    CreateThread(function()
        local result = mark(d.mode == 'spawn' and 'spawn' or 'area', d.draft or {})
        openNui({ action = 'marked', mode = d.mode, result = result })
    end)
end)

RegisterNUICallback('preview', function(d, cb)
    cb(1)
    if drawing or type(d.garage) ~= 'table' then return end
    hideNui()
    CreateThread(function()
        preview(d.garage)
        openNui({ action = 'show' })
    end)
end)

RegisterNUICallback('teleport', function(d, cb)
    cb(1)
    local g = d and d.garage
    if type(g) ~= 'table' or type(g.points) ~= 'table' or #g.points == 0 then return end
    local x, y = 0.0, 0.0
    for _, p in ipairs(g.points) do x, y = x + p.x, y + p.y end
    hideNui()
    SendNUIMessage({ action = 'close' })
    SetEntityCoords(cache.ped, x / #g.points, y / #g.points, (tonumber(g.z) or 0.0) + 1.0, false, false, false, false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if nuiOpen then SetNuiFocus(false, false) end
    if drawing then lib.hideTextUI() end
end)
