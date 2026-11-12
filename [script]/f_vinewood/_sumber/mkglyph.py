# Buat ydr XML huruf tambahan f_vinewood dari balok, memakai i.ydr.xml sebagai template
# (shader, layout vertex, urutan index). python -I mkglyph.py <i.ydr.xml> <outDir>
import math, re, sys

src, out = sys.argv[1], sys.argv[2]
tpl = open(src, encoding='utf-8').read()
rows = [l.split() for l in re.search(r'<Data2>(.*?)</Data2>', tpl, re.S).group(1).strip().splitlines()]
idx = [int(v) for v in re.search(r'<IndexBuffer>\s*<Data>(.*?)</Data>', tpl, re.S).group(1).split()]
assert len(rows) == 24 and len(idx) == 36

Y0, Y1 = -0.2, 0.0          # tebal huruf (sama seperti huruf lain)
Z0, Z1 = -0.63, 14.70       # tinggi huruf (sama seperti e/h/m/t)

GLYPHS = {
    # angka 4 blok: tiang kanan penuh, palang tengah (setinggi palang H), tiang kiri atas
    'vw_4': [
        (1.09, 4.39, Z0, Z1),
        (-4.39, 4.39, 5.38, 8.68),
        (-4.39, -1.09, 5.38, Z1),
    ],
    # pagar #: 2 tiang + 2 palang, stroke 2.5
    'vw_hash': [
        (-3.60, -1.10, Z0, Z1),
        (1.10, 3.60, Z0, Z1),
        (-5.00, 5.00, 2.60, 5.10),
        (-5.00, 5.00, 8.97, 11.47),
    ],
}

def box_rows(x0, x1, z0, z1):
    res = []
    for r in rows:
        x, y, z = float(r[0]), float(r[1]), float(r[2])
        nx = x1 if x > 0 else x0
        ny = Y1 if y > -0.1 else Y0
        nz = z1 if z > 8.0 else z0
        res.append('       %g %g %g   %s' % (nx, ny, nz, '   '.join([' '.join(r[3:6]), ' '.join(r[6:10]), ' '.join(r[10:12])])))
    return res

def f(v): return ('%.7f' % v).rstrip('0').rstrip('.')

for name, boxes in GLYPHS.items():
    data, ind = [], []
    for k, b in enumerate(boxes):
        data += box_rows(*b)
        ind += [i + 24 * k for i in idx]
    mn = (min(b[0] for b in boxes), Y0, min(b[2] for b in boxes))
    mx = (max(b[1] for b in boxes), Y1, max(b[3] for b in boxes))
    c = [(a + b) / 2 for a, b in zip(mn, mx)]
    rad = math.dist(c, mx)
    x = tpl
    x = re.sub(r'<Name>i</Name>', '<Name>%s</Name>' % name, x, count=1)
    x = re.sub(r'<BoundingSphereCenter [^>]*/>', '<BoundingSphereCenter x="%s" y="%s" z="%s" />' % tuple(map(f, c)), x)
    x = re.sub(r'<BoundingSphereRadius [^>]*/>', '<BoundingSphereRadius value="%s" />' % f(rad), x)
    x = re.sub(r'<BoundingBoxMin x="[^"]*" y="[^"]*" z="[^"]*"', '<BoundingBoxMin x="%s" y="%s" z="%s"' % tuple(map(f, mn)), x)
    x = re.sub(r'<BoundingBoxMax x="[^"]*" y="[^"]*" z="[^"]*"', '<BoundingBoxMax x="%s" y="%s" z="%s"' % tuple(map(f, mx)), x)
    x = re.sub(r'<Data2>.*?</Data2>', '<Data2>\n' + '\n'.join(data) + '\n      </Data2>', x, flags=re.S)
    lines = [' '.join(map(str, ind[i:i + 24])) for i in range(0, len(ind), 24)]
    x = re.sub(r'(<IndexBuffer>\s*<Data>).*?(</Data>)', lambda m: m.group(1) + '\n       ' + '\n       '.join(lines) + '\n      ' + m.group(2), x, flags=re.S)
    open('%s/%s.ydr.xml' % (out, name), 'w', encoding='utf-8').write(x)
    print(name, 'boxes', len(boxes), 'bb', mn, mx, 'r', round(rad, 3))
