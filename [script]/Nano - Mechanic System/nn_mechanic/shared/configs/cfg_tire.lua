if not Config then Config = {} end

Config.TireWear = {
    defaultProfile = "SemiSim",
    net = {
        telemKey = "ns_telem"
    },
    tick = {
        driving_ms = 1000,
        parked_ms = 20000
    },

    publish = {
        driving_ms = 1200,
        slow_ms = 6000,
        min_dist_m = 150,
        hard_brake_drop_kph = 25
    },

    limits = {
        max_kph = 300,
        max_dm = 2000,
        max_hb = 5
    },

    wheels = {FL = 0, FR = 1, RL = 2, RR = 3},
    bikeWheels = {F = 0, R = 4},

    defaults = {
        tread = 100.0,
        pressure = 32.0,
        alignment_bias = 1.00
    },

    epsilon = {
        treadPct = 0.01,
        pressure = 0.05
    },

    surface = {
        multipliers = {road = 1.00, offroad = 1.60}
    },

    handling = {
        applyEveryMs = 10000,
        traction = {
            curveMin = {minScale = 0.35, maxScale = 1.00},
            curveMax = {minScale = 0.35, maxScale = 1.00}
        }
    },

    profiles = {
        SemiSim = {
            wear = {
                BASE_WEAR_PER_KM = 0.1,
                HARD_BRAKE_WEAR = 0.12
            },

            pressure = {
                POPT = 32.0,
                DRIVING_MICRO_LOSS_PSI_PER_KM = 0.005,
                leakRange = {min = 0.000, max = 0.001}
            },

            mult = {
                SPEED_M = {base = 60.0, span = 120.0, cap = 0.80},
                PRESSURE_M = {perPsi = 0.04, cap = 0.60}
            },

            thresholds = {
                burstPsi = 8.0,
                baldTreadPct = 5.0
            },

            penalties = {
                pressure = {denom = 18.0, cap = 0.65},
                tread = {denom = 120.0, cap = 0.50}
            }
        },

        Arcade = {
            wear = {
                BASE_WEAR_PER_KM = 0.2,
                HARD_BRAKE_WEAR = 0.15
            },

            pressure = {
                POPT = 32.0,
                DRIVING_MICRO_LOSS_PSI_PER_KM = 0.02,
                leakRange = {min = 0.000, max = 0.002}
            },

            mult = {
                SPEED_M = {base = 60.0, span = 120.0, cap = 0.80},
                PRESSURE_M = {perPsi = 0.04, cap = 0.60}
            },

            thresholds = {burstPsi = 8.0, baldTreadPct = 5.0},

            penalties = {
                pressure = {denom = 18.0, cap = 0.65},
                tread = {denom = 120.0, cap = 0.50}
            }
        }
    },
}