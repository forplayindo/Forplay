-- Stok Gudang Bengkel (seperti Stok Gudang EMS). Dibaca client & server.
--  * Bahan perbaikan berupa ANGKA di database (mechanic_stock), bukan item di stash -> tidak bisa
--    diambil / dicuri karyawan. Panel perbaikan memotong stok ini langsung.
--  * Mekanik wajib membawa Tas Perkakas yang masih berlaku untuk memperbaiki.
--  * Stok bertambah lewat Supplier (Manager, uang rekening bengkel) atau Setor Bahan di titik Gudang
--    (item di tas mekanik -> angka stok, satu arah).
return {
    -- titik Gudang Bengkel (ox_target): Setor Bahan + Ambil Tas Perkakas. Atur dengan /vec3.
    point = { coords = vec3(-346.08, -1334.10, 30.32), radius = 1.0, distance = 2.5 },

    bag = 'tas_perkakas',     -- item Tas Perkakas (ox_inventory, degrade = masa berlaku)

    grade = 4,                -- grade mechanic minimal untuk membeli ke supplier (4 = Manager)
    maxPerBuy = 200,          -- jumlah maksimal per item per pembelian
    maxDeposit = 500,         -- jumlah maksimal per item per setoran

    -- isi stash lama yang dipindah ke stok sekali jalan (kosongkan untuk mematikan)
    migrateStash = 'mechanicstash',

    -- urutan tampil. item = nama item ox_inventory (dipakai juga untuk setor). price = harga supplier.
    items = {
        { item = 'engine_oil',  price = 20000, use = 'Ganti oli mesin' },
        { item = 'trans_fluid', price = 20000, use = 'Ganti oli transmisi' },
        { item = 'spark_plug',  price = 20000, use = 'Ganti busi' },
        { item = 'coolant',     price = 12000, use = 'Isi coolant' },
        { item = 'brake_fluid', price = 12000, use = 'Isi minyak rem' },
        { item = 'air_filter',  price = 12000, use = 'Ganti filter udara' },
        { item = 'steel',       price = 10000, use = 'Radiator ×5, suspensi ×4' },
        { item = 'copper',      price = 10000, use = 'Kopling ×6, rem ×5' },
        { item = 'aluminum',    price = 10000, use = 'As roda ×7' },
        { item = 'plastic',     price = 8000,  use = 'Bodi ×3, tangki ×5' },
        { item = 'metalscrap',  price = 25000, use = 'Mesin ×2' },
        { item = 'tirekit',     price = 25000, use = 'Ganti ban ×1' },
    },
}
