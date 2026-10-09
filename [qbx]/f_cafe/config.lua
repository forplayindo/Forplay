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
Config.Center = vec3(-1755.54, -1091.05, 13.06)   -- titik tengah cafe
Config.Radius = 40.0                           -- radius area cafe (validasi server)

Config.Blip = { enabled = false, sprite = 214, color = 5, scale = 0.8 } -- blip dipindah ke f_blips

-- Zona target berupa bola. Ambil koordinat dengan /vec3 sambil BERDIRI di depan benda (menghadap benda).
-- Radius menutupi benda di depanmu; per titik bisa ditimpa, contoh: { coords = vec3(...), radius = 1.5 }
Config.TargetRadius = 1.2    -- radius default zona (meter)
Config.TargetDistance = 2.5  -- jarak maksimal pemain ke titik yang ditarget

Config.Points = {
    duty    = { coords = vec3(-1750.66, -1078.58, 14.37) },  -- papan absen
    locker  = { coords = vec3(-1748.53, -1073.35, 13.06) },  -- loker seragam
    fridge  = { coords = vec3(-1759.23, -1087.98, 14.36) },  -- kulkas / gudang bahan
    ready   = { coords = vec3(-1753.05, -1081.94, 14.37) },  -- rak stok siap jual
    orders  = { coords = vec3(-1756.49, -1088.52, 14.18) },  -- layar list pemesanan
    counter = { coords = vec3(-1752.75, -1084.17, 14.17) },  -- meja kasir (pelanggan)
}

-- Stasiun masak
Config.Stations = {
    grill = { label = 'Grill',          icon = 'fa-solid fa-fire-burner', coords = vec3(-1755.62, -1084.94, 14.37),
              anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b', flag = 1 } },
    fryer = { label = 'Fryer & Oven',   icon = 'fa-solid fa-bowl-food',   coords = vec3(-1756.15, -1083.75, 14.37),
              anim = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b', flag = 1 } },
    drink = { label = 'Drink Station',  icon = 'fa-solid fa-mug-hot',     coords = vec3(-1752.83, -1079.77, 14.37),
              anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 } },
}

-- NPC kasir: muncul hanya jika tidak ada karyawan yang on duty
Config.NPC = {
    enabled = true,
    model = 'a_f_y_business_01',
    coords = vec4(-1757.21, -1088.3, 14.36, 226.68),  -- ambil dengan /vec4 sambil berdiri di posisi NPC
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
---------------------------------------------------------------------------
Config.Menu = {
    -- Makanan
    { item = 'cafe_burger',      label = 'Classic Beef Burger', category = 'food',  price = 14000, emoji = '🍔', desc = 'Bun, beef patty, cheese slice' },
    { item = 'cafe_hotdog',      label = 'Hot Dog Sausage',     category = 'food',  price = 11000, emoji = '🌭', desc = 'Hotdog bun, sausage, mustard' },
    { item = 'cafe_nachos',      label = 'Loaded Nachos',       category = 'food',  price = 13000, emoji = '🧀', desc = 'Tortilla chips, melted cheese, salsa' },
    { item = 'cafe_donut',       label = 'Glazed Donut',        category = 'food',  price = 10000, emoji = '🍩', desc = 'Donut dough, sugar glaze' },
    { item = 'cafe_sandwich',    label = 'Fresh Sandwich',      category = 'food',  price = 12000, emoji = '🥪', desc = 'Bread, chicken, cheese slice' },
    -- Minuman
    { item = 'cafe_cappuccino',  label = 'Classic Cappuccino',  category = 'drink', price = 8000, emoji = '☕', desc = 'Coffee, milk, cinnamon' },
    { item = 'cafe_colafloat',   label = 'Iced Cola Float',     category = 'drink', price = 8000, emoji = '🥤', desc = 'Cola, ice, vanilla ice cream' },
    { item = 'cafe_milkshake',   label = 'Chocolate Milkshake', category = 'drink', price = 9000, emoji = '🍫', desc = 'Milk, chocolate, ice' },
    { item = 'cafe_orangejuice', label = 'Fresh Orange Juice',  category = 'drink', price = 6000, emoji = '🍊', desc = 'Orange, sugar, ice' },
    { item = 'cafe_energysoda',  label = 'Energy Soda',         category = 'drink', price = 8000, emoji = '⚡', desc = 'Soda water, energy syrup, ice' },
}

-- Promo: harga diatur Manager di game (tersimpan di database).
-- Batas harga promo relatif terhadap harga normal (makanan + minuman), mencegah harga ngawur.
Config.Promo = {
    minPercent = 60,   -- promo minimal 60% dari harga normal
    maxPercent = 100,  -- tidak boleh lebih mahal dari harga normal
    maxPromos  = 10,
    defaults = {       -- dipakai sekali saat tabel promo masih kosong
        { label = 'Burger + Cola Float',      food = 'cafe_burger',   drink = 'cafe_colafloat',  price = 18000 },
        { label = 'Donut + Cappuccino',       food = 'cafe_donut',    drink = 'cafe_cappuccino', price = 15000 },
        { label = 'Sandwich + Orange Juice',  food = 'cafe_sandwich', drink = 'cafe_orangejuice', price = 15000 },
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
    cafe_cappuccino  = { station = 'drink', time = 6000, ingredients = { bubuk_kopi = 5, susu = 5, kayu_manis = 2 } },
    cafe_colafloat   = { station = 'drink', time = 6000, ingredients = { soda_cola = 10, es_batu = 5, es_krim_vanila = 3 } },
    cafe_milkshake   = { station = 'drink', time = 6000, ingredients = { susu = 10, bubuk_coklat = 5, es_batu = 5 } },
    cafe_orangejuice = { station = 'drink', time = 6000, ingredients = { jeruk = 10, gula = 2, es_batu = 3 } },
    cafe_energysoda  = { station = 'drink', time = 6000, ingredients = { air_soda = 10, sirup_energi = 5, es_batu = 3 } },
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
