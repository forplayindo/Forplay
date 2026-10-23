-- f_crew client: Gang Wars mode "Rebut Bendera".
--
--   * Item bendera (ox_inventory client export useFlag): pegang / simpan. Server memasang state bag
--     'crewFlag' pada pemain -> semua client menempelkan prop lokal ke tangan pemain itu.
--   * Bendera tertancap: GlobalState.crewFlags -> prop lokal hanya dibuat kalau dekat.
--   * Perang bendera (data HUD dari server): prompt [E] di dekat tiang, tahan E = cabut / tancap.
--     Progres & semua syarat dihitung server; client hanya mengirim mulai dan batal.
--
-- Ringan: dua loop 1 detik (pemegang bendera di sekitar, bendera tertancap). Loop per frame hanya
-- saat memegang bendera, dekat tiang saat perang, atau dekat bendera tertancap (nama gang).

local FLAG_STATE = 'crewFlag'
local ITEM = 'bendera_gang'            -- sama dengan config Turf.Flag.Item
local DEFAULT_MODEL = 'prop_flag_us'   -- cadangan kalau model addon gagal dimuat
local DEFAULT_HAND = 'prop_golfflag'
local DRAW_DIST = 150.0                -- bendera tertancap dibuat dalam jarak ini
local TEXT_DIST = 25.0                 -- nama gang di atas bendera tertancap
local PROMPT_SLACK = 0.3               -- prompt muncul sedikit lebih dekat dari batas server

-- Posisi bendera di tangan (bone SKEL_R_Hand). Atur di game: /benderapos x y z rx ry rz
local BONE = 57005
local handPos = vec3(0.12, 0.02, -0.02)
local handRot = vec3(-80.0, 0.0, 0.0)
local HOLD_ANIM = { 'rcmnigel1d', 'base_club_shoulder' }
local ACT_ANIM = { pull = { 'mini@repair', 'fixing_a_ped' }, plant = { 'amb@world_human_gardener_plant@male@base', 'base' } }

local myHold        -- state bendera yang sedang saya pegang
local war           -- data HUD terakhir kalau gang saya sedang perang bendera
local acting = false
local heldProps = {} -- server id -> { obj, model, ped }
local planted = {}   -- zone id -> { obj, key, top, label, rgb }

local function call(name, payload)
    return lib.callback.await('f_crew:turf:call', false, name, payload) or { ok = false, err = 'Server tidak merespons.' }
end

local function notify(text, kind)
    lib.notify({ title = 'Rebut Bendera', description = text, type = kind or 'inform' })
end

local function loadModel(model)
    if type(model) ~= 'string' or model == '' then return nil end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return hash
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

local function hexRgb(c)
    local r, g, b = (c or ''):match('^#(%x%x)(%x%x)(%x%x)$')
    if not r then return 255, 255, 255 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

-- Bendera di tangan (semua pemain) -------------------------------------------------------------

local function deleteHeld(sid)
    local h = heldProps[sid]
    if not h then return end
    if DoesEntityExist(h.obj) then DeleteEntity(h.obj) end
    heldProps[sid] = nil
end

local function attachHeld(sid, ped, st)
    local hash = loadModel(st.m) or loadModel(DEFAULT_HAND)
    if not hash or not DoesEntityExist(ped) then return end
    deleteHeld(sid)
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, BONE), handPos.x, handPos.y, handPos.z, handRot.x, handRot.y, handRot.z,
        true, true, false, true, 1, true)
    heldProps[sid] = { obj = obj, model = st.m, ped = ped }
end

-- Bendera yang saya pegang: animasi, batasan, X = simpan --------------------------------------

local function stow()
    if not myHold then return end
    myHold = nil
    TriggerServerEvent('f_crew:flag:stow')
    SendNUIMessage({ action = 'flagCarry', data = nil })
end

