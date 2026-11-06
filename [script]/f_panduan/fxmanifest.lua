fx_version 'cerulean'
game 'gta5'

description 'F_Panduan - panel Alur Kerja di tengah layar (penebang, tambang, nelayan, sampah, kurir)'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client.lua',
}

ui_page 'html/index.html'

files {
	'config.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'qbx_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
