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
    'client/flag.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

-- Gang Wars (menu /peranggang + scoreboard). App Crew di HP tetap memakai web/ lewat iframe f_phone.
ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/map.jpg',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/icon.svg',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'ox_inventory',
}
