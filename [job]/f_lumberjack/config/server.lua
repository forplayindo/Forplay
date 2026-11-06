return {
    platePrefix = 'KAYU',       -- model truk: config.shared trucks (solo Biff / kru flatbed)

    chainsawTrees = 50,         -- chainsaw rusak setelah sekian pohon (memotong batang tidak mengurangi)
    cutSeconds = 10,            -- lama menebang (client); server menolak jika lebih cepat dari ini - 1 dtk
    buckSeconds = 8,            -- lama memotong batang jadi potongan
    treeRespawn = 20 * 60,      -- pohon tumbuh lagi setelah 20 menit
    reserveSeconds = 30,        -- kunci pohon / batang untuk yang sedang memotong selama sekian detik
    minCarryMs = 1000,          -- kayu harus dipanggul minimal selama ini sebelum masuk bak

    unloadMsPerLog = 2500,      -- tiap sekian ms 1 batang dari bak masuk conveyor (truk dikunci selama bongkar)

    npcDistance = 4.0,          -- jarak ke NPC Mandor untuk menu / chainsaw / Gudang Kayu
    pileDistance = 5.0,         -- jarak pemain ke tumpukan papan sawmill (Pindahkan papan)
    pileTruckDistance = 20.0,   -- truk kru harus sedekat ini dari tumpukan papan
    depotDistance = 20.0,       -- truk ke parkir markas untuk Bongkar papan
    treeDistance = 8.0,         -- jarak penebang ke pohon
    itemDistance = 6.0,         -- jarak pemain ke potongan kayu di tanah (ambil)
    trunkDistance = 9.0,        -- jarak pemain ke titik tengah batang besar (potong / angkat), batangnya panjang
    liftPartnerDistance = 16.0, -- batang berdua: kedua pengangkat harus sedekat ini saat memasukkan ke bak
    loadDistance = 10.0,        -- jarak pemain ke tengah truk saat memasukkan (harus di belakang truk; flatbed panjang)
    stationDistance = 9.0,      -- truk ke titik stasiun olah

    inviteTimeout = 60,         -- detik
    lobbyTimeout = 600,         -- kru yang belum mulai dibubarkan setelah 10 menit
    abandonDistance = 300.0,    -- semua anggota sejauh ini dari truk ...
    abandonSeconds = 300,       -- ... selama 5 menit -> batal
    syncDistance = 200.0,       -- pemain sejauh ini dari pohon / sawmill ikut melihat animasi & suara
}
