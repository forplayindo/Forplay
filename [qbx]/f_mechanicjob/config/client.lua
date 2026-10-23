return {
    debugZones = false,
    -- tablet di tangan mekanik selama panel Periksa Kendaraan terbuka (sama dengan emote "tablet" rpemotes)
    tablet = {
        prop = 'prop_cs_tablet',
        bone = 28422,
        placement = { 0.0, -0.03, 0.0, 20.0, -90.0, 0.0 },
        dict = 'amb@world_human_tourist_map@male@base',
        clip = 'base',
    },
    -- animasi saat memperbaiki (per jenis). flag 1 = seluruh badan (jongkok ikut), 49 = badan atas saja
    anims = {
        under = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },             -- kopling (tanpa lift), perbaikan umum
        engine = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 }, -- ruang mesin: kunci pas di kap yang terbuka
        interior = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },       -- pasang interior (pintu pengemudi)
        fluid = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 1 },          -- cairan: sama, dengan kaleng oli di tangan
        lift = { dict = 'amb@prop_human_movie_bulb@idle_a', clip = 'idle_a', flag = 49 }, -- bagian bawah (config/shared.lua liftParts) di lift: tangan ke atas
        -- ganti ban: animasi kustom (stream/wymianakola@animation.ycd)
        -- props: muncul/hilang mengikuti waktu animasi (ms dari awal animasi). at = muncul, life = lama tampil (nil = sampai selesai)
        -- fullCycle: progress tiap ban minimal sepanjang 1 putaran animasi, supaya ban sempat muncul
        tyre = {
            dict = 'wymianakola@animation', clip = 'wymiana_clip', flag = 1, fullCycle = true,
            props = {
                { model = 'prop_tool_drill', bone = 28422, at = 500,
                  pos = vec3(0.07, 0.03, -0.03), rot = vec3(80.0, 0.0, 190.0) },
                { model = 'imp_prop_impexp_tyre_01c', bone = 28422, at = 9000, life = 4000,
                  pos = vec3(0.1, 0.1, -0.457), rot = vec3(-30.058, 23.295, 98.948) },
            },
        },
        body = { scenario = 'WORLD_HUMAN_WELDING' },
    },
    -- pasang kustom (tab Kustom): modifikasi memakai anims engine / tyre / body di atas per tahap,
    -- cat memakai semprotan di bawah sambil mengelilingi kendaraan
    spray = {
        distance = 1.0, -- meter dari bodi saat menyemprot
        anim = { dict = 'anim@scripted@freemode@postertag@graffiti_spray@male@', clip = 'spray_can_var_01_male', flag = 1 },
        prop = { model = 'prop_cs_spray_can', bone = 28422, pos = vec3(0.0, 0.0, 0.07), rot = vec3(0.0, 0.0, 0.0) },
        -- kabut cat (efek semprot grafiti bawaan GTA), menempel di kaleng
        fx = { asset = 'scr_playerlamgraff', name = 'scr_lamgraff_paint_spray', offset = vec3(0.0, 0.0, 0.15), rot = vec3(0.0, 0.0, 0.0), scale = 1.0, color = { 0.85, 0.85, 0.85 } },
    },
    animOf = {
        engine = 'engine', radiator = 'engine', airfilter = 'engine', sparkplugs = 'engine',
        oil = 'fluid', coolant = 'fluid', brakefluid = 'fluid', transfluid = 'fluid',
        tyre = 'tyre', body = 'body', tank = 'body', brakes = 'under', suspension = 'under', axle = 'under', -- mobil: di lift (anim lift); motor: anim under
    },
    -- prop di tangan selama animasi (format prop lib.progressCircle). bone 57005 = tangan kanan, 60309 = tangan kiri
    props = {
        tool = { model = 'prop_tool_screwdvr03', bone = 57005, pos = vec3(0.10, 0.03, -0.03), rot = vec3(-80.0, 0.0, 0.0) },
        wrench = { model = 'prop_tool_wrench', bone = 57005, pos = vec3(0.12, 0.03, -0.02), rot = vec3(-100.0, 0.0, 0.0) },
        fluid = { model = 'v_ind_cs_oiltub', bone = 60309, pos = vec3(0.1, 0.0, 0.1), rot = vec3(4.0, 180.0, 90.0) },
    },
    propOf = { under = 'tool', engine = 'wrench', lift = 'wrench', fluid = 'fluid' },

    -- ganti ban: mekanik berjalan ke samping roda yang diganti
    tyreWalk = {
        distance = 0.9,  -- meter dari roda ke samping (arah luar kendaraan)
        timeout = 10000, -- ms maksimal berjalan (termasuk memutari kendaraan); gagal mendekat = dibatalkan
    },
    -- bagian ruang mesin (config/shared.lua hoodParts): berjalan ke depan kendaraan & membuka kap
    hoodWalk = {
        distance = 0.45, -- meter di depan bumper
        timeout = 10000,
    },
}
