return {
    ---For a given vehicle, the config used is based on precendence of:
    ---1. model
    ---2. category from qbx_core shared/vehicles.lua
    ---3. class
    ---4. type
    ---5. default
    ---Each field falls back to its parent value if not specified.
    ---Example: model's shared value is nil, so the type's shared value is used.
    vehicles = {
        ---@type VehicleConfig
        default = {
            noLock = false,
            spawnLockedIfParked = 0.75,
            spawnLockedIfDriven = 0.75,
            carjackingImmune = false,
            lockpickImmune = false,
            shared = false,
            removeNormalLockpickChance = 0.4,
            removeAdvancedLockpickChance = 0.2,
            findKeysChance = 0.5,
        },
        ---@type table<VehicleClass, VehicleConfig>
        classes = {
            -- [VehicleClass.EMERGENCY] = {

            -- }
        },
        ---@type table<string, VehicleConfig>
        categories = { -- known categories: super, service, utility, helicopters, motorcycles, suvs, planes, sports, emergency, military, sportsclassics, compacts, sedans
            -- super = {
            --     noLock = false,
            --     spawnLockedIfParked = 1.0,
            --     carjackingImmune = false,
            --     lockpickImmune = false,
            --     shared = false,
            --     removeNormalLockpickChance = 1.0,
            --     removeAdvancedLockpickChance = 1.0,
            --     findKeysChance = 0.5,
            -- }
        },
        ---@type table<VehicleType, VehicleConfig>
        types = { -- known types: automobile, bike, boat, heli, plane, submarine, trailer, train
            bike = {
                noLock = true
            },
            -- automobile = {
            --     noLock = false,
            --     spawnLockedIfParked = 1.0,
            --     carjackingImmune = false,
            --     lockpickImmune = false,
            --     shared = false,
            --     removeNormalLockpickChance = 1.0,
            --     removeAdvancedLockpickChance = 1.0,
            --     findKeysChance = 0.5,
            -- }
        },
        ---@type table<Hash, VehicleConfig>
        models = {
            -- [`stockade`] = {
            --     spawnLockedIfParked = 0.5
            -- }
        }
    },

    -- Job Settings (checked on both client and server)
    ---@class SharedKeysConfig
    ---@field enableAutolock? boolean auto-lock door on driver exit
    ---@field requireOnDuty? boolean requires player to be on duty to access the vehicle
    ---@field classes? table<VehicleClass, boolean> vehicle classes to enable shared keys on
    ---@field vehicles? table<number, boolean> vehicle hashes to enable shared keys on

    ---@alias JobName string
    ---@type table<JobName, SharedKeysConfig>
    sharedKeys = { -- Share keys amongst employees. Employees can lock/unlock any job-listed vehicle
        police = { -- Job name
            enableAutolock = true,
            requireOnDuty = true,
            classes = {},
            vehicles = {
                [`police`] = true,  -- Vehicle model
                [`police2`] = true, -- Vehicle model
            }
        },
        ambulance = {
            enableAutolock = true,
            requireOnDuty = true,
            classes = {},
            vehicles = {
                [`ambulance`] = true,
            },
        },
        mechanic = {
            requireOnDuty = false,
            vehicles = {
                [`towtruck`] = true,
            }
        }
    },

    -- Physical keys (ox_inventory item) for player owned vehicles
    keyItem = 'car_key',

    -- Mechanic key duplication. Rekeys the vehicle: every older key of that vehicle stops working.
    duplicate = {
        jobs = { 'mechanic' },
        requireOnDuty = true,
        duration = 15000,           -- progress duration (ms)
        requiredItem = 'key_blank', -- consumed from the mechanic on success
        ownerDistance = 10.0,       -- owner must be online and this close to the vehicle
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    },

    -- Theft minigames (lockpick / hotwire / jammer)
    theft = {
        cooldown = 5000,            -- ms between two theft attempts per player
        minLockpickTime = 3000,     -- a lockpick cannot finish faster than this (ms), blocks forged results
        minHotwireTime = 3000,
        minJammerTime = 3000,

        difficulties = {
            easy = { pins = 3, timeLimit = 45000 },
            medium = { pins = 4, timeLimit = 35000 },
            hard = { pins = 5, timeLimit = 25000 },
            expert = { pins = 6, timeLimit = 20000 },
        },
        hotwireTimes = { easy = 35000, medium = 28000, hard = 22000, expert = 18000 },
        jammer = { difficulty = 'hard', timeLimit = 25000, item = 'signal_jammer' },

        ---@type table<VehicleClass, 'easy'|'medium'|'hard'|'expert'|false> false = cannot be stolen
        classDifficulty = {
            [0] = 'easy',     -- Compacts
            [1] = 'easy',     -- Sedans
            [2] = 'medium',   -- SUVs
            [3] = 'medium',   -- Coupes
            [4] = 'medium',   -- Muscle
            [5] = 'hard',     -- Sports Classics
            [6] = 'hard',     -- Sports
            [7] = 'expert',   -- Super
            [8] = 'easy',     -- Motorcycles
            [9] = 'medium',   -- Off-road
            [10] = 'hard',    -- Industrial
            [11] = 'medium',  -- Utility
            [12] = 'easy',    -- Vans
            [13] = 'easy',    -- Cycles
            [14] = 'easy',    -- Boats
            [15] = 'hard',    -- Helicopters
            [16] = 'expert',  -- Planes
            [17] = 'hard',    -- Service
            [18] = 'expert',  -- Emergency
            [19] = false,     -- Military
            [20] = 'hard',    -- Commercial
            [21] = false,     -- Trains
            [22] = 'easy',    -- Open wheel
        },

        alarm = {
            enabled = true,
            onStartMinTier = 2, -- security tier at which the alarm already fires when the attempt starts
            onFail = true,      -- alarm when a minigame fails
            notifyOwner = true, -- notify the online owner of a player vehicle
            duration = 30000,
        },
    },

    -- Vehicle security tiers (player owned vehicles only). Higher tier = harder minigame, tier 3 needs a signal jammer.
    security = {
        jobs = { 'mechanic' },
        requireOnDuty = true,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
        ---@type table<integer, {label: string, item: string, duration: integer}> keyed by the tier being upgraded TO
        upgrades = {
            [2] = { label = 'Keamanan Tinggi', item = 'security_chip_2', duration = 35000 },
            [3] = { label = 'Keamanan Ahli', item = 'security_chip_3', duration = 40000 },
        },
        labels = { [1] = 'Basic Security', [2] = 'Keamanan Tinggi', [3] = 'Keamanan Ahli' },
    },
}
