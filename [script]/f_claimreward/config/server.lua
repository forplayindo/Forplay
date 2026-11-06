-- f_claimreward — config SERVER saja (tidak dikirim ke client, jadi daftar admin & peluang gacha aman).
-- Setelah mengubah file ini: ensure f_claimreward

--[[ FORMAT HADIAH (dipakai harian, gacha, kode & toko)
    { type = 'item',    name = 'water', count = 3 }      -- item ox_inventory
    { type = 'vehicle', model = 'sultan' }                -- masuk garasi (vehicleGarage), kunci didapat saat diambil pertama kali
    { type = 'money',   amount = 25000 }                  -- uang ke rekening bank
    { type = 'coins',   amount = 10 }                     -- Koin Hadiah
    { type = 'manual',  label = 'Rumah', note = '...' }   -- diberikan admin langsung (muncul di tab Admin > Pemenang)
]]

return {
    command = 'hadiah', -- /hadiah

    -- Hanya identifier ini yang melihat tab Admin. Lihat license di txAdmin (Players > IDs).
    admins = {
        'license:3b28ac3d7f015e6e6983866188d94dedf79c0271',
    },

    -- Kendaraan hadiah langsung masuk garasi ini (Motel Parking, ±90 m dari Balai Kota).
    -- Kunci fisik diberikan f_vehiclekeys saat kendaraan pertama kali diambil dari garasi.
    vehicleGarage = 'motelgarage',
    vehicleTypes = { automobile = true, bike = true }, -- garasi mobil: pesawat/kapal tidak bisa dijadikan hadiah

    -- Cegah tebak-tebak kode: maksimal salah sekian kali per jendela waktu (detik)
    codeAttempts = { max = 8, window = 600 },

    ---------------------------------------------------------------------------
    -- HADIAH HARIAN: kalender 7 hari. Bolong 1 hari = kembali ke Hari 1.
    -- Sumber koin utama (±160 koin / minggu kalau login tiap hari).
    ---------------------------------------------------------------------------
    daily = {
        { { type = 'coins', amount = 15 } },
        { { type = 'coins', amount = 15 } },
        { { type = 'coins', amount = 20 }, { type = 'item', name = 'water', count = 3 } },
        { { type = 'coins', amount = 15 } },
        { { type = 'coins', amount = 15 } },
        { { type = 'coins', amount = 20 }, { type = 'item', name = 'burger', count = 3 } },
        { { type = 'coins', amount = 60 }, { type = 'item', name = 'firstaid', count = 1 } },
    },

    ---------------------------------------------------------------------------
    -- GACHA (semua acak di server; NUI hanya memutar animasi hasil dari server)
    ---------------------------------------------------------------------------
    gacha = {
        title = 'Banner Musim 1',
        subtitle = 'Kendaraan & rumah menanti. Jaminan Legendary setiap 80 tarikan.',
        costOne = 15,
        costTen = 135,           -- 10x: diskon 1 tarikan + dijamin minimal 1 Langka
        pity = {
            hard = 80,           -- tarikan ke-80 tanpa Legendary = pasti Legendary
            softStart = 65,      -- mulai tarikan ke-66 peluang Legendary naik...
            softStep = 6,        -- ...+6% per tarikan
        },
        tenGuarantee = 'rare',   -- minimal rarity di 10x
        announce = true,         -- Legendary diumumkan di tab Pengumuman f_chat

        -- ASET = hadiah Legendaris berjenis kendaraan / manual (rumah). Tidak ditampilkan ke pemain.
        -- Saat Legendaris keluar, peluang isinya aset tergantung tingkat karakter:
        --   tingkat 1 (belum pernah / sudah pulih) 100%, tingkat 2 (baru dapat 1) 50%, tingkat 3 (2+) 25%.
        -- Setiap recoverDays hari tanpa dapat aset, karakter naik kembali 1 tingkat.
        -- weeklyCap: aset dari gacha se-server per minggu (Senin 00:00). Habis = Legendaris diganti hadiah non-aset.
        assets = {
            share = { 100, 50, 25 },
            recoverDays = 30,
            weeklyCap = 1,
        },

        -- urutan rendah → tinggi; chance dalam persen. Tidak ditampilkan ke pemain.
        -- Legendaris dipakai persis; rarity lain dibagi rata-sebanding dari sisanya (100 - legendaris).
        rarities = {
            { id = 'common',    label = 'Biasa',     chance = 60 },
            { id = 'uncommon',  label = 'Tidak Biasa', chance = 25 },
            { id = 'rare',      label = 'Langka',    chance = 10 },
            { id = 'epic',      label = 'Epik',      chance = 4 },
            { id = 'legendary', label = 'Legendaris', chance = 1 },
        },

        -- weight = bobot di dalam rarity yang sama (default 1)
        pool = {
            common = {
                { type = 'item', name = 'water', count = 3, weight = 3 },
                { type = 'item', name = 'burger', count = 2, weight = 3 },
                { type = 'item', name = 'bandage', count = 2, weight = 2 },
                { type = 'money', amount = 15000, weight = 2 },
                { type = 'coins', amount = 3, weight = 1 },
            },
            uncommon = {
                { type = 'item', name = 'firstaid', count = 1, weight = 3 },
                { type = 'item', name = 'repairkit', count = 1, weight = 3 },
                { type = 'item', name = 'cafe_burger', count = 3, weight = 2 },
                { type = 'money', amount = 50000, weight = 2 },
                { type = 'coins', amount = 8, weight = 1 },
            },
            rare = {
                { type = 'item', name = 'armour', count = 1, weight = 3 },
                { type = 'item', name = 'repairkit', count = 3, weight = 2 },
                { type = 'money', amount = 150000, weight = 2 },
                { type = 'coins', amount = 25, weight = 1 },
            },
            epic = {
                { type = 'item', name = 'goldbar', count = 1, weight = 3 },
                { type = 'item', name = 'diamond', count = 1, weight = 2 },
                { type = 'money', amount = 500000, weight = 2 },
                { type = 'coins', amount = 80, weight = 1 },
            },
            -- Legendaris rata-rata ±50 tarikan (±1 bulan login). Aset (vehicle/manual) dan non-aset dipilih
            -- terpisah lewat `assets` di atas; weight hanya berlaku di dalam kelompoknya masing-masing.
            -- Wajib ada minimal 1 hadiah non-aset (dipakai saat kuota mingguan habis).
            legendary = {
                { type = 'vehicle', model = 'sultan', weight = 10, featured = true },
                { type = 'vehicle', model = 'bati', weight = 10 },
                { type = 'manual', label = 'Rumah', note = 'Datang ke admin untuk serah terima rumah.', weight = 5 },
                { type = 'coins', amount = 150, weight = 30 },
                { type = 'money', amount = 1000000, weight = 20 },
                { type = 'item', name = 'goldbar', count = 3, weight = 15 },
                { type = 'item', name = 'diamond', count = 2, weight = 10 },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- TOKO: diatur admin lewat NUI (/hadiah > Admin > Toko). Isi di bawah hanya
    -- dimasukkan SEKALI saat tabel toko masih kosong, sebagai titik awal harga.
    -- Patokan anti-inflasi: login tiap hari ±160 koin/minggu (±690/bulan).
    ---------------------------------------------------------------------------
    shopSeed = {
        { label = 'Paket Pemula', description = 'Bekal awal: P3K, kit reparasi, makan & minum.', category = 'bundle', price = 120, limit = 1,
          rewards = { { type = 'item', name = 'firstaid', count = 2 }, { type = 'item', name = 'repairkit', count = 1 }, { type = 'item', name = 'water', count = 5 }, { type = 'item', name = 'burger', count = 5 } } },
        { label = 'Shitzu PCJ 600', description = 'Motor lincah untuk keliling kota.', category = 'vehicle', price = 700, limit = 1,
          rewards = { { type = 'vehicle', model = 'pcj' } } },          -- ±1 bulan login
        { label = 'Karin Kuruma', description = 'Sedan sport andalan sehari-hari.', category = 'vehicle', price = 1400, limit = 1,
          rewards = { { type = 'vehicle', model = 'kuruma' } } },       -- ±2 bulan
        { label = 'Karin Sultan', description = 'Sedan sport cepat dan stabil.', category = 'vehicle', price = 2800, limit = 1,
          rewards = { { type = 'vehicle', model = 'sultan' } } },       -- ±4 bulan
        { label = 'Rumah', description = 'Serah terima rumah langsung oleh admin.', category = 'other', price = 4000, limit = 1,
          rewards = { { type = 'manual', label = 'Rumah', note = 'Datang ke admin untuk serah terima rumah.' } } }, -- ±6 bulan
        { label = 'P3K', description = 'Kotak pertolongan pertama.', category = 'item', price = 25, limit = 0,
          rewards = { { type = 'item', name = 'firstaid', count = 1 } } },
        { label = 'Kit Reparasi', description = 'Perbaiki kendaraan di jalan.', category = 'item', price = 40, limit = 0,
          rewards = { { type = 'item', name = 'repairkit', count = 1 } } },
    },

    -- Batas input admin
    limits = {
        rewards = 20,          -- jumlah baris hadiah per kode / barang toko
        itemCount = 10000,
        money = 100000000,     -- Rp 100 jt
        coins = 100000,
        minutes = 525600,      -- 1 tahun
    },
}
