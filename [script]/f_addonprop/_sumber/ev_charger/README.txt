Charger mobil listrik (dipakai ox_fuel). Sumber: 4play_ev_charge_station.glb + 4play_ev_charge_gun.glb.
Jalankan dari folder ini (_sumber\ev_charger). B = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"

1. Tekstur DXT1 (base color, maks 512 / pistol 256):
   B -b --factory-startup --python ..\..\_tools\glb_tex_dxt1.py -- 4play_ev_charge_station.glb build 4play_ev_charge_station 512
   B -b --factory-startup --python ..\..\_tools\glb_tex_dxt1.py -- 4play_ev_charge_station.glb build 4play_ev_charge_station_empty 512
   B -b --factory-startup --python ..\..\_tools\glb_tex_dxt1.py -- 4play_ev_charge_gun.glb build 4play_ev_charge_gun 256

2. XML (LED / layar / label = emissive.sps):
   set EM=emis=accent_cyan_led:2,screen_ui:1,label_4play:0.6
   python ..\..\_tools\build_prop.py 4play_ev_charge_station.glb build 4play_ev_charge_station boxes=station_collision.json 100 %EM%
   python ..\..\_tools\build_prop.py 4play_ev_charge_station.glb build 4play_ev_charge_station_empty boxes=station_collision.json 100 %EM% drop=ev_charge_gun,charge_cable
   python ..\..\_tools\build_prop.py 4play_ev_charge_gun.glb build 4play_ev_charge_gun none 50 %EM% drop=collision rotz=90 move=0,0.0695,-0.195

3. Biner: ..\..\_tools\cw.ps1 import build\<model>.ydr.xml ..\..\stream\ev_charger\<model>.ydr  (sama untuk .ytyp.xml)

- station_empty = station tanpa pistol + kabel; ox_fuel menukar model saat pistol diambil.
- Collision station = 3 kotak (station_collision.json, koordinat GTA): alas, badan, holster. Pistol tanpa collision.
- Depan station (layar) menghadap -Y model: berdiri di depan charger menghadap ke charger -> heading kamu = heading charger.
- Pistol diputar 90 + digeser supaya pivot & arahnya SAMA dengan prop_eletricpistol lc_fuel: pangkal kabel di (0, -0.033, -0.195),
  pegangan ke bawah, colokan menghadap +Y. Jadi angka tangan lc_fuel (0.13, 0.04, 0.01, -42, -115, -63.42, order 0) dan
  rotasi tancap (-45, 0, -90) dipakai apa adanya. Colokan kita 18 cm lebih panjang -> ox_fuel nozzles.electric.shift.
