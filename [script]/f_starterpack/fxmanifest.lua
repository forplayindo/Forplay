fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_starterpack'
description 'Starterpack warga baru: makanan, minuman, HP, dan kendaraan pertama (sekali per karakter)'
version '2.0.0'

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

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
    'ox_target',
    'f_vehicles',
    'f_vehiclekeys',
}
