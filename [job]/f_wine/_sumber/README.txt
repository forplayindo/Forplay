f_wine - sumber data titik petik + gambar item

Titik petik (config/kebun.lua) diambil dari kartu anggur vanilla GTA (model ch1_09b/ch1_05/ch1_04b_vinegrapes_*),
jadi tandan 3D kita menggantung tepat di tempat anggur vanilla di antara daun. Ulangi hanya kalau ingin titik baru:

1) Export posisi baris + model ke XML (butuh GTA V Steam + CodeWalker di C:\Users\GTA\Documents\_\CodeWalker30_dev46):
     powershell -File vinerows.ps1 <folder_kerja>          -> rows.txt, bbox.txt, xml\*.ydr.xml (213 model)
2) Pilih titik (1 per baris pohon, 3-5 kartu berdekatan, jarak antar tandan >= 0,3 m) + perkiraan pos injak:
     python -I cards.py <folder_kerja> kebun.json          (lambat, +-5 menit)
3) Tulis config:
     python -I kebun_lua.py kebun.json ../config/kebun.lua

Hasil saat ini: 136 titik / 481 tandan (merah 73, putih 16, rose 47). Pos injak & lokasi winery di config/shared.lua
adalah PERKIRAAN - kalibrasi di game dengan /winepos (admin) lalu tempel.

Prop (tandan, keranjang, tong injak) ada di [script]/f_addonprop/_sumber/anggur/gen_props.py.
Gambar item: lihat gambar/PROMPT.txt.
