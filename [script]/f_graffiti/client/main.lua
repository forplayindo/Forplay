-- f_graffiti client: gambar graffiti (PNG -> tekstur runtime, tanpa DUI), mode bidik, semprot, bersihkan.

local TXD = 'f_graffiti_txd'
local txd = CreateRuntimeTxd(TXD)
local DrawSpritePoly = DrawSpritePoly

local Aspect = {}      -- kunci desain -> tinggi / lebar
local Tex = {}         -- kunci desain -> nama tekstur (dimuat saat pertama terlihat)
local Records = {}     -- id -> graffiti
local Near = {}        -- graffiti terdekat yang digambar
local busy = false     -- sedang menu / bidik / semprot / bersihkan
local nuiOpen = false
local placing          -- { d, w, rot } saat mode bidik

---------------------------------------------------------------------------
-- Vektor & bentuk
---------------------------------------------------------------------------

local function v3(t) return vec3(t.x, t.y, t.z) end

local function cross(a, b)
    return vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

local function norm(v)
    local l = #v
    return l > 0.0001 and v / l or v
end

---4 sudut graffiti (kiri-atas, kanan-atas, kanan-bawah, kiri-bawah).
local function corners(p, n, r0, rot, w, aspect)
    local a = math.rad(rot)
    local r = r0 * math.cos(a) + cross(n, r0) * math.sin(a)
    local u = cross(n, r)
    local c = p + n * Config.SurfaceOffset
    local hw, hh = w * 0.5, w * aspect * 0.5
    local tl, tr = c - r * hw + u * hh, c + r * hw + u * hh
    local br, bl = c + r * hw - u * hh, c - r * hw - u * hh
    return { tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, bl.x, bl.y, bl.z }
end

local function texFor(key)
    local t = Tex[key]
    if t == nil then
        t = key:gsub('[^%w]', '_')
        CreateRuntimeTextureFromImage(txd, t, 'images/' .. key)
        Tex[key] = t
    end
    return t
end

local both, cw = Config.Winding == 'both', Config.Winding == 'cw'

local function drawQuad(q, tex, r, g, b, a)
    local x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 = table.unpack(q)
    if both or cw then
        DrawSpritePoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, TXD, tex, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
        DrawSpritePoly(x1, y1, z1, x3, y3, z3, x4, y4, z4, r, g, b, a, TXD, tex, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    end
    if both or not cw then
        DrawSpritePoly(x1, y1, z1, x3, y3, z3, x2, y2, z2, r, g, b, a, TXD, tex, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0)
        DrawSpritePoly(x1, y1, z1, x4, y4, z4, x3, y3, z3, r, g, b, a, TXD, tex, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)
    end
end

---------------------------------------------------------------------------
-- Data dari server
---------------------------------------------------------------------------

local function addRecord(rec)
    rec.pos = v3(rec.p)
    local aspect = Aspect[rec.d]
    if aspect then rec.q = corners(rec.pos, norm(v3(rec.n)), norm(v3(rec.r)), rec.rot, rec.w, aspect) end
    if rec.spraying then
        -- muncul perlahan selama disemprot
        rec.fade = { from = 0, to = 255, start = GetGameTimer() + 800, dur = Config.SprayTime - 800 }
    end
    Records[rec.id] = rec
end

local function loadAll()
    local data = lib.callback.await('f_graffiti:getAll', false)
    if not data then return end
    Aspect, Records, Near = data.designs or {}, {}, {}
    for _, rec in ipairs(data.records or {}) do addRecord(rec) end
end

RegisterNetEvent('f_graffiti:client:add', addRecord)

RegisterNetEvent('f_graffiti:client:remove', function(id)
    Records[id] = nil
end)

RegisterNetEvent('f_graffiti:client:cleaning', function(id, on)
    local rec = Records[id]
    if not rec then return end
    rec.fade = on and { from = 255, to = 30, start = GetGameTimer(), dur = Config.CleanTime } or nil
end)

RegisterNetEvent('f_graffiti:client:reload', loadAll)
AddEventHandler('QBCore:Client:OnPlayerLoaded', loadAll)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then loadAll() end
end)

local function alphaOf(rec, now)
    local f = rec.fade
    if not f then return 255 end
    local t = (now - f.start) / f.dur
    if t <= 0 then return f.from end
    if t >= 1 then return f.to end
    return math.floor(f.from + (f.to - f.from) * t)
end

