-- Dibaca client & server.
return {
    job = 'mechanic',      -- nama job (rekening organisasi, invoice f_phone)
    jobType = 'mechanic',  -- job.type yang dianggap mekanik

    -- Di mana bagian berat (heavy) boleh diperbaiki:
    --  'anywhere' = di mana saja (lift hanya untuk kenyamanan / RP)
    --  'workshop' = di area bengkel (lihat `workshop`) atau di atas lift
    --  'lift'     = hanya di atas lift yang sedang naik
    heavyRepair = 'anywhere',
    workshop = { center = vec3(-338.0, -1355.0, 30.4), radius = 45.0 },

    -- bagian bawah kendaraan: mobil WAJIB di atas lift yang sedang naik (motor tidak). Animasi tangan ke atas.
    liftParts = { brakes = true, axle = true, suspension = true, clutch = true, transfluid = true },

    -- bagian di ruang mesin: mekanik harus berdiri di depan kendaraan dengan kap terbuka (mobil saja)
    hoodParts = { engine = true, radiator = true, airfilter = true, sparkplugs = true, oil = true, coolant = true, brakefluid = true },

    distance = 3.0,        -- jarak ox_target "Periksa Kendaraan"
    closeDistance = 6.0,   -- jarak maksimal mekanik <-> kendaraan selama panel terbuka / perbaikan

    -- Bagian kendaraan. native = nilai bawaan GTA (0-1000), lainnya angka 0-100 yang disimpan script.
    -- heavy = bagian berat, lokasinya diatur `heavyRepair`.
    -- fluid = diisi ulang (label tombol "Isi Ulang"). service = kode harga di config/server.lua billing.
    parts = {
        oil        = { label = 'Oli Mesin',     item = 'engine_oil',  qty = 1, fluid = true, duration = 8000,  service = 'oil',
                       fx = { 'Normal', 'Oli mulai kotor', 'Oli kurang, mesin cepat aus', 'Oli habis, mesin bisa rusak berat' } },
        coolant    = { label = 'Coolant',       item = 'coolant',     qty = 1, fluid = true, duration = 8000,  service = 'coolant',
                       fx = { 'Normal', 'Coolant berkurang', 'Mesin cepat panas', 'Mesin overheat' } },
        brakefluid = { label = 'Minyak Rem',    item = 'brake_fluid', qty = 1, fluid = true, duration = 8000,  service = 'brakefluid',
                       fx = { 'Normal', 'Rem sedikit dalam', 'Rem terasa lembek', 'Rem hampir tidak berfungsi' } },
        transfluid = { label = 'Oli Transmisi', item = 'trans_fluid', qty = 1, fluid = true, duration = 8000,  service = 'transfluid',
                       fx = { 'Normal', 'Perpindahan gigi agak kasar', 'Gigi sering telat masuk', 'Transmisi bisa selip' } },

        engine     = { label = 'Mesin',         item = 'metalscrap',  qty = 2, heavy = true, native = 'engine', duration = 15000, service = 'engine',
                       fx = { 'Normal', 'Tenaga sedikit turun', 'Tenaga turun, asap tipis', 'Bisa mogok kapan saja' } },
        sparkplugs = { label = 'Busi',          item = 'spark_plug',  qty = 1, duration = 8000,  service = 'sparkplugs',
                       fx = { 'Normal', 'Kadang tersendat', 'Mesin sering tersendat', 'Susah hidup, tenaga drop' } },
        airfilter  = { label = 'Filter Udara',  item = 'air_filter',  qty = 1, duration = 6000,  service = 'airfilter',
                       fx = { 'Normal', 'Tenaga sedikit turun', 'Tenaga turun, boros bensin', 'Tenaga turun jauh, sangat boros' } },
        radiator   = { label = 'Radiator',      item = 'steel',       qty = 5, heavy = true, duration = 12000, service = 'radiator',
                       fx = { 'Normal', 'Mesin cepat panas', 'Coolant bocor', 'Coolant bocor deras' } },
        clutch     = { label = 'Kopling',       item = 'copper',      qty = 6, heavy = true, duration = 12000, service = 'clutch',
                       fx = { 'Normal', 'Kadang mesin mati sesaat', 'Sering mati sesaat', 'Mesin mati-mati terus' } },
        axle       = { label = 'As Roda',       bikeLabel = 'Rantai & As', item = 'aluminum', qty = 7, heavy = true, duration = 12000, service = 'axle',
                       fx = { 'Normal', 'Setir sedikit goyang', 'Setir tidak stabil', 'Setir sangat sulit dikendalikan' } },
        suspension = { label = 'Suspensi',      item = 'steel',       qty = 4, heavy = true, duration = 12000, service = 'suspension',
                       fx = { 'Normal', 'Sedikit limbung', 'Limbung & memantul', 'Sangat limbung, sulit dikendalikan' } },
        brakes     = { label = 'Rem',           item = 'copper',      qty = 5, duration = 10000, service = 'brakes',
                       fx = { 'Normal', 'Daya rem sedikit turun', 'Rem lemah', 'Rem sangat lemah, menarik ke samping' } },
        body       = { label = 'Body',          item = 'plastic',     qty = 3, native = 'body', duration = 12000, service = 'body',
                       fx = { 'Mulus', 'Lecet & penyok kecil', 'Penyok, kaca retak', 'Rusak berat, lampu/kaca pecah' } },
        tank       = { label = 'Tangki Bensin', item = 'plastic',     qty = 5, heavy = true, native = 'tank', duration = 10000, service = 'tank',
                       fx = { 'Normal', 'Tangki tergores', 'Bensin bocor', 'Bensin bocor deras' } },
    },

    -- urutan grup di daftar panel
    groups = {
        { 'Mesin & Penggerak', { 'engine', 'sparkplugs', 'airfilter', 'radiator', 'clutch', 'axle' } },
        { 'Kaki-kaki', { 'suspension', 'brakes', 'TYRES' } },
        { 'Bodi & Tangki', { 'body', 'tank' } },
        { 'Cairan', { 'oil', 'coolant', 'brakefluid', 'transfluid' } },
    },
    fluids = { 'oil', 'coolant', 'brakefluid', 'transfluid' },
    -- bagian yang disimpan script (selain native & ban)
    custom = { 'oil', 'coolant', 'brakefluid', 'transfluid', 'sparkplugs', 'airfilter', 'radiator', 'clutch', 'axle', 'suspension', 'brakes' },

    -- Ban. index = wheel id GTA (dipakai IsVehicleTyreBurst / SetVehicleTyreFixed).
    tyre = { item = 'tirekit', qty = 1, duration = 8000, service = 'tyre', fx = { 'Normal', 'Grip sedikit berkurang', 'Mudah selip saat menikung', 'Gundul, rawan bocor sendiri' } },
    tyres = {
        car  = { { key = 'FL', label = 'Ban depan kiri', index = 0 }, { key = 'FR', label = 'Ban depan kanan', index = 1 },
                 { key = 'RL', label = 'Ban belakang kiri', index = 4 }, { key = 'RR', label = 'Ban belakang kanan', index = 5 } },
        bike = { { key = 'F', label = 'Ban depan', index = 0 }, { key = 'R', label = 'Ban belakang', index = 4 } },
    },

    -- tingkat kondisi: >= 80 Baik, >= 50 Aus, >= 20 Rusak, < 20 Parah. Di bawah `needs` dianggap rusak.
    levels = { 80, 50, 20 },
    levelLabels = { 'Baik', 'Aus', 'Rusak', 'Parah' },
    needs = 80,

    -- jenis kendaraan (GetVehicleType server) yang bisa diperiksa
    vehicleTypes = { automobile = 'car', quadbike = 'car', bike = 'bike' },

    -- label item (panel & notifikasi)
    itemLabels = {
        metalscrap = 'Metal Scrap', plastic = 'Plastic', steel = 'Steel', aluminum = 'Aluminum', copper = 'Copper',
        tirekit = 'Tire Kit', engine_oil = 'Engine Oil', coolant = 'Coolant', brake_fluid = 'Brake Fluid',
        trans_fluid = 'Transmission Fluid', spark_plug = 'Spark Plugs', air_filter = 'Air Filter',
    },
    itemIcons = {
        metalscrap = '🔩', plastic = '🧴', steel = '🔗', aluminum = '🥫', copper = '🟠', tirekit = '⭕',
        engine_oil = '🛢️', coolant = '💧', brake_fluid = '🧪', trans_fluid = '⚙️', spark_plug = '⚡', air_filter = '🌀',
    },

    -- Lift bengkel nteam (platform nteam_mechanic_carlift). Koordinat dibaca dari file map.
    lift = {
        model = 'nteam_mechanic_carlift',
        height = 1.8,            -- meter naik
        duration = 6000,         -- ms naik / turun
        radius = 2.4,            -- kendaraan harus berada sedekat ini dari titik tengah platform
        animatePlatform = true,  -- false = platform map tetap diam, hanya kendaraan yang naik
        lifts = {
            { coords = vec4(-348.21, -1367.92, 30.95, 180.0), panel = vec3(-350.36, -1369.44, 30.36) },
            { coords = vec4(-340.58, -1367.92, 30.95, 180.0), panel = vec3(-342.69, -1369.44, 30.36) },
            { coords = vec4(-332.92, -1367.92, 30.95, 180.0), panel = vec3(-335.02, -1369.44, 30.36) },
        },
    },

    -- Titik bengkel (SEMENTARA, atur ulang dengan /vec3 di map nteam)
    locations = {
        blip = vec3(-338.0, -1355.0, 30.4),
        duty = vec3(-328.20, -1337.40, 30.35),
        stash = vec3(-349.78, -1327.88, 30.46),
        garage = vec3(-360.0, -1372.0, 30.4),           -- titik ambil / kembalikan kendaraan kerja
        garageSpawn = vec4(-362.0, -1378.0, 30.4, 90.0), -- tempat kendaraan kerja muncul
    },

    -- Kasir bengkel (SEMENTARA, atur dengan /vec3): warga membayar tagihan "Bayar di Kasir" & kustom,
    -- mekanik membuka Menu Kasir (daftar belum bayar + Master Harga). Pembayar harus dalam `distance`.
    cashier = { coords = vec3(-327.51, -1336.86, 30.46), radius = 0.8, distance = 3.0 },

    -- Pasang kustom dari tab Kustom (ms per tahap). Kendaraan harus di zona f_customs dengan jenis yang
    -- sama dengan order (cat = booth cat, modifikasi = lift) dan tanpa pengemudi. Total = jumlah tahap.
    customInstall = {
        paintSide = 6000,  -- cat: per sisi (depan, kiri, belakang, kanan)
        perf = 8000,       -- modifikasi performa / ruang mesin (kap dibuka)
        wheel = 3500,      -- velg / ban / asap ban: per roda
        body = 8000,       -- bodi, warna lain, lampu, kaca film, dll. (las)
        interior = 6000,   -- interior (pintu pengemudi dibuka)
    },

    -- kendaraan kerja
    jobVehicles = {
        { model = 'flatbed', label = 'Flatbed' },
        { model = 'towtruck', label = 'Towtruck' },
        { model = 'minivan', label = 'Minivan' },
    },

    stash = { id = 'mechanicstash', label = 'Gudang Bengkel', slots = 200, weight = 2000000 }, -- TIDAK DIPAKAI: stash dikelola f_stash (/stash)
}
