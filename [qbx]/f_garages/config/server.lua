---Represents a function that calculates a fee based on vehicle data.
---
---The function receives a vehicle identifier and a model name,
---retrieves or derives the necessary vehicle information,
---and returns a numeric fee based on custom logic.
---
---@alias FeeCalculator fun(vehicleId: number, modelName: string): number

return {
    autoRespawn = false,   -- True == auto respawn cars that are outside into your garage on script restart, false == does not put them into your garage and players have to go to the impound
    warpInVehicle = false, -- If false, player will no longer warp into vehicle upon taking the vehicle out.
    doorsLocked = true, -- If true, the doors will be locked upon taking the vehicle out.
    distanceCheck = 3.0, -- Radius around a spawn slot that must be free of vehicles before a vehicle can spawn there
    spawnReserveTime = 5000, -- (ms) a chosen spawn slot is reserved this long so simultaneous take-outs never pick the same slot
    zoneHeight = 6.0, -- Default zone height. The zone spans from z - 2 up to z + (zoneHeight - 2)
    defaultZoneSize = 3.0, -- Half-size of the square zone generated for access points without a `zone` (e.g. f_properties garages)
    calculateImpoundFee = require 'server.default-calculate-impound-fee',

    -- Editor garasi in-game (/garasi, pengaturan lain di config/editor.lua).
    -- Sama seperti f_stash: hanya identifier di bawah ini yang boleh membuka editor.
    -- Isi lengkap dengan awalannya, contoh 'license:1a2b3c...' (lihat di txAdmin > Players > IDs).
    editorLicenses = {
        'license:3b28ac3d7f015e6e6983866188d94dedf79c0271',
    },
    logging = {
        webhook = {
            error = nil,
            default = nil,
            anticheat = nil,
        },
    },

    ---@class GarageBlip
    ---@field name? string -- Name of the blip. Defaults to garage label.
    ---@field sprite? number -- Sprite for the blip. Defaults to 357
    ---@field color? number -- Color for the blip. Defaults to 3.

    ---Area where the player can press E to park or take out a vehicle.
    ---@class GarageZone
    ---@field points vector2[] polygon corners (min 3), listed in order around the edge
    ---@field z number ground height of the area
    ---@field height? number defaults to zoneHeight

    ---The place where the player can access the garage and spawn a car
    ---@class AccessPoint
    ---@field zone? GarageZone if omitted, a square of defaultZoneSize is generated around coords
    ---@field spawns? vector4[] spawn slots, the first free slot is used. Defaults to { spawn or coords }
    ---@field blip? GarageBlip placed at the zone's center
    ---@field coords? vector4 defaults to the zone's center
    ---@field spawn? vector4 legacy single spawn slot

    ---@class GarageConfig
    ---@field label string -- Label for the garage
    ---@field type? GarageType -- Optional special type of garage. Currently only used to mark DEPOT garages.
    ---@field vehicleType VehicleType -- Vehicle type
    ---@field groups? string | string[] | table<string, number> job/gangs that can access the garage
    ---@field shared? boolean defaults to false. Shared garages give all players with access to the garage access to all vehicles in it. If shared is off, the garage will only give access to player's vehicles which they own.
    ---@field states? VehicleState | VehicleState[] if set, only vehicles in the given states will be retrievable from the garage. Defaults to GARAGED.
    ---@field skipGarageCheck? boolean if true, returns vehicles for retrieval regardless of if that vehicle's garage matches this garage's name
    ---@field canAccess? fun(source: number): boolean checks access as an additional guard clause. Other filter fields still need to pass in addition to this function.
    ---@field accessPoints AccessPoint[]

    ---@type table<string, GarageConfig>

    garages = {
        -- Public Garages
        motelgarage = {
            label = 'Motel Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(266.26, -349.74), vec2(280.58, -349.74), vec2(280.58, -337.32), vec2(266.26, -337.32) },
                        z = 43.7,
                    },
                    spawns = {
                        vec4(271.26, -342.32, 44.7, 159.97),
                    },
                }
            },
        },
        sapcounsel = {
            label = 'San Andreas Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-342.11, -786.12), vec2(-325.67, -786.12), vec2(-325.67, -770.34), vec2(-342.11, -770.34) },
                        z = 32.6,
                    },
                    spawns = {
                        vec4(-337.11, -775.34, 33.56, 132.09),
                    },
                }
            },
        },
        spanishave = {
            label = 'Spanish Ave Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-1170.38, -752.65), vec2(-1155.46, -752.65), vec2(-1155.46, -736.04), vec2(-1170.38, -736.04) },
                        z = 17.9,
                    },
                    spawns = {
                        vec4(-1165.38, -747.65, 18.94, 40.45),
                    },
                }
            },
        },
        caears24 = {
            label = 'Caears 24 Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(63.08, 6.72), vec2(77.61, 6.72), vec2(77.61, 18.15), vec2(63.08, 18.15) },
                        z = 67.5,
                    },
                    spawns = {
                        vec4(72.61, 11.72, 68.47, 157.59),
                    },
                },
            },
        },
        littleseoul = {
            label = 'Little Seoul Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-477.24, -818.61), vec2(-458.51, -818.61), vec2(-458.51, -803.2), vec2(-477.24, -803.2) },
                        z = 29.3,
                    },
                    spawns = {
                        vec4(-472.24, -813.61, 30.3, 179.88),
                    },
                }
            },
        },
        lagunapi = {
            label = 'Laguna Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(358.85, 292.02), vec2(372.41, 292.02), vec2(372.41, 302.97), vec2(358.85, 302.97) },
                        z = 102.2,
                    },
                    spawns = {
                        vec4(367.41, 297.02, 103.2, 341.08),
                    },
                }
            },
        },
        airportp = {
            label = 'Airport Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-801.07, -2028.26), vec2(-788.35, -2028.26), vec2(-788.35, -2015.62), vec2(-801.07, -2015.62) },
                        z = 7.5,
                    },
                    spawns = {
                        vec4(-793.35, -2020.62, 8.51, 58.42),
                    },
                }
            },
        },
        beachp = {
            label = 'Beach Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-1189.4, -1514.65), vec2(-1179.21, -1514.65), vec2(-1179.21, -1496.88), vec2(-1189.4, -1496.88) },
                        z = 3.4,
                    },
                    spawns = {
                        vec4(-1184.4, -1501.88, 4.39, 214.7),
                    },
                }
            },
        },
        themotorhotel = {
            label = 'The Motor Hotel Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(1132.56, 2658.54), vec2(1142.77, 2658.54), vec2(1142.77, 2679.19), vec2(1132.56, 2679.19) },
                        z = 36.9,
                    },
                    spawns = {
                        vec4(1137.56, 2674.19, 38.17, 359.95),
                    },
                }
            },
        },
        liqourparking = {
            label = 'Liqour Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(955.48, 3600.71), vec2(965.68, 3600.71), vec2(965.68, 3614.32), vec2(955.48, 3614.32) },
                        z = 32.0,
                    },
                    spawns = {
                        vec4(960.48, 3605.71, 32.98, 87.09),
                    },
                }
            },
        },
        shoreparking = {
            label = 'Shore Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(1721.9, 3705.38), vec2(1733.65, 3705.38), vec2(1733.65, 3719.85), vec2(1721.9, 3719.85) },
                        z = 33.2,
                    },
                    spawns = {
                        vec4(1728.65, 3714.85, 34.18, 21.26),
                    },
                }
            },
        },
        haanparking = {
            label = 'Bell Farms Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(65.71, 6413.74), vec2(83.34, 6413.74), vec2(83.34, 6430.16), vec2(65.71, 6430.16) },
                        z = 29.9,
                    },
                    spawns = {
                        vec4(70.71, 6425.16, 30.92, 68.5),
                    },
                }
            },
        },
        dumbogarage = {
            label = 'Dumbo Private Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(152.26, -3245.0), vec2(170.32, -3245.0), vec2(170.32, -3231.1), vec2(152.26, -3231.1) },
                        z = 4.9,
                    },
                    spawns = {
                        vec4(165.32, -3236.10, 5.93, 268.5),
                    },
                }
            },
        },
        pillboxgarage = {
            label = 'Pillbox Garage Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(213.66, -810.01), vec2(234.33, -810.01), vec2(234.33, -799.08), vec2(213.66, -799.08) },
                        z = 29.5,
                    },
                    spawns = {
                        vec4(229.33, -805.01, 30.54, 156.79),
                    },
                }
            },
        },
        intairport = {
            label = 'Airport Hangar',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-1037.34, -3029.0), vec2(-967.2, -3029.0), vec2(-967.2, -2983.51), vec2(-1037.34, -2983.51) },
                        z = 13.0,
                        height = 10.0,
                    },
                    spawns = {
                        vec4(-979.2, -2995.51, 13.95, 52.19),
                    },
                }
            },
        },
        higginsheli = {
            label = 'Higgins Helitours',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-734.83, -1482.74), vec2(-712.12, -1482.74), vec2(-712.12, -1433.89), vec2(-734.83, -1433.89) },
                        z = 4.0,
                        height = 10.0,
                    },
                    spawns = {
                        vec4(-724.83, -1443.89, 5.0, 140.0),
                    },
                }
            },
        },
        airsshores = {
            label = 'Sandy Shores Hangar',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(1728.88, 3266.99), vec2(1769.74, 3266.99), vec2(1769.74, 3308.13), vec2(1728.88, 3308.13) },
                        z = 40.1,
                        height = 10.0,
                    },
                    spawns = {
                        vec4(1740.88, 3278.99, 41.09, 189.46),
                    },
                }
            },
        },
        lsymc = {
            label = 'LSYMC Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-800.64, -1516.89), vec2(-787.58, -1516.89), vec2(-787.58, -1495.4), vec2(-800.64, -1495.4) },
                        z = -0.9,
                    },
                    spawns = {
                        vec4(-793.58, -1501.4, 0.12, 111.5),
                    },
                }
            },
        },
        paleto = {
            label = 'Paleto Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-295.2, 6631.01), vec2(-271.4, 6631.01), vec2(-271.4, 6643.96), vec2(-295.2, 6643.96) },
                        z = 0.0,
                        height = 12.0,
                    },
                    spawns = {
                        vec4(-289.2, 6637.96, 1.01, 45.5),
                    },
                }
            },
        },
        millars = {
            label = 'Millars Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(1290.78, 4197.76), vec2(1305.02, 4197.76), vec2(1305.02, 4222.42), vec2(1290.78, 4222.42) },
                        z = 29.1,
                        height = 10.0,
                    },
                    spawns = {
                        vec4(1296.78, 4203.76, 30.12, 169.03),
                    },
                }
            },
        },

        -- Job Garages
        police = {
            label = 'Police',
            vehicleType = VehicleType.CAR,
            groups = 'police',
            accessPoints = {
                {
                    zone = {
                        points = { vec2(433.4, -1023.3), vec2(459.6, -1023.3), vec2(459.6, -1012.4), vec2(433.4, -1012.4) },
                        z = 26.7,
                    },
                    spawns = {
                        vec4(438.4, -1018.3, 27.7, 90.0),
                    },
                }
            },
        },

        -- Gang Garages: dibuat otomatis oleh f_crew (lokasi diatur boss dari HP), tidak ditulis di sini.

        -- Impound Lots
        impoundlot = {
            label = 'Tempat Sitaan',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(395.45, -1650.58), vec2(412.2, -1650.58), vec2(412.2, -1625.87), vec2(395.45, -1625.87) },
                        z = 28.3,
                    },
                    spawns = {
                        vec4(407.2, -1645.58, 29.31, 228.28),
                    },
                }
            },
        },
        airdepot = {
            label = 'Air Depot',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-1250.35, -3397.39), vec2(-1238.35, -3397.39), vec2(-1238.35, -3385.39), vec2(-1250.35, -3385.39) },
                        z = 12.9,
                    },
                    spawns = {
                        vec4(-1269.03, -3376.7, 13.94, 330.32),
                    },
                }
            },
        },
        seadepot = {
            label = 'LSYMC Depot',
            type = GarageType.DEPOT,
            states = { VehicleState.OUT, VehicleState.IMPOUNDED },
            skipGarageCheck = true,
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    -- blip dipindah ke f_blips
                    zone = {
                        points = { vec2(-778.71, -1437.11), vec2(-766.71, -1437.11), vec2(-766.71, -1425.11), vec2(-778.71, -1425.11) },
                        z = 0.6,
                    },
                    spawns = {
                        vec4(-729.77, -1355.49, 1.19, 142.5),
                    },
                }
            },
        },
    },
}
