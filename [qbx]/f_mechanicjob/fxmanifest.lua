fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'f_mechanicjob'
description 'Bengkel mekanik: Periksa Kendaraan (NUI), keausan & efek kerusakan, lift nteam, tagihan, kasir, kustom, toko bengkel, derek flatbed + job Derek'
version '2.0.0'

provide 'qb-towjob'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/job.lua',
    'client/panel.lua',
    'client/lift.lua',
    'client/wear.lua',
    'client/status.lua',
    'client/shop.lua',
    'client/kasir.lua',
    'client/tow.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/condition.lua',
    'server/lift.lua',
    'server/prices.lua',
    'server/stock.lua',
    'server/billing.lua',
    'server/kasir.lua',
    'server/customs.lua',
    'server/panel.lua',
    'server/job.lua',
    'server/shop.lua',
    'server/admin.lua',
    'server/tow.lua',
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'config/shared.lua',
    'config/client.lua',
    'config/wear.lua',
    'config/shop.lua',
    'config/stock.lua',
    'config/tow.lua',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/shop.js',
    'html/kasir.js',
    'html/sounds/*.mp3',
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'qbx_core',
}
