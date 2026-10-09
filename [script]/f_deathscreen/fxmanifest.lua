fx_version 'cerulean'
game 'gta5'

description 'f_deathscreen - deathscreen untuk f_medical (countdown server-side, dispatch EMS, sync)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'f_medical',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
