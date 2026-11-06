fx_version 'cerulean'
game 'gta5'

description 'F_CourierJob - kurir paket GoPostal bersama kru (maks 2), diambil di job centre balai kota'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/main.lua'
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'config/client.lua',
	'config/shared.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'ox_target',
	'qbx_core',
	'f_vehiclekeys',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