---------------------------------------------------------------------------
-- Gambar: daftar terdekat diperbarui tiap 500 ms, gambar tiap frame hanya kalau ada yang dekat
---------------------------------------------------------------------------

local probes = {}  -- id -> handle shape test (cek tertutup tembok, async)

local function refreshNear(cam)
    local list = {}
    for _, rec in pairs(Records) do
        if rec.q then
            local d = #(cam - rec.pos)
            if d <= Config.RenderDistance then
                rec.dist = d
                list[#list + 1] = rec
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    for i = #list, Config.MaxDrawn + 1, -1 do list[i] = nil end

    -- tertutup tembok? hasil probe sebelumnya dibaca, probe baru dimulai
    for i = 1, #list do
        local rec = list[i]
        local h = probes[rec.id]
        if h then
            local status, hit, endCoords = GetShapeTestResult(h)
            if status ~= 1 then
                probes[rec.id] = nil
                rec.hidden = hit == 1 and #(cam - endCoords) < rec.dist - 0.4
            end
        end
        if not probes[rec.id] then
            local tgt = rec.pos + v3(rec.n) * 0.25
            probes[rec.id] = StartShapeTestLosProbe(cam.x, cam.y, cam.z, tgt.x, tgt.y, tgt.z, 1, cache.ped, 7)
        end
    end
    for id in pairs(probes) do
        if not Records[id] then probes[id] = nil end
    end
    Near = list
end

CreateThread(function()
    local nextRefresh = 0
    while true do
        local now = GetGameTimer()
        if now >= nextRefresh then
            nextRefresh = now + 500
            refreshNear(GetFinalRenderedCamCoord())
        end

        if #Near > 0 then
            for i = 1, #Near do
                local rec = Near[i]
                if not rec.hidden and Records[rec.id] == rec then
                    local a = alphaOf(rec, now)
                    if a > 0 then drawQuad(rec.q, texFor(rec.d), 255, 255, 255, a) end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------

local function closeMenu()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---Tambah nama jalan & jarak untuk daftar graffiti gang.
local function enrich(data)
    local me = GetEntityCoords(cache.ped)
    for _, g in ipairs(data.list or {}) do
        local p = v3(g.p)
        local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(p.x, p.y, p.z))
        local zone = GetLabelText(GetNameOfZone(p.x, p.y, p.z))
        g.street = (street ~= '' and street or 'Jalan tanpa nama') .. (zone ~= 'NULL' and (', ' .. zone) or '')
        g.dist = math.floor(#(me - p))
        g.p = nil
    end
    return data
end

local function openMenu()
    if busy or cache.vehicle or IsPedDeadOrDying(cache.ped, true) then return end
    local data = lib.callback.await('f_graffiti:menu', false)
    if not data or not data.ok then
        return lib.notify({ title = 'Graffiti', description = data and data.msg or 'Gagal membuka menu.', type = 'error' })
    end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = enrich(data) })
end

-- ox_inventory: item pylox -> client.export = 'f_graffiti.usePylox'
exports('usePylox', function()
    openMenu()
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb(1)
end)

RegisterNUICallback('remove', function(data, cb)
    local res = lib.callback.await('f_graffiti:remove', false, data and data.id)
    cb(res and enrich(res) or { ok = false, msg = 'Tidak ada respon server.' })
end)

local startPlacing
RegisterNUICallback('spray', function(data, cb)
    cb(1)
    closeMenu()
    if data and type(data.key) == 'string' and Aspect[data.key] then startPlacing(data.key) end
end)

---------------------------------------------------------------------------
-- Mode bidik
---------------------------------------------------------------------------

local function camDir()
    local rot = GetFinalRenderedCamRot(2)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(x))
    return vec3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

---Bidikan ke geometri map saja (tembok/lantai bangunan & MLO), bukan kendaraan, ped, atau prop.
local function aim()
    local cam, dir = GetFinalRenderedCamCoord(), camDir()
    local to = cam + dir * (Config.PlaceDistance + 6.0)
    local h = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1, cache.ped, 7)
    local _, hit, pos, normal = GetShapeTestResult(h)
    if hit ~= 1 or #normal < 0.5 then return nil end
    local n = norm(normal)
    local r0
    if math.abs(n.z) < 0.85 then
        r0 = norm(cross(-n, vec3(0.0, 0.0, 1.0)))       -- tembok: tegak lurus
    else
        r0 = norm(cross(dir, n))                         -- lantai/plafon: menghadap pemain
        if #r0 < 0.5 then return nil end
    end
    local ok = #(GetEntityCoords(cache.ped) - pos) <= Config.PlaceDistance
    return pos, n, r0, ok
