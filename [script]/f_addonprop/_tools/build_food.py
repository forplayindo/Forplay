# glb (hasil prep_blender.py) -> CodeWalker XML ydr + ytyp untuk prop makanan yang dipegang (tanpa ymap, tanpa collision).
# python build_food.py <file.glb> <folder_build> <nama_model> [profil]
# Tekstur: <folder_build>/<nama_model>_<material>.dds (dari prep_blender.py) kalau ada, selain itu warna solid DXT1 8x8.
# Default: pivot tengah bawah (sama seperti prop_nasi_goreng_v2), skala 1:1, sumbu glTF (x, y, z) -> GTA (x, -z, y).
import sys, os, math, struct, json

# profil: sumbu glTF -> GTA + pivot (titik GTA yang jadi 0,0,0; None = tengah bawah)
PROFILES = {
    'default': (lambda p: (p[0], -p[2], p[1]), None),
    # sendok glTF: panjang di x (kepala di -x), atas y. Disamakan dengan devkit_spork:
    # kepala di -Y, pivot di gagang 5,7 cm dari ujung, sehingga offset tangan spork bisa dipakai.
    'sendok': (lambda p: (p[2], p[0], p[1]), (0.0, 0.038, 0.0185)),
}
glb, out, MODEL = sys.argv[1:4]
AXES, PIVOT = PROFILES[sys.argv[4] if len(sys.argv) > 4 else 'default']
os.makedirs(out, exist_ok=True)

# ---------- baca glb ----------
d = open(glb, 'rb').read()
jl, _ = struct.unpack('<II', d[12:20]); j = json.loads(d[20:20 + jl])
o = 20 + jl; bl, _ = struct.unpack('<II', d[o:o + 8]); b = d[o + 8:o + 8 + bl]

def acc(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    fmt = {5126: 'f', 5123: 'H', 5125: 'I', 5121: 'B'}[a['componentType']]
    sz = struct.calcsize(fmt); stride = bv.get('byteStride', sz * n)
    base = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * n, b, base + k * stride) if n > 1 else struct.unpack_from('<' + fmt, b, base + k * stride)[0] for k in range(a['count'])]

def matmul(a, c):  # column-major 4x4
    return [sum(a[k * 4 + r] * c[col * 4 + k] for k in range(4)) for col in range(4) for r in range(4)]

def nodemat(n):
    if 'matrix' in n: return n['matrix']
    t = n.get('translation', [0, 0, 0]); x, y, z, w = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
    R = [1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w), 0, 2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w), 0,
         2*(x*z+y*w), 2*(y*z-x*w), 1-2*(x*x+y*y), 0, 0, 0, 0, 1]
    for c in range(3):
        for r in range(3): R[c * 4 + r] *= s[c]
    R[12], R[13], R[14] = t
    return R

def xf(m, p, w=1):
    return tuple(m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r] * w for r in range(3))

mats = j['materials']

def uv_xform(mi):
    tex = mats[mi].get('pbrMetallicRoughness', {}).get('baseColorTexture', {})
    t = tex.get('extensions', {}).get('KHR_texture_transform', {})
    (ou, ov), (su, sv) = t.get('offset', [0, 0]), t.get('scale', [1, 1])
    return lambda uv: (ou + su * uv[0], ov + sv * uv[1])

# geometri per material; material doubleSided -> segitiga digandakan terbalik (GTA cull backface)
geo, allp = {}, []
def add(mi, pos, nor, uv, idx):
    g = geo.setdefault(mi, {'v': [], 'i': []})
    tf = uv_xform(mi)
    for flip in ((False, True) if mats[mi].get('doubleSided') else (False,)):
        base = len(g['v'])
        for p, n, t in zip(pos, nor, uv):
            P = AXES(p); N = AXES(n)
            ln = math.sqrt(sum(c * c for c in N)) or 1
            N = tuple((-c if flip else c) / ln for c in N)
            g['v'].append([P, N, tf(t)]); allp.append(P)
        for k in range(0, len(idx), 3):
            a, c, e = idx[k:k + 3]
            g['i'].extend((base + a, base + e, base + c) if flip else (base + a, base + c, base + e))

def rec(ni, parent):
    n = j['nodes'][ni]; m = matmul(parent, nodemat(n))
    if 'mesh' in n:
        for p in j['meshes'][n['mesh']]['primitives']:
            at = p['attributes']
            pos = [xf(m, v) for v in acc(at['POSITION'])]
            nor = [xf(m, v, 0) for v in acc(at['NORMAL'])]
            uv = acc(at['TEXCOORD_0']) if 'TEXCOORD_0' in at else [(0.0, 0.0)] * len(pos)
            idx = acc(p['indices']) if p.get('indices') is not None else list(range(len(pos)))
            add(p.get('material', 0), pos, nor, uv, idx)
    for c in n.get('children', []): rec(c, m)

