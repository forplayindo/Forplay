local billboards = {} -- [id] = data dari server
local spawned = {}    -- [key] = entity prop (key = id billboard, atau 'draft')
local loading = {}    -- [key] = token saat model sedang di-load
local slots = {}      -- [i] = { dui, txd, tex, key, url } pool browser DUI (maks Config.MaxActive)
local visible = {}    -- { bb, slot } yang digambar tiap frame
local draft           -- billboard yang sedang diedit (preview lokal, belum tersimpan)
local editingId       -- id billboard asli yang disembunyikan selama diedit
local nuiOpen, placing = false, false

local DUI_PAGE = ('https://cfx-nui-%s/html/dui.html'):format(GetCurrentResourceName())

local presetByModel = {}
for i = 1, #BillboardPresets do
    presetByModel[BillboardPresets[i].model] = BillboardPresets[i]
end

local function r3(n)
    return math.floor(n * 1000 + 0.5) / 1000
end

---------------------------------------------------------------------
-- Geometri layar
---------------------------------------------------------------------

-- Arah kanan/depan/atas dari rotasi (pitch rx, heading rz). Sama dengan matrix entity GTA.
local function getAxes(rx, rz)
    local h, p = math.rad(rz), math.rad(rx)
    local sh, ch, sp, cp = math.sin(h), math.cos(h), math.sin(p), math.cos(p)
    return vec3(ch, sh, 0.0), vec3(-sh * cp, ch * cp, sp), vec3(sh * sp, -ch * sp, cp)
end

-- Hitung sudut-sudut layar sekali saat data berubah (bukan tiap frame).
-- Prop dengan preset `sides` > 1 punya beberapa layar identik yang diputar mengelilingi `pivot`.
local function computeCorners(bb)
    local preset = bb.type == 'prop' and presetByModel[bb.model]
    local sides = preset and preset.sides or 1
    local pivot = preset and preset.pivot or vec2(0.0, 0.0)
    local pos = vec3(bb.x, bb.y, bb.z)
    local quads = {}

    for k = 0, sides - 1 do
        local right, fwd, up = getAxes(bb.type == 'zone' and bb.rx or 0.0, bb.rz + k * 360.0 / sides)
        local center = pos + up * bb.oz
        if k == 0 then
            center += right * bb.ox + fwd * bb.oy
        else
            -- posisi relatif ke pivot ikut diputar; pivot sendiri tetap mengikuti rotasi prop
            local r0, f0 = getAxes(0.0, bb.rz)
            center += r0 * pivot.x + f0 * pivot.y + right * (bb.ox - pivot.x) + fwd * (bb.oy - pivot.y)
        end
        local hw, hh = right * (bb.width / 2), up * (bb.height / 2)
        quads[k + 1] = { center - hw + hh, center + hw + hh, center + hw - hh, center - hw - hh }

        if k == 0 then bb.center, bb.fwd = center, fwd end
    end
    bb.quads = quads
end

local function tri(a, b, c, v, txd, tex, ua, va, ub, vb, uc, vc)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, v, v, v, 255, txd, tex,
        ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

