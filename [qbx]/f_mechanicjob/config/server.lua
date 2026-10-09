return {
    -- Tagihan layanan mekanik (sama seperti EMS): harga = batas atas, mekanik boleh diskon.
    billing = {
        job = 'mechanic',
        label = 'Bengkel Mekanik',
        services = {
            oil = { label = 'Isi oli mesin', price = 60000 },
            coolant = { label = 'Isi coolant', price = 40000 },
            brakefluid = { label = 'Isi minyak rem', price = 40000 },
            transfluid = { label = 'Isi oli transmisi', price = 60000 },
            sparkplugs = { label = 'Ganti busi', price = 60000 },
            airfilter = { label = 'Ganti filter udara', price = 40000 },
            tyre = { label = 'Ganti ban', price = 75000 },
            brakes = { label = 'Perbaiki rem', price = 150000 },
            body = { label = 'Perbaiki body', price = 150000 },
            tank = { label = 'Perbaiki tangki', price = 150000 },
            radiator = { label = 'Perbaiki radiator', price = 200000 },
            clutch = { label = 'Perbaiki kopling', price = 250000 },
            axle = { label = 'Perbaiki as roda', price = 250000 },
            suspension = { label = 'Perbaiki suspensi', price = 250000 },
            engine = { label = 'Perbaiki mesin', price = 300000 },
            callout = { label = 'Panggilan ke lokasi', price = 75000 },
            tow = { label = 'Derek', price = 150000 },
            keydup = { label = 'Duplikat kunci', price = 150000 }, -- dicatat otomatis oleh f_vehiclekeys
        },
        -- layanan yang bisa ditambahkan manual oleh mekanik di tab Tagihan
        manual = { 'callout', 'tow' },
        customerDistance = 6.0, -- pelanggan yang ditagih harus sedekat ini dengan mekanik
    },

    -- kondisi awal kendaraan non-pemain (NPC / kendaraan kerja): acak supaya terlihat bekas pakai
    npcCondition = { min = 70, max = 100, odoMin = 5000, odoMax = 60000 },

    saveEvery = 60, -- detik; kondisi kendaraan pemain disimpan ke database
}
