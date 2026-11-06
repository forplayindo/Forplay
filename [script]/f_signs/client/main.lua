local signs = {}     -- [id] = data dari server + geometri
local visible = {}   -- { s, d } yang digambar tiap frame (diperbarui tiap 500 ms)
local draft          -- papan yang sedang diedit (preview lokal, belum tersimpan)
local editingId      -- id papan asli yang disembunyikan selama diedit
local nuiOpen, placing = false, false
local previewNight = false
local nightNow = 0.0 -- 0 = siang, 1 = malam
local winding = Config.Winding

local TXD = 'f_signs'
local UP = vec3(0.0, 0.0, 1.0)

do
    local txd = CreateRuntimeTxd(TXD)
    for style in pairs(SignFonts) do
        CreateRuntimeTextureFromImage(txd, style, ('atlas/%s.png'):format(style))
        CreateRuntimeTextureFromImage(txd, style .. '_glow', ('atlas/%s_glow.png'):format(style))
    end
end

local function r3(n)
    return math.floor(n * 1000 + 0.5) / 1000
end

local function hexToInt(hex)
    return type(hex) == 'string' and hex:match('^#%x%x%x%x%x%x$') and tonumber(hex:sub(2), 16) or nil
end

local function intToHex(n)
    return ('#%06x'):format(n or 0xFFFFFF)
end

---------------------------------------------------------------------
-- Siang / malam
---------------------------------------------------------------------

local function computeNight()
    local n = Config.Night
    local h = GetClockHours() + GetClockMinutes() / 60
    if h >= n.onFull or h < n.offStart then return 1.0 end
    if h >= n.onStart then return (h - n.onStart) / (n.onFull - n.onStart) end
    if h < n.offFull then return 1.0 - (h - n.offStart) / (n.offFull - n.offStart) end
    return 0.0
end

---------------------------------------------------------------------
-- Geometri: dihitung sekali saat data berubah, bukan tiap frame
---------------------------------------------------------------------

-- Susun huruf dalam meter (x ke kanan, y ke atas, titik 0 = tengah huruf kapital)
local function layout(font, text, height)
    local k = height / (font.baseline - font.capTop)
    local mid = (font.capTop + font.baseline) / 2
    local glyphs, pen, inkEnd = {}, 0.0, 0.0

    for i = 1, #text do
        local c = text:byte(i)
        local w = font.w[c]
        if not w then
            pen += font.space
        else
            local idx = c - 32
            local px = (idx % font.cols) * font.cellW
            local row = idx // font.cols
            glyphs[#glyphs + 1] = {
                x0 = (pen - font.pad) * k, x1 = (pen + w + font.pad) * k,
                y0 = (mid - font.cellH) * k, y1 = mid * k,
                u0 = px / font.texW, u1 = (px + w + 2 * font.pad) / font.texW,
                v0 = row * font.cellH / font.texH, v1 = (row + 1) * font.cellH / font.texH,
            }
            inkEnd = pen + w
            pen += w + font.tracking
        end
    end

    local width = inkEnd * k
    local shift = width / 2
    for i = 1, #glyphs do
        local g = glyphs[i]
        g.x0 -= shift
        g.x1 -= shift
    end
    return glyphs, width
end

-- Ubah huruf jadi daftar quad di dunia: { tl(3), tr(3), br(3), bl(3), u0, v0, u1, v1 }
local function buildQuads(s, glyphs, offset, scale)
    local base = s.pos + s.n * offset
    local R = s.right
    local out = {}
    for i = 1, #glyphs do
        local g = glyphs[i]
        local x0, x1, y0, y1 = g.x0, g.x1, g.y0, g.y1
        if scale ~= 1.0 then
            local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            local hw, hh = (x1 - x0) / 2 * scale, (y1 - y0) / 2 * scale
            x0, x1, y0, y1 = cx - hw, cx + hw, cy - hh, cy + hh
        end
        local tl = base + R * x0 + UP * y1
        local tr = base + R * x1 + UP * y1
        local br = base + R * x1 + UP * y0
        local bl = base + R * x0 + UP * y0
        out[i] = {
            tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, bl.x, bl.y, bl.z,
            g.u0, g.v0, g.u1, g.v1,
        }
    end
    return out
end

