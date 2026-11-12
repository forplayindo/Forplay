fx_version 'cerulean'
game 'gta5'

description 'f_petshop: toko & kontrol hewan peliharaan (dibuat sendiri, bukan turunan script lain)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'accessories.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/accessories.lua',
    'client/preview.lua',
    'client/main.lua',
    'client/pet.lua',
    'client/ride.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'data/flight_animals_peds.meta',
}

-- kuda & keledai (stream/flight_animals, GPL-3)
data_file 'PED_METADATA_FILE' 'data/flight_animals_peds.meta'

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
