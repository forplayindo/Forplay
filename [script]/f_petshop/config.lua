Config = {}

-- Toko hewan: penjaga toko berdiri di `coords`, pemain tekan [E] di depannya.
Config.Shop = {
    label = 'Toko Hewan',
    coords = vec4(390.06, -965.7, 28.42, 117.28),
    keeperModel = 'a_f_y_hipster_01',
    -- blip toko ada di f_blips (data/blips.lua)

    -- Tempat hewan preview 3D saat toko dibuka (hanya terlihat oleh pembeli).
    -- nil = 3 meter di depan pemain. Ambil angkanya di game dengan /petpreview (butuh Config.Debug).
    preview = nil, -- contoh: vec4(392.0, -963.5, 28.42, 300.0)
}

-- Jarak & tinggi kamera preview per jenis hewan (zoom pemain dikalikan ke `dist`).
Config.PreviewCam = {
    default   = { dist = 2.4, height = 0.45, look = 0.30 },
    dog_big   = { dist = 2.6, height = 0.55, look = 0.35 },
    dog_small = { dist = 1.7, height = 0.35, look = 0.20 },
    cat       = { dist = 1.5, height = 0.30, look = 0.15 },
    small     = { dist = 1.2, height = 0.20, look = 0.10 },
    cougar    = { dist = 3.0, height = 0.60, look = 0.40 },
    farm      = { dist = 3.6, height = 0.80, look = 0.55 },
    horse     = { dist = 5.0, height = 1.20, look = 0.90 },
    ape       = { dist = 2.6, height = 0.70, look = 0.50 },
}

-- Menyembuhkan hewan mati: HANYA petugas EMS yang sedang bertugas, lewat target "Sembuhkan Hewan"
-- pada hewan. Syaratnya sama seperti merawat pasien manusia di f_ambulancejob:
--   * membawa Tas Darurat (`bag`) yang masih berlaku (diambil di Armory EMS)
--   * obat dipotong dari Stok Gudang EMS (`stock`), bukan dari inventory petugas
Config.Vet = {
    label = 'rumah sakit',
    emsJobs = { ambulance = true },
    bag = 'tas_emergency',
    stock = { hemostatic = 1 },  -- kunci Stok Gudang f_ambulancejob (hemostatic = Kasa Hemostatik)
    duration = 8000,             -- lama proses menyembuhkan (ms)

    -- area tempat EMS boleh menyembuhkan (hewan harus dibawa ke sini). requireArea = false -> di mana saja.
    requireArea = true,
    coords = vec3(392.25, -969.03, 28.44),
    radius = 40.0,
}

