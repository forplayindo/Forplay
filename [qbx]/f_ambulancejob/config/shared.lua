return {
    checkInCost = 200000, -- Biaya kasur RS + dokter AI (sedikit di atas dirawat EMS supaya pemain tetap cari EMS)
    minForCheckIn = 1, -- Minimum number of people with the ambulance job to prevent the check-in system from being used

    locations = { -- Various interaction points
        duty = {
            vec3(-2784.89, -78.76, 17.61),
            
        },
        vehicle = {
            vec4(-2784.75, -49.17, 17.61, 323.09),
           
        },
        helicopter = {
            vec4(-2802.07, -63.88, 56.89, 188.38),
            
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
                    vec3(-2800.67, -76.71, 17.61)
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
                label = 'Ocean Hospital',
                coords = vec3(-2786.37, -69.65, 17.61),
                checkIn = vec3(-2786.37, -69.65, 17.61),
                beds = {
                    {coords = vec4(-2769.61, -86.14, 18.17, 4.54), model = `v_med_bed2`},
                    {coords = vec4(-2766.13, -85.86, 18.17, 4.54), model = `v_med_bed2`},
                    {coords = vec4(-2762.62, -85.58, 18.17, 4.54), model = `v_med_bed2`},
                    {coords = vec4(-2759.14, -85.3, 18.17, 4.54), model = `v_med_bed2`},
                    {coords = vec4(-2755.66, -85.03, 18.17, 4.54), model = `v_med_bed2`},
                    
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
            {label = 'Ocean Hospital', coords = vec4(-2783.23, -66.29, 17.61, 322.73)},
        }
    },
}