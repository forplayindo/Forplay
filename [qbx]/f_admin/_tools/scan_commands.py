"""Pindai semua resource, catat command chat yang terdaftar + apakah dibatasi (restricted).

FiveM tidak punya native untuk tahu apakah sebuah command dibatasi ACE, jadi f_admin
membaca hasil pindaian ini (data/commands.json) untuk menandai command umum vs staff.
Jalankan ulang setelah menambah/menghapus resource:

    python "[qbx]/f_admin/_tools/scan_commands.py"
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
RES = HERE.parent.parent.parent  # folder resources
OUT = HERE.parent / 'data' / 'commands.json'

SKIP_DIRS = {'node_modules', '.git', 'backups', 'backup', '_sumber', '_tools', 'web', 'html', 'mockup'}

# lib.addCommand('nama', { ... }  atau  lib.addCommand({'a', 'b'}, { ... }
RE_OX = re.compile(r"lib\.addCommand\(\s*(\{[^}]*\}|'[^']+'|\"[^\"]+\")\s*,\s*(\{|false|nil)", re.S)
# RegisterCommand('nama', function ... end, true)
RE_REG = re.compile(r"RegisterCommand\(\s*['\"]([^'\"]+)['\"]")
RE_NAME = re.compile(r"['\"]([^'\"]+)['\"]")


def resource_of(path: Path) -> str:
    # resource = folder terdekat yang punya fxmanifest.lua
    for parent in path.parents:
        if (parent / 'fxmanifest.lua').exists() or (parent / '__resource.lua').exists():
            return parent.name
        if parent == RES:
            break
    return '?'


_locales = {}


def locale_text(file: Path, key: str) -> str:
    """help = locale('a.b') -> teks dari locales/id.json (cadangan en.json) milik resource itu."""
    root = next((p for p in file.parents if (p / 'fxmanifest.lua').exists()), None)
    if not root:
        return key
    for lang in ('id', 'en'):
        lf = root / 'locales' / f'{lang}.json'
        if lf not in _locales:
            try:
                _locales[lf] = json.loads(lf.read_text(encoding='utf-8'))
            except (OSError, ValueError):
                _locales[lf] = None
        node = _locales[lf]
        for part in key.split('.'):
            node = node.get(part) if isinstance(node, dict) else None
        if isinstance(node, str):
            return node
    return key


def block_after(src: str, start: int) -> str:
    """Ambil isi tabel opsi { ... } yang dimulai di src[start] == '{'."""
    depth = 0
    for i in range(start, min(len(src), start + 4000)):
        c = src[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
    return src[start:start + 800]


def strip_params(opts: str) -> str:
    """Buang tabel params = { ... } supaya help milik parameter tidak terbaca sebagai help command."""
    i = opts.find('params')
    if i < 0:
        return opts
    j = opts.find('{', i)
    if j < 0:
        return opts
    inner = block_after(opts, j)
    return opts[:i] + opts[j + len(inner):]


def main():
    cmds = {}
    for f in RES.rglob('*.lua'):
        if any(p in SKIP_DIRS or p.startswith('[backup') for p in f.parts):
            continue
        try:
            src = f.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        if 'addCommand' not in src and 'RegisterCommand' not in src:
            continue
        # file client tidak bisa dibatasi ACE (RegisterCommand client selalu umum)
        is_client = 'client' in [p.lower() for p in f.relative_to(RES).parts] or f.name.startswith('cl_')
        res = resource_of(f)

        for m in RE_OX.finditer(src):
            names = RE_NAME.findall(m.group(1))
            opts = block_after(src, m.start(2)) if m.group(2) == '{' else ''
            own = strip_params(opts)
            restricted = bool(re.search(r"restricted\s*=\s*(?!false|nil)['\"{\w]", own))
            hm = re.search(r"help\s*=\s*(locale\(\s*)?['\"]([^'\"]*)['\"]", own)
            help_ = (locale_text(f, hm.group(2)) if hm.group(1) else hm.group(2)) if hm else ''
            for n in names:
                cmds[n.lower()] = {'res': res, 'help': help_, 'restricted': restricted}

        for m in RE_REG.finditer(src):
            name = m.group(1).lower()
            if name in cmds:
                continue
            # cari argumen ketiga: ", true)" setelah fungsi selesai — cukup cek "end, true" terdekat
            tail = src[m.end():m.end() + 6000]
            end = re.search(r"end\s*,\s*(true|false)\s*\)", tail)
            restricted = bool(end and end.group(1) == 'true') and not is_client
            cmds[name] = {'res': res, 'help': '', 'restricted': restricted, 'client': is_client}

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(dict(sorted(cmds.items())), ensure_ascii=False, indent=1), encoding='utf-8')
    r = sum(1 for c in cmds.values() if c['restricted'])
    print(f'{len(cmds)} command ditulis ke {OUT} ({r} dibatasi, {len(cmds) - r} umum)')


if __name__ == '__main__':
    main()
