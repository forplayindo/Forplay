Config = {}

-------------------------------------------------------------------------------
-- Countdown
-------------------------------------------------------------------------------
-- Lama (detik) player tergeletak sebelum otomatis dibawa ke rumah sakit. Dihitung di SERVER,
-- jadi tidak bisa dipercepat dari client. Selama countdown EMS bisa revive.
Config.BleedoutTime = 300

-------------------------------------------------------------------------------
-- Tombol (default; player bisa ganti sendiri di Settings > Key Bindings > FiveM)
-------------------------------------------------------------------------------
Config.Keys = {
    dispatch = 'E', -- panggil EMS (atau dokter AI kalau tidak ada EMS)
    sync     = 'H', -- perbaiki desync (karakter nyangkut / tembus tanah / animasi lepas)
}

Config.DispatchCooldown = 60 -- detik, dicek di server
Config.SyncCooldown     = 30 -- detik, dicek di server

-------------------------------------------------------------------------------
-- Rumah sakit
-------------------------------------------------------------------------------
-- Saat waktu habis, player dibawa ke KASUR rumah sakit milik f_ambulancejob, dirawat, lalu
-- tekan E untuk bangun. Biaya administrasi (checkInCost di f_ambulancejob/config/shared.lua)
-- dipotong dari bank saat bangun dan tagihannya dikirim ke email f_phone. Item tidak hilang.
--
-- Key di bawah = nama rumah sakit di f_ambulancejob/config/shared.lua (locations.hospitals),
-- yang harus punya daftar beds. Nama tampilan diambil dari 'label' di sana.
-- 'nearest' = rumah sakit terdekat dari lokasi player tergeletak
-- 'fixed'   = selalu ke Config.FixedHospital
Config.HospitalMode  = 'nearest'
Config.FixedHospital = 'pillbox'
Config.Hospitals     = { 'pillbox' }

-- Player yang sedang dipenjara (metadata injail > 0) selalu dibawa ke sini. nil = ikut aturan biasa.
Config.JailHospital = 'jail'

-- Uang dokter AI masuk ke rekening society ini (Renewed-Banking). nil = tidak kemana-mana
Config.Society = 'ambulance'

-------------------------------------------------------------------------------
-- Dispatch ke EMS
-------------------------------------------------------------------------------
Config.EmsJobType = 'ems' -- job.type yang menerima panggilan (harus on duty)
Config.Blip = {
    sprite   = 153,
    color    = 1,
    scale    = 1.1,
    radius   = 45.0, -- lingkaran area di map, 0 = tanpa lingkaran
    duration = 300,  -- detik blip bertahan (hilang lebih cepat kalau pasien sudah bangun)
}

-------------------------------------------------------------------------------
-- Dokter AI (tombol E saat tidak ada EMS bertugas)
-------------------------------------------------------------------------------
Config.AiDoctor = {
    Enabled       = true,
    MaxEms        = 0,       -- dokter AI datang kalau jumlah EMS on duty <= angka ini
    Price         = 150000,   -- dipotong dari BANK; saldo kurang = tidak bisa dipanggil
    Label         = 'Foreplay Hospital', -- nama pengirim email tagihan
    Model         = 's_m_m_doctor_01',
    SpawnDistance = 25.0,    -- jarak dokter muncul dari player (meter)
    ArriveTimeout = 45,      -- detik; kalau dokter nyangkut, dipindah ke samping player
    ReviveTime    = 20,      -- detik dokter melakukan CPR
    Timeout       = 120,     -- detik; pengaman server: tetap revive kalau proses client macet
}

