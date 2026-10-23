Config = {}
Config.Debug = true
Config.Language = 'en' -- en, cs

Config.Creator = {
    Command = 'cmechanic',
    Job = 'mechanic',
    SetOwnerCommand = 'setmechanicowner'
}

-- This password will give you access to /givepart command: /givepart <referenceNumber> <amount> <password>
-- ex: /givepart BMP-FR-01-002X1U52EV0 1 123
-- Remove the password to disable the command.
Config.GivePartPassword = '123'

Config.Dashboard = {
    Key = 'F7',
}

Config.AdminPanel = {
    Command = 'mechanicadmin',           -- Command to open admin panel
    DeletePassword = 'confirm123',       -- Password required to delete a shop
}

Config.AdminLogsDiscordWebhook = 'https://discord.com/api/webhooks/1467169820670955713/r-5p0vbnjlpiNHYZE2e_YkwUZrMpyVPqOSETnEdprtWRXg8JKPMwpEy9DEnn_gMsWinc'

Config.PresetService = {
    enabled        = true,
    apiUrl         = 'https://mechpresets.nanoscripts.cloud/',   -- DO NOT CHANGE if you want it working :)
    supportContact = 'discord.gg/slumpliferp',  -- shown to the admin when the service is unreachable
    healthCacheSeconds = 30,                    -- cache /health for this many seconds
}

Config.TowDispatch = {
    PlayerCommand = 'calltow',           -- Command for players to request a tow
    MechanicCommand = 'towdispatch',     -- Command for mechanics to open dispatch
    CallTimeout = 15,                    -- Minutes before a call expires
    BaseTowPrice = 500,                  -- Base price for tow service
    PricePerMile = 50,                   -- Additional price per mile
    MaxDistance = 10000,                 -- Maximum distance in meters for tow calls
}

Config.PlayerShare = 0.10 -- 10% of each invoice/tow payment goes to the employee, rest to the shop
Config.InstantPartDelivery = false -- When true, ordered parts go directly to a chosen storage point instead of the warehouse pickup flow

