Prop nelayan: materi/*.glb (AI, 150 rb - 1,2 jt segitiga, tanpa tekstur) -> stream/*.ydr + f_nelayan.ytyp

1) Olah di Blender (decimate, jaring jadi kulit convex hull + tekstur jaring, ikan dipecah punggung/perut, peti kosong dari peti ikan):
   "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup -P olah_blender.py -- ..\materi ..\_build [file.glb ...]
   Hasil: _build\<model>.glb, _build\jaring_<material>.rgba, pratinjau _build\<model>_asli.png / _hasil.png
2) glb -> XML CodeWalker:
   python build_prop.py ..\_build ..\_build\xml
3) XML -> file game (pakai -LiteralPath, folder [job] dianggap wildcard oleh PowerShell):
   powershell -File cw.ps1 import ..\_build\xml\<nama>.ydr.xml ..\stream\<nama>.ydr   (juga f_nelayan.ytyp.xml)

Jatah segitiga / ukuran tile jaring / jatah peti: PROPS di olah_blender.py. lodDist + collision: MODELS di build_prop.py.
Jaring = cutout.sps (RenderBucket 3, HardAlphaBlend 0.01, sama seperti prop GTA), tekstur A8R8G8B8 128px + mipmap, muka dobel.
Pivot semua prop = tengah bawah. Peti punya collision kotak (GeometryBVH, physicsDictionary = nama model); jaring tanpa collision.
Uji in-game: /nelayanprop [tangan|lempar|laut|ikan|peti|kosong|tumpuk|hapus] (admin).