-------------------------------------------------------------------------------
-- Text (Bahasa Indonesia)
-------------------------------------------------------------------------------
Config.Locale = {
    ui = {
        downTitle      = 'KONDISI KRITIS', -- last stand
        deadTitle      = 'KAMU MENINGGAL', -- fully dead
        subtitle       = 'Tunggu EMS. Saat waktu habis kamu akan dibawa ke rumah sakit.',
        timeUp         = 'Membawamu ke rumah sakit...',
        transport      = 'Membawamu ke %s',
        dispatch       = 'Panggil EMS',
        sync           = 'Sinkron',
        causeOfDeath   = 'Penyebab kematian',
        murderWeapon   = 'Senjata pembunuh',
        distance       = 'Jarak',
        timeOfDeath    = 'Waktu kematian',
        location       = 'Lokasi',
        emsOnDuty      = 'EMS bertugas',
        bleeding       = 'Pendarahan',
        noInjury       = 'Tidak ada luka tercatat',
        dispatchSent   = 'Panggilan dikirim ke %d EMS',
        dispatchNoEms  = 'Tidak ada EMS bertugas, sinyalmu sudah dicatat',
        cooldown       = 'Tunggu %d detik lagi',
        syncDone       = 'Sinkron selesai',
        aiComing       = 'Dokter AI dipanggil, Rp %s dipotong dari bank',
        aiComingSub    = 'Tidak ada EMS bertugas. Dokter AI sedang menuju lokasimu.',
        aiTreating     = 'Dokter sedang merawatmu...',
        emsTreating    = 'EMS sedang merawatmu. Waktu dihentikan sementara.',
        aiNoMoney      = 'Saldo bank tidak cukup untuk memanggil dokter (Rp %s)',
        aiBusy         = 'Dokter AI sudah dalam perjalanan',
        bedsFull       = 'Semua kasur rumah sakit terisi, mencoba lagi...',
        unknown        = 'TIDAK DIKETAHUI',
        none           = '-',
    },

    causes = {
        shot      = 'DITEMBAK',
        melee     = 'DIPUKUL',
        stabbed   = 'DITUSUK',
        vehicle   = 'KENDARAAN',
        fall      = 'JATUH',
        drowned   = 'TENGGELAM',
        fire      = 'TERBAKAR',
        explosion = 'LEDAKAN',
        animal    = 'HEWAN',
        bleeding  = 'KEHABISAN DARAH',
        electric  = 'TERSENGAT LISTRIK',
        gas       = 'GAS',
        starved   = 'KELAPARAN',
        dehydrated = 'KEHAUSAN',
        starvedDehydrated = 'KELAPARAN & KEHAUSAN',
        unknown   = 'TIDAK DIKETAHUI',
    },

    body = {
        HEAD = 'Kepala', NECK = 'Leher', SPINE = 'Tulang belakang',
        UPPER_BODY = 'Dada', LOWER_BODY = 'Panggul',
        LARM = 'Lengan kiri', LHAND = 'Tangan kiri', LFINGER = 'Jari kiri',
        LLEG = 'Kaki kiri', LFOOT = 'Telapak kaki kiri',
        RARM = 'Lengan kanan', RHAND = 'Tangan kanan', RFINGER = 'Jari kanan',
        RLEG = 'Kaki kanan', RFOOT = 'Telapak kaki kanan',
    },

    severity = { 'Ringan', 'Sedang', 'Parah', 'Kritis' },
    bleed    = { [0] = 'Tidak ada', 'Ringan', 'Sedang', 'Berat', 'Parah' },

    -- Dispatch (f_phone notification for EMS)
    alertApp   = 'Dispatch EMS',
    alertTitle = 'Orang Tidak Sadarkan Diri',
    alertBody  = 'Butuh bantuan medis di %s',
    blipName   = 'Pasien Kritis',

    -- AI doctor bill email (lines 1, 3, 4 and 7 are filled in automatically)
    aiMailSubject = 'Tagihan Layanan Dokter Darurat',
    aiMailBody    = {
        'Yth. %s,',
        '',
        'Anda telah menerima perawatan darurat di lokasi dari dokter %s.',
        'Biaya layanan sebesar Rp %s telah dipotong dari rekening bank Anda.',
        '',
        'Semoga lekas sembuh.',
        '%s',
    },
}
