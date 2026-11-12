return {
    -- Gerbang tol di satu jalur (Great Ocean Hwy), urut dari selatan (kota) ke utara (Paleto).
    -- Map di f_assets/stream/tol: border1.ymap = Great Ocean, border2.ymap = Zancudo, border3.ymap = Paleto
    -- (Zancudo & Paleto = salinan border1; nama file dipakai ulang karena sudah terdaftar di _manifestgranicanteam.ymf).
    -- coords = titik tengah gerbang (jarak muat palang & arah jalur). Kalau gerbang digeser di CodeWalker, ubah juga di sini.
    -- Lajur, palang, & loket NPC diatur di game: /tolatur. Label boleh diganti.
    gates = {
        border1 = { label = 'GT Great Ocean', coords = vec3(-3006.9, 1462.7, 25.7) },
        zancudo = { label = 'GT Zancudo',     coords = vec3(-2265.7, 2268.7, 31.7) },
        paleto  = { label = 'GT Paleto',      coords = vec3(-929.6, 5418.4, 36.7) },
    },
    gateOrder = { 'border1', 'zancudo', 'paleto' },

    -- Tarif rute (dua arah sama). Lewat gerbang tengah = bayar sebagian; di gerbang akhir dipotong sisanya,
    -- jadi total tetap sesuai tabel (mis. Great Ocean > Zancudo 7.500, lalu Zancudo > Paleto 7.500 = 15.000).
    fare = {
        routes = {
            ['border1:zancudo'] = 7500,
            ['border1:paleto'] = 15000,
            ['zancudo:paleto'] = 10000,
        },
        tripTimeout = 7200, -- detik; catatan masuk lebih lama dari ini dibuang tanpa potongan
    },

    card = {
        item = 'etoll_card',
        price = 10000,          -- harga kartu baru (saldo 0)
        maxBalance = 2000000,   -- saldo maksimal per kartu
        minTopup = 10000,
        topups = { 20000, 50000, 100000, 200000 },
        -- saldo minimal saat masuk = tarif termahal dari gerbang itu (dihitung otomatis)
    },

    -- Uang tarif & penjualan kartu masuk rekening ini (f_banking). nil = tidak ke mana-mana.
    revenueAccount = 'government',

    barrier = {
        base = 'prop_sec_barier_base_01', -- tiang dasar (false = tanpa tiang)
        arm = 'prop_sec_barrier_ld_02a',  -- lengan saja (engsel di titik 0, panjang 4.9 m + pemberat 0.7 m)
        armOffset = vec3(0.0, 0.0, 1.0),  -- posisi engsel lengan dari tiang (atur live: /tolarm x y z)
        openAngle = 82.0,
        invert = false,                   -- true kalau lengan malah turun ke aspal saat dibuka
        animTime = 1200,                  -- ms
        blocker = 'prop_barier_conc_02a', -- penahan tak terlihat di bawah lengan selama palang utuh
        showBlockers = false,             -- true = penahan terlihat (debug)
        spawnDistance = 150.0,            -- palang dimuat kalau pemain sedekat ini ke gerbang
        npcOpenTime = 8000,               -- palang buka sendiri untuk mobil NPC (lokal saja)
    },

    tap = {
        distance = 3.5,     -- jarak mobil ke titik tap
        maxAngle = 50.0,    -- selisih arah mobil vs arah lajur
        openTime = 20,      -- detik palang menunggu mobil lewat setelah tap
    },

    hits = {
        speed = 15.0,       -- km/h minimal supaya tabrakan dihitung
        breakAt = 3,        -- palang patah di tabrakan ke-3
        resetAfter = 120,   -- detik tanpa tabrakan -> hitungan kembali 0
        restoreAfter = 30,  -- detik palang patah pulih sendiri
    },

    -- Deteksi lewat gerbang (server): kotak di sekitar lajur
    zone = { halfWidth = 2.4, length = 14.0, height = 6.0 },

    trafficLights = true,   -- lampu prop_traffic_03a di dekat palang: merah saat tutup, hijau saat buka
    trafficLightModel = `prop_traffic_03a`,

    dispatch = {
        jobType = 'leo',
        cooldown = 60,      -- detik, per pemain per gerbang
        blip = { sprite = 225, color = 1, scale = 1.0, duration = 120 },
    },

    hologram = { duration = 6000 },

    loket = {
        ped = `s_m_m_security_01`,
        distance = 1.8,
    },

    -- Minimarket (sama dengan toko General ox_inventory): [E] E-Toll untuk beli kartu & isi saldo
    minimarkets = {
        vec3(25.7, -1347.3, 29.49),
        vec3(-3038.71, 585.9, 7.9),
        vec3(-3241.47, 1001.14, 12.83),
        vec3(1728.66, 6414.16, 35.03),
        vec3(1697.99, 4924.4, 42.06),
        vec3(1961.48, 3739.96, 32.34),
        vec3(547.79, 2671.79, 42.15),
        vec3(2679.25, 3280.12, 55.24),
        vec3(2557.94, 382.05, 108.62),
        vec3(373.55, 325.56, 103.56),
    },
    minimarketDistance = 1.5,

    editor = {
        maxLanesPerGate = 12,
        maxDistance = 120.0, -- titik tap harus sedekat ini ke tengah gerbang
    },
}