end

local function hint(show, extra)
    SendNUIMessage({ action = 'hint', show = show, data = extra })
end

local DISABLE = { 24, 25, 14, 15, 16, 17, 37, 44, 38, 140, 141, 142, 257, 263, 177, 199, 200, 241, 242, 261, 262 }

local spray

startPlacing = function(key)
    if busy then return end
    busy = true
    placing = { d = key, w = Config.Size.default, rot = 0.0 }
    local tex, aspect = texFor(key), Aspect[key]
    local lastHint

    CreateThread(function()
        local result
        while placing do
            for i = 1, #DISABLE do DisableControlAction(0, DISABLE[i], true) end

            if cache.vehicle or IsPedDeadOrDying(cache.ped, true) then break end

            -- ukuran: scroll, putar: Q / E (tahan)
            if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then
                placing.w = math.min(Config.Size.max, placing.w + Config.Size.step)
            elseif IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then
                placing.w = math.max(Config.Size.min, placing.w - Config.Size.step)
            end
            if IsDisabledControlPressed(0, 44) then placing.rot = (placing.rot + 1.5) % 360 end
            if IsDisabledControlPressed(0, 38) then placing.rot = (placing.rot - 1.5) % 360 end

            local pos, n, r0, ok = aim()
            if pos then
                local q = corners(pos, n, r0, placing.rot, placing.w, aspect)
                if ok then
                    drawQuad(q, tex, 255, 255, 255, 190)
                else
                    drawQuad(q, tex, 255, 90, 90, 140)
                end
            end

            local state = ('%.1f|%d|%s'):format(placing.w, math.floor(placing.rot), pos and (ok and 'ok' or 'far') or 'none')
            if state ~= lastHint then
                lastHint = state
                hint(true, { w = placing.w, rot = math.floor(placing.rot), status = pos and (ok and 'ok' or 'far') or 'none' })
            end

            if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 191) then
                if pos and ok then
                    result = { d = key, p = pos, n = n, r = r0, rot = placing.rot, w = placing.w }
                    break
                end
            elseif IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                break
            end
            Wait(0)
        end

        placing = nil
        hint(false)
        if result then
            spray(result)
        else
            busy = false
        end
    end)
end

---------------------------------------------------------------------------
-- Menyemprot
---------------------------------------------------------------------------

local function loadPtfx(dict)
    RequestNamedPtfxAsset(dict)
    local t = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasNamedPtfxAssetLoaded(dict)
end

local SPRAY_DICT, SPRAY_CAN, SPRAY_FX = 'switch@franklin@lamar_tagging_wall', `prop_cs_spray_can`, 'scr_playerlamgraff'

