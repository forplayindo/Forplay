-- /kayutes (admin): uji Biff tanpa pasir + pilih prop potongan kayu untuk bak & tanah
-- file sementara: hapus dari fxmanifest setelah ukuran dipilih
local CANDIDATES = {
    'prop_log_02', 'prop_log_03', 'prop_log_01',
    'prop_log_aa', 'prop_log_ab', 'prop_log_ac', 'prop_log_ad', 'prop_log_ae', 'prop_log_af',
    'prop_tree_log_01', 'prop_tree_log_02', 'prop_woodpile_04a',
}
-- [Y] mode papan: kandidat tumpukan papan hasil sawmill (yang tidak ada di game dilewati)
local PLANKS = {
    -- bawaan GTA dulu (nama yang tidak ada di game otomatis dilewati); pilihan: prop_woodpile_02a
    'prop_woodpile_02a', 'prop_woodpile_01a', 'prop_woodpile_01b', 'prop_woodpile_01c', 'prop_woodpile_02b',
    'prop_woodpile_03a', 'prop_woodpile_03b', 'prop_woodpile_04b',
    'prop_byard_planks01', 'prop_byard_planks02', 'prop_cons_plank', 'prop_cons_ply01', 'prop_cons_ply02',
    'prop_cons_plyboard_01', 'prop_boards_01', 'prop_planks_01', 'prop_plank_01', 'prop_wood_planks',
    'prop_pallet_pile_01', 'prop_pallet_pile_02', 'prop_pallet_02a', 'prop_pallet_03a',
    '17mov_woodpile',   -- 17mov (terlalu panjang)
}

