local config = require 'config.shared'
local pohonList = require 'config.pohon'

local MODEL = `f_kelapa_buah`
local sisa = GlobalState.kelapaPohon or {}   -- index pohon -> sisa kelapa (dari server)
local jatuh = GlobalState.kelapaJatuh or {}  -- id -> { x, y, z, t, n } kelapa di tanah
local rendered = false
local buahObj = {}    -- [pohon][titik] -> prop kelapa di pohon (lokal)
local dropObj = {}    -- id -> prop kelapa di tanah (lokal)
local climbing = false
local busy = false

local function notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end

---------------------------------------------------------------------------
-- prop kelapa (lokal, hanya di dekat kebun)
---------------------------------------------------------------------------
local function spawn(pos, rx, ry, rz)
    local obj = CreateObject(MODEL, pos.x, pos.y, pos.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityRotation(obj, rx, ry, rz, 2, false)
    return obj
end

local function groundZ(d)
    local ok, z = GetGroundZFor_3dCoord(d.x, d.y, d.z + 3.0, false)
    return (ok and z or d.z) + 0.1
end

local function hapusDrop(id)
    local obj = dropObj[id]
    if not obj then return end
    if DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteEntity(obj)
    end
    dropObj[id] = nil
end

local taruhDrop

local function pungut(id)
    if busy or climbing then return end
    busy = true
    local P = config.pungut
    local ped = cache.ped
    local obj, diangkat = dropObj[id], false
    CreateThread(function()
        -- anim asli lebih pendek dari progress bar -> diperlambat; kelapa menempel saat tangan sampai di tanah
        local start = GetGameTimer()
        while busy and GetGameTimer() - start < P.durasi do
            if IsEntityPlayingAnim(ped, P.dict, P.clip, 3) then
                SetEntityAnimSpeed(ped, P.dict, P.clip, P.lamaAnim / P.durasi)
            end
            if not diangkat and GetGameTimer() - start >= P.angkatSetelah and obj and DoesEntityExist(obj) then
                diangkat = true
                local t = P.tangan
                SetEntityCollision(obj, false, false)
                AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, t.bone), t.pos.x, t.pos.y, t.pos.z, t.rot.x, t.rot.y, t.rot.z, false, false, false, false, 2, true)
            end
            Wait(0)
        end
    end)
    local ok = lib.progressBar({
        duration = P.durasi, label = 'Memungut kelapa...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = P.dict, clip = P.clip, flag = 0 },
    })
    local function kembalikan()
        -- batal / gagal: kelapa yang sudah terangkat dikembalikan ke tanah
        if diangkat and dropObj[id] == obj and jatuh[id] then
            hapusDrop(id)
            taruhDrop(id, jatuh[id])
        end
    end
    if not ok then kembalikan() end
    if ok then
        local res = lib.callback.await('f_kelapa:server:pungut', false, id)
        if res and res.ok then
            notify('Kamu mendapat 1 kelapa muda.', 'success')
        else
            kembalikan()
            if res and res.msg then notify(res.msg, 'error') end
        end
    end
    busy = false
end

local function pasangTarget(id, obj)
    SetEntityCollision(obj, true, true)
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'f_kelapa_pungut', label = 'Pungut Kelapa', icon = 'fa-solid fa-hand', distance = 2.0,
            canInteract = function() return not busy and not climbing end,
            onSelect = function() pungut(id) end,
        },
    })
end

function taruhDrop(id, d)
    local obj = spawn(vec3(d.x, d.y, groundZ(d)), math.random(0, 359), 90.0, math.random(0, 359))
    dropObj[id] = obj
    pasangTarget(id, obj)
end