for r in j['scenes'][j.get('scene', 0)]['nodes']:
    rec(r, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])

mn = [min(p[k] for p in allp) for k in range(3)]
mx = [max(p[k] for p in allp) for k in range(3)]
off = PIVOT or ((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2])  # default: pivot tengah bawah
for g in geo.values():
    for v in g['v']: v[0] = tuple(v[0][k] - off[k] for k in range(3))
bmin = [mn[k] - off[k] for k in range(3)]; bmax = [mx[k] - off[k] for k in range(3)]
cen = [(bmin[k] + bmax[k]) / 2 for k in range(3)]
rad = math.sqrt(sum(((bmax[k] - bmin[k]) / 2) ** 2 for k in range(3)))

f = lambda v: ('%.6f' % v).rstrip('0').rstrip('.') if v != 0 else '0'
xyz = lambda tag, v, ind, w=False: '%s<%s x="%s" y="%s" z="%s"%s />\n' % (ind, tag, f(v[0]), f(v[1]), f(v[2]), ' w="0"' if w else '')

def lin2srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def write_dds_dxt1(path, rgb, size=8):
    r, g, bl = (int(round(lin2srgb(c) * 255)) for c in rgb)
    c565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (bl >> 3)
    block = struct.pack('<HHI', c565, c565, 0); nblocks = (size // 4) ** 2
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, 0x81007, size, size, nblocks * 8, 0, 1) + b'\0' * 44
    hdr += struct.pack('<II4sIIIII', 32, 0x4, b'DXT1', 0, 0, 0, 0, 0) + struct.pack('<IIIII', 0x1000, 0, 0, 0, 0)
    open(path, 'wb').write(hdr + block * nblocks)

def dds_info(path):  # (w, h, mips, format) dari header DDS
    h = open(path, 'rb').read(128)
    hh, ww, mips = struct.unpack_from('<III', h, 12)[0], struct.unpack_from('<I', h, 16)[0], struct.unpack_from('<I', h, 28)[0]
    fourcc = h[84:88]
    fmt = 'D3DFMT_' + fourcc.decode() if fourcc.strip(b'\0') else 'D3DFMT_A8R8G8B8'
    return ww, hh, max(1, mips), fmt

# ---------- ydr ----------
order = sorted(geo.keys())
LOD = 100
X = ['<?xml version="1.0" encoding="UTF-8"?>\n<Drawable>\n', ' <Name>%s</Name>\n' % MODEL]
X.append(xyz('BoundingSphereCenter', cen, ' ')); X.append(' <BoundingSphereRadius value="%s" />\n' % f(rad))
X.append(xyz('BoundingBoxMin', bmin, ' ')); X.append(xyz('BoundingBoxMax', bmax, ' '))
X.append(' <LodDistHigh value="%d" />\n <LodDistMed value="9998" />\n <LodDistLow value="9998" />\n <LodDistVlow value="9998" />\n' % LOD)
X.append(' <FlagsHigh value="1" />\n <FlagsMed value="0" />\n <FlagsLow value="0" />\n <FlagsVlow value="0" />\n')
X.append(' <ShaderGroup>\n  <TextureDictionary>\n')
texname = {}
for mi in order:
    tn = '%s_%s' % (MODEL, mats[mi]['name'])
    p = os.path.join(out, tn + '.dds')
    if not ('baseColorTexture' in mats[mi].get('pbrMetallicRoughness', {}) and os.path.exists(p)):
        write_dds_dxt1(p, mats[mi]['pbrMetallicRoughness'].get('baseColorFactor', [1, 1, 1])[:3])
    if tn in texname.values(): texname[mi] = tn; continue
    texname[mi] = tn
    w, h, mips, fmt = dds_info(p)
    X.append('   <Item>\n    <Name>%s</Name>\n    <Unk32 value="128" />\n    <Usage>UNKNOWN</Usage>\n    <UsageFlags>UNK24</UsageFlags>\n    <ExtraFlags value="0" />\n'
             '    <Width value="%d" />\n    <Height value="%d" />\n    <MipLevels value="%d" />\n    <Format>%s</Format>\n    <FileName>%s.dds</FileName>\n   </Item>\n' % (tn, w, h, mips, fmt, tn))
