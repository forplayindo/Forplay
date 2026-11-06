-- Posisi lobby diambil dari MLO aquiver-mining-mlo (interior di -1150, 3285, -110).
-- KALIBRASI di game: /tambangpos (salin vec4 posisi + arah hadap ke clipboard).
return {
    -- pintu masuk tambang di permukaan (mulut tambang Great Chaparral, dipakai MLO aslinya)
    surface = vec4(-596.30, 2089.30, 130.40, 60.0),
    -- Gudang Hasil (hasil lebur + berlian) di atas, dekat parkir supaya langsung masuk mobil
    hasil = vec4(-595.74, 2092.69, 130.47, 0.0),

    lobby = {
        center = vec3(-1150.0, 3290.0, -111.78), -- pusat area tambang (lobby + gua)
        areaRadius = 120.0,                       -- prop lobby dibuat saat sedekat ini
        entrance = vec4(-1145.61, 3270.06, -111.78, 0.0), -- titik datang dari permukaan + target "Naik ke Atas"
        locker = vec3(-1144.80, 3275.47, -111.78),        -- loker baju tambang
        toolRack = vec3(-1144.04, 3278.07, -111.43),      -- rak kapak tambang
        gudang = vec4(-1154.43, 3294.70, -111.71, 90.0),   -- Gudang Tambang (+ ambil / kembalikan wadah), dikalibrasi di game
        gateExit = vec4(-1150.05, 3299.40, -111.78, 180.0), -- titik keluar dari gua ke lobby
        -- 12 tungku. Timur 1-6 = posisi tungku asli MLO. Barat 7-12 = sejajar timur (y 3279 = kandang lift).
        -- Properti MLO di barat y 3293-3295 disembunyikan lewat config/client.lua hideProps (untuk tungku 12).
        furnaces = {
            vec4(-1141.95, 3281.61, -111.59, 0.0),
            vec4(-1141.95, 3284.14, -111.59, 0.0),
            vec4(-1141.95, 3286.70, -111.59, 0.0),
            vec4(-1141.95, 3289.25, -111.59, 0.0),
            vec4(-1141.95, 3291.81, -111.59, 0.0),
            vec4(-1141.95, 3294.44, -111.59, 0.0),
            vec4(-1158.14, 3281.61, -111.59, 180.0),
            vec4(-1158.14, 3284.14, -111.59, 180.0),
            vec4(-1158.14, 3286.70, -111.59, 180.0),
            vec4(-1158.14, 3289.25, -111.59, 180.0),
            vec4(-1158.14, 3291.81, -111.59, 180.0),
            vec4(-1158.14, 3294.44, -111.59, 180.0),
        },
    },

    caves = { 'Gua A', 'Gua B', 'Gua C', 'Gua D', 'Gua E' },
    maxPerCave = 6,

    -- bijih -> hasil lebur (item yang sudah ada: copper = bahan mekanik)
    smelt = {
        bijih_tembaga = 'copper',
        bijih_perak = 'silverbar',
        bijih_emas = 'goldbar',
    },
    secondsPerBar = 6,
    wadahMax = 50,
    kapakPrice = 50000,         -- harga Kapak Tambang di rak lobby (tunai, kalau kurang dari bank)
}
