return {
    maxCrew = 2,

    -- loket Cari Pekerjaan di balai kota (f_cityhall office jobCenter)
    jobCentre = vec3(256.18, -412.04, 46.77),
    jobCentreDistance = 6.0,

    -- KALIBRASI di game: pakai /kurirpos (salin vec4 posisi + arah hadap ke clipboard)
    depot = {
        label = 'Depot GoPostal',
        coords = vec3(78.6, 111.8, 81.2),   -- blip, titik selesai rute & menu lanjut kerja
        finishRadius = 12.0,
        vanSpawns = {
            vec4(66.4, 119.8, 79.1, 160.0),
            vec4(62.0, 121.5, 79.1, 160.0),
        },
        pile = vec4(74.0, 118.0, 79.2, 160.0), -- tumpukan paket (prop lokal) saat fase muat
    },

    -- stops = jumlah titik per zona, big = paket besar (hanya kalau kru 2 orang), bonus = % gaji
    difficulties = {
        { key = 'easy', label = 'Easy', desc = 'Dalam kota, dekat depot', stops = { kota = 6 }, big = 1, bonus = 0 },
        { key = 'medium', label = 'Medium', desc = 'Kota sampai pinggiran', stops = { kota = 4, pinggir = 5 }, big = 2, bonus = 10 },
        { key = 'hard', label = 'Hard', desc = 'Sampai Sandy Shores & Paleto', stops = { kota = 4, sandy = 4, paleto = 4 }, big = 3, bonus = 65 },
    },

    -- titik antar: pintu / toko yang menghadap jalan besar (bukan gang). NPC penerima muncul di sini.
    -- Koordinat diambil dari script lain (toko, bank, rumah) - cek di game, geser kalau kurang pas.
    locations = {
        -- kota (Vinewood, Downtown, Hawick, Burton, Mirror Park)
        { label = 'Toko 24/7 Clinton Avenue', zone = 'kota', coords = vec3(372.57, 326.42, 103.56) },
        { label = 'Fleeca Bank Hawick', zone = 'kota', coords = vec3(314.2, -279.1, 54.17) },
        { label = 'Fleeca Bank Burton', zone = 'kota', coords = vec3(-350.8, -49.6, 49.04) },
        { label = 'Fleeca Bank Legion Square', zone = 'kota', coords = vec3(149.9, -1040.5, 29.37) },
        { label = 'Pillbox Hill Medical Center', zone = 'kota', coords = vec3(298.6, -584.5, 43.26) },
        { label = 'Apartemen Integrity Way', zone = 'kota', coords = vec3(-47.52, -585.86, 37.95) },
        { label = 'Tinsel Towers', zone = 'kota', coords = vec3(-614.58, 46.52, 43.59) },
        { label = 'Rumah Hawick Avenue', zone = 'kota', coords = vec3(69.43, -56.69, 73.02) },
        { label = 'Rumah West Hawick', zone = 'kota', coords = vec3(-102.84, -11.91, 70.52) },
        { label = 'Rumah Burton', zone = 'kota', coords = vec3(-332.97, 57.08, 54.43) },
        { label = 'LTD Mirror Park', zone = 'kota', coords = vec3(1164.7, -322.58, 69.2) },
        { label = 'Rumah Mirror Park Boulevard', zone = 'kota', coords = vec3(1098.57, -464.54, 67.32) },

        -- pinggiran kota
        { label = 'Robs Liquor El Rancho', zone = 'pinggir', coords = vec3(1134.15, -982.53, 46.41) },
        { label = 'Rumah Mirror Park Selatan', zone = 'pinggir', coords = vec3(960.01, -669.94, 58.45) },
        { label = 'Rumah Mirror Park Timur', zone = 'pinggir', coords = vec3(1240.51, -601.62, 69.78) },
        { label = 'Rumah Vinewood Hills', zone = 'pinggir', coords = vec3(-371.74, 343.46, 109.94) },
        { label = 'LTD Richman Glen', zone = 'pinggir', coords = vec3(-1820.17, 794.28, 138.08) },
        { label = 'Robs Liquor Prosperity Street', zone = 'pinggir', coords = vec3(-1486.26, -378.0, 40.16) },
        { label = 'Robs Liquor Vespucci', zone = 'pinggir', coords = vec3(-1222.03, -908.32, 12.32) },
        { label = 'LTD Little Seoul', zone = 'pinggir', coords = vec3(-706.08, -915.42, 19.21) },
        { label = 'Toko 24/7 Innocence Boulevard', zone = 'pinggir', coords = vec3(24.47, -1346.6, 29.49) },
        { label = 'LTD Grove Street', zone = 'pinggir', coords = vec3(-47.24, -1757.65, 29.53) },
        { label = 'Fleeca Bank Rockford Hills', zone = 'pinggir', coords = vec3(-1213.3, -331.1, 37.78) },
        { label = 'Del Perro Heights', zone = 'pinggir', coords = vec3(-1447.35, -537.84, 34.74) },
        { label = 'Richards Majestic', zone = 'pinggir', coords = vec3(-936.15, -378.91, 38.96) },
        { label = 'Rumah Davis', zone = 'pinggir', coords = vec3(495.25, -1823.31, 28.87) },
        { label = 'Rumah El Burro Heights', zone = 'pinggir', coords = vec3(1193.67, -1656.54, 43.03) },

        -- Sandy Shores & sekitarnya (Route 68, Senora)
        { label = 'Toko 24/7 Sandy Shores', zone = 'sandy', coords = vec3(1960.13, 3740.0, 32.34) },
        { label = 'Rumah Sandy Shores', zone = 'sandy', coords = vec3(1435.45, 3657.04, 34.4) },
        { label = 'Rumah Sandy Shores Utara', zone = 'sandy', coords = vec3(1808.93, 3907.97, 33.74) },
        { label = 'Sandy Shores Medical Center', zone = 'sandy', coords = vec3(1839.4, 3672.9, 34.28) },
        { label = 'Toko 24/7 Senora Freeway', zone = 'sandy', coords = vec3(2678.07, 3279.39, 55.24) },
        { label = 'Scoops Liquor Route 68', zone = 'sandy', coords = vec3(1165.9, 2710.81, 38.15) },
        { label = 'Fleeca Bank Route 68', zone = 'sandy', coords = vec3(1175.0, 2706.8, 38.09) },
        { label = 'Toko 24/7 Harmony', zone = 'sandy', coords = vec3(549.05, 2671.39, 42.15) },

        -- Grapeseed & Paleto Bay
        { label = 'Toko 24/7 Grapeseed', zone = 'paleto', coords = vec3(1698.28, 4923.32, 42.06) },
        { label = 'Toko 24/7 Route 1', zone = 'paleto', coords = vec3(1727.85, 6415.14, 35.03) },
        { label = 'Blaine County Savings Paleto', zone = 'paleto', coords = vec3(-112.2, 6469.3, 31.63) },
        { label = 'Rumah Paleto Bay', zone = 'paleto', coords = vec3(-280.54, 6350.67, 32.6) },
        { label = 'Paleto Bay Medical Center', zone = 'paleto', coords = vec3(-247.5, 6331.4, 32.43) },
        { label = 'Ammu-Nation Paleto', zone = 'paleto', coords = vec3(-330.2, 6083.9, 31.45) },
        { label = 'Barber Paleto Bay', zone = 'paleto', coords = vec3(-278.1, 6228.5, 31.7) },
        { label = 'Discount Store Paleto', zone = 'paleto', coords = vec3(5.8, 6511.5, 31.88) },
    },
}
