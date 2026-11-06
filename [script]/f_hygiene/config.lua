Config = {}

Config.Debug = false

---------------------------------------------------------------------------
-- MANDI (BATHING)
---------------------------------------------------------------------------
Config.Mandi = {
    DirtyDuration = 180 * 60 * 1000,    -- 90 menit (ms), waktu dari bersih (0%) ke kotor total (100%)
    ReminderPercent = 80,              -- persen HUD saat notifikasi reminder mandi muncul
    FliesPercent = 85,                -- persen HUD saat lalat mulai mengelilingi player
    BathDuration = 10000,              -- 10 detik durasi animasi mandi

    -- animasi tepuk lalat player yang kotor (dari resource escrow mosquitoes_singleanimation - jangan dihapus)
    FliesAnim = { dict = 'cm@insect@clip', anim = 'insect_clip' },
    FliesInterval = 60000, -- animasi tepuk lalat dimainkan sekali tiap 60 detik (suara nyamuk ikut bunyi bareng)

    -- efek visual lalat beneran (particle bawaan GTA), nempel di ped selama kotor
    FliesEffect = {
        dict = 'core',
        name = 'ent_amb_fly_swarm',
        offset = vector3(0.0, 0.0, 0.4),
        scale = 1.0,
    },

    -- lalat ikut terlihat player lain di sekitar (lewat statebag dari server). Suara nyamuk
    -- (html/sounds/nyamuk.wav) bunyi tiap kali player kotor main animasi tepuk lalat
    FliesSync = {
        Distance = 15.0, -- radius lalat ditampilkan & suara nyamuk terdengar
        Volume = 0.6,    -- volume suara maksimal (0.0 - 1.0), makin jauh makin pelan
        Tick = 500,      -- ms, interval cek player kotor di sekitar
    },

    -- reaksi player LAIN yang dekat player kotor: kibas bau (animasi bawaan GTA "Stinker"),
    -- dimainkan pas player kotor itu tepuk lalat, maksimal sekali tiap Cooldown
    FliesReaction = {
        Anim = { dict = 'anim@mp_player_intupperstinker', anim = 'idle_a' },
        Distance = 5.0,   -- radius player sekitar ikut bereaksi
        Cooldown = 60000, -- ms, jeda minimal antar reaksi
        Duration = 3500,  -- ms, lama kunci animasi reaksi
    },

    -- animasi proses mandi (dipakai baik mandi di air maupun di shower)
    BathAnim = { dict = 'mp_safehouseshower@male@', clip = 'male_shower_idle_a' },
    BathAnimFemale = { dict = 'mp_safehouseshower@female@', clip = 'shower_idle_a' },

    -- efek partikel air pada shower saat proses mandi.
    ShowerWaterEffect = {
        dict = 'core',
        name = 'ent_sht_water',
        interval = 800, -- ms, seberapa sering efek air di-spawn ulang selama mandi
        offset = vector3(0.0, 0.0, 1.2),
    },
}

---------------------------------------------------------------------------
-- KENCING (PEE)
---------------------------------------------------------------------------
Config.Kencing = {
    ThirstMultiplier = 1.2,    -- setiap +1% thirst (minum) -> +1.2% HUD kencing
    ReminderPercent = 70,
    DesperatePercent = 100,
    PeeDuration = 6000,        -- 6 detik
    SafeDistance = 10.0,        -- jarak minimal dari player lain untuk kencing sembarang tempat

    PeeAnim = { dict = 'misscarsteal2peeing', clip = 'peeing_loop' },                          -- male
    -- wanita kencing SEMBARANGAN (bukan di toilet) - pose jongkok. CODE_HUMAN_MEDIC_KNEEL sempat
    -- dicoba tapi itu pose berlutut bukan jongkok, jadi balik ke dict/clip mentah ini
    PeeAnimFemale = { dict = 'amb@world_human_bum_wash@male@low@idle_a', clip = 'idle_a' },

    -- efek keluar air kencing saat kencing sembarang tempat (bukan di prop toilet). offset relatif
    -- ke titik acuan ped (bukan ke kaki). rot dipakai buat memiringkan arah pancuran (default
    -- particle-nya lurus ke bawah mengikuti sumbu lokal ped, rot.x memiringkannya melengkung ke
    -- depan) - sesuaikan lagi kedua nilai ini kalau posisi/arahnya masih meleset
    PeeEffect = {
        dict = 'core',
        name = 'ent_amb_peeing',
        offset = vector3(0.0, 0.2, -0.05),
        rot = vector3(-70.0, 0.0, 0.0),
    },

    -- efek keluar air kencing khusus saat kencing di prop toilet - animasinya sama seperti
    -- kencing sembarangan, tapi arah pancurannya diarahkan lebih ke bawah/dekat (masuk ke lubang
    -- toilet), bukan melengkung jauh ke depan seperti versi di atas - masih perkiraan, sesuaikan
    -- lagi kalau posisinya masih meleset dari lubang toilet
    PeeEffectToilet = {
        dict = 'core',
        name = 'ent_amb_peeing',
        offset = vector3(0.0, 0.25, -0.05),
        rot = vector3(-100.0, 0.0, 0.0),
    },

    -- heading kencing di prop toilet = heading titik ToiletLocations + angka ini (derajat).
    -- kalau player kencing kebalik arah hadapnya, ganti ke 0 (dan Config.Poop.SeatOffset.headingFlip
    -- ke 180) - tidak perlu ubah ulang koordinat di ToiletLocations, tinggal tukar 2 angka ini
    HeadingFlip = 0.0,
    offset = vector3(0.0, 0.0, 0.0),
}

