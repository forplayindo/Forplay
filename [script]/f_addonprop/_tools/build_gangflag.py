# Bendera gang: setiap gambar _sumber/bendera/<nama>.png -> model stream/gang_flags/gangflag_<nama>.ydr
# (tiang + kain sama dengan flag_on_pole, hanya tekstur kain yang diganti), lalu gang_flags.ytyp dibuat ulang
# berisi tugu_flag_pedestal + flag_on_pole + semua gangflag_*.
# python _tools/build_gangflag.py            -> bangun semua gambar (yang belum / yang berubah)
# python _tools/build_gangflag.py --semua    -> paksa bangun ulang semua
# Gambar sebaiknya 3:2 (mis. 1500x1000), tanpa tulisan. Diubah ke 1024x512 DXT1 + mipmap.
import sys, os, re, glob, shutil, subprocess
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, '_sumber', 'bendera')
TPL = os.path.join(SRC, '_template')
BUILD = os.path.join(SRC, '_build')
OUT = os.path.join(ROOT, 'stream', 'gang_flags')
CW = os.path.join(ROOT, '_tools', 'cw.ps1')
TEX_W, TEX_H = 1024, 512
# UV kain: v=1 di tepi atas -> gambar dibalik atas-bawah. Kain 2 sisi, depan & belakang sama-sama terbaca
# (tidak cermin). Kalau di game gambar terbalik, ubah ke False/True lalu jalankan dengan --semua.
FLIP_V = True
FLIP_U = False

# bbox archetype (dari ytyp asli tugu_flag_props)
POLE_BB = ((-0.03, -0.05488932, 0.0), (1.22514617, 0.08332177, 2.821))
PEDESTAL_BB = ((-0.7, -0.7, 0.0), (0.7, 0.7, 0.516))


def slug(name):
    s = re.sub(r'[^a-z0-9_]+', '_', name.lower()).strip('_')
    return s[:50]


def write_dds_mips(img, path):
    """DXT1 dengan rantai mipmap (Pillow hanya menulis 1 level, jadi tiap level disimpan lalu digabung)."""
    levels, w, h = [], TEX_W, TEX_H
    while w >= 4 and h >= 4:
        tmp = path + '.lvl.dds'
        img.resize((w, h), Image.LANCZOS).save(tmp, pixel_format='DXT1')
        with open(tmp, 'rb') as f:
            data = f.read()
        os.remove(tmp)
        if not levels:
            header = bytearray(data[:128])
        levels.append(data[128:])
        w, h = w // 2, h // 2
    flags = int.from_bytes(header[8:12], 'little') | 0x20000          # DDSD_MIPMAPCOUNT
    header[8:12] = flags.to_bytes(4, 'little')
    header[28:32] = len(levels).to_bytes(4, 'little')
    caps = int.from_bytes(header[108:112], 'little') | 0x400008       # COMPLEX | MIPMAP
    header[108:112] = caps.to_bytes(4, 'little')
    with open(path, 'wb') as f:
        f.write(header)
        for lv in levels:
            f.write(lv)
    return len(levels)


def cw_import(xml, out):
    r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', CW, 'import', xml, out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit('CodeWalker import gagal untuk %s:\n%s%s' % (xml, r.stdout, r.stderr))


