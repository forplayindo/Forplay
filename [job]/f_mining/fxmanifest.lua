fx_version 'cerulean'
game 'gta5'

description 'F_Mining - tambang bebas: 5 gua (routing bucket), lori ke gudang, tungku lebur di lobby'
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
	'shared/cave.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/sfx/*.wav',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'ox_target',
	'ox_inventory',
	'qbx_core',
	'f_addonprop',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
