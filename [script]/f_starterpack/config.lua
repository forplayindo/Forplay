Config = {}

-- NPC petugas starterpack
Config.Ped = {
    model = 'a_m_y_business_03',
    coords = vec4(-1040.479126, -2731.582520, 20.164062, 238.110229),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    label = 'Klaim Starterpack',
    icon = 'fa-solid fa-gift',
    distance = 2.0,
}

-- Jarak maksimal pemain dari NPC saat klaim (dicek di server)
Config.ClaimRadius = 5.0

-- Item yang diberikan (sekali per karakter)
Config.Items = {
    { item = 'cafe_burger',      amount = 5 },
    { item = 'cafe_orangejuice', amount = 5 },
    { item = 'phone',            amount = 1 },
}

-- Kendaraan pertama. Model harus terdaftar di qbx_core shared/vehicles.lua
-- (ganti dengan model addon nanti). Plat dari f_vehicles, kunci fisik dari f_vehiclekeys.
Config.Vehicle = {
    enabled = true,
    model = 'asbo', -- sementara, ganti dengan mobil addon (wald2018 belum terdaftar di qbx_core)
    fuel = 80.0,
    warp = true, -- pemain langsung duduk di kursi pengemudi
    spawns = {
        vec4(-1039.02, -2727.53, 19.65, 243.17),
        vec4(-1043.3, -2725.09, 19.65, 241.12),
        vec4(-1047.57, -2722.66, 19.65, 240.54),
        vec4(-1034.38, -2719.0, 19.65, 240.52),
        vec4(-1038.51, -2716.53, 19.64, 240.34),
    },
}

-- Pesan sambutan sebelum klaim
Config.Welcome = {
    title = 'Bumi Kita Roleplay',
    message = 'Selamat Datang di BUMI KITA!\n\nJangan ragu untuk bertanya kepada penduduk setempat jika kamu membutuhkan bantuan atau ingin mengetahui lebih banyak tentang kehidupan di sini. Kami berharap kamu menemukan petualangan yang tak terlupakan di kota ini dan menjadi bagian dari komunitas yang hangat dan ramah.\n\nKunjungi Kantor Pemerintah untuk mendapatkan kartu kependudukan anda.',
}

Config.Text = {
    already = 'Kamu sudah pernah mengambil starterpack',
    success = 'Starterpack diterima, selamat menikmati!',
    vehicle = 'Kendaraan pertamamu (%s) sudah siap, kuncinya ada di tasmu',
    canceled = 'Klaim starterpack dibatalkan',
    too_far = 'Kamu terlalu jauh dari petugas',
    in_vehicle = 'Turun dari kendaraan dulu',
    no_spawn = 'Area parkir terhalang kendaraan lain, coba lagi sebentar',
    bad_model = 'Kendaraan starter belum terdaftar, hubungi admin',
    busy = 'Tunggu sebentar...',
}
