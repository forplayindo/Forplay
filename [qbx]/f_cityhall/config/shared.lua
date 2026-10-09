return {
    -- Service offices. `counter` = where citizens press E to apply, `desk` = where staff press E
    -- to open the request list. Services are only open while at least one `job` member is on duty.
    offices = {
        government = {
            label = 'Balai Kota',
            subtitle = 'Layanan KTP & Pajak Kendaraan',
            job = 'government',
            counter = vec3(-262.79, -964.18, 31.22),
            desk = vec3(-262.8, -962.2, 31.2),
            employment = true, -- job center at the counter (works even when services are closed)
            -- blip dipindah ke f_blips
        },
        police = {
            label = 'Kepolisian',
            subtitle = 'Layanan SIM, Lisensi Senjata & STNK',
            job = 'police',
            counter = vec3(441.1, -978.9, 30.7),
            desk = vec3(441.1, -981.0, 30.7),
            employment = false,
        },
    },

    -- Documents in display order. Prices are defaults; the boss of the office job can change
    -- them in-game within `rules.priceRange`.
    documents = {
        { key = 'id_card', label = 'KTP', office = 'government', kind = 'license', item = 'id_card', meta = 'id',
          price = { new = 25000, renew = 15000, lost = 40000 } },
        { key = 'tax', label = 'Pajak Kendaraan', office = 'government', kind = 'tax',
          percent = 1.0, min = 50000, max = 5000000 }, -- % of the vehicle's shop price, clamped to min/max
        { key = 'driver_license', label = 'SIM', office = 'police', kind = 'license', item = 'driver_license', meta = 'driver',
          price = { new = 150000, renew = 75000, lost = 100000 } },
        { key = 'weaponlicense', label = 'Lisensi Senjata', office = 'police', kind = 'license', item = 'weaponlicense', meta = 'weapon',
          price = { new = 2000000, renew = 750000, lost = 1000000 } },
        { key = 'stnk', label = 'STNK', office = 'police', kind = 'stnk',
          price = { new = 150000, renew = 75000, lost = 100000 } },
        -- penebusan tilang; harganya dari `tickets` di bawah, bukan dari menu Atur Harga
        { key = 'tilang', label = 'Penebusan Tilang', office = 'police', kind = 'redeem' },
    },

    -- Tilang polisi (menu Administrasi di f_police). SIM/STNK/kendaraan ditahan sampai ditebus di
    -- loket polisi (bayar + approve petugas); denda dikirim sebagai tagihan ke HP.
    tickets = {
        office = 'police',
        manageGrade = 2, -- grade minimum polisi untuk tombol Hapus / Kembalikan di tab Tilang

        -- harga tebus tetap per dokumen
        hold = {
            sim = { label = 'SIM', item = 'driver_license', price = 250000 },
            stnk = { label = 'STNK', item = 'stnk', price = 250000 },
        },

        -- alasan sita kendaraan dan harga tebusnya
        vehicleReasons = {
            { label = 'Parkir liar', price = 250000 },
            { label = 'Kendaraan ditinggal di jalan', price = 500000 },
            { label = 'Tanpa STNK / STNK mati', price = 750000 },
            { label = 'Barang bukti', price = 1500000 },
            { label = 'Dipakai untuk kejahatan', price = 3000000 },
        },

        -- jenis denda (bisa pilih lebih dari satu, totalnya ditagihkan ke HP)
        fines = {
            { label = 'Menerobos lampu merah', price = 150000 },
            { label = 'Melebihi batas kecepatan', price = 250000 },
            { label = 'Melawan arus', price = 200000 },
            { label = 'Parkir sembarangan', price = 100000 },
            { label = 'Mengemudi ugal-ugalan', price = 500000 },
            { label = 'Mengemudi tanpa SIM', price = 400000 },
            { label = 'Kendaraan tanpa STNK', price = 400000 },
        },
    },

    rules = {
        renewWindowDays = 5,     -- renewals only allowed when this many days (or fewer) are left
        plateDays = 20,          -- STNK plate validity
        taxDays = 10,            -- vehicle tax validity
        counterDistance = 3.0,   -- citizen must stand this close to the counter
        handoverDistance = 3.0,  -- applicant must stand this close to the officer on approval
        invoiceTimeout = 10,     -- minutes before an unpaid transfer invoice is cancelled
        maxCart = 6,
        priceRange = { min = 50, max = 200 },       -- % of the default price the boss may set
        taxPercentRange = { min = 0.5, max = 3.0 }, -- % of vehicle price the boss may set
        dutyToggleJobs = { government = true },     -- jobs that clock in/out at the desk (police has its own duty system)
    },

    mailFrom = 'Layanan Publik Kota',

    employment = {
        enabled = true, -- Set to false to disable the employment menu
        jobs = {
            unemployed = 'Unemployed',
            trucker = 'Trucker',
            taxi = 'Taxi',
            tow = 'Tow Truck',
            reporter = 'News Reporter',
            garbage = 'Garbage Collector',
            bus = 'Bus Driver',
        },
    },
}
