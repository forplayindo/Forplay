"""Potong lembar Gemini 2x2 (garis putih pemisah di tengah) jadi satu file per item di folder atas.

Pakai: python potong.py   lalu   python ../proses.py [nama_item ...]
Urutan nama per lembar: kiri atas, kanan atas, kiri bawah, kanan bawah. None = lewati (duplikat).
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAP = 10  # piksel yang dibuang di sekitar garis pemisah

SHEETS = {
    'bahan_1.jpg': ('jeruk', 'susu', 'es_krim_vanila', 'air_soda'),
    'bahan_2.jpg': (None, 'es_batu', None, 'soda_cola'),
    'bahan_3.jpg': ('mie_instan', 'bubuk_kopi', 'bubuk_coklat', 'kayu_manis'),
    'bahan_4.jpg': ('minyak_goreng', 'gula', 'beras', 'telur'),
    'bahan_5.jpg': ('saus_salsa', 'kecap_manis', 'keripik_tortilla', 'adonan_donat'),
    'bahan_6.jpg': ('daging_ayam', 'sosis', 'keju', 'saus_mustard'),
}

for sheet, names in SHEETS.items():
    im = Image.open(os.path.join(HERE, sheet)).convert('RGB')
    w, h = im.size
    cx, cy = w // 2, h // 2
    boxes = ((0, 0, cx - GAP, cy - GAP), (cx + GAP, 0, w, cy - GAP),
             (0, cy + GAP, cx - GAP, h), (cx + GAP, cy + GAP, w, h))
    for name, box in zip(names, boxes):
        if name:
            im.crop(box).save(os.path.join(HERE, '..', name + '.jpg'), quality=95)
            print(name, box)
