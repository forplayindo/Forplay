local config = require 'config.shared'
local cfg = require 'config.client'
local kebun = require 'config.kebun'

local kerja = false
local busy = false
local outfitSaved
local keranjang = { state = nil, obj = nil, n = 0, jenis = nil, isi = {} }  -- state: 'bawa' | 'tanah' | 'injak'
local pegang                -- { jenis, obj } tandan di tangan
local tumbuh = {}           -- 'spot:idx' -> GetGameTimer() tandan muncul lagi
local tandanObj = {}        -- 'spot:idx' -> prop tandan di pohon (lokal)
local objKey = {}           -- prop -> { spot, idx }
local tubObj = {}           -- pos injak -> prop tong
local injak = false
local nuiOpen = false

local MODEL_TANDAN, MODEL_TONG = {}, {}
for _, j in pairs(config.jenis) do
    MODEL_TANDAN[#MODEL_TANDAN + 1] = j.tandan
    MODEL_TONG[#MODEL_TONG + 1] = j.tong
end

-- titik tengah tiap blok (untuk waypoint dari menu Mandor)
local blokTengah = {}
do
    local sum = {}
    for _, s in ipairs(kebun) do
        local b = sum[s.j] or { x = 0, y = 0, z = 0, n = 0 }
        b.x, b.y, b.z, b.n = b.x + s.c.x, b.y + s.c.y, b.z + s.c.z, b.n + 1
        sum[s.j] = b
    end
    for j, b in pairs(sum) do blokTengah[j] = vec3(b.x / b.n, b.y / b.n, b.z / b.n) end
end

local function notify(msg, typ)
    exports.qbx_core:Notify(msg, typ or 'inform')
end

-- panel Alur Kerja (f_panduan), opsional
local function panduan(fn, ...)
    if GetResourceState('f_panduan') == 'started' then exports.f_panduan[fn](exports.f_panduan, ...) end
end

local function langkah()
    if keranjang.n >= config.keranjangMax or injak then return 4 end
    if keranjang.state == 'tanah' or pegang then return 3 end
    return 2
end

AddEventHandler('f_panduan:client:requestStep', function(job)
    if job ~= 'wine' or not kerja then return end
    panduan('SetStep', 'wine', langkah())
end)

local function groundZ(c, fallback)
    local ok, z = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    return ok and z or (fallback or c.z)
end

local function spawnObj(model, x, y, z)
    lib.requestModel(model)
    local o = CreateObjectNoOffset(model, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    return o
end

local function hapus(o)
    if o and DoesEntityExist(o) then DeleteEntity(o) end
end

---------------------------------------------------------------------------
-- baju kerja (wajib), sama seperti f_mining
---------------------------------------------------------------------------
local KOMPONEN = { pants = 4, arms = 3, ['t-shirt'] = 8, torso2 = 11, shoes = 6 }

local function myOutfit()
    local female = tonumber(QBX.PlayerData.charinfo and QBX.PlayerData.charinfo.gender) == 1
    return female and cfg.outfit.female or cfg.outfit.male
end

local function pakaiBaju()
    local o = myOutfit()
    if not outfitSaved then
        local ok, ap = pcall(function() return exports['illenium-appearance']:getPedAppearance(cache.ped) end)
        outfitSaved = ok and ap or true
    end
    for name, comp in pairs(KOMPONEN) do
        local p = o[name]
        if p then SetPedComponentVariation(cache.ped, comp, p.item, p.texture, 0) end
    end
    if o.hat then
        if o.hat.item < 0 then ClearPedProp(cache.ped, 0) else SetPedPropIndex(cache.ped, 0, o.hat.item, o.hat.texture, true) end
    end
end

local function lepasBaju()
    if not outfitSaved then return end
    local saved = outfitSaved
    outfitSaved = nil
    if type(saved) == 'table' and pcall(function() exports['illenium-appearance']:setPedAppearance(cache.ped, saved) end) then return end
    TriggerEvent('illenium-appearance:client:reloadSkin', true)
end

local function pakaiBajuKerja()
    return GetPedDrawableVariation(cache.ped, 11) == myOutfit().torso2.item
end

---------------------------------------------------------------------------
-- keranjang: dibawa (dua tangan) / ditaruh di tanah, isinya kelihatan
---------------------------------------------------------------------------
local function hapusIsi()
    for _, o in ipairs(keranjang.isi) do hapus(o) end
    keranjang.isi = {}
end

local function updateIsi()
    hapusIsi()
    if not keranjang.obj or keranjang.n <= 0 or not keranjang.jenis then return end
    local model = config.jenis[keranjang.jenis].tandan
    local slot = cfg.isiKeranjang
    local tampil = math.min(#slot, math.ceil(keranjang.n * #slot / config.keranjangMax))
    for i = 1, tampil do
        local o = spawnObj(model, 0.0, 0.0, 0.0)
        SetEntityCollision(o, false, false)
        AttachEntityToEntity(o, keranjang.obj, 0, slot[i][1].x, slot[i][1].y, slot[i][1].z, slot[i][2].x, slot[i][2].y, slot[i][2].z,
            false, false, false, false, 2, true)
        keranjang.isi[#keranjang.isi + 1] = o
    end
end

local BLOK_BAWA = { 21, 22, 23, 24, 25, 37, 44, 45, 140, 141, 142, 143, 257, 263, 264 }
local bawaJalan = false

local function loopBawa()
    if bawaJalan then return end
    bawaJalan = true
    CreateThread(function()
        local a = cfg.anim.bawa
        lib.requestAnimDict(a.dict)
        lib.showTextUI('[G] Taruh keranjang', { position = 'right-center' })
        while kerja and keranjang.state == 'bawa' do
            local ped = cache.ped
            if not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) and not IsPedRagdoll(ped) then
                TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, 49, 0.0, false, false, false)
            end
            for _, c in ipairs(BLOK_BAWA) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustPressed(0, 47) and not busy and not IsPedInAnyVehicle(ped, false) then
                bawaJalan = false
                lib.hideTextUI()
                StopAnimTask(ped, a.dict, a.clip, 1.0)
                TriggerEvent('f_wine:client:taruh')
                return
            end
            Wait(0)
        end
        bawaJalan = false
        lib.hideTextUI()
        StopAnimTask(cache.ped, a.dict, a.clip, 1.0)
    end)
end

local function bawaKeranjang()
    local ped = cache.ped
    if not keranjang.obj or not DoesEntityExist(keranjang.obj) then
        local c = GetEntityCoords(ped)
        keranjang.obj = spawnObj(cfg.keranjang, c.x, c.y, c.z)
        updateIsi()
    end
    FreezeEntityPosition(keranjang.obj, false)
    SetEntityCollision(keranjang.obj, false, false)
    local a = cfg.pasang.keranjangBawa
    AttachEntityToEntity(keranjang.obj, ped, a.bone == 0 and 0 or GetPedBoneIndex(ped, a.bone), a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z,
        false, false, false, false, 2, true)
    keranjang.state = 'bawa'
    loopBawa()
end

local function taruhDiTanah(pos, heading)
    local o = keranjang.obj
    DetachEntity(o, true, false)
    SetEntityCoordsNoOffset(o, pos.x, pos.y, groundZ(pos, pos.z - 1.0), false, false, false)
    SetEntityHeading(o, heading)
    PlaceObjectOnGroundProperly(o)
    FreezeEntityPosition(o, true)
    SetEntityCollision(o, true, true)
end

AddEventHandler('f_wine:client:taruh', function()
    if busy or keranjang.state ~= 'bawa' then return end
    busy = true
    local ped = cache.ped
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.75, 0.0)
    local res = lib.callback.await('f_wine:server:taruh', false, pos)
    if res and res.ok then
        keranjang.state = 'tanah'
        taruhDiTanah(pos, GetEntityHeading(ped))
        if keranjang.n == 0 then notify('Keranjang ditaruh. Petik tandan anggur di pohon sekitar sini.') end
        panduan('SetStep', 'wine', 3)
    else
        loopBawa()
    end
    busy = false
end)

local function angkat()
    if busy then return end
    busy = true
    local res = lib.callback.await('f_wine:server:angkat', false)
    if res and res.ok then
        bawaKeranjang()
        if keranjang.n >= config.keranjangMax then
            notify('Bawa keranjang penuh ke tong injak di pinggir blok ini.', 'inform')
            panduan('SetStep', 'wine', 4)
        end
    elseif res and res.msg then
        notify(res.msg, 'error')
    end
    busy = false
end

RegisterNetEvent('f_wine:client:keranjangKembali', function()
    if not kerja then return end
    notify('Keranjangmu ditinggal terlalu lama, sekarang kembali ke tanganmu.', 'inform')
    bawaKeranjang()
end)

---------------------------------------------------------------------------
-- tandan di pohon (lokal, per pemain) + petik + masukkan ke keranjang
---------------------------------------------------------------------------
local function kunci(s, i) return s .. ':' .. i end

local function hapusTandan(k)
    local o = tandanObj[k]
    if o then
        objKey[o] = nil
        hapus(o)
        tandanObj[k] = nil
    end
end

local function hapusSemuaTandan()
    for k in pairs(tandanObj) do hapusTandan(k) end
end

local function loopTandan()
    CreateThread(function()
        while kerja do
            local p = GetEntityCoords(cache.ped)
            local now = GetGameTimer()
            for s, spot in ipairs(kebun) do
                local dekat = #(p - spot.c) < config.jarak.render
                for i, t in ipairs(spot.t) do
                    local k = kunci(s, i)
                    local mau = dekat and (not tumbuh[k] or now >= tumbuh[k])
                    local o = tandanObj[k]
                    if mau and not o then
                        o = spawnObj(config.jenis[spot.j].tandan, t.x, t.y, t.z)
                        SetEntityHeading(o, t.w + 0.0)
                        FreezeEntityPosition(o, true)
                        tandanObj[k], objKey[o] = o, { s, i }
                    elseif not mau and o then
                        hapusTandan(k)
                    end
                end
            end
            Wait(1000)
        end
        hapusSemuaTandan()
    end)
end

local function pegangTandan(jenis)
    local ped = cache.ped
    local o = spawnObj(config.jenis[jenis].tandan, 0.0, 0.0, 0.0)
    SetEntityCollision(o, false, false)
    local a = cfg.pasang.tandanTangan
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, a.bone), a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, false, false, false, false, 2, true)
    pegang = { jenis = jenis, obj = o }
