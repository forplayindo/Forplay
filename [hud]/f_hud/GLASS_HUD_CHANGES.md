# HUD redesign (soft blur) – perubahan

Layout kanan atas: [online] [Job | Grade / Gang | Grade + jam game] -> [tanggal] [ID, Nama, Radio] -> Cash -> Bank -> Senjata

## Tampilan (sudah langsung jalan, TIDAK perlu build ulang)
- `ui/build/assets/index-*.js`  : komponen ClientInfo & Compass diganti versi glass.
- `ui/build/assets/index-*.css` : theme glass ditambahkan di akhir file.
- Source React juga sudah diupdate (`ui/dev/src/...`, `styles/glass.css`) jadi kalau nanti `npm run build`, hasilnya sama.

Posisi:
- Compass  : top-center, model tape (angka derajat + N/NE/E...), jarum merah, nama jalan di bawahnya.
- Info     : pojok kanan atas, mulai top 96px (area 80px di atas aman untuk logo).
  Geser jarak: ubah `j.top=y.y||96` (build js) / `LOGO_SAFE_TOP` (source).

## Config baru (config.lua)
- `client_info.gang.active` -> tampilkan info gang di kartu pekerjaan
  (QB: PlayerData.gang otomatis. ESX: edit `client.GetPlayerGang()` di modules/bridge/esx/client.lua)

## Optimasi resmon (Lua)
- NUI hanya dikirim kalau data berubah (sebelumnya full table tiap 100–200ms).
- Nilai float (rpm, stamina, oxygen, engine) dibulatkan -> lebih jarang berubah.
- Seatbelt: loop per-frame hanya saat sabuk terpasang (idle 250ms).
- Deteksi resource fuel di-cache (tidak GetResourceState tiap tick).
- Ammo natives hanya dipanggil saat pegang senjata.
- HideGTAHudComponents: scaleform dipanggil 1x/detik, bukan tiap frame.
- Nama karakter (QB/ESX) di-cache 5 detik.

## Blur asli ala iOS (ui/build/blur.js)
Membaca frame game lewat hook WebGL "game view" FiveM (teknik yang sama dengan
screenshot-basic), di-blur di 1/4 resolusi, lalu digambar HANYA di belakang panel.
Berjalan di GPU dalam NUI -> tidak menambah resmon Lua.

Pengaturan di bagian atas `ui/build/blur.js`:
- enabled    : true/false (false = panel transparan biasa)
- strength   : 1..4 jumlah pass blur
- spread     : 1.0..2.5 radius blur
- saturation / brightness : warna ala iOS
- fps        : 30/45/60 batas redraw (kalau ada flicker di monitor 144Hz+, coba 30)
Panel mana pun yang punya class `gl` atau atribut `data-blur` otomatis ikut di-blur.

## Optimasi FPS blur (untuk PC kentang)
- Blur hanya diproses di area panel (±5% layar), bukan seluruh layar.
  Beban GPU turun ke ~5% (high) / ~2% (medium) / ~0,5% (low) dibanding versi blur pertama.
- Kualitas otomatis dari FPS asli game (modules/blur/client.lua, cek 1x per 2 detik):
    FPS >= 75 -> high | >= 45 -> medium | >= 30 -> low | < 30 -> blur mati otomatis
  Naik tier butuh +8 FPS dan konfirmasi 4 detik (tidak bolak-balik).
- Tier low/off juga mematikan animasi CSS yang berulang terus.
- Player bisa pilih sendiri: /hudblur auto | high | medium | low | off  (tersimpan per player)
- config.lua -> Config.Blur untuk default server dan batas FPS.

## Optimasi performa (2026-11-03)
- Blur: mulai `off` sampai karakter spawn & HUD tampil; `off` saat HUD tersembunyi / pause menu / layar gelap;
  `pause` (frame terakhir dibiarkan) saat menu Settings terbuka. Mode `auto` paling tinggi `medium`
  (`Config.Blur.autoHigh = true` untuk mengizinkan high). Kanvas komposit 75% (medium) / 50% (low).
  Event `0r-hud:blurTier` tetap mengirim tier pilihan pemain (dipakai f_chat, ox_lib, f_banking).
- Lua hanya mengirim bagian `Hud.data` yang berubah (client_info / compass / navigation_widget / vehicle_info / bars / hygiene).
- React: `useData()` sekarang mencatat field yang dibaca komponen dan hanya render ulang kalau field itu berubah
  (DataProvider memberi store tetap, bukan value baru tiap render).
- Aset: miko.png (2,1 MB, cuma preview browser) dihapus, spoimp.jpeg 565 KB -> 4 KB, font .otf/.ttf -> .woff2.
- Edit di `ui/dev` lalu `npm run build` (blur.js sumbernya `ui/dev/public/blur.js`).
