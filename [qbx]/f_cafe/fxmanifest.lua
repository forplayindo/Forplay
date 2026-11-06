fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_cafe'
description 'Cafe job: duty, uniform, stations, customer ordering (cash / f_phone invoice), staff serving, NPC cashier'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/bank.lua',
    'server/invoice.lua',
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

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
}
