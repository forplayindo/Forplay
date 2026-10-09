fx_version 'cerulean'
game 'gta5'

description 'f_ambulancejob'
repository 'https://github.com/Qbox-project/f_ambulancejob'
version '1.0.0'

ox_lib 'locale'

dependencies {
    'qbx_core',
	'f_medical',
    'ox_lib',
	'ox_inventory',
	'ox_target',
}

ui_page 'html/index.html'

shared_scripts {
	'@ox_lib/init.lua',
	'@qbx_core/modules/lib.lua',
}

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	'client/*.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
}

files {
	'locales/*.json',
	'config/client.lua',
	'config/shared.lua',
	'config/treatment.lua',
	'config/pharmacy.lua',
	'config/stock.lua',
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/pharmacy.js',
	'html/surgery.js',
	'html/kasir.js',
	'html/body.png',
	'html/body-mask.png',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'