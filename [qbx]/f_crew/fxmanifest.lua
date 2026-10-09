fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_crew'
description 'Crew: gang/komunitas buatan pemain lewat app f_phone (boss menu, kas, leaderboard, garasi, channel radio)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
    'client/turf.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'shared/zones.lua',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/icon.svg',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