local function drawScreen(bb, s)
    local v = math.floor(255 * bb.brightness / 100)
    local txd, tex = s.txd, s.tex
    for i = 1, #bb.quads do
        local q = bb.quads[i]
        local tl, tr, br, bl = q[1], q[2], q[3], q[4]
        -- Digambar dua arah winding supaya selalu terlihat dari depan (poly GTA hanya satu sisi)
        tri(tl, tr, br, v, txd, tex, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0)
        tri(tl, br, bl, v, txd, tex, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0)
        tri(tl, br, tr, v, txd, tex, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0)
        tri(tl, bl, br, v, txd, tex, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
    end
end

---------------------------------------------------------------------
-- Pool DUI: browser dibuat sekali lalu dipakai ulang (tidak bocor memori)
---------------------------------------------------------------------

local function encode(s)
    return (s:gsub('[^%w%-_%.~]', function(ch) return ('%%%02X'):format(ch:byte()) end))
end

local function mediaUrl(bb)
    return ('%s?t=%s&s=%s&f=%s'):format(DUI_PAGE, bb.mediaType, encode(bb.mediaSrc), bb.fit)
end

local function getSlot(i)
    local s = slots[i]
    if s then return s end
    local dui = CreateDui('about:blank', Config.DuiWidth, Config.DuiHeight)
    local txdName = ('f_billboard_%d'):format(i)
    CreateRuntimeTextureFromDuiHandle(CreateRuntimeTxd(txdName), 'screen', GetDuiHandle(dui))
    s = { dui = dui, txd = txdName, tex = 'screen' }
    slots[i] = s
    return s
end

local function slotSet(s, key, bb)
    s.key = key
    local url = bb and mediaUrl(bb) or 'about:blank' -- about:blank = video berhenti, CPU idle
    -- DUI yang baru dibuat belum siap; SetDuiUrl saat itu diabaikan. Dicoba ulang di refresh berikutnya.
    if s.url ~= url and IsDuiAvailable(s.dui) then
        s.url = url
        SetDuiUrl(s.dui, url)
    end
end

---------------------------------------------------------------------
-- Prop billboard
---------------------------------------------------------------------

local function despawnProp(key)
    loading[key] = nil
    local ent = spawned[key]
    if ent ~= nil then
        if ent and DoesEntityExist(ent) then DeleteEntity(ent) end
        spawned[key] = nil
    end
end

local function spawnProp(key, bb)
    if spawned[key] ~= nil or loading[key] then return end
    local token = {}
    loading[key] = token
    CreateThread(function()
        local hash = joaat(bb.model)
        local ok = IsModelInCdimage(hash) and pcall(lib.requestModel, hash, 10000)

        -- billboard keburu dihapus / diubah / player menjauh saat model loading
        if loading[key] ~= token then
            if ok then SetModelAsNoLongerNeeded(hash) end
            return
        end
        loading[key] = nil
        if not ok then
            spawned[key] = false -- jangan dicoba ulang terus
            return
        end

        local ent = CreateObjectNoOffset(hash, bb.x, bb.y, bb.z, false, false, false)
        SetEntityRotation(ent, 0.0, 0.0, bb.rz, 2, false)
        FreezeEntityPosition(ent, true)
        if key == 'draft' then SetEntityCollision(ent, false, false) end
        SetModelAsNoLongerNeeded(hash)
        spawned[key] = ent
    end)
end

local function syncDraftProp()
    local ent = spawned.draft
    if draft and ent and DoesEntityExist(ent) then
        SetEntityCoordsNoOffset(ent, draft.x, draft.y, draft.z, false, false, false)
        SetEntityRotation(ent, 0.0, 0.0, draft.rz, 2, false)
    end
end

---------------------------------------------------------------------
-- Manager: tiap 1 detik tentukan prop mana yang muncul & layar mana yang menyala
---------------------------------------------------------------------

local function refresh()
    local pos = GetFinalRenderedCamCoord()
    local candidates = {}

    for id, bb in pairs(billboards) do
        if id == editingId then
            despawnProp(id)
        else
            if bb.type == 'prop' then
                local d = #(pos - vec3(bb.x, bb.y, bb.z))
                if d <= Config.PropStreamDistance then
                    spawnProp(id, bb)
                elseif d > Config.PropStreamDistance + 20.0 then
                    despawnProp(id)
                end
            end

            if bb.active and bb.mediaType then
                local d = #(pos - bb.center)
                if d <= bb.renderDistance then
                    candidates[#candidates + 1] = { key = id, bb = bb, dist = d }
                end
            end
        end
    end

    if draft then
        if draft.type == 'prop' then spawnProp('draft', draft) else despawnProp('draft') end
        if draft.mediaType then
            candidates[#candidates + 1] = { key = 'draft', bb = draft, dist = -1.0 }
        end
    else
        despawnProp('draft')
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local want = {}
    for i = 1, math.min(#candidates, Config.MaxActive) do
        want[candidates[i].key] = candidates[i].bb
    end

    local held = {}
    for i = 1, Config.MaxActive do
        local s = slots[i]
        if s and s.key ~= nil then
            if want[s.key] then held[s.key] = s else slotSet(s, nil, nil) end
        end
    end

    local list = {}
    for key, bb in pairs(want) do
        local s = held[key]
        if not s then
            for i = 1, Config.MaxActive do
                if not slots[i] or slots[i].key == nil then
                    s = getSlot(i)
                    break
                end
            end
        end
        slotSet(s, key, bb) -- reload otomatis kalau media berubah
        list[#list + 1] = { bb = bb, slot = s }
    end
    visible = list
end

CreateThread(function()
    local all = lib.callback.await('f_billboard:getAll', false) or {}
    for id, bb in pairs(all) do
        computeCorners(bb)
        billboards[id] = bb
    end
    while true do
        refresh()
        Wait(1000)
    end
end)

-- Garis tepi layar yang sedang diedit (supaya kelihatan walau URL belum diisi)
local function drawOutline(bb)
    for q = 1, #bb.quads do
        local c = bb.quads[q]
        for i = 1, 4 do
            local a, b = c[i], c[i % 4 + 1]
            DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 80, 200, 255, 255)
        end
    end
end

CreateThread(function()
    while true do
        if #visible == 0 and not draft then
            Wait(500)
        else
            for i = 1, #visible do
                local v = visible[i]
                drawScreen(v.bb, v.slot)
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
    for _, bb in pairs(billboards) do
        list[#list + 1] = {
            id = bb.id, label = bb.label, type = bb.type, mediaType = bb.mediaType,
            active = bb.active, dist = math.floor(#(pos - bb.center)),
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
        id = d.id, label = d.label, type = d.type, model = d.model,
        rx = r3(d.rx), rz = r3(d.rz), ox = r3(d.ox), oy = r3(d.oy), oz = r3(d.oz),
        width = r3(d.width), height = r3(d.height),
        url = d.url, mediaType = d.mediaType, fit = d.fit,
        brightness = d.brightness, renderDistance = d.renderDistance, active = d.active,
    }
end

local function applyPreset(d, model)
    local p = presetByModel[model] or BillboardPresets[1]
    d.model = p.model
    if p.width then
        d.width, d.height = p.width, p.height
        d.ox, d.oy, d.oz = p.offset.x, p.offset.y, p.offset.z
        return
    end
    -- tanpa ukuran di preset: tutupi seluruh sisi depan model
    local hash = joaat(p.model)
    if IsModelInCdimage(hash) and pcall(lib.requestModel, hash, 5000) then
        local min, max = GetModelDimensions(hash)
        SetModelAsNoLongerNeeded(hash)
        d.width, d.height = r3(max.x - min.x), r3(max.z - min.z)
        d.ox, d.oy, d.oz = r3((min.x + max.x) / 2), r3(min.y - 0.02), r3((min.z + max.z) / 2)
    end
end

local function clearDraft()
    draft, editingId = nil, nil
    despawnProp('draft')
    refresh()
end

local function startDraft(id)
    if id then
        local bb = billboards[id]
        if not bb then return false end
        draft = {}
        for k, v in pairs(bb) do draft[k] = v end
        editingId = id
    else
        local ped = cache.ped
        local heading = GetEntityHeading(ped)
        local pos = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 5.0
        draft = {
            label = 'Billboard', type = 'zone',
            x = pos.x, y = pos.y, z = pos.z + 1.0, rx = 0.0, rz = heading,
            ox = 0.0, oy = 0.0, oz = 0.0, width = 4.0, height = 2.25,
            url = '', fit = 'cover', brightness = 100,
            renderDistance = Config.DefaultRenderDistance, active = true,
        }
    end
    computeCorners(draft)
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

    if type(data.label) == 'string' then d.label = data.label:sub(1, 50) end

    local presetChanged = false
    if (data.type == 'prop' or data.type == 'zone') and data.type ~= d.type then
        if data.type == 'zone' then
            -- zone muncul tepat di posisi layar prop sebelumnya
            local c = d.center
            d.x, d.y, d.z = c.x, c.y, c.z
            d.model, d.ox, d.oy, d.oz = nil, 0.0, 0.0, 0.0
        else
            applyPreset(d, data.model)
            d.rx = 0.0
        end
        d.type = data.type
        despawnProp('draft')
        presetChanged = true
    elseif d.type == 'prop' and type(data.model) == 'string' and data.model ~= d.model and presetByModel[data.model] then
        applyPreset(d, data.model)
        despawnProp('draft')
        presetChanged = true
    end

    if not presetChanged then
        d.width = num(data.width, 0.1, Config.MaxSize, d.width)
        d.height = num(data.height, 0.1, Config.MaxSize, d.height)
        if d.type == 'prop' then
            d.ox = num(data.ox, -Config.MaxOffset, Config.MaxOffset, d.ox)
            d.oy = num(data.oy, -Config.MaxOffset, Config.MaxOffset, d.oy)
            d.oz = num(data.oz, -Config.MaxOffset, Config.MaxOffset, d.oz)
        else
            d.rx = num(data.rx, -90, 90, d.rx)
        end
        d.rz = num(data.rz, -720, 720, d.rz) % 360
    end

    if type(data.url) == 'string' then
        d.url = data.url:sub(1, Config.MaxUrlLength)
        d.mediaType, d.mediaSrc = DetectMedia(d.url)
    end
    if data.fit == 'cover' or data.fit == 'contain' or data.fit == 'fill' then d.fit = data.fit end
    d.brightness = math.floor(num(data.brightness, 10, 100, d.brightness))
    d.renderDistance = num(data.renderDistance, Config.MinRenderDistance, Config.MaxRenderDistance, d.renderDistance)
    if type(data.active) == 'boolean' then d.active = data.active end

    computeCorners(d)
    syncDraftProp()
    refresh()
end

local presetList
local function getPresetList()
    if presetList then return presetList end
    presetList = {}
    for i = 1, #BillboardPresets do
        local p = BillboardPresets[i]
        if IsModelInCdimage(joaat(p.model)) then
            presetList[#presetList + 1] = { model = p.model, label = p.label }
        end
    end
    return presetList
end

local function openEditor()
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        list = buildList(),
        presets = getPresetList(),
        limits = {
            minRender = Config.MinRenderDistance, maxRender = Config.MaxRenderDistance,
            maxSize = Config.MaxSize, maxOffset = Config.MaxOffset,
        },
    })
end

local function closeEditor()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if draft then clearDraft() end
end

local function teleportTo(bb)
    -- berdiri 6 meter di depan layar, menghadap layar
    local p = bb.center - bb.fwd * 6.0
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.0, false)
    local z = (found and p.z - gz < 15.0) and gz or p.z
    SetEntityCoords(cache.ped, p.x, p.y, z, false, false, false, false)
    SetEntityHeading(cache.ped, bb.rz)
end

---------------------------------------------------------------------
-- Mode penempatan
---------------------------------------------------------------------

local function camRaycast(dist, ignore)
    local camCoords = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cx = math.abs(math.cos(rx))
    local dest = camCoords + vec3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx)) * dist
    -- 1|16 = world + object (tanpa ped)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z,
        dest.x, dest.y, dest.z, 17, ignore or cache.ped, 4)
    local _, hit, endCoords, normal = GetShapeTestResult(handle)
    return hit == 1, endCoords, normal
end

local disabledControls = { 10, 11, 14, 15, 16, 17, 24, 25, 37, 44, 47, 140, 141, 142, 172, 173, 174, 175, 257, 263, 264 }

local function startPlacement()
    local d = draft
    if not d or placing then return end
    placing = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })

    local backup = { x = d.x, y = d.y, z = d.z, rx = d.rx, rz = d.rz, width = d.width, height = d.height }
    local isZone = d.type == 'zone'
    local align = isZone
    local lift = 0.0

    local help = '[Scroll] Putar (SHIFT = halus)  \n[PgUp/PgDn] Naik/Turun  \n[Panah Kiri/Kanan] Perbesar/Perkecil  \n'
    if isZone then
        help = help .. '[Panah Atas/Bawah] Miring  \n[G] Nempel dinding otomatis: %s  \n'
    end
    help = help .. '[E] Selesai  \n[Backspace] Batal'
    local shownAlign
    local confirmed = false

    while placing and draft == d do
        for i = 1, #disabledControls do DisableControlAction(0, disabledControls[i], true) end

        if isZone and shownAlign ~= align then
            shownAlign = align
            lib.showTextUI(help:format(align and 'ON' or 'OFF'))
        elseif not isZone and not shownAlign then
            shownAlign = true
            lib.showTextUI(help)
        end

        local ent = spawned.draft
        local hit, coords, normal = camRaycast(Config.PlaceDistance, ent and ent ~= 0 and ent or nil)

        local step = IsControlPressed(0, 21) and Config.RotateStepFine or Config.RotateStep
        if IsDisabledControlJustPressed(0, 15) then d.rz = (d.rz + step) % 360; align = false end
        if IsDisabledControlJustPressed(0, 14) then d.rz = (d.rz - step) % 360; align = false end
        if IsDisabledControlPressed(0, 10) then lift += Config.HeightStep end
        if IsDisabledControlPressed(0, 11) then lift -= Config.HeightStep end
        if IsDisabledControlPressed(0, 175) then
            d.width = math.min(Config.MaxSize, d.width * (1 + Config.ScaleStep))
            d.height = math.min(Config.MaxSize, d.height * (1 + Config.ScaleStep))
        end
        if IsDisabledControlPressed(0, 174) then
            d.width = math.max(0.1, d.width * (1 - Config.ScaleStep))
            d.height = math.max(0.1, d.height * (1 - Config.ScaleStep))
        end
        if isZone then
            if IsDisabledControlJustPressed(0, 47) then align = not align end
            if IsDisabledControlPressed(0, 172) then d.rx = math.min(90.0, d.rx + Config.PitchStep); align = false end
            if IsDisabledControlPressed(0, 173) then d.rx = math.max(-90.0, d.rx - Config.PitchStep); align = false end
        end

        if hit then
            if isZone then
                -- layar menghadap keluar dari dinding
                if align and math.abs(normal.z) < 0.7 then
                    d.rz = math.deg(math.atan(normal.x, -normal.y)) % 360
                    d.rx = 0.0
                end
                local p = coords + normal * 0.03
                d.x, d.y, d.z = p.x, p.y, p.z + lift
            else
                d.x, d.y, d.z = coords.x, coords.y, coords.z + lift
            end
        end

        computeCorners(d)
        syncDraftProp()

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
        computeCorners(d)
        syncDraftProp()
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
    local ok, res = lib.callback.await('f_billboard:save', false, {
        id = d.id, label = d.label, type = d.type, model = d.model,
        x = d.x, y = d.y, z = d.z, rx = d.rx, rz = d.rz, ox = d.ox, oy = d.oy, oz = d.oz,
        width = d.width, height = d.height, url = d.url, fit = d.fit,
        brightness = d.brightness, renderDistance = d.renderDistance, active = d.active,
    })
    if ok then clearDraft() end
    notifyResult(ok, res, 'Billboard tersimpan')
    cb({ ok = ok, list = buildList() })
