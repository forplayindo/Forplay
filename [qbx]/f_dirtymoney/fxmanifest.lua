fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_dirtymoney'
description 'Uang kotor: item cash tetap satu, server mencatat bagian kotornya. Bank menolak uang kotor.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
