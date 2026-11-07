Prop f_wine, dibuat prosedural tanpa Blender (bentuk tandan = mockup 'Mockup Tandan Anggur' yang disetujui):
  f_anggur_ungu / f_anggur_hijau / f_anggur_merah  tandan 22 cm + tangkai 7 cm, pivot = ujung atas tangkai (titik gantung), ~3,6k segitiga
  f_wine_keranjang                                  keranjang anyaman panen 59x37x30 cm (dengan pegangan), pivot tengah bawah
  f_wine_tong_merah / _putih / _rose                tong injak kayu terbuka 1,12 m, isi jus + anggur terinjak, pivot tengah bawah

Langkah (dari folder f_addonprop):
  1) python -I _sumber/anggur/gen_props.py _sumber/anggur/build          -> <model>.glb + tekstur .dds (A8R8G8B8)
  2) python -I _tools/build_prop.py _sumber/anggur/build/<model>.glb _sumber/anggur/build <model> box <lod>
     lod: tandan 50, keranjang 60, tong 120. Collision kotak supaya ox_target bisa mengenai prop.
  3) powershell -File _tools/cw.ps1 import _sumber/anggur/build/<model>.ydr.xml  stream/anggur/<model>.ydr
     powershell -File _tools/cw.ps1 import _sumber/anggur/build/<model>.ytyp.xml stream/anggur/<model>.ytyp
  4) data_file sudah ada di fxmanifest.lua.

Warna buah per tandan = tekstur palet 8x8 (16 warna, tiap buah memakai satu warna), jadi tidak seragam.
