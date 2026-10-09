-- Editor garasi in-game (/garasi): tandai area & titik keluar kendaraan, langsung aktif tanpa restart.
return {
    command = 'garasi', -- /garasi, hanya untuk editorLicenses di config/server.lua (tidak dikirim ke client)

    grades = { 0, 1, 2, 3, 4 }, -- 0 = semua grade; angka lain = grade itu ke atas

    defaultHeight = 6.0, -- tinggi zona default (meter)
    maxPoints = 24,      -- titik sudut area maksimal
    maxSpawns = 12,      -- titik keluar kendaraan maksimal
    maxSize = 200.0,     -- jarak maksimal titik dari tengah area (meter)
    spawnRange = 80.0,   -- titik keluar kendaraan maksimal sejauh ini dari tengah area

    -- Kendaraan di garasi yang dihapus dipindah ke garasi ini (sesuai jenis)
    fallback = {
        car = 'motelgarage',
        air = 'intairport',
        sea = 'lsymc',
    },

    -- Tombol saat menandai (kode kontrol GTA)
    keys = {
        pointHere = 38,   -- E: titik di posisi kaki
        pointAim = 24,    -- klik kiri: titik di tempat yang dibidik kamera
        spawn = 47,       -- G: titik keluar kendaraan (posisi + arah hadap)
        undo = 194,       -- Backspace: hapus titik terakhir
        finish = 191,     -- Enter: selesai
        cancel = 200,     -- Esc: batal
    },
}
