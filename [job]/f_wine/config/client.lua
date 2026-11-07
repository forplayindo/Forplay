return {
    mandorPed = `a_m_m_farmer_01`,
    tongFermentasi = `prop_wooden_barrel`,
    keranjang = `f_wine_keranjang`,

    -- Baju petani kebun (WAJIB saat memetik). Nomor ini USULAN AWAL: cek di game lalu ganti sesukamu.
    -- Komponen: pants 4, arms 3, t-shirt 8, torso2 11, shoes 6. Topi = prop 0 (item -1 = tanpa topi).
    -- Pengecekan "masih pakai baju kerja" memakai torso2.
    outfit = {
        male = {
            ['t-shirt'] = { item = 15, texture = 0 },
            ['torso2']  = { item = 41, texture = 0 },   -- kemeja flanel
            ['arms']    = { item = 1,  texture = 0 },
            ['pants']   = { item = 1,  texture = 0 },   -- jeans
            ['shoes']   = { item = 25, texture = 0 },   -- boots
            hat         = { item = 13, texture = 0 },   -- topi lebar
        },
        female = {
            ['t-shirt'] = { item = 14, texture = 0 },
            ['torso2']  = { item = 9,  texture = 0 },
            ['arms']    = { item = 9,  texture = 0 },
            ['pants']   = { item = 0,  texture = 0 },
            ['shoes']   = { item = 25, texture = 0 },
            hat         = { item = 12, texture = 0 },
        },
    },

    anim = {
        bawa = { dict = 'anim@heists@box_carry@', clip = 'idle' },                         -- membawa keranjang
        petikTinggi = { dict = 'amb@prop_human_movie_bulb@base', clip = 'base' },          -- tandan setinggi dada ke atas
        petikRendah = { dict = 'amb@medic@standing@kneel@base', clip = 'base' },           -- tandan rendah (< batasRendah dari kaki)
        batasRendah = 0.75,
        petikMs = 3500,
        masukkan = { dict = 'pickup_object', clip = 'putdown_low', ms = 1100 },
        injak = { dict = 'amb@world_human_jog_standing@male@idle_a', clip = 'idle_a' },  -- jalan di tempat = menginjak
        tuang = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d', ms = 3000 },
    },

    -- posisi prop (setel live dengan /wineoffset kalau debug = true di config/shared.lua)
    pasang = {
        keranjangBawa = { bone = 0, pos = vec3(0.0, 0.42, -0.08), rot = vec3(0.0, 0.0, 0.0) },     -- 0 = akar ped
        tandanTangan  = { bone = 57005, pos = vec3(0.11, 0.03, -0.02), rot = vec3(-70.0, 0.0, -20.0) },
        injakZ = 1.38,         -- tinggi akar ped dari dasar tong saat menginjak (kaki di permukaan jus)
    },

    -- tandan rebah di dalam keranjang (koordinat keranjang, pivot tandan = pangkal tangkai)
    isiKeranjang = {
        { vec3(0.10, -0.06, 0.075),  vec3(0.0,  90.0, 20.0) },
        { vec3(-0.10, 0.06, 0.075),  vec3(0.0, -90.0, -15.0) },
        { vec3(0.10, 0.07, 0.075),   vec3(0.0,  90.0, -10.0) },
        { vec3(-0.10, -0.07, 0.075), vec3(0.0, -90.0, 25.0) },
        { vec3(0.22, 0.0, 0.08),     vec3(0.0,  90.0, 90.0) },
        { vec3(-0.22, 0.0, 0.08),    vec3(0.0, -90.0, 80.0) },
        { vec3(0.05, 0.0, 0.15),     vec3(0.0,  90.0, 5.0) },
        { vec3(-0.06, 0.01, 0.16),   vec3(0.0, -90.0, -5.0) },
    },

    -- minigame injak
    minigame = {
        tekanan = 24,          -- tekanan benar sampai jus penuh
        salah = 0.05,          -- bar turun sekian (0-1) kalau salah tombol
        jedaMs = 220,          -- tekanan lebih cepat dari ini tidak dihitung
    },
}