end

local function petik(ent)
    local ref = objKey[ent]
    if not ref or busy or pegang then return end
    if not pakaiBajuKerja() then return notify('Pakai baju kerja dulu. Bicara dengan Mandor Kebun.', 'error') end
    if keranjang.state ~= 'tanah' then return notify('Taruh keranjangmu dulu di dekat pohon dengan [G].', 'error') end
    busy = true
    local s, i = ref[1], ref[2]
    local t = kebun[s].t[i]
    local ped = cache.ped
    local kaki = GetEntityCoords(ped).z - GetEntityHeightAboveGround(ped)
    local a = (t.z - kaki) < cfg.anim.batasRendah and cfg.anim.petikRendah or cfg.anim.petikTinggi
    TaskTurnPedToFaceCoord(ped, t.x, t.y, t.z, 500)
    Wait(500)
    local ok = lib.progressBar({
        duration = cfg.anim.petikMs, label = 'Memetik anggur...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = a.dict, clip = a.clip, flag = 1 },
    })
    if ok then
        local res = lib.callback.await('f_wine:server:petik', false, s, i)
        if res and res.ok then
            local k = kunci(s, i)
            tumbuh[k] = GetGameTimer() + res.tumbuh * 1000
            hapusTandan(k)
            pegangTandan(res.jenis)
        elseif res and res.msg then
            notify(res.msg, 'error')
        end
    end
    busy = false