local function compute(s)
    local font = SignFonts[s.style] or SignFonts.led
    local h = math.rad(s.heading)
    s.right = vec3(math.cos(h), math.sin(h), 0.0)
    s.n = vec3(math.sin(h), -math.cos(h), 0.0) -- keluar dari tembok
    s.pos = vec3(s.x, s.y, s.z)
    s.rgb = { (s.color >> 16) & 255, (s.color >> 8) & 255, s.color & 255 }
    s.tex, s.glowTex = s.style, s.style .. '_glow'

    local glyphs, width = layout(font, s.text, s.height)
    s.width = width
    s.center = s.pos + s.n * (s.depth / 2)
    s.radius = math.sqrt((width / 2) ^ 2 + s.height ^ 2) + 0.5

    local d = math.max(s.depth, 0.005)
    if s.style == 'neon' then
        s.wall = buildQuads(s, glyphs, 0.004, 1.8)          -- cahaya lembut di tembok
        s.glow = buildQuads(s, glyphs, d * 0.9, 1.0)        -- pendar di sekitar tabung
        s.face = buildQuads(s, glyphs, d, 1.0)              -- tabung
        s.sides = nil
    else
        s.wall = buildQuads(s, glyphs, 0.004, 1.25)         -- halo di tembok belakang huruf
        s.glow = nil
        s.sides = {}
        local n = Config.LedSideLayers
        for i = 1, n do
            s.sides[i] = buildQuads(s, glyphs, d * i / (n + 1), 1.0)
        end
        s.face = buildQuads(s, glyphs, d, 1.0)
    end
end

---------------------------------------------------------------------
-- Gambar
---------------------------------------------------------------------

local DrawSpritePoly = DrawSpritePoly

local function drawQuads(list, r, g, b, a, tex)
    local both, cw = winding == 'both', winding == 'cw'
    for i = 1, #list do
        local q = list[i]
        local x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 = q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8], q[9], q[10], q[11], q[12]
        local u0, v0, u1, v1 = q[13], q[14], q[15], q[16]
        if both or cw then
            DrawSpritePoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, TXD, tex, u0, v0, 1.0, u1, v0, 1.0, u1, v1, 1.0)
            DrawSpritePoly(x1, y1, z1, x3, y3, z3, x4, y4, z4, r, g, b, a, TXD, tex, u0, v0, 1.0, u1, v1, 1.0, u0, v1, 1.0)
        end
        if both or not cw then
            DrawSpritePoly(x1, y1, z1, x3, y3, z3, x2, y2, z2, r, g, b, a, TXD, tex, u0, v0, 1.0, u1, v1, 1.0, u1, v0, 1.0)
            DrawSpritePoly(x1, y1, z1, x4, y4, z4, x3, y3, z3, r, g, b, a, TXD, tex, u0, v0, 1.0, u0, v1, 1.0, u1, v1, 1.0)
        end
    end
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function clampByte(v)
    v = math.floor(v + 0.5)
    return v < 0 and 0 or (v > 255 and 255 or v)
end

local function litOf(s)
    if s == draft and previewNight then return 1.0, 1.0 end
    if s.alwaysOn then return 1.0, 0.35 + 0.65 * nightNow end
    return nightNow, 1.0
end

local function drawSign(s, detail, oblique)
    local lit, glowMul = litOf(s)
    local amb = 1.0 - 0.55 * nightNow -- bagian yang tidak menyala ikut gelap saat malam
    local cr, cg, cb = s.rgb[1], s.rgb[2], s.rgb[3]

    if s.style == 'neon' then
        if lit > 0.02 then
            if detail then drawQuads(s.wall, cr, cg, cb, clampByte(75 * lit * glowMul), s.glowTex) end
            drawQuads(s.glow, cr, cg, cb, clampByte(200 * lit * glowMul), s.glowTex)
        end
        -- tabung kaca pucat saat mati, putih-berwarna saat menyala
        local r = mix(mix(cr, 200, 0.55) * 0.8 * amb, mix(cr, 255, 0.45), lit)
        local g = mix(mix(cg, 200, 0.55) * 0.8 * amb, mix(cg, 255, 0.45), lit)
        local b = mix(mix(cb, 200, 0.55) * 0.8 * amb, mix(cb, 255, 0.45), lit)
        drawQuads(s.face, clampByte(r), clampByte(g), clampByte(b), 255, s.tex)
    else
        if lit > 0.02 then
            drawQuads(s.wall, cr, cg, cb, clampByte(120 * lit * glowMul), s.glowTex)
        end
        if detail and oblique then
            local k = 0.42 * amb + 0.18 * lit
            local sr, sg, sb = clampByte(cr * k), clampByte(cg * k), clampByte(cb * k)
            for i = 1, #s.sides do drawQuads(s.sides[i], sr, sg, sb, 255, s.tex) end
        end
        local r = mix(cr * 0.85 * amb, mix(cr, 255, 0.25), lit)
        local g = mix(cg * 0.85 * amb, mix(cg, 255, 0.25), lit)
        local b = mix(cb * 0.85 * amb, mix(cb, 255, 0.25), lit)
        drawQuads(s.face, clampByte(r), clampByte(g), clampByte(b), 255, s.tex)
    end
