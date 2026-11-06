"""Hapus background gambar menu di folder ini -> PNG 256x256 transparan ke ox_inventory/web/images.

Pakai: python proses.py [--dir FOLDER] [nama_item ...]
  tanpa nama_item = semua jpg/png/webp di folder (default folder ini), contoh gambar mekanik:
  python proses.py --dir "../../../f_mechanicjob/_sumber/gambar"
Butuh: pip install pillow numpy scipy onnxruntime rembg

Gambar AI sering punya background kotak-kotak "transparan" palsu yang tercetak di JPG,
jadi background dihapus pakai model rembg + perbaikan khusus per item (FIX di bawah).
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as nd
from rembg import new_session, remove

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..', '[ox]', 'ox_inventory', 'web', 'images'))
SIZE = 256        # ukuran akhir (persegi)
MARGIN = 0.04     # ruang kosong di tiap sisi
COLORS = 256      # warna palet PNG (kecilkan file); 0 = PNG penuh


def plate(rgb, alpha):
    """Piring putih hilang karena menyatu dengan kotak putih: cari area yang bukan warna kotak-kotak,
    ambil blob terbesar, lalu jadikan elips halus dari momennya."""
    L, sat = rgb.mean(2), rgb.max(2) - rgb.min(2)
    checker = (sat < 8) & ((L >= 251) | ((L >= 193) & (L <= 207)))
    m = nd.binary_closing(nd.binary_opening(~checker, iterations=3), iterations=14)
    lab, n = nd.label(m)
    m = nd.binary_fill_holes(lab == (np.argmax(nd.sum(m, lab, range(1, n + 1))) + 1))
    ys, xs = np.nonzero(m)
    cx, cy, rx, ry = xs.mean(), ys.mean(), 2 * xs.std(), 2 * ys.std()
    yy, xx = np.mgrid[:rgb.shape[0], :rgb.shape[1]]
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    ell = np.clip((1 - r) * min(rx, ry) + .5, 0, 1) * 255
    return np.maximum(alpha, ell)


def glass_base(y0, op=.28, blur=9):
    """Kaki gelas bening masih memperlihatkan kotak-kotak: di bawah y0 (rasio tinggi) warnanya
    diblur kuat sampai polanya hilang lalu dibuat semi-transparan (efek kaca)."""
    def fix(rgb, alpha):
        rows = np.arange(rgb.shape[0])[:, None] >= int(rgb.shape[0] * y0)
        soft = np.stack([nd.gaussian_filter(rgb[..., c].astype(float), blur) for c in range(3)], 2)
        rgb[rows[..., 0]] = soft[rows[..., 0]].astype(int)
        inner = nd.binary_erosion(alpha > 128, iterations=7)  # tepi kaca tetap tegas
        return np.where(rows, np.where(inner, alpha * op, alpha * .85), alpha)
    return fix


def fill_holes(close=4, opacity=255, min_light=None):
    """Bagian di tengah objek yang ikut terhapus (label putih/silver, plastik bening): tutup lubangnya.
    opacity < 255 = isi semi-transparan (plastik bening); min_light = hanya lubang yang terang (label putih),
    supaya area di dalam lingkaran selang dsb. tidak ikut terisi background."""
    def fix(rgb, alpha):
        holes = nd.binary_fill_holes(nd.binary_closing(alpha > 128, iterations=close)) & (alpha <= 128)
        if min_light is not None:
            holes &= rgb.mean(2) >= min_light
            holes = nd.binary_opening(holes, iterations=2)
        return np.where(holes, np.maximum(alpha, opacity), alpha)
    return fix


def drop_edge(side, split=8):
    """Buang blob yang menyentuh tepi gambar (objek terpotong di lembar Gemini). side: 'top'/'bottom'/'left'/'right'.
    Mask dierosi `split` piksel dulu supaya objek yang saling menempel terpisah jadi blob sendiri."""
    def fix(rgb, alpha):
        solid = alpha > 128
        lab, _ = nd.label(nd.binary_erosion(solid, iterations=split))
        k = split  # erosi juga mengikis k piksel dari tepi gambar, jadi cek baris/kolom ke-k
        line = {'top': lab[k], 'bottom': lab[-k - 1], 'left': lab[:, k], 'right': lab[:, -k - 1]}[side]
        keep = nd.binary_dilation((lab > 0) & ~np.isin(lab, np.unique(line[line > 0])), iterations=split + 3)
        return np.where(keep, alpha, 0)
    return fix


def cut_top(y0):
    """Hapus semua di atas y0 (rasio tinggi), contoh strip segel kantong plastik yang melayang."""
    def fix(rgb, alpha):
        alpha = alpha.copy()
        alpha[:int(alpha.shape[0] * y0)] = 0
        return alpha
    return fix


def drop_small(frac=.05):
    """Buang serpihan (blob < frac x blob terbesar), contoh sisi kantong plastik yang tersisa sepotong-sepotong."""
    def fix(rgb, alpha):
        lab, n = nd.label(alpha > 12)
        if n < 2:
            return alpha
        sizes = np.concatenate([[0], nd.sum(np.ones_like(alpha), lab, range(1, n + 1))])
        return np.where(sizes[lab] >= frac * sizes.max(), alpha, 0)
    return fix


def chain(*fixes):
    def fix(rgb, alpha):
        for f in fixes:
            alpha = f(rgb, alpha)
        return alpha
    return fix


FIX = {
    'adonan_donat': drop_edge('right'),
    'roti_burger': chain(cut_top(.25), drop_small()),
    'cafe_nasigoreng': plate,
    'cafe_milkshake': glass_base(.78),
    'engine_oil': fill_holes(),
    'trans_fluid': fill_holes(),
    'blood_bag': fill_holes(min_light=236),
    'suture': fill_holes(close=14, opacity=120),
    'chainsaw': fill_holes(close=6),  # bilah besi abu-abu ikut terhapus, isi area di dalam rantai
}

args = sys.argv[1:]
SRC = HERE
if args[:1] == ['--dir']:
    SRC = os.path.abspath(args[1])
    args = args[2:]
want = set(args)
session = new_session('isnet-general-use')

for fn in sorted(os.listdir(SRC)):
    name, ext = os.path.splitext(fn)
    if ext.lower() not in ('.jpg', '.jpeg', '.png', '.webp'):
        continue
    if want and name not in want:
        continue
    src = Image.open(os.path.join(SRC, fn)).convert('RGB')
    img = remove(src, session=session, post_process_mask=True)
    alpha = np.asarray(img.getchannel('A')).astype(float)
    if name in FIX:
        rgb = np.asarray(src).astype(int)
        alpha = FIX[name](rgb, alpha)
        src = Image.fromarray(rgb.clip(0, 255).astype(np.uint8))
    alpha[alpha < 12] = 0  # buang sisa piksel hampir transparan supaya bbox rapat
    a = Image.fromarray(alpha.astype(np.uint8))
    img = src.convert('RGBA')
    img.putalpha(a)
    img = img.crop(a.getbbox())
    w, h = img.size
    side = int(max(w, h) / (1 - 2 * MARGIN))
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - w) // 2, (side - h) // 2))
    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    if COLORS:
        canvas = canvas.quantize(COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    dst = os.path.join(OUT, name + '.png')
    canvas.save(dst, optimize=True)
    print(f'{name}: {os.path.getsize(dst) // 1024} KB')
