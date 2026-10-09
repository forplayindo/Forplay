Config = {}

-- Ace permission yang boleh pasang/hapus prop (group.admin sudah punya 'admin' di permissions.cfg)
Config.Ace = 'admin'

-- Jarak (meter) prop mulai dimunculkan di client. Di luar jarak ini prop dihapus dari memori client.
Config.StreamDistance = 150.0

-- Jarak maksimal raycast kamera saat menempatkan prop
Config.PlaceDistance = 20.0

-- Server menolak simpan kalau posisi prop lebih jauh dari ini dari player (anti-cheat)
Config.MaxServerDistance = 30.0

-- Batas total prop tersimpan
Config.MaxProps = 2000

-- Langkah rotasi (derajat) per scroll, dan saat tahan SHIFT
Config.RotateStep = 5.0
Config.RotateStepFine = 1.0

-- Kecepatan naik/turun per frame saat tahan PageUp/PageDown
Config.HeightStep = 0.01

-- Model yang tidak boleh dipasang (nama model, huruf kecil)
Config.Blacklist = {
    -- ['prop_gas_pump_1a'] = true,
}
