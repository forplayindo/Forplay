fx_version 'cerulean'
game 'gta5'

description 'f_blips: semua blip lokasi statis di satu config, dikelola admin lewat /blips'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'data/blips.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependency 'ox_lib'

lua54 'yes'
use_experimental_fxv2_oal 'yes'
