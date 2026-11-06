fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_dealer'
description 'Dealer kendaraan: NPC [E], NUI iOS (daftar, preview 3D, performa), test drive 1 menit di bandara, beli cash/bank, kendaraan donasi via tiket Discord + persetujuan admin'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'config.lua',
}

client_scripts {
    'client/preview.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/testdrive.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

-- f_vehicles sengaja tidak dicantumkan (server_only, client tidak punya → client gagal start)
dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'f_vehiclekeys',
}
