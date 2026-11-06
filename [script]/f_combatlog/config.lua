Config = {}

-- Tampilkan log debug di console server (F8 untuk client). Matikan setelah semuanya jalan.
Config.Debug = true

-- Berapa lama marker combat log bertahan (detik)
Config.Duration = 120

-- Jarak maksimal kartu & ring terlihat (meter)
Config.DrawDistance = 30.0

-- Jarak maksimal untuk bisa menyalin Discord ID (meter)
Config.CopyDistance = 3.0

-- Tombol default untuk salin (bisa diganti pemain di Settings > Key Bindings > FiveM)
Config.CopyKey = 'E'

-- Nama yang ditampilkan: 'fivem' (nama FiveM/Steam) atau 'character' (nama karakter Qbox)
Config.NameSource = 'fivem'

-- Ukuran kartu (1.0 = ukuran awal). Perkecil/perbesar sesuai selera, mis. 0.6 – 0.8
Config.UIScale = 0.7

-- Tinggi bagian bawah kartu dari tanah (meter). ~1.4 = sejajar kepala pemain
Config.CardHeight = 1.4

-- Teks header kartu
Config.ServerTag = '4PLAY'

-- Warna ring di tanah (RGBA) — disamakan dengan aksen #F3B354
Config.MarkerColor = { r = 243, g = 179, b = 84, a = 200 }

-- Label alasan keluar
Config.Reasons = {
    quit    = 'Quit game',
    crash   = 'Crashed',
    timeout = 'Timed out',
    kick    = 'Kicked',
    ban     = 'Banned',
    other   = 'Disconnected',
}

-- Teks UI
Config.Locale = {
    copy        = 'Salin ID',
    copied      = 'Tersalin',
    noDiscord   = 'Tidak terhubung',
    notifyCopy  = 'Info combat log disalin (nama, reason, discord, license, coord)',
    notifyGone  = 'Combat log ini sudah kedaluwarsa',
}
