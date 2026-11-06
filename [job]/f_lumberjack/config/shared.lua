return {
    maxCrew = 4,

    -- markas di kota Paleto: Mandor (mulai kerja, chainsaw, Gudang Kayu) + parkir truk
    npc = { model = `s_m_y_construct_01`, coords = vec4(91.78, 6360.56, 30.38, 26.08) },
    -- parkir truk di markas = titik Bongkar papan & Selesai Kerja
    depot = { coords = vec3(98.92, 6373.97, 30.23), radius = 15.0 },
    truckSpawns = {
        vec4(98.92, 6373.97, 30.23, 7.15),
    },

    forest = vec2(-645.61, 5411.87),   -- waypoint hutan (lokasi tebang) saat Mulai Kerja

    -- tumpukan papan sawmill: prop tetap untuk semua pemain (ox_target Pindahkan papan ke truk), jumlah papan dicatat server
    plankOutput = { coords = vec3(-552.4, 5367.01, 69.57), heading = 0.0 },
    conveyorMs = 9000,          -- lama satu batang menempuh conveyor sawmill

    -- stasiun olah kayu (parkir truk di sini, bak menghadap mesin)
    stations = {
        vec4(-488.77, 5341.81, 84.01, 249.7),
        vec4(-487.04, 5346.5, 84.01, 249.7),
    },
    stationRadius = 6.0,

    chainsawPrice = 50000,      -- dibeli di NPC Mandor (tunai, kalau kurang dari bank)
    papanPrice = 6000,          -- harga jual di f_koperasi (hanya untuk info di menu; harga asli di config koperasi)
    papanPerPiece = 2,          -- 1 potongan kayu = 2 papan (batang besar = 3 potongan = 6 papan)
    piecesPerTrunk = 3,         -- 1 pohon = 1 batang utuh = 3 potongan (nilai & tempat di bak sama)
    claimTimeout = 30,          -- pengangkat batang pertama menunggu rekan di ujung lain selama sekian detik
    groundLimit = 6,            -- kayu milik kru yang belum dimuat (dalam potongan, batang utuh = 3) -> maks 2 pohon
    -- bonus papan per ukuran kru: waktu jalan ke sawmill sama berapa pun anggotanya, jadi kru besar perlu bonus besar
    crewBonus = { [1] = 0, [2] = 35, [3] = 85, [4] = 130 },

    tree = { model = `prop_tree_cedar_02`, zOffset = -3.5 },
    -- setelah pohon tumbang jadi 1 batang besar; titik tengahnya sejauh ini dari tunggul
    trunk = { model = `prop_log_03`, offset = 6.5 },
    -- solo: batang besar dipotong jadi 3 batang kecil, berbaris searah batang tiap spacing meter
    -- (across = true -> berjajar menyamping)
    piece = { model = `prop_log_01`, spacing = 4.5, across = false },
    -- truk: solo Biff (bawa potongan), kru 2+ orang flatbed besar (bawa batang besar utuh, dari f_carjob)
    -- capacity = isi bak dalam potongan (batang besar = 3), samakan dengan jumlah slot layers di config.client truck
    trucks = {
        solo = { model = 'biff', capacity = 18 },           -- 18 batang kecil = 6 pohon
        crew = { model = '17mov_flatbed', capacity = 27 },  -- 9 batang besar = 9 pohon
    },

    -- 135 titik pohon dari 17mov (hutan sekitar sawmill), dipakai bersama semua kru
    trees = {
        vec3(-645.61, 5411.87, 47.29), vec3(-624.56, 5411.82, 49.45), vec3(-634.15, 5387.13, 53.53),
        vec3(-665.86, 5365.69, 58.91), vec3(-664.95, 5343.81, 62.6), vec3(-728.37, 5279.53, 78.79),
        vec3(-755.76, 5283.57, 83.55), vec3(-690.96, 5224.04, 94.91), vec3(-672.6, 5210.38, 95.82),
        vec3(-635.4, 5152.26, 111.67), vec3(-616.73, 5119.49, 120.38), vec3(-574.23, 5101.81, 122.5),
        vec3(-545.2, 5111.71, 112.19), vec3(-495.51, 5136.5, 103.01), vec3(-490.38, 5477.88, 82.8),
        vec3(-519.72, 5486.62, 70.91), vec3(-531.71, 5462.31, 70.49), vec3(-540.1, 5441.34, 68.05),
        vec3(-519.32, 5438.12, 72.49), vec3(-509.31, 5492.07, 74.33), vec3(-471.69, 5487.43, 84.03),
        vec3(-519.16, 5585.13, 65.9), vec3(-531.55, 5571.48, 62.81), vec3(-529.61, 5552.31, 64.9),
        vec3(-540.84, 5531.77, 61.61), vec3(-554.39, 5562.05, 56.39), vec3(-589.23, 5431.29, 57.21),
        vec3(-567.84, 5426.72, 61.0), vec3(-728.19, 5350.34, 63.3), vec3(-730.67, 5364.64, 60.48),
        vec3(-722.48, 5390.02, 55.06), vec3(-727.42, 5401.34, 50.97), vec3(-735.48, 5382.91, 55.01),
        vec3(-747.37, 5359.01, 59.81), vec3(-748.72, 5285.98, 80.81), vec3(-498.74, 5451.62, 79.77),
        vec3(-510.49, 5467.59, 76.77), vec3(-529.41, 5504.77, 66.24), vec3(-512.72, 5533.79, 70.85),
        vec3(-584.55, 5512.0, 52.62), vec3(-582.23, 5503.76, 54.13), vec3(-579.39, 5481.86, 58.13),
        vec3(-608.1, 5468.1, 56.72), vec3(-625.57, 5481.37, 52.83), vec3(-660.37, 5474.98, 51.37),
        vec3(-689.38, 5464.27, 47.12), vec3(-712.04, 5413.47, 49.73), vec3(-711.86, 5374.91, 60.19),
        vec3(-722.23, 5344.14, 65.91), vec3(-722.23, 5302.66, 72.62), vec3(-757.18, 5247.65, 95.3),
        vec3(-694.52, 5194.67, 103.17), vec3(-677.13, 5173.72, 108.07), vec3(-638.68, 5180.63, 99.24),
        vec3(-590.7, 5181.34, 95.81), vec3(-561.04, 5155.30, 101.71), vec3(-586.59, 5138.02, 111.49),
        vec3(-681.87, 5131.28, 124.55), vec3(-684.47, 5360.15, 65.19), vec3(-688.87, 4977.74, 179.36),
        vec3(-667.43, 5011.87, 164.96), vec3(-666.18, 5056.28, 147.76), vec3(-605.13, 5043.49, 140.34),
        vec3(-657.11, 5136.94, 124.69), vec3(-613.6, 5243.29, 72.38), vec3(-517.75, 5185.98, 89.79),
        vec3(-802.51, 5287.74, 86.55), vec3(-817.04, 5269.61, 87.95), vec3(-788.8, 5227.42, 104.26),
        vec3(-771.96, 5205.25, 111.4), vec3(-740.68, 5200.75, 104.22), vec3(-744.22, 5120.48, 135.0),
        vec3(-706.64, 5105.96, 132.03), vec3(-722.7, 5066.09, 143.12), vec3(-654.21, 5035.41, 154.55),
        vec3(-577.6, 5077.24, 130.64), vec3(-452.45, 5099.4, 130.34), vec3(-480.19, 5108.66, 118.7),
        vec3(-476.73, 5123.16, 113.17), vec3(-442.23, 5182.72, 110.59), vec3(-421.5, 5225.06, 124.34),
        vec3(-409.42, 5268.9, 127.09), vec3(-398.38, 5286.62, 125.51), vec3(-449.79, 5385.96, 80.44),
        vec3(-476.24, 5424.59, 68.6), vec3(-657.12, 5303.43, 66.9), vec3(-545.45, 5079.27, 123.59),
        vec3(-661.94, 5113.78, 129.96), vec3(-668.48, 5122.11, 127.41), vec3(-676.88, 5123.98, 127.41),
        vec3(-684.74, 5135.61, 122.77), vec3(-678.92, 5173.07, 108.17), vec3(-683.94, 5186.62, 105.05),
        vec3(-666.42, 5189.94, 102.1), vec3(-654.8, 5194.65, 96.19), vec3(-640.27, 5196.54, 92.35),
        vec3(-625.11, 5196.69, 89.46), vec3(-617.0, 5232.85, 73.87), vec3(-625.6, 5244.29, 73.76),
        vec3(-642.6, 5255.01, 74.94), vec3(-651.35, 5255.88, 75.64), vec3(-659.65, 5261.74, 76.39),
        vec3(-661.34, 5275.45, 74.48), vec3(-670.49, 5287.44, 72.19), vec3(-680.75, 5282.51, 72.4),
        vec3(-554.78, 5226.8, 74.85), vec3(-543.34, 5237.91, 74.79), vec3(-534.23, 5237.0, 78.31),
        vec3(-507.72, 5222.4, 87.04), vec3(-356.02, 5366.27, 132.39), vec3(-366.05, 5366.66, 125.56),
        vec3(-378.78, 5368.71, 118.62), vec3(-385.71, 5363.21, 115.97), vec3(-463.55, 5566.79, 72.87),
        vec3(-465.37, 5580.11, 71.19), vec3(-489.26, 5557.56, 72.94), vec3(-496.86, 5525.12, 75.06),
        vec3(-517.58, 5521.56, 69.58), vec3(-535.48, 5515.5, 64.09), vec3(-560.11, 5496.26, 59.52),
        vec3(-571.11, 5486.93, 58.88), vec3(-585.56, 5484.2, 56.46), vec3(-593.1, 5472.41, 57.3),
        vec3(-609.0, 5472.4, 55.09), vec3(-648.85, 5479.99, 51.72), vec3(-646.64, 5492.6, 51.28),
        vec3(-661.73, 5453.63, 50.43), vec3(-679.16, 5432.8, 47.39), vec3(-691.1, 5395.92, 53.59),
        vec3(-685.85, 5380.1, 58.06), vec3(-687.99, 5359.93, 65.76), vec3(-685.81, 5348.95, 67.62),
        vec3(-683.72, 5331.08, 68.33), vec3(-674.66, 5327.79, 66.42),
    },
}
