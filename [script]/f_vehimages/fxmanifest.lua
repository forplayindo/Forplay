fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'f_vehimages'
description 'Satu folder foto kendaraan addon untuk semua script (STNK, cityhall, garasi f_phone, mekanik) + /fotokendaraan'
version '1.1.0'

-- Foto dipakai lewat nui://f_vehimages/images/<spawn>.webp
-- Urutan di setiap script: foto di sini -> docs.fivem.net/vehicles/<spawn>.webp -> siluet/ikon
dependencies {
    'ox_lib',
}

shared_script '@ox_lib/init.lua'
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'config.lua',
    'html/index.html',
    'images/*.webp',
}
