-- Apotek: warga hanya MEMESAN di meja apotek (stok gudang langsung dikunci), lalu membayar di Kasir
-- (config/stock.lua `kasir`). Uang masuk rekening organisasi EMS. Dibaca client & server.
return {
    job = 'ambulance',            -- rekening organisasi & job invoice f_phone
    label = 'Apotek 4PLAY Hospital',
    cashItem = 'money',           -- item uang cash ox_inventory

    -- Meja apotek (boleh lebih dari satu, semua memakai data yang sama).
    -- Atur dengan /vec3 sambil berdiri di depan meja.
    counters = {
        { coords = vec3(311.9, -593.7, 43.28), size = vec3(1.6, 1.2, 1.6), rotation = 0 },
    },

    -- obat yang boleh dipesan warga. price = harga default (Boss bisa mengubah di Kasir > Daftar Harga).
    items = {
        { item = 'bandage', label = 'Perban', price = 8000, emoji = '🩹', desc = 'Luka ringan & pendarahan ringan · berlaku 3 hari' },
        { item = 'painkillers', label = 'Obat Pereda Nyeri', price = 12000, emoji = '💊', desc = 'Menahan rasa nyeri sementara · berlaku 3 hari' },
        { item = 'calm_pills', label = 'Pil Penenang', price = 20000, emoji = '🧠', desc = 'Obat penenang, menurunkan stres · berlaku 3 hari' },
    },

    -- batas total obat per pesanan (diatur petugas di Kasir > Pengaturan)
    limitWithEms = 10,            -- default saat ada EMS bertugas (obat diserahkan lewat Approval)
    limitWithoutEms = 5,          -- default saat tidak ada EMS bertugas (obat langsung masuk tas setelah bayar)
    maxLimit = 20,                -- batas tertinggi yang boleh diset
    settingsGrade = 0,            -- grade EMS minimal untuk mengubah batas

    orderTimeout = 30,            -- menit; pesanan yang belum dibayar dibatalkan, stok kembali ke gudang
    noEmsCooldown = 60,           -- menit jeda setelah membeli saat tidak ada EMS bertugas
    emsResetAfter = 5,            -- menit; jeda di atas hilang kalau ada EMS bertugas selama ini
    serveDistance = 4.0,          -- jarak maksimal petugas <-> pasien saat Approval
}
