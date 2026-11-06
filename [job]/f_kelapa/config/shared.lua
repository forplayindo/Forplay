return {
    item = 'kelapa_muda',           -- item yang sudah ada (bahan f_cafe), dijual di f_koperasi
    buahPerPohon = 6,               -- sama dengan jumlah titik kelapa di model f_kelapa_pohon
    tumbuhMenit = 20,               -- pohon yang habis dipetik berbuah penuh lagi setelah sekian menit
    jatuhMenit = 15,                -- kelapa di tanah yang tidak dipungut hilang setelah sekian menit

    -- tengah kebun Paleto (posisi tiap pohon ada di config/pohon.lua, dibuat _sumber/build_kebun.py)
    kebun = vec3(-8.7, 6868.3, 12.0),
    jarakRender = 150.0,            -- kelapa (di pohon & tanah) hanya dibuat saat player sedekat ini

    jarakPanjat = 3.0,              -- server: jarak maks player ke pangkal pohon saat mulai panjat
    jarakAtas = 3.0,                -- server: jarak maks player ke titik atas saat memetik
    jarakPungut = 2.5,              -- server: jarak maks player ke kelapa di tanah
    jatuhRadius = { 1.3, 2.6 },     -- kelapa mendarat sekian meter dari pangkal batang

    panjat = {
        -- animasi tangga bawaan GTA: tahan W = climb_up, tahan S = climb_down, diam = berpegangan
        dict = 'laddersbase',
        naik = 'climb_up', turun = 'climb_down', diam = 'base_left_hand_up',
        mulai = 'get_on_bottom_front_stand_high',  -- turun ke tanah tanpa anim get_off (anim itu meloncat dari tangga)
        kecepatanNaik = 0.55,       -- m/detik saat W ditahan (samakan dengan gerak tangan, /kelapaanim)
        kecepatanTurun = 0.8,       -- m/detik saat S ditahan
        jarakBatang = 0.45,         -- jarak pinggang ped dari sumbu batang
        rotasi = 0,                 -- koreksi arah hadap ped (derajat); 180 kalau ped membelakangi batang
        -- 0 sejak pohon tidak lagi terbenam 1,15 m (dulu /coords dikira pinggang, padahal kaki)
        angkat = 0.0,               -- koreksi tinggi ped yang di-attach (m)
        kurangAtas = 0.0,           -- berhenti sekian meter di bawah titik panjat_atas (pinggang 6,7 m, kelapa 7,6-7,9 m)
        tinggiAwal = 1.15,          -- tinggi pinggang ped dari pangkal pohon (pangkal dibenamkan 0,15 m)
    },

    petik = {
        -- tangan kanan meraih ke atas, diputar di badan atas saja (kaki tetap menjepit batang)
        dict = 'anim@scripted@player@freemode@gen_grab@male@', clip = 'high_rh',
        durasi = 1600,              -- ms, selama ini [E] tidak bisa ditekan lagi
        jatuhSetelah = 800,         -- ms setelah tangan mulai meraih, kelapa lepas
    },

    pungut = {
        -- membungkuk, tangan meraih ke tanah, berdiri (1,9 detik, diperlambat supaya pas durasi)
        durasi = 3000,
        dict = 'pickup_object', clip = 'pickup_low', lamaAnim = 1900,
        angkatSetelah = 1300,       -- ms: tangan sampai di tanah -> kelapa menempel ke tangan kanan
        tangan = { bone = 57005, pos = vec3(0.12, 0.02, -0.03), rot = vec3(0.0, 0.0, 0.0) },
    },

    debug = true,                   -- /kelapaanim <naik> <turun> <jarakBatang> untuk kalibrasi. Matikan setelah pas.
}
