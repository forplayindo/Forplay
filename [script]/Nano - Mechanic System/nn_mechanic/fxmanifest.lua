fx_version 'cerulean'
game 'gta5'
author 'Sinaps'
lua54 'yes'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'lib/shared.lua',
    'shared/**/*'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/**/*'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/**/*'
}

ui_page 'web/build/index.html'
files {
    'web/build/**/*',
}

escrow_ignore {
  'shared/**/*'
}