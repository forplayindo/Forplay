-- Aksesoris hewan: dibeli di toko (tab Aksesoris) langsung dipakai, tersimpan per hewan (bukan item).
-- Semua prop bawaan GTA, ditempel ke tulang hewan. Satu slot = satu aksesoris.

-- Slot: label di toko, harga default, bone default untuk alat /petfit.
Config.AccessorySlots = {
    { id = 'collar',  label = 'Kalung Warna', price = 50000 },
    { id = 'head',    label = 'Kepala',       price = 150000, bone = 31086 },
    { id = 'glasses', label = 'Kacamata',     price = 100000, bone = 31086 },
    { id = 'neck',    label = 'Leher',        price = 200000, bone = 31086 },
    { id = 'back',    label = 'Punggung',     price = 250000, bone = 23553 },
}

-- Warna kalung (variasi bawaan model anjing, komponen 3). Hanya warna yang ada di modelnya yang muncul.
Config.CollarComponent = 3
Config.CollarColors = { 'Coklat', 'Hitam', 'Merah', 'Putih', 'Biru', 'Oranye', 'Pink', 'Hijau' }
Config.CollarKinds = { dog_big = true, dog_small = true }

-- Katalog. price kosong = harga default slotnya.
Config.Accessories = {
    -- Kepala
    { prop = 'prop_cap_01',                    slot = 'head', label = 'Topi Baseball' },
    { prop = 'sf_prop_art_cap_01a',            slot = 'head', label = 'Topi Seniman' },
    { prop = 'm23_2_prop_m32_peterscap_01a',   slot = 'head', label = 'Topi Pet' },
    { prop = 'prop_proxy_hat_01',              slot = 'head', label = 'Topi Fedora' },
    { prop = 'prop_ld_hat_01',                 slot = 'head', label = 'Topi Bundar' },
    { prop = 'reh_prop_reh_hat_cowboy_01a',    slot = 'head', label = 'Topi Koboi', price = 200000 },
    { prop = 'm23_2_prop_m32_hat_captain_01a', slot = 'head', label = 'Topi Kapten', price = 200000 },
    { prop = 'xm3_prop_xm3_hat_ron_01a',       slot = 'head', label = 'Topi Ron' },
    { prop = 'ch_prop_drills_hat01x',          slot = 'head', label = 'Topi Pesta' },
    { prop = 'ch_prop_drills_hat02x',          slot = 'head', label = 'Topi Pesta Kerucut' },
    { prop = 'prop_hard_hat_01',               slot = 'head', label = 'Helm Proyek' },
    { prop = 'sf_prop_sf_helmet_01a',          slot = 'head', label = 'Helm Motor', price = 250000 },
    { prop = 'xm3_prop_xm3_helmet_01a',        slot = 'head', label = 'Helm Pilot', price = 250000 },
    { prop = 'ba_prop_battle_headphones_dj',   slot = 'head', label = 'Headphone DJ', price = 300000 },
    { prop = 'prop_ear_defenders_01',          slot = 'head', label = 'Pelindung Telinga' },
    { prop = 'v_ret_gc_ear01',                 slot = 'head', label = 'Penutup Telinga' },
    { prop = 'prop_player_gasmask',            slot = 'head', label = 'Masker Gas', price = 250000 },
    { prop = 'reh_prop_reh_rebreather_01a',    slot = 'head', label = 'Alat Selam', price = 250000 },
    { prop = 'p_single_rose_s',                slot = 'head', label = 'Bunga Mawar', price = 75000 },

    -- Kacamata
    { prop = 'prop_cs_sol_glasses',            slot = 'glasses', label = 'Kacamata Hitam' },
    { prop = 'xm_prop_x17_b_glasses_01',       slot = 'glasses', label = 'Kacamata Gaya' },
    { prop = 'xm3_prop_xm3_glasses_ron_01a',   slot = 'glasses', label = 'Kacamata Ron' },
    { prop = 'prop_safety_glasses',            slot = 'glasses', label = 'Kacamata Safety' },

    -- Leher
    { prop = 'p_jewel_necklace01_s',           slot = 'neck', label = 'Kalung Permata', price = 500000 },
    { prop = 'sf_prop_sf_necklace_01a',        slot = 'neck', label = 'Kalung Emas', price = 400000 },
    { prop = 'tr_prop_tr_dd_necklace_01a',     slot = 'neck', label = 'Kalung Rantai' },
    { prop = 'h4_prop_h4_necklace_01a',        slot = 'neck', label = 'Kalung Liontin' },
    { prop = 'p_omega_neck_01_s',              slot = 'neck', label = 'Kalung Omega' },
    { prop = 'p_omega_neck_02_s',              slot = 'neck', label = 'Kalung Omega 2' },
    { prop = 'p_oscar_necklace_s',             slot = 'neck', label = 'Kalung Oscar' },
    { prop = 'p_stretch_necklace_s',           slot = 'neck', label = 'Kalung Stretch' },
    { prop = 'p_wade_necklace_s',              slot = 'neck', label = 'Kalung Wade' },
    { prop = 'p_jimmy_necklace_s',             slot = 'neck', label = 'Kalung Jimmy' },
    { prop = 'ch_p_ch_jimmy_necklace_2_s',     slot = 'neck', label = 'Kalung Jimmy 2' },
    { prop = 'p_lamarneck_01_s',               slot = 'neck', label = 'Kalung Lamar' },
    { prop = 'p_cs_tracy_neck2_s',             slot = 'neck', label = 'Kalung Tracy' },
    { prop = 'p_cs_beverly_lanyard_s',         slot = 'neck', label = 'Tali Kartu', price = 100000 },
    { prop = 'prop_stat_pack_01',              slot = 'neck', label = 'Tas Pinggang', price = 150000 },

    -- Punggung
    { prop = 'prop_michael_backpack',          slot = 'back', label = 'Ransel Hitam' },
    { prop = 'xm3_prop_xm3_backpack_01a',      slot = 'back', label = 'Ransel Gunung' },
    { prop = 'prop_parapack_01',               slot = 'back', label = 'Tas Parasut' },
    { prop = 'p_ld_heist_bag_01',              slot = 'back', label = 'Tas Duffel' },
    { prop = 'xm_prop_x17_bag_med_01a',        slot = 'back', label = 'Tas Medis' },
    { prop = 'prop_beach_bag_01b',             slot = 'back', label = 'Tas Pantai' },
    { prop = 'h4_prop_h4_pouch_01a',           slot = 'back', label = 'Kantong Kecil', price = 150000 },
    { prop = 'ch_p_m_bag_var01_arm_s',         slot = 'back', label = 'Tas Militer 1' },
    { prop = 'ch_p_m_bag_var03_arm_s',         slot = 'back', label = 'Tas Militer 2' },
    { prop = 'ch_p_m_bag_var04_arm_s',         slot = 'back', label = 'Tas Militer 3' },
    { prop = 'ch_p_m_bag_var06_arm_s',         slot = 'back', label = 'Tas Militer 4' },
    { prop = 'ch_p_m_bag_var07_arm_s',         slot = 'back', label = 'Tas Militer 5' },
    { prop = 'ch_p_m_bag_var08_arm_s',         slot = 'back', label = 'Tas Militer 6' },
    { prop = 'ch_p_m_bag_var09_arm_s',         slot = 'back', label = 'Tas Militer 7' },
    { prop = 'ch_p_m_bag_var10_arm_s',         slot = 'back', label = 'Tas Militer 8' },
}

