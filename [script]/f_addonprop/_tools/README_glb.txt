glb -> prop makanan GTA (ydr + ytyp), contoh mie goreng/rebus telor (sumber di ..\_sumber\makanan):

1. Kurangi polygon + tekstur DDS + preview (Blender 5.2, headless):
   blender -b --factory-startup --python prep_blender.py -- <in.glb> <build\x.glb> <build\folder> <nama_model> 12000 3000 1200 0.001
   (batas segitiga: mie / wadah / lainnya; 0.001 = voxel remesh untuk mie. Tanpa remesh, untaian mie jadi serpihan.)
   Cek <build\folder>\<nama_model>_sesudah.png.
   Wadah (piring/mangkok) memakai planar dissolve, bukan collapse: collapse merusak lekukan piring -> makanan tembus.
2. XML CodeWalker:   python build_food.py <build\x.glb> <build\folder> <nama_model> [profil]
   (profil 'sendok' = orientasi + pivot sama dengan devkit_spork, jadi offset tangan spork bisa dipakai)
3. Biner ke stream:  cw.ps1 import <build\folder>\<nama_model>.ydr.xml  ..\stream\makanan\<nama_model>.ydr
                     cw.ps1 import <build\folder>\<nama_model>.ytyp.xml ..\stream\makanan\<nama_model>.ytyp
   (cw.ps1 butuh CodeWalker di C:\Users\GTA\Documents\_\CodeWalker30_dev46)
4. Tambah data_file 'DLC_ITYP_REQUEST' untuk ytyp baru di fxmanifest.lua.
5. Ikon inventory:   blender -b --factory-startup --python render_icon.py -- <in.glb> <ox_inventory\web\images\item.png> 256
   Prop tanpa glb (ydr saja): cw.ps1 export <file.ydr> <folder>, lalu
                     blender -b --factory-startup --python render_icon_ydr.py -- <folder\x.ydr.xml> <item.png> 256
Ydr tanpa archetype (mis. steak.ydr dari luar) tidak akan muncul: beri ytyp sendiri (nama file = nama model).

Pivot tengah bawah, skala 1:1 (sama dengan prop_nasi_goreng_v2). Tidak ada collision (prop dipegang).
Jangan taruh .glb di folder stream.

glb -> prop umum (pohon, buah, peti) dengan collision: build_prop.py (contoh kelapa, sumber ..\..\..\[job]\f_kelapa\materi)
1. Tekstur DDS saja:  blender -b --factory-startup --python prep_blender.py -- <in.glb> <build\x.blender.glb> <build> <nama_model> 99999 99999 99999
2. XML dari glb ASLI (bukan hasil Blender, supaya alphaMode + matrix empty tetap):
                     python build_prop.py <in.glb> <build> <nama_model> <mesh|box|none> <lod> [static]
   mesh = collision dari mesh col_* (tidak digambar), box = kotak bbox, static = ytyp flags 32 (prop map).
   Pivot = origin glb. Material MASK -> cutout.sps. Empty dicetak + <nama_model>_titik.json (offset GTA).
3. cw.ps1 import seperti di atas ke ..\stream\<pack>\, lalu data_file di fxmanifest.lua.
