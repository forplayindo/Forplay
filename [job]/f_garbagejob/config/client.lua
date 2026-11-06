return {
    -- versi cutscene dari prop_dumpster_01a: bentuk sama, tapi bukan model dumpster ox_inventory
    -- (jadi tidak muncul opsi "Cari tempat sampah" di kontainer kerja)
    containerModel = `prop_cs_dumpster_01a`,
    containerFallback = `prop_dumpster_01a`, -- dipakai kalau model di atas tidak ada
    bagModels = {
        `prop_cs_rub_binbag_01`,
        `qua_binbag_big_black`,     -- dari f_addonprop (stream/sampah)
        `qua_binbag_big_blue`,
        `qua_binbag_mid_black`,
    },
    handBagModel = `prop_cs_rub_binbag_01`,
    propDistance = 90.0,            -- prop titik dibuat saat sedekat ini

    -- panah GTA di atas kantong / kontainer yang belum diambil
    markerDistance = 40.0,
    markers = {
        bagHeight = 0.9, bagScale = 0.35, bagColour = { 243, 179, 84 },               -- emas
        containerHeight = 2.4, containerScale = 0.6, containerColour = { 52, 199, 89 }, -- hijau
    },

    -- scoop truk master2 (bone 'scoop', digerakkan lewat pintu kap): [E] kait, [SHIFT] angkat & tuang
    scoop = {
        attachDistance = 12.0,
        liftRatio = 0.8,            -- kap/scoop dianggap terangkat setelah terbuka sejauh ini
        emptyDuration = 5000,
        offset = vec3(0.0, 1.75, 3.25),
        rotation = vec3(82.0, 0.0, 0.0),
    },

    -- baju kerja (format qb-clothing, dipasang lewat illenium-appearance)
    outfit = {
        male = {
            ['t-shirt'] = { item = 59, texture = 0 },
            ['torso2'] = { item = 56, texture = 0 },
            ['arms'] = { item = 203, texture = 0 },
            ['pants'] = { item = 36, texture = 0 },
            ['shoes'] = { item = 12, texture = 0 },
            ['hat'] = { item = -1, texture = 0 },
        },
        female = {
            ['t-shirt'] = { item = 36, texture = 0 },
            ['torso2'] = { item = 27, texture = 0 },
            ['arms'] = { item = 72, texture = 0 },
            ['pants'] = { item = 35, texture = 0 },
            ['shoes'] = { item = 26, texture = 0 },
            ['hat'] = { item = -1, texture = 0 },
        },
    },
}