-- Hewan yang memakai posisi aksesoris hewan lain (bentuk badan mirip). Setel ulang dengan /petfit kalau kurang pas.
Config.AccessoryFitAlias = {
    a_c_shepherd = 'a_c_husky',
}

-- Posisi aksesoris per model: [prop] = { offset, rotasi, bone }.
-- Hanya aksesoris yang punya posisi di sini (atau disimpan lewat /petfit) yang bisa dibeli untuk hewan itu.
-- Hasil /petfit disimpan di data/accessory_fits.json dan menimpa angka di bawah.
Config.AccessoryFits = {
    a_c_rottweiler = {
        prop_michael_backpack = { vec3(-0.06, -0.01, 0.2), vec3(-24.0, 98.0, -281.0), 23553 },
        prop_parapack_01 = { vec3(-0.14, -0.04, -0.02), vec3(-38.0, 3.0, -83.0), 23553 },
        p_ld_heist_bag_01 = { vec3(0.04, -0.04, -0.04), vec3(18.0, 364.0, 8.0), 23553 },
        xm_prop_x17_bag_med_01a = { vec3(-0.08, 0.0, 0.12), vec3(2.0, -11.0, 0.0), 23553 },
        prop_proxy_hat_01 = { vec3(0.06, 0.0, 0.15), vec3(-9.0, -26.0, -90.0), 31086 },
        reh_prop_reh_hat_cowboy_01a = { vec3(0.11, 0.0, 0.15), vec3(0.0, 3.0, -93.0), 31086 },
        prop_hard_hat_01 = { vec3(0.11, 0.0, -0.04), vec3(13.0, 1.0, -281.0), 31086 },
        sf_prop_sf_helmet_01a = { vec3(0.04, 0.0, 0.09), vec3(16.0, -4.0, -85.0), 31086 },
        sf_prop_art_cap_01a = { vec3(0.11, 0.0, 0.09), vec3(-4.0, 0.0, -90.0), 31086 },
        ba_prop_battle_headphones_dj = { vec3(0.15, 0.0, 0.07), vec3(5.0, 0.0, 90.0), 31086 },
        prop_safety_glasses = { vec3(0.11, 0.0, 0.0), vec3(-1.0, 0.0, 92.0), 31086 },
        xm_prop_x17_b_glasses_01 = { vec3(0.16, 0.0, 0.07), vec3(0.0, 2.0, 91.0), 31086 },
        xm3_prop_xm3_glasses_ron_01a = { vec3(0.09, 0.0, 0.15), vec3(-12.0, -13.0, -95.0), 31086 },
        prop_ld_hat_01 = { vec3(0.11, 0.0, 0.1), vec3(-11.0, 15.0, 90.0), 31086 },
        m23_2_prop_m32_hat_captain_01a = { vec3(0.11, -0.01, 0.09), vec3(-14.0, -14.0, -90.0), 31086 },
        v_ret_gc_ear01 = { vec3(-0.03, 0.0, 0.06), vec3(30.0, 0.0, -89.0), 31086 },
        xm3_prop_xm3_hat_ron_01a = { vec3(-0.25, -0.02, -0.11), vec3(79.0, 0.0, 91.0), 39317 },
        p_omega_neck_01_s = { vec3(-0.11, 0.0, -0.31), vec3(31.0, 0.0, 88.0), 31086 },
        p_oscar_necklace_s = { vec3(0.14, 0.0, -0.02), vec3(-32.0, 14.0, 92.0), 31086 },
        prop_player_gasmask = { vec3(0.07, 0.0, 0.04), vec3(17.0, 0.0, 92.0), 31086 },
        xm3_prop_xm3_helmet_01a = { vec3(0.12, 0.0, 0.16), vec3(5.0, 0.0, 89.0), 31086 },
        m23_2_prop_m32_peterscap_01a = { vec3(0.12, 0.0, 0.09), vec3(36.0, 0.0, 89.0), 31086 },
        prop_ear_defenders_01 = { vec3(-0.13, -0.01, -0.01), vec3(12.0, 60.0, 0.0), 31086 },
        p_single_rose_s = { vec3(0.11, 0.0, 0.15), vec3(7.0, 0.0, 90.0), 31086 },
        ch_prop_drills_hat02x = { vec3(0.11, 0.0, 0.15), vec3(7.0, 0.0, 90.0), 31086 },
        ch_prop_drills_hat01x = { vec3(-0.01, 0.0, 0.22), vec3(-90.0, -10.0, 0.0), 23553 },
        prop_stat_pack_01 = { vec3(-0.12, 0.0, -0.33), vec3(21.0, 0.0, 92.0), 31086 },
        p_stretch_necklace_s = { vec3(-0.11, 0.0, -0.38), vec3(26.0, 0.0, 91.0), 31086 },
        p_omega_neck_02_s = { vec3(0.05, 0.0, -0.18), vec3(78.0, 0.0, 94.0), 31086 },
        sf_prop_sf_necklace_01a = { vec3(0.12, 0.0, -0.1), vec3(28.0, 0.0, 90.0), 31086 },
        p_jewel_necklace01_s = { vec3(-0.04, 0.0, -0.05), vec3(0.0, 0.0, 91.0), 31086 },
        tr_prop_tr_dd_necklace_01a = { vec3(-0.14, 0.0, -0.26), vec3(15.0, 0.0, 89.0), 31086 },
        p_wade_necklace_s = { vec3(-0.07, 0.0, -0.45), vec3(25.0, 0.0, 89.0), 31086 },
        h4_prop_h4_necklace_01a = { vec3(-0.11, 0.0, -0.28), vec3(0.0, 0.0, 90.0), 31086 },
        ch_p_ch_jimmy_necklace_2_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var01_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var03_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var04_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var06_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var07_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var08_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var09_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        ch_p_m_bag_var10_arm_s = { vec3(-0.06, 0.0, -0.46), vec3(-2.0, 6.0, 0.0), 23553 },
        prop_cs_sol_glasses = { vec3(0.09, 0.0, 0.03), vec3(-25.0, 0.0, 92.0), 31086 },
        p_cs_beverly_lanyard_s = { vec3(-0.06, 0.0, -0.28), vec3(14.0, 0.0, 90.0), 31086 },
        h4_prop_h4_pouch_01a = { vec3(0.05, 0.0, -0.03), vec3(-73.0, 0.0, -94.0), 23553 },
        p_lamarneck_01_s = { vec3(-0.01, 0.0, -0.36), vec3(-20.0, 0.0, 93.0), 31086 },
        p_jimmy_necklace_s = { vec3(-0.11, 0.0, -0.44), vec3(-16.0, 0.0, 92.0), 31086 },
        xm3_prop_xm3_backpack_01a = { vec3(-0.08, 0.0, 0.12), vec3(4.0, 0.0, -90.0), 23553 },
        p_cs_tracy_neck2_s = { vec3(0.0, 0.0, -0.42), vec3(-5.0, 0.0, 88.0), 31086 },
        prop_cap_01 = { vec3(0.03, 0.0, 0.1), vec3(-12.0, 0.0, 90.0), 31086 },
        reh_prop_reh_rebreather_01a = { vec3(0.22, 0.0, -0.06), vec3(5.0, 0.0, 88.0), 31086 },
        prop_beach_bag_01b = { vec3(0.03, -0.01, 0.03), vec3(0.0, -6.0, 0.0), 23553 },
    },
    a_c_retriever = {
        prop_michael_backpack = { vec3(-0.06, 0.02, 0.05), vec3(-19.0, 108.0, -285.0), 23553 },
        prop_parapack_01 = { vec3(-0.14, -0.02, -0.08), vec3(-44.0, 3.0, -90.0), 23553 },
        p_ld_heist_bag_01 = { vec3(-0.04, -0.05, -0.15), vec3(6.0, 0.0, 0.0), 23553 },
        xm_prop_x17_bag_med_01a = { vec3(-0.08, 0.0, -0.04), vec3(-7.0, -14.0, 2.0), 23553 },
        prop_proxy_hat_01 = { vec3(0.06, 0.0, 0.15), vec3(-9.0, -26.0, -90.0), 31086 },
        reh_prop_reh_hat_cowboy_01a = { vec3(0.02, 0.0, 0.03), vec3(18.0, 0.0, -89.0), 31086 },
        prop_hard_hat_01 = { vec3(-0.02, 0.0, 0.09), vec3(-32.0, 3.0, -274.0), 31086 },
        sf_prop_sf_helmet_01a = { vec3(0.09, 0.0, -0.11), vec3(-19.0, 1.0, -269.0), 31086 },
        sf_prop_art_cap_01a = { vec3(-0.01, 0.0, 0.02), vec3(27.0, -4.0, -85.0), 31086 },
        ba_prop_battle_headphones_dj = { vec3(0.04, 0.0, 0.04), vec3(35.0, 0.0, -90.0), 31086 },
        prop_safety_glasses = { vec3(0.11, 0.0, 0.03), vec3(-21.0, 0.0, 90.0), 31086 },
        xm_prop_x17_b_glasses_01 = { vec3(0.05, 0.0, -0.03), vec3(-16.0, 0.0, 92.0), 31086 },
        xm3_prop_xm3_glasses_ron_01a = { vec3(0.1, 0.0, 0.01), vec3(-38.0, 2.0, 91.0), 31086 },
        prop_ld_hat_01 = { vec3(-0.01, 0.0, 0.09), vec3(10.0, -13.0, -95.0), 31086 },
        m23_2_prop_m32_hat_captain_01a = { vec3(0.04, 0.0, 0.04), vec3(-37.0, 15.0, 90.0), 31086 },
        v_ret_gc_ear01 = { vec3(0.02, -0.01, 0.02), vec3(-14.0, -14.0, -90.0), 31086 },
        xm3_prop_xm3_hat_ron_01a = { vec3(0.05, 0.08, -0.01), vec3(0.0, 0.0, -89.0), 31086 },
        p_omega_neck_01_s = { vec3(-0.25, 0.04, -0.05), vec3(79.0, 0.0, 81.0), 39317 },
        p_oscar_necklace_s = { vec3(-0.04, 0.0, -0.33), vec3(14.0, 0.0, 88.0), 31086 },
        prop_player_gasmask = { vec3(0.09, 0.0, -0.05), vec3(-67.0, 14.0, 92.0), 31086 },
        xm3_prop_xm3_helmet_01a = { vec3(0.02, 0.0, -0.03), vec3(-16.0, 0.0, 92.0), 31086 },
        m23_2_prop_m32_peterscap_01a = { vec3(0.02, 0.0, 0.1), vec3(-16.0, 0.0, 89.0), 31086 },
        prop_ear_defenders_01 = { vec3(0.01, 0.0, 0.04), vec3(-9.0, 0.0, 89.0), 31086 },
        p_single_rose_s = { vec3(-0.13, -0.15, -0.06), vec3(12.0, 60.0, 0.0), 31086 },
        ch_prop_drills_hat02x = { vec3(0.02, 0.0, 0.11), vec3(-13.0, 0.0, 90.0), 31086 },
        ch_prop_drills_hat01x = { vec3(0.02, 0.0, 0.11), vec3(-13.0, 0.0, 90.0), 31086 },
        prop_stat_pack_01 = { vec3(-0.08, 0.06, -0.4), vec3(5.0, 8.0, 0.0), 23553 },
        p_stretch_necklace_s = { vec3(0.01, 0.0, -0.39), vec3(-9.0, 0.0, 92.0), 31086 },
        p_omega_neck_02_s = { vec3(0.01, 0.0, -0.35), vec3(-1.0, 0.0, 91.0), 31086 },
        sf_prop_sf_necklace_01a = { vec3(0.06, 0.0, -0.18), vec3(58.0, 0.0, 94.0), 31086 },
        p_jewel_necklace01_s = { vec3(0.07, 0.0, -0.18), vec3(28.0, 0.0, 90.0), 31086 },
        tr_prop_tr_dd_necklace_01a = { vec3(-0.06, 0.01, -0.21), vec3(-20.0, 0.0, 91.0), 31086 },
        p_wade_necklace_s = { vec3(-0.06, 0.0, -0.4), vec3(-14.0, 0.0, 89.0), 31086 },
        h4_prop_h4_necklace_01a = { vec3(-0.04, 0.0, -0.41), vec3(19.0, 0.0, 89.0), 31086 },
        ch_p_ch_jimmy_necklace_2_s = { vec3(-0.11, 0.0, -0.28), vec3(0.0, 0.0, 90.0), 31086 },
        ch_p_m_bag_var01_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var03_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var04_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var06_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var07_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var08_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var09_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        ch_p_m_bag_var10_arm_s = { vec3(-0.11, 0.0, -0.37), vec3(-3.0, 5.0, 0.0), 23553 },
        prop_cs_sol_glasses = { vec3(0.16, 0.0, 0.06), vec3(-11.0, 0.0, 92.0), 31086 },
        p_cs_beverly_lanyard_s = { vec3(-0.06, 0.0, -0.22), vec3(14.0, 0.0, 90.0), 31086 },
        h4_prop_h4_pouch_01a = { vec3(0.05, 0.0, 0.09), vec3(-73.0, 0.0, -94.0), 23553 },
        p_lamarneck_01_s = { vec3(-0.09, 0.0, -0.25), vec3(13.0, 0.0, 93.0), 31086 },
        p_jimmy_necklace_s = { vec3(-0.13, 0.0, -0.22), vec3(13.0, 0.0, 92.0), 31086 },
        xm3_prop_xm3_backpack_01a = { vec3(-0.03, 0.0, 0.21), vec3(0.0, 0.0, -92.0), 23553 },
        p_cs_tracy_neck2_s = { vec3(-0.1, 0.0, -0.33), vec3(18.0, 0.0, 88.0), 31086 },
        prop_cap_01 = { vec3(0.09, 0.0, 0.15), vec3(-12.0, 0.0, 90.0), 31086 },
        reh_prop_reh_rebreather_01a = { vec3(0.22, 0.0, -0.06), vec3(-17.0, 0.0, 88.0), 31086 },
        prop_beach_bag_01b = { vec3(0.03, -0.01, 0.13), vec3(0.0, -6.0, 0.0), 23553 },
    },
    a_c_husky = {
        prop_proxy_hat_01 = { vec3(0.01, 0.09, 0.01), vec3(-83.0, 91.0, 4.0), 31086 },
        reh_prop_reh_hat_cowboy_01a = { vec3(0.01, 0.02, 0.01), vec3(-88.0, -89.0, 0.0), 31086 },
        prop_hard_hat_01 = { vec3(0.02, 0.09, -0.01), vec3(-89.0, -276.0, 0.0), 31086 },
        sf_prop_sf_helmet_01a = { vec3(0.03, -0.06, 0.0), vec3(-90.0, 93.0, 0.0), 31086 },
        sf_prop_art_cap_01a = { vec3(0.05, 0.02, -0.01), vec3(-108.0, 92.0, 0.0), 31086 },
        ba_prop_battle_headphones_dj = { vec3(0.0, 0.05, 0.01), vec3(-105.0, 89.0, 0.0), 31086 },
        prop_safety_glasses = { vec3(0.05, 0.02, 0.0), vec3(-85.0, 88.0, 6.0), 31086 },
        xm_prop_x17_b_glasses_01 = { vec3(-0.02, -0.04, -0.01), vec3(-95.0, 88.0, 0.0), 31086 },
        xm3_prop_xm3_glasses_ron_01a = { vec3(0.05, 0.0, 0.0), vec3(-105.0, 93.0, 0.0), 31086 },
        prop_ld_hat_01 = { vec3(0.02, 0.1, -0.01), vec3(-94.0, 79.0, 2.0), 31086 },
        m23_2_prop_m32_hat_captain_01a = { vec3(0.0, 0.03, 0.0), vec3(-98.0, 89.0, 0.0), 31086 },
        v_ret_gc_ear01 = { vec3(0.0, 0.06, 0.0), vec3(-99.0, -90.0, 0.0), 31086 },
        xm3_prop_xm3_hat_ron_01a = { vec3(-0.03, 0.02, 0.0), vec3(-69.0, -88.0, 3.0), 31086 },
        p_jewel_necklace_02 = { vec3(-0.01, -0.1, 0.0), vec3(-98.0, 112.0, 0.0), 31086 },
        p_oscar_necklace_s = { vec3(-0.04, -0.33, 0.0), vec3(-97.0, 91.0, 0.0), 31086 },
        prop_player_gasmask = { vec3(0.0, -0.07, 0.0), vec3(-94.0, 88.0, 0.0), 31086 },
        xm3_prop_xm3_helmet_01a = { vec3(-0.02, -0.04, 0.0), vec3(-68.0, 90.0, 0.0), 31086 },
        m23_2_prop_m32_peterscap_01a = { vec3(0.04, 0.13, 0.0), vec3(-90.0, 92.0, 0.0), 31086 },
        prop_ear_defenders_01 = { vec3(0.0, 0.07, 0.0), vec3(-69.0, -83.0, 0.0), 31086 },
        p_single_rose_s = { vec3(-0.14, -0.15, -0.02), vec3(-123.0, -65.0, 0.0), 31086 },
        ch_prop_drills_hat02x = { vec3(0.0, 0.12, 0.0), vec3(-97.0, 89.0, 0.0), 31086 },
        ch_prop_drills_hat01x = { vec3(0.0, 0.11, 0.0), vec3(-97.0, 89.0, 0.0), 31086 },
        sf_prop_sf_necklace_01a = { vec3(0.04, -0.07, 0.0), vec3(-24.0, 90.0, 0.0), 31086 },
        p_jewel_necklace01_s = { vec3(0.05, -0.1, 0.0), vec3(-68.0, 88.0, 0.0), 31086 },
        p_wade_necklace_s = { vec3(-0.14, -0.3, 0.0), vec3(-86.0, 90.0, 0.0), 31086 },
        h4_prop_h4_necklace_01a = { vec3(0.0, -0.4, 0.0), vec3(-79.0, 89.0, 0.0), 31086 },
        ch_p_ch_jimmy_necklace_2_s = { vec3(-0.14, -0.22, 0.0), vec3(-84.0, 91.0, 0.0), 31086 },
        prop_cs_sol_glasses = { vec3(0.07, 0.03, 0.0), vec3(-91.0, 91.0, 0.0), 31086 },
        p_cs_beverly_lanyard_s = { vec3(-0.08, -0.31, 0.0), vec3(-95.0, 91.0, 0.0), 31086 },
        reh_prop_reh_rebreather_01a = { vec3(0.21, -0.05, 0.0), vec3(-150.0, 90.0, 0.0), 31086 },
    },
}

---------------------------------------------------------------------------
-- Helper bersama (client & server)
---------------------------------------------------------------------------
Acc = { byProp = {}, slots = {} }
for _, s in ipairs(Config.AccessorySlots) do Acc.slots[s.id] = s end
for _, a in ipairs(Config.Accessories) do Acc.byProp[a.prop] = a end

function Acc.price(a)
    return a.price or Acc.slots[a.slot].price
end

-- posisi aksesoris untuk model: hasil /petfit (GlobalState) > config > alias model lain
---@return { [1]: vector3, [2]: vector3, [3]: number }?
function Acc.fit(model, prop)
    model = model:lower()
    local custom = GlobalState.fpetFits
    for _, m in ipairs({ model, Config.AccessoryFitAlias[model] }) do
        local c = custom and custom[m] and custom[m][prop]
        if c then return { vec3(c[1], c[2], c[3]), vec3(c[4], c[5], c[6]), c[7] } end
        local f = Config.AccessoryFits[m] and Config.AccessoryFits[m][prop]
        if f then return f end
    end
end

function Acc.collarAllowed(cfg)
    return cfg and Config.CollarKinds[cfg.kind] == true
end
