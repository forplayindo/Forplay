return {

    licenseExpiryDays = 7, -- default: berapa hari setelah terbit/perpanjang kartu dianggap kedaluwarsa

    idCardSettings = {
        closeKey = 'Backspace',
        autoClose = {
            status = false, -- or true
            time = 3000
        }
    },

    -- header = judul kartu, subtitle = baris kecil di bawah judul, tier = label pojok kanan atas
    -- expiryDays (opsional) menimpa licenseExpiryDays, theme (opsional) = kelas warna di web/css/style.css
    licenses = {
        ['id_card'] = {
            header = 'Kartu Tanda Penduduk',
            subtitle = 'Dinas Kependudukan & Pencatatan Sipil',
            tier = 'Dokumen Resmi',
            background = '#0f1b2c',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_franklin_dl'
        },
        ['ktp_sementara'] = {
            header = 'Kartu Tanda Penduduk Sementara',
            subtitle = 'Pengganti KTP · Berlaku 1 × 24 Jam',
            tier = 'Dokumen Sementara',
            theme = 'temp',
            expiryDays = 1,
            background = '#1d4f9c',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_franklin_dl'
        },
        ['driver_license'] = {
            header = 'Surat Izin Mengemudi',
            subtitle = 'Kepolisian Kota',
            tier = 'Dokumen Resmi',
            background = '#3d1420',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_franklin_dl',
        },
        ['weaponlicense'] = {
            header = 'Izin Kepemilikan Senjata',
            subtitle = 'Kepolisian Kota',
            tier = 'Dokumen Resmi',
            background = '#13261c',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_franklin_dl',
        },
        ['lawyerpass'] = {
            header = 'Kartu Advokat',
            subtitle = 'Perhimpunan Advokat Kota',
            tier = 'Dokumen Resmi',
            background = '#271a30',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_cs_r_business_card'
        },
        ['stnk'] = {
            header = 'Surat Tanda Nomor Kendaraan Bermotor',
            subtitle = 'Kepolisian Kota · Registrasi Kendaraan',
            tier = 'Dokumen Resmi',
            background = '#1d2a3a',
            backgroundImage = 'https://i.ibb.co/vxvGzg1/card.png',
            prop = 'prop_franklin_dl',
        },
    },

    -- Vehicle photos for STNK: vanilla GTA cars use the official FiveM image automatically;
    -- addon car photos live in the shared f_vehimages resource (made with /fotokendaraan).
}