end

local function masukkan()
    if busy or not pegang then return end
    busy = true
    local a = cfg.anim.masukkan
    TaskTurnPedToFaceEntity(cache.ped, keranjang.obj, 400)
    Wait(400)
    local ok = lib.progressBar({
        duration = a.ms, label = 'Memasukkan ke keranjang...', canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = a.dict, clip = a.clip, flag = 0 },
    })
    if ok then
        local res = lib.callback.await('f_wine:server:masukkan', false)
        if res and res.ok then
            hapus(pegang.obj)
            pegang = nil
            keranjang.n, keranjang.jenis = res.n, res.jenis
            updateIsi()
            if res.n >= config.keranjangMax then
                notify('Keranjang penuh! Angkat keranjang lalu bawa ke tong injak di pinggir blok.', 'success')
                panduan('SetStep', 'wine', 4)
            else
                notify(('Keranjang %d/%d'):format(res.n, config.keranjangMax), 'inform')
            end
        elseif res and res.msg then
            notify(res.msg, 'error')
        end
    end
    busy = false
end

exports.ox_target:addModel(MODEL_TANDAN, {
    {
        name = 'f_wine_petik', label = 'Petik anggur', icon = 'fa-solid fa-hand', distance = config.jarak.petik,
        canInteract = function(entity) return kerja and not busy and not pegang and objKey[entity] ~= nil end,
        onSelect = function(data) petik(data.entity) end,
    },
})

