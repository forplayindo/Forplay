return {
    taxRate = 5,                -- % potongan pajak saat paycheck dicairkan
    govAccount = 'government',  -- rekening Renewed-Banking penerima pajak
    mailFrom = 'Kantor Gaji',   -- pengirim email f_phone
    useDistance = 4.0,          -- jarak maksimal (meter) dari NPC, dicek ulang di server

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

    -- NPC kantor gaji (koordinat placeholder dekat Balai Kota Alta, sesuaikan)
    locations = {
        {
            label = 'Kantor Gaji',
            coords = vec4(-265.0, -960.9, 31.22, 205.0),
            model = `a_m_y_business_03`,
            scenario = 'WORLD_HUMAN_CLIPBOARD',
            blip = { sprite = 500, colour = 2, scale = 0.7 },
        },
    },
}