-- Universal Items: when enabled, parts flagged with metadata.universal = true
-- bypass the strict reference-number check and can be installed on any vehicle
-- as long as the item type matches the expected modId. Players obtain them
-- via the new "Universal Items" website on the shop computer.
Config.UniversalItems = {
    enabled = false,
    -- Per-modId allow-list. nil = all modIds allowed; { [modId] = false } to
    -- explicitly exclude a category from accepting universal items.
    allowedModIds = nil,
    -- Catalog shown on the new Universal Items website (Safari app).
    -- Each entry corresponds to one of the existing mechanic_* item names so
    -- no new items have to be added to the inventory framework.
    -- One catalog line per installable `mechanic_*` item (see shared/utils.lua
    -- ModItemMap). Register matching ox_inventory / qb-core items on your server.
    catalog = {
        { id = 'mechanic_spoiler',          label = 'Universal Spoiler',           price = 800,  description = 'Fits any spoiler slot.', image = 'spoiler' },
        { id = 'mechanic_front_bumper',    label = 'Universal Front Bumper',      price = 1200, description = 'Fits any front bumper slot.', image = 'bumper' },
        { id = 'mechanic_rear_bumper',     label = 'Universal Rear Bumper',       price = 1200, description = 'Fits any rear bumper slot.', image = 'bumper' },
        { id = 'mechanic_side_skirt',      label = 'Universal Side Skirt',        price = 900,  description = 'Fits any side skirt slot.', image = 'skirt' },
        { id = 'mechanic_exhaust',         label = 'Universal Exhaust',           price = 1100, description = 'Fits any exhaust slot.', image = 'exhaust' },
        { id = 'mechanic_roll_cage',       label = 'Universal Roll Cage',         price = 1500, description = 'Fits any roll cage slot.', image = 'cage' },
        { id = 'mechanic_grille',          label = 'Universal Grille',            price = 700,  description = 'Fits any grille slot.', image = 'grille' },
        { id = 'mechanic_hood',            label = 'Universal Hood',              price = 1800, description = 'Fits any hood slot.', image = 'hood' },
        { id = 'mechanic_fender',          label = 'Universal Fender / Arch',    price = 1000, description = 'Fits fenders and arch covers.', image = 'fender' },
        { id = 'mechanic_roof',            label = 'Universal Roof',              price = 800,  description = 'Fits any roof trim slot.', image = 'roof' },
        { id = 'mechanic_engine',          label = 'Universal Engine Upgrade',    price = 5000, description = 'Stock or swap engine install.', image = 'engine' },
        { id = 'mechanic_brakes',          label = 'Universal Brakes',            price = 1200, description = 'Fits any brake upgrade slot.', image = 'brakes' },
        { id = 'mechanic_transmission',    label = 'Universal Transmission',      price = 2500, description = 'Fits any transmission slot.', image = 'transmission' },
        { id = 'mechanic_horn',            label = 'Universal Horn',              price = 400,  description = 'Fits any horn slot.', image = 'horn' },
        { id = 'mechanic_suspension',      label = 'Universal Suspension',        price = 1800, description = 'Fits suspension upgrade slot.', image = 'suspension' },
        { id = 'mechanic_armor',           label = 'Universal Armor',             price = 3500, description = 'Fits armor upgrade slot.', image = 'body' },
        { id = 'mechanic_nitrous',         label = 'Universal Nitrous',           price = 4000, description = 'Fits nitrous install.', image = 'body' },
        { id = 'mechanic_turbo',           label = 'Universal Turbo',             price = 3000, description = 'Fits turbo slot.', image = 'turbo' },
        { id = 'mechanic_subwoofer',       label = 'Universal Subwoofer',         price = 600,  description = 'Fits subwoofer slot.', image = 'interior' },
        { id = 'mechanic_tyre_smoke',      label = 'Universal Tyre Smoke',        price = 400,  description = 'Tyre smoke kit slot.', image = 'body' },
        { id = 'mechanic_hydraulics',      label = 'Universal Hydraulics',        price = 2200, description = 'Vehicle hydraulics slot.', image = 'body' },
        { id = 'mechanic_xenon',           label = 'Universal Xenon',             price = 800,  description = 'Xenon / headlight kit slot.', image = 'body' },
        { id = 'mechanic_wheels',          label = 'Universal Wheel Set',         price = 1500, description = 'Installs order wheel choice.', image = 'wheels' },
        { id = 'mechanic_plate_holder',    label = 'Universal Plate Holder',      price = 350,  description = 'Plate holder slot.', image = 'body' },
        { id = 'mechanic_vanity_plate',    label = 'Universal Vanity Plate',      price = 350,  description = 'Vanity plate slot.', image = 'body' },
        { id = 'mechanic_trim_a',          label = 'Universal Trim A',            price = 550,  description = 'Interior trim A slot.', image = 'interior' },
        { id = 'mechanic_ornaments',       label = 'Universal Ornaments',         price = 450,  description = 'Ornaments slot.', image = 'interior' },
        { id = 'mechanic_dashboard',       label = 'Universal Dashboard',         price = 700,  description = 'Dashboard slot.', image = 'interior' },
        { id = 'mechanic_dial',            label = 'Universal Dials',             price = 500,  description = 'Dial cluster slot.', image = 'interior' },
        { id = 'mechanic_door_speaker',    label = 'Universal Door Speaker',      price = 500,  description = 'Door speaker slot.', image = 'interior' },
        { id = 'mechanic_seats',           label = 'Universal Seats',             price = 900,  description = 'Seat slot.', image = 'interior' },
        { id = 'mechanic_steering_wheel',  label = 'Universal Steering Wheel',    price = 650,  description = 'Steering wheel slot.', image = 'interior' },
        { id = 'mechanic_shifter_lever',   label = 'Universal Shifter',           price = 500,  description = 'Shifter lever slot.', image = 'interior' },
        { id = 'mechanic_plaque',          label = 'Universal Plaque',            price = 400,  description = 'Plaque slot.', image = 'interior' },
        { id = 'mechanic_speaker',         label = 'Universal Speaker Kit',       price = 550,  description = 'Speaker kit slot.', image = 'interior' },
        { id = 'mechanic_trunk',           label = 'Universal Trunk',             price = 600,  description = 'Trunk display slot.', image = 'interior' },
        { id = 'mechanic_hydraulic_kit',   label = 'Universal Engine Hydraulic',  price = 1800, description = 'Engine bay hydraulic slot.', image = 'engine' },
        { id = 'mechanic_engine_block',    label = 'Universal Engine Block',      price = 4500, description = 'Engine block cosmetic slot.', image = 'engine' },
        { id = 'mechanic_air_filter',      label = 'Universal Air Filter',        price = 700,  description = 'Air filter slot.', image = 'engine' },
        { id = 'mechanic_strut',           label = 'Universal Strut',             price = 1400, description = 'Strut / brace slot.', image = 'suspension' },
        { id = 'mechanic_aerial',          label = 'Universal Aerial',            price = 350,  description = 'Aerial slot.', image = 'body' },
        { id = 'mechanic_trim_b',          label = 'Universal Trim B',            price = 550,  description = 'Interior trim B slot.', image = 'interior' },
        { id = 'mechanic_fuel_tank',       label = 'Universal Fuel Tank',         price = 1200, description = 'Fuel tank slot.', image = 'body' },
        { id = 'mechanic_left_door',       label = 'Universal Left Door Shell',   price = 1800, description = 'Left door slot.', image = 'body' },
        { id = 'mechanic_right_door',      label = 'Universal Right Door Shell',  price = 1800, description = 'Right door slot.', image = 'body' },
        { id = 'mechanic_livery',          label = 'Universal Livery Kit',        price = 2500, description = 'Livery install.', image = 'body' },
        { id = 'mechanic_lightbar',        label = 'Universal Lightbar',          price = 1100, description = 'Lightbar slot.', image = 'body' },
        { id = 'mechanic_plate_index',     label = 'Universal Plate Index',       price = 300,  description = 'Plate style index slot.', image = 'body' },
        { id = 'mechanic_window_tint',     label = 'Universal Window Tint',       price = 650,  description = 'Window tint install.', image = 'window_tint' },
        { id = 'mechanic_extras',          label = 'Universal Extras',          price = 500,  description = 'Vehicle extras slot.', image = 'body' },
        -- Legacy catch-all (still registered for old inventories); prefer per-mod items from ModItemMap.
        { id = 'mechanic_interior',        label = 'Universal Interior (legacy)', price = 700, description = 'Legacy multi-slot interior item.', image = 'interior' },
    },
    deliveryTime = 5, -- minutes (uses the existing supplier delivery pipeline)
    supplierCode = 'UI',
    instantDelivery = true, -- Universal items are delivered straight to the shop storage
}

