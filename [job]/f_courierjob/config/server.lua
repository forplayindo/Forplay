return {
    vehicle = 'boxville2',      -- Boxville livery GoPostal
    platePrefix = 'POS',

    -- gaji ke kas kru (dibagi rata), x bonus tingkat:
    -- Easy ±750rb / Medium ±890rb / Hard ±1,3jt per orang per jam (perkiraan, setel setelah tes)
    packageWorth = 15000,       -- per paket kecil, paket besar = 2x
    kmWorth = 15000,            -- per km jarak titik ke titik (garis lurus), x jumlah anggota

    signChance = 0.5,           -- peluang penerima minta tanda tangan
    signSeconds = 3,
    minCarrySeconds = 1,        -- jeda minimal angkat -> masukkan / serahkan (anti macro)

    groundDistance = 4.0,       -- jarak ke paket di tanah / tumpukan
    vanDistance = 8.0,          -- jarak ke pusat van (pintu belakang + toleransi)
    vanStopDistance = 40.0,     -- van harus diparkir sedekat ini ke titik untuk menurunkan paket
    deliverDistance = 35.0,     -- jarak ke titik saat menyerahkan (penerima berdiri di trotoar terdekat, maks 30 m dari titik)
    partnerDistance = 4.0,      -- angkat belakang paket besar: sedekat ini ke rekan
    spawnDistance = 80.0,       -- jarak ke depot saat minta van
    depotDistance = 25.0,       -- van harus sedekat ini ke depot untuk selesai rute
    menuDistance = 30.0,        -- menu lanjut kerja di depot

    inviteTimeout = 60,         -- detik
    lobbyTimeout = 600,         -- kru yang belum mulai di balai kota dibubarkan setelah 10 menit
    depotLobbyTimeout = 120,    -- setelah rute selesai: 2 menit untuk lanjut, lewat itu kru bubar
    depotTimeout = 900,         -- van tidak diambil 15 menit -> batal
    abandonDistance = 300.0,    -- semua anggota sejauh ini dari van ...
    abandonSeconds = 300,       -- ... selama 5 menit -> batal
}