-- Daftar hewan yang dijual (semua di satu toko, tampil sebagai preview 3D).
--   id        : kunci unik (disimpan di database, jangan diganti setelah ada yang beli)
--   group     : kelompok di daftar toko
--   model     : nama ped GTA (atau ped addon yang di-stream, mis. kuda di folder stream/)
--   variants  : pilihan warna { comp = komponen ped, labels = { nama warna per texture 0, 1, 2, ... } }
--               (opsional; kosong = satu warna)
--   kind      : jenis -> 'dog_big' | 'dog_small' | 'cat' | 'small' | 'cougar' | 'farm' | 'horse' | 'ape'
--               (menentukan animasi, kamera preview, gendong & kendaraan)
--   carry     : posisi gendong khusus hewan ini { offset, rot } (opsional); false = tidak bisa digendong
--   icon      : emoji di panel kontrol & daftar toko
--   attack    : true = bisa disuruh MENYERANG & JAGA AREA (lihat Config.Attack)
Config.Pets = {
    -- Anjing
    { id = 'retriever',  group = 'Anjing', label = 'Golden Retriever', model = 'a_c_retriever',  kind = 'dog_big',   price = 5000000, attack = true, icon = '🐕',
      variants = { comp = 0, labels = { 'Warna 1', 'Warna 2', 'Warna 3', 'Warna 4' } } },
    { id = 'shepherd',   group = 'Anjing', label = 'German Shepherd',  model = 'a_c_shepherd',   kind = 'dog_big',   price = 6000000, attack = true, icon = '🐕',
      variants = { comp = 0, labels = { 'Warna 1', 'Warna 2', 'Warna 3' } } },
    { id = 'husky',      group = 'Anjing', label = 'Husky',            model = 'a_c_husky',      kind = 'dog_big',   price = 6500000, attack = true, icon = '🐺',
      variants = { comp = 0, labels = { 'Warna 1', 'Warna 2', 'Warna 3' } } },
    { id = 'rottweiler', group = 'Anjing', label = 'Rottweiler',       model = 'a_c_rottweiler', kind = 'dog_big',   price = 6000000, attack = true, icon = '🐕',
      variants = { comp = 4, labels = { 'Warna 1', 'Warna 2', 'Warna 3' } } },
    { id = 'pug',        group = 'Anjing', label = 'Pug',              model = 'a_c_pug',        kind = 'dog_small', price = 3500000, attack = false, icon = '🐶',
      variants = { comp = 4, labels = { 'Warna 1', 'Warna 2', 'Warna 3', 'Warna 4' } } },
    { id = 'poodle',     group = 'Anjing', label = 'Poodle',           model = 'a_c_poodle',     kind = 'dog_small', price = 4000000, attack = false, icon = '🐩' },
    { id = 'westy',      group = 'Anjing', label = 'West Highland',    model = 'a_c_westy',      kind = 'dog_small', price = 3500000, attack = false, icon = '🐶',
      variants = { comp = 4, labels = { 'Warna 1', 'Warna 2', 'Warna 3' } } },

    -- Kucing & hewan kecil
    { id = 'cat',        group = 'Kucing & Hewan Kecil', label = 'Kucing', model = 'a_c_cat_01',   kind = 'cat',   price = 1500000, attack = false, icon = '🐈',
      variants = { comp = 0, labels = { 'Abu-abu', 'Hitam', 'Oranye' } } },
    { id = 'rabbit',     group = 'Kucing & Hewan Kecil', label = 'Kelinci', model = 'a_c_rabbit_01', kind = 'small', price = 1000000, attack = false, icon = '🐇',
      variants = { comp = 0, labels = { 'Warna 1', 'Warna 2', 'Warna 3' } } },
    { id = 'rat',        group = 'Kucing & Hewan Kecil', label = 'Tikus',  model = 'a_c_rat',      kind = 'small', price = 750000, attack = false,  icon = '🐀',
      variants = { comp = 0, labels = { 'Warna 1', 'Warna 2', 'Warna 3', 'Warna 4', 'Warna 5' } } },
    { id = 'hen',        group = 'Kucing & Hewan Kecil', label = 'Ayam',   model = 'a_c_hen',      kind = 'small', price = 500000, attack = false,  icon = '🐔' },

    -- Ternak (terlalu besar untuk digendong / naik mobil)
    { id = 'Pig',        group = 'Ternak', label = 'Babi',      model = 'a_c_pig',  kind = 'farm', price = 5000000, attack = false,  icon = '🐖', carry = false },
    { id = 'boar',       group = 'Ternak', label = 'Babi Hutan', model = 'a_c_boar', kind = 'farm', price = 7500000, attack = false,  icon = '🐗', carry = false },
    { id = 'cow',        group = 'Ternak', label = 'Sapi',      model = 'a_c_cow',  kind = 'farm', price = 15000000, attack = false, icon = '🐄', carry = false },
    { id = 'deer',       group = 'Ternak', label = 'Rusa',      model = 'a_c_deer', kind = 'farm', price = 15000000, attack = false, icon = '🦌', carry = false },

    -- Kuda (model di stream/flight_animals, GPL-3)
    { id = 'donkey',      group = 'Kuda', label = 'Keledai',       model = 'Donkey',     kind = 'horse', price = 20000000, attack = false, icon = '🫏', carry = false },
    { id = 'horse_young', group = 'Kuda', label = 'Kuda Muda',     model = 'Younghorse', kind = 'horse', price = 35000000, attack = false, icon = '🐎', carry = false },
    { id = 'horse_full',  group = 'Kuda', label = 'Kuda Ras Murni', model = 'Fullhorse', kind = 'horse', price = 45000000, attack = false, icon = '🐎', carry = false },
    { id = 'horse_range', group = 'Kuda', label = 'Kuda Padang',   model = 'Rangehorse', kind = 'horse', price = 60000000, attack = false, icon = '🐎', carry = false },

    -- Hewan liar
    { id = 'cougar',     group = 'Hewan Liar', label = 'Singa Gunung', model = 'a_c_mtlion', kind = 'cougar', price = 25000000, attack = true, icon = '🐆' },
    { id = 'chimp',      group = 'Hewan Liar', label = 'Simpanse',     model = 'a_c_chimp',  kind = 'ape',    price = 30000000, attack = false, icon = '🐒', carry = false },
    { id = 'rhesus',     group = 'Hewan Liar', label = 'Monyet',       model = 'a_c_rhesus', kind = 'ape',    price = 20000000, attack = false, icon = '🐵', carry = false },
}

-- Hewan lama yang dulu dijual per warna -> sekarang satu hewan dengan pilihan warna.
-- Data di database dipindahkan otomatis saat server start: [id lama] = { id baru, nomor warna }
Config.LegacyPets = {
    cat_grey   = { 'cat', 0 },
    cat_black  = { 'cat', 1 },
    cat_orange = { 'cat', 2 },
}

