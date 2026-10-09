fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_signs'
description 'Papan nama toko 3D menempel di tembok (LED / Neon), menyala saat malam - admin only'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/fonts.lua',
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
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'atlas/*.png',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
