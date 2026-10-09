return {
    checkInCost = 200000, -- Biaya kasur RS + dokter AI (sedikit di atas dirawat EMS supaya pemain tetap cari EMS)
    minForCheckIn = 2, -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    locations = { -- Various interaction points
        duty = {
            vec3(311.18, -599.25, 43.29),
            vec3(-254.88, 6324.5, 32.58),
        },
        vehicle = {
            vec4(294.578, -574.761, 43.179, 35.79),
            vec4(-234.28, 6329.16, 32.15, 222.5),
        },
        helicopter = {
            vec4(351.58, -587.45, 74.16, 160.5),
            vec4(-475.43, 5988.353, 31.716, 31.34),
        },
        armory = {
            {
                shopType = 'AmbulanceArmory',
                name = 'Armory',
                groups = { ambulance = 0 },
                -- obat tidak ada di armory: semua tindakan memotong Stok Gudang (config/stock.lua).
                -- Tas: maksimal 1 yang masih berlaku per petugas (dicek hook di server/armory.lua).
                inventory = {
                    { name = 'tas_emergency', price = 0 },
                    { name = 'tas_operasi', price = 0, grade = 2 },
                    { name = 'blood_bag_empty', price = 0 },
                    { name = 'radio', price = 0 },
                    { name = 'weapon_flashlight', price = 0 },
                    { name = 'weapon_fireextinguisher', price = 0 },
                },
                locations = {
                    vec3(309.93, -602.94, 43.29)
                }
            }
        },
        roof = {
            vec3(338.54, -583.88, 74.17),
        },
        main = {
            vec3(298.62, -599.66, 43.29),
        },
        stash = {}, -- dikelola f_stash (/stash); 'ambulanceStash' sudah dipindah ke sana

        ---@class Bed
        ---@field coords vector4
        ---@field model number

        ---@type table<string, {coords: vector3, checkIn?: vector3|vector3[], beds: Bed[]}>
        hospitals = {
            pillbox = {
                label = 'Foreplay Hospital',
                coords = vec3(350, -580, 43),
                checkIn = vec3(308.19, -595.35, 43.29),
                beds = {
                    {coords = vec4(356.68, -581.23, 16.76, 272.16), model = 1631638868},
                    {coords = vec4(356.68, -581.23, 16.76, 272.16), model = 1631638868},
                    {coords = vec4(356.68, -581.23, 16.76, 272.16), model = 2117668672},
                    
                },
            },
            
            jail = {
                label = 'Bolingbroke Infirmary',
                coords = vec3(1761, 2600, 46),
                beds = {
                    {coords = vec4(1761.96, 2597.74, 45.66, 270.14), model = 2117668672},
                    {coords = vec4(1761.96, 2591.51, 45.66, 269.8), model = 2117668672},
                    {coords = vec4(1771.8, 2598.02, 45.66, 89.05), model = 2117668672},
                    {coords = vec4(1771.85, 2591.85, 45.66, 91.51), model = 2117668672},
                },
            },
        },

        stations = {
            {label = 'Forplay Hospital', coords = vec4(304.27, -600.33, 43.28, 272.249)},
        }
    },
}