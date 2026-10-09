-- Interaksi warga / gang lewat ox_target (bidik pemain atau kendaraan).
-- Semua aksi tetap dicek ulang di server: job, jarak, dan kondisi target.
return {
    rob = {
        gangOnly = true,   -- true: hanya anggota crew bertag 'gang' (app Crew) yang bisa merampok
        duration = 5000,   -- lama progress sebelum inventory korban terbuka (ms)

        -- Batas uang yang boleh diambil dari SATU korban oleh SATU perampok.
        -- false = tanpa batas, 0 = tidak boleh diambil sama sekali.
        limits = {
            money = 500000,       -- cash
            black_money = 1000000, -- uang kotor
        },
        limitWindow = 1800, -- detik; setelah lewat, hitungan batas korban yang sama dimulai dari 0 lagi
    },

    cuffs = {
        zipItem = 'zipties',      -- habis 1 tiap dipakai mengikat
        handcuffItem = 'handcuffs',

        -- semua cara membuka harus dari BELAKANG orang yang diborgol (tangannya di belakang)
        behindDot = -0.35, -- makin kecil (mendekati -1) makin harus tepat di belakang
        maxDistance = 1.3,

        hand = { duration = 5000 },  -- zipties: dibuka orang lain tanpa alat
        key = { duration = 2500 },   -- polisi on-duty: kunci borgol, tanpa item

        lockpick = {                 -- handcuffs: lockpick berkurang 1 kalau gagal
            item = 'lockpick',
            difficulty = { 'easy', 'medium', 'medium' },
            keys = { 'w', 'a', 's', 'd' },
        },

        cutter = {                   -- handcuffs: pemotong besi, pasti berhasil, tidak habis
            item = 'bolt_cutter',
            duration = 10000,
            -- prop di tangan; kalau model tidak ada di game, animasi tetap jalan tanpa prop
            prop = { model = 'prop_tool_pliers', bone = 57005, pos = vec3(0.10, 0.02, -0.02), rot = vec3(-80.0, 0.0, 0.0) },
        },
    },

    hostage = {
        gangOnly = false, -- true: hanya anggota crew bertag 'gang' yang bisa menyandera
        maxDistance = 2.0,
        -- senjata yang boleh dipakai menyandera (harus sedang dipegang)
        weapons = {
            `WEAPON_PISTOL`, `WEAPON_PISTOL_MK2`, `WEAPON_COMBATPISTOL`, `WEAPON_APPISTOL`,
            `WEAPON_PISTOL50`, `WEAPON_SNSPISTOL`, `WEAPON_SNSPISTOL_MK2`, `WEAPON_HEAVYPISTOL`,
            `WEAPON_VINTAGEPISTOL`, `WEAPON_MARKSMANPISTOL`, `WEAPON_REVOLVER`, `WEAPON_REVOLVER_MK2`,
            `WEAPON_DOUBLEACTION`, `WEAPON_CERAMICPISTOL`, `WEAPON_NAVYREVOLVER`, `WEAPON_GADGETPISTOL`,
            `WEAPON_PISTOLXM3`,
        },
        releaseKey = 47, -- G
        executeKey = 74, -- H
    },

    trunk = {
        -- posisi korban di bagasi per kelas kendaraan (false = tidak bisa)
        classes = {
            [0] = vec3(0.0, -1.5, 0.0),  -- Compacts
            [1] = vec3(0.0, -2.0, 0.0),  -- Sedans
            [2] = vec3(0.0, -1.0, 0.25), -- SUVs
            [3] = vec3(0.0, -1.5, 0.0),  -- Coupes
            [4] = vec3(0.0, -2.0, 0.0),  -- Muscle
            [5] = vec3(0.0, -2.0, 0.0),  -- Sports Classics
            [6] = vec3(0.0, -2.0, 0.0),  -- Sports
            [7] = vec3(0.0, -2.0, 0.0),  -- Super
            [8] = false,                 -- Motorcycles
            [9] = vec3(0.0, -1.0, 0.25), -- Off-road
            [10] = vec3(0.0, -1.0, 0.25), -- Industrial
            [11] = vec3(0.0, -1.0, 0.25), -- Utility
            [12] = vec3(0.0, -1.0, 0.25), -- Vans
            [13] = false,                 -- Cycles
            [14] = false,                 -- Boats
            [15] = false,                 -- Helicopters
            [16] = false,                 -- Planes
            [17] = vec3(0.0, -1.0, 0.25), -- Service
            [18] = vec3(0.0, -1.0, 0.25), -- Emergency
            [19] = vec3(0.0, -1.0, 0.25), -- Military
            [20] = vec3(0.0, -1.0, 0.25), -- Commercial
            [21] = false,                 -- Trains
        },
    },

    text = {
        rob = 'Rampok',
        robbing = 'Merampok...',
        beingRobbed = 'Kamu sedang dirampok',
        robLimit = 'Batas %s dari korban ini tinggal %s',
        robNotAllowed = 'Hanya anggota gang yang bisa merampok',
        cuff = 'Borgol',
        uncuffHand = 'Buka Borgol',
        uncuffKey = 'Buka Borgol (Kunci)',
        uncuffLockpick = 'Buka Borgol (Lockpick)',
        uncuffCutter = 'Potong Borgol',
        unlocking = 'Membuka borgol...',
        cutting = 'Memotong borgol...',
        beingUnlocked = 'Seseorang sedang membuka borgolmu',
        lockpickBroke = 'Lockpick patah',
        escort = 'Seret',
        carry = 'Gendong / Lepas',
        putInVehicle = 'Masukkan ke Mobil',
        takeOut = 'Keluarkan Penumpang',
        putInTrunk = 'Masukkan ke Bagasi',
        takeOutTrunk = 'Keluarkan dari Bagasi',
        trunkNotAllowed = 'Kendaraan ini tidak punya bagasi',
        hostage = 'Sandera',
        hostageHelp = '[G] Lepaskan  \n[H] Eksekusi',
        hostageVictim = 'Kamu disandera',
        hostageFailed = 'Tidak bisa menyandera sekarang',

        -- polisi on-duty
        search = 'Geledah',
        beingSearched = 'Kamu sedang digeledah polisi',
        takeDna = 'Ambil DNA',
        anklet = 'Pasang / Lepas Anklet',
        checkPlate = 'Cek Plat',
        plateTitle = 'Plat %s',
        plateOwner = 'Pemilik: %s',
        plateUnregistered = 'Pemilik: tidak terdaftar (kendaraan lokal)',
        plateFlagged = '**%s** (lihat catatan kendaraan di MDT)',
        plateClean = 'Tidak ada tanda dicari',

        -- Administrasi (tilang); panelnya NUI html/admin.*, harga & daftar denda ada di
        -- f_cityhall/config/shared.lua `tickets`
        admin = 'Administrasi',
        seizing = 'Menyita kendaraan...',
    },
}
