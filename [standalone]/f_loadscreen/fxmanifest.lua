fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_loadscreen'
author 'Foreplay'
description 'Loading screen Foreplay — video, musik + visualizer, status server live, peraturan/staf/berita, tips'
version '1.0.0'

loadscreen 'index.html'
loadscreen_cursor 'yes'
loadscreen_manual_shutdown 'yes'
-- NUI callback hanya diteruskan ke resource yang punya ui_page
ui_page 'nui/callbacks.html'

client_script 'client.lua'
server_script 'server.lua'

files {
    'index.html',
    'nui/callbacks.html',
    'config.js',
    'locales/*.json',
    'assets/fonts/*.woff2',
    'assets/video/*.mp4',
    'assets/video/*.webm',
    'assets/audio/*.mp3',
    'assets/audio/*.ogg',
    'assets/img/*.png',
    'assets/img/*.jpg',
    'assets/img/*.webp',
    'assets/img/*.svg',
}
