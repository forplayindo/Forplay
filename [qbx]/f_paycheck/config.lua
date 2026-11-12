return {
    taxRate = 5,                -- % potongan pajak saat paycheck dicairkan
    govAccount = 'government',  -- rekening f_banking penerima pajak
    mailFrom = 'Penggajian',    -- pengirim email f_phone

    -- Ambil Gaji lewat ox_target di ATM & NPC bank (lokasi dari config f_banking)
    atmDistance = 3.0,          -- jarak maksimal (meter) player ke ATM, dicek ulang di server
    bankDistance = 6.0,         -- jarak maksimal (meter) player ke NPC bank, dicek ulang di server

    -- notifikasi ox_lib tiap paycheck masuk (tiap qbx_core paycheckTimeout)
    notify = {
        title = 'Paycheck Tersimpan',
        icon = 'money-check-dollar',
        iconColor = '#4ade80',
        position = 'top-right',
        duration = 7000,
        style = {
            backgroundColor = '#111827',
            color = '#e8edf6',
            borderLeft = '3px solid #4ade80',
            ['.description'] = { color = '#93a0b8' },
        },
    },
}