-- kelapa baru dipetik: jatuh dari titik buah di pohon ke tanah
local function jatuhkan(id, d)
    local p = pohonList[d.t]
    local from = p and p.buah[d.n]
    if not from then return taruhDrop(id, d) end
    local to = vec3(d.x, d.y, groundZ(d))
    local obj = spawn(from, 0.0, 0.0, 0.0)
    SetEntityCollision(obj, false, false)
    dropObj[id] = obj
    CreateThread(function()
        local start, dur = GetGameTimer(), 900
        while true do
            local t = math.min((GetGameTimer() - start) / dur, 1.0)
            if dropObj[id] ~= obj or not DoesEntityExist(obj) then return end
            -- xy lurus, z dipercepat (t^2) seperti jatuh bebas
            SetEntityCoordsNoOffset(obj, from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t, from.z + (to.z - from.z) * t * t, false, false, false)
            SetEntityRotation(obj, t * 540.0, 90.0, t * 220.0, 2, false)
            if t >= 1.0 then break end
            Wait(0)
        end
        pasangTarget(id, obj)
    end)
end

local function refreshPohon(i)
    local p = pohonList[i]
    buahObj[i] = buahObj[i] or {}
    for n = 1, config.buahPerPohon do
        local ada = n <= (sisa[i] or 0)
        local obj = buahObj[i][n]
        if ada and not obj and p.buah[n] then
            obj = spawn(p.buah[n], (n * 37) % 50 - 25, (n * 23) % 40 - 20, (n * 61) % 360)
            SetEntityCollision(obj, false, false)
            buahObj[i][n] = obj
        elseif not ada and obj then
            DeleteEntity(obj)
            buahObj[i][n] = nil
        end
    end
end

local function render()
    lib.requestModel(MODEL)
    rendered = true
    for i in ipairs(pohonList) do refreshPohon(i) end
    for id, d in pairs(jatuh) do
        if not dropObj[id] then taruhDrop(id, d) end
    end
end

local function unrender()
    rendered = false
    for i, list in pairs(buahObj) do
        for _, obj in pairs(list) do DeleteEntity(obj) end
        buahObj[i] = nil
    end
    for id in pairs(dropObj) do hapusDrop(id) end
    SetModelAsNoLongerNeeded(MODEL)
end

AddStateBagChangeHandler('kelapaPohon', 'global', function(_, _, value)
    sisa = value or {}
    if rendered then
        for i in ipairs(pohonList) do refreshPohon(i) end
    end
end)

AddStateBagChangeHandler('kelapaJatuh', 'global', function(_, _, value)
    jatuh = value or {}
    if not rendered then return end
    for id in pairs(dropObj) do
        if not jatuh[id] then hapusDrop(id) end
    end
    for id, d in pairs(jatuh) do
        if not dropObj[id] then jatuhkan(id, d) end
    end
end)

CreateThread(function()
    while true do
        local near = #(GetEntityCoords(cache.ped) - config.kebun) < config.jarakRender
        if near ~= rendered then
            if near then render() else unrender() end
        end
        Wait(1500)
    end
end)

---------------------------------------------------------------------------
-- panjat: tahan W naik, tahan S turun, [E] petik di atas, S di bawah = turun ke tanah
---------------------------------------------------------------------------
local cfg = config.panjat
-- gerak, lompat, senjata, masuk mobil, cover, melee; W (32) S (33) E (38) dibaca lewat IsDisabledControl*
local BLOCK = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 45, 47, 140, 141, 142, 143, 257, 263, 264 }

local function headingKe(dx, dy)  -- heading GTA untuk menghadap arah (dx, dy): 0 = +Y, 90 = -X
    return (math.deg(math.atan(-dx, dy)) + 360.0) % 360.0
end

-- titik pinggang ped di ketinggian h dari pangkal: sumbu batang (condong) + sisi tempat player mulai
local function posisi(p, h, sisi)
    local sumbu = p.coords + (p.atas - p.coords) * (h / (p.atas.z - p.coords.z))
    return sumbu + sisi * cfg.jarakBatang
end

local function blokir()
    for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
end

local function putar(ped, clip, loop)
    TaskPlayAnim(ped, cfg.dict, clip, 4.0, -4.0, -1, loop and 1 or 2, 0.0, false, false, false)
end

-- Ped ditempel ke prop pembantu tak terlihat; prop itu yang digeser naik/turun.
-- (Freeze + collision off pada ped mematikan animasinya -> ped A-pose.)
local pegangan

