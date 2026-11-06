-- Konfigurasi f_crew (server). Gang dibuat pemain lewat app Crew di f_phone.
return {
    -- Batas anggota: default saat gang dibuat, boss bisa ubah dalam rentang min-max.
    MaxMembersDefault = 20,
    MaxMembersMin = 5,
    MaxMembersMax = 50,

    -- Panjang teks.
    NameMin = 3,
    NameMax = 24,
    DescMax = 140,
    MessageMax = 140,
    AnnounceMax = 300,
    GradeNameMax = 16,

    -- Waktu (jam/hari).
    CooldownHours = 24,     -- setelah keluar / di-kick / bubar, sebelum boleh buat atau gabung gang lagi
    ApplicationDays = 3,    -- lamaran & undangan hangus setelah ini
    InactiveDays = 30,      -- gang tanpa anggota login selama ini dibubarkan saat server start
    BankLogDays = 30,       -- riwayat kas lebih tua dari ini dihapus saat server start

    -- Rank bawaan (0-3). Nama bisa diganti boss; flag tidak bisa.
    Grades = {
        [0] = { name = 'Anggota' },
        [1] = { name = 'Senior' },
        [2] = { name = 'Wakil', bankAuth = true },
        [3] = { name = 'Boss', isboss = true, bankAuth = true },
    },
    DeputyGrade = 2, -- wakil ke atas: lamaran, undang, rank, kick, kas tarik/transfer, pengumuman
    BossGrade = 3,

    -- Channel radio otomatis per gang (dikunci di server lewat pma-voice).
    RadioMin = 300,
    RadioMax = 499,

    -- Kendaraan di garasi gang dipindah ke sini saat gang bubar.
    ImpoundGarage = 'impoundlot',

    -- Batas transaksi kas sekali jalan.
    BankMax = 500000000,
    -- Saldo maksimal kas gang (setoran yang melewati batas ini ditolak).
    BalanceMax = 500000000,

    LeaderboardLimit = 50,
    BankLogLimit = 30,

    -- Nama gang tidak boleh mengandung kata ini (huruf kecil). Nama job juga otomatis ditolak.
    BlockedWords = {
        'admin', 'staff', 'owner', 'developer', 'moderator',
        'polisi', 'police', 'lspd', 'bcso', 'sheriff', 'fib', 'noose',
        'ems', 'ambulance', 'dokter', 'pemerintah', 'government', 'goverment',
        'anjing', 'bangsat', 'kontol', 'memek', 'ngentot', 'bajingan', 'babi', 'tolol', 'goblok',
        'nigga', 'nigger', 'fuck', 'bitch',
    },

    -- Warna default kartu gang.
    DefaultColor = '#8e44ad',

    -- Log: selalu tercetak di console server (txAdmin). Isi URL webhook Discord kalau mau dikirim juga.
    Webhook = nil,

    -- Gang Wars (perebutan wilayah). Menu /peranggang + radial. Hanya gang bertag 'gang' yang ikut.
    -- Wilayah (poligon, minimal peserta, reward) disimpan di tabel crew_turf_zones dan diatur admin
    -- lewat menu. Alur: Boss/Wakil klik Kuasai/Rebut -> syarat dicek SAAT ITU saja (anggota online
    -- penyerang & pemilik >= minimal peserta wilayah) -> persiapan PrepMinutes (gang lain bisa Join)
    -- -> perang WarMinutes -> poin terbanyak menguasai wilayah + dapat reward. Setelah setuju, perang
    -- tetap jalan walau anggota logout / crash. Satu gang hanya bisa ikut satu perang sekaligus.
    Turf = {
        Enabled = true,
        TickSeconds = 15,       -- hitung poin hadir + kirim scoreboard + simpan ke database
        AdminAce = 'admin',     -- ACE untuk tambah / edit / hapus wilayah di menu

        PrepMinutes = 1,       -- persiapan sebelum perang (gang lain bisa Join)
        WarMinutes = 10,
        MaxWars = 3,            -- perang bersamaan di seluruh kota (persiapan ikut dihitung)
        DefaultMinPlayers = 5,  -- minimal peserta online per gang (default form wilayah baru)
        WarCooldownMinutes = 24 * 60, -- wilayah yang baru selesai diperebutkan tidak bisa direbut lagi selama ini

        HistoryLimit = 20,      -- riwayat perang yang disimpan; sisanya dihapus
        RewardKeepDays = 7,     -- reward yang SUDAH diambil dihapus dari daftar setelah sekian hari
        MaxRewardItems = 10,    -- item reward per wilayah

        -- Pengumuman chat (f_chat tab Pengumuman). Tidak dikirim ke job bertipe ini (cek job, bukan duty).
        ChatHideJobTypes = { leo = true, ems = true },
        ChatTag = 'GANG WARS',
        ChatColor = '#E5484D',

        -- Poin perebutan (hanya dihitung selama masa perebutan, bukan saat persiapan)
        WarPresencePoints = 1,  -- per menit untuk tiap anggota yang hidup di zona
        WarKillPoints = 10,     -- membunuh anggota gang lain di zona itu
        -- graffiti perang (f_graffiti): semprot di wilayah = +poin; dibersihkan gang peserta = -poin
        -- (pembersih netral / polisi tidak mengubah poin). Graffiti perang dihapus saat perang selesai.
        WarGraffitiPoints = 1,
        -- cooldown = menit per pemain per aktivitas
        Activities = {
            drugselling = { points = 3, cooldown = 1 }, -- jual narkoba di pojokan (f_drugs)
            carjacking = { points = 5, cooldown = 10 }, -- hotwire mobil orang (f_vehiclekeys)
        },

        -- Mode "Rebut Bendera" (dipilih admin per wilayah). Saat perang: bendera musuh dicabut (tahan E),
        -- lalu gang peserta menancapkan benderanya (pegang item, tahan E). Bendera yang berdiri saat
        -- waktu habis = pemenang; titik kosong = pemilik lama tetap menang. Poin kill/hadir tidak dipakai.
        -- Item hanya dari admin (tab Bendera di /peranggang) atau mafia. Bendera yang dicabut kembali ke Boss.
        Flag = {
            Item = 'bendera_gang',
            PullSeconds = 15,           -- tahan E untuk mencabut bendera musuh
            PlantSeconds = 20,          -- tahan E untuk menancapkan bendera sendiri
            ActionRadius = 2.5,         -- jarak maksimal dari tiang (meter, dicek server)
            ContestRadius = 10.0,       -- musuh hidup dalam radius ini = progres berhenti
            DefaultModel = 'prop_flag_us',  -- bendera tertancap untuk gang tanpa model addon (sementara: bendera Indonesia)
            DefaultHandModel = 'prop_golfflag', -- bendera di tangan untuk gang tanpa model addon
        },
    },
}