end

local function drawOutline(s)
    local hw, top, bottom = s.right * (s.width / 2 + 0.05), UP * (s.height * 0.75), UP * (-s.height * 0.75)
    local p = s.pos + s.n * 0.01
    local c = { p - hw + top, p + hw + top, p + hw + bottom, p - hw + bottom }
    for i = 1, 4 do
        local a, b = c[i], c[i % 4 + 1]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 80, 200, 255, 255)
    end
end

---------------------------------------------------------------------
-- Manager: tiap 500 ms tentukan papan mana yang perlu digambar
---------------------------------------------------------------------

local function refresh()
    local cam = GetFinalRenderedCamCoord()
    local list = {}
    for id, s in pairs(signs) do
        if s.active and id ~= editingId then
            local d = #(cam - s.center)
            if d <= s.renderDistance then list[#list + 1] = { s = s, d = d } end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    for i = #list, Config.MaxVisible + 1, -1 do list[i] = nil end
    if draft then table.insert(list, 1, { s = draft, d = 0.0 }) end

    nightNow = computeNight()
    visible = list
end

CreateThread(function()
    local all = lib.callback.await('f_signs:getAll', false) or {}
    for id, s in pairs(all) do
        compute(s)
        signs[id] = s
    end
    while true do
        refresh()
        Wait(500)
    end
end)

CreateThread(function()
    local lights = Config.Lights
    while true do
        if #visible == 0 then
            Wait(500)
        else
            local cam = GetFinalRenderedCamCoord()
            local lightsLeft = lights.max
            for i = 1, #visible do
                local s = visible[i].s
                local toCam = cam - s.center
                local front = toCam.x * s.n.x + toCam.y * s.n.y
                -- di belakang tembok: tidak perlu digambar sama sekali
                if front > 0.02 then
                    local dist = #toCam
                    if lightsLeft > 0 and dist < lights.distance then
                        local lit = litOf(s)
                        if lit > 0.05 then
                            lightsLeft -= 1
                            local lp = s.pos + s.n * (0.3 + s.height * 0.4)
                            local range = math.min(12.0, math.max(3.0, s.width * 0.6 + s.height * 2.0))
                            DrawLightWithRange(lp.x, lp.y, lp.z, s.rgb[1], s.rgb[2], s.rgb[3], range, lights.intensity * lit)
                        end
                    end
                    if IsSphereVisible(s.center.x, s.center.y, s.center.z, s.radius) then
                        drawSign(s, dist < Config.DetailDistance, front / dist < 0.985)
                    end
                end
            end
            if draft then drawOutline(draft) end
            Wait(0)
        end
    end
end)

---------------------------------------------------------------------
-- Editor NUI
---------------------------------------------------------------------

local function buildList()
    local pos = GetEntityCoords(cache.ped)
    local list = {}
    for _, s in pairs(signs) do
        list[#list + 1] = {
            id = s.id, text = s.text, style = s.style, color = intToHex(s.color),
            active = s.active, alwaysOn = s.alwaysOn, dist = math.floor(#(pos - s.center)),
        }
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local function pushList()
    if nuiOpen then SendNUIMessage({ action = 'list', list = buildList() }) end
end

local function draftForNui()
    local d = draft
    if not d then return nil end
    return {
        id = d.id, text = d.text, style = d.style, color = intToHex(d.color),
        height = r3(d.height), depth = math.floor(d.depth * 100 + 0.5),
        alwaysOn = d.alwaysOn, renderDistance = d.renderDistance, active = d.active,
        previewNight = previewNight,
    }
end

local function clearDraft()
    draft, editingId = nil, nil
    refresh()
end

local function startDraft(id)
    if id then
        local s = signs[id]
        if not s then return false end
        draft = {}
        for k, v in pairs(s) do draft[k] = v end
        editingId = id
    else
        local ped = cache.ped
        local heading = GetEntityHeading(ped) -- tulisan menghadap player
        local pos = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 3.0
        draft = {
            text = 'NAMA TOKO', style = 'led', color = 0xFFFFFF,
            x = pos.x, y = pos.y, z = pos.z + 1.5, heading = heading,
            height = 0.4, depth = 0.04, alwaysOn = false,
            renderDistance = Config.DefaultRenderDistance, active = true,
        }
    end
    compute(draft)
    refresh()
    return true
end

local function num(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, v))
end

local function applyDraft(data)
    local d = draft
    if not d or type(data) ~= 'table' then return end

    if type(data.text) == 'string' then
        d.text = data.text:gsub('[^ -~]', ''):sub(1, Config.MaxTextLength)
    end
    if type(data.style) == 'string' and SignFonts[data.style] then d.style = data.style end
    d.color = hexToInt(data.color) or d.color
    d.height = num(data.height, Config.MinHeight, Config.MaxHeight, d.height)
    d.depth = num(data.depth, 0, Config.MaxDepth * 100, d.depth * 100) / 100
    d.renderDistance = num(data.renderDistance, Config.MinRenderDistance, Config.MaxRenderDistance, d.renderDistance)
    if type(data.alwaysOn) == 'boolean' then d.alwaysOn = data.alwaysOn end
    if type(data.active) == 'boolean' then d.active = data.active end
    if type(data.previewNight) == 'boolean' then previewNight = data.previewNight end

    compute(d)
end

local function openEditor()
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        list = buildList(),
        colors = Config.Colors,
        limits = {
            minHeight = Config.MinHeight, maxHeight = Config.MaxHeight, maxDepth = Config.MaxDepth * 100,
            minRender = Config.MinRenderDistance, maxRender = Config.MaxRenderDistance,
            maxText = Config.MaxTextLength,
        },
    })
