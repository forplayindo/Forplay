fx_version 'cerulean'
game 'gta5'

description 'f_jewelery'
repository 'https://github.com/Qbox-project/f_jewelery'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_script 'client/main.lua'

server_script 'server/main.lua'

files {
    'config/client.lua',
    'config/shared.lua',
    'locales/*.json',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'