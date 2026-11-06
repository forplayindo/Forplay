-- Offset relatif kendaraan (x kanan, y depan, z atas) diukur dari model tug & bison asli GTA.
-- Kurang pas? Berdiri di titiknya lalu /nelayandek untuk menyalin offset.
return {
    tug = {
        stern = vec3(0.0, -14.2, 1.3),      -- lingkaran biru di lantai dek buritan (dek naik ke belakang, z ±1.2)
        sternRadius = 2.5,
        sternEdge = -12.7,                  -- berdiri di belakang garis ini (di belakang tumpukan peti) = boleh tebar / tarik
        castOffset = vec3(0.0, -24.0, 0.0), -- jaring mendarat di air di belakang buritan
        board = vec4(0.0, -7.8, 1.7, 180.0),  -- naik dari dermaga muncul di dek tengah, menghadap buritan
        crateReach = 2.5,                   -- berdiri sedekat ini ke salah satu peti -> opsi Masukkan ikan / Turunkan peti
        -- 8 slot peti dasar di tengah dek, tepat di belakang 2 gulungan tali: 4 kolom x 2 baris, diisi dari kiri.
        -- Peti ke-9 dst menumpuk di atasnya (lapis 2, 3, 4 = maks 32 untuk kru 4 orang).
        -- Peti diputar 90 derajat (sisi panjang searah kapal). z lapis dasar ditempel otomatis ke lantai dek.
        crateHeading = 90.0,
        crateLayer = 0.31,                  -- tinggi peti (0.30 m) + celah
        crates = {
            vec3(-0.56, -11.45, 0.7), vec3(-0.12, -11.45, 0.7), vec3(0.32, -11.45, 0.7), vec3(0.76, -11.45, 0.7),
            vec3(-0.56, -12.10, 0.8), vec3(-0.12, -12.10, 0.8), vec3(0.32, -12.10, 0.8), vec3(0.76, -12.10, 0.8),
        },
    },
    bison = {
        rear = vec3(0.0, -3.2, 0.0),        -- berdiri di belakang bak untuk muat / ambil
        rearRadius = 2.2,
        -- lantai bak z 0.3, lebar 1.82 m, panjang 1.9 m -> 2 kolom x 4 baris = 8 peti (bagian 1 orang)
        crates = {
            vec3(-0.33, -1.16, 0.31), vec3(0.33, -1.16, 0.31),
            vec3(-0.33, -1.60, 0.31), vec3(0.33, -1.60, 0.31),
            vec3(-0.33, -2.04, 0.31), vec3(0.33, -2.04, 0.31),
            vec3(-0.33, -2.48, 0.31), vec3(0.33, -2.48, 0.31),
        },
    },

    -- tug bawaan GTA sangat pelan: tambahan tenaga & kecepatan maks (persen) untuk tug kerja nelayan saja
    tugBoost = { power = 60.0, topSpeed = 60.0 },

    propDistance = 120.0,       -- prop dek / bak dibuat saat sedekat ini
    shoalDistance = 300.0,

    -- animasi (semua sudah dicek ada di file GTA)
    anims = {
        throw = { dict = 'anim@heists@narcotics@trash', clip = 'throw_b', releaseMs = 750 },
        pull = { dict = 'random@mugging4', clip = 'struggle_loop_b_thief' },
        sort = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d' },
        carry = { dict = 'anim@heists@box_carry@', clip = 'idle' },
        pickup = { dict = 'pickup_object', clip = 'pickup_low' },
    },
    -- jaring di tangan kanan, digantung dari ujung atas (pivot prop = tengah bawah)
    handAttach = { bone = 57005, pos = vec3(0.12, 0.02, 0.0), rot = vec3(0.0, 180.0, 0.0) },
    -- peti dibawa dua tangan di depan perut (bone 0 = root ped, sisi panjang peti melintang)
    crateAttach = { bone = 0, pos = vec3(0.0, 0.42, -0.05), rot = vec3(0.0, 0.0, 0.0) },
    -- jaring isi ikan (±1 m) dipeluk di depan badan setelah ditarik, sampai ikannya habis disortir ke peti
    netFishAttach = { bone = 0, pos = vec3(0.0, 0.55, -0.6), rot = vec3(0.0, 0.0, 0.0) },
    sortDuration = 5000,

    -- tarik-ulur: 3 putaran, tekan [E] saat penanda di zona hijau
    pull = { rounds = 3, zone = 0.22, speed = 1.15 },
    reelMs = 6000,              -- lama jaring di laut ditarik mendekat ke buritan (dengan tali di tangan)
}