-- Tool Matching minigame difficulty presets.
-- have per round (in ms), and how many tools are shown in the grid (max 6).
Config.ToolMatching = {
    defaultDifficulty = 'medium', -- 'easy' or 'medium' or 'hard'
    difficulties = {
        easy   = { rounds = 3, timeMs = 3500, toolCount = 4 },
        medium = { rounds = 5, timeMs = 2500, toolCount = 5 },
        hard   = { rounds = 7, timeMs = 1800, toolCount = 6 },
    },
}

Config.CarLiftSearchRadius = 10.0

Config.NanoLiftStyles = {
    [1] = {
        body = 'nano_lift_body_1',
        arms = 'nano_lift_arms_1',
        armsOffset = vector3(0.0, 0.0, 0.0),
        armsRotation = vector3(0.0, 0.0, 0.0),
        vehicleOffset = vector3(0.0, 0.0, 0.35),
    },
    [2] = {
        body = 'nano_lift_body_2',
        arms = 'nano_lift_arms_2',
        armsOffset = vector3(0.0, 0.0, 0.0),
        armsRotation = vector3(0.0, 0.0, 0.0),
        vehicleOffset = vector3(-0.2, 0.0, 0.62),
    },
}

Config.AddEngineToInventoryAfterDeposit = true -- When true, the engine is added to the inventory after it is deposited
Config.EngineSwap = {
    
    engines = {
        ["v10_52"] = {
            meta = {
                label = "5.2L V10",
                description = "Naturally aspirated V10. Screams to 8,500 RPM. Motorsport DNA.",
                item = "v10_52_engine",
                price = 135000,
                category = "combustion",
            },
            audio = { preset = "t20" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = { "panto" },
                allowedClasses = { "sports", "super" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 1.64,
                    fClutchChangeRateScaleDownShift = 10.3,
                    fClutchChangeRateScaleUpShift = 11.3,
                    fInitialDriveMaxFlatVel = 415.0,
                    fDriveInertia = 1.63,
                }
            }
        },

        ["v8_40tt"] = {
            meta = {
                label = "4.0L V8 Twin-Turbo",
                description = "High-revving flat-plane V8 with twin turbos. Exotic-tier performance.",
                item = "v8_40tt_engine",
                price = 120000,
                category = "combustion",
            },
            audio = { preset = "jugular" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = { "panto" },
                allowedClasses = { "sports", "super", "coupes" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.52,
                    fClutchChangeRateScaleDownShift = 7.0,
                    fClutchChangeRateScaleUpShift = 8.5,
                    fInitialDriveMaxFlatVel = 232.0,
                    fDriveInertia = 1.1,
                }
            }
        },

        ["v8_67d"] = {
            meta = {
                label = "6.7L V8 Diesel",
                description = "Turbodiesel V8. Enormous low-end torque, built for towing and off-road.",
                item = "v8_67d_engine",
                price = 55000,
                category = "combustion",
            },
            audio = { preset = "bison" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "suvs", "off_road", "vans", "utility" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.42,
                    fClutchChangeRateScaleDownShift = 3.0,
                    fClutchChangeRateScaleUpShift = 3.5,
                    fInitialDriveMaxFlatVel = 135.0,
                    fDriveInertia = 0.55,
                }
            }
        },

        ["v6_35"] = {
            meta = {
                label = "3.5L V6",
                description = "Naturally aspirated V6. Reliable torque across the rev range.",
                item = "v6_35_engine",
                price = 35000,
                category = "combustion",
            },
            audio = { preset = "oracle" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "sedans", "suvs", "coupes", "muscle" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.28,
                    fClutchChangeRateScaleDownShift = 4.2,
                    fClutchChangeRateScaleUpShift = 5.0,
                    fInitialDriveMaxFlatVel = 168.0,
                    fDriveInertia = 0.9,
                }
            }
        },

        ["i4_20t"] = {
            meta = {
                label = "2.0L I4 Custom",
                description = "Punchy turbo-four with good mid-range. Popular swap for lighter chassis.",
                item = "i4_20t_engine",
                price = 28000,
                category = "combustion",
            },
            audio = { preset = "sultan" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "compacts", "sedans", "coupes", "sportsclassics" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.26,
                    fClutchChangeRateScaleDownShift = 4.5,
                    fClutchChangeRateScaleUpShift = 5.5,
                    fInitialDriveMaxFlatVel = 157.0,
                    fDriveInertia = 1.0,
                }
            }
        },

        ["i4_14t"] = {
            meta = {
                label = "1.4L I4 Turbo",
                description = "Efficient turbo four-cylinder. Zippy in the city, modest on highways.",
                item = "i4_14t_engine",
                price = 18000,
                category = "combustion",
            },
            audio = { preset = "blista" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "compacts", "sedans", "vans" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.18,
                    fClutchChangeRateScaleDownShift = 3.8,
                    fClutchChangeRateScaleUpShift = 4.5,
                    fInitialDriveMaxFlatVel = 116.0,
                    fDriveInertia = 1.05,
                }
            }
        },

        ["h4_25t"] = {
            meta = {
                label = "2.5L Flat-4 Turbo",
                description = "Boxer turbo-four. Low COG, rally heritage. Characteristic burble.",
                item = "h4_25t_engine",
                price = 42000,
                category = "combustion",
            },
            audio = { preset = "sultan2" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "compacts", "sedans", "coupes", "sports" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.29,
                    fClutchChangeRateScaleDownShift = 5.0,
                    fClutchChangeRateScaleUpShift = 6.0,
                    fInitialDriveMaxFlatVel = 176.0,
                    fDriveInertia = 1.05,
                }
            }
        },

        ["v8_50"] = {
            meta = {
                label = "5.0L V8",
                description = "Classic naturally aspirated V8. Deep rumble, strong low-end torque.",
                item = "v8_50_engine",
                price = 62000,
                category = "combustion",
            },
            audio = { preset = "dominator" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "muscle", "sportsclassics", "sports", "suvs" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.38,
                    fClutchChangeRateScaleDownShift = 4.5,
                    fClutchChangeRateScaleUpShift = 5.5,
                    fInitialDriveMaxFlatVel = 190.0,
                    fDriveInertia = 0.8,
                }
            }
        },

        ["v8_62sc"] = {
            meta = {
                label = "6.2L V8 Supercharged",
                description = "Roots-blown V8. Instant boost, massive low-end torque. Drinks fuel.",
                item = "v8_62sc_engine",
                price = 95000,
                category = "combustion",
            },
            audio = { preset = "gauntlet" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = { "panto" },
                allowedClasses = { "muscle", "sports", "super" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.48,
                    fClutchChangeRateScaleDownShift = 6.0,
                    fClutchChangeRateScaleUpShift = 7.5,
                    fInitialDriveMaxFlatVel = 217.0,
                    fDriveInertia = 0.85,
                }
            }
        },

        ["i6_30t"] = {
            meta = {
                label = "3.0L I6 Twin-Turbo",
                description = "Silky-smooth inline-six with twin turbos. Linear power, refined feel.",
                item = "i6_30t_engine",
                price = 48000,
                category = "combustion",
            },
            audio = { preset = "comet4" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "sedans", "coupes", "sports", "sportsclassics" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.32,
                    fClutchChangeRateScaleDownShift = 5.5,
                    fClutchChangeRateScaleUpShift = 6.5,
                    fInitialDriveMaxFlatVel = 187.0,
                    fDriveInertia = 0.95,
                }
            }
        },

        ["v6_35tt"] = {
            meta = {
                label = "3.5L V6 Twin-Turbo",
                description = "Force-fed V6 with explosive mid-range. Punches above its displacement.",
                item = "v6_35tt_engine",
                price = 58000,
                category = "combustion",
            },
            audio = { preset = "ninef" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = {  },
                allowedClasses = { "coupes", "sports", "sportsclassics", "muscle" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.36,
                    fClutchChangeRateScaleDownShift = 5.8,
                    fClutchChangeRateScaleUpShift = 7.0,
                    fInitialDriveMaxFlatVel = 198.0,
                    fDriveInertia = 1.0,
                }
            }
        },

        ["v12_65"] = {
            meta = {
                label = "6.5L V12",
                description = "Hand-built V12. Effortless power delivery, unmatched refinement.",
                item = "v12_65_engine",
                price = 185000,
                category = "combustion",
            },
            audio = { preset = "entityxf" },
            compatibility = {
                allowedFuel = { "combustion" },
                blacklistModels = { "panto" },
                allowedClasses = { "super" },
            },
            handling = {
                mode = "set",
                values = {
                    fInitialDriveForce = 0.55,
                    fClutchChangeRateScaleDownShift = 6.5,
                    fClutchChangeRateScaleUpShift = 8.0,
                    fInitialDriveMaxFlatVel = 247.0,
                    fDriveInertia = 0.85,
                }
            }
        },
    }
}