def build_flag(png, model):
    img = Image.open(png).convert('RGBA')
    bg = Image.new('RGBA', img.size, (255, 255, 255, 255))   # bagian transparan jadi putih
    img = Image.alpha_composite(bg, img).convert('RGB')
    if FLIP_V:
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
    if FLIP_U:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)

    d = os.path.join(BUILD, model)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    tex = model + '_kain'
    mips = write_dds_mips(img, os.path.join(d, tex + '.dds'))
    shutil.copy(os.path.join(TPL, 'flagpole_steel_d.dds'), d)

    with open(os.path.join(TPL, 'flag_on_pole.ydr.xml'), encoding='utf-8') as f:
        xml = f.read()
    xml = xml.replace('<Name>flag_on_pole</Name>', '<Name>%s</Name>' % model, 1)
    old_entry = re.search(r'<Item>\s*<Name>flagpole_cloth_d</Name>.*?</Item>', xml, re.S).group(0)
    new_entry = re.sub(r'<Width value="\d+" />', '<Width value="%d" />' % TEX_W, old_entry)
    new_entry = re.sub(r'<Height value="\d+" />', '<Height value="%d" />' % TEX_H, new_entry)
    new_entry = re.sub(r'<MipLevels value="\d+" />', '<MipLevels value="%d" />' % mips, new_entry)
    new_entry = new_entry.replace('flagpole_cloth_d', tex)
    xml = xml.replace(old_entry, new_entry, 1)
    xml = xml.replace('<Name>flagpole_cloth_d</Name>', '<Name>%s</Name>' % tex)   # DiffuseSampler kain
    xml_path = os.path.join(d, model + '.ydr.xml')
    with open(xml_path, 'w', encoding='utf-8') as f:
        f.write(xml)
    cw_import(xml_path, os.path.join(OUT, model + '.ydr'))


def archetype(name, bb):
    (x0, y0, z0), (x1, y1, z1) = bb
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    r = (((x1 - x0) / 2) ** 2 + ((y1 - y0) / 2) ** 2 + ((z1 - z0) / 2) ** 2) ** 0.5
    # textureDictionary kosong (tekstur tertanam di ydr), physicsDictionary = nama model (collision tertanam)
    return f'''  <Item type="CBaseArchetypeDef">
   <lodDist value="150" />
   <flags value="0" />
   <specialAttribute value="0" />
   <bbMin x="{x0}" y="{y0}" z="{z0}" />
   <bbMax x="{x1}" y="{y1}" z="{z1}" />
   <bsCentre x="{cx}" y="{cy}" z="{cz}" />
   <bsRadius value="{r:.6f}" />
   <hdTextureDist value="50" />
   <name>{name}</name>
   <textureDictionary />
   <clipDictionary />
   <drawableDictionary />
   <physicsDictionary>{name}</physicsDictionary>
   <assetType>ASSET_TYPE_DRAWABLE</assetType>
   <assetName>{name}</assetName>
   <extensions />
  </Item>
'''


def build_ytyp(models):
    items = archetype('tugu_flag_pedestal', PEDESTAL_BB) + archetype('flag_on_pole', POLE_BB)
    items += ''.join(archetype(m, POLE_BB) for m in models)
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n<CMapTypes>\n <extensions />\n <archetypes>\n' + items +
           ' </archetypes>\n <name>gang_flags</name>\n <dependencies />\n'
           ' <compositeEntityTypes itemType="CCompositeEntityType" />\n</CMapTypes>\n')
    os.makedirs(BUILD, exist_ok=True)
    p = os.path.join(BUILD, 'gang_flags.ytyp.xml')
    with open(p, 'w', encoding='utf-8') as f:
        f.write(xml)
    cw_import(p, os.path.join(OUT, 'gang_flags.ytyp'))


def main():
    force = '--semua' in sys.argv
    pngs = sorted(p for ext in ('*.png', '*.jpg', '*.jpeg', '*.webp') for p in glob.glob(os.path.join(glob.escape(SRC), ext)))
    models, seen = [], {}
    for png in pngs:
        model = 'gangflag_' + slug(os.path.splitext(os.path.basename(png))[0])
        if model in seen:
            sys.exit('Nama bentrok: %s dan %s sama-sama jadi %s' % (seen[model], png, model))
        seen[model] = png
        models.append(model)
        ydr = os.path.join(OUT, model + '.ydr')
        if force or not os.path.exists(ydr) or os.path.getmtime(png) > os.path.getmtime(ydr):
            build_flag(png, model)
            print('dibangun  ', model)
        else:
            print('tetap     ', model)
    # model lama yang gambarnya sudah dihapus
    for old in glob.glob(os.path.join(glob.escape(OUT), 'gangflag_*.ydr')):
        if os.path.splitext(os.path.basename(old))[0] not in seen:
            os.remove(old)
            print('dihapus   ', os.path.basename(old))
    build_ytyp(models)
    print('\n%d bendera gang. Isi nama model di /peranggang > Bendera, lalu restart server.' % len(models))


if __name__ == '__main__':
    main()
