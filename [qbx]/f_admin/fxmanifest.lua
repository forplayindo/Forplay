fx_version 'cerulean'
game 'gta5'

description 'f_admin: panel admin NUI dengan role Owner / Admin / Support, izin per command, ban HWID, laporan warga, log Discord'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts {
    'client/main.lua',
    'client/self.lua',
    'client/spectate.lua',
    'client/dev.lua',
    'client/wtune.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/discord.lua',
    'server/acl.lua',
    'server/main.lua',
    'server/players.lua',
    'server/give.lua',
    'server/world.lua',
    'server/reports.lua',
    'server/pets.lua',
    'server/bans.lua',
    'server/commands.lua',
    'server/wtune.lua',
}

ui_page 'html/index.html'

files {
    'shared/weapons.lua',
    'html/ui/ios.css',
    'html/ui/fonts/*.woff2',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/lapor.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