local COMMON_REPAIR_DEFAULT_PROP = 'hei_prop_heist_box'
local COMMON_REPAIR_DEFAULT_ATTACH = {
    bone = 60309,
    coords = { x = 0.025, y = 0.08, z = 0.255 },
    rotation = { x = -145.0, y = 290.0, z = 0.0 }
}

-- Optional per-mod deposit prop overrides.
-- Supported formats:
-- [modId] = 'prop_name'
-- [modId] = {
--     prop = 'prop_name',
--     bone = 57005,
--     coords = { x = 0.0, y = 0.0, z = 0.0 },
--     rotation = { x = 0.0, y = 0.0, z = 0.0 }
-- }
Config.CommonRepairPropOverrides = {
    [0]  = 'imp_prop_impexp_spoiler_02a', -- Spoiler
    [1]  = 'prop_bumper_02',              -- Front Bumper
    [2]  = 'prop_bumper_02',              -- Rear Bumper
    [3]  = 'prop_bumper_02',              -- Side Skirt
    [4]  = 'prop_car_exhaust_01',         -- Exhaust
    [7]  = 'imp_prop_impexp_bonnet_01a',  -- Hood
    [8]  = 'prop_car_door_03',            -- Left Fender
    [9]  = 'prop_car_door_04',            -- Right Fender
    [32] = 'prop_car_seat',               -- Seats
    [37] = 'imp_prop_impexp_trunk_01a',   -- Trunk
    [46] = 'prop_car_door_01',            -- Left Door
    [47] = 'prop_car_door_02',            -- Right Door
    [25] = 'p_num_plate_01',              -- Plate Holder
    [26] = 'p_num_plate_02',              -- Vanity Plates
    [50] = 'p_num_plate_03',              -- Plate Index
}

