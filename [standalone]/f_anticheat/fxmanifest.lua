fx_version 'cerulean'
game 'gta5'

name 'f_anticheat'
description 'Server-authoritative anti-cheat: entity/explosion spam, speed & teleport anomaly detection, unauthorized weapon detection, and a self-contained ban list'
author 'Server owner'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhook.lua',
    'server/storage.lua',
    'server/punish.lua',
    'server/connecting.lua',
    'server/detections/entityspam.lua',
    'server/detections/explosion.lua',
    'server/detections/speed.lua',
    'server/detections/weapon.lua',
    'server/detections/health.lua',
    'server/commands.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
