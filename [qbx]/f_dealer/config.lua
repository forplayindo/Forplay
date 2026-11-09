Config = {}

Config.Title = 'Premium Deluxe Motorsport'
Config.MailFrom = 'Premium Deluxe Motorsport'

-- NPC dealer (koordinat /coords = posisi kaki). Belum dikalibrasi: berdiri di titik NPC, /vec4, tempel di sini.
Config.Ped = {
    model = 'a_m_y_business_02',
    coords = vec4(-55.61, -1098.03, 25.42, 41.16),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    distance = 2.0,   -- jarak muncul [E]
}

-- Jarak maksimal pemain dari NPC untuk beli / ambil / test drive (dicek di server)
Config.ServerRadius = 8.0

-- Preview 3D di lantai showroom (lokal, hanya terlihat oleh pemain itu sendiri)
Config.Preview = {
    coords = vec4(-45.4, -1098.0, 25.44, 120.0),   -- z = lantai (posisi kaki /coords)
    camAngle = 35.0,      -- sudut kamera dari depan kendaraan (derajat)
    camHeight = 0.9,      -- tinggi awal kamera di atas pusat kendaraan
    zoomMin = 0.65,
    zoomMax = 1.9,
}

-- Mobil pajangan di showroom (z = lantai / posisi kaki; lokal, muncul saat pemain dekat, disembunyikan saat menu dibuka)
Config.Display = {
    { coords = vec4(-45.65, -1093.66, 25.44, 69.5),   model = 'asbo' },
    { coords = vec4(-48.27, -1101.86, 25.44, 294.5),  model = 'schafter2' },
    { coords = vec4(-39.6, -1096.01, 25.44, 66.5),    model = 'greenwood' },
    { coords = vec4(-51.21, -1096.77, 25.44, 254.5),  model = 'vigero' },
    { coords = vec4(-40.18, -1104.13, 25.44, 338.5),  model = 'impaler' },
    { coords = vec4(-43.31, -1099.02, 25.44, 52.5),   model = 'bati' },
}

-- Garasi dealer: kendaraan yang dibeli / diambil muncul di titik pertama yang kosong, pemain langsung duduk di kursi sopir
Config.Spawns = {
    vec4(-61.35, -1110.31, 25.86, 71.01),
    vec4(-59.61, -1104.74, 25.85, 70.13),
    vec4(-52.96, -1113.49, 25.87, 71.53),
    vec4(-52.34, -1107.93, 25.87, 71.63),
    vec4(-44.27, -1116.36, 25.87, 71.7),
    vec4(-41.75, -1111.49, 25.87, 71.5),
}

-- Kalau kendaraan sudah tercatat tapi gagal di-spawn, dimasukkan ke garasi ini
Config.FallbackGarage = 'motelgarage'

-- Test drive: dunia terpisah (routing bucket per pemain), tanpa NPC/lalu lintas
Config.TestDrive = {
    seconds = 60,
    -- Ujung landasan LSIA, w = arah lurus landasan. BELUM DIKALIBRASI: berdiri di ujung landasan, /vec4.
    coords = vec4(-1336.0, -3044.0, 13.94, 240.0),
    bucketBase = 7000,   -- bucket = bucketBase + id pemain
    plate = 'TESTDRIV',
    exitGrace = 3,       -- detik setelah turun dari kendaraan sebelum test drive diakhiri
}

-- Kategori (urutan = urutan di menu). key = kategori qbx_core supaya default saat admin menambah kendaraan.
Config.DonationCategory = 'donasi'   -- jangan diganti: NUI juga memakai key 'donasi'
Config.Categories = {
    { key = 'compacts',       label = 'Compact' },
    { key = 'sedans',         label = 'Sedan' },
    { key = 'suvs',           label = 'SUV' },
    { key = 'coupes',         label = 'Coupe' },
    { key = 'muscle',         label = 'Muscle' },
    { key = 'sportsclassics', label = 'Sport Klasik' },
    { key = 'sports',         label = 'Sport' },
    { key = 'super',          label = 'Super' },
    { key = 'offroad',        label = 'Offroad' },
    { key = 'vans',           label = 'Van' },
    { key = 'motorcycles',    label = 'Motor' },
    { key = 'cycles',         label = 'Sepeda' },
    { key = 'donasi',         label = 'Mobil Donasi' },
}

-- Batas atas bar performa (nilai di atas ini = bar penuh)
Config.StatMax = {
    speed = 320.0,    -- km/h (perkiraan GTA)
    accel = 0.50,
    brake = 1.60,
    traction = 3.60,
}

Config.Donation = {
    maxPending = 3,          -- maksimal permintaan menunggu per karakter
    ticketPattern = '^[%w%-#_]+$',
    ticketMax = 32,
}
