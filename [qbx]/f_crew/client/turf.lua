-- f_crew client: Gang Wars. Menu /peranggang (+ radial), scoreboard + hitung mundur di layar, dan
-- editor wilayah admin (titik dari posisi pemain + garis wilayah di dunia game).
--
-- Ringan: tidak ada loop kecuali (1) cek pause menu 2x per detik selama scoreboard tampil dan
-- (2) gambar garis wilayah tiap frame hanya saat admin sedang mode gambar. Semua data dari server;
-- hitung mundur dihitung NUI dari sisa waktu yang dikirim server.

local HUD_KEY = 'F7' -- default tombol sembunyikan / tampilkan scoreboard (bisa diganti di Settings FiveM)

local menuOpen = false
local hudActive = false
local hudHidden = false
---@type { points: number[][], z: table<integer, number>, flag: number[]?, flagMode: boolean }?
local drawing

local function call(name, payload)
    return lib.callback.await('f_crew:turf:call', false, name, payload) or { ok = false, err = 'Server tidak merespons.' }
end

local function notify(text, kind)
    lib.notify({ title = 'Gang Wars', description = text, type = kind or 'inform' })
end

local function myPos()
    local p = GetEntityCoords(cache.ped)
    return { math.floor(p.x * 100 + 0.5) / 100, math.floor(p.y * 100 + 0.5) / 100 }
end

-- Menu -----------------------------------------------------------------------------------------

local function openMenu()
    if menuOpen or drawing then return end
    local res = call('data', true)
    if not res.ok then return notify(res.err, 'error') end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = res.data, pos = myPos() })
end

RegisterCommand('peranggang', openMenu, false)
TriggerEvent('chat:addSuggestion', '/peranggang', 'Buka menu Gang Wars (perebutan wilayah)')

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
end

RegisterNUICallback('close', function(_, cb)
    cb(true)
    closeMenu()
end)

---Satu pintu untuk semua aksi menu: { name = string, payload = any }.
---Bukan 'call': nama itu sudah dipakai app Crew di HP (client/main.lua) di resource yang sama.
RegisterNUICallback('turfCall', function(data, cb)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return cb({ ok = false, err = 'Data tidak valid.' }) end
    local res = call(data.name, data.payload)
    if res.ok and data.name == 'data' and type(res.data) == 'table' then res.data.pos = myPos() end
    if not res.ok then print(('[f_crew] Gang Wars %s gagal: %s'):format(data.name, tostring(res.err))) end
    cb(res)
end)

-- Editor admin: titik dari posisi pemain -------------------------------------------------------

local function groundZ(x, y, fallback)
    local found, z = GetGroundZFor_3dCoord(x, y, fallback + 80.0, false)
    return found and z or fallback
end

local function drawOutline()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local pts = drawing.points
    local n = #pts
    for i = 1, n do
        local a = pts[i]
        if not drawing.z[i] then drawing.z[i] = groundZ(a[1], a[2], pos.z) end
    end
    for i = 1, n do
        local a, b = pts[i], pts[i % n + 1]
        local za, zb = drawing.z[i], drawing.z[i % n + 1]
        local near = #(vec2(a[1], a[2]) - pos.xy) < 400.0 or #(vec2(b[1], b[2]) - pos.xy) < 400.0
        if near then
            -- tiang di tiap titik + dinding tipis transparan antar titik
            DrawLine(a[1], a[2], za - 1.0, a[1], a[2], za + 25.0, 91, 157, 255, 255)
            if n >= 2 and (i < n or n >= 3) then
                DrawLine(a[1], a[2], za + 0.3, b[1], b[2], zb + 0.3, 91, 157, 255, 255)
                DrawPoly(a[1], a[2], za, b[1], b[2], zb, b[1], b[2], zb + 12.0, 91, 157, 255, 60)
                DrawPoly(b[1], b[2], zb + 12.0, a[1], a[2], za + 12.0, a[1], a[2], za, 91, 157, 255, 60)
                DrawPoly(b[1], b[2], zb + 12.0, b[1], b[2], zb, a[1], a[2], za, 91, 157, 255, 60)
                DrawPoly(a[1], a[2], za, a[1], a[2], za + 12.0, b[1], b[2], zb + 12.0, 91, 157, 255, 60)
            end
        end
    end
    -- titik bendera (mode Rebut Bendera): tiang kuning
    local f = drawing.flag
    if f then
        if not f[3] then f[3] = groundZ(f[1], f[2], pos.z) end
        DrawLine(f[1], f[2], f[3], f[1], f[2], f[3] + 6.0, 255, 214, 10, 255)
        if f[4] then -- arah kain bendera (sumbu X model setelah diputar heading)
            local r = math.rad(f[4])
            DrawLine(f[1], f[2], f[3] + 5.5, f[1] + math.cos(r) * 1.5, f[2] + math.sin(r) * 1.5, f[3] + 5.5, 255, 214, 10, 255)
        end
        DrawMarker(4, f[1], f[2], f[3] + 6.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.2, 255, 214, 10, 220, false, true, 2, false, nil, nil, false) ---@diagnostic disable-line: param-type-mismatch
    end
