fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_hygiene'
author 'f_hygiene'
description 'HUD Hygiene: Mandi, Kencing, Poop, Sleep'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/hud.lua',
    'client/blips.lua',
    'client/mandi.lua',
    'client/kencing.lua',
    'client/poop.lua',
    'client/sleep.lua',
    'client/debug.lua'
}

server_scripts {
    'server/main.lua',
    'server/mandi.lua',
    'server/kencing.lua',
    'server/poop.lua',
    'server/debug.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/sounds/nyamuk.wav'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'illenium-appearance',
    'f_medical'
}
