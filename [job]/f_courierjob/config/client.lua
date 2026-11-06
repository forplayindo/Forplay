return {
    boxModel = `prop_cs_cardbox_01`,        -- paket kecil
    bigBoxModel = `prop_cardbordbox_04a`,   -- paket besar (2 orang)

    -- posisi kardus di tangan (paket kecil: sama seperti f_recyclejob)
    boxAttach = { bone = 57005, pos = vec3(0.05, 0.1, -0.3), rot = vec3(300.0, 250.0, 20.0) },
    bigAttach = { bone = 0, pos = vec3(0.0, 0.65, 0.05), rot = vec3(0.0, 0.0, 0.0) },
    backAttach = vec3(0.0, 1.35, 0.0),  -- rekan belakang menempel di depan pengendali, saling berhadapan

    propDistance = 60.0,        -- paket di tanah dibuat (lokal) saat sedekat ini
    npcDistance = 45.0,         -- penerima muncul saat sedekat ini ke titik
    npcSnapDistance = 30.0,     -- penerima dicarikan trotoar terdekat dari titik, maks sejauh ini
    rearDistance = 2.5,         -- jarak ke pintu belakang van untuk opsi muat / ambil
    rearDoors = { 2, 3 },       -- pintu belakang boxville
    signDuration = 3000,

    -- penerima menulis di notes (anim biasa + prop lokal, jalan di semua model ped pria/wanita)
    signAnim = {
        dict = 'missheistdockssetup1clipboard@base',
        clip = 'base',
        props = {
            { model = `prop_notepad_01`, bone = 18905, pos = vec3(0.1, 0.02, 0.05), rot = vec3(10.0, 0.0, 0.0) },
            { model = `prop_pencil_01`, bone = 58866, pos = vec3(0.11, -0.02, 0.001), rot = vec3(-120.0, 0.0, 0.0) },
        },
    },

    receiverModels = {
        `a_m_y_business_01`, `a_f_y_business_01`, `a_m_m_bevhills_01`, `a_f_m_bevhills_01`,
        `a_m_y_hipster_01`, `a_f_y_hipster_02`, `a_m_m_farmer_01`, `a_f_m_tourist_01`,
    },

    -- baju kerja (format qb-clothing, dipasang lewat illenium-appearance)
    -- SEMENTARA sama dengan job sampah: ganti ke seragam GoPostal setelah dipilih di menu baju
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
