-- Panel "Cek Pasien" (EMS). Dibaca client & server.
return {
    distance = 3.0,          -- jarak maksimal EMS ke pasien (dicek server di setiap tindakan)
    closeDistance = 6.0,     -- panel tertutup otomatis kalau pasien menjauh

    -- nama item ox_inventory
    items = {
        bandage = 'bandage',
        hemostatic = 'hemostatic',
        splint = 'splint',
        suture = 'suture',
        firstaid = 'firstaid',
        painkillers = 'painkillers',
        bloodBag = 'blood_bag',
        crutch = 'crutch',
    },
    -- nama item untuk pesan (sama dengan label di ox_inventory)
    itemLabels = {
        bandage = 'Bandage',
        hemostatic = 'Hemostatic Gauze',
        splint = 'Splint',
        suture = 'Suture Kit',
        firstaid = 'First Aid Kit',
        painkillers = 'Painkillers',
        bloodBag = 'Blood Bag',
        crutch = 'Crutch',
        anesthetic = 'Anesthetic',
        surgical_kit = 'Surgical Kit',
    },

    -- Masa pemulihan: dimulai saat Splint dipasang di area di bawah ini (dan setelah operasi kaki).
    -- Dihitung dalam waktu bermain (hanya berkurang saat online), disimpan di metadata player.
    recovery = {
        duration = 20 * 60,   -- detik
        tick = 30,            -- detik antar pengurangan di server
        parts = { LLEG = true, RLEG = true, LFOOT = true, RFOOT = true, SPINE = true },
        fallChance = 25,      -- % peluang jatuh per detik kalau memaksa lari tanpa Crutch
    },

    -- Operasi. Luka yang perlu operasi: tingkat 4 akibat tembakan di kepala / leher / badan (peluru
    -- bersarang) dan tingkat 4 di kaki / telapak / tulang belakang (patah parah). Item lapangan hanya
    -- MENSTABILKAN luka ini; selama belum dioperasi darah maksimal `bloodCap` dan bisa berdarah lagi.
    surgery = {
        doctorGrade = 2,          -- grade ambulance minimal (2 = Doctor)
        bloodCap = 60,            -- darah maksimal selama ada luka yang perlu operasi
        rebleedChance = 20,       -- % peluang luka distabilkan berdarah lagi tiap 5 menit
        recoverTime = 10,        -- detik pasien berbaring setelah operasi sebelum boleh bangun
        anesthetic = 'anesthetic',
        kit = 'surgical_kit',
        kitWear = 5,              -- durability Surgical Kit berkurang per tahap yang memakainya (2 tahap = 10 per operasi)

        -- Meja operasi. ISI setelah MLO siap: berdiri di posisi pasien berbaring, ambil /vec4.
        -- Selama kosong, fitur operasi tidak aktif.
        tables = {
             { label = 'Ruang Operasi 1', coords = vec4(-231.86, -978.82, 28.19, 13.4) },
        },

        -- tahap berurutan; durasi ms. bloodLoss = darah pasien turun (%), needBlood = darah minimal sebelum mulai
        steps = {
            { id = 'anesthesia', label = 'Bius', duration = 10000, item = 'anesthetic', desc = 'Pasien dibius, tidak sadar sampai operasi selesai' },
            { id = 'sterilize', label = 'Sterilisasi', duration = 10000, desc = 'Membersihkan area operasi' },
            { id = 'incision', label = 'Sayat', duration = 15000, kit = true, bloodLoss = 5, desc = 'Membuka area luka' },
            { id = 'repair', label = 'Ambil peluru / pasang pen', duration = 25000, kit = true, bloodLoss = 10, needBlood = 20, desc = 'Darah pasien minimal 20%, transfusi dulu kalau kurang' },
            { id = 'suture', label = 'Jahit', duration = 20000, item = 'suture', desc = 'Menutup luka' },
            { id = 'dress', label = 'Perban', duration = 10000, item = 'bandage', desc = 'Membalut luka operasi' },
        },
    },

    -- Crutch (prop bawaan GTA). Posisi di tangan bisa disetel admin live dengan /crutchpos.
    crutch = {
        model = 'v_med_crutch01',
        bone = 57005,                         -- SKEL_R_Hand
        pos = vec3(0.0, -0.06, -0.6),
        rot = vec3(0.0, 0.0, 0.0),
        clipset = 'move_lester_CaneUp',       -- gaya jalan dengan tongkat
        limpClipset = 'move_m@injured',       -- pemulihan tanpa Crutch
    },

    -- Donor darah: EMS ambil darah pemain lewat ox_target "Ambil Darah" (pendonor harus setuju).
    donor = {
        emptyBag = 'blood_bag_empty', -- dibawa EMS (armory), berubah jadi blood_bag setelah diambil
        duration = 20000,             -- ms progress bar
        minBlood = 70,                -- darah pendonor minimal (%)
        bloodLoss = 20,               -- darah pendonor berkurang (%)
        cooldown = 60,                -- menit sebelum karakter yang sama boleh donor lagi
        weakTime = 120,               -- detik pendonor lemas (tidak bisa lari)
        consentTimeout = 20,          -- detik pendonor menjawab pop-up persetujuan
    },

    -- durasi progress bar (ms). Server menolak tindakan yang selesai lebih cepat dari ini.
    durations = {
        treat = 6000,        -- obati satu area
        bleed = 6000,        -- hentikan pendarahan
        all = 10000,         -- obati semua
        painkiller = 3000,
        revive = 10000,
        transfusion = 20000, -- 1 kantong darah = darah penuh 100%
        crutch = 3000,       -- memberikan Crutch ke pasien
    },

    blood = {
        critical = 20,       -- darah di bawah ini = kritis; pengobatan biasa hanya bisa menaikkan sampai sini
        perTreat = 10,       -- tambahan darah per area yang diobati
        afterRevive = 25,    -- darah setelah revive lapangan (luka tetap ada)
    },

    -- Area tubuh: label Indonesia & jenis (limb = anggota gerak -> bidai, skin = kepala/badan -> kit jahit)
    bodyParts = {
        HEAD = { label = 'Kepala', kind = 'skin' },
        NECK = { label = 'Leher', kind = 'skin' },
        UPPER_BODY = { label = 'Badan atas', kind = 'skin' },
        LOWER_BODY = { label = 'Badan bawah', kind = 'skin' },
        SPINE = { label = 'Tulang belakang', kind = 'limb', limp = true },
        LARM = { label = 'Lengan kiri', kind = 'limb' },
        LHAND = { label = 'Tangan kiri', kind = 'limb' },
        LFINGER = { label = 'Jari kiri', kind = 'limb' },
        RARM = { label = 'Lengan kanan', kind = 'limb' },
        RHAND = { label = 'Tangan kanan', kind = 'limb' },
        RFINGER = { label = 'Jari kanan', kind = 'limb' },
        LLEG = { label = 'Kaki kiri', kind = 'limb', limp = true },
        LFOOT = { label = 'Telapak kiri', kind = 'limb', limp = true },
        RLEG = { label = 'Kaki kanan', kind = 'limb', limp = true },
        RFOOT = { label = 'Telapak kanan', kind = 'limb', limp = true },
    },

    severityLabels = { 'Iritasi', 'Cukup sakit', 'Sakit', 'Sangat sakit' },
    bleedLabels = { 'Sedikit berdarah', 'Berdarah', 'Banyak berdarah', 'Pendarahan hebat' },
    heavyBleed = 3,          -- pendarahan >= ini butuh Hemostatic Gauze & mengunci revive

    -- Harga layanan (tab Tagihan). EMS boleh diskon, tidak bisa menaikkan.
    billing = {
        light = { label = 'Obati luka ringan', price = 10000 },
        bleed = { label = 'Hentikan pendarahan', price = 20000 },
        heavy = { label = 'Obati luka berat', price = 30000 },
        painkiller = { label = 'Painkillers', price = 10000 },
        revive = { label = 'Revive di lapangan', price = 150000 },
        transfusion = { label = 'Transfusi darah', price = 75000 },
        crutch = { label = 'Pemberian Kruk', price = 30000 },
        surgery = { label = 'Operasi', price = 400000 },
    },
}
