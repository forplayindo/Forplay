if not Config then Config = {} end

Config.BrakeWear = {
    defaultProfile = "SemiSim", -- "SemiSim" | "Arcade"

    -------------------------------------------------------------------------
    -- NETWORK / STATEBAG KEYS
    -------------------------------------------------------------------------
    net = {
        telemKey = "ns_telem" -- Shared with tire system
        -- per-vehicle replication keys:
        --   entity bag keys: ns_brake_front  (front pad health % * 100)
        --                    ns_brake_rear   (rear pad health % * 100)
        --                    ns_brake_heat   (brake heat in Celsius)
    },

    -------------------------------------------------------------------------
    -- TICKS & RATES
    -------------------------------------------------------------------------
    tick = {
        driving_ms = 1000, -- Same as tire system
        parked_ms = 20000
    },

    -------------------------------------------------------------------------
    -- LIMITS / GUARDS
    -------------------------------------------------------------------------
    limits = {
        max_brake_sec = 10.0, -- Max seconds of braking per publish
        max_handbrake_sec = 10.0, -- Max seconds of handbrake per publish
        max_decel_kph = 100.0 -- Max deceleration rate
    },

    -------------------------------------------------------------------------
    -- GEOMETRY / DEFAULT STATE
    -------------------------------------------------------------------------
    defaults = {
        front = 100.0, -- Front pad health %
        rear = 100.0, -- Rear pad health %
        heat = 0.0 -- Brake heat (Celsius)
    },

    -- Only publish/DB-write when changes exceed these
    epsilon = {
        padHealth = 0.5, -- % pad health change
        heat = 5.0 -- Celsius change
    },

    -------------------------------------------------------------------------
    -- HANDLING EFFECTS (client)
    -------------------------------------------------------------------------
    handling = {
        applyEveryMs = 10000 -- Brake effectiveness update cadence
    },

    -------------------------------------------------------------------------
    -- VEHICLE CLASS MAPPING
    -------------------------------------------------------------------------
    vehicleClassProfiles = {
        [0] = "Economy", -- Compacts
        [1] = "Economy", -- Sedans
        [2] = "Economy", -- SUVs
        [3] = "SemiMetallic", -- Coupes
        [4] = "SemiMetallic", -- Muscle
        [5] = "SemiMetallic", -- Sports Classics
        [6] = "SemiMetallic", -- Sports
        [7] = "SemiMetallic", -- Super
        [8] = "Ceramic", -- Motorcycles
        [9] = "Ceramic", -- Off-road
        [10] = "Ceramic", -- Industrial
        [11] = "SemiMetallic", -- Utility
        [12] = "SemiMetallic", -- Vans
        [13] = "Economy", -- Cycles
        [14] = "SemiMetallic", -- Boats
        [15] = "SemiMetallic", -- Helicopters
        [16] = "SemiMetallic", -- Planes
        [17] = "SemiMetallic", -- Service
        [18] = "SemiMetallic", -- Emergency
        [19] = "SemiMetallic", -- Military
        [20] = "SemiMetallic", -- Commercial
        [21] = "Ceramic" -- Trains
    },

    -------------------------------------------------------------------------
    -- PROFILES (physics constants & thresholds)
    -------------------------------------------------------------------------
    profiles = {
        Economy = {
            wear = {
                BASE_WEAR_PER_KM = 0.01, -- % per km (minimal)
                BRAKE_WEAR_PER_SEC = 0.15, -- % per second of braking (scaled by speed/mass)
                HARD_BRAKE_WEAR = 0.20, -- % per hard brake event (front)
                HANDBRAKE_WEAR = 0.10 -- % per second of handbrake (rear)
            },

            heat = {
                GENERATION_PER_BRAKE_SEC = 8.0, -- Heat generated per second of braking
                GENERATION_SPEED_MULT = 0.15, -- Additional heat per kph
                GENERATION_MASS_MULT = 0.0001, -- Additional heat per kg
                COOLING_AMBIENT = 0.5, -- Cooling per second (ambient)
                COOLING_AIRFLOW = 0.08, -- Cooling per kph (airflow)
                FADE_THRESHOLD = 200.0, -- Heat level where fade starts (Celsius)
                FADE_RANGE = 300.0, -- Heat range for fade (Celsius)
                MAX_FADE = 0.40 -- Maximum fade (40% braking loss)
            },

            mult = {
                -- SPEED_M = 1 + clamp((kph - base)/span, 0, cap)
                SPEED_M = {base = 40.0, span = 100.0, cap = 1.20},
                -- MASS_M = 1 + clamp((mass - base)/span, 0, cap)
                MASS_M = {base = 1000.0, span = 2000.0, cap = 0.80},
                -- SURFACE_M: off-road multiplier
                SURFACE_M = {road = 1.00, offroad = 1.30}
            },

            thresholds = {
                lowPadHealth = 20.0, -- Below: significant braking penalty
                criticalPadHealth = 5.0 -- Below: severe braking penalty
            },

            penalties = {
                -- Braking effectiveness penalty from low pad health
                padHealth = {denom = 80.0, cap = 0.50},
                -- Braking effectiveness penalty from heat fade
                heatFade = {denom = 300.0, cap = 0.40}
            }
        },

        SemiMetallic = {
            wear = {
                BASE_WEAR_PER_KM = 0.008,
                BRAKE_WEAR_PER_SEC = 0.12,
                HARD_BRAKE_WEAR = 0.15,
                HANDBRAKE_WEAR = 0.08
            },

            heat = {
                GENERATION_PER_BRAKE_SEC = 6.0,
                GENERATION_SPEED_MULT = 0.12,
                GENERATION_MASS_MULT = 0.00008,
                COOLING_AMBIENT = 0.6,
                COOLING_AIRFLOW = 0.10,
                FADE_THRESHOLD = 250.0,
                FADE_RANGE = 350.0,
                MAX_FADE = 0.35
            },

            mult = {
                SPEED_M = {base = 50.0, span = 120.0, cap = 1.30},
                MASS_M = {base = 1200.0, span = 2500.0, cap = 0.90},
                SURFACE_M = {road = 1.00, offroad = 1.25}
            },

            thresholds = {
                lowPadHealth = 25.0,
                criticalPadHealth = 8.0
            },

            penalties = {
                padHealth = {denom = 100.0, cap = 0.45},
                heatFade = {denom = 350.0, cap = 0.35}
            }
        },

        Ceramic = {
            wear = {
                BASE_WEAR_PER_KM = 0.005,
                BRAKE_WEAR_PER_SEC = 0.08,
                HARD_BRAKE_WEAR = 0.10,
                HANDBRAKE_WEAR = 0.05
            },

            heat = {
                GENERATION_PER_BRAKE_SEC = 4.0,
                GENERATION_SPEED_MULT = 0.10,
                GENERATION_MASS_MULT = 0.00006,
                COOLING_AMBIENT = 0.8,
                COOLING_AIRFLOW = 0.12,
                FADE_THRESHOLD = 350.0,
                FADE_RANGE = 400.0,
                MAX_FADE = 0.25
            },

            mult = {
                SPEED_M = {base = 60.0, span = 140.0, cap = 1.40},
                MASS_M = {base = 1500.0, span = 3000.0, cap = 1.00},
                SURFACE_M = {road = 1.00, offroad = 1.20}
            },

            thresholds = {
                lowPadHealth = 30.0,
                criticalPadHealth = 10.0
            },

            penalties = {
                padHealth = {denom = 120.0, cap = 0.40},
                heatFade = {denom = 400.0, cap = 0.25}
            }
        },

        SemiSim = {
            wear = {
                BASE_WEAR_PER_KM = 0.008,
                BRAKE_WEAR_PER_SEC = 0.12,
                HARD_BRAKE_WEAR = 0.15,
                HANDBRAKE_WEAR = 0.08
            },

            heat = {
                GENERATION_PER_BRAKE_SEC = 6.0,
                GENERATION_SPEED_MULT = 0.12,
                GENERATION_MASS_MULT = 0.00008,
                COOLING_AMBIENT = 0.6,
                COOLING_AIRFLOW = 0.10,
                FADE_THRESHOLD = 250.0,
                FADE_RANGE = 350.0,
                MAX_FADE = 0.35
            },

            mult = {
                SPEED_M = {base = 50.0, span = 120.0, cap = 1.30},
                MASS_M = {base = 1200.0, span = 2500.0, cap = 0.90},
                SURFACE_M = {road = 1.00, offroad = 1.25}
            },

            thresholds = {
                lowPadHealth = 25.0,
                criticalPadHealth = 8.0
            },

            penalties = {
                padHealth = {denom = 100.0, cap = 0.45},
                heatFade = {denom = 350.0, cap = 0.35}
            }
        },

        Arcade = {
            wear = {
                BASE_WEAR_PER_KM = 0.02,
                BRAKE_WEAR_PER_SEC = 0.25,
                HARD_BRAKE_WEAR = 0.30,
                HANDBRAKE_WEAR = 0.15
            },

            heat = {
                GENERATION_PER_BRAKE_SEC = 10.0,
                GENERATION_SPEED_MULT = 0.20,
                GENERATION_MASS_MULT = 0.00015,
                COOLING_AMBIENT = 0.4,
                COOLING_AIRFLOW = 0.06,
                FADE_THRESHOLD = 180.0,
                FADE_RANGE = 250.0,
                MAX_FADE = 0.50
            },

            mult = {
                SPEED_M = {base = 30.0, span = 80.0, cap = 1.50},
                MASS_M = {base = 800.0, span = 1500.0, cap = 1.20},
                SURFACE_M = {road = 1.00, offroad = 1.40}
            },

            thresholds = {
                lowPadHealth = 15.0,
                criticalPadHealth = 5.0
            },

            penalties = {
                padHealth = {denom = 60.0, cap = 0.60},
                heatFade = {denom = 250.0, cap = 0.50}
            }
        }
    },
}