fx_version 'cerulean'
game 'gta5'

description 'f_multichar: pilih karakter + pilih lokasi spawn dalam satu layar (pengganti menu qbx_core + f_spawn)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'config.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
