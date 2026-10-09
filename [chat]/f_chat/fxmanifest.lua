fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_chat'
author 'custom build'
description 'Channel-based roleplay chat for QBox / QBCore / ESX / standalone'
version '1.0.0'

-- Replaces the built-in chat resource.
provide 'chat'

shared_script 'config.lua'

client_scripts {
    'client/main.lua',
    'client/bubbles.lua',
    'client/blur.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/blur.js',
}