exports.ox_target:addModel({ cfg.keranjang }, {
    {
        name = 'f_wine_masukkan', label = 'Masukkan anggur', icon = 'fa-solid fa-basket-shopping', distance = config.jarak.keranjang,
        canInteract = function(entity) return kerja and not busy and pegang ~= nil and entity == keranjang.obj and keranjang.state == 'tanah' end,
        onSelect = masukkan,
    },
    {
        name = 'f_wine_angkat', label = 'Angkat keranjang', icon = 'fa-solid fa-hands', distance = config.jarak.keranjang,
        canInteract = function(entity) return kerja and not busy and not pegang and entity == keranjang.obj and keranjang.state == 'tanah' end,
        onSelect = angkat,
    },
})

---------------------------------------------------------------------------
-- tong injak di pinggir tiap blok + minigame A/D
---------------------------------------------------------------------------
for pos, c in pairs(config.lokasi.injak) do
    lib.points.new({
        coords = c.xyz, distance = 70.0,
        onEnter = function()
            if tubObj[pos] then return end
            local o = spawnObj(config.jenis[pos].tong, c.x, c.y, groundZ(c, c.z))
            SetEntityHeading(o, c.w + 0.0)
            FreezeEntityPosition(o, true)
            tubObj[pos] = o
        end,
        onExit = function()
            if injak then return end
            hapus(tubObj[pos])
            tubObj[pos] = nil
        end,
    })
end

local function posDariTong(ent)
    for pos, o in pairs(tubObj) do
        if o == ent then return pos end
    end
end

local KEY = { A = 34, D = 35 }

local function minigame(jenis)
    local m = cfg.minigame
    local mulai = GetGameTimer()
    local prog, last = 0.0, 0
    local function acak() return math.random() < 0.5 and 'A' or 'D' end
    local now, next = acak(), acak()
    local warna = config.jenis[jenis] and config.jenis[jenis].warna
    SendNUIMessage({ action = 'injak', show = true, key = now, next = next, progress = 0, warna = warna })
    while true do
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true); EnableControlAction(0, 2, true)  -- kamera
        EnableControlAction(0, 245, true); EnableControlAction(0, 249, true) -- chat + push to talk
        if IsPedDeadOrDying(cache.ped, true) then break end
        if IsDisabledControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 177) then break end -- X / Backspace = berhenti
        local t = GetGameTimer()
        local tekan = IsDisabledControlJustPressed(0, KEY.A) and 'A' or IsDisabledControlJustPressed(0, KEY.D) and 'D' or nil
        if tekan and prog < 1.0 and t - last >= m.jedaMs then
            last = t
            local benar = tekan == now
            if benar then
                prog = math.min(1.0, prog + 1.0 / m.tekanan)
                now, next = next, acak()
            else
                prog = math.max(0.0, prog - m.salah)
            end
            SendNUIMessage({ action = 'injak', key = now, next = next, progress = prog, flash = benar and 'ok' or 'bad' })
        end
        if prog >= 1.0 then
            -- server menolak kalau terlalu cepat: tunggu sampai waktu minimal lewat
            if t - mulai >= (config.injakMinDetik + 0.5) * 1000 then
                SendNUIMessage({ action = 'injak', show = false })
                return true
            end
            SendNUIMessage({ action = 'injak', progress = 1, tunggu = true })
        end
        Wait(0)
    end
    SendNUIMessage({ action = 'injak', show = false })
    return false
