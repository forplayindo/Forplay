return {
    licenseRank = 2, -- Grade minimum untuk beri/cabut lisensi (2 = Sergeant), juga kartu Cabut Lisensi di Administrasi
    licenseItems = { -- kartu yang diambil dari inventory saat lisensi dicabut
        driver = { item = 'driver_license', label = 'SIM' },
        weapon = { item = 'weaponlicense', label = 'Lisensi Senjata' },
    },
    towPay = 150000, -- Police tow paid
    lawyerPay = 250000, -- Police lawyer paid
    validLicenses = { -- valid licenses
        driver = true,
        weapon = true,
    },
    towJobs = { -- tow jobs
        tow = true,
    },
    lawyerJobs = { -- lawyer jobs
        lawyer = true,
    }
}