---Gaya Lamar: gerakan tagging dulu, lalu semprot terus; kabut cat keluar dari ujung kaleng.
local function startSprayAnim(duration)
    local ped = cache.ped
    lib.requestAnimDict(SPRAY_DICT)
    lib.requestModel(SPRAY_CAN)

    local c = GetEntityCoords(ped)
    local s = { active = true }
    s.prop = CreateObject(SPRAY_CAN, c.x, c.y, c.z, true, true, false)
    AttachEntityToEntity(s.prop, ped, GetPedBoneIndex(ped, 28422), 0.0, -0.01, -0.012, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    SetModelAsNoLongerNeeded(SPRAY_CAN)
    TaskPlayAnim(ped, SPRAY_DICT, 'lamar_tagging_wall_loop_lamar', 8.0, -8.0, -1, 1, 0.0, false, false, false)

    CreateThread(function()
        Wait(math.floor(duration * 0.4))
        if not s.active then return end
        TaskPlayAnim(ped, SPRAY_DICT, 'lamar_tagging_exit_loop_lamar', 8.0, -2.0, -1, 1, 0.0, false, false, false)
        if loadPtfx(SPRAY_FX) and s.active then
            UseParticleFxAssetNextCall(SPRAY_FX)
            s.fx = StartParticleFxLoopedOnEntity('scr_lamgraff_paint_spray', s.prop, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
            SetParticleFxLoopedAlpha(s.fx, 0.25)
        end
    end)
    return s
end

local function stopSprayAnim(s)
    s.active = false
    if s.fx then StopParticleFxLooped(s.fx, false) end
    if DoesEntityExist(s.prop) then DeleteEntity(s.prop) end
    RemoveNamedPtfxAsset(SPRAY_FX)
    StopAnimTask(cache.ped, SPRAY_DICT, 'lamar_tagging_wall_loop_lamar', 1.0)
    StopAnimTask(cache.ped, SPRAY_DICT, 'lamar_tagging_exit_loop_lamar', 1.0)
    RemoveAnimDict(SPRAY_DICT)
end

spray = function(data)
    local function vt(v) return { x = v.x, y = v.y, z = v.z } end
    local ok, msg = lib.callback.await('f_graffiti:sprayBegin', false, {
        d = data.d, p = vt(data.p), n = vt(data.n), r = vt(data.r), rot = data.rot, w = data.w,
    })
    if not ok then
        busy = false
        return lib.notify({ title = 'Graffiti', description = msg or 'Gagal menyemprot.', type = 'error' })
    end

    -- menghadap tembok (berlawanan arah normal), bukan ke titik graffiti yang bisa lebih tinggi
    TaskAchieveHeading(cache.ped, GetHeadingFromVector_2d(-data.n.x, -data.n.y), 1000)
    Wait(1000)

    local anim = startSprayAnim(Config.SprayTime - 1000)
    local done = lib.progressBar({
        duration = Config.SprayTime - 1000,
        label = 'Menyemprot graffiti...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    stopSprayAnim(anim)

    if done then
        local okF, msgF = lib.callback.await('f_graffiti:sprayFinish', false)
        lib.notify({ title = 'Graffiti', description = msgF or (okF and 'Graffiti terpasang.' or 'Gagal.'), type = okF and 'success' or 'error' })
    else
        TriggerServerEvent('f_graffiti:server:sprayCancel')
    end
    busy = false
end

---------------------------------------------------------------------------
-- Membersihkan: [E] muncul kalau membawa alat pembersih, jalan kaki, dan membidik graffiti dekat
---------------------------------------------------------------------------

local shown = false

local function setPrompt(on)
    if on == shown then return end
    shown = on
    if on then lib.showTextUI('[E] Bersihkan Graffiti') else lib.hideTextUI() end
end

local function target()
    local me = GetEntityCoords(cache.ped)
    local best, bestD
    for i = 1, #Near do
        local rec = Near[i]
        if not rec.spraying and not rec.hidden and Records[rec.id] == rec then
            local d = #(me - rec.pos)
            if d <= Config.CleanDistance and (not bestD or d < bestD) then
                local on, sx, sy = GetScreenCoordFromWorldCoord(rec.pos.x, rec.pos.y, rec.pos.z)
                if on and math.abs(sx - 0.5) < 0.2 and math.abs(sy - 0.5) < 0.25 then
                    best, bestD = rec, d
                end
            end
        end
    end
    return best
end

local function clean(rec)
    busy = true
    setPrompt(false)
    local ok, msg = lib.callback.await('f_graffiti:cleanBegin', false, rec.id)
    if not ok then
        busy = false
        return lib.notify({ title = 'Graffiti', description = msg or 'Gagal.', type = 'error' })
    end

    TaskTurnPedToFaceCoord(cache.ped, rec.pos.x, rec.pos.y, rec.pos.z, 800)
    Wait(800)
    local done = lib.progressBar({
        duration = Config.CleanTime - 800,
        label = 'Membersihkan graffiti...',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    })
    ClearPedTasks(cache.ped)

    if done then
        local okF, msgF = lib.callback.await('f_graffiti:cleanFinish', false)
        lib.notify({ title = 'Graffiti', description = msgF or (okF and 'Graffiti dibersihkan.' or 'Gagal.'), type = okF and 'success' or 'error' })
    else
        TriggerServerEvent('f_graffiti:server:cleanCancel')
    end
    busy = false
end

CreateThread(function()
    while true do
        local sleep = 500
        local rec
        if not busy and #Near > 0 and not cache.vehicle and LocalPlayer.state.isLoggedIn
            and exports.ox_inventory:GetItemCount(Config.CleanItem) > 0 then
            rec = target()
        end
        if rec then
            sleep = 0
            setPrompt(true)
            if IsControlJustReleased(0, 38) then clean(rec) end
        else
            setPrompt(false)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if shown then lib.hideTextUI() end
    if nuiOpen then SetNuiFocus(false, false) end
end)
