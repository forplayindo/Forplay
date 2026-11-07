"""Kartu anggur vanilla (ch1_*_vinegrapes_*) -> titik petik f_wine.
python -I cards.py <folder vine> <out json>"""
import sys, os, re, json, math, random

D = sys.argv[1]
OUT = sys.argv[2]
BLOK = {'ch1_09b': 'merah', 'ch1_05': 'putih', 'ch1_04b': 'rose'}

def cards_of(fn):
    s = open(fn, encoding='utf-8').read()
    V, I = [], []
    for gm in re.finditer(r'<VertexBuffer>.*?<Data2?>(.*?)</Data2?>.*?<IndexBuffer>\s*<Data>(.*?)</Data>', s, re.S):
        base = len(V)
        for l in gm.group(1).strip().splitlines():
            p = l.split()
            V.append((float(p[0]), float(p[1]), float(p[2]), float(p[3]), float(p[4])))
        I += [base + int(x) for x in gm.group(2).split()]
    # union-find per posisi (dibulatkan) supaya muka depan/belakang menyatu
    key = [(round(v[0], 3), round(v[1], 3), round(v[2], 3)) for v in V]
    par = {}
    def f(a):
        while par.setdefault(a, a) != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for k in range(0, len(I), 3):
        a, b, c = (key[i] for i in I[k:k + 3])
        ra, rb, rc = f(a), f(b), f(c)
        par[rb] = ra; par[f(rc)] = ra
    grp = {}
    for i, k in enumerate(key):
        grp.setdefault(f(k), set()).add(i)
    out = []
    for g in grp.values():
        pts = [V[i] for i in g]
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]; zs = [p[2] for p in pts]
        nx = sum(abs(p[3]) for p in pts) / len(pts); ny = sum(p[4] for p in pts) / len(pts)
        n0 = max(pts, key=lambda p: abs(p[3]) + abs(p[4]))
        out.append({'x': sum(xs) / len(xs), 'y': sum(ys) / len(ys), 'top': max(zs), 'bot': min(zs), 'nx': n0[3], 'ny': n0[4]})
    return out

cache = {}
rows = []
for l in open(os.path.join(D, 'rows.txt'), encoding='utf-8-sig'):
    p = l.strip().split('|')
    if len(p) < 5: continue
    arch = p[1].lower()
    x, y, z = float(p[2]), float(p[3]), float(p[4])
    if arch not in cache:
        cache[arch] = cards_of(os.path.join(D, 'xml', arch + '.ydr.xml'))
    blk = next(v for k, v in BLOK.items() if arch.startswith(k + '_'))
    rows.append({'arch': arch, 'blok': blk, 'pos': (x, y, z),
                 'cards': [{'x': c['x'] + x, 'y': c['y'] + y, 'top': c['top'] + z, 'bot': c['bot'] + z, 'nx': c['nx'], 'ny': c['ny']} for c in cache[arch]]})

# gabung entity di posisi sama (04b punya 2 model per posisi)
merged = {}
for r in rows:
    k = (round(r['pos'][0]), round(r['pos'][1]))
    if k in merged:
        merged[k]['cards'] += r['cards']
    else:
        merged[k] = r
rows = list(merged.values())
allc = [c for r in rows for c in r['cards']]
print('rows', len(rows), 'cards', len(allc), 'per blok', {b: sum(1 for r in rows if r['blok'] == b) for b in BLOK.values()})
h = sorted(c['top'] - c['bot'] for c in allc); print('card height median', round(h[len(h) // 2], 2))

rnd = random.Random(4)
spots = []
for r in rows:
    cs = r['cards']
    if len(cs) < 3: continue
    mx = sum(c['x'] for c in cs) / len(cs); my = sum(c['y'] for c in cs) / len(cs)
    # titik di tengah baris (kartu terdekat ke rata-rata), lalu 3-5 kartu terdekat dalam 1,6 m, jarak antar tandan >= 0,3 m
    cs = sorted(cs, key=lambda c: (c['x'] - mx) ** 2 + (c['y'] - my) ** 2)
    a = cs[0]
    near = sorted(cs, key=lambda c: (c['x'] - a['x']) ** 2 + (c['y'] - a['y']) ** 2)
    pick = []
    want = rnd.randint(3, 5)
    for c in near:
        d = math.hypot(c['x'] - a['x'], c['y'] - a['y'])
        if d > 1.6: break
        if all(math.hypot(c['x'] - q['x'], c['y'] - q['y']) >= 0.3 for q in pick):
            pick.append(c)
        if len(pick) >= want: break
    if len(pick) < 3: continue
    t = []
    for c in pick:
        t.append([round(c['x'], 2), round(c['y'], 2), round(c['top'] - 0.04, 2), round(rnd.uniform(0, 360))])
    cx = sum(q[0] for q in t) / len(t); cy = sum(q[1] for q in t) / len(t); cz = sum(q[2] for q in t) / len(t)
    spots.append({'b': r['blok'], 'c': [round(cx, 2), round(cy, 2), round(cz, 2)], 't': t})

print('spots', len(spots), {b: sum(1 for s in spots if s['b'] == b) for b in BLOK.values()},
      'tandan', sum(len(s['t']) for s in spots))

# pos injak: titik bebas kartu (>= 3,5 m) paling dekat winery, di pinggir tiap blok
WINERY = (-1887.0, 2049.0)
pos = {}
for b in BLOK.values():
    bc = [c for r in rows if r['blok'] == b for c in r['cards']]
    best = None
    rr = [r for r in rows if r['blok'] == b]
    rr.sort(key=lambda r: math.hypot(r['pos'][0] - WINERY[0], r['pos'][1] - WINERY[1]))
    for r in rr[:6]:
        for ang in range(0, 360, 15):
            for rad in (5, 7, 9, 11):
                x = r['pos'][0] + rad * math.cos(math.radians(ang)); y = r['pos'][1] + rad * math.sin(math.radians(ang))
                dmin = min(math.hypot(c['x'] - x, c['y'] - y) for c in allc)
                if dmin < 3.5: continue
                near = sorted(bc, key=lambda c: math.hypot(c['x'] - x, c['y'] - y))[:4]
                dn = math.hypot(near[0]['x'] - x, near[0]['y'] - y)
                if dn > 9: continue
                z = min(c['bot'] for c in near) - 0.35
                score = math.hypot(x - WINERY[0], y - WINERY[1]) + dn * 2
                if not best or score < best[0]: best = (score, x, y, z)
    pos[b] = [round(best[1], 2), round(best[2], 2), round(best[3], 2)]
print('pos injak', pos)
bot = sorted(c['bot'] for c in allc)
json.dump({'spots': spots, 'pos': pos}, open(OUT, 'w'), indent=0)
