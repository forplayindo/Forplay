return {
    -- 2 ayunan = 1 item (tiap ayunan bunyi batu + serpihan saat kapak kena), total ±5 dtk
    swings = 2,
    swingTime = 4800,           -- jarak minimal antar ayunan (ms); harus >= hitCooldown server (4,5 dtk)
    impactAt = 0.45,            -- titik kena di dalam animasi (0-1)
    hitVolume = 0.55,
    swingAnim = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot' },
    pickaxe = { model = `prop_tool_pickaxe`, bone = 57005, pos = vec3(0.09, -0.53, -0.22), rot = vec3(252.0, 180.0, 0.0) },
    helmet = { model = `prop_hard_hat_01`, bone = 31086, pos = vec3(0.135, 0.0, 0.0), rot = vec3(180.0, 90.0, -5.0) },
    carryAnim = { dict = 'anim@heists@box_carry@', clip = 'idle' },
    wadahAttach = { bone = 28422, pos = vec3(0.0, -0.18, -0.18) },

    textDistance = 10.0,        -- teks 3D tungku terlihat sedekat ini

    -- properti bawaan MLO yang menghalangi jalan di sisi barat lobby: disembunyikan lewat script
    -- (JANGAN edit ytyp MLO: hasil rebuild CodeWalker membuat lobby tidak termuat)
    hideProps = {
        { model = 0x26C318F1, coords = vec3(-1156.06, 3294.94, -111.30) },
        { model = 0x26C318F1, coords = vec3(-1156.19, 3294.13, -111.42) },
        { model = 0xE258D3CE, coords = vec3(-1154.06, 3293.17, -111.77) },
    },

    -- penerangan (cahaya script; hanya lampu dalam radius distance dari pemain yang digambar)
    light = {
        colour = { 255, 214, 170 },  -- putih hangat
        range = 9.0,
        intensity = 4.0,
        distance = 25.0,
        -- titik lampu lobby (gua memakai posisi lampu tiap tabung terowongan)
        lobby = {
            vec3(-1146.0, 3274.0, -109.0), vec3(-1154.0, 3274.0, -109.0),
            vec3(-1146.0, 3281.0, -109.0), vec3(-1154.0, 3281.0, -109.0),
            vec3(-1146.0, 3288.0, -109.0), vec3(-1154.0, 3288.0, -109.0),
            vec3(-1146.0, 3295.0, -109.0), vec3(-1154.0, 3295.0, -109.0),
        },
    },

    -- baju tambang (format qb-clothing seperti f_garbagejob; nilai dari wardrobe aquiver, silakan ganti)
    outfit = {
        male = {
            ['t-shirt'] = { item = 15, texture = 0 },
            ['torso2'] = { item = 248, texture = 0 },
            ['arms'] = { item = 64, texture = 0 },
            ['pants'] = { item = 90, texture = 3 },
            ['shoes'] = { item = 27, texture = 0 },
        },
        female = {
            ['t-shirt'] = { item = 14, texture = 0 },
            ['torso2'] = { item = 79, texture = 0 },
            ['arms'] = { item = 47, texture = 0 },
            ['pants'] = { item = 92, texture = 23 },
            ['shoes'] = { item = 26, texture = 0 },
        },
    },
}