end

local function mulaiInjak(ent)
    local pos = posDariTong(ent)
    if not pos or busy or injak then return end
    busy = true
    local res = lib.callback.await('f_wine:server:mulaiInjak', false, pos)
    if not res or not res.ok then
        busy = false
        if res and res.msg then notify(res.msg, 'error') end
        return
    end
    injak = true
    keranjang.state = 'injak'   -- loop bawa berhenti
    Wait(50)
    local ped, tub = cache.ped, tubObj[pos]
    -- keranjang ditaruh di samping tong, pemain naik ke dalam tong
    taruhDiTanah(GetOffsetFromEntityInWorldCoords(tub, 0.95, 0.35, 0.0), GetEntityHeading(tub))
    SetEntityCollision(keranjang.obj, false, false)
    local a = cfg.anim.injak
    lib.requestAnimDict(a.dict)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    AttachEntityToEntity(ped, tub, 0, 0.0, 0.0, cfg.pasang.injakZ, 0.0, 0.0, GetEntityHeading(ped) - GetEntityHeading(tub),
        false, false, false, false, 2, true)
    TaskPlayAnim(ped, a.dict, a.clip, 4.0, -4.0, -1, 1, 0.0, false, false, false)
    LocalPlayer.state:set('sibukAnim', true, false)
    panduan('SetStep', 'wine', 4)

    local selesai = minigame(res.jenis)

    DetachEntity(ped, true, false)
    StopAnimTask(ped, a.dict, a.clip, 1.0)
    local turun = GetOffsetFromEntityInWorldCoords(tub, -1.0, 0.0, 0.0)
    SetEntityCoords(ped, turun.x, turun.y, groundZ(turun, turun.z), false, false, false, false)
    RemoveAnimDict(a.dict)
    LocalPlayer.state:set('sibukAnim', false, false)

    if selesai then
        local r = lib.callback.await('f_wine:server:selesaiInjak', false)
        if r and r.ok then
            keranjang.n, keranjang.jenis = 0, nil
            updateIsi()
            notify(('Kamu mendapat 1 %s. Bawa ke tong fermentasi di winery.'):format(r.label), 'success')
            panduan('SetStep', 'wine', 5)
        elseif r and r.msg then
            notify(r.msg, 'error')
        end
    else
        TriggerServerEvent('f_wine:server:batalInjak')
    end
    injak = false
    busy = false
    if kerja then bawaKeranjang() end
end

exports.ox_target:addModel(MODEL_TONG, {
    {
        name = 'f_wine_injak', label = 'Tuang & injak anggur', icon = 'fa-solid fa-shoe-prints', distance = config.jarak.injak,
        canInteract = function(entity)
            return kerja and not busy and not injak and keranjang.state == 'bawa' and keranjang.n >= config.keranjangMax and posDariTong(entity) ~= nil
        end,
        onSelect = function(data) mulaiInjak(data.entity) end,
    },
})

---------------------------------------------------------------------------
-- NPC Mandor + tong fermentasi di winery
---------------------------------------------------------------------------
local mandorPed, tongFerm = nil, {}

local function bukaNui(action, data)
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = action, data = data })
end

