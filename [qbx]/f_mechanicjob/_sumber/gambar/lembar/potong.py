"""Potong lembar gambar Gemini (banyak item dalam satu gambar) jadi satu file per item di folder atas.

Pakai: python potong.py   lalu   python ../../../../f_cafe/_sumber/gambar/proses.py --dir ..
Kotak (x0, y0, x1, y1) dalam piksel gambar 1024x1024; batas bawah dicari dari celah kosong antar item.
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

SHEETS = {
    'mekanik_1.jpg': {
        # baris 1 & 2 (ada garis putih pemisah)
        'engine_oil':  (0, 0, 254, 254),     'coolant':    (258, 0, 510, 254),
        'brake_fluid': (514, 0, 766, 254),   'trans_fluid': (770, 0, 1024, 254),
        'spark_plug':  (0, 258, 254, 510),   'air_filter': (258, 258, 510, 510),
        'metalscrap':  (514, 258, 766, 510), 'steel':      (770, 258, 1024, 510),
        # bawah: item bertumpuk tanpa garis
        'aluminum':    (0, 514, 254, 695),   'glass':      (0, 695, 254, 838),   'repairkit': (0, 838, 254, 1024),
        'copper':      (258, 514, 510, 690), 'rubber':     (258, 690, 510, 840),
        'plastic':     (514, 514, 766, 766), 'cleaningkit': (514, 770, 766, 1024),
        'iron':        (770, 514, 1024, 686), 'tas_perkakas': (770, 686, 1024, 833), 'tirekit': (770, 833, 1024, 1024),
        # cadangan (tidak diproses): toolbox laci
        'lembar/repairkit_alt': (258, 840, 510, 1024),
    },
}

for sheet, boxes in SHEETS.items():
    im = Image.open(os.path.join(HERE, sheet)).convert('RGB')
    for name, box in boxes.items():
        dst = os.path.join(HERE, '..', name + '.jpg') if not name.startswith('lembar/') else os.path.join(HERE, name.split('/', 1)[1] + '.jpg')
        im.crop(box).save(dst, quality=95)
        print(name, box)
