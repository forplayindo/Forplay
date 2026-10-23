-- Dibaca client & server.
-- Zona kustom: warga masuk dengan kendaraan, tekan E, pilih modifikasi sendiri (preview), lalu
-- "Selesai Modifikasi" -> tagihan masuk Kasir bengkel (f_mechanicjob). Mekanik memasang setelah lunas,
-- di zona dengan jenis yang sama (order cat di booth cat, order modifikasi di lift).
-- Mekanik on duty + kendaraan miliknya sendiri = langsung terpasang, gratis.
--
-- station:
--   'mod'   = Modifikasi Kendaraan: semua kategori KECUALI warna bodi
--   'paint' = Cat Kendaraan: hanya warna bodi (utama, kedua, pearl)

---Kotak `w` x `l` meter berpusat di `c` (untuk lib.zones.poly, semua titik Z sama).
local function box(c, w, l)
    local hw, hl = w / 2, l / 2
    return {
        vec3(c.x - hw, c.y - hl, c.z), vec3(c.x + hw, c.y - hl, c.z),
        vec3(c.x + hw, c.y + hl, c.z), vec3(c.x - hw, c.y + hl, c.z),
    }
end

return {
    -- tinggi zona (meter). ox_lib hanya menerima pemain dalam +- thickness/4 dari Z titik zona,
    -- jadi 8.0 = +- 2 m (cukup untuk pengemudi di dalam mobil / di atas lift)
    thickness = 8.0,
    debug = false, -- true = gambar zona di game (cek posisi)

    stations = {
        mod = { label = 'Modifikasi Kendaraan', icon = 'fa-solid fa-screwdriver-wrench' },
        paint = { label = 'Cat Kendaraan', icon = 'fa-solid fa-spray-can' },
    },

    -- warna bodi (nama properti ox_lib): HANYA di station 'paint', tidak dijual di station 'mod'
    paintKeys = { color1 = true, color2 = true, pearlescentColor = true },

    zones = {
        -- deniedClasses = { [14] = true }  -- opsional per zona: kelas GTA yang ditolak
        { station = 'mod', points = box(vec3(-347.68, -1367.83, 29.88), 6.0, 6.0) },
        { station = 'mod', points = box(vec3(-340.09, -1367.91, 29.88), 6.0, 6.0) },
        { station = 'mod', points = box(vec3(-332.40, -1367.51, 29.89), 6.0, 6.0) },
        { station = 'paint', points = box(vec3(-330.55, -1343.35, 29.83), 5.0, 7.0) },
        { station = 'paint', points = box(vec3(-336.15, -1343.29, 29.82), 5.0, 7.0) },
    },

    -- kelas yang tidak pernah bisa dikustom (sepeda, perahu, heli, pesawat, kereta)
    deniedClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
}
