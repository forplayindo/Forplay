return {
    -- Studio foto: titik di udara di atas laut (jauh dari bangunan) tempat kendaraan dimunculkan.
    -- Hanya terlihat oleh admin yang memotret.
    studio = vec4(-1894.99, -3357.08, 200.0, 240.0),

    -- Layar hijau di belakang kendaraan (prop bawaan GTA), diperbesar supaya menutupi seluruh layar
    greenScreen = { model = 'prop_ld_greenscreen_01', distance = 10.0, scale = 30.0 },

    -- Ukuran foto akhir (latar transparan, kendaraan di tengah)
    output = { width = 640, height = 360, quality = 0.92 },

    -- Model addon yang difoto dengan `/fotokendaraan addon`
    addonVehicles = {
        -- 'civic22',
    },
}
