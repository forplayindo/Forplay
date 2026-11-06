return {
    treeDistance = 120.0,       -- prop pohon dibuat saat sedekat ini
    itemDistance = 120.0,       -- prop kayu di tanah (batang / potongan) dibuat saat sedekat ini
    truckDistance = 120.0,      -- isi bak truk kru dibuat saat sedekat ini
    soundDistance = 60.0,       -- suara chainsaw / pohon tumbang / conveyor terdengar sampai sejauh ini
    volume = 0.5,

    -- menebang & memotong batang (animasi & prop chainsaw dari 17mov)
    cutAnim = { dict = 'weapons@heavy@minigun', clip = 'fire_med' },
    chainsaw = { model = `17mov_chainsaw`, bone = 57005, pos = vec3(0.3, 0.18, -0.1), rot = vec3(-52.0, 20.0, 65.0) },
    fallMs = 4800,              -- lama pohon tumbang

    -- truk Biff (KALIBRASI pakai /kayutes)
    -- isi bak 1:1 dengan yang dimuat. layers = jumlah batang per lapis dari bawah, tiap lapis di tengah
    -- (lapis lebih sedikit duduk di celah lapis bawahnya). grid = ukuran slot pakai prop piece / trunk,
    -- unit = potongan per slot (Biff 1 potong, flatbed 1 batang besar = 3; potongan di flatbed: 1 prop per 3 potong).
    -- squeeze < 1 merapatkan (kotak ukuran prop lebih besar dari batangnya)
    truck = {
        rearRadius = 2.5,       -- [E] Masukkan ke bak muncul sedekat ini dari ujung belakang truk
        plankModel = `prop_woodpile_02a`,   -- tumpukan papan (di bawah mesin sawmill & di bak)
        solo = {                -- Biff: 18 batang kecil (6 pohon)
            extrasOff = { 1, 11, 12 },  -- muatan pasir yang dimatikan
            grid = 'piece', unit = 1,
            bed = { origin = vec3(0.00, -1.30, 0.55), layers = { 4, 4, 4, 3, 3 }, squeeze = 0.9, yaw = 0.0 },
            -- papan hasil sawmill di bak (tampilan saja): count tumpukan berbaris ke belakang, yaw -90 = putar 90° kanan dari /kayutes
            planks = { origin = vec3(0.00, -1.30, 0.30), count = 1, yaw = 0.0 },
        },
        crew = {                -- 17mov_flatbed: 9 batang besar (9 pohon)
            extrasOff = {},
            grid = 'trunk', unit = 3,
            bed = { origin = vec3(0.00, -4.10, 0.80), layers = { 3, 3, 3 }, squeeze = 0.9, yaw = 0.0 },
            planks = { origin = vec3(0.00, -1.60, 0.40), count = 2, yaw = 0.0 },
        },
    },

    -- memanggul (KALIBRASI di game)
    carry = {
        -- batang kecil dipanggul di bahu kanan (pose carry orang di bahu), memanjang depan-belakang.
        -- pos dari titik tengah pemain: x kanan, y depan, z atas; rot.z ditambah otomatis supaya sisi panjang searah badan
        pieceAnim = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman' },
        piece = { bone = 0, pos = vec3(0.24, -0.3, 0.72), rot = vec3(0.0, 0.0, 0.0) },
        trunkAnim = { dict = 'missfbi4prepp1', clip = 'idle' },                             -- batang di bahu kanan
        trunk = { frontEnd = vec3(0.25, 0.6, 0.55) },   -- ujung depan batang besar dari pemain depan, memanjang ke belakang
        backGap = 1.2,          -- pemain belakang sejauh ini dari ujung belakang batang (ke arah dalam)
    },

    -- animasi tumbang: berputar di titik potong, berhenti setinggi jari-jari batang di atas tanah, kemiringan diukur sejauh probe
    fallen = { radius = 0.35, probe = 15.0 },

    -- conveyor sawmill (jalur batang dari 17mov), batang lewat satu per satu
    conveyor = {
        { pos = vec3(-495.28, 5346.84, 80.76), rot = vec3(0.0, 0.0, -20.0) },
        { pos = vec3(-499.27, 5348.30, 80.47), rot = vec3(0.0, 0.0, -20.0), ptfx = true },
        { pos = vec3(-504.43, 5350.17, 77.15), rot = vec3(0.0, 0.0, -20.0), ptfx = true },
        { pos = vec3(-546.57, 5365.51, 73.12), rot = vec3(0.0, 0.0, -20.0) },
        { pos = vec3(-547.57, 5365.88, 71.33), rot = vec3(0.0, 0.0, -20.0), ptfx = true },
    },
    sawmillCenter = vec3(-520.0, 5355.0, 76.0),
    pileDistance = 120.0,       -- tumpukan papan di sawmill dibuat saat sedekat ini

    -- seragam penebang (format qb-clothing; nilai dari 17mov, silakan ganti)
    outfit = {
        male = {
            ['t-shirt'] = { item = 59, texture = 1 },
            ['torso2'] = { item = 118, texture = 2 },
            ['arms'] = { item = 6, texture = 0 },
            ['pants'] = { item = 9, texture = 0 },
            ['shoes'] = { item = 25, texture = 0 },
        },
        female = {
            ['t-shirt'] = { item = 15, texture = 0 },
            ['torso2'] = { item = 109, texture = 2 },
            ['arms'] = { item = 6, texture = 0 },
            ['pants'] = { item = 30, texture = 0 },
            ['shoes'] = { item = 24, texture = 0 },
        },
    },
}