end

local function stopDrawing(reopen)
    drawing = nil
    SendNUIMessage({ action = 'drawHint', show = false })
    if reopen then
        menuOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'drawReturn', pos = myPos() })
    end
end

---NUI (admin) keluar sebentar ke game untuk menaruh titik dari posisi sendiri.
RegisterNUICallback('draw', function(data, cb)
    cb(true)
    if type(data) ~= 'table' or type(data.points) ~= 'table' then return end
    local pts = {}
    for i = 1, math.min(#data.points, 80) do
        local p = data.points[i]
        if type(p) == 'table' and tonumber(p[1]) and tonumber(p[2]) then pts[#pts + 1] = { tonumber(p[1]), tonumber(p[2]) } end
    end
    local flag = type(data.flag) == 'table' and tonumber(data.flag[1]) and tonumber(data.flag[2])
        and { tonumber(data.flag[1]), tonumber(data.flag[2]), tonumber(data.flag[3]), tonumber(data.flag[4]) } or nil
    drawing = { points = pts, z = {}, flag = flag, flagMode = data.flagMode == true }
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'drawHint', show = true, flagMode = drawing.flagMode })

    CreateThread(function()
        while drawing do
            drawOutline()
            DisableControlAction(0, 38, true) -- E
            DisableControlAction(0, 47, true) -- G
            DisableControlAction(0, 23, true) -- F
            if drawing.flagMode and IsDisabledControlJustPressed(0, 23) then
                -- titik tugu dari kaki pemain (z ikut disimpan supaya pas di tanah / atap, arah = hadap pemain)
                local p = GetEntityCoords(cache.ped)
                local pt = { math.floor(p.x * 100 + 0.5) / 100, math.floor(p.y * 100 + 0.5) / 100, math.floor((p.z - 1.0) * 100 + 0.5) / 100,
                    math.floor(GetEntityHeading(cache.ped) * 100 + 0.5) / 100 }
                drawing.flag = pt
                SendNUIMessage({ action = 'drawFlag', point = pt })
                notify('Titik bendera ditandai.', 'success')
            elseif IsDisabledControlJustPressed(0, 38) then
                if #drawing.points >= 80 then
                    notify('Maksimal 80 titik.', 'error')
                else
                    local p = myPos()
                    drawing.points[#drawing.points + 1] = p
                    SendNUIMessage({ action = 'drawPoint', point = p, count = #drawing.points })
                end
            elseif IsDisabledControlJustPressed(0, 47) then
                stopDrawing(true)
            end
            Wait(0)
        end
    end)
end)

-- Scoreboard + hitung mundur -------------------------------------------------------------------

local function watchPause()
    CreateThread(function()
        local paused = false
        while hudActive do
            local now = IsPauseMenuActive()
            if now ~= paused then
                paused = now
                SendNUIMessage({ action = 'hudPause', paused = now })
            end
            Wait(500)
        end
    end)
end

RegisterNetEvent('f_crew:turf:hud', function(data)
    if data and not hudActive then
        hudActive = true
        watchPause()
    elseif not data then
        hudActive = false
    end
    SendNUIMessage({ action = 'hud', data = data, hidden = hudHidden, key = HUD_KEY })
end)

RegisterNetEvent('f_crew:turf:hudDone', function(text)
    hudActive = false
    SendNUIMessage({ action = 'hudDone', text = text })
end)

RegisterCommand('peranggang_hud', function()
    hudHidden = not hudHidden
    SendNUIMessage({ action = 'hudToggle', hidden = hudHidden })
end, false)
RegisterKeyMapping('peranggang_hud', 'Gang Wars: sembunyikan / tampilkan scoreboard', 'keyboard', HUD_KEY)

-- Radial menu (hanya anggota gang bertag 'gang') ------------------------------------------------

local function syncRadial()
    if LocalPlayer.state.crewTag == 'gang' then
        lib.addRadialItem({ id = 'f_crew_gangwars', label = 'Gang Wars', icon = 'flag', onSelect = openMenu })
    else
        lib.removeRadialItem('f_crew_gangwars')
    end
end

-- f_radialmenu menjalankan lib.clearRadialItems() saat player loaded / mati / revive, jadi item
-- didaftarkan ulang sesudahnya (sama seperti f_petshop / f_hygiene)
local function reSync() SetTimeout(1500, syncRadial) end

AddStateBagChangeHandler('crewTag', ('player:%s'):format(cache.serverId), function() SetTimeout(0, syncRadial) end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', reSync)
RegisterNetEvent('radialmenu:client:deadradial', function(isDead)
    if not isDead then reSync() end
end)
syncRadial()

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    if menuOpen then SetNuiFocus(false, false) end
end)
