"""Salin kit F-UI (ios.css + font Inter) ke semua resource NUI.

Jalankan dari mana saja:  python _design/f-ui/sync.py
Setiap target mendapat <html>/ui/ios.css dan <html>/ui/fonts/*.woff2.
Resource baru: tambahkan folder html-nya ke TARGETS, lalu di fxmanifest `files`
tambahkan 'html/ui/ios.css' dan 'html/ui/fonts/*.woff2'.
"""
import shutil
from pathlib import Path

KIT = Path(__file__).resolve().parent
RES = KIT.parent.parent  # folder resources

TARGETS = [
    '[qbx]/f_cityhall/html',
    '[qbx]/f_police/html',
    '[qbx]/f_garages/html',
    '[qbx]/f_stash/html',
    '[qbx]/f_blips/html',
    '[qbx]/f_spawnpoints/html',
    '[qbx]/f_crew/html',
    '[qbx]/f_paycheck/html',
    '[script]/f_karakter/html',
    '[script]/f_petshop/html',
    '[ox]/ox_fuel/html',
    '[qbx]/f_cafe/html',
    '[qbx]/f_mechanicjob/html',
    '[qbx]/f_customs/html',
    '[qbx]/f_ambulancejob/html',
    '[job]/f_garbagejob/html',
    '[job]/f_courierjob/html',
    '[job]/f_mining/html',
    '[job]/f_lumberjack/html',
    '[job]/f_nelayan/html',
    '[job]/f_wine/html',
    '[script]/f_koperasi/html',
    '[script]/f_toll/html',
    '[script]/f_claimreward/html',
    '[script]/f_starterpack/html',
    '[qbx]/f_admin/html',
    '[qbx]/f_dealer/html',
    '[script]/f_graffiti/html',
    '[script]/f_dashboard/html',
    '[script]/f_panduan/html',
    '[script]/f_handling/html',
    '[script]/f_antitroll',  # ui_page di ui/ → ui/ios.css
]

for t in TARGETS:
    html = RES / t
    if not html.is_dir():
        print('LEWAT (tidak ada):', t)
        continue
    ui = html / 'ui'
    (ui / 'fonts').mkdir(parents=True, exist_ok=True)
    shutil.copy2(KIT / 'ios.css', ui / 'ios.css')
    for f in (KIT / 'fonts').glob('*.woff2'):
        shutil.copy2(f, ui / 'fonts' / f.name)
    print('ok', t)
