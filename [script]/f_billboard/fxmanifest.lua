fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_billboard'
description 'Billboard gambar/video/YouTube (tersimpan di database) - admin only'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/presets.lua',
    'shared/media.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/dui.html',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.jpeg',
    'html/images/*.webp',
    'html/images/*.gif',
    'html/images/*.mp4',
    'html/images/*.webm',
}

dependencies {
    'ox_lib',
    'oxmysql',
}