local COMMON_REPAIR_LABELS = {
    [0] = 'Spoiler',
    [1] = 'Front Bumper',
    [2] = 'Rear Bumper',
    [3] = 'Side Skirt',
    [4] = 'Exhaust',
    [5] = 'Roll Cage',
    [6] = 'Grille',
    [7] = 'Hood',
    [8] = 'Left Fender',
    [9] = 'Right Fender',
    [10] = 'Roof',
    [11] = 'Engine Upgrade',
    [12] = 'Brake Upgrade',
    [13] = 'Transmission Upgrade',
    [14] = 'Horns',
    [15] = 'Suspension Upgrade',
    [16] = 'Armor Upgrade',
    [17] = 'Nitrous',
    [18] = 'Turbo Upgrade',
    [19] = 'Subwoofer',
    [21] = 'Hydraulics',
    [23] = 'Wheels',
    [25] = 'Plate Holder',
    [26] = 'Vanity Plates',
    [27] = 'Trim A',
    [28] = 'Ornaments',
    [29] = 'Dashboard',
    [30] = 'Dial',
    [31] = 'Door Speaker',
    [32] = 'Seats',
    [33] = 'Steering Wheel',
    [34] = 'Shifter Lever',
    [35] = 'Plaque',
    [36] = 'Speaker',
    [37] = 'Trunk',
    [38] = 'Hydraulic',
    [39] = 'Engine Block',
    [40] = 'Air Filter',
    [41] = 'Strut',
    [42] = 'Arch Cover',
    [43] = 'Aerial',
    [44] = 'Trim B',
    [45] = 'Fuel Tank',
    [46] = 'Left Door',
    [47] = 'Right Door',
    -- [48] Livery is intentionally omitted; liveries use the dedicated
    -- vinyl-wrap flow (StartLiveryInstall / InstallRecipes.livery_install)
    -- instead of the remove/deposit/install common-repair pipeline.
    [49] = 'Lightbar',
    [50] = 'Plate Index',
    [51] = 'Window Tint',
    [52] = 'Extra',
}

local function makeCommonRepairProgress(label)
    return {
        duration = 10000,
        label = label,
        animation = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
        },
    }
end

local function buildCommonRepairPropAttach(propConfig)
    if type(propConfig) == 'string' then
        return {
            prop = propConfig,
            bone = COMMON_REPAIR_DEFAULT_ATTACH.bone,
            coords = COMMON_REPAIR_DEFAULT_ATTACH.coords,
            rotation = COMMON_REPAIR_DEFAULT_ATTACH.rotation,
        }
    end

    if type(propConfig) == 'table' then
        return {
            prop = propConfig.prop or COMMON_REPAIR_DEFAULT_PROP,
            bone = propConfig.bone or COMMON_REPAIR_DEFAULT_ATTACH.bone,
            coords = propConfig.coords or COMMON_REPAIR_DEFAULT_ATTACH.coords,
            rotation = propConfig.rotation or COMMON_REPAIR_DEFAULT_ATTACH.rotation,
        }
    end

    return {
        prop = COMMON_REPAIR_DEFAULT_PROP,
        bone = COMMON_REPAIR_DEFAULT_ATTACH.bone,
        coords = COMMON_REPAIR_DEFAULT_ATTACH.coords,
        rotation = COMMON_REPAIR_DEFAULT_ATTACH.rotation,
    }
end

local function makeCommonRepairConfig(partLabel, propConfig)
    local lowerLabel = string.lower(partLabel)
    local propAttach = buildCommonRepairPropAttach(propConfig)

    return {
        [1] = {
            type = 'remove',
            progressbar = makeCommonRepairProgress(('Removing %s...'):format(lowerLabel)),
            menuLabel = ('Remove %s'):format(partLabel),
            minigame = 'key_press_timing'
        },
        [2] = {
            type = 'deposit',
            propAttach = propAttach,
            menuLabel = ('Deposit %s'):format(partLabel),
        },
        [3] = {
            type = 'install',
            progressbar = makeCommonRepairProgress(('Installing %s...'):format(lowerLabel)),
            menuLabel = ('Install %s'):format(partLabel),
            minigame = 'tool_matching'
        }
    }
end

Config.CommonRepairs = {}

for modId, partLabel in pairs(COMMON_REPAIR_LABELS) do
    Config.CommonRepairs[modId] = makeCommonRepairConfig(partLabel, Config.CommonRepairPropOverrides[modId])
end

-- Parts that require the vehicle to be attached and raised on a lift before
-- installation can proceed. When true, the install flow will show attach/lift
-- instructions first. Add or remove mod IDs as needed.
-- Can also be overridden per-recipe in shared/install_recipes.lua via requiresLift = true/false.
Config.RequiresLift = {
    [12] = true, -- Brakes
    [15] = true, -- Suspension
}


local commonRepairFallbackCache = {}

function Config.GetCommonRepairConfig(modId)
    if Config.CommonRepairs[modId] then
        return Config.CommonRepairs[modId]
    end

    if not commonRepairFallbackCache[modId] then
        local partLabel = COMMON_REPAIR_LABELS[modId] or ('Part %s'):format(tostring(modId))
        commonRepairFallbackCache[modId] = makeCommonRepairConfig(partLabel, Config.CommonRepairPropOverrides[modId])
    end

    return commonRepairFallbackCache[modId]
end

Config.VehicleUpdateInterval = 1000 -- 1 second
Config.VehicleUpgrades = {
    ['towtruck_large'] = {
        price = 15000,
        label = 'Tow Truck (large)',
        description = 'Heavy-duty vehicle for towing disabled vehicles',
        model = 'towtruck'
    },
    ['towtruck_small'] = {
        price = 10000,
        label = 'Tow Truck (small)',
        description = 'Small vehicle for towing disabled vehicles',
        model = 'towtruck2'
    },
    ['flatbed_truck'] = {
        price = 12000,
        label = 'Flatbed Truck',
        description = 'Transport vehicle for carrying multiple cars',
        model = 'flatbed'
    },
    ['bobcat_xl'] = {
        price = 15000,
        label = 'Bobcat XL',
        description = 'Heavy-duty vehicle for towing disabled vehicles',
        model = 'bobcatxl'
    },
    ['mule'] = {
        price = 15000,
        label = 'Mule',
        description = 'Heavy-duty vehicle for towing disabled vehicles',
        model = 'mule'
    }
}