end

local function closeEditor()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if draft then clearDraft() end
end

local function teleportTo(s)
    -- berdiri 4 meter di depan tulisan, menghadap tulisan
    local p = s.pos + s.n * 4.0
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.0, false)
    local z = (found and p.z - gz < 15.0) and gz or p.z
    SetEntityCoords(cache.ped, p.x, p.y, z, false, false, false, false)
    SetEntityHeading(cache.ped, s.heading)
end

---------------------------------------------------------------------
-- Mode penempatan: arahkan kamera ke tembok
---------------------------------------------------------------------

local function camRaycast(dist)
    local camCoords = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cx = math.abs(math.cos(rx))
    local dest = camCoords + vec3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx)) * dist
    -- 1|16 = world + object (tanpa ped)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z,
        dest.x, dest.y, dest.z, 17, cache.ped, 4)
    local _, hit, endCoords, normal = GetShapeTestResult(handle)
    return hit == true or hit == 1, endCoords, normal
end

local disabledControls = { 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }

local function startPlacement()
    local d = draft
    if not d or placing then return end
    placing = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    local backup = { x = d.x, y = d.y, z = d.z, heading = d.heading, height = d.height }
    local confirmed = false
    lib.showTextUI('[Mouse] Arahkan ke tembok  \n[Scroll] Besar/Kecil (SHIFT = halus)  \n[E] Selesai  \n[Backspace] Batal')

    while placing and draft == d do
        for i = 1, #disabledControls do DisableControlAction(0, disabledControls[i], true) end

        local step = IsControlPressed(0, 21) and Config.ScaleStepFine or Config.ScaleStep
        if IsDisabledControlJustPressed(0, 15) then d.height = math.min(Config.MaxHeight, d.height * (1 + step)) end
        if IsDisabledControlJustPressed(0, 14) then d.height = math.max(Config.MinHeight, d.height * (1 - step)) end

        local hit, coords, normal = camRaycast(Config.PlaceDistance)
        -- hanya permukaan tegak (tembok), bukan lantai/atap
        if hit and math.abs(normal.z) < 0.7 then
            local n = vec3(normal.x, normal.y, 0.0)
            n = n / #n
            d.heading = math.deg(math.atan(n.x, -n.y)) % 360
            d.x, d.y, d.z = coords.x + n.x * 0.003, coords.y + n.y * 0.003, coords.z
        end

        compute(d)

        if IsDisabledControlJustPressed(0, 38) or IsControlJustPressed(0, 38) then
            confirmed = true
            placing = false
        elseif IsControlJustPressed(0, 177) then
            placing = false
        end

        Wait(0)
    end

    placing = false
    lib.hideTextUI()

    if draft ~= d then return end
    if not confirmed then
        for k, v in pairs(backup) do d[k] = v end
        compute(d)
    end
    refresh()

    if nuiOpen then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'show', draft = draftForNui() })
    end
