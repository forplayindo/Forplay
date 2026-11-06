# glb ringan (hasil olah_blender.py) -> CodeWalker XML: <model>.ydr.xml + tekstur dds, dan satu f_nelayan.ytyp.xml.
# python build_prop.py <folder_build> <folder_xml>
# Pivot = tengah bawah. Material jaring -> cutout.sps + tekstur jaring alpha (A8R8G8B8 + mipmap),
# sisanya default.sps warna polos (DXT1 8x8). Peti dapat collision kotak (GeometryBVH), jaring tanpa collision.
import sys, os, math, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from glbread import load, walk

BUILD, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
YTYP = 'f_nelayan'

# model -> (lodDist, collision kotak?)
MODELS = {
    'f_nelayan_jaring_tangan': (60, False),
    'f_nelayan_jaring_lempar': (120, False),
    'f_nelayan_jaring_laut':   (200, False),
    'f_nelayan_jaring_ikan':   (100, False),
    'f_nelayan_peti_ikan':     (80, True),
    'f_nelayan_peti_kosong':   (80, True),
    'f_nelayan_peti_tumpuk':   (100, True),
}
NET_SIZE = 128

def is_net(name):
    n = name.lower()
    return 'nylon' in n or n.startswith('net')

def lin2srgb(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def write_dds_dxt1(path, rgb, size=8):
    r, g, bl = (int(round(lin2srgb(c) * 255)) for c in rgb)
    c565 = ((r >> 3) << 11) | ((g >> 2) << 5) | (bl >> 3)
    block = struct.pack('<HHI', c565, c565, 0)
    nblocks = (size // 4) * (size // 4)
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, 0x81007, size, size, nblocks * 8, 0, 1)
    hdr += b'\0' * 44
    hdr += struct.pack('<II4sIIIII', 32, 0x4, b'DXT1', 0, 0, 0, 0, 0)
    hdr += struct.pack('<IIIII', 0x1000, 0, 0, 0, 0)
    open(path, 'wb').write(hdr + block * nblocks)

def write_dds_argb(path, rgba, size):
    """A8R8G8B8 + mipmap (box filter). rgba = bytes RGBA baris atas dulu."""
    levels = []
    cur = [list(rgba[i:i + 4]) for i in range(0, len(rgba), 4)]
    s = size
    while True:
        levels.append((s, cur))
        if s == 1:
            break
        n = s // 2
        nxt = []
        for y in range(n):
            for x in range(n):
                px = [cur[(2 * y + dy) * s + 2 * x + dx] for dy in (0, 1) for dx in (0, 1)]
                nxt.append([sum(p[k] for p in px) // 4 for k in range(4)])
        cur, s = nxt, n
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, 0x2100F, size, size, size * 4, 0, len(levels))
    hdr += b'\0' * 44
    hdr += struct.pack('<II4sIIIII', 32, 0x41, b'\0\0\0\0', 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
    hdr += struct.pack('<IIIII', 0x401008, 0, 0, 0, 0)
    body = bytearray()
    for _, px in levels:
        for r, g, b, a in px:
            body += bytes((b, g, r, a))
    open(path, 'wb').write(hdr + bytes(body))
    return len(levels)

f = lambda v: ('%.6f' % v).rstrip('0').rstrip('.') if v != 0 else '0'
xyz = lambda tag, v, ind, w=False: '%s<%s x="%s" y="%s" z="%s"%s />\n' % (ind, tag, f(v[0]), f(v[1]), f(v[2]), ' w="0"' if w else '')

SHADER_COMMON = ('     <Item name="matMaterialColorScale" type="Vector" x="1" y="0" z="0" w="1" />\n'
                 '     <Item name="HardAlphaBlend" type="Vector" x="%s" y="0" z="0" w="0" />\n'
                 '     <Item name="useTessellation" type="Vector" x="0" y="0" z="0" w="0" />\n'
                 '     <Item name="wetnessMultiplier" type="Vector" x="1" y="0" z="0" w="0" />\n'
                 '     <Item name="globalAnimUV1" type="Vector" x="0" y="1" z="0" w="0" />\n'
                 '     <Item name="globalAnimUV0" type="Vector" x="1" y="0" z="0" w="0" />\n')

FLAGS1 = 'MAP_WEAPON, MAP_DYNAMIC, MAP_ANIMAL, MAP_COVER, MAP_VEHICLE'
FLAGS2 = ('UNKNOWN, MAP_WEAPON, MAP_DYNAMIC, MAP_ANIMAL, MAP_COVER, MAP_VEHICLE, VEHICLE_NOT_BVH, VEHICLE_BVH, VEHICLE_BOX, '
          'PED, RAGDOLL, ANIMAL, ANIMAL_RAGDOLL, OBJECT, OBJECT_ENV_CLOTH, PLANT, PROJECTILE, EXPLOSION, PICKUP, FOLIAGE, '
          'FORKLIFT_FORKS, TEST_WEAPON, TEST_CAMERA, TEST_AI, TEST_SCRIPT, TEST_VEHICLE_WHEEL, GLASS, MAP_RIVER, SMOKE, '
          'UNSMASHED, MAP_STAIRS, MAP_DEEP_SURFACE')
FACES = [(0, 2, 1), (0, 3, 2), (4, 5, 6), (4, 6, 7), (0, 1, 5), (0, 5, 4),
         (3, 7, 6), (3, 6, 2), (0, 4, 7), (0, 7, 3), (1, 2, 6), (1, 6, 5)]

def bound_common(ind, a, c, margin):
    ce = [(a[k] + c[k]) / 2 for k in range(3)]
    r = math.sqrt(sum(((c[k] - a[k]) / 2) ** 2 for k in range(3)))
    s = xyz('BoxMin', a, ind) + xyz('BoxMax', c, ind) + xyz('BoxCenter', ce, ind) + xyz('SphereCenter', ce, ind)
    s += '%s<SphereRadius value="%s" />\n%s<Margin value="%s" />\n%s<Volume value="1" />\n%s<Inertia x="1" y="1" z="1" />\n' % (ind, f(r), ind, f(margin), ind, ind)
    for tag, v in (('MaterialIndex', 0), ('MaterialColourIndex', 0), ('ProceduralID', 0), ('RoomID', 0), ('PedDensity', 0), ('UnkFlags', 0), ('PolyFlags', 0), ('UnkType', 1)):
        s += '%s<%s value="%d" />\n' % (ind, tag, v)
    return s

def box_bounds(a, c):
    """Satu GeometryBVH berisi 12 segitiga kotak (child Box polos tidak menahan ped, lihat f_logokota)."""
    gc = [(a[k] + c[k]) / 2 for k in range(3)]
    verts = []
    for z in (a[2], c[2]):
        for x, y in ((a[0], a[1]), (c[0], a[1]), (c[0], c[1]), (a[0], c[1])):
            verts.append((x - gc[0], y - gc[1], z - gc[2]))
    X = [' <Bounds type="Composite">\n', bound_common('  ', a, c, 0), '  <Children>\n   <Item type="GeometryBVH">\n']
    X.append(bound_common('    ', a, c, 0.005))
    X.append('    <CompositeTransform>\n     1 0 0 0\n     0 1 0 0\n     0 0 1 0\n     0 0 0 1\n    </CompositeTransform>\n')
    X.append('    <CompositeFlags1>%s</CompositeFlags1>\n    <CompositeFlags2>%s</CompositeFlags2>\n' % (FLAGS1, FLAGS2))
    X.append(xyz('GeometryCenter', gc, '    '))
    X.append('    <UnkFloat1 value="0" />\n    <UnkFloat2 value="0.002" />\n')
    X.append('    <Materials>\n     <Item>\n      <Type value="1" />\n      <ProceduralID value="0" />\n      <RoomID value="0" />\n      <PedDensity value="0" />\n      <Flags>NONE</Flags>\n      <MaterialColourIndex value="0" />\n      <Unk value="0" />\n     </Item>\n    </Materials>\n')
    X.append('    <Vertices>\n' + ''.join('     %s, %s, %s\n' % tuple(f(c_) for c_ in v) for v in verts) + '    </Vertices>\n')
    X.append('    <Polygons>\n' + ''.join('     <Triangle m="0" v1="%d" v2="%d" v3="%d" f1="0" f2="0" f3="0" />\n' % t for t in FACES) + '    </Polygons>\n')
    X.append('   </Item>\n  </Children>\n </Bounds>\n')
    return ''.join(X)

archetypes = []
for MODEL, (LOD, COLL) in MODELS.items():
    glb = os.path.join(BUILD, MODEL + '.glb')
    j, b = load(glb)
    mats = j['materials']
    texdir = OUT  # cw.ps1 import mencari dds di folder xml

    geo, allp = {}, []
    for name, mi, pos, nor, uv, idx in walk(j, b):
        g = geo.setdefault(mi, {'v': [], 'i': []})
        base = len(g['v'])
        for p, n, t in zip(pos, nor, uv):
            P = (p[0], -p[2], p[1])                     # glTF Y-up -> GTA Z-up
            N = (n[0], -n[2], n[1])
            ln = math.sqrt(sum(c * c for c in N)) or 1
            g['v'].append([P, tuple(c / ln for c in N), t])
            allp.append(P)
        g['i'].extend(base + k for k in idx)

    mn = [min(p[k] for p in allp) for k in range(3)]
    mx = [max(p[k] for p in allp) for k in range(3)]
    off = ((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2])  # pivot: tengah bawah
    for g in geo.values():
        for v in g['v']:
            v[0] = tuple(v[0][k] - off[k] for k in range(3))
    bmin = [mn[k] - off[k] for k in range(3)]
    bmax = [mx[k] - off[k] for k in range(3)]
    cen = [(bmin[k] + bmax[k]) / 2 for k in range(3)]
    rad = math.sqrt(sum(((bmax[k] - bmin[k]) / 2) ** 2 for k in range(3)))

    order = sorted(geo.keys())
    X = ['<?xml version="1.0" encoding="UTF-8"?>\n<Drawable>\n', ' <Name>%s</Name>\n' % MODEL]
    X.append(xyz('BoundingSphereCenter', cen, ' '))
    X.append(' <BoundingSphereRadius value="%s" />\n' % f(rad))
    X.append(xyz('BoundingBoxMin', bmin, ' ')); X.append(xyz('BoundingBoxMax', bmax, ' '))
    for t in ('High', 'Med', 'Low', 'Vlow'):
        X.append(' <LodDist%s value="9998" />\n' % t)
    X.append(' <FlagsHigh value="1" />\n <FlagsMed value="0" />\n <FlagsLow value="0" />\n <FlagsVlow value="0" />\n')
    X.append(' <ShaderGroup>\n  <TextureDictionary>\n')
    shaders = []
    for mi in order:
        m = mats[mi]
        tn = MODEL.replace('f_nelayan_', 'fn_') + '_' + m['name']  # unik per model (satu folder dds)
        if is_net(m['name']):
            raw = open(os.path.join(BUILD, 'jaring_' + m['name'] + '.rgba'), 'rb').read()
            nm = write_dds_argb(os.path.join(texdir, tn + '.dds'), raw, NET_SIZE)
            X.append('   <Item>\n    <Name>%s</Name>\n    <Unk32 value="128" />\n    <Usage>DIFFUSE</Usage>\n    <UsageFlags>UNK24</UsageFlags>\n    <ExtraFlags value="0" />\n    <Width value="%d" />\n    <Height value="%d" />\n    <MipLevels value="%d" />\n    <Format>D3DFMT_A8R8G8B8</Format>\n    <FileName>%s.dds</FileName>\n   </Item>\n' % (tn, NET_SIZE, NET_SIZE, nm, tn))
            shaders.append('   <Item>\n    <Name>default</Name>\n    <FileName>cutout.sps</FileName>\n    <RenderBucket value="3" />\n    <Parameters>\n'
                           '     <Item name="DiffuseSampler" type="Texture">\n      <Name>%s</Name>\n     </Item>\n' % tn + SHADER_COMMON % '0.01' + '    </Parameters>\n   </Item>\n')
        else:
            write_dds_dxt1(os.path.join(texdir, tn + '.dds'), m['pbrMetallicRoughness'].get('baseColorFactor', [1, 1, 1])[:3])
            X.append('   <Item>\n    <Name>%s</Name>\n    <Unk32 value="128" />\n    <Usage>UNKNOWN</Usage>\n    <UsageFlags>UNK24</UsageFlags>\n    <ExtraFlags value="0" />\n    <Width value="8" />\n    <Height value="8" />\n    <MipLevels value="1" />\n    <Format>D3DFMT_DXT1</Format>\n    <FileName>%s.dds</FileName>\n   </Item>\n' % (tn, tn))
            shaders.append('   <Item>\n    <Name>default</Name>\n    <FileName>default.sps</FileName>\n    <RenderBucket value="0" />\n    <Parameters>\n'
                           '     <Item name="DiffuseSampler" type="Texture">\n      <Name>%s</Name>\n     </Item>\n' % tn + SHADER_COMMON % '1' + '    </Parameters>\n   </Item>\n')
    X.append('  </TextureDictionary>\n  <Shaders>\n' + ''.join(shaders) + '  </Shaders>\n </ShaderGroup>\n')
    X.append(' <DrawableModelsHigh>\n  <Item>\n   <RenderMask value="255" />\n   <Flags value="0" />\n   <HasSkin value="0" />\n   <BoneIndex value="0" />\n   <Unknown1 value="0" />\n   <Geometries>\n')
    for si, mi in enumerate(order):
        g = geo[mi]
        assert len(g['v']) < 65535, (MODEL, mats[mi]['name'], len(g['v']))
        gmn = [min(v[0][k] for v in g['v']) for k in range(3)]
        gmx = [max(v[0][k] for v in g['v']) for k in range(3)]
        X.append('    <Item>\n     <ShaderIndex value="%d" />\n' % si)
        X.append(xyz('BoundingBoxMin', gmn, '     ', True)); X.append(xyz('BoundingBoxMax', gmx, '     ', True))
        X.append('     <VertexBuffer>\n      <Flags value="0" />\n      <Layout type="GTAV1">\n       <Position />\n       <Normal />\n       <Colour0 />\n       <TexCoord0 />\n      </Layout>\n      <Data2>\n')
        for P, N, T in g['v']:
            X.append('       %s %s %s   %s %s %s   255 255 255 255   %s %s\n' % (f(P[0]), f(P[1]), f(P[2]), f(N[0]), f(N[1]), f(N[2]), f(T[0]), f(T[1])))
        X.append('      </Data2>\n     </VertexBuffer>\n     <IndexBuffer>\n      <Data>\n')
        ii = g['i']
        for k in range(0, len(ii), 24):
            X.append('       ' + ' '.join(str(x) for x in ii[k:k + 24]) + '\n')
        X.append('      </Data>\n     </IndexBuffer>\n    </Item>\n')
    X.append('   </Geometries>\n  </Item>\n </DrawableModelsHigh>\n')
    if COLL:
        X.append(box_bounds(bmin, bmax))
    X.append('</Drawable>\n')
    open(os.path.join(OUT, MODEL + '.ydr.xml'), 'w', encoding='utf-8').write(''.join(X))
    archetypes.append((MODEL, LOD, COLL, bmin, bmax, cen, rad))
    print('%-26s %.2f x %.2f x %.2f m | %d geometri | %d tris | collision %s' % (
        MODEL, bmax[0] - bmin[0], bmax[1] - bmin[1], bmax[2] - bmin[2], len(order),
        sum(len(g['i']) for g in geo.values()) // 3, 'ya' if COLL else 'tidak'))

# ---------- ytyp: semua archetype dalam satu file ----------
# physicsDictionary = nama model hanya untuk yang punya collision (game memakai bound di ydr, lihat f_logokota).
Y = ['<?xml version="1.0" encoding="UTF-8"?>\n<CMapTypes>\n <extensions />\n <archetypes>\n']
for MODEL, LOD, COLL, bmin, bmax, cen, rad in archetypes:
    Y.append('  <Item type="CBaseArchetypeDef">\n   <lodDist value="%d" />\n   <flags value="32" />\n   <specialAttribute value="0" />\n' % LOD)
    Y.append(xyz('bbMin', bmin, '   ') + xyz('bbMax', bmax, '   ') + xyz('bsCentre', cen, '   '))
    Y.append('   <bsRadius value="%s" />\n   <hdTextureDist value="%d" />\n   <name>%s</name>\n   <textureDictionary />\n   <clipDictionary />\n   <drawableDictionary />\n' % (f(rad), LOD, MODEL))
    Y.append('   <physicsDictionary>%s</physicsDictionary>\n' % (MODEL if COLL else ''))
    Y.append('   <assetType>ASSET_TYPE_DRAWABLE</assetType>\n   <assetName>%s</assetName>\n   <extensions />\n  </Item>\n' % MODEL)
Y.append(' </archetypes>\n <name>%s</name>\n <dependencies />\n <compositeEntityTypes itemType="CCompositeEntityType" />\n</CMapTypes>\n' % YTYP)
open(os.path.join(OUT, YTYP + '.ytyp.xml'), 'w', encoding='utf-8').write(''.join(Y))
print('ytyp %s: %d archetype' % (YTYP, len(archetypes)))
