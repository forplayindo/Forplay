fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_phone'
author ' lintang dev'
version '1.0.5-duo'
description 'HP iPhone Duo'

-- Kompatibilitas: script pihak ketiga yang ditulis untuk sd-phone memanggil exports['sd-phone'].
-- Nama itu diteruskan ke f_phone oleh shared/export_alias.lua (provide sendiri tidak meneruskan export).
provide 'sd-phone'

shared_scripts {
    'shared/export_alias.lua',
    '@ox_lib/init.lua',
    'bridge/shared/init.lua',
}

client_scripts {
    'bridge/client/init.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/crypto.js',
    'server/relay.js',
    'server/upload.js',
    'bridge/server/init.lua',
    'server/main.lua',
}

ui_page 'web/build/index.html'

files {
    'bridge/**.lua',
    'shared/**.lua',
    'configs/*.lua',
    'client/**.lua',
    'locales/*.json',
    'web/build/index.html',
    'web/build/uploader.html',
    'web/build/sdphone-sdk.js',
    'web/build/sdphone-sdk.d.ts',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/assets/*.png',
    'web/build/assets/*.glb',
    'web/build/assets/*.jpg',
    'web/build/assets/*.webp',
    'web/build/assets/*.svg',
    'web/build/assets/*.woff2',
    'web/build/assets/*.woff',
    'web/build/assets/*.mp3',
    'web/build/assets/*.ogg',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Model HP di tangan (dulu resource sd-phone-props), di-stream dari folder stream/.
data_file 'DLC_ITYP_REQUEST' 'stream/sd_phone.ytyp'

provide 'lb-phone'
provide 'lb-tablet'
provide 'yseries'

provide 'qs-smartphone'
provide 'qs-smartphone-pro'
provide 'qs-smartphone-lite'
provide 'gksphone'
provide 'roadphone'
