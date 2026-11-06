# Kebun kelapa Paleto: satu sumber posisi pohon -> ymap (f_addonprop/stream/kelapa) + config/pohon.lua (f_kelapa).
# python build_kebun.py   lalu   cw.ps1 import <build>/f_kebun_kelapa.ymap.xml <stream>/kelapa/f_kebun_kelapa.ymap
# Titik = tinggi TANAH: /coords server ini mencetak z kaki (dicek raycast collision map: selisih 0,00 m).
# Pivot pohon dibenamkan BENAM m supaya tidak melayang di tanah miring.
import os, math, random

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
BUILD = os.path.join(RES, '[script]', 'f_addonprop', '_sumber', 'kelapa', 'build')
LUA = os.path.join(HERE, '..', 'config', 'pohon.lua')

MODEL, YMAP, LOD, BENAM = 'f_kelapa_pohon', 'f_kebun_kelapa', 300, 0.15
TITIK = [
    (8.5, 6858.89, 11.89), (0.67, 6860.01, 11.9), (-2.3, 6865.88, 11.81), (2.35, 6868.68, 11.63),
    (9.8, 6870.8, 11.53), (5.24, 6877.39, 11.34), (11.38, 6881.21, 11.38), (18.61, 6873.85, 11.9),
    (-7.17, 6879.74, 11.65), (-14.5, 6874.77, 12.14), (-24.49, 6869.66, 12.99), (-25.0, 6879.81, 12.83),
    (-14.52, 6883.98, 11.87), (-26.66, 6852.75, 12.63), (-35.99, 6857.29, 13.15),
    # +30 acak (2026-11-01): di area 15 titik di atas (+4 m), jarak >= 5 m, tanah sama (material 18/46), datar.
    # z = raycast ke collision map GTA (cs1_07_5 / cs1_09_20 + hi@), bukan /coords.
    (17.87, 6867.02, 11.91), (-8.2, 6871.79, 11.89), (-0.56, 6879.86, 11.45), (-28.08, 6858.24, 12.98),
    (-11.36, 6859.66, 12.2), (-20.25, 6857.76, 12.55), (7.98, 6864.46, 11.71), (13.01, 6863.91, 11.74),
    (-31.79, 6874.0, 13.68), (-32.7, 6865.26, 13.8), (-20.95, 6883.46, 12.38), (-26.8, 6864.22, 13.17),
    (-21.44, 6851.63, 12.59), (-16.72, 6866.53, 12.42), (16.88, 6880.83, 11.57), (6.3, 6885.64, 11.18),
    (-13.61, 6852.82, 12.5), (-1.52, 6884.86, 11.38), (-21.15, 6875.35, 12.59), (-31.17, 6850.59, 12.59),
    (-0.55, 6874.45, 11.57), (12.59, 6875.79, 11.52), (-7.73, 6865.62, 12.02), (-7.23, 6885.52, 11.52),
    (-26.64, 6874.72, 13.12), (-4.91, 6859.12, 11.99), (-20.67, 6862.89, 12.65), (-7.83, 6853.69, 12.41),
    (-37.69, 6862.32, 13.97), (-17.29, 6879.64, 12.21),
]
# bbox ytyp f_kelapa_pohon (v2, pelepah menyambung) + offset empty dari build_prop.py (f_kelapa_pohon_titik.json)
BMIN, BMAX = (-3.04, -3.39, 0.0), (4.2, 3.7, 9.95)
BUAH = [(0.854, 0.0, 7.92), (0.743, -0.184, 7.8), (0.59, -0.318, 7.88), (0.758, -0.082, 7.62), (0.66, -0.258, 7.56), (0.478, -0.253, 7.68)]
ATAS = (0.469, 0.0, 6.7)

rnd = random.Random(7)  # heading acak tapi tetap sama setiap build
pohon = []
for x, y, z in TITIK:
    pohon.append((x, y, round(z - BENAM, 2), rnd.randrange(0, 360, 5)))

def rot(h, p):  # offset lokal -> dunia (sama seperti GetOffsetFromEntityInWorldCoords)
    a = math.radians(h); c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c, p[2])

f = lambda v: ('%.4f' % v).rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0'
xyz = lambda tag, v, ind: '%s<%s x="%s" y="%s" z="%s" />\n' % (ind, tag, f(v[0]), f(v[1]), f(v[2]))

