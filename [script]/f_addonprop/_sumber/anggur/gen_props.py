"""Prop f_wine dibuat prosedural (tanpa Blender): tandan anggur 3 warna + tong injak 3 warna jus.
python gen_props.py <folder_build>
Hasil per model: <build>/<model>.glb (+ <model>_buah.dds / _kayu.dds untuk build_prop.py).
Lanjut: python ../../_tools/build_prop.py <build>/<model>.glb <build> <model> box <lod>
        powershell -File ../../_tools/cw.ps1 import <build>/<model>.ydr.xml ../../stream/anggur/<model>.ydr  (juga .ytyp)

Bentuk tandan = mockup yang disetujui (artifact 'Mockup Tandan Anggur'): panjang 22 cm + tangkai 7 cm,
pivot = ujung atas tangkai (titik gantung), buah ~1,9 cm, low-poly 8x5 per buah.
Koordinat ditulis dalam sumbu GTA (Z ke atas) lalu diubah ke glTF (x, z, -y) - build_prop.py mengubahnya balik.
"""
import sys, os, math, struct, json, random, colorsys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build')
os.makedirs(OUT, exist_ok=True)

# ----------------------------------------------------------------- util
def norm(v):
    l = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / l for c in v)

def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])

def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def add(a, b): return tuple(x + y for x, y in zip(a, b))
def mul(a, s): return tuple(x * s for x in a)


class Prim:
    def __init__(self):
        self.p, self.n, self.t, self.i = [], [], [], []

    def v(self, p, n, uv):
        self.p.append(p); self.n.append(norm(n)); self.t.append(uv)
        return len(self.p) - 1

    def tri(self, a, b, c):
        self.i += [a, b, c]


def sphere(pr, c, r, sz, uv, lon=8, lat=5, rot=0.0):
    base = len(pr.p)
    for i in range(lat + 1):
        th = math.pi * i / lat
        for j in range(lon):
            ph = 2 * math.pi * j / lon + rot
            d = (math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th))
            pr.v(add(c, (d[0] * r, d[1] * r, d[2] * r * sz)), (d[0], d[1], d[2] / sz), uv)
    for i in range(lat):
        for j in range(lon):
            a = base + i * lon + j; b = base + i * lon + (j + 1) % lon
            cc = base + (i + 1) * lon + j; d = base + (i + 1) * lon + (j + 1) % lon
            if i > 0: pr.tri(a, cc, b)
            if i < lat - 1: pr.tri(b, cc, d)


def tube(pr, pts, radius, sides, uv, r_end=None):
    """Pipa sepanjang titik pts (GTA). r_end = jari-jari ujung (mengecil)."""
    base = len(pr.p)
    n = len(pts)
    prevN = None
    for k, p in enumerate(pts):
        T = norm(sub(pts[min(k + 1, n - 1)], pts[max(k - 1, 0)]))
        ref = prevN or ((0, 0, 1) if abs(T[2]) < 0.9 else (1, 0, 0))
        B = norm(cross(T, ref)); N = norm(cross(B, T)); prevN = N
        r = radius if r_end is None else radius + (r_end - radius) * k / (n - 1)
        for j in range(sides):
            a = 2 * math.pi * j / sides
            d = add(mul(N, math.cos(a)), mul(B, math.sin(a)))
            pr.v(add(p, mul(d, r)), d, uv)
    for k in range(n - 1):
        for j in range(sides):
            a = base + k * sides + j; b = base + k * sides + (j + 1) % sides
            c = base + (k + 1) * sides + j; d = base + (k + 1) * sides + (j + 1) % sides
            pr.tri(a, b, c); pr.tri(b, d, c)


def catmull(ctrl, steps):
    out = []
    P = [ctrl[0]] + ctrl + [ctrl[-1]]
    for s in range(len(ctrl) - 1):
        p0, p1, p2, p3 = P[s], P[s + 1], P[s + 2], P[s + 3]
        for k in range(steps):
            t = k / steps
            out.append(tuple(0.5 * ((2 * p1[i]) + (-p0[i] + p2[i]) * t + (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * t * t
                                    + (-p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]) * t ** 3) for i in range(3)))
    out.append(ctrl[-1])
    return out

