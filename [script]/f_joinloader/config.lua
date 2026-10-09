Config = {}

-- hitung mundur minimal setelah spawn (detik). Selama ini karakter dibekukan dan tidak bisa
-- ngapa-ngapain (keyboard ditahan oleh layar loader, jadi chat/HP/inventory juga tidak bisa dibuka)
Config.MinSeconds = 10

-- batas maksimal (detik). Kalau setelah MinSeconds map/HUD belum siap, loader menunggu lagi,
-- tapi tidak akan pernah lebih lama dari ini supaya pemain tidak tertahan selamanya
Config.MaxSeconds = 25

Config.Text = {
    title = 'Memuat Kota',
    description = 'Tunggu sebentar, HUD, handphone, dan map di sekitarmu sedang dimuat. Kamu belum bisa bergerak sampai proses selesai.',
    finishing = 'Hampir selesai...',
}