local function infoJenis()
    local out = {}
    for _, key in ipairs(config.urutan) do
        local j = config.jenis[key]
        out[#out + 1] = { key = key, label = j.label, anggur = j.anggur, blok = j.blok, warna = j.warna, harga = j.harga,
                          jus = exports.ox_inventory:Items(j.jus) and exports.ox_inventory:Items(j.jus).label or j.jus }
    end
    return out
end

local function bukaMandor()
    local d = lib.callback.await('f_wine:server:menu', false)
    if not d then return end
    d.jenis = infoJenis()
    d.max = config.keranjangMax
    d.baju = kerja and pakaiBajuKerja()
    d.pegang = pegang ~= nil
    d.fermentasiMenit = config.fermentasiMenit
    bukaNui('mandor', d)
end

local function bukaTong()
    local d = lib.callback.await('f_wine:server:tong', false)
    if not d then return end
    d.jenis = infoJenis()
    d.maxJus = config.jusPerTong
    d.botolPerJus = config.botolPerJus
    d.fermentasiMenit = config.fermentasiMenit
    bukaNui('tong', d)
end

lib.points.new({
    coords = config.lokasi.mandor.xyz, distance = 60.0,
    onEnter = function()
        local c = config.lokasi.mandor
        lib.requestModel(cfg.mandorPed)
        mandorPed = CreatePed(4, cfg.mandorPed, c.x, c.y, groundZ(c, c.z), c.w, false, false)
        SetModelAsNoLongerNeeded(cfg.mandorPed)
        FreezeEntityPosition(mandorPed, true)
        SetEntityInvincible(mandorPed, true)
        SetBlockingOfNonTemporaryEvents(mandorPed, true)
        TaskStartScenarioInPlace(mandorPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        exports.ox_target:addLocalEntity(mandorPed, {
            { name = 'f_wine_mandor', label = 'Bicara dengan Mandor Kebun', icon = 'fa-solid fa-wine-bottle', distance = config.jarak.mandor, onSelect = bukaMandor },
        })
        for i, t in ipairs(config.lokasi.fermentasi) do
            local o = spawnObj(cfg.tongFermentasi, t.x, t.y, groundZ(t, t.z) + 0.5)
            SetEntityHeading(o, t.w + 0.0)
            PlaceObjectOnGroundProperly(o)
            FreezeEntityPosition(o, true)
            exports.ox_target:addLocalEntity(o, {
                { name = 'f_wine_tong', label = 'Tong Fermentasi', icon = 'fa-solid fa-wine-glass', distance = config.jarak.fermentasi, onSelect = bukaTong },
            })
            tongFerm[i] = o
        end
    end,
    onExit = function()
        if mandorPed then exports.ox_target:removeLocalEntity(mandorPed) end
        hapus(mandorPed)
        mandorPed = nil
        for i, o in pairs(tongFerm) do
            exports.ox_target:removeLocalEntity(o)
            hapus(o)
            tongFerm[i] = nil
        end
    end,
})

---------------------------------------------------------------------------
-- mulai / selesai kerja
---------------------------------------------------------------------------
local function mulai()
    local res = lib.callback.await('f_wine:server:mulai', false)
    if not res or not res.ok then return res or { ok = false } end
    kerja = true
    tumbuh = {}
    local now = GetGameTimer()
    for k, sisa in pairs(res.dipetik or {}) do tumbuh[k] = now + sisa * 1000 end
    keranjang.n, keranjang.jenis = 0, nil
    pakaiBaju()
    bawaKeranjang()
    loopTandan()
    notify('Selamat bekerja! Pilih blok kebun, taruh keranjang dengan [G], lalu petik tandan anggur.', 'success')
    panduan('Start', 'wine')
    return { ok = true }
end

local function bersihkan()
    kerja = false
    hapusSemuaTandan()
    if pegang then hapus(pegang.obj) pegang = nil end
    hapusIsi()
    hapus(keranjang.obj)
    keranjang = { state = nil, obj = nil, n = 0, jenis = nil, isi = {} }
    lib.hideTextUI()
end

local function selesai()
    lib.callback.await('f_wine:server:selesai', false)
    bersihkan()
    lepasBaju()
    panduan('Stop', 'wine')
    notify('Kamu selesai bekerja di kebun anggur.', 'inform')
    return { ok = true }
end

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
local function tutupNui()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'tutup' })
end