ents, emn, emx = [], [1e9] * 3, [-1e9] * 3
for i, (x, y, z, h) in enumerate(pohon):
    for cx in (BMIN[0], BMAX[0]):
        for cy in (BMIN[1], BMAX[1]):
            for cz in (BMIN[2], BMAX[2]):
                ox, oy, oz = rot(h, (cx, cy, cz)); w = (x + ox, y + oy, z + oz)
                emn = [min(emn[k], w[k]) for k in range(3)]; emx = [max(emx[k], w[k]) for k in range(3)]
    a = math.radians(h)
    # rotasi entity ymap disimpan terbalik (inverse quaternion), sama seperti build_logo.py
    ents.append('''  <Item type="CEntityDef">
   <archetypeName>%s</archetypeName>
   <flags value="32" />
   <guid value="%d" />
   <position x="%s" y="%s" z="%s" />
   <rotation x="0" y="0" z="%s" w="%s" />
   <scaleXY value="1" />
   <scaleZ value="1" />
   <parentIndex value="-1" />
   <lodDist value="%d" />
   <childLodDist value="0" />
   <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>
   <numChildren value="0" />
   <priorityLevel>PRI_REQUIRED</priorityLevel>
   <extensions />
   <ambientOcclusionMultiplier value="255" />
   <artificialAmbientOcclusion value="255" />
   <tintValue value="0" />
  </Item>
''' % (MODEL, 0x4B454C00 + i, f(x), f(y), f(z), f(-math.sin(a / 2)), f(math.cos(a / 2)), LOD))

smn = [v - LOD for v in emn]; smx = [v + LOD for v in emx]
M = '''<?xml version="1.0" encoding="UTF-8"?>
<CMapData>
 <name>%s</name>
 <parent />
 <flags value="0" />
 <contentFlags value="1" />
%s%s%s%s <entities>
%s </entities>
 <containerLods itemType="rage__fwContainerLodDef" />
 <boxOccluders itemType="BoxOccluder" />
 <occludeModels itemType="OccludeModel" />
 <physicsDictionaries />
 <instancedData>
  <ImapLink />
  <PropInstanceList itemType="rage__fwPropInstanceListDef" />
  <GrassInstanceList itemType="rage__fwGrassInstanceListDef" />
 </instancedData>
 <timeCycleModifiers itemType="CTimeCycleModifier" />
 <carGenerators itemType="CCarGen" />
 <LODLightsSOA>
  <direction itemType="FloatXYZ" />
  <falloff />
  <falloffExponent />
  <timeAndStateFlags />
  <hash />
  <coneInnerAngle />
  <coneOuterAngleOrCapExt />
  <coronaIntensity />
 </LODLightsSOA>
 <DistantLODLightsSOA>
  <position itemType="FloatXYZ" />
  <RGBI />
  <numStreetLights value="0" />
  <category value="0" />
 </DistantLODLightsSOA>
 <block>
  <version value="0" />
  <flags value="0" />
  <name>%s</name>
  <exportedBy>CodeWalker</exportedBy>
  <owner />
  <time />
 </block>
</CMapData>
''' % (YMAP, xyz('streamingExtentsMin', smn, ' '), xyz('streamingExtentsMax', smx, ' '), xyz('entitiesExtentsMin', emn, ' '),
       xyz('entitiesExtentsMax', emx, ' '), ''.join(ents), YMAP)
os.makedirs(BUILD, exist_ok=True)
open(os.path.join(BUILD, YMAP + '.ymap.xml'), 'w', encoding='utf-8').write(M)

v3 = lambda p: 'vec3(%.2f, %.2f, %.2f)' % p
L = ['-- DIBUAT OTOMATIS oleh _sumber/build_kebun.py (jangan edit manual: ubah TITIK di sana, build ulang ymap + file ini).\n',
     '-- coords = pangkal pohon di tanah, heading = rotasi ymap, atas = titik ped berhenti di atas, buah = posisi kelapa menggantung.\n',
     'return {\n']
for x, y, z, h in pohon:
    w = lambda p: (x + rot(h, p)[0], y + rot(h, p)[1], z + p[2])
    L.append('    { coords = %s, heading = %d.0, atas = %s,\n      buah = { %s } },\n'
             % (v3((x, y, z)), h, v3(w(ATAS)), ', '.join(v3(w(b)) for b in BUAH)))
L.append('}\n')
os.makedirs(os.path.dirname(LUA), exist_ok=True)
open(LUA, 'w', encoding='utf-8', newline='\n').write(''.join(L))
print('%d pohon | entities %s .. %s' % (len(pohon), [round(v, 1) for v in emn], [round(v, 1) for v in emx]))
