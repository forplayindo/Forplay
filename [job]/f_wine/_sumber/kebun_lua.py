"""kebun.json (hasil cards.py) -> ../config/kebun.lua
python -I kebun_lua.py kebun.json ../config/kebun.lua"""
import sys, json

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
L = ['-- DIBUAT OTOMATIS oleh _sumber/kebun_lua.py dari kartu anggur vanilla (ch1_*_vinegrapes_*), jangan diedit manual.',
     '-- j = jenis wine per blok: merah = ch1_09b (sekitar winery), putih = ch1_05 (tenggara), rose = ch1_04b (lereng utara).',
     '-- c = tengah titik petik, t = tandan { x, y, z = titik gantung (atas kartu anggur vanilla), heading }.',
     'return {']
for s in d['spots']:
    t = ', '.join('vec4(%.2f, %.2f, %.2f, %d)' % tuple(q) for q in s['t'])
    L.append("    { j = '%s', c = vec3(%.2f, %.2f, %.2f), t = { %s } }," % (s['b'], *s['c'], t))
L.append('}')
open(dst, 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
print('ok', len(d['spots']), 'titik ->', dst)
print('pos injak (perkiraan):', d['pos'])
