Config = {}

-- Toko hewan: penjaga toko berdiri di `coords`, pemain tekan [E] di depannya.
Config.Shop = {
    label = 'Toko Hewan',
    coords = vec4(390.06, -965.7, 28.42, 117.28),
    keeperModel = 'a_f_y_hipster_01',
    -- blip toko ada di f_blips (data/blips.lua)
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

-- Daftar hewan yang dijual. Tambah hewan baru cukup dengan menambah baris di sini.
--   id        : kunci unik (disimpan di database, jangan diganti setelah ada yang beli)
--   model     : nama ped GTA (atau ped addon yang sudah di-stream)
--   texture   : variasi warna (opsional, contoh kucing a_c_cat_01 punya 0/1/2)
--   kind      : jenis animasi -> 'dog_big' | 'dog_small' | 'cat' | 'cougar' | 'none'
--   carry     : posisi gendong khusus hewan ini { offset, rot } (opsional); false = tidak bisa digendong
--   image     : gambar di menu toko (boleh URL); kosong = pakai emoji `icon`
Config.Pets = {
    { id = 'retriever',  label = 'Golden Retriever', model = 'a_c_retriever',  kind = 'dog_big',   price = 5000000, icon = '🐕',
      image = 'https://docs.fivem.net/peds/a_c_retriever.webp' },
    { id = 'shepherd',   label = 'German Shepherd',  model = 'a_c_shepherd',   kind = 'dog_big',   price = 6000000, icon = '🐕',
      image = 'https://docs.fivem.net/peds/a_c_shepherd.webp' },
    { id = 'husky',      label = 'Husky',            model = 'a_c_husky',      kind = 'dog_big',   price = 6500000, icon = '🐺',
      image = 'https://docs.fivem.net/peds/a_c_husky.webp' },
    { id = 'rottweiler', label = 'Rottweiler',       model = 'a_c_rottweiler', kind = 'dog_big',   price = 6000000, icon = '🐕',
      image = 'https://docs.fivem.net/peds/a_c_rottweiler.webp' },
    { id = 'pug',        label = 'Pug',              model = 'a_c_pug',        kind = 'dog_small', price = 3500000, icon = '🐶',
      image = 'https://docs.fivem.net/peds/a_c_pug.webp' },
    { id = 'poodle',     label = 'Poodle',           model = 'a_c_poodle',     kind = 'dog_small', price = 4000000, icon = '🐩',
      image = 'https://docs.fivem.net/peds/a_c_poodle.webp' },
    { id = 'westy',      label = 'West Highland',    model = 'a_c_westy',      kind = 'dog_small', price = 3500000, icon = '🐶',
      image = 'https://docs.fivem.net/peds/a_c_westy.webp' },
    { id = 'cat_grey',   label = 'Kucing Abu-abu',   model = 'a_c_cat_01', texture = 0, kind = 'cat', price = 1500000, icon = '🐈',
      image = 'https://docs.fivem.net/peds/a_c_cat_01.webp' },
    { id = 'cat_black',  label = 'Kucing Hitam',     model = 'a_c_cat_01', texture = 1, kind = 'cat', price = 1500000, icon = '🐈‍⬛' },
    { id = 'cat_orange', label = 'Kucing Oranye',    model = 'a_c_cat_01', texture = 2, kind = 'cat', price = 1500000, icon = '🐈' },
    { id = 'cougar',     label = 'Singa Gunung',     model = 'a_c_mtlion',     kind = 'cougar',    price = 25000000, icon = '🐆',
      image = 'https://docs.fivem.net/peds/a_c_mtlion.webp' },
       { id = 'Pig',     label = 'Babi',     model = 'A_C_Pig',     kind = 'cougar',    price = 25000000, icon = '🐆',
      image = 'https://docs.fivem.net/peds/a_c_mtlion.webp' },
      { id = 'Burung',     label = 'Burng',     model = 'A_C_Pigeon',     kind = 'cougar',    price = 25000000, icon = '🐆',
      image = 'https://docs.fivem.net/peds/a_c_mtlion.webp' },
}

-- Posisi gendong default per jenis (dipakai kalau hewan tidak punya `carry` sendiri).
-- Offset terhadap badan pemain (pinggul): x = kanan, y = depan, z = atas. rot z 90 = melintang di lengan.
Config.Carry = {
    dog_big   = { offset = vec3(0.0, 0.48, 0.18), rot = vec3(0.0, 0.0, 90.0) },
    dog_small = { offset = vec3(0.0, 0.40, 0.25), rot = vec3(0.0, 0.0, 90.0) },
    cat       = { offset = vec3(0.0, 0.40, 0.25), rot = vec3(0.0, 0.0, 90.0) },
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
    dog_big   = vec4(0.0, 0.05, 0.25, 0.0),
    dog_small = vec4(0.0, 0.10, 0.30, 0.0),
    cat       = vec4(0.0, 0.10, 0.30, 0.0),
}

-- true = perintah /petseat aktif untuk menyetel posisi duduk di kendaraan. Matikan setelah selesai.
Config.Debug = true

-- Animasi per jenis (animasi bawaan GTA). `dead` = pose lemas saat mati / digendong
-- (kalau kosong dipakai `lay`, lalu `sit`).
Config.Anims = {
    dog_big   = { sit = { 'creatures@rottweiler@amb@world_dog_sitting@base', 'base' },
                  lay = { 'creatures@rottweiler@amb@sleep_in_kennel@', 'sleep_in_kennel' } },
    dog_small = { sit = { 'creatures@pug@amb@world_dog_sitting@base', 'base' } },
    cat       = { sit = { 'creatures@cat@amb@world_cat_sleeping_ground@base', 'base' },
                  lay = { 'creatures@cat@amb@world_cat_sleeping_ground@base', 'base' } },
    cougar    = { lay = { 'creatures@cougar@amb@world_cougar_rest@base', 'base' } },
}

-- Makanan hewan (item ox_inventory). Dijual di toko yang sama.
Config.Food = {
    { item = 'pet_food', label = 'Makanan Hewan', price = 15000, hunger = 40 },
}

Config.MaxPets = 5           -- maksimal hewan yang dimiliki satu karakter (semuanya bisa dipanggil bersamaan)
Config.NameMaxLength = 20

-- Rasa lapar turun selama hewan sedang dipanggil (dihitung di server).
Config.Hunger = {
    tickMinutes = 5,         -- tiap berapa menit
    drop = 5,                -- lapar berkurang sekian per tick (100 = kenyang)
    starveDamage = 10,       -- kalau lapar 0, nyawa berkurang sekian per tick sampai mati
}