local function taruh(pos)
    SetEntityCoordsNoOffset(pegangan, pos.x, pos.y, pos.z, false, false, false)
end

-- animasi sekali jalan (naik ke batang / turun ke tanah); false kalau ped mati
local function sekali(ped, clip)
    putar(ped, clip, false)
    local sampai = GetGameTimer() + math.floor(GetAnimDuration(cfg.dict, clip) * 1000)
    while GetGameTimer() < sampai do
        if IsPedDeadOrDying(ped, true) then return false end
        blokir()
        Wait(0)
    end
    return true
end

local function teks(diAtas, n)
    local t = '[W] Naik  \n[S] Turun'
    if diAtas then
        t = n > 0 and ('[E] Petik kelapa (%d)  \n[S] Turun'):format(n) or '[S] Turun (kelapa habis)'
    end
    lib.showTextUI(t, { position = 'right-center' })
end

-- selama memanjat semua animasi lain dimatikan: emote rpemotes, reaksi f_hygiene (cek sibukAnim/canEmote)
local bisaEmote

local function kunciAnim(ped)
    pcall(function() exports.rpemotes:EmoteCancel(true) end)
    ClearPedSecondaryTask(ped)
    bisaEmote = LocalPlayer.state.canEmote
    LocalPlayer.state:set('sibukAnim', true, false)
    LocalPlayer.state:set('canEmote', false, true)
end

local function lepasPed(ped, clip)
    DetachEntity(ped, true, false)
    -- clip = animasi terakhir: dilepas pelan supaya ped tidak tersentak; tanpa clip langsung dibersihkan
    if clip then StopAnimTask(ped, cfg.dict, clip, 1.5) else ClearPedTasks(ped) end
    ClearPedSecondaryTask(ped)
    if pegangan and DoesEntityExist(pegangan) then DeleteEntity(pegangan) end
    pegangan = nil
    LocalPlayer.state:set('sibukAnim', false, false)
    LocalPlayer.state:set('canEmote', bisaEmote ~= false, true)
end

