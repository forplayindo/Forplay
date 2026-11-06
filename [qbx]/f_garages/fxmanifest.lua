fx_version 'cerulean'
game 'gta5'

name 'f_garages'
description 'Garage system for Qbox'
repository 'https://github.com/Qbox-project/f_garages'
version '1.1.4'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/*',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/editor.lua', -- editor garasi in-game (/garasi)
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/default-calculate-impound-fee.lua',
    'server/main.lua',
    'server/spawn-vehicle.lua',
    'server/editor.lua', -- editor garasi in-game (/garasi)
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'config/client.lua',
    'config/editor.lua',
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'