fx_version 'cerulean'
game 'gta5'

author 'Master Mind'
version '0.4.0'
description 'MM Radio - UI HUD Taktis ringan (vanilla JS, tanpa CDN)'
repository 'https://github.com/SOH69/mm_radio'

lua54 'yes'

ui_page 'build/index.html'
-- ui_page 'http://localhost:3000/' --for dev

shared_script {
    '@ox_lib/init.lua',
    'shared/**'
}

client_script {
    '@qbx_core/modules/playerdata.lua',
    'client/interface.lua',
    'client/function.lua',
    'client/event.lua',
    'client/nui.lua',
    'client/crew.lua' -- patch f_crew: channel gang dinamis
}

server_script {
    'server/main.lua',
}

files {
    'build/index.html',
    'build/style.css',
    'build/app.js',
    'build/fonts/*.woff2',
    'locales/*.json'
}

dependencies {
    'pma-voice',
    'ox_lib',
    '/onesync'
}
