fx_version 'cerulean'
game 'gta5'

description 'F_Toll - gerbang tol: palang per lajur, kartu e-toll (saldo di kartu), tarif rute masuk-keluar, dispatch polisi'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'config/shared.lua',
	'shared/route.lua',
	'client/barrier.lua',
	'client/display.lua',
	'client/editor.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/hologram.html',
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
