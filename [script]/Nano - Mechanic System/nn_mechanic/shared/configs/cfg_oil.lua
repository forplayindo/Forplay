if not Config then Config = {} end

Config.OilQuality = {
    defaultProfile = "SemiSim",
    net = {
        telemKey = "ns_telem"
    },
    tick = {
        driving_ms = 1000,
        parked_ms = 20000
    },
    
    limits = {
        min_quality = 0.0,
        max_quality = 100.0
    },

    defaults = {
        quality = 100.0,
        lastChangeKm = 0.0
    },

    epsilon = {
        quality = 1.0
    },

    handling = {
        applyEveryMs = 1000
    },

    profiles = {
        SemiSim = {
            degradation = {
                BASE_DEGRADATION_PER_KM = 0.12 -- % quality lost per km driven
            },

            changeInterval = {
                recommendedKm = 5000.0 -- Recommended oil change interval (km)
            },

            thresholds = {
                excellent = 80.0, -- Above: no effects
                good = 50.0, -- Above: minimal effects
                fair = 30.0, -- Above: moderate effects
                poor = 15.0, -- Above: significant effects
                critical = 0.0 -- Below: severe effects
            },

            powerReduction = {
                -- Multiplier applied to fInitialDriveForce (typically 0.10-0.40)
                -- Keep values close to 1.0 to avoid making vehicles undriveable
                excellent = 1.00, -- 100% power (no effect)
                good      = 0.97, -- 97% power (barely noticeable)
                fair      = 0.93, -- 93% power (slight sluggishness)
                poor      = 0.85, -- 85% power (noticeable loss)
                critical  = 0.10  -- 70% power (significant but still driveable)
            },

            inertiaReduction = {
                -- Multiplier applied to fDriveInertia (default 1.0, range 0.01-2.0)
                -- Controls how fast the engine revs. Lower = slower revving.
                -- Values below 0.5 may noticeably slow down high-acceleration cars.
                excellent = 1.00, -- Normal rev speed
                good      = 0.97, -- Barely noticeable
                fair      = 0.93, -- Slight delay in revving
                poor      = 0.85, -- Noticeably sluggish throttle response
                critical  = 0.10  -- Very sluggish revving
            },

            effects = {
                smoke = {
                    light  = { drainPerTick = 1.0,  floorHealth = 600 },
                    medium = { drainPerTick = 3.0,  floorHealth = 300 },
                    heavy  = { drainPerTick = 6.0,  floorHealth = 100 },
                },

                stall = {
                    poor = {
                        chance          = 0.10,
                        checkIntervalMs = 12000,
                        minDurationMs   = 600,
                        maxDurationMs   = 1500,
                        shakeIntensity  = 0.15,
                        backfire        = true
                    },
                    critical = {
                        chance          = 0.45,
                        checkIntervalMs = 7000,
                        minDurationMs   = 1500,
                        maxDurationMs   = 3500,
                        shakeIntensity  = 0.35,
                        backfire        = true
                    }
                },

                knock = {
                    poor = {
                        intervalMs   = 4000,
                        durationMs   = 150,
                        torqueMult   = 0.4
                    },
                    critical = {
                        intervalMs   = 1800,
                        durationMs   = 250,
                        torqueMult   = 0.15
                    }
                }
            }
        },

        Arcade = {
            degradation = {
                BASE_DEGRADATION_PER_KM = 0.2 -- Faster degradation
            },

            changeInterval = {
                recommendedKm = 3000.0 -- Shorter change interval
            },

            thresholds = {
                excellent = 70.0,
                good = 40.0,
                fair = 25.0,
                poor = 10.0,
                critical = 0.0
            },

            powerReduction = {
                excellent = 1.00,
                good = 0.97,
                fair = 0.92,
                poor = 0.80,
                critical = 0.65
            },

            inertiaReduction = {
                excellent = 1.00,
                good      = 0.96,
                fair      = 0.90,
                poor      = 0.78,
                critical  = 0.60
            }
        }
    },
}