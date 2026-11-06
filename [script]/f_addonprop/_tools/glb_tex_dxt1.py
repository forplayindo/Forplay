# Blender (headless): ambil tekstur base color tiap material dari glb -> DDS DXT1 + mipmap (ringan, 0.5 byte/pixel).
# blender -b --factory-startup --python glb_tex_dxt1.py -- <in.glb> <out_dir> <prefix> [max_size=512]
# Hasil: <out_dir>/<prefix>_<material>.dds, dipakai build_prop.py (prefix = nama model).
# Beda dengan prep_blender.py: tidak ada decimate, dan yang diambil pasti baseColorTexture (bukan bump/metallic).
import bpy, sys, os, struct, json, math, tempfile
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
src, outdir, prefix = argv[:3]
MAX = int(argv[3]) if len(argv) > 3 else 512
os.makedirs(outdir, exist_ok=True)

d = open(src, 'rb').read()
jl = struct.unpack_from('<I', d, 12)[0]; j = json.loads(d[20:20 + jl])
o = 20 + jl; b = d[o + 8:]

def pow2(n):
    return 1 << max(2, int(round(math.log2(n))))

def load_rgb(img_index):
    im = j['images'][img_index]; bv = j['bufferViews'][im['bufferView']]
    s = bv.get('byteOffset', 0)
    tmp = os.path.join(tempfile.gettempdir(), 'glbtex_%d.png' % img_index)
    open(tmp, 'wb').write(b[s:s + bv['byteLength']])
    img = bpy.data.images.load(tmp)
    w, h = img.size
    tw = min(MAX, pow2(w)); th = max(4, min(MAX, pow2(h * tw / w)))
    img.scale(tw, th)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(th, tw, 4)[::-1, :, :3]  # Blender: baris bawah dulu
    bpy.data.images.remove(img)
    os.remove(tmp)
    return px * 255.0

def to565(c):
    c = np.clip(np.rint(c), 0, 255).astype(np.uint32)
    return ((c[..., 0] >> 3) << 11) | ((c[..., 1] >> 2) << 5) | (c[..., 2] >> 3)

def from565(v):
    r = (v >> 11) & 31; g = (v >> 5) & 63; bl = v & 31
    return np.stack([(r << 3) | (r >> 2), (g << 2) | (g >> 4), (bl << 3) | (bl >> 2)], -1).astype(np.float32)

def dxt1(px):
    h, w = px.shape[:2]
    blk = px.reshape(h // 4, 4, w // 4, 4, 3).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 3)
    hi, lo = blk.max(1), blk.min(1)
    inset = (hi - lo) / 16
    c0, c1 = to565(hi - inset), to565(lo + inset)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    p0, p1 = from565(c0), from565(c1)
    pal = np.stack([p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3], 1)  # (n, 4, 3)
    dist = ((blk[:, :, None, :] - pal[:, None, :, :]) ** 2).sum(-1)  # (n, 16, 4)
    idx = dist.argmin(-1).astype(np.uint32)
    idx[c0 == c1] = 0
    bits = (idx << (2 * np.arange(16, dtype=np.uint32))).sum(1).astype(np.uint32)
    out = np.zeros(len(blk), dtype=[('c0', '<u2'), ('c1', '<u2'), ('i', '<u4')])
    out['c0'], out['c1'], out['i'] = c0, c1, bits
    return out.tobytes()

def write_dds(path, px):
    h, w = px.shape[:2]
    levels = [px]
    while min(levels[-1].shape[:2]) > 4:
        a = levels[-1]
        levels.append((a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4)
    data = b''.join(dxt1(l) for l in levels)
    hdr = struct.pack('<4sIIIIIII', b'DDS ', 124, 0xA1007, h, w, (w // 4) * (h // 4) * 8, 0, len(levels)) + b'\0' * 44
    hdr += struct.pack('<II4sIIIII', 32, 0x4, b'DXT1', 0, 0, 0, 0, 0) + struct.pack('<IIIII', 0x401008, 0, 0, 0, 0)
    open(path, 'wb').write(hdr + data)
    print('DDS %-40s %dx%d mips %d %d KB' % (os.path.basename(path), w, h, len(levels), len(data) // 1024))

for m in j['materials']:
    tex = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
    if not tex: continue
    write_dds(os.path.join(outdir, '%s_%s.dds' % (prefix, m['name'])), load_rgb(j['textures'][tex['index']]['source']))
