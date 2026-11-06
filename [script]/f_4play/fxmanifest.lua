fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'f_4play'
description 'Gabungan script kecil tanpa NUI: bel lobi, prop permanen, marker jarak suara, duduk di kursi'
version '1.0.0'

-- Semua file berbagi satu Lua state: tiap modul memakai config global sendiri
-- (BellConfig, PropConfig, VoiceRangeConfig, SitConfig) supaya tidak saling menimpa.

shared_scripts {
    '@ox_lib/init.lua',
    'modules/bell/config.lua',
    'modules/prop/config.lua',
    'modules/voicerange/config.lua',
    'modules/sit/config.lua',
}

client_scripts {
    'modules/bell/client.lua',
    'modules/prop/props.lua',
    'modules/prop/client.lua',
    'modules/voicerange/client.lua',
    'modules/sit/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'modules/bell/server.lua',
    'modules/prop/server.lua',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
    'qbx_core',
}
