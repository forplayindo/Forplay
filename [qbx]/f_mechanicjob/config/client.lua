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
    -- animasi saat memperbaiki (per jenis)
    anims = {
        under = { dict = 'mini@repair', clip = 'fixing_a_ped' },          -- mesin, radiator, oli, coolant, busi, filter
        tyre = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' },
        body = { scenario = 'WORLD_HUMAN_WELDING' },
    },
    -- animasi pasang kustom (tab Kustom)
    customAnim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    animOf = {
        tyre = 'tyre', body = 'body', tank = 'body', brakes = 'tyre', suspension = 'tyre', axle = 'tyre',
    },
}
