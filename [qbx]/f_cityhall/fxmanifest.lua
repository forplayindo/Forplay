fx_version 'cerulean'
game 'gta5'

description 'f_cityhall: layanan publik (KTP, SIM, lisensi senjata, STNK, pajak kendaraan) dengan petugas'
repository 'https://github.com/Qbox-project/f_cityhall'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bank.lua',
    'server/main.lua',
    'server/tickets.lua',
}

ui_page 'html/index.html'

files {
    'config/client.lua',
    'config/shared.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'f_idcard',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
