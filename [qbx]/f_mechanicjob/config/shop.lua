-- Toko bengkel (konsep seperti apotek EMS & f_cafe): warga memesan di meja bengkel & membayar
-- (cash / transfer HP), lalu mekanik on duty menyerahkan barang (pembeli harus dekat mekanik).
-- Uang masuk rekening organisasi mechanic. Dibaca client & server.
return {
    job = 'mechanic',
    label = 'Toko Bengkel',
    cashItem = 'money',

    -- meja bengkel (SEMENTARA, atur dengan /vec3 di map nteam)
    counter = vec3(-328.20, -1337.40, 30.35),
    counterSize = vec3(1.6, 1.2, 1.6),

    items = {
        { item = 'repairkit', label = 'Alat Perbaikan', price = 100000, emoji = '🧰', desc = 'Darurat: mesin naik ke 50% supaya bisa jalan ke bengkel' },
        { item = 'tirekit', label = 'Alat Tambal Ban', price = 75000, emoji = '⭕', desc = 'Tambal ban yang bocor (keausan tetap perlu mekanik)' },
        { item = 'cleaningkit', label = 'Alat Pembersih', price = 25000, emoji = '🧽', desc = 'Membersihkan kendaraan' },
    },

    defaultLimit = 5,
    maxLimit = 20,
    settingsGrade = 0,
    orderCooldown = 10,
    serveDistance = 4.0,
    invoiceTimeout = 10,
    refundAfter = 30,
}
