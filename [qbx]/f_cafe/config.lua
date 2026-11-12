Config = {}

Config.Debug = false            -- tampilkan kotak zona ox_target
Config.Job = 'cafe'             -- nama job (grade: 0 Waitress, 1 Chef, 2 Manager)
Config.Label = 'Cafe'           -- nama yang tampil di menu, invoice & rekening
Config.CashItem = 'money'       -- item uang cash di ox_inventory

-- Grade minimal untuk tiap aksi
Config.Grades = {
    cook    = 0,  -- memasak di stasiun
    serve   = 0,  -- serahkan pesanan
    restock = 2,  -- beli bahan dari supplier (uang rekening organisasi)
    discard = 2,  -- buang stok di stash siap jual
    promo   = 2,  -- kelola paket promo
}

---------------------------------------------------------------------------
-- LOKASI (placeholder, silakan ganti)
---------------------------------------------------------------------------
Config.Center = vec3(-1715.9, -805.2, 9.24)   -- titik tengah cafe
Config.Radius = 40.0                           -- radius area cafe (validasi server)

Config.Blip = { enabled = false, sprite = 214, color = 5, scale = 0.8 } -- blip dipindah ke f_blips

-- Zona target berupa bola. Ambil koordinat dengan /vec3 sambil BERDIRI di depan benda (menghadap benda).
-- Radius menutupi benda di depanmu; per titik bisa ditimpa, contoh: { coords = vec3(...), radius = 1.5 }
Config.TargetRadius = 1.2    -- radius default zona (meter)
Config.TargetDistance = 2.5  -- jarak maksimal pemain ke titik yang ditarget

Config.Points = {
    duty    = { coords = vec3(-1694.55, -798.04, 5.51) },  -- papan absen
    locker  = { coords = vec3(-1706.0, -796.49, 5.51) },  -- loker seragam
    fridge  = { coords = vec3(-1701.0, -796.85, 5.77) },  -- kulkas / gudang bahan
    ready   = { coords = vec3(-1709.76, -799.63, 10.34) },  -- rak stok siap jual
    orders  = {                                              -- layar list pemesanan, boleh lebih dari satu
        { coords = vec3(-1708.28, -802.68, 9.24) },
        { coords = vec3(-1707.64, -799.56, 10.3) },          -- nampan prop_food_tray_01
    },
    counter = {                                              -- meja kasir (pelanggan), boleh lebih dari satu
        { coords = vec3(-1707.76, -803.41, 10.52) },
    },
}

