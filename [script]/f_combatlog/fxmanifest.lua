fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name '4play-combatlog'
description 'Combat log marker dengan Discord ID (Qbox)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
