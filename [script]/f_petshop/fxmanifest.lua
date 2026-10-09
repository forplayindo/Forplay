fx_version 'cerulean'
game 'gta5'

description 'f_petshop: toko & kontrol hewan peliharaan (dibuat sendiri, bukan turunan script lain)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/pet.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/pets/*', -- gambar hewan untuk toko (nama file = nama model, lihat config.lua)
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
