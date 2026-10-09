return {
    -- Tempat karakter berdiri saat memilih (bandara) dan posisi kamera
    preview = {
        ped = vec4(-1040.77, -2742.8, 12.94, 327.41),
        cam = vec4(-1039.58, -2740.95, 13.99, 147.41), -- z dinaikkan 0.15 (dulu 13.79)
        fov = 90.0,
    },

    -- Pilihan lokasi spawn untuk karakter yang sudah ada
    -- ("Lokasi Terakhir" dan rumah milik karakter ditambahkan otomatis)
    spawns = {
        { label = 'Legion Square', coords = vec4(195.17, -933.77, 29.7, 144.5) },
        { label = 'Paleto Bay', coords = vec4(80.35, 6424.12, 31.67, 45.5) },
    },

    -- Karakter baru selalu muncul di defaultSpawn qbx_core (config/shared.lua)

    -- Hanya untuk tampilan form; server tetap memvalidasi (qbx_core config/server.lua)
    birthdate = { min = '1900-01-01', max = '2006-12-31' },

    modelTimeout = 30000, -- ms; PC lambat butuh waktu lama untuk memuat model
}