Config.Rarity = {
    availabilityChance = {
        common = 1.0,      -- 80% chance
        rare = 1.0,        -- 50% chance
        epic = 1.0,        -- 25% chance
        legendary = 1.0    -- 10% chance
    },
    quantityLimits = {
        common = 10,        -- Max 10 per order
        rare = 5,           -- Max 5 per order
        epic = 2,           -- Max 2 per order
        legendary = 1       -- Max 1 per order
    },
    deliveryTimeMultiplier = {
        common = 1.0,       -- Base time
        rare = 1.5,         -- 1.5x longer
        epic = 2.0,         -- 2x longer
        legendary = 3.0     -- 3x longer
    },
    baseDeliveryTime = 1  -- Base delivery time in minutes
}

Config.WarehouseLocations = {
    UB = {
        coords = vector3(vec3(827.73, -3204.52, 5.9)),  -- UrbanBody Shop warehouse
        heading = 180.0,
        pedModel = 'a_m_m_eastsa_02',
        blipColor = 17  -- Orange
    },
    GL = {
        coords = vector3(765.68, -3202.92, 5.98),  -- GripLine Wheels warehouse
        heading = 268.31,
        pedModel = 'a_m_m_eastsa_02',
        blipColor = 2  -- Green
    },
    RL = {
        coords = vector3(921.92, -2487.0, 28.49),  -- Redline Tuning warehouse
        heading = 353.4,
        pedModel = 'a_m_m_eastsa_02',
        blipColor = 1  -- Red
    },
    MS = {
        coords = vector3(767.27, -3170.32, 5.9),  -- MechSupply warehouse
        heading = 277.54,
        pedModel = 'a_m_m_eastsa_02',
        blipColor = 46  -- Amber/Yellow
    }
}

Config.MechSupplyCatalog = {
    categories = {
        { id = 'tools', name = 'Tools & Equipment', icon = 'wrench' },
        { id = 'fluids', name = 'Fluids & Brake Components', icon = 'droplet' },
        { id = 'repair', name = 'Repair Kits', icon = 'tool' },
        { id = 'lighting', name = 'Lighting & Electronics', icon = 'lightbulb' },
        { id = 'stance', name = 'Stance & Suspension', icon = 'circle' },
        { id = 'performance', name = 'Performance & Boost', icon = 'zap' },
    },
    items = {
        { id = 'mechanic_tablet', name = 'Mechanic Tablet', category = 'tools', price = 2500, image = 'https://cfx-nui-ox_inventory/web/images/mechanic_tablet.png', description = 'See and manage all your mechanic order using this tablet' },
        { id = 'obd_tablet', name = 'OBD Tablet', category = 'tools', price = 2500, image = 'https://cfx-nui-ox_inventory/web/images/obd_tablet.png', description = 'Diagnose all vehicles using this OBD tablet' },
        { id = 'engine_lift', name = 'Engine Lift', category = 'tools', price = 2500, image = 'engine', description = 'Heavy-duty engine hoist for professional mechanics' },
        { id = 'mechanic_air_compressor', name = 'Air Compressor', category = 'tools', price = 1200, image = 'mechanic_air_compressor', description = 'Industrial air compressor for pneumatic tools' },
        { id = 'empty_spray_gun', name = 'Spray Gun', category = 'tools', price = 350, image = 'spray_gun', description = 'Professional paint spray gun' },
        { id = 'mechanic_lights_control', name = 'Lights Control Unit', category = 'tools', price = 450, image = 'mechanic_lights_control', description = 'Electronic lighting control system' },

        { id = 'mechanic_oil_basic', name = 'Basic Engine Oil', category = 'fluids', price = 50, image = 'mechanic_oil_basic', description = 'Standard mineral engine oil' },
        { id = 'mechanic_oil_semi_synth', name = 'Semi-Synthetic Oil', category = 'fluids', price = 85, image = 'mechanic_oil_semi_synth', description = 'Semi-synthetic blend for better performance' },
        { id = 'mechanic_oil_full', name = 'Full Synthetic Oil', category = 'fluids', price = 120, image = 'mechanic_oil_full', description = 'Premium full synthetic engine oil' },
        { id = 'mechanic_oil_heavy', name = 'Heavy Duty Oil', category = 'fluids', price = 150, image = 'mechanic_oil_heavy', description = 'Heavy-duty oil for trucks and SUVs' },
        { id = 'brake_pads_basic', name = 'Basic Brake Pads', category = 'fluids', price = 75, image = 'brakes', description = 'Standard replacement brake pads' },
        { id = 'brake_pads_semi_metallic', name = 'Semi-Metallic Brake Pads', category = 'fluids', price = 120, image = 'brakes', description = 'Semi-metallic pads for improved stopping' },
        { id = 'brake_pads_full_performance', name = 'Performance Brake Pads', category = 'fluids', price = 200, image = 'brakes', description = 'High-performance ceramic brake pads' },
        { id = 'brake_pads_heavy_duty', name = 'Heavy Duty Brake Pads', category = 'fluids', price = 180, image = 'brakes', description = 'Heavy-duty pads for trucks' },

        { id = 'mechanic_engine_repair_kit', name = 'Engine Repair Kit', category = 'repair', price = 500, image = 'engine', description = 'Complete engine repair toolkit' },
        { id = 'mechanic_body_repair_kit', name = 'Body Repair Kit', category = 'repair', price = 350, image = 'body', description = 'Body panel repair and dent removal kit' },

        { id = 'mechanic_neon_light', name = 'Mechanic Neon Light', category = 'lighting', price = 250, image = 'mechanic_neon_light', description = 'Workshop neon lighting' },
        { id = 'mechanic_xenon_light', name = 'Xenon Light Kit', category = 'lighting', price = 400, image = 'mechanic_xenon_light', description = 'HID xenon headlight conversion kit' },

        { id = 'stance_kit', name = 'Stance Kit', category = 'stance', price = 800, image = 'stance_kit', description = 'Complete stance adjustment kit' },
        { id = 'stance_controller', name = 'Stance Controller', category = 'stance', price = 450, image = 'stance_kit', description = 'Electronic stance control unit' },
        { id = 'mechanic_suspension', name = 'Suspension Kit', category = 'stance', price = 1200, image = 'suspension', description = 'Full suspension upgrade kit' },

        { id = 'nitro_bottle_small', name = 'Small Nitro Bottle', category = 'performance', price = 500, image = 'nitro_bottle_small', description = '5lb nitrous oxide bottle' },
        { id = 'nitro_bottle_medium', name = 'Medium Nitro Bottle', category = 'performance', price = 750, image = 'nitro_bottle_medium', description = '10lb nitrous oxide bottle' },
        { id = 'nitro_bottle_large', name = 'Large Nitro Bottle', category = 'performance', price = 1000, image = 'nitro_bottle_large', description = '15lb nitrous oxide bottle' },
    }
}

