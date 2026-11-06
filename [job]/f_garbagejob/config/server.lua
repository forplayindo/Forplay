return {
    vehicle = 'master2',        -- truk scoop dari [vehicle]/f_carjob
    platePrefix = 'DKP',

    minBagsPerStop = 2,
    maxBagsPerStop = 5,
    extraBagsPerMember = 3,     -- anggota tambahan menambah kantong per titik, jadi gaji per orang ~sama dengan solo

    bagLowerWorth = 5000,       -- gaji per kantong ke kas kru, x bonus tingkat (Easy solo ±Rp 750rb/jam + paycheck pengangguran 300rb < polisi 1,4jt)
    bagUpperWorth = 9000,
    containerWorthBags = 3,     -- kontainer yang dituang = gaji 3 kantong

    minCarrySeconds = 1,        -- jeda minimal ambil -> lempar kantong (anti macro)
    minEmptySeconds = 4,        -- jeda minimal kait -> tuang kontainer

    stopDistance = 8.0,         -- jarak maksimal ke titik saat ambil kantong
    truckThrowDistance = 7.0,   -- jarak maksimal ke pusat truk saat melempar kantong (client 5.5 + toleransi)
    containerTruckDistance = 15.0,
    spawnDistance = 80.0,       -- jarak ke depo saat minta truk
    depotDistance = 25.0,       -- truk harus sedekat ini ke depo untuk selesai shift

    inviteTimeout = 60,         -- detik
    lobbyTimeout = 600,         -- kru yang belum mulai dibubarkan setelah 10 menit
    depotTimeout = 900,         -- truk tidak diambil 15 menit -> batal
    abandonDistance = 300.0,    -- semua anggota sejauh ini dari truk ...
    abandonSeconds = 300,       -- ... selama 5 menit -> batal
}
