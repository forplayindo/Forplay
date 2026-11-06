# Buat ymap 1 prop dari template.ymap (tanpa CodeWalker).
# python mkymap.py <out.ymap> <archetype> <x> <y> <z> [heading] [lodDist] [bbmin_x,y,z] [bbmax_x,y,z]
# z = titik pivot model (biasanya tengah model untuk prop custom).
import sys, os, zlib, struct, math

def jenk(s):
    h = 0
    for c in s.lower().encode():
        h = (h + c) & 0xffffffff; h = (h + (h << 10)) & 0xffffffff; h ^= h >> 6
    h = (h + (h << 3)) & 0xffffffff; h ^= h >> 11; h = (h + (h << 15)) & 0xffffffff
    return h

CMAPDATA, CENTITYDEF, STRING = 0xd3593fa6, 0xce501483, 0x10

out, arch = sys.argv[1], sys.argv[2]
x, y, z = map(float, sys.argv[3:6])
heading = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0
lod = float(sys.argv[7]) if len(sys.argv) > 7 else 300.0
bbmin = list(map(float, sys.argv[8].split(','))) if len(sys.argv) > 8 else [-2, -2, -2]
bbmax = list(map(float, sys.argv[9].split(','))) if len(sys.argv) > 9 else [2, 2, 2]

src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'template.ymap'), 'rb').read()
hdr = src[:16]
raw = bytearray(zlib.decompress(src[16:], -15))

dbp, = struct.unpack_from('<Q', raw, 0x30)
dbc, = struct.unpack_from('<h', raw, 0x4C)
blocks = {}
for i in range(dbc):
    h, l, p = struct.unpack_from('<IiQ', raw, (dbp & 0xfffffff) + 16 * i)
    blocks[h] = ((p & 0xfffffff), l)

# rotasi heading -> radius XY pakai bounding box terputar
a = math.radians(heading)
c, s = abs(math.cos(a)), abs(math.sin(a))
hx, hy = (bbmax[0] - bbmin[0]) / 2, (bbmax[1] - bbmin[1]) / 2
cx, cy = (bbmax[0] + bbmin[0]) / 2, (bbmax[1] + bbmin[1]) / 2
ex, ey = hx * c + hy * s, hx * s + hy * c
emin = (x + cx - ex, y + cy - ey, z + bbmin[2])
emax = (x + cx + ex, y + cy + ey, z + bbmax[2])

name = os.path.splitext(os.path.basename(out))[0]
m, _ = blocks[CMAPDATA]
struct.pack_into('<IIII', raw, m + 8, jenk(name), 0, 0, 1)
struct.pack_into('<4f', raw, m + 0x20, emin[0] - lod, emin[1] - lod, emin[2] - lod, 0)
struct.pack_into('<4f', raw, m + 0x30, emax[0] + lod, emax[1] + lod, emax[2] + lod, 0)
struct.pack_into('<4f', raw, m + 0x40, *emin, 0)
struct.pack_into('<4f', raw, m + 0x50, *emax, 0)

e, _ = blocks[CENTITYDEF]
struct.pack_into('<III', raw, e + 8, jenk(arch), 0x20, jenk(name))
struct.pack_into('<4f', raw, e + 0x20, x, y, z, 0)
# ymap menyimpan quaternion terbalik (konvensi CodeWalker)
struct.pack_into('<4f', raw, e + 0x30, 0, 0, -math.sin(a / 2), math.cos(a / 2))
struct.pack_into('<ffiff', raw, e + 0x40, 1, 1, -1, lod, 0)

# nama di CBlockDesc (kosmetik), muat di slot 24 byte pertama
so, _ = blocks[STRING]
nm = name.encode()[:23]
raw[so:so + 24] = nm + b'\0' * (24 - len(nm))
struct.pack_into('<HH', raw, m + 0x1c8, len(nm), len(nm))

co = zlib.compressobj(9, zlib.DEFLATED, -15)
open(out, 'wb').write(hdr + co.compress(bytes(raw)) + co.flush())
print('ok', out, 'pos', (x, y, z), 'heading', heading, 'extents', emin, emax)
