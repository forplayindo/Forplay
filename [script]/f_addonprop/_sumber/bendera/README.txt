BENDERA GANG (Rebut Bendera f_crew)

Tambah bendera untuk gang baru:
  1. Simpan gambar kain di folder ini: <nama>.png  (3:2, mis. 1500x1000, tanpa tulisan)
     Nama file = nama model: hitam_panther.png -> gangflag_hitam_panther
  2. Jalankan dari folder f_addonprop:
       python _tools/build_gangflag.py
  3. Restart server (jangan restart f_addonprop saat server ramai / ada bendera tertancap).
  4. Di game: /peranggang > tab Bendera > baris gang -> isi model gangflag_<nama> > Simpan > Beri ke Boss.

Ganti gambar gang: timpa file png yang sama, jalankan lagi langkah 2-3 (model ikut terbaru).
Hapus bendera: hapus png-nya, jalankan langkah 2 (ydr ikut terhapus), kosongkan model di tab Bendera.
Paksa bangun ulang semua: python _tools/build_gangflag.py --semua

_template/  = flag_on_pole asli (XML CodeWalker + dds), jangan diubah.
_build/     = hasil sementara, boleh dihapus.
contoh.png  = bendera tes arah (tulisan ATAS harus tegak di game; kalau terbalik ubah FLIP_V di skrip).
Asal model: resources/tugu_flag_fivem (tugu_flag_pedestal + flag_on_pole), ytyp dibuat ulang di stream/gang_flags.
