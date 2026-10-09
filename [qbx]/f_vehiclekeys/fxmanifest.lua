fx_version 'cerulean'
game 'gta5'

description 'vehicle key management system'
repository 'https://github.com/Qbox-project/f_vehiclekeys'
version '1.1.0'

ox_lib 'locale'

ui_page 'web/build/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/types.lua',
    'shared/vehicle-config.lua',
    'shared/access.lua',
    'bridge/qb/shared.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/functions.lua',
    'client/searchkeys.lua',
    'client/main.lua',
    'client/carjack.lua',
    'client/ui.lua',
    'client/mechanic.lua',
    'bridge/qb/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/version.lua',
    'server/keys.lua',
    'server/main.lua',
    'server/theft.lua',
    'server/commands.lua',
    'bridge/qb/server.lua',
}

files {
    'locales/*.json',
    'config/client.lua',
    'config/shared.lua',
    'web/build/index.html',
    'web/build/**/*',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
provide 'qb-vehiclekeys'
