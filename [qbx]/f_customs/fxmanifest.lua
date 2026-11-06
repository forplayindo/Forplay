fx_version 'cerulean'
game 'gta5'

author 'Jorn#0008'
description 'f_customs: bengkel kustom self-service (NUI), tagihan ke kasir f_mechanicjob'
version '2.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    '@qbx_core/modules/lib.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'config/shared.lua',
    'config/client.lua',
    'config/mods.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'carcols_gen9.meta',
    'carmodcols_gen9.meta',
}

data_file 'CARCOLS_GEN9_FILE' 'carcols_gen9.meta'
data_file 'CARMODCOLS_GEN9_FILE' 'carmodcols_gen9.meta'

dependencies {
    'ox_lib',
    'qbx_core',
    'f_mechanicjob',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
