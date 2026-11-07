fx_version 'cerulean'
game 'gta5'

description 'F_Wine - job bebas kebun anggur Marlowe: petik tandan, injak di tong blok, fermentasi di winery, jual wine di f_koperasi'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
	'config/shared.lua',
	'config/client.lua',
	'config/kebun.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'ox_target',
	'ox_inventory',
	'qbx_core',
	'f_addonprop',          -- prop f_anggur_* / f_wine_keranjang / f_wine_tong_*
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
