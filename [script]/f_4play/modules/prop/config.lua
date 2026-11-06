-- Pasang prop permanen (tersimpan di database tabel f_props) - admin only. Perintah: /prop, /proplist
PropConfig = {}

-- Ace permission yang boleh pasang/hapus prop (group.admin sudah punya 'admin' di permissions.cfg)
PropConfig.Ace = 'admin'

-- Jarak (meter) prop mulai dimunculkan di client. Di luar jarak ini prop dihapus dari memori client.
PropConfig.StreamDistance = 150.0

-- Jarak maksimal raycast kamera saat menempatkan prop
PropConfig.PlaceDistance = 20.0

-- Server menolak simpan kalau posisi prop lebih jauh dari ini dari player (anti-cheat)
PropConfig.MaxServerDistance = 30.0

-- Batas total prop tersimpan
PropConfig.MaxProps = 2000

-- Langkah rotasi (derajat) per scroll, dan saat tahan SHIFT
PropConfig.RotateStep = 5.0
PropConfig.RotateStepFine = 1.0

-- Kecepatan naik/turun per frame saat tahan PageUp/PageDown
PropConfig.HeightStep = 0.01

-- Model yang tidak boleh dipasang (nama model, huruf kecil)
PropConfig.Blacklist = {
    -- ['prop_gas_pump_1a'] = true,
}
