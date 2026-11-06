# 4play-combatlog (Qbox)

Marker combat log di lokasi pemain keluar, lengkap dengan Discord ID yang bisa disalin.

## Instalasi
1. Taruh folder `4play-combatlog` di `resources/`.
2. Tambahkan ke `server.cfg` **setelah** ox_lib dan qbx_core:
   ```
   ensure 4play-combatlog
   ```
3. Atur `config.lua` sesuai kebutuhan.

## Cara pakai
- Saat pemain keluar, kartu + ring muncul di lokasinya selama `Config.Duration` detik.
- Dekati marker (≤ `Config.CopyDistance` m) lalu tekan **E** untuk menyalin Discord ID.
  Tombol bisa diganti pemain di *Settings › Key Bindings › FiveM*.
- Tes: `/combatlogtest` (admin) membuat combat log palsu di posisimu.

## Performa
- Server: tanpa thread/loop; kerja hanya saat `playerDropped`.
- Client: tanpa thread saat tidak ada log; cek jarak tiap 500 ms saat log jauh;
  per-frame hanya saat log dalam `Config.DrawDistance`, dan NUI hanya di-update
  kalau posisi di layar berubah. Timer bar memakai satu transisi CSS.
- NUI tanpa font/asset eksternal dan tanpa `backdrop-filter`.