-- Stasiun masak. prop = alat yang dipegang saat masak (bone 28422 = tangan kanan), hapus baris prop kalau tidak mau.
Config.Stations = {
    grill = { label = 'Grill',          icon = 'fa-solid fa-fire-burner', coords = vec3(-1709.35, -796.01, 10.29),
              anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b', flag = 1 },
              prop = { model = 'prop_fish_slice_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } },  -- sudip
    fryer = { label = 'Fryer & Oven',   icon = 'fa-solid fa-bowl-food',   coords = vec3(-1708.02, -794.86, 10.26),
              anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b', flag = 1 },
              prop = { model = 'prop_fish_slice_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } },  -- sudip
    drink = { label = 'Drink Station',  icon = 'fa-solid fa-mug-hot',     coords = vec3(-1712.79, -802.4, 10.34),
              -- loop = { dari, sampai } dalam detik: setelah intro, potongan ini diulang terus sampai progress bar selesai
              anim = { dict = 'anim_casino_b@amb@casino@games@blackjack@dealer', clip = 'check_and_turn_card', flag = 1, loop = { 0.60, 1.80 } },
              prop = { model = 'p_amb_coffeecup_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } },  -- gelas kopi
}

-- NPC kasir (hiasan saja): muncul hanya jika tidak ada karyawan yang on duty. Pembeli pesan lewat Points.counter.
Config.NPC = {
    enabled = true,
    model = 'a_f_y_business_01',
    coords = vec4(-1708.44, -802.94, 10.24, 232.88),  -- ambil dengan /vec4 sambil berdiri di posisi NPC
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
}

---------------------------------------------------------------------------
-- STASH
---------------------------------------------------------------------------
Config.Stash = {
    fridge = { id = 'cafe_fridge', label = 'Kulkas & Gudang Bahan', slots = 80, weight = 1000000 },
    ready  = { id = 'cafe_ready',  label = 'Stok Siap Jual',         slots = 50, weight = 1000000 },
}

---------------------------------------------------------------------------
-- ORDER
---------------------------------------------------------------------------
Config.Order = {
    defaultQty     = 10,     -- quantity default di UI menu
    minQty         = 1,
    maxQty         = 50,     -- per baris keranjang
    maxLines       = 15,     -- jumlah baris keranjang maksimum
    counterDistance = 4.0,   -- pelanggan harus sedekat ini dengan meja kasir untuk order
    serveDistance  = 4.0,    -- jarak maksimal karyawan <-> pelanggan saat Serve Order (melewati meja kasir)
    invoiceTimeout = 10,     -- menit; invoice transfer yang belum dibayar otomatis dibatalkan
    cooldown       = 3,      -- detik jeda antar order per pemain
}

---------------------------------------------------------------------------
-- MENU (harga dalam Rupiah). Stok siap jual TIDAK kadaluarsa, item di tangan
-- pemain kadaluarsa 3 hari (degrade diatur di ox_inventory/data/items.lua).
-- Hunger/thirst/stress diatur di items.lua (client.status) dan tampil otomatis di menu.
-- Harga mengikuti biaya isi bar 100%: makanan ~Rp 100-126rb, minuman ~Rp 68-84rb.
---------------------------------------------------------------------------
Config.Menu = {
    -- Makanan
    { item = 'cafe_burger',      label = 'Classic Beef Burger', category = 'food',  price = 18000, emoji = '🍔', desc = 'Bun, beef patty, cheese slice' },
    { item = 'cafe_hotdog',      label = 'Hot Dog Sausage',     category = 'food',  price = 16000, emoji = '🌭', desc = 'Hotdog bun, sausage, mustard' },
    { item = 'cafe_nachos',      label = 'Loaded Nachos',       category = 'food',  price = 17000, emoji = '🧀', desc = 'Tortilla chips, melted cheese, salsa' },
    { item = 'cafe_donut',       label = 'Glazed Donut',        category = 'food',  price = 15000, emoji = '🍩', desc = 'Donut dough, sugar glaze' },
    { item = 'cafe_sandwich',    label = 'Fresh Sandwich',      category = 'food',  price = 17000, emoji = '🥪', desc = 'Bread, chicken, cheese slice' },
    { item = 'mie_goreng_telor', label = 'Mie Goreng Telor',    category = 'food',  price = 28000, emoji = '🍜', desc = 'Mie instan goreng, telur ceplok' },
    { item = 'mie_rebus_telor',  label = 'Mie Telor Rebus',     category = 'food',  price = 28000, emoji = '🍜', desc = 'Mie instan berkuah, telur ceplok' },
    { item = 'cafe_nasigoreng',  label = 'Nasi Goreng',         category = 'food',  price = 50000, emoji = '🍛', desc = 'Nasi, telur, kecap manis' },
    { item = 'steak',            label = 'Steak',               category = 'food',  price = 58000, emoji = '🥩', desc = 'Daging sapi panggang' },
    -- Minuman
    { item = 'cafe_cappuccino',  label = 'Classic Cappuccino',  category = 'drink', price = 12000, emoji = '☕', desc = 'Coffee, milk, cinnamon' },
    { item = 'cafe_colafloat',   label = 'Iced Cola Float',     category = 'drink', price = 11000, emoji = '🥤', desc = 'Cola, ice, vanilla ice cream' },
    { item = 'cafe_energysoda',  label = 'Energy Soda',         category = 'drink', price = 11000, emoji = '⚡', desc = 'Soda water, energy syrup, ice' },
    { item = 'cafe_orangejuice', label = 'Fresh Orange Juice',  category = 'drink', price = 17000, emoji = '🍊', desc = 'Orange, sugar, ice' },
    { item = 'cafe_milkshake',   label = 'Chocolate Milkshake', category = 'drink', price = 19000, emoji = '🍫', desc = 'Milk, chocolate, ice' },
    { item = 'cafe_stmj',        label = 'STMJ',                category = 'drink', price = 18000, emoji = '🍵', desc = 'Susu, telur, madu, jahe' },
    { item = 'cafe_kelapamuda',  label = 'Es Kelapa Muda Utuh', category = 'drink', price = 35000, emoji = '🥥', desc = 'Satu buah kelapa muda, es' },
    { item = 'cafe_jusalpukat',  label = 'Jus Alpukat Jumbo',   category = 'drink', price = 30000, emoji = '🥑', desc = 'Alpukat, susu kental manis, es' },
}

-- Promo: harga diatur Manager di game (tersimpan di database).
-- Batas harga promo relatif terhadap harga normal (makanan + minuman), mencegah harga ngawur.
Config.Promo = {
    minPercent = 60,   -- promo minimal 60% dari harga normal
    maxPercent = 100,  -- tidak boleh lebih mahal dari harga normal
    maxPromos  = 10,
    defaults = {       -- dipakai sekali saat tabel promo masih kosong
        { label = 'Burger + Cola Float',      food = 'cafe_burger',   drink = 'cafe_colafloat',  price = 25000 },
        { label = 'Donut + Cappuccino',       food = 'cafe_donut',    drink = 'cafe_cappuccino', price = 23000 },
        { label = 'Sandwich + Orange Juice',  food = 'cafe_sandwich', drink = 'cafe_orangejuice', price = 29000 },
    },
}

---------------------------------------------------------------------------
-- RESEP. Satu batch = 10 porsi; pemain memilih 10/20/30/40/50 porsi,
-- kebutuhan bahan dikalikan jumlah batch. Bahan diambil dari kulkas (stash).
---------------------------------------------------------------------------
Config.BatchSize = 10
Config.BatchOptions = { 10, 20, 30, 40, 50 }

Config.Recipes = {
    cafe_burger      = { station = 'grill', time = 8000, ingredients = { roti_burger = 10, daging_sapi = 10, keju = 10 } },
    cafe_hotdog      = { station = 'grill', time = 7000, ingredients = { roti_hotdog = 10, sosis = 10, saus_mustard = 2 } },
    cafe_sandwich    = { station = 'grill', time = 7000, ingredients = { roti_tawar = 5, daging_ayam = 10, keju = 5 } },
    cafe_nachos      = { station = 'fryer', time = 7000, ingredients = { keripik_tortilla = 5, keju = 10, saus_salsa = 5 } },
    cafe_donut       = { station = 'fryer', time = 8000, ingredients = { adonan_donat = 5, gula = 5, minyak_goreng = 2 } },
    cafe_nasigoreng  = { station = 'fryer', time = 8000, ingredients = { beras = 5, telur = 10, kecap_manis = 2 } },
    mie_goreng_telor = { station = 'fryer', time = 8000, ingredients = { mie_instan = 10, telur = 10 } },
    mie_rebus_telor  = { station = 'fryer', time = 8000, ingredients = { mie_instan = 10, telur = 10 } },
    steak            = { station = 'grill', time = 8000, ingredients = { daging_sapi = 10, minyak_goreng = 2 } },
    cafe_cappuccino  = { station = 'drink', time = 6000, ingredients = { bubuk_kopi = 5, susu = 5, kayu_manis = 2 } },
    cafe_colafloat   = { station = 'drink', time = 6000, ingredients = { soda_cola = 10, es_batu = 5, es_krim_vanila = 3 } },
    cafe_milkshake   = { station = 'drink', time = 6000, ingredients = { susu = 10, bubuk_coklat = 5, es_batu = 5 } },
    cafe_orangejuice = { station = 'drink', time = 6000, ingredients = { jeruk = 10, gula = 2, es_batu = 3 } },
    cafe_energysoda  = { station = 'drink', time = 6000, ingredients = { air_soda = 10, sirup_energi = 5, es_batu = 3 } },
    cafe_stmj        = { station = 'drink', time = 6000, ingredients = { susu = 10, telur = 10, madu = 5, jahe = 5 } },
    cafe_kelapamuda  = { station = 'drink', time = 6000, ingredients = { kelapa_muda = 10, gula = 5, es_batu = 10 } },
    cafe_jusalpukat  = { station = 'drink', time = 6000, ingredients = { alpukat = 20, susu_kental_manis = 5, es_batu = 10 } },
}

---------------------------------------------------------------------------
-- SUPPLIER (restock oleh Manager, dibayar dari rekening organisasi).
-- Modal bahan (HPP) ~30% dari harga jual per batch.
---------------------------------------------------------------------------
Config.Supplier = {
    { item = 'roti_burger',      label = 'Roti Burger',       price = 1000 },
    { item = 'roti_hotdog',      label = 'Roti Hotdog',       price = 1000 },
    { item = 'roti_tawar',       label = 'Roti Tawar',        price = 1500 },
    { item = 'daging_sapi',      label = 'Daging Sapi',       price = 2500 },
    { item = 'daging_ayam',      label = 'Daging Ayam',       price = 2500 },
    { item = 'sosis',            label = 'Sosis',             price = 2000 },
    { item = 'keju',             label = 'Keju',              price = 1000 },
    { item = 'saus_mustard',     label = 'Saus Mustard',      price = 1500 },
    { item = 'saus_salsa',       label = 'Saus Salsa',        price = 2000 },
    { item = 'keripik_tortilla', label = 'Keripik Tortilla',  price = 4000 },
    { item = 'adonan_donat',     label = 'Adonan Donat',      price = 4000 },
    { item = 'minyak_goreng',    label = 'Minyak Goreng',     price = 3000 },
    { item = 'gula',             label = 'Gula',              price = 1000 },
    { item = 'bubuk_kopi',       label = 'Bubuk Kopi',        price = 3000 },
    { item = 'bubuk_coklat',     label = 'Bubuk Coklat',      price = 3000 },
    { item = 'kayu_manis',       label = 'Kayu Manis',        price = 2000 },
    { item = 'susu',             label = 'Susu',              price = 1000 },
    { item = 'es_batu',          label = 'Es Batu',           price = 500 },
    { item = 'es_krim_vanila',   label = 'Es Krim Vanila',    price = 3000 },
    { item = 'soda_cola',        label = 'Soda Cola',         price = 1500 },
    { item = 'air_soda',         label = 'Air Soda',          price = 1000 },
    { item = 'sirup_energi',     label = 'Sirup Energi',      price = 3000 },
    { item = 'jeruk',            label = 'Jeruk',             price = 1500 },
    { item = 'beras',            label = 'Beras',             price = 3000 },
    { item = 'telur',            label = 'Telur',             price = 1500 },
    { item = 'kecap_manis',      label = 'Kecap Manis',       price = 2500 },
    { item = 'mie_instan',       label = 'Mie Instan',        price = 2500 },
    { item = 'madu',             label = 'Madu',              price = 4000 },
    { item = 'jahe',             label = 'Jahe',              price = 2000 },
    { item = 'kelapa_muda',      label = 'Kelapa Muda',       price = 9000 },
    { item = 'alpukat',          label = 'Alpukat',           price = 3500 },
    { item = 'susu_kental_manis', label = 'Susu Kental Manis', price = 2500 },
}
Config.SupplierMaxPerBuy = 500  -- jumlah maksimal per item per transaksi

---------------------------------------------------------------------------
-- SERAGAM (component: [id] = { drawable, texture }, prop: [id] = { drawable, texture })
-- Component id: 1 mask, 3 arms, 4 pants, 5 bag, 6 shoes, 7 accessory, 8 undershirt, 9 armor, 10 decals, 11 torso
---------------------------------------------------------------------------
Config.Uniform = {
    male = {
        components = { [3] = { 0, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 }, [8] = { 15, 0 }, [11] = { 13, 0 } },
        props = {},
    },
    female = {
        components = { [3] = { 14, 0 }, [4] = { 6, 0 }, [6] = { 29, 0 }, [8] = { 14, 0 }, [11] = { 27, 0 } },
        props = {},
    },
}
