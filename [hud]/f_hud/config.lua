--[[ All settings of the script are found and edited in this file. ]]

Config = {}

--[[
    You can edit the default settings for Hud like this.
    I tried to choose the variable names as meaningful as possible.
--]]
Config.DefaultHudSettings   = {
    ---@type BarStyle
    bar_style = 'hexagon-w',
    --[[ Places all bar types in a new order. ]]
    is_res_style_active = true,
    vehicle_hud_style = 11, -- 11 = Sora Series (default)
    -- If `editableByPlayers` value is `false` players cannot change the `onlyInVehicle` value.
    mini_map = { onlyInVehicle = true, style = 'rectangle', editableByPlayers = true },
    -- If `editableByPlayers` value is `false` players cannot change the `onlyInVehicle` value.
    compass = { active = true, onlyInVehicle = true, editableByPlayers = true },
    cinematic = { active = true },
    -- kmH 'true' or 'false' | false is MPH
    vehicle_info = { kmH = true },
    --[[
        - It is located in the upper right corner.
        - It lists data such as date, server name, money, etc.
    --]]
    client_info = {
        active = true,
        server_info = {
            active = true,
            -- Server name
            name = 'MY SERVER',
            -- Server Logo | path: ui/build/images/server_images/<file>
            image = 'index.png',
            -- Show online players on client_info
            showOnlinePlayers = true,
        },
        bank = { active = true },
        cash = { active = true },
        job = { active = true },
        player_source = { active = true },
        radio = { active = true },
        time = { active = true },
        weapon = { active = true },
        real_time = { active = true },
        extra_currency = { active = true },
        -- Character name on the player card (glass HUD)
        player_name = { active = true },
        -- Gang info on the job card (QB: PlayerData.gang)
        gang = { active = true },
    },
    music_info = {
        -- Listening to music feature true/false
        active = true,
    },
    --[[
        - Located above the map.
        - Shows current location, music information or time.
    --]]
    navigation_widget = { active = true },
    -- Bar colors set by default.
    bar_colors = {
        armor = '#1D4ED8',
        health = '#CF4E5B',
        hunger = '#FFC400',
        oxygen = '#00FFA3',
        stamina = '#C4FF48',
        stress = '#6b21a8',
        thirst = '#00c2ff',
        vehicle_engine = '#C4FF48',
        voice = '#FFFFFF',
        vehicle_nitro = '#cf654e',
        mandi = '#4FC3F7',
        kencing = '#FFE14D',
        poop = '#B07A4F',
    },
}

--If money is an item on your server, you need to edit this.
Config.MoneySettings        = {
    isMoneyItem = false,
    itemName = 'cash',
    -- You can put one more currency if you want it to appear on the `client_info`.
    -- to hide it or set active to `false`
    -- f_dirtymoney: akun qbx 'dirty' = bagian kotor dari cash; cash di HUD = bagian bersih
    extra_currency = {
        type = 'account', --[[@type 'item' | 'account']]
        name = 'dirty', --[[@type string | nil]] -- account or item name
    }
}

Config.ToggleSettingsMenu   = {
    active = true,
    key = 'I',             -- nil or Key
    command = 'hudsettings', -- Shortcut key to open hud settings menu
}

-- Configures for seat-belt system.
Config.ToggleSeatBelt       = {
    active = true,
    key = 'B',
    --What should be the minimum vehicle speed for eject:
    -- This value is set according to kmH being `true`. If you are using kmH `false`, you can write it as `MPH`.
    ejectSpeed = 160,
    -- If true, you will receive a warning if you are not wearing your seat belt.
    warning = true,
}

-- Shortcut key to turn the vehicle engine on and off
Config.ToggleVehicleEngine  = {
    active = true,
    key = 'G',
}

-- Shortcut key to toggle cinametic mode
Config.ToggleCinematicMode  = {
    active = true,
    key = nil,             -- nil or Key
    command = 'cinematic', -- Toggle cinematic mode
}

-- Allows the player to default all positions.
Config.ResetHudPositions    = {
    active = true,
    command = 'resethudpos',
}

--[[ Real background blur behind the HUD panels (ui/build/blur.js)
     GPU only (no Lua resmon). Quality tiers:
       high   = 60 fps redraw, 1/4 res      medium = 30 fps, 1/6 res
       low    = 20 fps, 1/8 res, no looping CSS animations
       off    = no blur, plain translucent panels (0 GPU cost)
     'auto' picks the tier from the player's real FPS and turns blur off
     by itself on very weak PCs. Players can override with /hudblur. ]]
Config.Blur = {
    enabled = true,     -- false = blur disabled for everyone
    default = 'auto',   -- 'auto' | 'high' | 'medium' | 'low' | 'off'
    command = 'hudblur', -- nil to disable the command
    autoFps = { high = 75, medium = 45, low = 30 }, -- below `low` -> blur off
}

