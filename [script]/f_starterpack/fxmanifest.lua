fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_starterpack'
description 'Starterpack warga baru: item + kendaraan pertama (sekali per karakter), NUI iOS'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_script 'client/main.lua'

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
}

-- f_vehicles sengaja tidak dicantumkan: resource itu server_only, client tidak punya,
-- jadi kalau ditulis di sini client gagal start ("Couldn't start resource").
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'ox_target',
    'f_vehiclekeys',
}
