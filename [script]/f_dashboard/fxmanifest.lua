fx_version 'cerulean'
game 'gta5'

description 'F_Dashboard - analitik ekonomi kota (owner/admin), ringan: snapshot + cache, tanpa log per transaksi'
version '1.0.0'

shared_script '@ox_lib/init.lua'

client_script 'client/main.lua'

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server/flow.lua',
	'server/scan.lua',
	'server/main.lua',
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/ui/ios.css',
	'html/ui/fonts/*.woff2',
}

dependencies {
	'ox_lib',
	'oxmysql',
	'qbx_core',
	'ox_inventory',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
