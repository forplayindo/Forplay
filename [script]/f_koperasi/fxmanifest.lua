fx_version 'cerulean'
game 'gta5'

description 'F_Koperasi - jual hasil kerja (tambang, daur ulang, dll) di Koperasi, uang ke bank + pajak'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'config/shared.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'ox_inventory',
	'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
