Config = {}

-- Job pemerintah: bisa /auditpajak (wajib on duty), menerima uang pajak, dan TIDAK kena pajak
Config.Government = 'government'
Config.GovAccount = 'government'   -- rekening Renewed-Banking tujuan pembayaran pajak

-- Job yang dikenakan pajak (nama job = nama rekening organisasi di Renewed-Banking).
-- Job baru harus didaftarkan di sini dulu, sebelum itu pendapatannya tidak dihitung.
Config.Jobs = {
    'cafe',
    'ambulance',
    'police',
}

Config.DefaultRate = 7             -- tarif awal (%), setelah diubah di menu pemerintah disimpan di database
Config.MinRate = 0
Config.MaxRate = 50

Config.PayTopGrades = 2            -- N grade tertinggi job yang boleh bayar pajak (menu Balai Kota)
Config.RateTopGrades = 2           -- N grade tertinggi pemerintah yang boleh ubah tarif pajak

Config.HistoryLimit = 20           -- jumlah riwayat pembayaran yang ditampilkan