--[[ Stress (dipindah dari f_stress). Nilai disimpan server di statebag/metadata 'stress'. ]]
Config.Stress = {
    enabled = true,
    excludedJobs = { police = true },  -- job ini tidak bisa dapat stress
    -- Ngebut
    minimumSpeed = 100,                -- km/j, di atas ini dapat stress tiap 10 detik
    speedGain = { min = 1, max = 3 },
    ignoredVehicleClasses = { [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
    -- Menembak
    shootChance = 0.1,                 -- 10% per tembakan
    shootGain = { min = 1, max = 3 },
    whitelistedWeapons = { `weapon_petrolcan`, `weapon_hazardcan`, `weapon_fireextinguisher` },
    -- Efek layar
    minimumStress = 50,                -- mulai blur dari level ini, 100 = jatuh/ragdoll
    blur = {                           -- lama blur (ms) per rentang level
        { min = 50, max = 60, intensity = 1500 },
        { min = 60, max = 70, intensity = 2000 },
        { min = 70, max = 80, intensity = 2500 },
        { min = 80, max = 90, intensity = 2700 },
        { min = 90, max = 100, intensity = 3000 },
    },
    interval = {                       -- jeda antar efek (ms) per rentang level
        { min = 50, max = 60, from = 50000, to = 60000 },
        { min = 60, max = 70, from = 40000, to = 50000 },
        { min = 70, max = 80, from = 30000, to = 40000 },
        { min = 80, max = 90, from = 20000, to = 30000 },
        { min = 90, max = 100, from = 15000, to = 20000 },
    },
    -- Server: berkurang sendiri
    passiveRelief = { every = 3 * 60000, amount = 5 },
    -- Server: batas per event dari client (anti-cheat)
    maxGainPerEvent = 10,
    gainCooldown = 1000,               -- ms antar GainStress per pemain
    reliefCooldown = 5000,             -- ms antar RelieveStress per pemain
}

--If you want to hide GTA components, you need to enable this.
Config.HideGTAHudComponents = true -- sembunyikan HUD bawaan GTA (nama/kelas kendaraan "Karin Sultan, Sport", nama area, jalan, uang)
--Works with `HideGTAHudComponents` Components. | Can be used to fix the map if it is broken.
Config.HavePostalMap        = false
--[[ Minimap gaya GTA VI (stream/minimap.gfx, minimap.ytd, gta6_graphics.ytd).
     Status darah/lapar/haus/suara/armor tampil di bawah minimap, jadi peta dinaikkan (y negatif = naik). ]]
Config.Minimap              = {
    --[[ Nilai bawaan minimap "rectangle" asli f_hud (1080p). mask & blur: x relatif terhadap x minimap,
         mask y relatif terhadap minimap, blur y absolut. Area = bagian peta yang terlihat (satuan tinggi layar). ]]
    x = -0.007, y = -0.075, width = 0.1685, height = 0.19,
    mask = { x = 0.007, y = -0.006, w = 0.128, h = 0.2 }, -- y -0.006: garis rute tidak keluar di bawah peta
    blur = { x = -0.0015, y = -0.045, w = 0.27, h = 0.3 },
    arrow = { x = 0.0, y = 0.0 },
    lift = -0.003,                  -- negatif = minimap turun (mendekati bar status), positif = naik
    area = { left = 0.0148, bottom = 0.0972, w = 0.2944, h = 0.1787 }, -- diukur in-game 1920x1080: peta x 16-334, y 782-975
    zoom = 1000,
    routeColor = { 247, 115, 164 }, -- garis GPS pink
    showNorth = false,              -- ikon N bawaan disembunyikan (seperti gta6_hud)
    radius = 30,                    -- px, sudut lapisan malam (samakan dengan sudut peta)
    frame = false,                  -- garis tepi NUI di sekeliling peta (gta6 tidak memakai frame)
    statusGap = 8,                  -- px jarak bar status di bawah peta
    -- lapisan gelap malam di atas peta (0 = mati, seperti gta6_hud; mis. 0.42 untuk menyalakan)
    night = { opacity = 0.0, duskStart = 19, duskEnd = 21, dawnStart = 5, dawnEnd = 7 },
    -- koreksi area overlay (fraksi layar). Cek dengan /hudmapdebug
    overlayOffset = { x = 0.0, y = 0.0, w = 0.0, h = 0.0 },
    coverRight = 0,
}

--Defines the refresh thread timecycle for data that need to be updated periodically. Milliseconds
Config.RefreshTimes         = {
    hud = 200,
    vehicle = 100,
    requestPlayerCount = 30 * 1000 -- 30 seconds
}

-- Colors available by default.
-- I advise you to set 20.
Config.BarColors            = {
    '#CF4E5B', '#CF4E75', '#CF4EAB', '#A888DE', '#6b21a8', '#7FCF4E', '#C4FF48', '#FFC400', '#FF9900', '#CF654E',
    '#1d4ed8', '#00C2FF', '#4EB0CF', '#4ECFA1', '#00FFA3', '#A68A7B', '#FFFFFF', '#7A7A7A', '#4B4B4B', '#00000057'
}

--A list of electric vehicles available in the game.
Config.ElectricVehicles     = {
    'Imorgon',
    'Neon',
    'Raiden',
    'Cyclone',
    'Voltic',
    'Voltic2',
    'Tezeract',
    'Dilettante',
    'Dilettante2',
    'Airtug',
    'Caddy',
    'Caddy2',
    'Caddy3',
    'Surge',
    'Khamelion',
    'RCBandito'
}