---------------------------------------------------------------------------
-- POOP (BAB)
---------------------------------------------------------------------------
Config.Poop = {
    HungerMultiplier = 0.5,    -- setiap +1% hunger (makan) -> +0.5% HUD poop
    ReminderPercent = 70,
    DesperatePercent = 100,
    PoopDuration = 6000,       -- 6 detik
    SafeDistance = 15.0,        -- jarak minimal dari player lain untuk poop sembarang tempat

    -- poop SEMBARANG TEMPAT (menu radial): animasi, tisu & efek sama dengan emote "shit" rpemotes,
    -- bedanya kotoran langsung keluar selama progress bar (tidak perlu tekan G)
    AnywhereAnim = { dict = 'missfbi3ig_0', clip = 'shit_loop_trev' },
    AnywhereProp = {
        model = 'prop_toilet_roll_01',
        bone = 28422,
        pos = vector3(0.07, -0.02, -0.21),
        rot = vector3(0.0, 0.0, 0.0),
    },
    AnywhereEffect = {
        dict = 'scr_amb_chop',
        name = 'ent_anim_dog_poo',
        bone = 11816,
        offset = vector3(0.0, 0.0, -0.1),
        rot = vector3(0.0, 0.0, 0.0),
        scale = 1.3,
        delay = 1500,          -- ms setelah mulai jongkok baru kotoran keluar
    },

    -- poop di prop toilet (ox_target):
    -- animasi Trevor duduk toilet asli (dict/clip mentah lewat TaskPlayAnim) - posisinya sudah
    -- dikalibrasi & terkonfirmasi pas lewat SeatOffset di bawah.
    ToiletAnim = {
        dict = 'switch@trevor@on_toilet',
        clip = 'trev_on_toilet_loop',
    },

    -- posisi duduk poop DIHITUNG OTOMATIS dari titik yang sama di Config.ToiletLocations, dibalik
    -- sebesar headingFlip ini dari heading dasarnya (bukan dari heading kencing yang sudah kena
    -- Config.Kencing.HeadingFlip - dua-duanya independen, hitung dari titik dasar yang sama).
    -- Kalau kencing/poop kebalik pas testing, tukar angka ini dengan Config.Kencing.HeadingFlip
    -- (bukan ubah koordinat ToiletLocations). offset.x/y (kanan/depan) relatif ke heading SETELAH
    -- dibalik. offset.z = tambahan dari Z player saat ini (client/poop.lua) - animasi
    -- trev_on_toilet_loop punya elevasi bawaan sendiri jadi masih perlu di-tuning manual, makin
    -- negatif = makin turun. -0.9 di bawah cuma tebakan awal, pakai /hygiene_place_poop buat
    -- pas-in lagi kalau masih ngambang/ketinggian
    SeatOffset = {
        headingFlip = 180.0,
        offset = vector3(0.0, 0.6, -0.80),
    },

    -- celana dilepas sementara selama poop (cuma komponen legs, bukan full-undress kayak mandi),
    -- dikembalikan lagi setelah selesai/dibatalkan. drawable sama dengan yang dipakai Config.BathClothes
    PoopClothes = {
        male = { component_id = 4, drawable = 14, texture = 0 },
        female = { component_id = 4, drawable = 17, texture = 0 },
    },
}

---------------------------------------------------------------------------
-- LOKASI TOILET & SHOWER - daftarkan manual satu-satu di sini.
-- ToiletLocations: coords/heading = titik BERDIRI MENGHADAP toilet (posisi kencing, gampang
-- diambil - cukup berdiri nempel di depan toilet seperti biasa). Posisi duduk poop DIHITUNG
-- OTOMATIS dari titik yang sama (dibalik 180 derajat / membelakangi toilet, lihat
-- Config.Poop.SeatOffset) - tidak perlu ambil titik duduk terpisah.
-- ShowerLocations: coords/heading = titik final berdiri buat mandi.
-- zoneCoords (opsional, kedua list) = titik munculnya target/crosshair ox_target - boleh beda
-- dari coords kalau mau, tapi biasanya sama saja karena coords di sini sudah posisi berdiri wajar.
-- Kalau zoneCoords tidak diisi, otomatis pakai coords yang sama.
-- Cara ambil nilainya: berdiri/pas-kan posisi di titik yang diinginkan (atau pakai alat bantu
-- F9 di client/debug.lua), lalu print GetEntityCoords(PlayerPedId()) dan
-- GetEntityHeading(PlayerPedId()) via F8 console.
---------------------------------------------------------------------------
Config.ToiletLocations = {
    { coords = vector3(359.2, -603.57, 27.66), heading = 271.29 },
    { coords = vector3(352.1, -607.02, 27.79), heading = 47.79 },
    
}

