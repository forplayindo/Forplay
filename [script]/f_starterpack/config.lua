Config = {}

-- NPC petugas starterpack (koordinat dari /coords, z = posisi kaki)
Config.Ped = {
    model = 'a_m_y_business_03',
    coords = vec4(-1031.85, -2736.67, 19.17, 99.57),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    label = 'Klaim Starterpack',
    icon = 'fa-solid fa-gift',
    distance = 2.0,
}

-- Jarak maksimal pemain dari NPC saat klaim (dicek di server)
Config.ClaimRadius = 5.0

-- Item yang diberikan (sekali per karakter). HP & KTP Sementara sudah diberi qbx_core saat buat karakter.
Config.Items = {
    { item = 'cafe_nasigoreng',  amount = 5 },
    { item = 'cafe_orangejuice', amount = 5 },
}

-- Kendaraan pertama. Model harus terdaftar di qbx_core shared/vehicles.lua.
-- Plat dari f_vehicles (F 1234 R), kunci fisik dari f_vehiclekeys, pemain langsung duduk di kursi sopir.
Config.Vehicle = {
    enabled = true,
    model = 'asbo', -- sementara, ganti dengan mobil addon nanti
    fuel = 100.0,
    -- Dipakai titik pertama yang kosong. w = arah hadap kendaraan (ubah kalau mobil menghadap ke arah yang salah).
    spawns = {
        vec4(-1041.93, -2676.68, 12.83, 317.5),
        vec4(-1044.39, -2674.32, 12.83, 317.5),
        vec4(-1046.76, -2672.23, 12.83, 317.5),
    },
}

-- Teks sambutan di NUI
Config.Welcome = {
    title = 'Selamat Datang di 4PLAY',
    message = 'Ini bekal awal untuk memulai hidupmu di kota. Jangan ragu bertanya ke warga lain kalau butuh bantuan. KTP Sementara-mu berlaku 1 hari, segera buat KTP di Balai Kota.',
}

Config.Text = {
    already = 'Kamu sudah pernah mengambil starterpack',
    success = 'Starterpack diterima, selamat menikmati!',
    vehicle = 'Kendaraan pertamamu (%s) sudah siap, kuncinya ada di tasmu',
    too_far = 'Kamu terlalu jauh dari petugas',
    in_vehicle = 'Turun dari kendaraan dulu',
    no_space = 'Tasmu penuh, kosongkan dulu sebagian',
    no_spawn = 'Area parkir terhalang kendaraan lain, coba lagi sebentar',
    bad_model = 'Kendaraan starter belum terdaftar, hubungi admin',
    busy = 'Tunggu sebentar...',
    failed = 'Klaim gagal, hubungi admin',
}