# ----------------------------------------------------------------- tekstur
def write_dds(path, w, h, px):
    """px = list baris RGBA sRGB 0-255; A8R8G8B8 tanpa mipmap (dibaca build_prop.dds_info)."""
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, 0x100F, h, w, w * 4, 0, 1) + b'\0' * 44
    hdr += struct.pack('<IIIIIIII', 32, 0x41, 0, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
    hdr += struct.pack('<IIIII', 0x1000, 0, 0, 0, 0)
    data = bytearray()
    for row in px:
        for r, g, b, a in row: data += bytes((b, g, r, a))
    open(path, 'wb').write(hdr + bytes(data))


PALET = {  # warna buah (HSL, sRGB) + sebaran
    'ungu':  (0.80, 0.42, 0.20, 0.035, 0.05),
    'hijau': (0.20, 0.48, 0.47, 0.025, 0.06),
    'merah': (0.975, 0.58, 0.29, 0.025, 0.06),
}

def palette_px(key, seed):
    """8x8: 16 warna buah dalam blok 2x2."""
    h, s, l, dh, dl = PALET[key]
    rnd = random.Random(seed)
    cols = []
    for _ in range(16):
        r, g, b = colorsys.hls_to_rgb((h + rnd.uniform(-dh, dh)) % 1, l + rnd.uniform(-dl, dl), min(1, s * rnd.uniform(0.85, 1.15)))
        cols.append((int(r * 255), int(g * 255), int(b * 255), 255))
    return [[cols[(y // 2) * 4 + (x // 2)] for x in range(8)] for y in range(8)]

def palette_uv(k):
    k %= 16
    return ((2 * (k % 4) + 1) / 8, (2 * (k // 4) + 1) / 8)

def wood_px(size=64, planks=14, seed=3):
    rnd = random.Random(seed)
    tone = [rnd.uniform(0.85, 1.12) for _ in range(planks)]
    px = []
    for y in range(size):
        row = []
        for x in range(size):
            pl = x * planks // size
            seam = (x * planks) % size < planks  # garis gelap antar papan
            grain = 0.92 + 0.08 * math.sin(y * 0.55 + pl * 1.7 + math.sin(x * 0.9) * 0.6)
            f = tone[pl] * grain * (0.55 if seam else 1.0)
            row.append((min(255, int(118 * f)), min(255, int(80 * f)), min(255, int(50 * f)), 255))
        px.append(row)
    return px

# ----------------------------------------------------------------- glb
def write_glb(path, name, prims):
    """prims = [(nama_material, Prim, material_dict)]"""
    buf = bytearray(); views = []; accs = []; mats = []; prim_js = []

    def view(data, target):
        while len(buf) % 4: buf.append(0)
        views.append({'buffer': 0, 'byteOffset': len(buf), 'byteLength': len(data), 'target': target})
        buf.extend(data)
        return len(views) - 1

    def g(p): return (p[0], p[2], -p[1])  # GTA -> glTF

    for mname, pr, mat in prims:
        P = [g(p) for p in pr.p]; N = [g(n) for n in pr.n]
        vp = view(b''.join(struct.pack('<3f', *p) for p in P), 34962)
        accs.append({'bufferView': vp, 'componentType': 5126, 'count': len(P), 'type': 'VEC3',
                     'min': [min(p[k] for p in P) for k in range(3)], 'max': [max(p[k] for p in P) for k in range(3)]})
        ap = len(accs) - 1
        vn = view(b''.join(struct.pack('<3f', *n) for n in N), 34962)
        accs.append({'bufferView': vn, 'componentType': 5126, 'count': len(N), 'type': 'VEC3'}); an = len(accs) - 1
        vt = view(b''.join(struct.pack('<2f', *t) for t in pr.t), 34962)
        accs.append({'bufferView': vt, 'componentType': 5126, 'count': len(pr.t), 'type': 'VEC2'}); at = len(accs) - 1
        assert len(P) < 65535
        vi = view(b''.join(struct.pack('<H', i) for i in pr.i), 34963)
        accs.append({'bufferView': vi, 'componentType': 5123, 'count': len(pr.i), 'type': 'SCALAR'}); ai = len(accs) - 1
        mats.append(dict(mat, name=mname))
        prim_js.append({'attributes': {'POSITION': ap, 'NORMAL': an, 'TEXCOORD_0': at}, 'indices': ai, 'material': len(mats) - 1})
    while len(buf) % 4: buf.append(0)
    js = {'asset': {'version': '2.0', 'generator': 'f_addonprop/_sumber/anggur/gen_props.py'},
          'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': name}],
          'meshes': [{'name': name, 'primitives': prim_js}], 'materials': mats,
          'buffers': [{'byteLength': len(buf)}], 'bufferViews': views, 'accessors': accs}
    if any('baseColorTexture' in m.get('pbrMetallicRoughness', {}) for m in mats):
        js['images'] = [{'uri': name + '.dds'}]; js['textures'] = [{'source': 0}]
    j = json.dumps(js, separators=(',', ':')).encode()
    while len(j) % 4: j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(buf))
    out += struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(buf), 0x004E4942) + bytes(buf)
    open(path, 'wb').write(out)
    tris = sum(len(p.i) for _, p, _ in prims) // 3
    print('%-22s verts %5d  tris %5d' % (name, sum(len(p.p) for _, p, _ in prims), tris))

TEX = {'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0, 'roughnessFactor': 0.6}}
def solid(rgb_lin): return {'pbrMetallicRoughness': {'baseColorFactor': list(rgb_lin) + [1], 'metallicFactor': 0, 'roughnessFactor': 0.8}}

# ----------------------------------------------------------------- tandan anggur
L, BR, TOP = 0.22, 0.0095, -0.07   # panjang tandan, jari-jari buah, awal tandan di bawah titik gantung

def radius_at(t):
    top = 0.42 + 0.58 * (lambda x: x * x * (3 - 2 * x))(min(1, t / 0.16)) if t < 0.16 else (1 - (t - 0.16) / 0.84) ** 0.95
    return 0.06 * top + 0.008

def bunch(model, key, seed, density=80):
    rnd = random.Random(seed)
    def axis(t):
        return (math.sin(t * 3.1 + seed) * 0.008, math.cos(t * 2.3 + seed) * 0.006, TOP - t * L)
    berries = []
    tries = 0
    while len(berries) < density and tries < 12000:
        tries += 1
        t = rnd.random(); rt = radius_at(t)
        if rnd.random() > (rt / 0.068) ** 1.6: continue
        a = rnd.random() * 2 * math.pi
        rad = rt * (0.5 + 0.5 * math.sqrt(rnd.random()))
        c = axis(t)
        r = BR * rnd.uniform(0.86, 1.1)
        p = (c[0] + math.cos(a) * rad, c[1] + math.sin(a) * rad, c[2] + rnd.uniform(-0.005, 0.005))
        if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 + (p[2] - q[2]) ** 2 >= ((r + qr) * 0.9) ** 2 for q, qr in berries):
            berries.append((p, r))
    buah = Prim()
    for k, (p, r) in enumerate(berries):
        sphere(buah, p, r, 1.1, palette_uv(k), lon=7, lat=4, rot=rnd.random())
    tangkai = Prim()
    tube(tangkai, catmull([axis(t) for t in (0, 0.3, 0.6, 0.95)], 4), 0.0024, 5, (0.5, 0.5), r_end=0.0012)
    tube(tangkai, catmull([(0.036 * 0.15, -0.012 * 0.15, 0.0), (0.016, -0.004, -0.02), (0.004, 0.002, -0.05), axis(0)], 4), 0.0045, 6, (0.5, 0.5))
    write_dds(os.path.join(OUT, model + '_buah.dds'), 8, 8, palette_px(key, seed))
    write_glb(os.path.join(OUT, model + '.glb'), model, [('buah', buah, TEX), ('tangkai', tangkai, solid((0.12, 0.1, 0.035)))])
    return len(berries)

# ----------------------------------------------------------------- tong injak (kayu terbuka, berisi jus + anggur terinjak)
JUS = {'merah': (0.05, 0.004, 0.02), 'putih': (0.55, 0.48, 0.12), 'rose': (0.5, 0.07, 0.15)}
BUAH_TONG = {'merah': 'ungu', 'putih': 'hijau', 'rose': 'merah'}
R_BOT, R_TOP, H, WALL, JUS_Z, SEG = 0.50, 0.56, 0.62, 0.035, 0.40, 28

def ring_r(z): return R_BOT + (R_TOP - R_BOT) * z / H

def tong(model, jenis, seed):
    rnd = random.Random(seed)
    kayu = Prim()
    # dinding luar, dalam, bibir atas, alas bawah; u = keliling (papan), v = tinggi
    for side in ('luar', 'dalam'):
        base = len(kayu.p)
        for zi, z in enumerate((0.0, H)):
            for j in range(SEG + 1):
                a = 2 * math.pi * j / SEG
                r = ring_r(z) - (WALL if side == 'dalam' else 0)
                n = (math.cos(a), math.sin(a), 0) if side == 'luar' else (-math.cos(a), -math.sin(a), 0)
                kayu.v((math.cos(a) * r, math.sin(a) * r, z), n, (j / SEG * 2, 1 - z / H))
        for j in range(SEG):
            a, b, c, d = base + j, base + j + 1, base + SEG + 1 + j, base + SEG + 2 + j
            if side == 'luar': kayu.tri(a, b, c); kayu.tri(b, d, c)
            else: kayu.tri(a, c, b); kayu.tri(b, c, d)
    base = len(kayu.p)
    for j in range(SEG + 1):
        a = 2 * math.pi * j / SEG
        for r in (ring_r(H), ring_r(H) - WALL):
            kayu.v((math.cos(a) * r, math.sin(a) * r, H), (0, 0, 1), (j / SEG * 2, 0.02))
    for j in range(SEG):
        a, b, c, d = base + 2 * j, base + 2 * j + 2, base + 2 * j + 1, base + 2 * j + 3
        kayu.tri(a, b, c); kayu.tri(b, d, c)
    cb = kayu.v((0, 0, 0), (0, 0, -1), (0.5, 0.5)); base = len(kayu.p)
    for j in range(SEG):
        a = 2 * math.pi * j / SEG
        kayu.v((math.cos(a) * R_BOT, math.sin(a) * R_BOT, 0), (0, 0, -1), (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)))
    for j in range(SEG): kayu.tri(cb, base + (j + 1) % SEG, base + j)
    # ring besi
    besi = Prim()
    for zc in (0.11, H - 0.12):
        base = len(besi.p)
        for zi, z in enumerate((zc - 0.022, zc + 0.022)):
            for j in range(SEG):
                a = 2 * math.pi * j / SEG; r = ring_r(z) + 0.006
                besi.v((math.cos(a) * r, math.sin(a) * r, z), (math.cos(a), math.sin(a), 0), (0.5, 0.5))
        for j in range(SEG):
            a, b, c, d = base + j, base + (j + 1) % SEG, base + SEG + j, base + SEG + (j + 1) % SEG
            besi.tri(a, b, c); besi.tri(b, d, c)
    # permukaan jus
    jus = Prim(); rj = ring_r(JUS_Z) - WALL
    cj = jus.v((0, 0, JUS_Z), (0, 0, 1), (0.5, 0.5)); base = len(jus.p)
    for j in range(SEG):
        a = 2 * math.pi * j / SEG
        jus.v((math.cos(a) * rj, math.sin(a) * rj, JUS_Z), (0, 0, 1), (0.5, 0.5))
    for j in range(SEG): jus.tri(cj, base + j, base + (j + 1) % SEG)
    # anggur terinjak mengapung (setengah tenggelam)
    buah = Prim()
    for k in range(46):
        a = rnd.random() * 2 * math.pi; d = math.sqrt(rnd.random()) * (rj - 0.03)
        r = BR * rnd.uniform(0.95, 1.2)
        sphere(buah, (math.cos(a) * d, math.sin(a) * d, JUS_Z + r * rnd.uniform(0.25, 0.45)), r,
               rnd.uniform(0.75, 0.95), palette_uv(k), lon=7, lat=4)
    write_dds(os.path.join(OUT, model + '_kayu.dds'), 64, 64, wood_px(seed=seed))
    write_dds(os.path.join(OUT, model + '_buah.dds'), 8, 8, palette_px(BUAH_TONG[jenis], seed))
    write_glb(os.path.join(OUT, model + '.glb'), model, [
        ('kayu', kayu, TEX), ('besi', besi, solid((0.03, 0.03, 0.03))),
        ('jus', jus, solid(JUS[jenis])), ('buah', buah, TEX)])

# kayu & buah tong memakai tekstur berbeda -> material bertekstur harus punya nama file sendiri.
# build_prop mencari <model>_<material>.dds, jadi 'kayu' dan 'buah' sudah terpisah.

# ----------------------------------------------------------------- keranjang anyaman panen
KB_BOT, KB_TOP, KB_H, KB_WALL, KB_SEG = (0.21, 0.14), (0.25, 0.18), 0.26, 0.018, 32

def oval(a, b, t, e=3.0):
    """titik superellips (sudut membulat) pada sudut t."""
    c, s = math.cos(t), math.sin(t)
    return (a * math.copysign(abs(c) ** (2 / e), c), b * math.copysign(abs(s) ** (2 / e), s))

def weave_px(size=64, seed=9):
    rnd = random.Random(seed)
    px = []
    for y in range(size):
        row = []
        for x in range(size):
            over = ((x // 8) + (y // 4)) % 2 == 0           # anyaman: pita tegak / mendatar bergantian
            edge = (x % 8 in (0, 7)) if over else (y % 4 in (0, 3))
            f = (1.0 if over else 0.82) * (0.7 if edge else 1.0) * rnd.uniform(0.95, 1.05)
            row.append((min(255, int(196 * f)), min(255, int(150 * f)), min(255, int(92 * f)), 255))
        px.append(row)
    return px

def keranjang(model):
    k = Prim()
    def ring(z, inset):
        a = KB_BOT[0] + (KB_TOP[0] - KB_BOT[0]) * z / KB_H - inset
        b = KB_BOT[1] + (KB_TOP[1] - KB_BOT[1]) * z / KB_H - inset
        return [oval(a, b, 2 * math.pi * j / KB_SEG) for j in range(KB_SEG + 1)]
    for side, inset in (('luar', 0.0), ('dalam', KB_WALL)):
        base = len(k.p)
        for z in (0.0, KB_H):
            for j, (x, y) in enumerate(ring(z, inset)):
                n = norm((x, y, 0)) if side == 'luar' else norm((-x, -y, 0))
                k.v((x, y, z), n, (j / KB_SEG * 6, z / KB_H * 2))
        for j in range(KB_SEG):
            a, b, c, d = base + j, base + j + 1, base + KB_SEG + 1 + j, base + KB_SEG + 2 + j
            if side == 'luar': k.tri(a, b, c); k.tri(b, d, c)
            else: k.tri(a, c, b); k.tri(b, c, d)
    # alas (atas + bawah)
    for z, up in ((0.0, False), (0.012, True)):
        c0 = k.v((0, 0, z), (0, 0, 1 if up else -1), (0.5, 0.5)); base = len(k.p)
        for j, (x, y) in enumerate(ring(0.0, KB_WALL if up else 0.0)[:-1]):
            k.v((x, y, z), (0, 0, 1 if up else -1), (0.5 + x * 2, 0.5 + y * 2))
        for j in range(KB_SEG):
            a, b = base + j, base + (j + 1) % KB_SEG
            k.tri(c0, a, b) if up else k.tri(c0, b, a)
    tepi = Prim()
    # bibir atas tebal + 2 pegangan di sisi pendek
    rim = [(x, y, KB_H) for x, y in ring(KB_H, KB_WALL / 2)]
    tube(tepi, rim, 0.014, 6, (0.5, 0.5))
    for sx in (-1, 1):
        x0 = sx * (KB_TOP[0] - KB_WALL / 2)
        tube(tepi, catmull([(x0, -0.07, KB_H - 0.01), (x0 + sx * 0.035, -0.05, KB_H + 0.02), (x0 + sx * 0.045, 0, KB_H + 0.03),
                            (x0 + sx * 0.035, 0.05, KB_H + 0.02), (x0, 0.07, KB_H - 0.01)], 4), 0.011, 6, (0.5, 0.5))
    write_dds(os.path.join(OUT, model + '_anyaman.dds'), 64, 64, weave_px())
    write_glb(os.path.join(OUT, model + '.glb'), model, [('anyaman', k, TEX), ('tepi', tepi, solid((0.22, 0.12, 0.05)))])

if __name__ == '__main__':
    keranjang('f_wine_keranjang')
    for model, key, seed in (('f_anggur_ungu', 'ungu', 11), ('f_anggur_hijau', 'hijau', 23), ('f_anggur_merah', 'merah', 37)):
        n = bunch(model, key, seed)
        print('   buah', n)
    for jenis, seed in (('merah', 5), ('putih', 6), ('rose', 7)):
        tong('f_wine_tong_' + jenis, jenis, seed)