Config.NeonEffects = {
    enabled = true,
    interval = 80,
    rgbSpeed = 10,
    pulseSpeed = 3,
}

Config.TirePressure = {
    maxPressure = 50, -- PSI threshold for explosion
    wheelLabels = {
        [0] = "Front Left",
        [1] = "Front Right",
        [2] = "Rear Left",
        [3] = "Rear Right",
        [4] = "Rear" -- bike rear
    },
    bikeWheelLabels = {
        [0] = "Front",
        [4] = "Rear"
    }
}

-- Shared helper: returns the wheel indices for a given vehicle class
function GetWheelIndicesForClass(vehClass)
    if vehClass == 8 then -- Motorcycles
        return {0, 4}
    end
    return {0, 1, 2, 3}
end

-- Shared helper: returns the wheel labels for a given vehicle class
function GetWheelLabelsForClass(vehClass)
    if vehClass == 8 then -- Motorcycles
        return Config.TirePressure.bikeWheelLabels
    end
    return Config.TirePressure.wheelLabels
end

-- Shared helper: returns true if the vehicle class is a motorcycle
function IsBikeClass(vehClass)
    return vehClass == 8
end

Config.OilClasses = {
    [0] = "basic",          -- Compacts
    [1] = "basic",          -- Sedans
    [2] = "semi",           -- SUVs
    [3] = "semi",           -- Coupes
    [4] = "semi",           -- Muscle
    [5] = "semi",           -- Sports Classics
    [6] = "full",           -- Sports
    [7] = "full",           -- Super
    [8] = "semi",           -- Motorcycles (medium performance)
    [9] = "semi",           -- Off-road
    [10] = "heavy",         -- Industrial
    [11] = "heavy",         -- Utility
    [12] = "basic",         -- Vans
    [13] = "none",          -- Cycles
    [17] = "basic",         -- Service
    [18] = "full",          -- Emergency
    [19] = "full",          -- Military
    [22] = "full",          -- Open Wheel (F1)
}

Config.BreakpadsClasses = {
    [0] = "basic",              -- Compacts
    [1] = "semi_metallic",      -- Sedans
    [2] = "heavy_duty",         -- SUVs
    [3] = "semi_metallic",      -- Coupes
    [4] = "full_performance",   -- Muscle
    [5] = "semi_metallic",      -- Sports Classics
    [6] = "full_performance",   -- Sports
    [7] = "full_performance",   -- Super
    [8] = "full_performance",   -- Motorcycles
    [9] = "heavy_duty",         -- Off-road
    [10] = "heavy_duty",        -- Industrial
    [11] = "heavy_duty",        -- Utility
    [12] = "semi_metallic",     -- Vans
    [13] = "basic",             -- Cycles
    [17] = "heavy_duty",        -- Service
    [18] = "full_performance",  -- Emergency
    [22] = "full_performance",  -- Open Wheel (F1)
}

-- Default markup percentage for shop prices over supplier prices (0.20 = 20%)
-- Shops can override individual prices via the AutoLedger website
Config.DefaultShopMarkup = 0.20

Config.PriceLimits = {
    -- Mod ID based limits
    [11] = {min = 5000, max = 50000},      -- Engine
    [12] = {min = 1000, max = 10000},      -- Brakes
    [13] = {min = 2000, max = 25000},      -- Transmission
    [15] = {min = 1500, max = 20000},      -- Suspension
    [18] = {min = 5000, max = 15000},      -- Turbo
    [23] = {min = 200, max = 2000},        -- Wheels
    [50] = {min = 50, max = 500},          -- Plate Index
    [51] = {min = 100, max = 1000},        -- Window Tint
    
    -- Category based limits
    ['cosmetic'] = {min = 100, max = 2000},
    ['colors'] = {min = 500, max = 5000},
    ['extra_colours'] = {min = 200, max = 3000},
    ['tyre_smoke'] = {min = 100, max = 2000},
    ['neon_lights'] = {min = 500, max = 5000},
    ['xenon_lights'] = {min = 500, max = 5000},
}