X.append('  </TextureDictionary>\n  <Shaders>\n')
for mi in order:
    X.append('   <Item>\n    <Name>default</Name>\n    <FileName>default.sps</FileName>\n    <RenderBucket value="0" />\n    <Parameters>\n')
    X.append('     <Item name="DiffuseSampler" type="Texture">\n      <Name>%s</Name>\n     </Item>\n' % texname[mi])
    X.append('     <Item name="matMaterialColorScale" type="Vector" x="1" y="0" z="0" w="1" />\n     <Item name="HardAlphaBlend" type="Vector" x="1" y="0" z="0" w="0" />\n     <Item name="useTessellation" type="Vector" x="0" y="0" z="0" w="0" />\n     <Item name="wetnessMultiplier" type="Vector" x="1" y="0" z="0" w="0" />\n     <Item name="globalAnimUV1" type="Vector" x="0" y="1" z="0" w="0" />\n     <Item name="globalAnimUV0" type="Vector" x="1" y="0" z="0" w="0" />\n    </Parameters>\n   </Item>\n')
X.append('  </Shaders>\n </ShaderGroup>\n <DrawableModelsHigh>\n  <Item>\n   <RenderMask value="255" />\n   <Flags value="0" />\n   <HasSkin value="0" />\n   <BoneIndex value="0" />\n   <Unknown1 value="0" />\n   <Geometries>\n')
for si, mi in enumerate(order):
    g = geo[mi]
    assert len(g['v']) < 65535, (mats[mi]['name'], len(g['v']))
    gmn = [min(v[0][k] for v in g['v']) for k in range(3)]; gmx = [max(v[0][k] for v in g['v']) for k in range(3)]
    X.append('    <Item>\n     <ShaderIndex value="%d" />\n' % si)
    X.append(xyz('BoundingBoxMin', gmn, '     ', True)); X.append(xyz('BoundingBoxMax', gmx, '     ', True))
    X.append('     <VertexBuffer>\n      <Flags value="0" />\n      <Layout type="GTAV1">\n       <Position />\n       <Normal />\n       <Colour0 />\n       <TexCoord0 />\n      </Layout>\n      <Data2>\n')
    for P, N, T in g['v']:
        X.append('       %s %s %s   %s %s %s   255 255 255 255   %s %s\n' % (f(P[0]), f(P[1]), f(P[2]), f(N[0]), f(N[1]), f(N[2]), f(T[0]), f(T[1])))
    X.append('      </Data2>\n     </VertexBuffer>\n     <IndexBuffer>\n      <Data>\n')
    ii = g['i']
    for k in range(0, len(ii), 24): X.append('       ' + ' '.join(str(x) for x in ii[k:k + 24]) + '\n')
    X.append('      </Data>\n     </IndexBuffer>\n    </Item>\n')
X.append('   </Geometries>\n  </Item>\n </DrawableModelsHigh>\n</Drawable>\n')
open(os.path.join(out, MODEL + '.ydr.xml'), 'w', encoding='utf-8').write(''.join(X))

# ---------- ytyp ----------
# flags sama dengan prop_nasi_goreng_v2 (sudah jalan di tangan). Tanpa collision -> physicsDictionary kosong,
# textureDictionary kosong (tekstur tertanam di ydr).
Y = '''<?xml version="1.0" encoding="UTF-8"?>
<CMapTypes>
 <extensions />
 <archetypes>
  <Item type="CBaseArchetypeDef">
   <lodDist value="%d" />
   <flags value="549453856" />
   <specialAttribute value="0" />
%s%s%s   <bsRadius value="%s" />
   <hdTextureDist value="50" />
   <name>%s</name>
   <textureDictionary />
   <clipDictionary />
   <drawableDictionary />
   <physicsDictionary />
   <assetType>ASSET_TYPE_DRAWABLE</assetType>
   <assetName>%s</assetName>
   <extensions />
  </Item>
 </archetypes>
 <name>%s</name>
 <dependencies />
 <compositeEntityTypes itemType="CCompositeEntityType" />
</CMapTypes>
''' % (LOD, xyz('bbMin', bmin, '   '), xyz('bbMax', bmax, '   '), xyz('bsCentre', cen, '   '), f(rad), MODEL, MODEL, MODEL)
open(os.path.join(out, MODEL + '.ytyp.xml'), 'w', encoding='utf-8').write(Y)

print('%s: %.3f x %.3f x %.3f m | geometries %d | verts %d | tris %d' % (MODEL, *(bmax[k] - bmin[k] for k in range(3)), len(order),
      sum(len(g['v']) for g in geo.values()), sum(len(g['i']) for g in geo.values()) // 3))
