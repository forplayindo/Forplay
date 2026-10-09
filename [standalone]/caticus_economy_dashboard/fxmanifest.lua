fx_version 'cerulean'
game 'gta5'

name 'economy_dashboard'
description 'Economy Dashboard Rebuilt To Be Fully Open Source'
author 'Caticus'
website 'www.5Mservers.com'

lua54 'yes'

escrow_ignore {
    'config.lua',
    'server/bridge/esx.lua',
    'server/bridge/qbcore.lua',
    'server/bridge/qbox.lua',
    'server/bridge/standalone.lua',
    'server/bridge/_init.lua'
}

shared_scripts {
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge/_init.lua',
    'server/bridge/qbcore.lua',
    'server/bridge/qbox.lua',
    'server/bridge/esx.lua',
    'server/bridge/standalone.lua',
    'server/database.lua',
    'server/tracking.lua',
    'server/analytics.lua',
    'server/alerts.lua',
    'server/admin.lua',
    'server/discord.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/css/*.css',
    'ui/js/*.js',
}

dependencies {
    'oxmysql',
}

dependency '/assetpacks'