-- Posisi gendong default per jenis (dipakai kalau hewan tidak punya `carry` sendiri).
-- Offset terhadap badan pemain (pinggul): x = kanan, y = depan, z = atas. rot z 90 = melintang di lengan.
Config.Carry = {
    dog_big   = { offset = vec3(0.0, 0.48, 0.18), rot = vec3(0.0, 0.0, 90.0) },
    dog_small = { offset = vec3(0.0, 0.40, 0.25), rot = vec3(0.0, 0.0, 90.0) },
    cat       = { offset = vec3(0.0, 0.40, 0.25), rot = vec3(0.0, 0.0, 90.0) },
    small     = { offset = vec3(0.0, 0.35, 0.30), rot = vec3(0.0, 0.0, 90.0) },
    cougar    = { offset = vec3(0.0, 0.55, 0.15), rot = vec3(0.0, 0.0, 90.0) },
}

-- Emote elus (ox_target "Elus" pada hewan). `player` = animasi pemain, `pet` = animasi hewan
-- (hanya diputar untuk hewan milik sendiri), `offset` = posisi pemain relatif ke hewan.
Config.Petting = {
    duration = 6000,
    dog_big = {
        player = { 'creatures@rottweiler@tricks@', 'petting_franklin' },
        pet    = { 'creatures@rottweiler@tricks@', 'petting_chop' },
        offset = vec3(0.0, 0.85, 0.0),
    },
    default = {
        player = { 'amb@medic@standing@kneel@base', 'base' },
        offset = vec3(0.0, 0.75, 0.0),
    },
}

-- Posisi hewan di kursi kendaraan, relatif ke titik kursi: vec4(x kanan, y depan, z atas, rotasi).
-- Atur langsung di game dengan /petseat x y z (butuh Config.Debug = true), lalu salin angkanya ke sini.
Config.VehicleSeat = {
    default   = vec4(0.0, 0.05, 0.25, 0.0),
    dog_big   = vec4(0.0, -0.10, 0.30, 0.0), -- disetel di game dengan /petseat
    dog_small = vec4(0.0, 0.10, 0.30, 0.0),
    cat       = vec4(0.0, 0.10, 0.30, 0.0),
    small     = vec4(0.0, 0.10, 0.35, 0.0),
}

-- Cara hewan naik kendaraan (otomatis saat hewan MENGIKUTI dan pemiliknya masuk kendaraan,
-- lalu ikut turun saat pemiliknya keluar):
--   'scene'    = jalan ke pintu lalu melompat masuk dengan animasi (anjing besar)
--   'teleport' = jalan ke pintu lalu langsung duduk di kursi
--   false      = tidak bisa naik kendaraan (ditinggal, menyusul saat pemilik turun)
Config.VehicleEnter = {
    dog_big   = 'scene',
    dog_small = 'teleport',
    cat       = 'teleport',
    small     = 'teleport',
    cougar    = 'teleport',
    farm      = false,
    horse     = false,
    ape       = false,
}
Config.BoardTimeout = 8000 -- ms; kalau hewan belum sampai pintu (atau mobil sudah jalan), langsung didudukkan

-- true = perintah /petseat aktif untuk menyetel posisi duduk di kendaraan. Matikan setelah selesai.
Config.Debug = true

-- Animasi per jenis (animasi bawaan GTA). `dead` = pose lemas saat mati / digendong
-- (kalau kosong dipakai `lay`, lalu `sit`). `wake` = animasi bangun saat baru dipanggil.
Config.Anims = {
    dog_big   = { sit  = { 'creatures@rottweiler@amb@world_dog_sitting@base', 'base' },
                  lay  = { 'creatures@rottweiler@amb@sleep_in_kennel@', 'sleep_in_kennel' },
                  wake = { 'creatures@rottweiler@amb@sleep_in_kennel@', 'exit_kennel' } },
    dog_small = { sit  = { 'creatures@pug@amb@world_dog_sitting@base', 'base' },
                  wake = { 'creatures@pug@amb@world_dog_sitting@exit', 'exit' } },
    cat       = { sit  = { 'creatures@cat@amb@world_cat_sleeping_ground@base', 'base' },
                  lay  = { 'creatures@cat@amb@world_cat_sleeping_ground@base', 'base' },
                  wake = { 'creatures@cat@amb@world_cat_sleeping_ground@exit', 'exit' } },
    cougar    = { lay  = { 'creatures@cougar@amb@world_cougar_rest@base', 'base' } },
}