local function holdLoop()
    local dictOk = loadDict(HOLD_ANIM[1])
    local nextCheck = 0
    while myHold do
        local ped = cache.ped
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped, true) then
            stow()
            break
        end
        if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true) end
        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 24, true)  -- serang
        DisableControlAction(0, 25, true)  -- bidik
        DisableControlAction(0, 37, true)  -- roda senjata
        DisableControlAction(0, 140, true) -- pukul
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 263, true)
        DisableControlAction(0, 23, true)  -- masuk kendaraan
        if dictOk and not acting and not IsEntityPlayingAnim(ped, HOLD_ANIM[1], HOLD_ANIM[2], 3) then
            TaskPlayAnim(ped, HOLD_ANIM[1], HOLD_ANIM[2], 8.0, -8.0, -1, 49, 0, false, false, false)
        end
        if IsControlJustPressed(0, 73) then -- X
            stow()
            break
        end
        local now = GetGameTimer()
        if now > nextCheck then
            nextCheck = now + 2000
            if (exports.ox_inventory:Search('count', ITEM) or 0) < 1 then
                stow()
                break
            end
        end
        Wait(0)
    end
    if dictOk then StopAnimTask(cache.ped, HOLD_ANIM[1], HOLD_ANIM[2], 2.0) end
end

local function onMyHold(st)
    local was = myHold
    myHold = st
    SendNUIMessage({ action = 'flagCarry', data = st and { label = st.l, color = st.c } or nil })
    if st and not was then CreateThread(holdLoop) end
end

AddStateBagChangeHandler(FLAG_STATE, nil, function(bag, _, value) ---@diagnostic disable-line: param-type-mismatch
    local ply = GetPlayerFromStateBagName(bag)
    if not ply or ply == 0 then return end
    local sid = GetPlayerServerId(ply)
    SetTimeout(0, function()
        deleteHeld(sid)
        if value then
            local ped = GetPlayerPed(ply)
            if ped ~= 0 then attachHeld(sid, ped, value) end
        end
        if ply == cache.playerId then onMyHold(value) end
    end)
end)

-- pemegang yang baru masuk jangkauan / ped berganti (respawn, ganti baju)
CreateThread(function()
    while true do
        local seen = {}
        for _, ply in ipairs(GetActivePlayers()) do
            local sid = GetPlayerServerId(ply)
            local st = Player(sid).state[FLAG_STATE]
            local ped = GetPlayerPed(ply)
            if st and ped ~= 0 then
                seen[sid] = true
                local h = heldProps[sid]
                if h and (h.model ~= st.m or h.ped ~= ped or not DoesEntityExist(h.obj) or not IsEntityAttachedToEntity(h.obj, ped)) then
                    deleteHeld(sid)
                    h = nil
                end
                if not h then attachHeld(sid, ped, st) end
            end
        end
        for sid in pairs(heldProps) do
            if not seen[sid] then deleteHeld(sid) end
        end
        Wait(1000)
    end
end)

-- Item: dipanggil ox_inventory (data/items.lua: client.export = 'f_crew.useFlag')
exports('useFlag', function(_, slot)
    if myHold then return stow() end
    if cache.vehicle then return notify('Turun dari kendaraan dulu.', 'error') end
    local res = call('flagHold', slot and slot.slot)
    if not res.ok then notify(res.err, 'error') end
end)

-- Cabut / tancap saat perang ------------------------------------------------------------------

local prompt
local function setPrompt(p)
    local key = p and (p.text .. (p.dim and '1' or '0')) or nil
    if key == prompt then return end
    prompt = key
    SendNUIMessage({ action = 'flagPrompt', data = p })
end

local function stopActAnim()
    for _, a in pairs(ACT_ANIM) do StopAnimTask(cache.ped, a[1], a[2], 2.0) end
end

local function cancelAct()
    if not acting then return end
    acting = false
    TriggerServerEvent('f_crew:flag:cancel')
    SendNUIMessage({ action = 'flagHold', data = nil })
    stopActAnim()
