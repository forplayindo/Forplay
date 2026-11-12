import re, sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding='utf-8').read()
first = re.search(r'  <Item type="CBaseArchetypeDef">.*?</Item>\n', t, re.S).group(0)
GL = {'vw_4': ((-4.39, -0.2, -0.63), (4.39, 0.0, 14.7)), 'vw_hash': ((-5.0, -0.2, -0.63), (5.0, 0.0, 14.7))}
add = ''
for name, (mn, mx) in GL.items():
    assert name not in t
    c = [(a + b) / 2 for a, b in zip(mn, mx)]
    r = sum((b - a) ** 2 for a, b in zip(c, mx)) ** 0.5
    it = first
    it = re.sub(r'<bbMin [^>]*/>', '<bbMin x="%g" y="%g" z="%g" />' % mn, it)
    it = re.sub(r'<bbMax [^>]*/>', '<bbMax x="%g" y="%g" z="%g" />' % mx, it)
    it = re.sub(r'<bsCentre [^>]*/>', '<bsCentre x="%g" y="%g" z="%g" />' % tuple(c), it)
    it = re.sub(r'<bsRadius [^>]*/>', '<bsRadius value="%.5f" />' % r, it)
    it = re.sub(r'<name>[^<]*</name>', '<name>%s</name>' % name, it)
    it = re.sub(r'<assetName>[^<]*</assetName>', '<assetName>%s</assetName>' % name, it)
    add += it
t = t.replace(' </archetypes>', add + ' </archetypes>', 1)
open(dst, 'w', encoding='utf-8').write(t)
print('ok', t.count('CBaseArchetypeDef'))
