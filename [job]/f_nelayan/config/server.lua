return {
    -- jenis ikan & harga per peti di Pasar Ikan. 1 tarikan = 1 peti dengan 1 jenis ikan acak.
    -- ±32 peti/jam: rata-rata spot dekat ±Rp 35rb/peti (±1,1 jt/jam), spot jauh ±Rp 43rb (±1,4 jt/jam)
    fish = {
        kembung = { label = 'Ikan Kembung', price = 30000 },
        tongkol = { label = 'Ikan Tongkol', price = 38000 },
        tenggiri = { label = 'Ikan Tenggiri', price = 42000 },
        kakap = { label = 'Ikan Kakap Merah', price = 52000 },
        tuna = { label = 'Ikan Tuna Sirip Kuning', price = 90000, rare = true },
    },
    -- peluang (bobot) per jenis spot
    catchTable = {
        near = { { 'kembung', 60 }, { 'tongkol', 30 }, { 'kakap', 10 } },
        far = { { 'tongkol', 45 }, { 'tenggiri', 35 }, { 'kakap', 17 }, { 'tuna', 3 } },
    },
    perfectBonus = 0.10,        -- tarikan sempurna (3/3): harga peti +10%
    minHits = 2,                -- tarik-ulur: hijau kurang dari ini (merah 2x+) = ikan lepas, jaring tidak aus

    soakMin = 25,               -- detik jaring direndam sebelum bisa ditarik
    soakMax = 40,
    haulMinSeconds = 5,         -- tarik jaring minimal selama ini (anti macro)
    sortSeconds = 4,            -- jeda minimal tarik -> ikan masuk peti (progress klien 5 detik)
    unloadSeconds = 3,
    minCarrySeconds = 1,

    castMaxSpeed = 2.5,         -- m/s, kapal harus hampir berhenti saat tebar
    onBoatDistance = 22.0,      -- pemain sedekat ini ke pusat tug (tug panjang 31 m)
    castDistance = 30.0,        -- titik jaring maksimal sejauh ini dari pusat tug
    haulDistance = 45.0,        -- tug harus sedekat ini ke jaring untuk menarik
    netBreakDistance = 120.0,   -- tug sejauh ini dari jaring -> jaring putus
    pierDistance = 4.0,
    truckDistance = 6.0,        -- ke pusat bison (bak + toleransi)
    marketDistance = 5.0,
    truckMarketDistance = 40.0, -- bison diparkir sedekat ini ke pasar untuk menurunkan peti
    officeDistance = 6.0,
    spawnClear = 3.0,           -- titik spawn kendaraan harus kosong sejauh ini (tug x3)
    truckReuseDistance = 150.0, -- bison kosong lebih jauh dari ini saat bongkar berikutnya -> diganti baru di dermaga

    inviteTimeout = 60,         -- detik
    lobbyTimeout = 600,         -- kru yang belum melaut dibubarkan setelah 10 menit

    -- anti dibawa jalan-jalan
    returnSeconds = 300,        -- bagian habis terjual -> bison wajib kembali ke parkiran dermaga dalam 5 menit
    returnRadius = 25.0,        -- bison sedekat ini ke truckSpawn & tanpa sopir = dikembalikan (hilang)
    returnFine = 200000,        -- tidak dikembalikan / dibawa keluar jalur saat kosong = denda
    truckRouteMargin = 300.0,   -- bison harus sedekat ini ke jalur dermaga <-> Pasar Ikan
    truckOutsideGrace = 30,     -- detik di luar jalur sebelum bison dihapus
    tugRouteMargin = 800.0,     -- tug harus sedekat ini ke jalur dermaga <-> spot ikan
    tugOutsideGrace = 60,       -- detik di luar area sebelum kerja dibatalkan

    abandonDistance = 300.0,    -- pemain sejauh ini dari tug DAN bison ...
    abandonSeconds = 300,       -- ... selama 5 menit -> kerja batal
}
