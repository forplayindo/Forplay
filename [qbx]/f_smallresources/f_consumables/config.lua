return {
    defaultStressRelief = {
        min = 0,
        max = 4
    },
    ---@class anim
    ---@field clip string
    ---@field dict string
    ---@field flag number

    ---@class prop
    ---@field model string
    ---@field bone number
    ---@field pos vector3
    ---@field rot vector3

    ---@class stressRelief
    ---@field min number
    ---@field max number

    ---@class consumable
    ---@field min number
    ---@field max number
    ---@field anim anim?
    ---@field prop table?
    ---@field stressRelief table?

    ---@class consumableAlcohol : consumable
    ---@field alcoholLevel number?

    consumables = {
        ---@type table<string, consumable>
        food = {
            sandwich = {
                min = 10,
                max = 10,
            },
            tosti = {
                min = 10,
                max = 10,
            },
            burger = {
                min = 10,
                max = 10,
            },
           
        },

        ---@type table<string, consumable>
        drink = {
            water_bottle = {
                min = 10,
                max = 10,
                stressRelief = {
                    min = 1,
                    max = 4
                },
            },
            kurkakola = {
                min = 10,
                max = 10,
                stressRelief = {
                    min = 1,
                    max = 4
                },
            },
            coffee = {
                min = 10,
                max = 10,
                anim = {
                    clip = 'idle_c',
                    dict = 'amb@world_human_drinking@coffee@male@idle_a',
                    flag = 49
                },
                prop = {
                    model = 'p_amb_coffeecup_01',
                    bone = 28422,
                    pos = {x = 0.0, y = 0.0, z = 0.0},
                    rot = {x = 0.0, y = 0.0, z = 0.0}
                },
                stressRelief = {
                    min = -10,
                    max = -1
                },
            },
        },

        ---@type table<string, consumableAlcohol>
        alcohol = {
            whiskey = {
                min = 10,
                max = 10,
                stressRelief = {
                    min = 1,
                    max = 4
                },
            },
            beer = {
                min = 10,
                max = 10,
                stressRelief = {
                    min = 1,
                    max = 4
                },
                alcoholLevel = 0.25
            },
            vodka = {
                min = 10,
                max = 10,
                stressRelief = {
                    min = 1,
                    max = 4
                },
            },
            -- f_wine (kebun anggur Marlowe): botol wine di tangan; 3 botol dalam 20 menit = mabuk ringan (client.lua mabukRingan)
            wine_merah = {
                min = 10, max = 10,
                stressRelief = { min = 1, max = 4 },
                alcoholLevel = 1,
                prop = { { model = 'prop_wine_red', bone = 18905, pos = { x = 0.10, y = -0.02, z = 0.04 }, rot = { x = 240.0, y = -60.0, z = 0.0 } } },
            },
            wine_putih = {
                min = 10, max = 10,
                stressRelief = { min = 1, max = 4 },
                alcoholLevel = 1,
                prop = { { model = 'prop_wine_white', bone = 18905, pos = { x = 0.10, y = -0.02, z = 0.04 }, rot = { x = 240.0, y = -60.0, z = 0.0 } } },
            },
            wine_rose = {
                min = 10, max = 10,
                stressRelief = { min = 1, max = 4 },
                alcoholLevel = 1,
                prop = { { model = 'prop_wine_rose', bone = 18905, pos = { x = 0.10, y = -0.02, z = 0.04 }, rot = { x = 240.0, y = -60.0, z = 0.0 } } },
            },
        },
    },
}
