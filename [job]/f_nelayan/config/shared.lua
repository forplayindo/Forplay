-- KALIBRASI di game: /nelayanpos (salin vec4 posisi + arah hadap), /nelayandek (salin offset relatif kapal/bison).
-- Titik awal di dermaga LSYMC Puerto Del Sol (koordinat laut dari garasi kapal f_garages), geser sesukamu.
return {
    boatModel = 'tug',
    truckModel = 'bison',
    platePrefix = 'IKN',

    -- Syahbandar: menu Kerja Nelayan
    office = {
        label = 'Syahbandar Dermaga',
        coords = vec4(-775.15, -1496.11, 1.48, 344.79),
        model = `s_m_m_dockwork_01`,
    },
    boatSpawn = vec4(-793.58, -1501.4, 0.12, 111.5),   -- tug muncul di sini (air)
    dock = vec3(-793.58, -1501.4, 0.0),                -- kapal disandarkan di sekitar sini untuk bongkar peti
    dockRadius = 45.0,                                 -- tug sedekat ini ke dock = "bersandar" (naik/turun kapal, bongkar peti)
    boardPoint = vec4(-776.5, -1497.5, 1.5, 100.0),    -- turun dari kapal muncul di sini (dermaga dekat Syahbandar)
    pier = vec4(-761.49, -1489.87, 4.0, 219.76),          -- tumpukan peti ikan di dermaga setelah dibongkar
    -- bison muncul saat peti dibongkar: 1 per anggota, berjajar ke kanan dari titik ini (arah hadap = w)
    truckSpawn = vec4(-761.08, -1482.04, 4.0, 6.63),
    truckSpacing = 3.5,

    -- Pasar Ikan (sementara di area dermaga)
    market = {
        label = 'Pasar Ikan',
        coords = vec4(-722.53, -1413.95, 4.0, 307.05),
        model = `s_m_m_linecook`,
    },

    -- spot ikan di laut lepas (barat Vespucci / Del Perro); far = bonus harga
    spots = {
        { label = 'Perairan Vespucci', coords = vec3(-2000.0, -1500.0, 0.0), far = false },
        { label = 'Perairan Del Perro', coords = vec3(-2100.0, -1150.0, 0.0), far = false },
        { label = 'Perairan Bandara', coords = vec3(-1950.0, -1850.0, 0.0), far = false },
        { label = 'Laut Lepas Barat', coords = vec3(-2700.0, -1400.0, 0.0), far = true },
        { label = 'Laut Lepas Barat Daya', coords = vec3(-2600.0, -2100.0, 0.0), far = true },
        { label = 'Laut Lepas Pacific Bluffs', coords = vec3(-2900.0, -900.0, 0.0), far = true },
    },
    spotRadius = 150.0,

    -- kru: dek tug muat 8 peti x jumlah anggota (1 orang 8, 4 orang 32). 1 jaring isi ikan = 1 peti.
    -- Peti di dermaga dibagi rata ke anggota; tiap anggota memuat bagiannya ke bison sendiri (maks 8).
    maxCrew = 4,
    cratesPerPlayer = 8,
    bedCapacity = 8,

    -- jaring = item ox_inventory, dibeli di Syahbandar, rusak setelah netUses kali tebar
    netItem = 'jaring_ikan',
    netPrice = 15000,   -- 5 tebar per jaring -> ±2 jaring per orang per trip 8 peti
    netUses = 5,

    models = {
        netHand = `f_nelayan_jaring_tangan`,
        netThrow = `f_nelayan_jaring_lempar`,
        netSea = `f_nelayan_jaring_laut`,
        netFish = `f_nelayan_jaring_ikan`,
        crateFull = `f_nelayan_peti_ikan`,
        crateEmpty = `f_nelayan_peti_kosong`,
        shoal = `p_shoalfish_s`,
    },
}
