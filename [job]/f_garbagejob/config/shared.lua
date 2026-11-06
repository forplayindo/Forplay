return {
    maxCrew = 4,

    -- loket Cari Pekerjaan di balai kota (f_cityhall office jobCenter)
    jobCentre = vec3(256.18, -412.04, 46.77),
    jobCentreDistance = 6.0,

    depot = {
        label = 'Depo Sampah',
        coords = vec3(-325.5, -1530.0, 27.4),          -- blip + titik selesai shift
        finishRadius = 9.0,
        truckSpawns = {                                -- dari 0r, pas dengan depot sampah di f_assets (stream/garbage)
            vec4(-331.81, -1519.58, 27.39, 180.0),
            vec4(-326.08, -1519.71, 27.39, 180.0),
            vec4(-319.44, -1519.44, 27.39, 180.0),
        },
    },

    -- master2: door 4 (bone bonnet) = tutup atas, terbuka saat kontainer dituang DAN saat kantong dilempar;
    -- door 5 (bone boot) = pintu belakang, tidak dipakai
    truck = {
        hopperDoor = 4,         -- terbuka saat kantong dilempar ke atas, tertutup lagi setelahnya
        hopperBone = 'bonnet',  -- titik tujuan lemparan kantong
        scoopDoor = 4,          -- tertutup = scoop turun, terbuka = terangkat
        throwDistance = 5.5,    -- jarak pemain ke pusat truk untuk melempar kantong
    },

    -- jumlah titik per zona. jauh diambil dari satu arah (region) acak per shift
    difficulties = {
        { key = 'easy', label = 'Mudah', desc = 'Sekitar depo', stops = { dekat = 5 }, bonus = 0 },
        { key = 'medium', label = 'Sedang', desc = 'Sampai tengah kota', stops = { dekat = 4, tengah = 4 }, bonus = 10 },
        { key = 'hard', label = 'Sulit', desc = 'Sampai pinggir kota', stops = { dekat = 3, tengah = 3, jauh = 4 }, bonus = 15 },
    },

    -- container = true: ada kontainer untuk diangkat scoop truk (sopir), selain kantong plastik
    locations = {
        -- dekat (< 800 m dari depo)
        { label = 'Strawberry', zone = 'dekat', container = true, coords = vec4(-238.91, -1467.72, 30.52, 24.86) },
        { label = 'Chamberlain Hills', zone = 'dekat', container = true, coords = vec4(-131.26, -1616.69, 31.61, 52.0) },
        { label = 'Forum Drive', zone = 'dekat', coords = vec4(-168.07, -1662.8, 33.31, 137.5) },
        { label = 'Strawberry Utara', zone = 'dekat', container = true, coords = vec4(-175.56, -1370.88, 30.27, 305.41) },
        { label = 'South Arsenal Street', zone = 'dekat', coords = vec4(-587.74, -1739.13, 22.47, 339.5) },
        { label = 'South Rockford Drive', zone = 'dekat', coords = vec4(-635.21, -1226.45, 11.8, 143.5) },
        { label = 'Adam\'s Apple Boulevard', zone = 'dekat', container = true, coords = vec4(86.23, -1241.57, 28.29, 6.92) },
        { label = 'Davis', zone = 'dekat', container = true, coords = vec4(185.96, -1456.61, 28.14, 51.09) },
        { label = 'Grove Street', zone = 'dekat', coords = vec4(118.06, -1943.96, 20.43, 179.5) },
        { label = 'Palomino Avenue', zone = 'dekat', coords = vec4(-845.87, -1113.07, 6.91, 253.5) },
        { label = 'Jamestown Barat', zone = 'dekat', container = true, coords = vec4(136.68, -2058.54, 17.38, 180.0) },
        { label = 'Elgin Selatan', zone = 'dekat', container = true, coords = vec4(313.58, -1167.19, 28.3, 181.46) },
        { label = 'Davis Avenue', zone = 'dekat', coords = vec4(424.98, -1523.57, 29.28, 120.08) },
        { label = 'Rancho', zone = 'dekat', container = true, coords = vec4(455.06, -1502.56, 28.29, 296.0) },
        { label = 'Jamestown Street', zone = 'dekat', coords = vec4(297.94, -2018.26, 20.49, 119.5) },
        { label = 'Jamestown', zone = 'dekat', container = true, coords = vec4(274.87, -2059.56, 16.41, 322.0) },

        -- tengah (800 - 1300 m)
        { label = 'Vespucci Boulevard', zone = 'tengah', coords = vec4(307.47, -1033.6, 29.03, 46.5) },
        { label = 'Rancho Projects', zone = 'tengah', container = true, coords = vec4(377.93, -1980.47, 23.1, 243.0) },
        { label = 'Little Bighorn Avenue', zone = 'tengah', coords = vec4(488.49, -1284.1, 29.24, 138.5) },
        { label = 'Rancho Timur', zone = 'tengah', container = true, coords = vec4(455.37, -1910.73, 23.87, 296.0) },
        { label = 'Rancho Selatan', zone = 'tengah', container = true, coords = vec4(414.91, -2072.33, 20.48, 236.0) },
        { label = 'Magellan Avenue', zone = 'tengah', coords = vec4(-1243.73, -1359.72, 3.93, 287.5) },
        { label = 'Elgin Avenue', zone = 'tengah', coords = vec4(239.19, -681.5, 37.15, 178.5) },
        { label = 'Cypress Flats Barat', zone = 'tengah', container = true, coords = vec4(719.12, -2106.85, 28.23, 90.0) },
        { label = 'Sandcastle Way', zone = 'tengah', coords = vec4(-1350.0, -895.64, 13.36, 17.5) },
        { label = 'Industry Passage', zone = 'tengah', coords = vec4(-1057.06, -515.45, 35.83, 61.5) },

        -- jauh (> 1300 m), dikelompokkan per arah
        { label = 'Cypress Flats', zone = 'jauh', region = 'timur', container = true, coords = vec4(860.19, -2096.32, 29.32, 180.0) },
        { label = 'Cypress Flats Selatan', zone = 'jauh', region = 'timur', container = true, coords = vec4(712.13, -2418.81, 19.1, 69.6) },
        { label = 'Cypress Flats Tengah', zone = 'jauh', region = 'timur', container = true, coords = vec4(884.11, -2213.4, 29.52, 90.0) },
        { label = 'El Burro Heights', zone = 'jauh', region = 'timur', container = true, coords = vec4(1039.98, -2136.92, 31.66, 90.0) },
        { label = 'Cypress Flats Timur', zone = 'jauh', region = 'timur', container = true, coords = vec4(1056.63, -2340.57, 29.55, 270.0) },
        { label = 'Cypress Flats Ujung', zone = 'jauh', region = 'timur', container = true, coords = vec4(988.3, -2451.41, 27.51, 270.0) },
        { label = 'Eastbourne Way Barat', zone = 'jauh', region = 'utara', coords = vec4(-771.02, -218.06, 37.05, 277.5) },
        { label = 'Eastbourne Way', zone = 'jauh', region = 'utara', coords = vec4(-683.23, -169.62, 37.74, 267.5) },
        { label = 'Elgin Avenue Utara', zone = 'jauh', region = 'utara', coords = vec4(543.51, -204.41, 54.16, 199.5) },
        { label = 'Power Street', zone = 'jauh', region = 'utara', coords = vec4(268.72, -25.92, 73.36, 90.5) },
        { label = 'Milton Road', zone = 'jauh', region = 'utara', coords = vec4(-546.9, 286.57, 82.85, 127.5) },
        { label = 'Alta Street', zone = 'jauh', region = 'utara', coords = vec4(267.03, 276.01, 105.54, 332.5) },
        { label = 'Didion Drive', zone = 'jauh', region = 'utara', coords = vec4(21.65, 375.44, 112.67, 323.5) },
        { label = 'Boulevard Del Perro', zone = 'jauh', region = 'barat', coords = vec4(-1558.64, -478.22, 35.18, 179.5) },
    },
}
