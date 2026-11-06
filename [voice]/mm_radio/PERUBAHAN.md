# MM Radio 0.4.0 — UI HUD Taktis

Semua fungsi sama dengan MM Radio asli. Nama pesan NUI dan callback Lua tidak diubah:
join, leave, toggleMute, volumeChange, hideUI, addFav, removeFav, showPlayerList,
updatePlayerListPosition, updateRadioPosition, allowMovement, enableClicks,
updateRadioSize, saveData, getMutedList, togglemutePlayer.

## Letak fungsi di desain HUD
- Layar > tab RADIO: frekuensi, channel, sinyal (Baik / Terganggu jammer), lokasi jalan, jumlah anggota,
  siapa yang sedang bicara (TX) + gelombang suara.
- Ketuk kotak frekuensi -> numpad di layar (atau ketik angka langsung di keyboard), GABUNG = join.
- Tab ANGGOTA: daftar anggota, tombol Bisu per pemain, tombol OVERLAY (tampil/sembunyi).
- Tab CHANNEL: Favorit & Terakhir dipakai, klik untuk join.
- Tab ATUR: nama di radio, ukuran radio, ukuran overlay, pindahkan radio, bisa jalan, suara radio.
- Tombol fisik: KEMBALI, FAV (tambah/hapus favorit), PUTUS (leave).
- Tombol menyala di atas = MUTE (merah saat mute). Knob atas: scroll = volume.
- Dua tombol di sisi kanan = VOL+ / VOL-.
- Radio muncul meluncur dari bawah saat dibuka dan turun ke bawah saat ditutup (animasi sekali jalan, ±0,3 detik).
- Posisi dasar radio digeser 48 px ke kiri dari tepi kanan (atur di BASE_RIGHT, build/app.js).
- Tutup radio: Esc, atau tombol yang sama dengan tombol buka (default =). Kalau pemain mengganti tombol radio ke huruf/simbol lain di Key Bindings, tombol tutup ikut berubah.
- Keyboard: 0-9 . Backspace Enter, panah kiri/kanan ganti tab.

## Ringan
- Tanpa framework/CDN. Font Oxanium dibundel lokal (3 file, ~27 KB).
- Tidak ada animasi berulang; efek cahaya statis.
- Optimasi Lua dari versi 0.3.0 tetap dipakai (daftar anggota hanya dikirim ke anggota channel, dll).

## Emote radio (2026-11-03)
- Saat bicara di radio (tombol radio pma-voice) pemain memakai emote rpemotes `wt4` (Walkie Talkie 4, radio di tangan);
  selesai bicara emote dibatalkan. Emote lain yang sedang dipakai (duduk, dll.) tidak diganggu.
- Animasi bawaan pma-voice dimatikan lewat export `setDisableRadioAnim(true)` (client/event.lua), voice.cfg tidak diubah.
- HUD "siapa yang bicara" ada di f_hud (modules/radio + RadioHud.tsx), memakai event yang sama; mm_radio tidak perlu diubah untuk itu.
