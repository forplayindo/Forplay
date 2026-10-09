---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT
fx_version 'bodacious'
game 'gta5'

lua54 "yes"

author 'GX | Nestor Ramos'
name 'bk_asuransi'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/styles.css',
    'web/script.js',
    'web/assets/*',
    'web/music/*',
}

server_scripts {
    'Framework/sv_.lua',
    'Framework/compatibility/sv_notify.lua',
    'src/server.lua',
    'custom/Notify.lua',
}
client_scripts {
    'src/client.lua',
    'Framework/cl_.lua',
}

shared_scripts{
    'config.lua'
}

escrow_ignore {
    'config.lua',
    'custom/Notify.lua',
}
---- my tebex: https://guxfiz.tebex.io/
---- my discord: https://discord.gg/kncN7Fr5KT