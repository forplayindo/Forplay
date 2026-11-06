fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_graffiti'
description 'Graffiti gang (crew f_crew) dari PNG per gang: semprot pakai pylox, bersihkan pakai Alat Pembersih'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
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
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'images/**/*.png',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
