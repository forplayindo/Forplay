fx_version 'cerulean'
game 'gta5'

description 'f_paycheck: gaji disimpan, dicairkan di ATM / bank (potong pajak ke rekening pemerintah)'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'config.lua',
    'shared/banking.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ox_lib',
    'ox_target',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
