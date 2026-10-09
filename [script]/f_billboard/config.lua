Config = {}

-- Ace permission yang boleh buat/edit/hapus billboard (group.admin sudah punya 'admin' di permissions.cfg)
Config.Ace = 'admin'

-- Command untuk membuka editor
Config.Command = 'billboard'

-- Batas total billboard tersimpan
Config.MaxBillboards = 300

-- Maksimal layar (browser DUI) yang aktif bersamaan di satu client.
-- Kalau lebih banyak billboard dalam jangkauan, hanya yang terdekat yang menyala.
Config.MaxActive = 4

-- Resolusi browser DUI tiap layar
Config.DuiWidth = 1280
Config.DuiHeight = 720

-- Jarak (meter) layar mulai menyala
Config.DefaultRenderDistance = 80.0
Config.MinRenderDistance = 10.0
Config.MaxRenderDistance = 300.0

-- Jarak (meter) prop billboard dimunculkan (prop tetap terlihat walau layarnya belum menyala)
Config.PropStreamDistance = 350.0

-- Batas ukuran layar (meter) dan offset layar dari prop
Config.MaxSize = 40.0
Config.MaxOffset = 30.0

-- Jarak maksimal raycast kamera saat menempatkan billboard
Config.PlaceDistance = 40.0

-- Server menolak simpan kalau posisi billboard lebih jauh dari ini dari admin (anti-cheat)
Config.MaxServerDistance = 80.0

-- Panjang maksimal URL media
Config.MaxUrlLength = 512

-- Kosong = semua domain boleh. Isi untuk membatasi, contoh:
-- Config.AllowedDomains = { 'i.imgur.com', 'youtube.com', 'youtu.be', 'cdn.discordapp.com' }
Config.AllowedDomains = {}

-- Kontrol saat mode penempatan
Config.RotateStep = 5.0      -- derajat per scroll
Config.RotateStepFine = 1.0  -- derajat per scroll sambil tahan SHIFT
Config.HeightStep = 0.01     -- naik/turun per frame (PageUp/PageDown)
Config.PitchStep = 0.5       -- miring per frame (Panah Atas/Bawah, khusus zone)
Config.ScaleStep = 0.01      -- skala per frame (Panah Kiri/Kanan)
