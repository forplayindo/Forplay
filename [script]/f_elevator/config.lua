return {
    key = 38, -- E

    texts = {
        open = '[E] - Elevator'
    },

    interact_dist = 1.5,

    -- Urutkan lantai dari PALING BAWAH ke PALING ATAS (lift naik/turun mengikuti urutan ini).
    -- number = label tombol & layar: angka atau teks, mis. 'B1', 'G', 1, 2, 'R'.
    elevators = {
        ['Ocean Hospital'] = {
            {
                number = 1, -- floor
                name = 'Ground Floor', -- or false
                code = nil, -- restrict floor by password
                pos = vector3(-2779.26, -70.79, 17.61),
            },
            {
                number = 2, -- floor
                name = 'Rawat Inap', -- or false
                code = nil, -- restrict floor by password
                pos = vector3(-2795.64, -62.71, 30.38),
            },
            {
                number = 3, -- floor
                name = 'Roof', -- or false
                code = '1234', -- restrict floor by password
                pos = vec3(-2801.31, -55.02, 53.82),
            },
            
        },
        ['Example'] = {
            {
                number = 0, -- floor
                name = false, -- or false
                code = nil, -- restrict floor by password
                pos = vector3(-1067.68, -284.49, 37.71),
            },
            {
                number = 1, -- floor
                name = 'Roof', -- or false
                code = nil, -- restrict floor by password
                pos = vector3(-1066.94, -286.98, 50.02),
            },
        },
    },
}