-- Trik di panel hewan (per jenis). loop = terus sampai diberi perintah lain,
-- tanpa loop = sekali lalu kembali ke perintah sebelumnya. bark = sekalian bersuara.
Config.Tricks = {
    dog_big = {
        { id = 'beg',  label = 'Minta',    icon = '🙏', anim = { 'creatures@rottweiler@tricks@', 'beg_loop' }, loop = true },
        { id = 'paw',  label = 'Salaman',  icon = '🤝', anim = { 'creatures@rottweiler@tricks@', 'paw_right_loop' }, loop = true },
        { id = 'bark', label = 'Gonggong', icon = '🔊', anim = { 'creatures@rottweiler@amb@world_dog_barking@idle_a', 'idle_a' }, bark = true },
        { id = 'spin', label = 'Berputar', icon = '🌀', anim = { 'creatures@retriever@amb@world_dog_barking@idle_a', 'idle_c' } },
    },
    dog_small = {
        { id = 'bark', label = 'Gonggong', icon = '🔊', anim = { 'creatures@pug@amb@world_dog_barking@idle_a', 'idle_a' }, bark = true },
    },
}

-- Lempar bola: pemilik melempar bola (harus punya item `item`, tidak berkurang), anjing mengejar
-- dan membawanya kembali. `pickup` = animasi menggigit bola per jenis (opsional).
Config.Fetch = {
    item = 'WEAPON_BALL',
    prop = 'prop_tennis_ball',
    timeout = 30000,
    kinds = {
        dog_big   = { pickup = { 'creatures@rottweiler@move', 'fetch_pickup' } },
        dog_small = {},
    },
}

-- Makanan hewan (item ox_inventory). Dijual di toko yang sama, tab Perlengkapan.
Config.Food = {
    { item = 'pet_food', label = 'Makanan Hewan', price = 15000, hunger = 40 },
}

-- Minuman hewan (item ox_inventory). Diberikan lewat target "Beri ..." pada hewan sendiri.
Config.Drinks = {
    { item = 'pet_water', label = 'Air Minum Hewan', price = 10000, thirst = 40 },
}

-- Perlengkapan lain yang dijual di tab Perlengkapan (bukan makanan).
Config.Supplies = {
    { item = 'WEAPON_BALL', label = 'Bola Tenis', price = 25000, icon = '🎾', desc = 'Untuk main lempar bola' },
    { item = 'pet_leash',   label = 'Tali Anjing', price = 50000, icon = '🦮', desc = 'Pasang lewat Menu Hewan' },
}

-- Tali anjing: dipasang/dilepas dari Menu Hewan, butuh item `item` (tidak berkurang).
-- Talinya terlihat oleh semua pemain (digambar dari tangan pemilik ke leher hewan).
Config.Leash = {
    item = 'pet_leash',
    kinds = { dog_big = true, dog_small = true, cat = true, small = true },
    color = { 120, 82, 45 }, -- warna tali (RGB)
    width = 0.025,           -- tebal tali (meter); 0.02 = tipis, 0.04 = tebal
}

-- Hewan TIDAK dibeli: pemain mencoba dulu, lalu mengajukan kepemilikan yang disetujui Admin / Owner
-- di /admin → Pengajuan Hewan (Support tidak bisa). `price` di Config.Pets tidak dipakai lagi.
Config.Trial = {
    minutes = 5,             -- lama mencoba hewan, setelah itu otomatis kembali ke toko
    warnSeconds = 60,        -- peringatan sebelum waktu coba habis
}

Config.MaxPets = 5           -- maksimal hewan yang dimiliki satu karakter (semuanya bisa dipanggil bersamaan)
Config.NameMaxLength = 20

-- Serang & jaga area. Hewan mana yang bisa diatur lewat `attack = true` di Config.Pets.
Config.Attack = {
    enabled  = true,
    players  = true,            -- boleh menyerang pemain
    npcs     = true,            -- boleh menyerang NPC (hanya lewat perintah Serang, jaga area hanya pemain)
    jobs     = false,           -- false = semua pemilik boleh; atau daftar job, contoh { 'police' }
    range    = 40.0,            -- jarak maksimal pilih target / kejar (meter)
    maxTime  = 20,              -- detik; serangan berhenti otomatis setelah ini
    stopWhenDown = true,        -- berhenti menyerang saat target jatuh / pingsan
    guardRadius  = { min = 1, max = 10, default = 5 }, -- meter, diisi angka di panel
    guardCooldown = 10,         -- detik sebelum pemain yang sama diserang lagi saat jaga area
    -- job yang bisa dicentang di Daftar Teman (tidak diserang saat jaga area)
    friendJobs = { 'police', 'ambulance' },
}

-- Lapar & haus turun HANYA selama hewan sedang dipanggil (yang disembunyikan tidak dihitung).
Config.Needs = {
    hours = 8,               -- dari 100 sampai 0 dalam sekian jam online
    tickMinutes = 5,         -- tiap berapa menit dihitung (server)
    starveDamage = 10,       -- kalau lapar ATAU haus 0, nyawa berkurang sekian per tick sampai mati
    warnAt = 20,             -- peringatan "lapar" / "haus" di bawah angka ini
}
