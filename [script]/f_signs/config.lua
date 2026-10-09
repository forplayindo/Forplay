Config = {}

-- Ace permission yang boleh buat/edit/hapus papan nama (group.admin sudah punya 'admin' di permissions.cfg)
Config.Ace = 'admin'

-- Command untuk membuka editor
Config.Command = 'papannama'

-- Batas total papan nama tersimpan
Config.MaxSigns = 500

-- Panjang maksimal tulisan (huruf, angka, dan simbol standar keyboard)
Config.MaxTextLength = 32

-- Batas tinggi huruf kapital (meter)
Config.MinHeight = 0.1
Config.MaxHeight = 3.0

-- Batas tebal huruf LED / jarak tabung neon dari tembok (meter)
Config.MaxDepth = 0.15

-- Jarak (meter) tulisan mulai terlihat
Config.DefaultRenderDistance = 60.0
Config.MinRenderDistance = 15.0
Config.MaxRenderDistance = 200.0

-- Maksimal papan nama yang digambar bersamaan (yang terdekat didahulukan)
Config.MaxVisible = 12

-- Di bawah jarak ini detail ekstra ikut digambar (sisi tebal huruf LED, cahaya neon di tembok)
Config.DetailDistance = 25.0

-- Jumlah lapisan sisi huruf LED (makin banyak makin halus tapi makin berat)
Config.LedSideLayers = 2

-- Jam menyala (jam game). Antara Start dan Full nyalanya bertahap.
Config.Night = {
    onStart = 18.5,  -- mulai menyala 18:30
    onFull = 19.5,   -- menyala penuh 19:30
    offStart = 5.5,  -- mulai padam 05:30
    offFull = 6.5,   -- padam penuh 06:30
}

-- Cahaya yang memantul ke tembok/tanah di sekitar tulisan (paling makan GPU, jadi dibatasi)
Config.Lights = {
    max = 3,          -- hanya papan terdekat
    distance = 40.0,
    intensity = 3.0,
}

-- Sisi poligon yang digambar: 'both' (aman, 2x lebih berat), 'cw' atau 'ccw' (ringan).
-- Tes dengan command /papannama_sisi di game: pilih mode yang tulisannya tetap terlihat, lalu isi di sini.
Config.Winding = 'both'

-- Penempatan
Config.PlaceDistance = 25.0
Config.ScaleStep = 0.05       -- per scroll
Config.ScaleStepFine = 0.01   -- per scroll sambil tahan SHIFT

-- Server menolak simpan kalau posisi papan lebih jauh dari ini dari admin (anti-cheat)
Config.MaxServerDistance = 60.0

-- Pilihan warna cepat di editor
Config.Colors = {
    '#ffffff', '#fff1c1', '#ffd23f', '#ff8a00', '#ff2d2d', '#ff3d9a',
    '#c13dff', '#3d7bff', '#20d8ff', '#2dff7a', '#1a1a1a', '#b08d57',
}
