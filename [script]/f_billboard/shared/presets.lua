-- Prop yang boleh dipakai untuk billboard tipe 'prop' (server hanya menerima model di daftar ini).
--
-- offset = posisi TENGAH layar relatif ke prop (x = kanan, y = depan, z = atas).
-- Layar menghadap ke arah -Y prop (sisi depan billboard).
-- width/height = ukuran layar dalam meter.
--
-- Kalau width/height/offset dikosongkan, ukuran diambil otomatis dari dimensi model
-- (menutupi seluruh sisi depan model). Semua nilai bisa di-fine-tune per billboard di editor.
--
-- sides = jumlah layar identik yang mengelilingi prop (media sama, tetap 1 browser DUI).
-- pivot = vec2(x, y) titik putar layar tambahan, default tengah prop vec2(0, 0).
BillboardPresets = {
    { model = 'prop_billboard_04',     label = 'Billboard Jalan Raya', width = 14.30, height = 6.70, offset = vec3(-4.0, -0.40, 15.0) },
    { model = 'prop_billboard_05',     label = 'Billboard Jalan',      width = 13.00, height = 5.80, offset = vec3(-5.60, -0.50, 17.2) },
    { model = 'prop_huge_display_01',  label = 'Layar Besar 1',        width = 10.70, height = 6.50, offset = vec3(0.0, -0.25, 0.67) },
    { model = 'prop_huge_display_02',  label = 'Layar Besar 2',        width = 8.80,  height = 4.80, offset = vec3(0.0, -0.20, 0.01) },
    { model = 'vw_casino_billboard_03', label = 'Billboard Casino' },
    { model = 'bh1_34_tower_billboard', label = 'Billboard Menara (Burton)' },
    -- 3 papan segitiga di atas tiang: layar 1 diatur, layar 2 & 3 otomatis diputar 120/240 derajat
    -- mengelilingi pivot (titik tengah tiang). Ukuran masih perkiraan, perlu kalibrasi di game.
    { model = 'prop_billboard_07',     label = 'Billboard Tiang 3 Sisi', width = 6.0, height = 8.0, offset = vec3(0.0, -1.73, 14.0), sides = 3 },
    { model = 'prop_tv_flat_01',       label = 'TV Flat' },
    { model = 'prop_tv_flat_michael',  label = 'TV Flat Besar' },
    { model = 'prop_tv_03',            label = 'TV Tabung' },
    { model = 'v_ilev_cin_screen',     label = 'Layar Bioskop' },
}
