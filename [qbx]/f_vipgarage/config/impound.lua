return {
    -- Disabled: impounds are handled by f_garages (same player_vehicles table, state 0 = out).
    -- f_vipgarage is only used for the VIP property garages. Restore the entries below to re-enable.
    Locations = {
        -- {
        --     type = 'car',
        --     coords = vec3(399.373, -1633.517, 29.292),
        --     blip = { id = 524, colour = 1, scale = 0.9 },
        --     spawns = {
        --         vec4(417.557, -1645.661, 28.880, 50.769),
        --         vec4(420.034, -1641.964, 28.879, 88.880),
        --         vec4(420.167, -1639.015, 28.880, 87.007),
        --         vec4(419.857, -1635.934, 28.880, 89.199),
        --         vec4(418.899, -1630.608, 28.880, 141.614),
        --     }
        -- },
        -- {
        --     type = 'car',
        --     coords = vec3(-209.207, 6209.153, 31.490),
        --     blip = { id = 524, colour = 1, scale = 0.9 },
        --     spawns = {
        --         vec4(-207.559, 6219.600, 31.084, 223.938),
        --         vec4(-205.136, 6221.833, 31.079, 224.720),
        --         vec4(-202.652, 6223.741, 31.078, 225.072),
        --         vec4(-199.926, 6225.770, 30.995, 222.797)
        --     }
        -- },
        -- {
        --     type = 'car',
        --     coords = vec3(1726.164, 3708.771, 34.221),
        --     blip = { id = 524, colour = 1, scale = 0.9 },
        --     spawns = {
        --         vec4(1723.294, 3712.600, 33.820, 22.669),
        --         vec4(1727.581, 3715.914, 33.734, 21.011)
        --     }
        -- }
    },
    ImpoundPrices = {
        [0] = 150000,      -- Compacts
        [1] = 250000,      -- Sedans
        [2] = 250000,      -- SUVs
        [3] = 400000,      -- Coupes
        [4] = 600000,     -- Muscle
        [5] = 400000,      -- Sports Classics
        [6] = 750000,     -- Sports
        [7] = 1250000,     -- Super
        [8] = 150000,      -- Motorcycles
        [9] = 250000,      -- Off-road
        [10] = 500000,    -- Industrial
        [11] = 250000,     -- Utility
        [12] = 300000,     -- Vans
        [13] = 50000,     -- Cylces
        [14] = 1400000,    -- Boats
        [15] = 1750000,    -- Helicopters
        [16] = 1900000,    -- Planes
        [17] = 250000,     -- Service
        [18] = 0,       -- Emergency
        [19] = 50000,     -- Military
        [20] = 750000,    -- Commercial
        [21] = 0        -- Trains
    }
}