RegisterNUICallback('tutup', function(_, cb) tutupNui() cb({}) end)

RegisterNUICallback('mulai', function(_, cb)
    local r = mulai()
    cb(r)
    if r.ok then tutupNui() end
end)

RegisterNUICallback('selesai', function(_, cb)
    cb(selesai())
    tutupNui()
end)

RegisterNUICallback('baju', function(_, cb)
    if kerja then pakaiBaju() end
    cb({ ok = true })
    tutupNui()
end)

RegisterNUICallback('waypoint', function(data, cb)
    local c = blokTengah[data and data.jenis]
    if c then
        SetNewWaypoint(c.x, c.y)
        notify(('Rute ke %s dipasang di peta.'):format(config.jenis[data.jenis].blok), 'inform')
    end
    cb({ ok = c ~= nil })
end)

RegisterNUICallback('tuang', function(data, cb)
    local r = lib.callback.await('f_wine:server:tuang', false, tonumber(data.i), data.jenis, tonumber(data.n))
    cb(r or { ok = false })
end)

RegisterNUICallback('botolkan', function(data, cb)
    local r = lib.callback.await('f_wine:server:botolkan', false, tonumber(data.i))
    if r and r.ok then notify(('Kamu mendapat %d botol %s.'):format(r.jumlah, r.label), 'success') end
    cb(r or { ok = false })
end)

RegisterNUICallback('refreshTong', function(_, cb)
    cb(lib.callback.await('f_wine:server:tong', false) or { tong = {}, jus = {} })
end)

---------------------------------------------------------------------------
-- admin: /winepos (salin vec4, z = kaki) + /wineoffset (debug)
---------------------------------------------------------------------------
RegisterNetEvent('f_wine:client:pos', function()
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    local z = c.z - GetEntityHeightAboveGround(ped)
    local s = ('vec4(%.2f, %.2f, %.2f, %.1f)'):format(c.x, c.y, z, GetEntityHeading(ped))
    lib.setClipboard(s)
    notify('Disalin: ' .. s, 'success')
end)

if config.debug then
    -- /wineoffset <keranjang|tangan|injak> x y z [rx ry rz] : berlaku langsung / di aksi berikutnya
    RegisterCommand('wineoffset', function(_, a)
        local n = function(i, d) return tonumber(a[i]) or d end
        if a[1] == 'injak' then
            cfg.pasang.injakZ = n(2, cfg.pasang.injakZ)
            return notify(('injakZ = %.2f'):format(cfg.pasang.injakZ))
        end
        local t = a[1] == 'keranjang' and cfg.pasang.keranjangBawa or a[1] == 'tangan' and cfg.pasang.tandanTangan
        if not t then return notify('/wineoffset keranjang|tangan|injak x y z rx ry rz', 'error') end
        t.pos = vec3(n(2, t.pos.x), n(3, t.pos.y), n(4, t.pos.z))
        t.rot = vec3(n(5, t.rot.x), n(6, t.rot.y), n(7, t.rot.z))
        if a[1] == 'keranjang' and keranjang.state == 'bawa' then bawaKeranjang() end
        if a[1] == 'tangan' and pegang then
            local j = pegang.jenis
            hapus(pegang.obj)
            pegangTandan(j)
        end
        notify(('%s pos %.2f %.2f %.2f rot %.0f %.0f %.0f'):format(a[1], t.pos.x, t.pos.y, t.pos.z, t.rot.x, t.rot.y, t.rot.z))
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= cache.resource then return end
    if injak then DetachEntity(cache.ped, true, false) ClearPedTasks(cache.ped) end
    if nuiOpen then SetNuiFocus(false, false) end
    if kerja then
        bersihkan()
        lepasBaju()
        panduan('Stop', 'wine')
    end
    for _, o in pairs(tubObj) do hapus(o) end
    for _, o in pairs(tongFerm) do hapus(o) end
    hapus(mandorPed)
end)
