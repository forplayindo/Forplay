fx_version 'cerulean'
game 'gta5'

description 'F_Vehicles'
repository 'https://github.com/Qbox-project/f_vehicles'
version '1.4.2'

server_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/appearance.lua',
}

server_only 'yes'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
