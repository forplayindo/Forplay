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

    -- Wilayah (turf war). Zona ada di shared/zones.lua. Hanya gang bertag 'gang' yang ikut.
    -- Alur: di zona gang lain / bebas selama PromptSeconds -> pilihan [J] Rebut / [X] Abaikan ->
    -- persiapan PrepMinutes (tetap di zona) -> perebutan WarMinutes -> poin terbanyak menguasai zona.
    -- Zona tetap milik gang sampai direbut gang lain. Semua dihitung di server.
    Turf = {
        Enabled = true,
        TickSeconds = 15,       -- cek posisi anggota gang online + status di layar + simpan ke database

        PromptSeconds = 60,     -- lama di zona sebelum pilihan Rebut / Abaikan muncul
        PrepMinutes = 2,        -- TEST: kembalikan ke 10 setelah selesai tes. Persiapan sebelum perebutan.

        -- Perebutan
        WarMinutes = 10,
        MaxWars = 3,            -- perebutan bersamaan di seluruh kota
        MinDefenders = 2,       -- zona milik gang hanya bisa direbut kalau anggota pemilik online sebanyak ini
        WarCooldownMinutes = 24 * 60, -- zona yang baru selesai diperebutkan tidak bisa direbut lagi selama ini

        -- Poin perebutan (hanya dihitung selama masa perebutan, bukan saat persiapan)
        WarPresencePoints = 1,  -- per menit untuk tiap anggota yang hidup di zona
        WarKillPoints = 10,     -- membunuh anggota gang lain di zona itu
        -- cooldown = menit per pemain per aktivitas
        Activities = {
            drugselling = { points = 3, cooldown = 1 }, -- jual narkoba di pojokan (f_drugs)
            carjacking = { points = 5, cooldown = 10 }, -- hotwire mobil orang (f_vehiclekeys)
        },

        -- Blip map (hanya terlihat anggota gang bertag 'gang').
        BlipAlpha = 60,         -- transparansi kotak zona (0-255); kecil = jalan di minimap tetap terlihat
        LabelBlips = true,      -- ikon kecil di tengah zona berisi nama zona + gang pemilik
        LabelSprite = 84,
        LabelScale = 0.6,
    },
}
