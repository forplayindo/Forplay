fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_dbmigrate'
description 'Pastikan semua kolom uang di database bertipe BIGINT (aman sampai triliunan)'
version '1.0.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependency 'oxmysql'
