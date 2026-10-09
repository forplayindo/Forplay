fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_prop'
description 'Pasang prop permanen (tersimpan di database) - admin only'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'props.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
