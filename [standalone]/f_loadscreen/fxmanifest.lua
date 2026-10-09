-- lastresort_loading
-- LastResort Development · https://intelnpc.com

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'foreplay'
author 'LastResort Development'
description 'Configurable loading screen — live server stats, local MP4 background video, local MP3 music with a real spectrum visualizer, particles, stripes/dots/hex/grid pattern, i18n.'
version '2.1.0'
repository 'https://fivem-last-resort.tebex.io'

loadscreen 'index.html'
loadscreen_cursor 'yes'
ui_page 'nui/callbacks.html'
loadscreen_manual_shutdown 'yes'

client_script 'bridge/handover.lua'
server_script 'bridge/server.lua'

files {
    'index.html',
    'nui/callbacks.html',
    'config.js',
    'locales/*.json',
    'assets/fonts/app-font.css',
    'assets/fonts/*.woff2',
    'assets/lucide/lucide.css',
    'assets/lucide/lucide.woff2',
    'assets/video/*.mp4',
    'assets/video/*.webm',
    'assets/video/*.mkv',
    'assets/video/*.m4v',
    'assets/video/*.ogv',
    'assets/img/*.png',
    'assets/img/*.jpg',
    'assets/img/*.svg',
    'assets/img/*.webp'
}

escrow_ignore {
    'config.js',
    'locales/*.json',
    'assets/**/*',
    'data/*',
    '*.md',
}

dependency '/assetpacks'