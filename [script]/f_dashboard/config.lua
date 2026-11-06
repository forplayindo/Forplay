-- Config server saja (tidak dikirim ke client, aman untuk webhook)
Config = {}

-- Perintah buka dashboard
Config.Command = 'ekonomi'

-- Yang boleh buka: owner dan admin (lihat server.cfg add_ace group.owner / group.admin)
Config.Aces = { 'group.owner', 'group.admin' }

-- Cache dihitung ulang tiap X menit (semua karakter online + offline)
Config.RebuildMinutes = 30

-- Tombol Refresh di menu: jeda minimal (detik) sejak hitung ulang terakhir
Config.RefreshCooldown = 300

-- Arus uang (masuk/keluar per kategori) disimpan ke DB tiap X menit
Config.FlushMinutes = 60

-- Hitung cash item 'money' di stash, bagasi, dan glovebox (1 query per tabel saat hitung ulang)
Config.CountStorage = true

-- Karakter admin/test yang tidak ikut statistik (citizenid)
Config.Exclude = {
    -- 'F1234567',
}

-- Pemain dianggap aktif kalau login dalam X hari terakhir
Config.ActiveDays = 7

-- Status butuh data minimal X hari (sebelum itu "Mengumpulkan data")
Config.MinDays = 7

-- Batas status (4 angka = batas antara Lesu | Sehat | Waspada | Inflasi | Kritis)
Config.Thresholds = {
    growth = { -5, 5, 15, 30 },     -- % pertumbuhan uang per pemain aktif dalam 7 hari
    ratio = { 0.8, 1.2, 1.5, 2.0 }, -- rasio uang masuk : uang keluar 7 hari
}

-- Penanda "ketimpangan tinggi" kalau 10% terkaya menguasai lebih dari X% uang pemain
Config.InequalityShare = 60

-- Alert pemain dapat uang tidak wajar: total uang masuk (bukan transfer) dalam 1 jam
Config.Alert = {
    amount = 50000000,
    webhook = '', -- URL webhook Discord (kosong = tidak dikirim)
}

-- Rentang kekayaan untuk halaman Sebaran (cash + bank, termasuk dirty)
Config.Brackets = { 1000000, 10000000, 100000000, 1000000000, 10000000000 }

-- Kategori arus uang, ditebak dari teks reason (huruf kecil, cocok sebagian). Urutan = prioritas.
-- Uang yang pindah antar pemain/rekening (setor, tarik, transfer, bayar tagihan ke rekening job)
-- otomatis dianggap perpindahan dan tidak dihitung.
Config.Categories = {
    ['in'] = {
        { id = 'admin', label = 'Admin', keys = { 'f_admin', 'admin', 'unknown', 'givemoney' } },
        { id = 'criminal', label = 'Kriminal', keys = { 'rob', 'heist', 'drug', 'armored', 'kotor', 'dirty', 'rampok', 'cuci', 'launder', 'meth', 'weed', 'coke' } },
        { id = 'jobs', label = 'Job & gaji', keys = { 'paycheck', 'salary', 'payslip', 'gaji', 'job', 'trucker', 'tow', 'garbage', 'courier', 'kurir', 'mining', 'tambang', 'lumber', 'kayu', 'delivery', 'fishing', 'taxi', 'ryde', 'bus' } },
        { id = 'sales', label = 'Penjualan', keys = { 'koperasi', 'sold', 'sell', 'jual', 'coral', 'pengepul' } },
        { id = 'reward', label = 'Hadiah & event', keys = { 'starter', 'hadiah', 'reward', 'gacha', 'claim', 'race', 'casino' } },
        { id = 'refund', label = 'Refund', keys = { 'refund' } },
    },
    ['out'] = {
        { id = 'vehicles', label = 'Kendaraan', keys = { 'vehicle', 'showroom', 'finance', 'depot', 'garage', 'garasi', 'impound', 'bensin', 'fuel', 'repair', 'mechanic', 'bengkel', 'custom', 'toll', 'tol', 'tow' } },
        { id = 'items', label = 'Belanja item', keys = { 'shop:', 'shop', 'toko', 'beli', 'buy', 'pharmacy', 'store' } },
        { id = 'government', label = 'Denda & pajak', keys = { 'fine', 'tilang', 'tax', 'pajak', 'bill', 'invoice', 'layanan', 'license', 'lisensi', 'bail', 'jail', 'police', 'lawyer' } },
        { id = 'services', label = 'Layanan (EMS, dll)', keys = { 'hospital', 'ems', 'doctor', 'cafe', 'medis' } },
        { id = 'property', label = 'Properti', keys = { 'house', 'rumah', 'rent', 'sewa', 'property', 'apartment' } },
        { id = 'leisure', label = 'Hiburan', keys = { 'casino', 'race', 'chips', 'judi' } },
        { id = 'admin', label = 'Admin', keys = { 'f_admin', 'admin' } },
    },
}
