-- Stok Gudang obat EMS + Kasir. Dibaca client & server.
--  * Stok tersimpan di database (tabel ems_stock), bukan item di inventory, dan tidak kedaluwarsa.
--  * Hanya Boss EMS (job grade isboss) yang membeli ke supplier; uangnya dari rekening organisasi.
--  * Semua petugas EMS on duty bisa melihat stok di Menu Kasir.
return {
    job = 'ambulance',
    label = 'Forplay Hospital',

    -- Titik kasir (boleh lebih dari satu, semua memakai data yang sama).
    -- SEMENTARA: atur dengan /vec3 sambil berdiri di depan meja kasir.
    kasir = {
        { coords = vec3(309.6, -594.6, 43.28), size = vec3(1.4, 1.2, 1.6), rotation = 0 },
    },
    menuDistance = 8.0,     -- menu kasir tertutup kalau pemain menjauh sejauh ini dari titik kasir terdekat

    -- Isi stok gudang (urutan tampil). units = jumlah stok yang bertambah per 1 pembelian.
    -- hpp = harga beli ke supplier per pembelian. nil = tidak dijual supplier (Blood Bag hanya dari donor).
    -- Harga dalam Rupiah per pembelian.
    items = {
        { key = 'bandage',     label = 'Perban',          emoji = '🩹', hpp = 3000,   units = 1,  use = 'apotek, luka ringan, pendarahan ringan, perban operasi' },
        { key = 'painkillers', label = 'Obat Pereda Nyeri',      emoji = '💊', hpp = 4000,   units = 1,  use = 'apotek, pereda nyeri' },
        { key = 'calm_pills',  label = 'Pil Penenang',    emoji = '🧠', hpp = 7000,  units = 1,  use = 'apotek' },
        { key = 'hemostatic',  label = 'Kasa Hemostatik', emoji = '🧻', hpp = 6000,  units = 1,  use = 'pendarahan berat' },
        { key = 'splint',      label = 'Bidai',           emoji = '🦴', hpp = 8000,  units = 1,  use = 'luka berat tangan/kaki' },
        { key = 'suture',      label = 'Alat Jahit Luka',       emoji = '🧵', hpp = 10000,  units = 1,  use = 'luka berat kepala/badan, jahit operasi' },
        { key = 'firstaid',    label = 'Kotak P3K',    emoji = '⛑️', hpp = 15000,  units = 1,  use = 'revive' },
        { key = 'crutch',      label = 'Kruk',           emoji = '🩼', hpp = 15000,  units = 1,  use = 'diberikan ke pasien pemulihan' },
        { key = 'anesthetic',  label = 'Obat Bius',       emoji = '💉', hpp = 30000,  units = 1,  use = 'bius operasi' },
        { key = 'surgery',     label = 'Alat Operasi',     emoji = '🔪', hpp = 200000, units = 10, use = '1 operasi = 1 jatah · 1 kit = 10 jatah', unitLabel = 'jatah' },
        { key = 'blood_bag',   label = 'Kantong Darah',        emoji = '🩸', hpp = nil, units = 1,  use = 'transfusi · hanya dari donor darah' },
    },

    maxPerBuy = 200,        -- jumlah maksimal per item per pembelian
}