local function available(list)
    local out = {}
    for _, name in ipairs(list) do
        if IsModelInCdimage(joaat(name)) then out[#out + 1] = name end
    end
    return out
end

local active = false

local function obj(model, at)
    lib.requestModel(model, 5000)
    local o = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    return o
end

-- truk uji: Biff (solo) / 17mov_flatbed (kru, dari f_carjob) — ukuran bak kira-kira untuk hitung kolom & baris
local TRUCKS = {
    biff = { model = `biff`, bedW = 2.0, bedL = 4.0, origin = nil },
    flatbed = { model = `17mov_flatbed`, bedW = 2.4, bedL = 7.0, origin = nil },
}

RegisterNetEvent('f_lumberjack:client:kayutes', function(kind)
    if active then return end
    local truck = TRUCKS[kind] or TRUCKS.biff
    if not IsModelInCdimage(truck.model) then
        return FLJ.notify('Model truk tidak ditemukan (cek f_carjob sudah di-ensure).', 'error')
    end
    active = true

    local logModels, plankModels = available(CANDIDATES), available(PLANKS)
    local models = logModels
    local plankMode = false
    if #models == 0 then
        active = false
        return FLJ.notify('Tidak ada kandidat prop kayu yang ditemukan.', 'error')
    end

    -- truk di depan pemain, bak menghadap pemain
    local model = truck.model
    lib.requestModel(model, 10000)
    local spawn = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 8.0, 0.0)
    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, GetEntityHeading(cache.ped), false, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDoorsLocked(veh, 2)

    local extras = {}
    for i = 0, 20 do
        if DoesExtraExist(veh, i) then extras[#extras + 1] = i end
    end

    local exSel, mSel = 1, 1
    local tb = FLJ.config.truck[kind == 'flatbed' and 'crew' or 'solo'].bed
    local yaw = tb.yaw                      -- 0 = memanjang searah truk, 90 = melintang
    local origin = truck.origin or tb.origin    -- titik awal tumpukan di bak (offset dari truk)
    local bedW, bedL = truck.bedW, truck.bedL
    local bed, ground = {}, {}
    local count = 0
    local colsSet               -- nil = otomatis dari lebar bak, angka = diatur manual [Z]/[B]
    local shown

    local function dims()
        local mn, mx = GetModelDimensions(joaat(models[mSel]))
        return mx - mn
    end

    -- ukuran potongan setelah diputar: lebar (X truk), panjang (Y truk), tinggi; lebar & tinggi dirapatkan squeeze config
    local function footprint()
        local a = FLJ.modelAxis(joaat(models[mSel]))
        local sq = plankMode and 1.0 or FLJ.config.truck[kind == 'flatbed' and 'crew' or 'solo'].bed.squeeze or 1.0
        if yaw % 180.0 == 0.0 then return a.width * sq, a.len, a.height * sq end
        return a.len, a.width * sq, a.height * sq
    end

    local function gridSize()
        local w, l = footprint()
        local cols = colsSet or math.max(1, math.floor(bedW / math.max(w, 0.05)))
        if plankMode then return cols, math.max(1, math.ceil(count / cols)) end    -- papan berbaris ke belakang, tidak ditumpuk
        return cols, math.max(1, math.floor(bedL / math.max(l, 0.05)))
    end

    local preview = true        -- [L] bak penuh sesuai config (truck.solo / truck.crew), mati = susun manual [G]
    local tKind = kind == 'flatbed' and 'crew' or 'solo'

    local function layout()
        for _, o in ipairs(bed) do DeleteEntity(o) end
        bed = {}
        if preview then
            local t = FLJ.config.truck[tKind]
            local m = FLJ.models[t.grid]
            local rot = FLJ.modelAxis(m).yaw + t.bed.yaw
            for _, s in ipairs(FLJ.bedSlots(tKind)) do
                local o = obj(m, GetEntityCoords(veh))
                SetEntityCollision(o, false, false)
                AttachEntityToEntity(o, veh, 0, s.x, s.y, s.z, 0.0, 0.0, rot, false, true, false, false, 2, true)
                bed[#bed + 1] = o
            end
            return 0, 0
        end
        local w, l, h = footprint()
        local cols, rows = gridSize()
        local rot = FLJ.modelAxis(joaat(models[mSel])).yaw + yaw
        for i = 0, count - 1 do
            local col = i % cols
            local row = math.floor(i / cols) % rows
            local layer = math.floor(i / (cols * rows))
            local off = vec3(origin.x + (col - (cols - 1) / 2) * w, origin.y - row * l, origin.z + layer * h)
            local o = obj(models[mSel], GetEntityCoords(veh))
            SetEntityCollision(o, false, false)
            AttachEntityToEntity(o, veh, 0, off.x, off.y, off.z, 0.0, 0.0, rot, false, true, false, false, 2, true)
            bed[#bed + 1] = o
        end
        return cols, rows
    end

    local function info()
        local s = dims()
        local cols, rows = layout()
        local ex = extras[exSel]
        local exText = ex and ('%d (%s)'):format(ex, IsVehicleExtraTurnedOn(veh, ex) and 'NYALA' or 'mati') or 'tidak ada'
        local text = table.concat({
            ('**Truk:** %s  |  **Extra:** %s  [%d ada]'):format(kind == 'flatbed' and '17mov_flatbed' or 'Biff', exText, #extras),
            ('**Mode:** %s [Y]  |  **Prop:** %s  (%d/%d)'):format(plankMode and 'PAPAN' or 'batang', models[mSel], mSel, #models),
            ('Ukuran: %.2f x %.2f x %.2f m'):format(s.x, s.y, s.z),
            ('Bak: %d %s (%d kolom%s x %d baris per lapis)'):format(count, plankMode and 'tumpukan' or 'potong', cols, colsSet and ' manual' or '', rows),
            ('Lebar %d kolom: %.2f m'):format(cols, cols * footprint()),
            ('Titik awal: %.1f, %.1f, %.1f  putar %d°'):format(origin.x, origin.y, origin.z, yaw),
            '[←/→] pilih extra  [E] nyala/mati',
            '[↑/↓] ganti prop  [R] putar 90°',
            '[G] +1 ke bak  [X] kosongkan bak  [Z/B] kolom -/+',
            ('[L] lihat bak penuh sesuai config: %s'):format(preview and 'NYALA' or 'mati'),
            '[Shift+↑/↓] geser maju/mundur  [PgUp/PgDn] naik/turun',
            '[H] jatuhkan ke tanah  [C] salin config  [Backspace] selesai',
        }, '  \n')
        if text ~= shown then
            shown = text
            lib.showTextUI(text)
        end
    end

    info()
    CreateThread(function()
        local block = { 7, 10, 11, 20, 21, 23, 29, 38, 45, 47, 73, 74, 75, 172, 173, 174, 175, 177, 199, 200, 202, 246, 26 }
        while active do
            for i = 1, #block do DisableControlAction(0, block[i], true) end
            local shift = IsDisabledControlPressed(0, 21)
            local changed = false

            if IsDisabledControlJustPressed(0, 174) and #extras > 0 then exSel = (exSel - 2) % #extras + 1; changed = true end
            if IsDisabledControlJustPressed(0, 175) and #extras > 0 then exSel = exSel % #extras + 1; changed = true end
            if IsDisabledControlJustPressed(0, 38) and extras[exSel] then
                local ex = extras[exSel]
                SetVehicleExtra(veh, ex, IsVehicleExtraTurnedOn(veh, ex))   -- true = matikan
                changed = true
            end
            if shift then
                if IsDisabledControlJustPressed(0, 172) then origin = origin + vec3(0.0, 0.1, 0.0); changed = true end
                if IsDisabledControlJustPressed(0, 173) then origin = origin - vec3(0.0, 0.1, 0.0); changed = true end
            else
                if IsDisabledControlJustPressed(0, 172) then mSel = mSel % #models + 1; changed = true end
                if IsDisabledControlJustPressed(0, 173) then mSel = (mSel - 2) % #models + 1; changed = true end
            end
            if IsDisabledControlJustPressed(0, 10) then origin = origin + vec3(0.0, 0.0, 0.05); changed = true end
            if IsDisabledControlJustPressed(0, 11) then origin = origin - vec3(0.0, 0.0, 0.05); changed = true end
            if IsDisabledControlJustPressed(0, 45) then yaw = yaw == 0.0 and -90.0 or 0.0; changed = true end
            if IsDisabledControlJustPressed(0, 47) then count = count + 1; changed = true end
            if IsDisabledControlJustPressed(0, 73) then count = 0; changed = true end
            if IsDisabledControlJustPressed(0, 7) then preview = not preview; changed = true end
            -- [Y] ganti mode batang / papan (papan disusun manual: [G] tambah, [Z/B] kolom)
            if IsDisabledControlJustPressed(0, 246) then
                if #plankModels == 0 then
                    FLJ.notify('Tidak ada prop papan yang ditemukan.', 'error')
                else
                    plankMode = not plankMode
                    models = plankMode and plankModels or logModels
                    mSel, colsSet, preview = 1, nil, not plankMode
                    count = 0
                    if plankMode then
                        -- mulai dari papan di config (truck.<solo/crew>.planks), bisa digeser lalu [C]
                        local p = FLJ.config.truck[tKind].planks
                        origin, yaw, count, colsSet = p.origin, p.yaw, p.count, 1
                    else
                        origin, yaw = truck.origin or tb.origin, tb.yaw
                    end
                    changed = true
                end
            end
            if IsDisabledControlJustPressed(0, 20) then colsSet = math.max(1, gridSize() - 1); changed = true end
            if IsDisabledControlJustPressed(0, 29) then colsSet = math.min(6, gridSize() + 1); changed = true end

            -- jatuh dengan fisika, lihat apakah rebah rapi di tanah (tidak ngambang)
            if IsDisabledControlJustPressed(0, 74) then
                local at = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.5, 1.0)
                local o = obj(models[mSel], at)
                SetEntityHeading(o, GetEntityHeading(cache.ped) + 90.0)
                SetEntityDynamic(o, true)
                ActivatePhysics(o)
                ground[#ground + 1] = o
            end

            if IsDisabledControlJustPressed(0, 26) then
                local cols, rows = gridSize()
                local off = {}
                for _, ex in ipairs(extras) do
                    if not IsVehicleExtraTurnedOn(veh, ex) then off[#off + 1] = tostring(ex) end
                end
                local line = ("truk = %s | %s = `%s` | jumlah = %d | extrasOff = { %s } | bed = { origin = vec3(%.2f, %.2f, %.2f), cols = %d, rows = %d, yaw = %.1f }")
                    :format(kind or 'biff', plankMode and 'papan' or 'piece', models[mSel], count, table.concat(off, ', '),
                        origin.x, origin.y, origin.z, cols, rows, yaw)
                lib.setClipboard(line)
                FLJ.notify('Config disalin ke clipboard.', 'success')
            end

            if changed then info() end

            if IsDisabledControlJustPressed(0, 177) or IsEntityDead(cache.ped) or not DoesEntityExist(veh)
                or #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) > 60.0 then
                active = false
            end
            Wait(0)
        end

        lib.hideTextUI()
        for _, o in ipairs(bed) do if DoesEntityExist(o) then DeleteEntity(o) end end
        for _, o in ipairs(ground) do if DoesEntityExist(o) then DeleteEntity(o) end end
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then active = false end
end)
