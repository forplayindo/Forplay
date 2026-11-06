Config = {}

-- Siapa yang boleh menyemprot: anggota crew f_crew bertipe 'gang' (bukan komunitas).
-- Semua anggota gang boleh menyemprot dan menghapus graffiti gangnya lewat menu.
Config.MaxPerGang = 10            -- graffiti aktif per gang; penuh = bersihkan / hapus dulu

-- Graffiti perang (Gang Wars f_crew, mode poin, fase perang): semprot di dalam wilayah yang sedang
-- diperebutkan gangmu = graffiti perang. Tidak memakai slot MaxPerGang, tidak disimpan ke database,
-- tidak bisa dihapus lewat menu, dan otomatis hilang saat perang selesai. Nilai poin di f_crew
-- config (Turf.WarGraffitiPoints).
Config.WarMaxPerGang = 15         -- total semprotan per gang selama satu perang (yang dibersihkan tetap terhitung)

-- Item semprot (dijual di toko 24/7). 1 kaleng = SprayUses kali semprot, sisanya di metadata.
Config.SprayItem = 'pylox'
Config.SprayUses = 3

-- Item pembersih (Alat Pembersih dari supplier mekanik). Siapa saja yang membawanya bisa membersihkan.
-- 1 alat = CleanUses kali bersihkan graffiti, lalu hilang.
Config.CleanItem = 'cleaningkit'
Config.CleanUses = 10

-- Penempatan
Config.PlaceDistance = 6.0        -- jarak bidik maksimal (m)
Config.Size = { min = 0.6, max = 3.0, default = 1.5, step = 0.1 } -- lebar graffiti (m)
Config.SurfaceOffset = 0.015      -- jarak graffiti dari tembok (m); terlalu kecil = berkedip
Config.SprayTime = 9000           -- lama menyemprot (ms); graffiti muncul perlahan selama ini

-- Membersihkan
Config.CleanDistance = 2.0        -- jarak maksimal ke graffiti (m)
Config.CleanTime = 6000           -- lama mengelap (ms)

-- Tampilan (ringan: tanpa DUI, PNG dimuat sekali jadi tekstur)
Config.RenderDistance = 45.0      -- graffiti hanya digambar dalam radius ini
Config.MaxDrawn = 15              -- maksimal graffiti terdekat yang digambar sekaligus
Config.Winding = 'both'           -- 'both' | 'cw' | 'ccw' (kalau sudah pasti, pilih satu agar lebih ringan)

-- Admin: /hapusgraffiti (radius) dan /hapusgraffiti semua
Config.AdminCommand = 'hapusgraffiti'
Config.AdminRadius = 10.0

-- Desain per gang. Nama gang = nama internal crew f_crew: crew_<id> (lihat tabel crew_gangs, kolom name).
-- File PNG ditaruh di images/<nama gang>/<file>. PNG latar transparan, disarankan 512x512 (maks 1024).
-- Gang baru: buat folder images/crew_<id>/, taruh PNG-nya, tambah baris di sini, lalu `ensure f_graffiti`.
Config.Designs = {
    crew_1 = {
         { file = 'sexyroad1.png', label = 'Logo Utama' },
    --     { file = 'tag2.png', label = 'Logo' },
    },
}
