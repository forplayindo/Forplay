-- Dibaca client & server.
-- Zona kustom: warga masuk dengan kendaraan, tekan E, pilih modifikasi sendiri (preview), lalu
-- "Selesai Modifikasi" -> tagihan masuk Kasir bengkel (f_mechanicjob). Mekanik memasang setelah lunas.
-- Mekanik on duty + kendaraan miliknya sendiri = langsung terpasang, gratis.
-- Pastikan nilai Z semua titik sama (lib.zones.poly).
return {
    thickness = 4.0, -- tinggi zona (meter)

    zones = {
        {
            -- Satu titik modifikasi: kotak 6 x 6 m berpusat di vec3(-340.18, -1367.55, 30.51).
            label = 'Bengkel Kustom',
            -- blip dipindah ke f_blips
            -- deniedClasses = { [14] = true, [15] = true, [16] = true }, -- opsional: kelas GTA yang ditolak
            points = {
                vec3(-343.18, -1370.55, 30.51),
                vec3(-337.18, -1370.55, 30.51),
                vec3(-337.18, -1364.55, 30.51),
                vec3(-343.18, -1364.55, 30.51),
            },
        },
    },

    -- kelas yang tidak pernah bisa dikustom (sepeda, perahu, heli, pesawat, kereta)
    deniedClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
}
