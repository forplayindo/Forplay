fx_version 'cerulean'
game 'gta5'

description 'f_handling: editor handling kendaraan addon (Owner/Admin). Langsung terasa, disimpan ke handling.meta di folder kendaraannya.'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'shared/fields.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
