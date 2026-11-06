return {
    -- titik Koperasi ([E], tanpa blip). KALIBRASI di game: berdiri di depan loket lalu salin koordinatnya.
    locations = {
        vec3(253.38, -419.59, 53.65), -- Balai Kota (dikalibrasi di game)
    },
    distance = 1.5,                  -- jarak tombol [E] muncul

    taxRate = 2,                     -- % pajak penjualan
    govAccount = 'government',       -- rekening Renewed-Banking penerima pajak

    -- barang yang dibeli Koperasi (harga per buah). Tambah barang baru cukup satu baris.
    categories = {
        {
            label = 'Tambang',
            items = {
                { item = 'copper', price = 1250 },
                { item = 'silverbar', price = 3000 },
                { item = 'goldbar', price = 9500 },
                { item = 'diamond', price = 50000 },
            },
        },
        {
            label = 'Daur Ulang',
            items = {
                { item = 'plastic', price = 800 },
                { item = 'metalscrap', price = 2500 },
                { item = 'steel', price = 1000 },
                { item = 'aluminum', price = 1000 },
                { item = 'iron', price = 1000 },
                { item = 'glass', price = 600 },
                { item = 'rubber', price = 800 },
            },
        },
        {
            label = 'Kayu',
            items = {
                { item = 'papan_kayu', price = 6000 },
            },
        },
        {
            label = 'Kebun',
            items = {
                { item = 'kelapa_muda', price = 3500 },  -- dari f_kelapa (cafe beli dari supplier 9.000)
            },
        },
    },
}
