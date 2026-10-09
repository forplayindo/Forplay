fx_version 'cerulean'
game 'gta5'

description 'F_StreetRaces'
repository 'https://github.com/Qbox-project/f_streetraces'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua'

}
client_script 'client/main.lua'
server_script 'server/main.lua'

lua54 'yes'
use_experimental_fxv2_oal 'yes'