end

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------

local function notifyResult(ok, err, okText)
    lib.notify(ok and { type = 'success', description = okText } or { type = 'error', description = err or 'Gagal' })
end

RegisterNUICallback('close', function(_, cb)
    closeEditor()
    cb(1)
end)

RegisterNUICallback('new', function(_, cb)
    startDraft(nil)
    cb(draftForNui())
end)

RegisterNUICallback('edit', function(data, cb)
    cb(startDraft(tonumber(data.id)) and draftForNui() or false)
end)

RegisterNUICallback('update', function(data, cb)
    applyDraft(data)
    cb(draftForNui())
end)

RegisterNUICallback('cancel', function(_, cb)
    clearDraft()
    cb(buildList())
end)

RegisterNUICallback('place', function(_, cb)
    cb(1)
    CreateThread(startPlacement)
end)

RegisterNUICallback('save', function(_, cb)
    local d = draft
    if not d then return cb({ ok = false, err = 'Tidak ada data' }) end
    local ok, res = lib.callback.await('f_signs:save', false, {
        id = d.id, text = d.text, style = d.style, color = d.color,
        x = d.x, y = d.y, z = d.z, heading = d.heading,
        height = d.height, depth = d.depth, alwaysOn = d.alwaysOn,
        renderDistance = d.renderDistance, active = d.active,
    })
    if ok then clearDraft() end
    notifyResult(ok, res, 'Papan nama tersimpan')
    cb({ ok = ok, err = not ok and res or nil, list = buildList() })
end)

RegisterNUICallback('toggle', function(data, cb)
    local ok, res = lib.callback.await('f_signs:toggle', false, tonumber(data.id))
    if not ok then notifyResult(false, res) end
    cb(1)
end)

RegisterNUICallback('delete', function(data, cb)
    local ok, res = lib.callback.await('f_signs:delete', false, tonumber(data.id))
    notifyResult(ok, res, 'Papan nama dihapus')
    cb(1)
end)

RegisterNUICallback('teleport', function(data, cb)
    cb(1)
    local s = signs[tonumber(data.id)]
    if not s then return end
    closeEditor()
    teleportTo(s)
end)

---------------------------------------------------------------------
-- Sinkronisasi dari server
---------------------------------------------------------------------

RegisterNetEvent('f_signs:set', function(s)
    if GetInvokingResource() or type(s) ~= 'table' then return end
    compute(s)
    signs[s.id] = s
    refresh()
    pushList()
end)

RegisterNetEvent('f_signs:remove', function(id)
    if GetInvokingResource() then return end
    signs[id] = nil
    if editingId == id then clearDraft() end
    refresh()
    pushList()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if nuiOpen then SetNuiFocus(false, false) end
    if placing then lib.hideTextUI() end
end)

---------------------------------------------------------------------
-- Command
---------------------------------------------------------------------

RegisterCommand(Config.Command, function()
    if nuiOpen or placing then return end
    if not lib.callback.await('f_signs:canUse', false) then
        return lib.notify({ type = 'error', description = 'Tidak punya izin' })
    end
    openEditor()
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Buka editor papan nama toko (admin)')

-- Tes sisi poligon (hanya mengubah tampilan di layar sendiri)
local WINDINGS = { both = 'cw', cw = 'ccw', ccw = 'both' }
RegisterCommand(Config.Command .. '_sisi', function()
    winding = WINDINGS[winding] or 'both'
    lib.notify({
        type = 'info',
        description = ('Mode sisi: %s. Kalau tulisan tetap terlihat di mode cw/ccw, isi Config.Winding = \'%s\''):format(winding, winding),
    })
end, false)