-- Towing configuration
Config.Towing = {
    radius = 10.0,
}

Config.Stance = {
    enabled = true
}

-- Nitro configuration
Config.Nitro = {
    enabled = true,
    maxBottles = 3,                    -- Maximum bottles per vehicle
    engineMinLevel = 3,                -- Minimum engine upgrade level (1-4, 0-indexed: 2 = level 3)
    allowElectric = false,             -- Whether electric vehicles can use nitro
    screenEffectsEnabled = true,       -- Whether to enable screen effects
    
    -- Control settings
    controls = {
        keyboardKey = 19,              -- INPUT_CHARACTER_WHEEL (Alt by default)
        controllerKey = 73,            -- INPUT_VEH_DUCK (A/X button)
        useAccelerateForBoost = true,  -- If true, hold nitro + accelerate = boost, hold nitro only = purge
    },
    
    -- Fuel settings
    fuel = {
        drainRate = 0.5,                -- Fuel drained per tick while boosting
        purgeMultiplier = 2,           -- Purge drains fuel at this multiplier
        rechargeRate = 5,              -- Fuel recharged per tick when not using
        rechargeCooldown = 2500,       -- Ms after using before recharge starts
    },
    
    -- Bottle definitions (item name -> stats)
    bottles = {
        ['nitro_bottle_small'] = {
            label = 'Small Nitro Bottle',
            capacity = 1500,           -- Fuel capacity
            power = 1.5,               -- Torque multiplier base
            strength = 1.0,            -- Effect intensity
        },
        ['nitro_bottle_medium'] = {
            label = 'Medium Nitro Bottle',
            capacity = 2500,
            power = 2.0,
            strength = 1.25,
        },
        ['nitro_bottle_large'] = {
            label = 'Large Nitro Bottle',
            capacity = 4000,
            power = 2.5,
            strength = 1.5,
        },
    },
    
    
    -- Electric vehicle models (cannot install nitro)
    electricVehicles = {
        ['airtug'] = true,
        ['cyclone'] = true,
        ['caddy'] = true,
        ['caddy2'] = true,
        ['caddy3'] = true,
        ['dilettante'] = true,
        ['imorgon'] = true,
        ['khamel'] = true,
        ['neon'] = true,
        ['raiden'] = true,
        ['surge'] = true,
        ['voltic'] = true,
        ['voltic2'] = true,
        ['tezeract'] = true,
    },
}

Config.SoundEffects = {
    urls = {
        lift = 'https://s3.nanoscripts.cloud/mechanic/sound_effects/carlift.mp3',
        liftstop = 'https://s3.nanoscripts.cloud/mechanic/sound_effects/liftstop.mp3',
        pressure = 'https://s3.nanoscripts.cloud/mechanic/sound_effects/pressure.mp3'
    },
    config = {
        lift = { distance = 15.0, volume = 0.35, fadeout = 50 },           -- Looping lift motor sound
        liftstop = { distance = 15.0, volume = 0.4, fadein = 200 },        -- One-shot stop sound with fade in
        pressure = { distance = 10.0, volume = 0.35, fadeout = 0 }         -- Air compressor pressure sound (instant stop)
    }
}

Config.PublicShopRepair = {
    enabled = true,                 -- Enable the repair prompt for damaged vehicles at public shops
    price = 500,                    -- Price to repair the vehicle
    bodyThreshold = 999,            -- Body health below this value triggers repair prompt (1000 = pristine)
    engineThreshold = 999,          -- Engine health below this value triggers repair prompt (1000 = pristine)
}

Config.PointMarkers = {
    markerType = 27,                 -- 1 = Cylinder, 2 = Inverted cylinder, 20 = Circle with X, 21 = Halo, etc.
    size = vector3(1.0, 1.0, 1.0),
    alpha = 150,
    bobUpAndDown = false,
    drawDistance = 10.0,
    rotate = false,
    zOffset = -0.9,
    colors = {
        dyno_station = { r = 239, g = 68, b = 68 },      -- Red (matches dyno point color)
        storage = { r = 139, g = 92, b = 246 },          -- Purple (matches storage point color)
        customer_garage = { r = 245, g = 158, b = 11 },  -- Amber (matches customer garage point color)
        car_lift = { r = 6, g = 182, b = 212 },          -- Cyan (matches car lift point color)
        part_deposit = { r = 249, g = 115, b = 22 },     -- Orange (matches part deposit point color)
    }
}

Config.ChangeVehicleState = function(plate, stored)
    if GetResourceState('qbx_core') == 'started' then
        MySQL.query.await('UPDATE player_vehicles SET state = ?  WHERE plate = ?', {stored and 1 or 0, plate})
        MySQL.query.await('UPDATE player_vehicles SET garage = ? WHERE plate = ?', {'nn_mechanic_storage', plate})
    elseif GetResourceState('qb-core') == 'started' then
        MySQL.query.await('UPDATE player_vehicles SET state = ? WHERE plate = ?', {stored and 1 or 0, plate})
        MySQL.query.await('UPDATE player_vehicles SET garage = ? WHERE plate = ?', {'nn_mechanic_storage', plate})
    elseif GetResourceState('es_extended') == 'started' then
        MySQL.query.await('UPDATE owned_vehicles SET state = ? WHERE plate = ?', {stored and 1 or 0, plate})
        MySQL.query.await('UPDATE owned_vehicles SET parking = ? WHERE plate = ?', {'nn_mechanic_storage', plate})
    end
end