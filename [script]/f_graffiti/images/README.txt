Desain graffiti per gang.

1. Cari nama internal gang di tabel crew_gangs (kolom name), contoh: crew_5
2. Buat folder images/crew_5/ lalu taruh PNG di situ (latar transparan, disarankan 512x512, maks 1024)
   Nama file: huruf/angka/_-. saja, contoh: tag_utama.png
3. Tambah di config.lua:
       Config.Designs = {
           crew_5 = {
               { file = 'tag_utama.png', label = 'Tag Utama' },
           },
       }
4. ensure f_graffiti

Gang hanya melihat desain di foldernya sendiri. Graffiti di tembok terlihat semua orang.
