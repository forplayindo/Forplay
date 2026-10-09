-- Kustom kendaraan (server). Harga di sini = harga AWAL; boss bisa mengubahnya lewat
-- Kasir > Master Harga (disimpan di tabel mechanic_prices dan menimpa angka di bawah).
--
-- Patokan ekonomi Rupiah (2026-10): gaji mekanik Rp350rb-700rb / 10 menit, mobil Rp10jt-500jt,
-- layanan perbaikan Rp40rb-300rb. Upgrade performa Rp600rb-10jt, kosmetik/cat Rp100rb-2jt.
--  - Harga level = harga untuk naik LANGSUNG ke level itu (tidak dijumlah per level).
return {
    -- grade minimal yang boleh membuka Master Harga (mechanic grade 4 = Manager)
    priceGrade = 4,

    -- Katalog harga per kategori (urutan = urutan tampil di Master Harga).
    -- Kode `svc:*` (layanan perbaikan) ditambahkan otomatis dari config/server.lua billing.services.
    catalog = {
        { cat = 'Performa', items = {
            { code = 'modEngine:1', label = 'Mesin Lv.1', price = 1600000 },
            { code = 'modEngine:2', label = 'Mesin Lv.2', price = 3200000 },
            { code = 'modEngine:3', label = 'Mesin Lv.3', price = 5200000 },
            { code = 'modEngine:4', label = 'Mesin Lv.4', price = 7600000 },
            { code = 'modBrakes:1', label = 'Rem Lv.1', price = 1000000 },
            { code = 'modBrakes:2', label = 'Rem Lv.2', price = 2000000 },
            { code = 'modBrakes:3', label = 'Rem Lv.3', price = 3200000 },
            { code = 'modTransmission:1', label = 'Transmisi Lv.1', price = 1200000 },
            { code = 'modTransmission:2', label = 'Transmisi Lv.2', price = 2400000 },
            { code = 'modTransmission:3', label = 'Transmisi Lv.3', price = 3800000 },
            { code = 'modTransmission:4', label = 'Transmisi Lv.4', price = 5400000 },
            { code = 'modSuspension:1', label = 'Suspensi Lv.1', price = 600000 },
            { code = 'modSuspension:2', label = 'Suspensi Lv.2', price = 1200000 },
            { code = 'modSuspension:3', label = 'Suspensi Lv.3', price = 1800000 },
            { code = 'modSuspension:4', label = 'Suspensi Lv.4', price = 2400000 },
            { code = 'modSuspension:5', label = 'Suspensi Lv.5', price = 3000000 },
            { code = 'modArmor:1', label = 'Armor Lv.1', price = 2000000 },
            { code = 'modArmor:2', label = 'Armor Lv.2', price = 4000000 },
            { code = 'modArmor:3', label = 'Armor Lv.3', price = 6000000 },
            { code = 'modArmor:4', label = 'Armor Lv.4', price = 8000000 },
            { code = 'modArmor:5', label = 'Armor Lv.5', price = 10000000 },
            { code = 'modTurbo', label = 'Turbo', price = 5000000 },
        } },
        { cat = 'Bodi', items = {
            { code = 'spoiler', label = 'Spoiler', price = 500000 },
            { code = 'frontBumper', label = 'Bumper Depan', price = 500000 },
            { code = 'rearBumper', label = 'Bumper Belakang', price = 440000 },
            { code = 'sideSkirt', label = 'Rok Samping', price = 360000 },
            { code = 'exhaust', label = 'Knalpot', price = 400000 },
            { code = 'grille', label = 'Grill', price = 240000 },
            { code = 'hood', label = 'Kap Mesin', price = 500000 },
            { code = 'fender', label = 'Fender (per sisi)', price = 300000 },
            { code = 'roof', label = 'Atap', price = 360000 },
            { code = 'rollcage', label = 'Roll Cage', price = 700000 },
            { code = 'bodyAcc', label = 'Aksesori Bodi Lain', price = 200000 },
            { code = 'livery', label = 'Livery', price = 800000 },
            { code = 'extra', label = 'Extra (per item)', price = 100000 },
        } },
        { cat = 'Interior & Mesin', items = {
            { code = 'interior', label = 'Aksesori Interior', price = 200000 },
            { code = 'engineBay', label = 'Aksesori Ruang Mesin', price = 300000 },
            { code = 'horn', label = 'Klakson', price = 120000 },
        } },
        { cat = 'Cat', items = {
            { code = 'paint:Classic', label = 'Cat Metalik', price = 600000 },
            { code = 'paint:Matte', label = 'Cat Matte', price = 900000 },
            { code = 'paint:Metal', label = 'Cat Metal / Chrome', price = 1400000 },
            { code = 'paint:Worn', label = 'Cat Kusam', price = 300000 },
            { code = 'paint:Chameleon', label = 'Cat Chameleon', price = 2000000 },
            { code = 'pearl', label = 'Pearl', price = 500000 },
            { code = 'wheelColor', label = 'Warna Velg', price = 300000 },
            { code = 'interiorColor', label = 'Warna Interior / Dashboard', price = 240000 },
        } },
        { cat = 'Velg & Ban', items = {
            { code = 'wheels', label = 'Velg', price = 900000 },
            { code = 'customTires', label = 'Ban Custom', price = 400000 },
            { code = 'tyreSmoke', label = 'Asap Ban', price = 400000 },
        } },
        { cat = 'Lampu', items = {
            { code = 'xenon', label = 'Lampu Xenon', price = 600000 },
            { code = 'neon', label = 'Neon (per sisi)', price = 300000 },
            { code = 'neonColor', label = 'Warna Neon', price = 160000 },
        } },
        { cat = 'Lainnya', items = {
            { code = 'windowTint', label = 'Kaca Film', price = 300000 },
            { code = 'plateIndex', label = 'Gaya Plat', price = 160000 },
        } },
    },

    -- mod yang tidak bisa dibeli (true = dimatikan)
    disabled = { modArmor = true },

    -- Harga cat dihitung dari kelompok warna GTA. Id di luar daftar = Classic (metalik).
    paintGroups = {
        Matte = { 12, 13, 14, 39, 40, 41, 42, 55, 82, 83, 84, 131, 148, 149, 151, 152, 153, 154, 155 },
        Metal = { 117, 118, 119, 120, 158, 159 },
        Worn = { 21, 22, 23, 24, 25, 26, 46, 47, 48, 58, 59, 60, 85, 86, 87, 113, 114, 115, 116, 121, 123, 124, 126, 130, 132, 133 },
        chameleonFrom = 161, -- id >= ini = Chameleon
    },
}