end)

RegisterNUICallback('toggle', function(data, cb)
    local ok, res = lib.callback.await('f_billboard:toggle', false, tonumber(data.id))
    if not ok then notifyResult(false, res) end
    cb(1)
end)

RegisterNUICallback('delete', function(data, cb)
    local ok, res = lib.callback.await('f_billboard:delete', false, tonumber(data.id))
    notifyResult(ok, res, 'Billboard dihapus')
    cb(1)
end)

RegisterNUICallback('teleport', function(data, cb)
    cb(1)
    local bb = billboards[tonumber(data.id)]
    if not bb then return end
    closeEditor()
    teleportTo(bb)
end)

---------------------------------------------------------------------
-- Sinkronisasi dari server
---------------------------------------------------------------------

RegisterNetEvent('f_billboard:set', function(bb)
    if GetInvokingResource() or type(bb) ~= 'table' then return end
    despawnProp(bb.id) -- model/posisi bisa berubah, spawn ulang di refresh berikutnya
    computeCorners(bb)
    billboards[bb.id] = bb
    refresh()
    pushList()
end)

RegisterNetEvent('f_billboard:remove', function(id)
    if GetInvokingResource() then return end
    despawnProp(id)
    billboards[id] = nil
    if editingId == id then clearDraft() end
    refresh()
    pushList()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key in pairs(spawned) do despawnProp(key) end
    for i = 1, Config.MaxActive do
        if slots[i] then DestroyDui(slots[i].dui) end
    end
    if nuiOpen then SetNuiFocus(false, false) end
    if placing then lib.hideTextUI() end
end)

---------------------------------------------------------------------
-- Command
---------------------------------------------------------------------

RegisterCommand(Config.Command, function()
    if nuiOpen or placing then return end
    if not lib.callback.await('f_billboard:canUse', false) then
        return lib.notify({ type = 'error', description = 'Tidak punya izin' })
    end
    openEditor()
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Buka editor billboard (admin)')