Config.ShowerLocations = {
     { coords = vector3(369.33, -599.89, 27.87), heading = 332.54 },
}

Config.ToiletZoneRadius = 1.5 -- radius zone ox_target di tiap titik ToiletLocations
Config.ShowerZoneRadius = 1.5 -- radius zone ox_target di tiap titik ShowerLocations

---------------------------------------------------------------------------
-- BLIP DI PETA - dibuat otomatis buat tiap titik di ToiletLocations/ShowerLocations.
-- show = tampilkan/sembunyikan semua blip jenis ini. sprite pakai id blip bawaan GTA - default di
-- sini pakai 1 (bulat putih polos, pasti ada/aman), ganti sesuai selera (cari "gta blip sprite id
-- list" buat lihat id icon lain, misal sprite khusus toilet/shower kalau ada yang cocok)
---------------------------------------------------------------------------
Config.Blips = {
    Toilet = {
        show = false, -- blip dipindah ke f_blips
        name = 'Toilet',
        sprite = 1,
        color = 3,
        scale = 0.7,
    },
    Shower = {
        show = false,
        name = 'Shower',
        sprite = 1,
        color = 3,
        scale = 0.7,
    },
}

---------------------------------------------------------------------------
-- ANIMASI "KEBELET" saat kencing / poop 100% - animasi nempel di atas jalan normal (upper body),
-- bukan clipset gaya jalan. Kencing = pegang selangkangan, poop = emote rpemotes "puke"
-- (cross_arms@dark, animasinya saja tanpa efek muntah). Keduanya 100% = gantian.
---------------------------------------------------------------------------
Config.Desperate = {
    AnimDict = 'mp_player_int_uppergrab_crotch',     -- kencing
    AnimClip = 'mp_player_int_grab_crotch',
    PoopAnimDict = 'cross_arms@dark',                -- poop (anim stream dari rpemotes)
    PoopAnimClip = 'cross_arms_clip',
    Interval = 30000, -- dimainkan sekali tiap 30 detik
    Duration = 4000,  -- lama animasi tiap kali main
}

---------------------------------------------------------------------------
-- TIDUR / SLEEP
---------------------------------------------------------------------------
Config.Sleep = {
    -- opsi "Tidur" selalu ada di radial menu, bisa dipakai dimana saja (tidur di tempat, tanpa deteksi apapun)
    -- murni buat rileks/roleplay, tidak ada efek stat apapun

    -- daftar model prop kasur yang dicari otomatis di sekitar player (bukan koordinat tetap),
    -- jadi berlaku di interior/MLO manapun selama model kasurnya terdaftar di sini.
    -- silakan tambahkan model kasur lain sesuai interior/MLO yang dipakai di map kamu.
    BedModels = {
        'v_ilev_bed_stately_double',
        'xm_prop_x17dlc_bed_double_01a',
        'xm_prop_x17dlc_bed_double_02a',
        'v_ilev_mp_h_bed_double',
    },
    BedSearchRadius = 3.0,     -- radius pencarian prop kasur di sekitar player
    BedInteractDistance = 1.5, -- jarak munculnya textUI [E] Tidur saat dekat prop kasur

    -- animasi tidur (posisi berbaring), dimainkan berurutan: enter -> base (loop) -> exit
    Anim = {
        enterDict = 'amb@world_human_sunbathe@male@back@enter', enterClip = 'enter',
        baseDict  = 'amb@world_human_sunbathe@male@back@base',  baseClip  = 'base',
        exitDict  = 'amb@world_human_sunbathe@male@back@exit',  exitClip  = 'exit',
    },
}

---------------------------------------------------------------------------
-- PAKAIAN SAAT MANDI (komponen ped, dilepas sementara & dikembalikan setelah mandi)
---------------------------------------------------------------------------
Config.BathClothes = {
    male = {
        { component_id = 3,  drawable = 15, texture = 0 },  -- arms (kosong)
        { component_id = 4,  drawable = 14, texture = 0 },  -- legs (celana dalam pria)
        { component_id = 6,  drawable = 34, texture = 0 },  -- shoes (telanjang kaki)
        { component_id = 8,  drawable = 15, texture = 0 },  -- undershirt (kosong)
        { component_id = 11, drawable = 15, texture = 0 },  -- torso/jaket (kosong)
    },
    female = {
        { component_id = 3,  drawable = 15, texture = 0 },  -- arms (kosong)
        { component_id = 4,  drawable = 17, texture = 0 },  -- legs (celana dalam wanita)
        { component_id = 6,  drawable = 35, texture = 0 },  -- shoes (telanjang kaki)
        { component_id = 8,  drawable = 2,  texture = 0 },  -- undershirt (bra)
        { component_id = 11, drawable = 15, texture = 0 },  -- torso/jaket (kosong)
    },
}