local function panjat(i)
    if climbing or busy then return end
    local p = pohonList[i]
    climbing = true
    local res = lib.callback.await('f_kelapa:server:panjat', false, i)
    if not res or not res.ok then
        climbing = false
        if res and res.msg then notify(res.msg, 'error') end
        return
    end

    local ped = cache.ped
    kunciAnim(ped)
    lib.requestAnimDict(cfg.dict)
    lib.requestAnimDict(config.petik.dict)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

    -- naik dari sisi tempat player berdiri, menghadap batang
    local here = GetEntityCoords(ped)
    local sisi = vec3(here.x - p.coords.x, here.y - p.coords.y, 0.0)
    sisi = #sisi > 0.05 and sisi / #sisi or vec3(-1.0, 0.0, 0.0)
    local hadap = headingKe(-sisi.x, -sisi.y)

    local bawah, atas = cfg.tinggiAwal, p.atas.z - p.coords.z - cfg.kurangAtas
    local h = bawah
    local start = posisi(p, h, sisi)
    lib.requestModel(MODEL)
    pegangan = CreateObject(MODEL, start.x, start.y, start.z, false, false, false)
    SetEntityVisible(pegangan, false, false)
    SetEntityCollision(pegangan, false, false)
    FreezeEntityPosition(pegangan, true)
    SetEntityHeading(pegangan, hadap)
    AttachEntityToEntity(ped, pegangan, 0, 0.0, 0.0, cfg.angkat + 0.0, 0.0, 0.0, cfg.rotasi + 0.0, false, false, false, false, 2, true)

    local hidup = sekali(ped, cfg.mulai)
    local n = sisa[i] or 0
    local state, diAtas
    local petikSampai, jatuhPada = 0, nil  -- anim meraih sedang jalan / waktu kelapa dilepas
    while hidup do
        if IsPedDeadOrDying(ped, true) then hidup = false break end
        blokir()
        local dt = GetFrameTime()
        local now = GetGameTimer()
        local meraih = now < petikSampai
        -- selama tangan meraih kelapa, W/S diabaikan
        local w = not meraih and IsDisabledControlPressed(0, 32)
        local s = not meraih and IsDisabledControlPressed(0, 33)
        local mau = 'diam'
        if w and not s and h < atas then
            h = math.min(h + cfg.kecepatanNaik * dt, atas)
            mau = 'naik'
        elseif s and not w then
            if h <= bawah then break end  -- sudah di bawah: turun ke tanah
            h = math.max(h - cfg.kecepatanTurun * dt, bawah)
            mau = 'turun'
        end
        if mau ~= state then
            state = mau
            putar(ped, cfg[mau], true)
        end
        taruh(posisi(p, h, sisi))

        local sekarangAtas = h >= atas - 0.05
        if sekarangAtas ~= diAtas then
            diAtas = sekarangAtas
            teks(diAtas, n)
        end
        if diAtas and n > 0 and not meraih and IsDisabledControlJustPressed(0, 38) then
            -- tangan kanan meraih ke atas (badan atas saja, flag 48), kelapa lepas di tengah gerakan
            TaskPlayAnim(ped, config.petik.dict, config.petik.clip, 4.0, -4.0, config.petik.durasi, 48, 0.0, false, false, false)
            petikSampai = now + config.petik.durasi
            jatuhPada = now + config.petik.jatuhSetelah
        end
        if jatuhPada and now >= jatuhPada then
            jatuhPada = nil
            local r = lib.callback.await('f_kelapa:server:petik', false)
            if r and r.ok then
                n = r.sisa
                teks(true, n)
            elseif r and r.msg then
                notify(r.msg, 'error')
            end
        end
        Wait(0)
    end
    lib.hideTextUI()

    -- langsung dilepas di tempat (pinggang sudah setinggi orang berdiri), tanpa anim turun tangga yang meloncat
    lepasPed(ped, hidup and cfg[state or 'diam'] or nil)
    if hidup then SetEntityHeading(ped, hadap) end
    RemoveAnimDict(cfg.dict)
    RemoveAnimDict(config.petik.dict)
    TriggerServerEvent('f_kelapa:server:turun')
    climbing = false
end

for i, p in ipairs(pohonList) do
    exports.ox_target:addSphereZone({
        coords = p.coords + vec3(0.0, 0.0, 1.15),
        radius = 0.9,
        options = {
            {
                name = 'f_kelapa_panjat', label = 'Panjat Pohon Kelapa', icon = 'fa-solid fa-arrow-up', distance = 2.5,
                canInteract = function() return not climbing and not busy and (sisa[i] or 0) > 0 end,
                onSelect = function() panjat(i) end,
            },
        },
    })
end

if config.debug then
    -- /kelapaanim <naik m/s> <turun m/s> <jarakBatang> <rotasi> <angkat> <kurangAtas> : kalibrasi tanpa restart (berlaku saat panjat berikutnya)
    RegisterCommand('kelapaanim', function(_, args)
        cfg.kecepatanNaik = tonumber(args[1]) or cfg.kecepatanNaik
        cfg.kecepatanTurun = tonumber(args[2]) or cfg.kecepatanTurun
        cfg.jarakBatang = tonumber(args[3]) or cfg.jarakBatang
        cfg.rotasi = tonumber(args[4]) or cfg.rotasi
        cfg.angkat = tonumber(args[5]) or cfg.angkat
        cfg.kurangAtas = tonumber(args[6]) or cfg.kurangAtas
        notify(('Panjat: naik %.2f, turun %.2f, jarak batang %.2f, rotasi %d, angkat %.2f, kurang atas %.2f'):format(
            cfg.kecepatanNaik, cfg.kecepatanTurun, cfg.jarakBatang, cfg.rotasi, cfg.angkat, cfg.kurangAtas), 'inform')
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    unrender()
    if climbing then
        lepasPed(cache.ped)
        lib.hideTextUI()
    end
end)
