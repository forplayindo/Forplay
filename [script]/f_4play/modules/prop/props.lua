-- Daftar prop yang muncul di menu /prop.
-- Tambah kategori / model sesuka hati. Model yang tidak ada di game otomatis disembunyikan dari menu.
-- Format: { label = 'Nama di menu', model = 'nama_model' }

PropCategories = {
    {
        label = 'Prop Custom Server',
        icon = 'star',
        props = {
            -- { label = 'Contoh prop custom', model = 'nama_prop_custom' },
        },
    },
    {
        label = 'Kursi & Meja',
        icon = 'chair',
        props = {
            { label = 'Bangku taman', model = 'prop_bench_01a' },
            { label = 'Bangku kayu', model = 'prop_bench_05' },
            { label = 'Kursi plastik', model = 'prop_chair_01a' },
            { label = 'Kursi kayu', model = 'prop_chair_04a' },
            { label = 'Kursi kantor', model = 'prop_off_chair_01' },
            { label = 'Kursi santai', model = 'prop_patio_lounger1' },
            { label = 'Meja', model = 'prop_table_03' },
            { label = 'Meja 2', model = 'prop_table_04' },
            { label = 'Meja piknik', model = 'prop_picnictable_01' },
            { label = 'Payung pantai', model = 'prop_parasol_04b' },
        },
    },
    {
        label = 'Pembatas & Jalan',
        icon = 'road-barrier',
        props = {
            { label = 'Cone', model = 'prop_roadcone02a' },
            { label = 'Cone besar', model = 'prop_roadcone01a' },
            { label = 'Barrier kerja', model = 'prop_barrier_work05' },
            { label = 'Barrier kerja 2', model = 'prop_barrier_work06a' },
            { label = 'Barrier polisi', model = 'prop_mp_barrier_02b' },
            { label = 'Barrier beton', model = 'prop_barier_conc_02a' },
            { label = 'Barrier beton 2', model = 'prop_barier_conc_05a' },
            { label = 'Lampu kerja', model = 'prop_worklight_03b' },
        },
    },
    {
        label = 'Tanaman',
        icon = 'leaf',
        props = {
            { label = 'Tanaman pot', model = 'prop_plant_int_01a' },
            { label = 'Tanaman pot 2', model = 'prop_plant_int_03a' },
            { label = 'Pot bunga', model = 'prop_pot_plant_01a' },
            { label = 'Semak', model = 'prop_bush_med_03' },
            { label = 'Pohon cedar', model = 'prop_tree_cedar_02' },
        },
    },
    {
        label = 'Kotak, Tong & Sampah',
        icon = 'box',
        props = {
            { label = 'Tumpukan kardus', model = 'prop_boxpile_07d' },
            { label = 'Tumpukan kardus 2', model = 'prop_boxpile_06a' },
            { label = 'Peti kayu', model = 'prop_box_wood02a' },
            { label = 'Palet', model = 'prop_pallet_02a' },
            { label = 'Tong', model = 'prop_barrel_02a' },
            { label = 'Container', model = 'prop_container_01a' },
            { label = 'Tempat sampah', model = 'prop_bin_01a' },
            { label = 'Dumpster', model = 'prop_dumpster_01a' },
            { label = 'Kantong sampah', model = 'prop_rub_binbag_01' },
        },
    },
    {
        label = 'Lain-lain',
        icon = 'cubes',
        props = {
            { label = 'ATM', model = 'prop_atm_01' },
            { label = 'Mesin soda', model = 'prop_vend_soda_01' },
            { label = 'Mesin snack', model = 'prop_vend_snak_01' },
            { label = 'BBQ', model = 'prop_bbq_1' },
            { label = 'Api unggun', model = 'prop_beach_fire' },
            { label = 'Gazebo', model = 'prop_gazebo_02' },
            { label = 'Tenda', model = 'prop_skid_tent_01' },
            { label = 'Generator', model = 'prop_generator_03b' },
            { label = 'Lemari perkakas', model = 'prop_toolchest_05' },
            { label = 'Meja kerja', model = 'prop_tool_bench02' },
        },
    },
}
