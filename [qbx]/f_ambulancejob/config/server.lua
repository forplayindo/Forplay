return {
    doctorCallCooldown = 1, -- Time in minutes for cooldown between doctors calls
    wipeInvOnRespawn = false, -- item tidak dihapus saat dibawa ke rumah sakit (hanya bayar administrasi)
    depositSociety = function(society, amount)
        exports['Renewed-Banking']:addAccountMoney(society, amount)
    end,

    -- Email tagihan (f_phone Mail) yang dikirim saat pasien bangun dari kasur.
    -- Baris 1, 3, 4, 7 diisi otomatis: nama, rumah sakit, biaya, rumah sakit.
    -- Tagihan layanan EMS (tab Tagihan di panel Cek Pasien + daftar Belum Bayar di MDT).
    emsBill = {
        job = 'ambulance',                      -- invoice f_phone atas nama job ini -> uang masuk rekening organisasinya
        label = '4PLAY Hospital',            -- nama pengirim di invoice & email
        -- email saat EMS menarik tagihan langsung dari bank pasien (tombol Tagih di MDT).
        -- %s berurutan: nama pasien, nomor tagihan, total, rincian.
        collectMail = {
            subject = 'Penarikan Tagihan Layanan EMS',
            body = 'Yth. %s,\n\nTagihan layanan EMS #%s sebesar Rp %s belum dibayar, sehingga telah ditarik langsung dari rekening bank Anda.\n\nRincian:\n%s\n\nTerima kasih.\n4PLAY Hospital',
        },
    },

    billMail = {
        subject = 'Hospital Administration Bill',
        body = {
            'Dear %s,',
            '',
            'Kamu telah menerima perawatan medis di %s.',
            'Biaya administrasi Rp %s telah dipotong dari rekening bankmu.',
            '',
            'Get well soon.',
            '%s',
        },
    },
}