end

local function startAct()
    acting = true
    CreateThread(function()
        local res = call('flagStart')
        if not res.ok then
            acting = false
            return notify(res.err, 'error')
        end
        if not acting then return end -- E sudah dilepas sebelum server menjawab (batal sudah dikirim)
        local a = ACT_ANIM[res.data.kind]
        if a and loadDict(a[1]) then TaskPlayAnim(cache.ped, a[1], a[2], 8.0, -8.0, -1, 1, 0, false, false, false) end
        SendNUIMessage({ action = 'flagHold', data = { kind = res.data.kind, title = res.data.title, p = 0, left = res.data.need } })
    end)
end

local function warLoop()
    local startPos
    while war do
        local d = war
        local pt = d.point
        local ped = cache.ped
        local pos = GetEntityCoords(ped)
        local dist = #(pos.xy - vec2(pt[1], pt[2]))
        if dist > 40.0 then
            setPrompt(nil)
            if acting then cancelAct() end
            Wait(1000)
        else
            local radius = (d.radius or 2.5) - PROMPT_SLACK
            -- lingkaran area tiang
            local gz = pt[3] or pos.z - 1.0
            DrawMarker(1, pt[1], pt[2], gz - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2, radius * 2, 0.6, 255, 214, 10, 70, false, false, 2, false, nil, nil, false) ---@diagnostic disable-line: param-type-mismatch

            local kind
            if d.flag and d.flag.g ~= d.mine then
                kind = 'pull'
            elseif not d.flag then
                kind = (myHold and myHold.g == d.mine) and 'plant' or 'need'
            end

            if acting then
                setPrompt(nil)
                if not IsControlPressed(0, 38) or (startPos and #(pos - startPos) > 1.0) or IsEntityDead(ped) then cancelAct() end
            elseif dist <= radius and kind and not cache.vehicle then
                if d.action then -- orang lain (lawan / teman) sedang mencabut / menancap
                    setPrompt({ text = ('%s sedang %s bendera'):format(d.action.label, d.action.kind == 'pull' and 'mencabut' or 'menancapkan'), dim = true })
                elseif kind == 'pull' then
                    setPrompt({ key = 'E', text = ('Tahan untuk cabut bendera %s'):format(d.flag.label), sub = ('%d dtk'):format(d.pull or 15) })
                elseif kind == 'plant' then
                    setPrompt({ key = 'E', text = 'Tahan untuk tancap benderamu', sub = ('%d dtk'):format(d.plant or 20) })
                else
                    setPrompt({ key = 'E', text = 'Pegang item bendera gangmu dulu untuk menancap', dim = true })
                end
                if (kind == 'pull' or kind == 'plant') and not d.action and IsControlJustPressed(0, 38) then
                    startPos = pos
                    startAct()
                end
            else
                setPrompt(nil)
            end
            Wait(0)
        end
    end
    setPrompt(nil)
    if acting then cancelAct() end
end

RegisterNetEvent('f_crew:turf:hud', function(data)
    if type(data) == 'table' and data.mode == 'flag' and data.phase == 'war' and type(data.point) == 'table' then
        local start = not war
        war = data
        if start then CreateThread(warLoop) end
    else
        war = nil
    end
end)

RegisterNetEvent('f_crew:turf:hudDone', function() war = nil end)

RegisterNetEvent('f_crew:flag:progress', function(d)
    if type(d) ~= 'table' then return end
    if d.stop then
        acting = false
        stopActAnim()
        SendNUIMessage({ action = 'flagHold', data = nil })
        if d.done then notify(d.done, 'success') elseif d.reason then notify(d.reason, 'error') end
        return
    end
    if acting then SendNUIMessage({ action = 'flagHold', data = d }) end
end)

RegisterNetEvent('f_crew:flag:event', function(text)
    if type(text) == 'string' then notify(text) end
end)

-- Bendera tertancap (semua pemain) -------------------------------------------------------------

local function deletePlanted(id)
    local p = planted[id]
    if not p then return end
    if DoesEntityExist(p.obj) then DeleteEntity(p.obj) end
    planted[id] = nil
end

local function flagKey(f) return ('%s:%s:%s:%s:%s'):format(f.m, f.x, f.y, f.l, f.c) end

local function spawnPlanted(id, f, pos)
    local hash = loadModel(f.m) or loadModel(DEFAULT_MODEL)
    if not hash then return end
    local z = f.z
    if not z then
        local found, gz = GetGroundZFor_3dCoord(f.x, f.y, pos.z + 50.0, false)
        z = found and gz or pos.z - 1.0
    end
    local obj = CreateObject(hash, f.x, f.y, z, false, false, false)
    local _, max = GetModelDimensions(hash)
    SetModelAsNoLongerNeeded(hash)
    FreezeEntityPosition(obj, true)
    local r, g, b = hexRgb(f.c)
    planted[id] = { obj = obj, key = flagKey(f), top = vec3(f.x, f.y, z + max.z + 0.5), label = f.l or '', rgb = { r, g, b } }
end

local texting = false
local function textLoop()
    texting = true
    while texting do
        local pos = GetEntityCoords(cache.ped)
        local any = false
        for _, p in pairs(planted) do
            if #(pos - p.top) < TEXT_DIST + 8.0 then
                any = true
                SetDrawOrigin(p.top.x, p.top.y, p.top.z, 0)
                SetTextScale(0.0, 0.38)
                SetTextFont(4)
                SetTextCentre(true)
                SetTextOutline()
                SetTextColour(p.rgb[1], p.rgb[2], p.rgb[3], 235)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(p.label)
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()
            end
        end
        if not any then break end
        Wait(0)
    end
    texting = false
end

CreateThread(function()
    while true do
        local flags = GlobalState.crewFlags or {}
        local pos = GetEntityCoords(cache.ped)
        local near = false
        for id, f in pairs(flags) do
            local d = #(pos.xy - vec2(f.x, f.y))
            local p = planted[id]
            if p and p.key ~= flagKey(f) then
                deletePlanted(id)
                p = nil
            end
            if d < DRAW_DIST then
                if not p then spawnPlanted(id, f, pos) end
                if d < TEXT_DIST then near = true end
            elseif p then
                deletePlanted(id)
            end
        end
        for id in pairs(planted) do
            if not flags[id] then deletePlanted(id) end
        end
        if near and not texting then CreateThread(textLoop) end
        Wait(1000)
    end
end)

-- Atur posisi bendera di tangan (hanya tampilan lokal, untuk mencari angka yang pas lalu ditulis ke file ini)
RegisterCommand('benderapos', function(_, args)
    local n = {}
    for i = 1, 6 do n[i] = tonumber(args[i]) end
    if not n[6] then
        return print(('[f_crew] /benderapos x y z rx ry rz  (sekarang: %.2f %.2f %.2f %.1f %.1f %.1f)'):format(handPos.x, handPos.y, handPos.z, handRot.x, handRot.y, handRot.z))
    end
    handPos, handRot = vec3(n[1], n[2], n[3]), vec3(n[4], n[5], n[6])
    for sid in pairs(heldProps) do deleteHeld(sid) end -- loop 1 detik menempelkan ulang dengan posisi baru
    print(('[f_crew] posisi bendera: %.2f %.2f %.2f %.1f %.1f %.1f'):format(n[1], n[2], n[3], n[4], n[5], n[6]))
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    for sid in pairs(heldProps) do deleteHeld(sid) end
    for id in pairs(planted) do deletePlanted(id) end
    if myHold then StopAnimTask(cache.ped, HOLD_ANIM[1], HOLD_ANIM[2], 2.0) end
end)
